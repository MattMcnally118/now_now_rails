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

    # Calculate temporal score
    temporal_score = 0.0
    if trip.target_month.present?
      month_matches = nearby_sightings.count { |s| s.month == trip.target_month }
      temporal_score += month_matches.to_f / nearby_sightings.size * 0.5
    end
    if trip.target_hour.present?
      hour_matches = nearby_sightings.count { |s| s.hour == trip.target_hour }
      temporal_score += hour_matches.to_f / nearby_sightings.size * 0.5
    end
    temporal_score = 0.5 if trip.target_month.blank? && trip.target_hour.blank?

    # Calculate spatial score based on density
    spatial_score = [nearby_sightings.size.to_f / 100, 1.0].min

    trip.temporal_score = temporal_score
    trip.spatial_score = spatial_score

    # Combined likelihood (70% temporal, 30% spatial like original app)
    trip.likelihood_score = ((temporal_score * 0.7 + spatial_score * 0.3) * 100).round

    # Generate notes
    notes = []
    notes << "Found #{nearby_sightings.size} #{animal.name} sightings within #{trip.radius_km}km"

    if hotspot[:cluster_count] > 0
      notes << "#{hotspot[:cluster_count]} activity clusters detected, largest has #{hotspot[:points_in_largest]} sightings"
    end

    if trip.target_month.present?
      month_sightings = nearby_sightings.count { |s| s.month == trip.target_month }
      notes << "#{month_sightings} sightings in #{Date::MONTHNAMES[trip.target_month]}"
    end

    trip.notes = notes
  end

  def get_nearby_sightings(trip)
    trip.animal.sightings.select do |s|
      Sighting.haversine_km(trip.start_latitude, trip.start_longitude, s.latitude, s.longitude) <= trip.radius_km
    end.first(100)
  end
end
