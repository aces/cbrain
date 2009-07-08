#!/usr/bin/env ruby

# You might want to change this
ENV["RAILS_ENV"] ||= "production"

require File.dirname(__FILE__) + "/../../config/environment"

$running = true
Signal.trap("TERM") do 
  $running = false
end

while($running) do
  @tasks = DrmaaTask.find(:all, :conditions => { :bourreau_id => CBRAIN::BOURREAU_ID, :status => 'Data Ready' }) || []
  
  @tasks.each do |task|
    task.post_process
  end   
  
  sleep 300
end
