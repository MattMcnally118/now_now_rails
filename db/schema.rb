# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_01_06_100751) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "animal_infos", force: :cascade do |t|
    t.bigint "animal_id", null: false
    t.text "habitat"
    t.text "diet"
    t.text "behavior_notes"
    t.string "image_path"
    t.string "icon_path"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["animal_id"], name: "index_animal_infos_on_animal_id"
  end

  create_table "animals", force: :cascade do |t|
    t.string "name"
    t.string "slug"
    t.integer "label"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["label"], name: "index_animals_on_label", unique: true
    t.index ["slug"], name: "index_animals_on_slug", unique: true
  end

  create_table "sightings", force: :cascade do |t|
    t.integer "external_id"
    t.bigint "animal_id", null: false
    t.string "common_name"
    t.decimal "latitude", precision: 10, scale: 7, null: false
    t.decimal "longitude", precision: 10, scale: 7, null: false
    t.datetime "observed_at", null: false
    t.integer "hour", null: false
    t.integer "day", null: false
    t.integer "month", null: false
    t.string "season", null: false
    t.decimal "ndvi", precision: 6, scale: 4
    t.decimal "distance_to_water_km", precision: 10, scale: 4
    t.boolean "near_water", default: false
    t.decimal "temperature_c", precision: 5, scale: 2
    t.decimal "hour_sin", precision: 10, scale: 8
    t.decimal "hour_cos", precision: 10, scale: 8
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["animal_id"], name: "index_sightings_on_animal_id"
    t.index ["latitude", "longitude"], name: "index_sightings_on_latitude_and_longitude"
    t.index ["month", "hour"], name: "index_sightings_on_month_and_hour"
    t.index ["ndvi"], name: "index_sightings_on_ndvi", where: "(ndvi IS NOT NULL)"
    t.index ["observed_at"], name: "index_sightings_on_observed_at"
  end

  create_table "trips", force: :cascade do |t|
    t.string "session_id"
    t.bigint "animal_id", null: false
    t.decimal "start_latitude", precision: 10, scale: 7, null: false
    t.decimal "start_longitude", precision: 10, scale: 7, null: false
    t.integer "radius_km", null: false
    t.integer "target_month"
    t.integer "target_hour"
    t.decimal "recommended_latitude", precision: 10, scale: 7
    t.decimal "recommended_longitude", precision: 10, scale: 7
    t.integer "likelihood_score"
    t.decimal "temporal_score", precision: 5, scale: 4
    t.decimal "spatial_score", precision: 5, scale: 4
    t.text "notes", default: [], array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["animal_id"], name: "index_trips_on_animal_id"
    t.index ["session_id"], name: "index_trips_on_session_id"
  end

  add_foreign_key "animal_infos", "animals"
  add_foreign_key "sightings", "animals"
  add_foreign_key "trips", "animals"
end
