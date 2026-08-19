Rails.application.routes.draw do
  root "tests#index"

  get    "/login",                   to: "sessions#new",    as: :login
  get    "/auth/:provider/callback", to: "sessions#create"
  post   "/auth/:provider/callback", to: "sessions#create"
  get    "/auth/failure",            to: "sessions#failure"
  delete "/logout",                  to: "sessions#destroy", as: :logout

  resources :tests, only: [ :index, :show ], param: :slug do
    resources :runs, only: [ :show ], controller: "runs"
    resource :run, only: [ :new, :create ], controller: "runs"
    resources :attempts, only: [ :index ], controller: "test_attempts"
  end

  # Разовое прохождение теста из перетащенного файла: без записи в БД.
  post   "/preview",       to: "previews#create", as: :preview
  post   "/preview/grade", to: "previews#grade",  as: :preview_grade
  # Тест живёт только в теле POST-запроса, восстановить его по GET не из чего.
  # Сюда попадают перезагрузкой страницы прохождения — возвращаем на список.
  get    "/preview",       to: "previews#show"

  get    "/settings/tags",    to: "preferences#edit",   as: :settings_tags
  patch  "/preferences/tags", to: "preferences#update", as: :preferences_tags

  post   "/bookmarks",     to: "bookmarks#create"
  delete "/bookmarks",     to: "bookmarks#destroy"

  get "/dashboard", to: "dashboard#index", as: :dashboard
  get "/stats",     to: "stats#index",     as: :stats

  get "up" => "rails/health#show", as: :rails_health_check
end
