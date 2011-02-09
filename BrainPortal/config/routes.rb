ActionController::Routing::Routes.draw do |map|

  # Session
  map.resource  :session

  # Control channel
  map.resources :controls,                        :controller => :controls

  # Standard CRUD resources
  map.resources :sites
  map.resources :custom_filters
  map.resources :tool_configs
  map.resources :user_preferences
  map.resources :tags
  map.resources :statistics

  # Standard CRUD resources, with extra methods
  map.resources :feedbacks,      :collection => { :delete_feedback => :delete }

  map.resources :messages,       :collection => { :delete_messages => :delete }

  map.resources :users,          :member     => { :switch           => :post },
                                 :collection => { :request_password => :get,
                                                  :send_password    => :post }

  map.resources :groups,         :member     => { :switch           => :post }

  map.resources :bourreaux,      :member     => { :start => :post, :stop => :post, :row_data  => :get },
                                 :collection => { :refresh_ssh_keys => :post } 

  map.resources :data_providers, :member     => { :browse  => :get,  :register   => :post, :is_alive => :get },
                                 :collection => { :cleanup => :post, :disk_usage => :get }

  map.resources :userfiles,      :member     => { :content => :get, :display  => :get, :sync_to_cache => :post, :extract_from_collection  => :post }, 
                                 :collection => { :download             => :get,
                                                  :new_parent_child     => :get,
                                                  :create_parent_child  => :post,
                                                  :delete_files         => :delete, 
                                                  :create_collection    => :post,
                                                  :update_multiple      => :put,  
                                                  :change_provider      => :post, 
                                                  :compress             => :post,
                                                  :quality_control      => :post,
                                                  :manage_persistent    => :post,
                                                  :sync_multiple        => :post }
  
  map.resources :tasks,          :collection => { :new => :post, :operation => :post }
  
  map.resources :tools,          :collection => { :bourreau_select  => :get, :tool_management => :get, :assign_tools => :post, :delete_tools => :delete }

  # Special named routes
  map.home             '/home',                   :controller => 'portal',   :action => 'welcome'
  map.information      '',                        :controller => 'portal',   :action => 'credits'
  map.about_us         '/about_us',               :controller => 'portal',   :action => 'about_us'
  map.login            '/login',                  :controller => 'sessions', :action => 'new'
  map.session_status   '/session_status',         :controller => 'sessions', :action => 'show'
  map.logout           '/logout',                 :controller => 'sessions', :action => 'destroy'
  map.jiv              '/jiv',                    :controller => 'jiv',      :action => 'index'
  map.jiv_display      '/jiv/show',               :controller => 'jiv',      :action => 'show'
  
  # Individual maps
  map.connect "logged_exceptions/:action/:id",    :controller => "logged_exceptions" 

end
