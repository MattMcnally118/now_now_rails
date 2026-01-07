namespace :sightings do
  desc "Import wildlife sightings from CSV and seed animal data"
  task import: :environment do
    require "csv"

    puts "Starting import..."

    # Create animals first
    animal_map = {}
    Animal::KNOWLEDGE.each_with_index do |(slug, knowledge), idx|
      puts "  Creating animal: #{slug.titleize}..."

      animal = Animal.find_or_create_by!(slug: slug) do |a|
        a.name = slug.titleize
        a.label = idx
      end

      # Create animal info from knowledge base
      AnimalInfo.find_or_create_by!(animal: animal) do |info|
        info.habitat = knowledge[:habitat]
        info.diet = knowledge[:diet]
        info.behavior_notes = knowledge[:behavior_notes]
        info.image_path = "animals/#{slug}.jpg"
        info.icon_path = "animals/#{slug}-icon.png"
      end

      # Map various name formats to animal
      animal_map[slug.titleize] = animal
      animal_map[slug.capitalize] = animal
      animal_map[slug] = animal
    end

    puts "Created #{Animal.count} animals with info"

    # Import sightings from CSV
    csv_path = Rails.root.join("data", "animals_temp.csv")

    unless File.exist?(csv_path)
      puts "ERROR: CSV file not found at #{csv_path}"
      exit 1
    end

    puts "Importing sightings from #{csv_path}..."

    count = 0
    errors = 0

    Sighting.transaction do
      CSV.foreach(csv_path, headers: true).each_slice(1000) do |batch|
        sightings_to_insert = []

        batch.each do |row|
          # Normalize animal group name
          animal_group = row["animal_group"]&.downcase
          animal = animal_map[animal_group]

          unless animal
            errors += 1
            next
          end

          # Parse datetime
          datetime = begin
            DateTime.parse(row["datetime"])
          rescue
            nil
          end

          next unless datetime

          sightings_to_insert << {
            external_id: row["id"].to_i,
            animal_id: animal.id,
            common_name: row["common name"],
            latitude: row["latitude"].to_f,
            longitude: row["longitude"].to_f,
            observed_at: datetime,
            hour: row["hour"].to_i,
            day: row["day"].to_i,
            month: row["month"].to_i,
            season: row["season"],
            ndvi: row["NDVI_mean"].presence&.to_f,
            distance_to_water_km: row["distance_to_water_km_comprehensive"].presence&.to_f,
            near_water: row["near_water"] == "1",
            temperature_c: row["temperature_C"].presence&.to_f,
            hour_sin: row["hour_sin"].presence&.to_f,
            hour_cos: row["hour_cos"].presence&.to_f,
            created_at: Time.current,
            updated_at: Time.current
          }

          count += 1
        end

        # Bulk insert for performance
        Sighting.insert_all(sightings_to_insert) if sightings_to_insert.any?
        print "."
      end
    end

    puts ""
    puts "Import complete!"
    puts "  Sightings imported: #{Sighting.count}"
    puts "  Skipped (errors): #{errors}"

    # Show summary by animal
    puts ""
    puts "Sightings by animal:"
    Animal.includes(:sightings).find_each do |animal|
      puts "  #{animal.name}: #{animal.sightings.count} records"
    end
  end

  desc "Clear all sightings data"
  task clear: :environment do
    puts "Clearing all sightings..."
    Sighting.delete_all
    puts "Done. #{Sighting.count} sightings remaining."
  end
end
