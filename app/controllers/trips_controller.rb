class TripsController < ApplicationController
  def index
    @trips = Trip.includes(:animal).order(created_at: :desc).limit(20)
  end

  def new
    @trip = Trip.new
    @animals = Animal.order(:name)
  end

  def create
    @trip = Trip.new(trip_params)
    @animals = Animal.order(:name)

    # Geocode if place query provided
    if params[:place_query].present?
      coords = GeocodingService.geocode(params[:place_query])
      if coords
        @trip.start_latitude = coords[:lat]
        @trip.start_longitude = coords[:lon]
        @location_name = coords[:display_name]
      else
        flash.now[:alert] = "Could not find location: #{params[:place_query]}"
        render :new, status: :unprocessable_entity
        return
      end
    end

    # Calculate recommendation
    if @trip.valid?
      calculate_recommendation(@trip)
    end

    if @trip.save
      redirect_to @trip, notice: "Trip plan created!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @trip = Trip.includes(:animal).find(params[:id])
    @nearby_sightings = get_nearby_sightings(@trip)
  end

  private

  def trip_params
    params.require(:trip).permit(
      :animal_id, :start_latitude, :start_longitude,
      :radius_km, :target_month, :target_hour, :session_id
    )
  end

  def calculate_recommendation(trip)
    animal = Animal.find(trip.animal_id)

    # Get sightings within radius
    nearby_sightings = animal.sightings.select do |s|
      Sighting.haversine_km(trip.start_latitude, trip.start_longitude, s.latitude, s.longitude) <= trip.radius_km
    end

    if nearby_sightings.empty?
      trip.likelihood_score = 0
      trip.notes = ["No sightings found within #{trip.radius_km}km radius"]
      return
    end

    # Get hotspot from ML service
    coordinates = nearby_sightings.map { |s| { lat: s.latitude, lon: s.longitude } }
    hotspot = MlService.cluster_hotspots(coordinates, eps_km: trip.radius_km / 5.0, min_samples: 5)

    if hotspot[:center_lat] && hotspot[:center_lon]
      trip.recommended_latitude = hotspot[:center_lat]
      trip.recommended_longitude = hotspot[:center_lon]
    else
      # Use centroid of all sightings
      trip.recommended_latitude = nearby_sightings.map(&:latitude).sum / nearby_sightings.size
      trip.recommended_longitude = nearby_sightings.map(&:longitude).sum / nearby_sightings.size
    end

    # Get ML predictions for activity
    predictions = MlService.predict_activity(animal)
    grid = predictions[:grid] || []

    # Find max activity and best time from predictions
    max_activity = grid.map { |g| g[:predicted_activity] }.max || 1.0
    best_month = predictions[:best_month] || 6
    best_hour = predictions[:best_hour] || 7

    # Use user's target time or recommend the best
    target_month = trip.target_month.present? ? trip.target_month : best_month
    target_hour = trip.target_hour.present? ? trip.target_hour : best_hour

    # Store recommended time if user didn't specify
    trip.target_month ||= best_month
    trip.target_hour ||= best_hour

    # Find predicted activity for target time
    target_prediction = grid.find { |g| g[:month] == target_month && g[:hour] == target_hour }
    target_activity = target_prediction ? target_prediction[:predicted_activity] : (max_activity * 0.5)

    # Calculate ML-based likelihood score (percentage of optimal)
    ml_score = (target_activity / max_activity * 100).round

    # Apply confidence modifier based on sighting density
    sighting_count = nearby_sightings.size
    confidence_cap = if sighting_count < 50
      60  # Low confidence
    elsif sighting_count < 200
      85  # Medium confidence
    else
      100 # High confidence
    end

    trip.likelihood_score = [ml_score, confidence_cap].min

    # Store component scores for reference
    trip.temporal_score = ml_score / 100.0
    trip.spatial_score = [sighting_count.to_f / 200, 1.0].min

    # Generate notes
    notes = []
    notes << "Found #{sighting_count} #{animal.name} sightings within #{trip.radius_km}km"

    if trip.target_month.present? && trip.target_hour.present?
      time_str = "#{Date::MONTHNAMES[trip.target_month]} at #{format('%02d:00', trip.target_hour)}"
      notes << "Best viewing: #{time_str}"
    end

    if sighting_count < 50
      notes << "Limited data - confidence capped at 60%"
    elsif sighting_count < 200
      notes << "Moderate data - confidence capped at 85%"
    end

    trip.notes = notes
  end

  def get_nearby_sightings(trip)
    trip.animal.sightings.select do |s|
      Sighting.haversine_km(trip.start_latitude, trip.start_longitude, s.latitude, s.longitude) <= trip.radius_km
    end.first(100)
  end
end
