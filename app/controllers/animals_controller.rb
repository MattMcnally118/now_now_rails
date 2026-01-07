class AnimalsController < ApplicationController
  def index
    @animals = Animal.includes(:animal_info, :sightings).order(:name)
  end

  def show
    @animal = Animal.includes(:animal_info, :sightings).find_by!(slug: params[:id])
  end
end
