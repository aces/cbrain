
# CBRAIN Routing Table

CbrainRailsPortal::Application.routes.draw do

  # Session
  resource  :session

  # Control channel
  resources :controls,       :controller => :controls

  # Standard CRUD resources
  resources :sites
  resources :custom_filters
  resources :tool_configs
  resources :tags

  # Standard CRUD resources, with extra methods

  resources :feedbacks do
    collection do
      delete 'delete_feedback'
    end
  end

  resources :messages do
    collection do
      delete 'delete_messages'
    end
  end

  resources :users do
    member do
      post 'switch'
    end
    collection do
      get  'request_password'
      post 'send_password'
    end
  end

  resources :groups do
    member do
      get 'switch'
    end
  end

  resources :bourreaux do
    member do
      post 'start'
      post 'stop'
      get  'row_data'
    end
    collection do
      post 'refresh_ssh_keys'
      get  'load_info'
    end
  end

  resources :data_providers do
    member do
      get  'browse'
      post 'register'
      get  'is_alive'
    end
    collection do
      post 'cleanup'
      get  'disk_usage'
    end
  end

  resources :userfiles do
    member do
      get  'content'
      get  'display'
      post 'sync_to_cache'
      post 'extract_from_collection'
    end
    collection do
      get    'download'
      get    'new_parent_child'
      post   'create_parent_child'
      delete 'delete_files'
      post   'create_collection'
      put    'update_multiple'
      post   'change_provider'
      post   'compress'
      post   'quality_control'
      post   'quality_control_panel'
      post   'manage_persistent'
      post   'sync_multiple'
    end
  end

  resources :tasks do
    collection do
      post 'new'
      post 'operation'
      get  'batch_list'
    end
  end

  resources :tools do
    collection do
      get    'bourreau_select'
      get    'tool_management'
      post   'assign_tools'
    end
  end

  # Special named routes
  match                 '/home'           => 'portal#welcome'
  match                 ''                => 'portal#credits'
  match                 '/about_us'       => 'portal#about_us'
  match                 '/login'          => 'sessions#new'
  match                 '/session_status' => 'sessions#show'
  match                 '/logout'         => 'sessions#destroy'
  match                 '/jiv'            => 'jiv#index'
  match                 '/jiv/show'       => 'jiv#show'
  
  # Individual maps
  match "logged_exceptions/:action/:id", :controller => "logged_exceptions" 

end

# 
# 
# Nana::Application.routes.draw do
#   # The priority is based upon order of creation:
#   # first created -> highest priority.
# 
#   # Sample of regular route:
#   #   match 'products/:id' => 'catalog#view'
#   # Keep in mind you can assign values other than :controller and :action
# 
#   # Sample of named route:
#   #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
#   # This route can be invoked with purchase_url(:id => product.id)
# 
#   # Sample resource route (maps HTTP verbs to controller actions automatically):
#   #   resources :products
# 
#   # Sample resource route with options:
#   #   resources :products do
#   #     member do
#   #       get 'short'
#   #       post 'toggle'
#   #     end
#   #
#   #     collection do
#   #       get 'sold'
#   #     end
#   #   end
# 
#   # Sample resource route with sub-resources:
#   #   resources :products do
#   #     resources :comments, :sales
#   #     resource :seller
#   #   end
# 
#   # Sample resource route with more complex sub-resources
#   #   resources :products do
#   #     resources :comments
#   #     resources :sales do
#   #       get 'recent', :on => :collection
#   #     end
#   #   end
# 
#   # Sample resource route within a namespace:
#   #   namespace :admin do
#   #     # Directs /admin/products/* to Admin::ProductsController
#   #     # (app/controllers/admin/products_controller.rb)
#   #     resources :products
#   #   end
# 
#   # You can have the root of your site routed with "root"
#   # just remember to delete public/index.html.
#   # root :to => "welcome#index"
# 
#   # See how all your routes lay out with "rake routes"
# 
#   # This is a legacy wild controller route that's not recommended for RESTful applications.
#   # Note: This route will make all actions in every controller accessible via GET requests.
#   # match ':controller(/:action(/:id(.:format)))'
# end
# 
