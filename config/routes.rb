Rails.application.routes.draw do
  devise_for :users, controllers: { 
    registrations: 'users/registrations' 
  }
  
  root "pages#home"
  get "home", to: "pages#home"
  
  resources :movies
  resources :cinemas
  resources :halls
  resources :showtimes do
    collection do
      post :create_batch
    end
  end
  resources :workdays do
    member do
      patch :close
    end
  end
  resources :reports, only: [:index, :show, :update] do
    member do
      get :download
    end
  end
  resources :tickets, only: [:new, :create, :show, :edit, :update, :destroy]
  resources :users, path: 'staff'
  resources :products, only: [:index, :create, :destroy, :edit, :update] do
    collection do
      patch :bulk_update
    end
  end

  resources :forecasts, only: [:index, :show] do
    collection do
      post :run
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end