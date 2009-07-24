ActionController::Routing::Routes.draw do |map|

  #map.resources :tasks
  map.connect  ':drmaa_tasks/ping.:format', :controller => 'tasks', :action => 'ping'
  map.resources :drmaa_tasks,     :controller => :tasks
  map.resources :drmaa_sleepers,  :controller => :tasks
  map.resources :drmaa_snoozers,  :controller => :tasks
  map.resources :drmaa_minc2jivs, :controller => :tasks
  map.resources :drmaa_civets,    :controller => :tasks
  map.resources :drmaa_dcm2mncs,  :controller => :tasks
  map.resources :drmaa_mnc2niis,  :controller => :tasks
  map.resources :drmaa_mincaverages,  :controller => :tasks
  map.resources :drmaa_mincmaths,  :controller => :tasks
  map.resources :drmaa_mincresamples, :controller => :tasks
  

  #UNF resources
  map.resources :drmaa_cw5filters,     :controller => :tasks  
  map.resources :drmaa_matlabs,         :controller => :tasks
  map.resources :drmaa_cw5s,            :controller => :tasks  

  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'

end