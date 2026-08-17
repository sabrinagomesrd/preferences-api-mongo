# frozen_string_literal: true

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  get "health_check" => "health#show"

  namespace :v1 do
    namespace :preferences do
      get "raw", to: "raw#show"
      get "resolved", to: "resolved#show"

      put "singleton", to: "singletons#upsert"
      delete "singleton", to: "singletons#destroy"

      get "/", to: "multi#index"
      post "/", to: "multi#create"
      delete "/:id", to: "multi#destroy"
    end
  end
end
