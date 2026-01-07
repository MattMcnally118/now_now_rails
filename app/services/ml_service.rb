class MlService
  BASE_URL = ENV.fetch("ML_SERVICE_URL", "http://localhost:8000")

  class << self
    def predict_activity(animal)
      sightings = animal.sightings.limit(2000)

      payload = {
        animal_id: animal.id,
        sightings: sightings.map { |s|
          {
            hour: s.hour,
            month: s.month,
            ndvi: s.ndvi&.to_f,
            temperature_c: s.temperature_c&.to_f
          }
        }
      }

      response = connection.post("/api/v1/predict/activity", payload)

      if response.success?
        response.body.deep_symbolize_keys
      else
        Rails.logger.error("ML Service error: #{response.status} - #{response.body}")
        fallback_predictions
      end
    rescue Faraday::Error => e
      Rails.logger.error("ML Service connection error: #{e.message}")
      fallback_predictions
    end

    def gmm_curve(animal, month)
      sightings = animal.sightings.limit(2000)

      payload = {
        animal_id: animal.id,
        month: month,
        sightings: sightings.map { |s|
          {
            hour: s.hour,
            month: s.month,
            ndvi: s.ndvi&.to_f,
            temperature_c: s.temperature_c&.to_f
          }
        }
      }

      response = connection.post("/api/v1/predict/gmm-curve", payload)

      if response.success?
        response.body.deep_symbolize_keys
      else
        fallback_gmm_curve
      end
    rescue Faraday::Error => e
      Rails.logger.error("ML Service connection error: #{e.message}")
      fallback_gmm_curve
    end

    def cluster_hotspots(coordinates, eps_km: 10.0, min_samples: 10)
      payload = {
        coordinates: coordinates.map { |c| { lat: c[:lat], lon: c[:lon] } },
        eps_km: eps_km,
        min_samples: min_samples
      }

      response = connection.post("/api/v1/cluster/hotspots", payload)

      if response.success?
        response.body.deep_symbolize_keys
      else
        { center_lat: nil, center_lon: nil, cluster_count: 0, points_in_largest: 0 }
      end
    rescue Faraday::Error => e
      Rails.logger.error("ML Service connection error: #{e.message}")
      { center_lat: nil, center_lon: nil, cluster_count: 0, points_in_largest: 0 }
    end

    def health_check
      response = connection.get("/api/v1/health")
      response.success?
    rescue Faraday::Error
      false
    end

    private

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.request :json
        f.response :json
        f.adapter Faraday.default_adapter
        f.options.timeout = 30
      end
    end

    def fallback_predictions
      # Return fallback data when ML service is unavailable
      {
        best_month: 6,
        best_hour: 7,
        grid: (1..12).flat_map { |m| (0..23).map { |h| { month: m, hour: h, predicted_activity: 1.0 } } },
        r2_score: 0.0,
        error: "ML service unavailable - showing fallback data"
      }
    end

    def fallback_gmm_curve
      {
        hours: (0..23).to_a,
        probabilities: Array.new(24, 1.0/24),
        error: "ML service unavailable - showing uniform distribution"
      }
    end
  end
end
