class CreateSightings < ActiveRecord::Migration[7.1]
  def change
    create_table :sightings do |t|
      t.integer :external_id
      t.references :animal, null: false, foreign_key: true
      t.string :common_name
      t.decimal :latitude, precision: 10, scale: 7, null: false
      t.decimal :longitude, precision: 10, scale: 7, null: false
      t.datetime :observed_at, null: false
      t.integer :hour, null: false
      t.integer :day, null: false
      t.integer :month, null: false
      t.string :season, null: false
      t.decimal :ndvi, precision: 6, scale: 4
      t.decimal :distance_to_water_km, precision: 10, scale: 4
      t.boolean :near_water, default: false
      t.decimal :temperature_c, precision: 5, scale: 2
      t.decimal :hour_sin, precision: 10, scale: 8
      t.decimal :hour_cos, precision: 10, scale: 8

      t.timestamps
    end

    add_index :sightings, [:latitude, :longitude]
    add_index :sightings, :observed_at
    add_index :sightings, [:month, :hour]
    add_index :sightings, :ndvi, where: 'ndvi IS NOT NULL'
  end
end
