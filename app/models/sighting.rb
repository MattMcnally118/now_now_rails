class Sighting < ApplicationRecord
  include Geospatial

  belongs_to :animal

  validates :latitude, presence: true, numericality: { in: -90..90 }
  validates :longitude, presence: true, numericality: { in: -180..180 }
  validates :observed_at, presence: true
  validates :hour, presence: true, inclusion: { in: 0..23 }
  validates :month, presence: true, inclusion: { in: 1..12 }
  validates :day, presence: true, inclusion: { in: 1..31 }
  validates :season, presence: true, inclusion: { in: %w[dry wet] }

  scope :for_animal, ->(animal_id) { where(animal_id: animal_id) }
  scope :for_month, ->(month) { where(month: month) }
  scope :for_hour, ->(hour) { where(hour: hour) }
  scope :for_season, ->(season) { where(season: season) }

  # For map JSON serialization
  def as_map_json
    {
      lat: latitude.to_f,
      lon: longitude.to_f,
      animal: animal.name,
      species: common_name,
      datetime: observed_at&.iso8601,
      ndvi: ndvi&.round(2),
      temp: temperature_c&.round(1),
      dist_water: distance_to_water_km&.round(2)
    }
  end
end
