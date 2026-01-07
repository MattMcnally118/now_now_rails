class EnablePostgis < ActiveRecord::Migration[7.1]
  def change
    # PostGIS not needed - using Ruby-based Haversine calculations instead
    # This matches the original Python app's approach
  end
end
