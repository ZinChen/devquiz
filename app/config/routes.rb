Rails.application.routes.draw do
  root "tests#index"

  get    "/login",                   to: "sessions#new",    as: :login
  get    "/auth/:provider/callback", to: "sessions#create"
  post   "/auth/:provider/callback", to: "sessions#create"
  delete "/logout",                  to: "sessions#destroy", as: :logout

  resources :tests, only: [ :index, :show ], param: :slug do
    resources :runs, only: [ :show ], controller: "runs"
    resource :run, only: [ :new, :create ], controller: "runs"
    resources :attempts, only: [ :index ], controller: "test_attempts"
  end

  post   "/bookmarks",     to: "bookmarks#create"
  delete "/bookmarks",     to: "bookmarks#destroy"

  get "/dashboard", to: "dashboard#index", as: :dashboard
  get "/stats",     to: "stats#index",     as: :stats

  get "up" => "rails/health#show", as: :rails_health_check
end
