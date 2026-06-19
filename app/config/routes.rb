Rails.application.routes.draw do
  root "tests#index"

  get    "/login",                   to: "sessions#new",    as: :login
  get    "/auth/:provider/callback", to: "sessions#create"
  post   "/auth/:provider/callback", to: "sessions#create"
  delete "/logout",                  to: "sessions#destroy", as: :logout

  resources :tests, only: [:index, :show], param: :slug do
    resource :run, only: [:new, :create, :show], controller: "runs"
  end

  get "/dashboard", to: "dashboard#index", as: :dashboard
  get "/stats",     to: "stats#index",     as: :stats

  get "up" => "rails/health#show", as: :rails_health_check
end
