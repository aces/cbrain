
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
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

  # Standard CRUD resources, with extra actions

  resources :tool_configs, :except => [ :edit ] do
    collection do
      get  'report'
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
    end
    collection do
      get  'dp_access'
      get  'dp_transfers'
    end
  end

  resources :userfiles,       :except => [ :edit, :destroy ] do
    member do
      get  'content'
      get  'file_collection_content/*file_path' => 'userfiles#file_collection_content'
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
  get   '/search'                 => 'portal#search'
  get   '/login'                  => 'sessions#new'
  get   '/logout'                 => 'sessions#destroy'
  get   '/session_status'         => 'sessions#show'
  get   '/session_data'           => 'session_data#show'
  post  '/session_data'           => 'session_data#update'

  # Report Maker
  get   "/report",                :controller => :portal, :action => :report

  # Network Operation Center; daily status (shows everything publicly!)
  #get   "/noc/daily",             :controller => :noc,    :action => :daily
  #get   "/noc/weekly",            :controller => :noc,    :action => :weekly
  #get   "/noc/monthly",           :controller => :noc,    :action => :monthly
  #get   "/noc/yearly",            :controller => :noc,    :action => :yearly

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
  # Service; most of these actions are only needed
  # for the CANARIE monitoring system, and are therefore
  # shipped disabled by default, because it's not needed
  # anywhere else.
  ####################################################################################
  #get   '/platform/info',           :controller => :service, :action => :info
  #get   '/platform/stats',          :controller => :service, :action => :stats
  #get   '/platform/detailed_stats', :controller => :service, :action => :detailed_stats
  #get   '/platform/doc',            :controller => :service, :action => :doc
  #get   '/platform/releasenotes',   :controller => :service, :action => :releasenotes
  #get   '/platform/support',        :controller => :service, :action => :support
  #get   '/platform/source',         :controller => :service, :action => :source
  #get   '/platform/tryme',          :controller => :service, :action => :tryme
  #get   '/platform/licence',        :controller => :service, :action => :licence
  #get   '/platform/provenance',     :controller => :service, :action => :provenance
  #get   '/platform/factsheet',      :controller => :service, :action => :factsheet



  ####################################################################################
  # NeuroHub routes
  ####################################################################################

    # Special named routes
    get   '/neurohub'               => 'neurohub_portal#welcome'
    get   '/styleguide'             => 'neurohub_portal#styleguide'
    get   '/nh_search'              => 'neurohub_portal#search'
    get   '/signin'                 => 'nh_sessions#new'
    get   '/signout'                => 'nh_sessions#destroy'
    get   '/myaccount'              => 'nh_users#myaccount'

    # ORCID authentication
    get   '/orcid'                  => 'nh_sessions#orcid'

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
    resources :nh_messages,        :except => [ :edit, :show ] do
    end
    resources :nh_loris_hooks, :only => [] do
      collection do
        post :file_list_maker
        post :csv_data_maker
      end
    end

end

