
#
# CBRAIN Project
#
# Copyright (C) 2008-2023
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# CBRAIN Routing Table

Rails.application.routes.draw do

  # Session
  resource  :session,         :only => [ :new, :create, :show, :destroy ]

  # Control channel
  resources :controls,        :only => [ :show, :create ], :controller => :controls

  # Documentation
  resources :docs,            :except => [ :edit ], :controller => :help_documents

  # ResourceUsage
  resources :resource_usage,  :only => [ :index ]

  # Standard CRUD resources
  resources :sites,           :except => [ :edit ]
  resources :custom_filters,  :except => [ :index ]
  resources :tags,            :except => [ :new, :edit ]
  resources :access_profiles, :except => [ :edit ]
  resources :disk_quotas,     :only   => [ :new, :index, :show, :create, :destroy, :update ] do
    collection do
      get 'report'
    end
  end

  # Standard CRUD resources, with extra actions

  resources :tool_configs, :except => [ :edit ] do
    collection do
      get  'report'
    end
    member do
      get  'boutiques_descriptor'
    end
  end

  resources :messages,        :except => [ :edit, :show ] do
    collection do
      delete 'delete_messages'
    end
  end

  resources :users,           :except => [ :edit ] do
    member do
      get  'change_password'
      post 'switch'
      put  'push_keys'
    end
    collection do
      get  'request_password'
      post 'send_password'
      post 'new_token'
    end
  end

  resources :groups,          :except => [ :edit ] do
    collection do
      post 'unregister'
      post 'switch'
      get 'switch'
    end
  end

  resources :invitations,     :only => [ :new, :create, :update, :destroy ]

  resources :bourreaux,       :except => [ :edit ] do
    member do
      post 'start'
      post 'stop'
      get  'row_data'
      get  'info'
      get  'cache_disk_usage'
    end
    collection do
      get  'load_info'
      get  'rr_disk_usage'
      get  'rr_access'
      post 'cleanup_caches'
      get  'rr_access_dp'
    end
  end

  resources :data_providers,  :except => [ :edit ] do
    member do
      get  'browse'
      post 'register'
      post 'unregister'
      post 'delete'
      get  'is_alive'
      get  'disk_usage'
      get  'report'
      post 'report'
      post 'repair'
      post 'check_personal'
    end
    collection do
      get  'dp_access'
      get  'dp_transfers'
      get  'new_personal'
      post 'create_personal'
    end
  end

  resources :userfiles,       :except => [ :edit, :destroy ] do
    member do
      get  'content'
      get  'stream/*file_path' => 'userfiles#stream'
      get  'display'
      post 'extract_from_collection'
    end
    collection do
      post   'download'
      get    'download'
      get    'new_parent_child'
      post   'create_parent_child'
      delete 'delete_files'
      post   'create_collection'
      put    'update_multiple'
      post   'change_provider'
      post   'compress'
      post   'uncompress'
      post   'quality_control'
      post   'quality_control_panel'
      post   'sync_multiple'
      post   'detect_file_type'
      post   'export_file_list'
    end
  end

  resources :tasks, :except => [ :destroy ] do
    member do
      get  'zenodo'
      post 'create_zenodo'
      post 'reset_zenodo'
    end
    collection do
      post 'new', :as => 'new', :via => 'new'
      post 'operation'
      get  'batch_list'
      post 'update_multiple'
    end
  end

  resources :tools do
    collection do
      get    'tool_config_select'
    end
  end

  resources :exception_logs,  :only => [ :index, :show ] do
    delete :destroy, :on => :collection
  end

  resources :signups do
    member do
      post 'resend_confirm'
      get  'confirm'
    end
    collection do
      post 'multi_action'
    end
  end

  resources :nh_signups do
    member do
      get  'confirm'
    end
    collection do
      post 'multi_action'
    end
  end

  # Special named routes
  root  :to                       => 'portal#welcome'
  get   '/home'                   => 'portal#welcome'
  post  '/home'                   => 'portal#welcome' # lock/unlock service
  get   '/credits'                => 'portal#credits'
  get   '/about_us'               => 'portal#about_us'
  get   '/available'              => 'portal#available'
  get   '/search'                 => 'portal#search'
  get   '/stats'                  => 'portal#stats'
  get   '/login'                  => 'sessions#new'
  get   '/logout'                 => 'sessions#destroy'
  get   '/session_status'         => 'sessions#show'
  get   '/session_data'           => 'session_data#show'
  post  '/session_data'           => 'session_data#update'
  # Globus authentication
  get   '/globus'                 => 'sessions#globus'
  post  '/unlink_globus'          => 'sessions#unlink_globus'
  get   '/mandatory_globus'       => 'sessions#mandatory_globus'

  # Report Maker
  get   "/report",                :controller => :portal, :action => :report

  # Network Operation Center; daily status (shows everything publicly!)
  #get   "/noc/daily",             :controller => :noc,    :action => :daily
  #get   "/noc/weekly",            :controller => :noc,    :action => :weekly
  #get   "/noc/monthly",           :controller => :noc,    :action => :monthly
  #get   "/noc/yearly",            :controller => :noc,    :action => :yearly
  #get   "/noc/users",             :controller => :noc,    :action => :users
  #get   "/noc/users/:by",         :controller => :noc,    :action => :users # :by is 'year' by default
  #get   "/noc/cpu",               :controller => :noc,    :action => :cpu
  #get   "/noc/cpu/:by",           :controller => :noc,    :action => :cpu # :by is 'month' by default
  #get   "/noc/tools",             :controller => :noc,    :action => :tools
  #get   "/noc/tools/:mode",       :controller => :noc,    :action => :tools # :mode is 'count' by default

  # API description, by Swagger
  get   "/swagger",               :controller => :portal, :action => :swagger

  # Licence handling
  get   '/show_license/:license', :controller => :portal, :action => :show_license
  post  '/sign_license/:license', :controller => :portal, :action => :sign_license

  # Portal log
  get   '/portal_log',            :controller => :portal, :action => :portal_log

  ####################################################################################
  # CARMIN platform routes
  ####################################################################################
  get    '/platform',               :controller => :carmin, :action => :platform
  post   '/authenticate',           :controller => :carmin, :action => :authenticate
  get    '/executions',             :controller => :carmin, :action => :executions
  get    '/executions/count',       :controller => :carmin, :action => :exec_count
  get    '/executions/:id/results', :controller => :carmin, :action => :exec_results
  get    '/executions/:id/stdout',  :controller => :carmin, :action => :exec_stdout
  get    '/executions/:id/stderr',  :controller => :carmin, :action => :exec_stderr
  put    '/executions/:id/play',    :controller => :carmin, :action => :exec_play
  put    '/executions/:id/kill',    :controller => :carmin, :action => :exec_kill
  put    '/executions/:id',         :controller => :carmin, :action => :exec_update
  get    '/executions/:id',         :controller => :carmin, :action => :exec_show
  delete '/executions/:id',         :controller => :carmin, :action => :exec_delete
  post   '/executions',             :controller => :carmin, :action => :exec_create
  get    '/pipelines',              :controller => :carmin, :action => :pipelines
  get    '/pipelines/:id',          :controller => :carmin, :action => :pipelines_show
  get    '/pipelines/:id/boutiquesdescriptor', # man is this long!
                                    :controller => :carmin, :action => :pipelines_boutiques
  # Note: the constraints below prevent the parser from processing and removing the extensions
  # to the paths given, e.g. for '/path/mydir/hello.txt', the :path will be 'mydir/hello.txt'
  get    '/path/*path',             :controller => :carmin, :action => :path_show,    :constraints => { :path => nil }
  put    '/path/*path',             :controller => :carmin, :action => :path_create,  :constraints => { :path => nil }
  delete '/path/*path',             :controller => :carmin, :action => :path_delete,  :constraints => { :path => nil }



  ####################################################################################
  # NeuroHub routes
  ####################################################################################

    # Special named routes
    get   '/neurohub'               => 'neurohub_portal#welcome'
    get   '/nh_news'                => 'neurohub_portal#news'
    get   '/styleguide'             => 'neurohub_portal#styleguide'
    get   '/nh_search'              => 'neurohub_portal#search'
    get   '/signin'                 => 'nh_sessions#new'
    get   '/signout'                => 'nh_sessions#destroy'
    get   '/myaccount'              => 'nh_users#myaccount'

    # Globus authentication
    get   '/nh_globus'              => 'nh_sessions#nh_globus'
    post  '/nh_unlink_globus'       => 'nh_sessions#nh_unlink_globus'
    get   '/nh_mandatory_globus'    => 'nh_sessions#nh_mandatory_globus'

    # ORCID authentication
    get   '/orcid'                  => 'nh_sessions#orcid'
    post  '/unlink_orcid'           => 'nh_users#unlink_orcid'

    # Sessions
    resource  :nh_session,   :only => [ :new, :create, :destroy ] do
      collection do
        get  'request_password'
        post 'send_password'
      end
    end

    # NeuroHub Resources
    resources :nh_invitations, :only => [ :new, :create, :index, :update, :destroy]
    resources :nh_signups
    resources :nh_users,       :only => [ :myaccount, :edit, :update] do
      collection do
        get  'change_password'
        post 'new_token'
      end
    end
    resources :nh_storages do # yeah pluralized, looks weird because it's uncountable
      member do
        post :check
        post :autoregister
      end
    end
    resources :nh_projects do
      member do
        get  :files
        get  :new_license
        post :add_license
        get  :show_license
        post :sign_license
        get  :new_file
        post :upload_file
      end
    end
    resources :nh_messages,    :except => [ :edit, :show ]
    resources :nh_loris_hooks, :only => [] do
      collection do
        post :file_list_maker
        post :csv_data_maker
      end
    end

end

