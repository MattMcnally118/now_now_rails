Rails.application.routes.draw do
  # Animal Info feature
  resources :animals, only: [:index, :show]

  # Sightings Map feature
  resources :sightings, only: [:index] do
    collection do
      get :map_data
    end
  end

  # Activity Analysis feature
  resources :activities, only: [:index, :show], param: :animal_slug

  # Trip Planner feature
  resources :trips, only: [:index, :new, :create, :show]

  # Landing page
  root "home#index"

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
