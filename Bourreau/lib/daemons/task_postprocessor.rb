#!/usr/bin/env ruby

# You might want to change this
ENV["RAILS_ENV"] ||= "production"

require File.dirname(__FILE__) + "/../../config/environment"

$running = true
Signal.trap("TERM") do 
  $running = false
end

while($running) do
  @tasks = DrmaaTask.find(:all, :conditions => {:cluster_name => CBRAIN_CLUSTERS::BOURREAU_CLUSTER_NAME, :status => 'Data Ready' }) || []
  
  @tasks.each do |task|
    task.post_process
  end   
  
  sleep 300
end