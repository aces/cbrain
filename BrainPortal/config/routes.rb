
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

CbrainRailsPortal::Application.routes.draw do

  # Session
  resource  :session do
    member do
      post 'mozilla_persona_auth'
    end
  end

  # Control channel
  resources :controls,       :controller => :controls

  # Documentation
  resources :docs,           :controller => :help_documents

  # Standard CRUD resources
  resources :sites
  resources :custom_filters
  resources :tool_configs
  resources :tags

  # Standard CRUD resources, with extra methods

  resources :feedbacks

  resources :messages do
    collection do
      delete 'delete_messages'
    end
  end

  resources :users do
    member do
      get  'change_password'
      post 'switch'
    end
    collection do
      get  'request_password'
      post 'send_password'
    end
  end

  resources :groups do
    collection do
      get  'switch_panel'
      post 'unregister'
      post 'switch'
    end
  end

  resources :invitations, :only => [:new, :create, :update, :destroy]

  resources :bourreaux do
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

  resources :data_providers do
    member do
      get  'browse'
      post 'register'
      get  'is_alive'
      get  'disk_usage'
      get  'report'
      post 'repair'
    end
    collection do
      get  'dp_access'
      get  'dp_transfers'
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
      post   'archive_management'
      post   'quality_control'
      post   'quality_control_panel'
      post   'manage_persistent'
      post   'sync_multiple'
    end
  end

  resources :tasks do
    collection do
      post 'new', :path => 'new', :as => 'new'
      post 'operation'
      get  'batch_list'
      post 'update_multiple'
    end
  end

  resources :tools do
    collection do
      get    'tool_config_select'
      post   'assign_tools'
    end
  end

  resources :exception_logs, :only => [:index, :show] do
    delete :destroy, :on => :collection
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
  get   '/filter_proxy'           => 'application#filter_proxy'

  # Report Maker
  get   "/report",                :controller => :portal, :action => :report

  # Licence handling
  get   '/show_license/:license', :controller => :portal, :action => :show_license
  post  '/sign_license/:license', :controller => :portal, :action => :sign_license

  # Portal log
  get   '/portal_log', :controller => :portal, :action => :portal_log

  # Service; most of these actions are only needed
  # for the CANARIE monitoring system, and are therefore
  # shipped disabled by default, because it's not needed
  # anywhere else.
  #get   '/service/info',           :controller => :service, :action => :info
  #get   '/service/stats',          :controller => :service, :action => :stats
  #get   '/service/detailed_stats', :controller => :service, :action => :detailed_stats
  #get   '/service/doc',            :controller => :service, :action => :doc
  #get   '/service/releasenotes',   :controller => :service, :action => :releasenotes
  #get   '/service/support',        :controller => :service, :action => :support
  #get   '/service/source',         :controller => :service, :action => :source
  #get   '/service/tryme',          :controller => :service, :action => :tryme
  #get   '/service/licence',        :controller => :service, :action => :licence
  #get   '/service/provenance',     :controller => :service, :action => :provenance

end

