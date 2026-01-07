class Animal < ApplicationRecord
  has_one :animal_info, dependent: :destroy
  has_many :sightings, dependent: :destroy
  has_many :trips, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
  validates :label, presence: true, uniqueness: true

  # Knowledge base matching original Python app's ANIMAL_KNOWLEDGE
  KNOWLEDGE = {
    "lion" => {
      habitat: "Open savanna and light woodland; often near water in dry periods.",
      diet: "Carnivore – antelope, zebra, buffalo; will scavenge.",
      behavior_notes: "Social cats in prides; most hunting at dusk/dawn."
    },
    "elephant" => {
      habitat: "Savanna, forest edges, riverine zones – wide ranging.",
      diet: "Herbivore – grasses, leaves, bark, fruit; up to 150 kg/day.",
      behavior_notes: "Matriarchal herds; active day & night, rest midday."
    },
    "giraffe" => {
      habitat: "Open woodland and savanna with acacia trees.",
      diet: "Browser – mainly acacia leaves; long tongue avoids thorns.",
      behavior_notes: "Loose herds; most feeding early morning & late afternoon."
    },
    "zebra" => {
      habitat: "Grassland and open savanna; seasonal migrations.",
      diet: "Grazer – tall grasses; often first to graze, then wildebeest.",
      behavior_notes: "Harem groups; mutual grooming; active mostly daytime."
    },
    "cheetah" => {
      habitat: "Open savanna; avoids dense bush (needs run-up space).",
      diet: "Carnivore – small to medium antelope; hunts by day.",
      behavior_notes: "Solitary or small coalitions; rests during midday heat."
    },
    "hippopotamus" => {
      habitat: "Rivers, lakes, and wetlands – highly water-dependent.",
      diet: "Grazer – grasses at night; travels up to 10 km to pasture.",
      behavior_notes: "Territorial in water; nocturnal feeder; basks by day."
    },
    "warthog" => {
      habitat: "Savanna, grassland, and light woodland near water.",
      diet: "Omnivore – grasses, roots, bulbs, occasional carrion.",
      behavior_notes: "Diurnal; sleeps in burrows; kneels to graze."
    }
  }.freeze

  def record_count
    sightings.count
  end

  def range_span_km
    return 0 if sightings.empty?

    bounds = sightings.pluck(:latitude, :longitude)
    lats = bounds.map(&:first)
    lons = bounds.map(&:last)

    lat_span = lats.max - lats.min
    lon_span = lons.max - lons.min

    # Approximate km (1 degree ≈ 111 km at equator, less at higher latitudes)
    ((lat_span + lon_span) * 55).to_i
  end
end
