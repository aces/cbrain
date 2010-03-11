#
# CBRAIN Project
#
# Model for Statistics
#
# Original author: Angela McCloskey
#
# $Id$
#

class Statistic < ActiveRecord::Base
  
  def update_stats
    entry = Statistic.find(:first, :conditions => { :bourreau_id => self.bourreau_id, :task_name => self.task_name, :user_id => self.user_id })
    if entry == nil
      self.count = 1
      self.save!
    else
      entry.count += 1
      entry.save!
    end
  end
  
  def self.user_task_stats(task_name, user)
      stats_user = Statistic.find(:first, :conditions => {:user_id => user, :task_name => task_name})
      stats_user.count
  end
  
  
  def self.total_task_user(user)
    total = Statistic.find(:all, :conditions => {:user_id => user})
    total_count = 0
    total.each do |entry|
      total_count += entry.count
    end
    return total_count
  end
  

  #Search through the bourreau of interest to get a list of tasks
  def self.bourreau_stats(bourreau)
    extracted_stats = Hash.new
    list_tools = Bourreau.find(bourreau).tools.map{|tool| tool.drmaa_class}
    total_count_bourreau =0 
    list_tools.each do |tool|
      total_count_tool =0
      from_all_users = Statistic.find(:all, :conditions => {:task_name => tool, :bourreau_id => bourreau})
      from_all_users.each do |user_tool|
        total_count_tool += user_tool.count
        total_count_bourreau += user_tool.count
      end
      if total_count_tool > 0
        extracted_stats[tool] = total_count_tool 
      end
    end
    extracted_stats["total_count_bourreau"] = total_count_bourreau
    return extracted_stats
  end

end
