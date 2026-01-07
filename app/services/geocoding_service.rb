class GeocodingService
  NOMINATIM_URL = "https://nominatim.openstreetmap.org"

  class << self
    def geocode(query)
      return nil if query.blank?

      response = connection.get("/search") do |req|
        req.params["q"] = query
        req.params["format"] = "json"
        req.params["limit"] = 1
      end

      return nil unless response.success?

      data = JSON.parse(response.body)
      return nil if data.empty?

      {
        lat: data[0]["lat"].to_f,
        lon: data[0]["lon"].to_f,
        display_name: data[0]["display_name"]
      }
    rescue Faraday::Error => e
      Rails.logger.error("Geocoding error: #{e.message}")
      nil
    end

    def reverse_geocode(lat, lon)
      response = connection.get("/reverse") do |req|
        req.params["lat"] = lat
        req.params["lon"] = lon
        req.params["format"] = "json"
        req.params["zoom"] = 14
      end

      return nil unless response.success?

      data = JSON.parse(response.body)
      data["display_name"]
    rescue Faraday::Error => e
      Rails.logger.error("Reverse geocoding error: #{e.message}")
      nil
    end

    private

    def connection
      @connection ||= Faraday.new(url: NOMINATIM_URL) do |f|
        f.headers["User-Agent"] = "NowNowWildlifeFinder/1.0 (Rails)"
        f.adapter Faraday.default_adapter
        f.options.timeout = 10
      end
    end
  end
end
