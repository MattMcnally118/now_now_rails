class CreateTrips < ActiveRecord::Migration[7.1]
  def change
    create_table :trips do |t|
      t.string :session_id
      t.references :animal, null: false, foreign_key: true
      t.decimal :start_latitude, precision: 10, scale: 7, null: false
      t.decimal :start_longitude, precision: 10, scale: 7, null: false
      t.integer :radius_km, null: false
      t.integer :target_month
      t.integer :target_hour
      t.decimal :recommended_latitude, precision: 10, scale: 7
      t.decimal :recommended_longitude, precision: 10, scale: 7
      t.integer :likelihood_score
      t.decimal :temporal_score, precision: 5, scale: 4
      t.decimal :spatial_score, precision: 5, scale: 4
      t.text :notes, array: true, default: []

      t.timestamps
    end

    add_index :trips, :session_id
  end
end
