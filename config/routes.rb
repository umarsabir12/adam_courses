Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "bundles#builder"
  get 'bundle', to: 'bundles#builder'
  
  resource :checkout, only: [:show, :create], controller: 'checkouts'

  get 'payments', to: 'payments#index'
  post 'payments/create_session', to: 'payments#create_session'

  resources :courses, only: [:index, :show] do
    collection do
      post :sync
    end
  end
  namespace :api do
    get 'catalog', to: 'catalog#index'
    post 'cart/price', to: 'cart#price'
    post 'cart/gifts', to: 'cart#gifts'
    post 'checkout/session', to: 'checkout#session'
    post 'upsell/show', to: 'upsell#show'
    post 'upsell/add', to: 'upsell#add'
  end
end
