class ActivitiesController < ApplicationController
  def index
    @animals = Animal.order(:name)
    @selected_animal = @animals.first
  end

  def show
    @animals = Animal.order(:name)
    @selected_animal = Animal.find_by!(slug: params[:animal_slug])

    # Get activity statistics from database
    @hourly_counts = @selected_animal.sightings
      .group(:hour)
      .count
      .transform_keys(&:to_i)

    @monthly_counts = @selected_animal.sightings
      .group(:month)
      .count
      .transform_keys(&:to_i)

    # Try to get ML predictions (fallback if service unavailable)
    @predictions = MlService.predict_activity(@selected_animal)
    @best_month = @predictions[:best_month]
    @best_hour = @predictions[:best_hour]

    # Get GMM curve for best month
    @gmm_curve = MlService.gmm_curve(@selected_animal, @best_month)
  end
end
