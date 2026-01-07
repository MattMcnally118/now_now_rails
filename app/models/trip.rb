class Trip < ApplicationRecord
  belongs_to :animal

  validates :start_latitude, presence: true, numericality: { in: -90..90 }
  validates :start_longitude, presence: true, numericality: { in: -180..180 }
  validates :radius_km, presence: true, numericality: { greater_than: 0 }
  validates :target_month, inclusion: { in: 1..12 }, allow_nil: true
  validates :target_hour, inclusion: { in: 0..23 }, allow_nil: true
  validates :likelihood_score, inclusion: { in: 0..100 }, allow_nil: true

  # Month names for display
  MONTHS = %w[January February March April May June July August September October November December].freeze

  def target_month_name
    MONTHS[target_month - 1] if target_month
  end

  def formatted_hour
    return nil unless target_hour
    format("%02d:00", target_hour)
  end
end
