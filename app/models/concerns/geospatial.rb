module Geospatial
  extend ActiveSupport::Concern

  EARTH_RADIUS_KM = 6371.0

  class_methods do
    # Haversine formula for distance between two lat/lon points
    def haversine_km(lat1, lon1, lat2, lon2)
      lat1_rad = lat1 * Math::PI / 180
      lat2_rad = lat2 * Math::PI / 180
      delta_lat = (lat2 - lat1) * Math::PI / 180
      delta_lon = (lon2 - lon1) * Math::PI / 180

      a = Math.sin(delta_lat / 2)**2 +
          Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(delta_lon / 2)**2
      c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

      EARTH_RADIUS_KM * c
    end

    # Filter records within radius (in km) of a point
    # Uses bounding box for efficiency, then filters with Haversine
    def within_radius(lat, lon, radius_km)
      # Approximate bounding box (1 degree ≈ 111 km)
      lat_delta = radius_km / 111.0
      lon_delta = radius_km / (111.0 * Math.cos(lat * Math::PI / 180))

      where(
        latitude: (lat - lat_delta)..(lat + lat_delta),
        longitude: (lon - lon_delta)..(lon + lon_delta)
      ).select do |record|
        haversine_km(lat, lon, record.latitude, record.longitude) <= radius_km
      end
    end

    # Bounding box filter (faster, for map views)
    def within_bounds(south, north, west, east)
      where(latitude: south..north, longitude: west..east)
    end
  end

  # Instance method to calculate distance from a point
  def distance_from(lat, lon)
    self.class.haversine_km(lat, lon, latitude, longitude)
  end
end
