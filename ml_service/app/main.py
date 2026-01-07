"""
NowNow Wildlife Finder - ML Microservice
FastAPI service for activity predictions using LightGBM and GMM
"""
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import numpy as np
from lightgbm import LGBMRegressor
from sklearn.mixture import GaussianMixture
from sklearn.cluster import DBSCAN
import math

app = FastAPI(
    title="NowNow ML Service",
    description="Machine learning predictions for wildlife activity patterns",
    version="1.0.0"
)

# Allow CORS for Rails app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# --- Pydantic Models ---

class SightingData(BaseModel):
    hour: int
    month: int
    ndvi: Optional[float] = None
    temperature_c: Optional[float] = None


class ActivityPredictionRequest(BaseModel):
    animal_id: int
    sightings: List[SightingData]


class ActivityGridItem(BaseModel):
    month: int
    hour: int
    predicted_activity: float


class ActivityPredictionResponse(BaseModel):
    best_month: int
    best_hour: int
    grid: List[ActivityGridItem]
    r2_score: float


class GmmCurveRequest(BaseModel):
    animal_id: int
    month: int
    sightings: List[SightingData]


class GmmCurveResponse(BaseModel):
    hours: List[int]
    probabilities: List[float]


class HotspotRequest(BaseModel):
    coordinates: List[dict]  # [{lat, lon}, ...]
    eps_km: float = 10.0
    min_samples: int = 10


class HotspotResponse(BaseModel):
    center_lat: Optional[float]
    center_lon: Optional[float]
    cluster_count: int
    points_in_largest: int


# --- Helper Functions ---

def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate the great-circle distance between two points on Earth."""
    R = 6371.0  # Earth's radius in km

    lat1_rad = math.radians(lat1)
    lat2_rad = math.radians(lat2)
    delta_lat = math.radians(lat2 - lat1)
    delta_lon = math.radians(lon2 - lon1)

    a = math.sin(delta_lat/2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(delta_lon/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))

    return R * c


def prepare_features(sightings: List[SightingData]) -> np.ndarray:
    """Convert sightings to feature matrix for ML model."""
    features = []
    for s in sightings:
        hour_sin = np.sin(2 * np.pi * s.hour / 24)
        hour_cos = np.cos(2 * np.pi * s.hour / 24)
        month_sin = np.sin(2 * np.pi * s.month / 12)
        month_cos = np.cos(2 * np.pi * s.month / 12)
        ndvi = s.ndvi if s.ndvi is not None else 0.45  # Default NDVI
        temp = s.temperature_c if s.temperature_c is not None else 25.0  # Default temp

        features.append([hour_sin, hour_cos, month_sin, month_cos, ndvi, temp])

    return np.array(features)


# --- API Endpoints ---

@app.get("/api/v1/health")
def health():
    """Health check endpoint."""
    return {"status": "healthy", "service": "ml-service"}


@app.post("/api/v1/predict/activity", response_model=ActivityPredictionResponse)
def predict_activity(request: ActivityPredictionRequest):
    """
    Train LightGBM on sighting data and predict activity levels across all month/hour combinations.
    Returns the best month and hour for viewing, plus a full prediction grid.
    """
    if len(request.sightings) < 50:
        raise HTTPException(status_code=400, detail="Need at least 50 sightings for prediction")

    # Prepare features and target
    X = prepare_features(request.sightings)

    # Count sightings per month/hour bin as target variable
    hour_month_counts = {}
    for s in request.sightings:
        key = (s.month, s.hour)
        hour_month_counts[key] = hour_month_counts.get(key, 0) + 1

    y = np.array([hour_month_counts.get((s.month, s.hour), 1) for s in request.sightings])

    # Train LightGBM
    model = LGBMRegressor(
        n_estimators=100,
        max_depth=6,
        learning_rate=0.1,
        num_leaves=31,
        random_state=42,
        verbose=-1
    )
    model.fit(X, y)

    # Calculate R² score
    y_pred_train = model.predict(X)
    ss_res = np.sum((y - y_pred_train) ** 2)
    ss_tot = np.sum((y - np.mean(y)) ** 2)
    r2 = 1 - (ss_res / ss_tot) if ss_tot > 0 else 0

    # Generate predictions for all month/hour combinations
    grid = []
    best_activity = -1
    best_month = 1
    best_hour = 0

    for month in range(1, 13):
        for hour in range(24):
            hour_sin = np.sin(2 * np.pi * hour / 24)
            hour_cos = np.cos(2 * np.pi * hour / 24)
            month_sin = np.sin(2 * np.pi * month / 12)
            month_cos = np.cos(2 * np.pi * month / 12)

            features = np.array([[hour_sin, hour_cos, month_sin, month_cos, 0.45, 25.0]])
            pred = model.predict(features)[0]

            grid.append(ActivityGridItem(month=month, hour=hour, predicted_activity=float(pred)))

            if pred > best_activity:
                best_activity = pred
                best_month = month
                best_hour = hour

    return ActivityPredictionResponse(
        best_month=best_month,
        best_hour=best_hour,
        grid=grid,
        r2_score=float(r2)
    )


@app.post("/api/v1/predict/gmm-curve", response_model=GmmCurveResponse)
def gmm_curve(request: GmmCurveRequest):
    """
    Fit a Gaussian Mixture Model on hourly activity for a specific month.
    Returns hourly probabilities for the 24-hour activity curve.
    """
    # Filter sightings for the specified month
    month_sightings = [s for s in request.sightings if s.month == request.month]

    if len(month_sightings) < 20:
        # Return uniform distribution if not enough data
        return GmmCurveResponse(
            hours=list(range(24)),
            probabilities=[1/24] * 24
        )

    # Extract hours
    hours = np.array([[s.hour] for s in month_sightings])

    # Fit GMM with 3 components (dawn, day, dusk activity patterns)
    n_components = min(3, len(month_sightings) // 10)
    n_components = max(1, n_components)

    gmm = GaussianMixture(
        n_components=n_components,
        covariance_type='full',
        random_state=42
    )
    gmm.fit(hours)

    # Generate probability curve
    hour_range = np.array([[h] for h in range(24)])
    log_probs = gmm.score_samples(hour_range)
    probs = np.exp(log_probs)

    # Normalize to sum to 1
    probs = probs / probs.sum()

    return GmmCurveResponse(
        hours=list(range(24)),
        probabilities=probs.tolist()
    )


@app.post("/api/v1/cluster/hotspots", response_model=HotspotResponse)
def cluster_hotspots(request: HotspotRequest):
    """
    Run DBSCAN clustering on coordinates to find wildlife hotspots.
    Returns the center of the largest cluster.
    """
    if len(request.coordinates) < request.min_samples:
        return HotspotResponse(
            center_lat=None,
            center_lon=None,
            cluster_count=0,
            points_in_largest=0
        )

    # Convert to numpy array
    coords = np.array([[c['lat'], c['lon']] for c in request.coordinates])

    # Convert eps from km to approximate degrees (1 degree ≈ 111 km)
    eps_degrees = request.eps_km / 111.0

    # Run DBSCAN
    clustering = DBSCAN(
        eps=eps_degrees,
        min_samples=request.min_samples,
        metric='euclidean'  # Approximate for small areas
    )
    labels = clustering.fit_predict(coords)

    # Find unique clusters (excluding noise labeled as -1)
    unique_labels = set(labels)
    unique_labels.discard(-1)

    if not unique_labels:
        return HotspotResponse(
            center_lat=None,
            center_lon=None,
            cluster_count=0,
            points_in_largest=0
        )

    # Find the largest cluster
    cluster_sizes = {}
    for label in unique_labels:
        cluster_sizes[label] = np.sum(labels == label)

    largest_cluster = max(cluster_sizes, key=cluster_sizes.get)
    largest_mask = labels == largest_cluster
    largest_coords = coords[largest_mask]

    # Calculate centroid
    center_lat = float(np.mean(largest_coords[:, 0]))
    center_lon = float(np.mean(largest_coords[:, 1]))

    return HotspotResponse(
        center_lat=center_lat,
        center_lon=center_lon,
        cluster_count=len(unique_labels),
        points_in_largest=int(cluster_sizes[largest_cluster])
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
