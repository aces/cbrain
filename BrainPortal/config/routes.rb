ActionController::Routing::Routes.draw do |map|
  map.resources :tools,          :collection => { :bourreau_select  => :get, :tool_management => :get, :assign_tools => :post, :delete_tools => :delete }

  map.resources :statistics

  # Session
  map.resource  :session

  # Control channel
  map.resources :controls,                :controller => :controls

  # Standard CRUD resources
  map.resources :sites
  map.resources :custom_filters
  map.resources :user_preferences
  map.resources :feedbacks,      :collection => { :delete_feedback => :delete }
  map.resources :tags
  map.resources :messages,       :collection => { :delete_messages => :delete }

  # Standard CRUD resources, with extra methods
  map.resources :users,          :member => { :switch  => :post }, :collection  => {:request_password  => :get, :send_password  => :post }
  map.resources :groups,         :member => { :switch  => :post }
  map.resources :bourreaux,      :member => { :start   => :post, :stop => :post, :row_data  => :get }, :collection  => { :refresh_ssh_keys  => :post } 
  map.resources :data_providers, :member => { :browse  => :get, :register => :post}, :collection => { :cleanup => :post, :disk_usage  => :get, :is_alive  => :get }
  map.resources :userfiles,      :member => { :content => :get, :sync_to_cache  => :post, :extract_from_collection  => :post }, 
                                 :collection => { :download => :get, 
                                                  :delete_files  => :delete, 
                                                  :create_collection  => :post,
                                                  :update_multiple  => :put,
                                                  :change_provider  => :post}

  # Redirect for polymorphisms
  map.resources :single_files,            :controller => :userfiles  
  map.resources :file_collection,         :controller => :userfiles  
  map.resources :civet_collection,        :controller => :userfiles  
  map.resources :civet_study,             :controller => :userfiles  
  map.resources :macacc_collection,       :controller => :userfiles

  map.resources :work_groups,             :controller => :groups     
  map.resources :system_groups,           :controller => :groups     
  map.resources :userfile_custom_filters, :controller => :custom_filters
  map.resources :task_custom_filters,     :controller => :custom_filters

  # Special named routes
  map.home        '/home',                :controller => 'portal',   :action => 'welcome'
  map.information '',                     :controller => 'portal',   :action => 'credits'
  map.about_us    '/about_us',            :controller => 'portal',   :action => 'about_us'
  map.signup      '/signup',              :controller => 'users',    :action => 'new'
  map.login       '/login',               :controller => 'sessions', :action => 'new'
  map.logout      '/logout',              :controller => 'sessions', :action => 'destroy'
  map.jiv         '/jiv',                 :controller => 'jiv',      :action => 'index'
  map.jiv_display '/jiv/show',            :controller => 'jiv',      :action => 'show'
  
  # Individual maps
  map.connect 'tasks/:action',                  :controller => 'tasks'
  map.connect 'tasks/:action/:id',              :controller => 'tasks'
  map.connect "logged_exceptions/:action/:id",  :controller => "logged_exceptions" 

  # The priority is based upon order of creation: first created -> highest priority.

  # Sample of regular route:
  #   map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   map.resources :products

  # Sample resource route with options:
  #   map.resources :products, :member => { :short => :get, :toggle => :post }, :collection => { :sold => :get }

  # Sample resource route with sub-resources:
  #   map.resources :products, :has_many => [ :comments, :sales ], :has_one => :seller
  
  # Sample resource route with more complex sub-resources
  #   map.resources :products do |products|
  #     products.resources :comments
  #     products.resources :sales, :collection => { :recent => :get }
  #   end

  # Sample resource route within a namespace:
  #   map.namespace :admin do |admin|
  #     # Directs /admin/products/* to Admin::ProductsController (app/controllers/admin/products_controller.rb)
  #     admin.resources :products
  #   end

  # You can have the root of your site routed with map.root -- just remember to delete public/index.html.
  # map.root :controller => "welcome"

  # See how all your routes lay out with "rake routes"

  # Install the default routes as the lowest priority.
  # Note: These default routes make all actions in every controller accessible via GET requests. You should
  # consider removing the them or commenting them out if you're using named routes and resources.
  #map.connect ':controller/:action/:id'
  #map.connect ':controller/:action/:id.:format'
end
