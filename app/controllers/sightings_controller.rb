class SightingsController < ApplicationController
  def index
    @render_mode = params[:mode] || "markers"
    @animals = Animal.order(:name)
  end

  def map_data
    sightings = filtered_sightings.includes(:animal)

    render json: sightings.map(&:as_map_json)
  end

  private

  def filtered_sightings
    scope = Sighting.all

    # Filter by animal if specified
    if params[:animal_id].present?
      scope = scope.for_animal(params[:animal_id])
    end

    # Filter by bounding box if specified
    if params[:bounds].present?
      bounds = JSON.parse(params[:bounds])
      scope = scope.within_bounds(
        bounds["south"].to_f,
        bounds["north"].to_f,
        bounds["west"].to_f,
        bounds["east"].to_f
      )
    end

    scope
  end
end
