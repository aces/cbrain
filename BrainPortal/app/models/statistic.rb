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
  
  def self.count_task_bourreau(task, bourreau)
    result = Statistic.find(:all, :conditions => {:task_name => task, :bourreau_id => bourreau})
    stat_count = 0
    result.each do |entry|
      stat_count += entry.count     
    end
    stat_count
  end
  
  def self.total_task_bourreau(bourreau)
    total = Statistic.find(:all, :conditions => {:bourreau_id => bourreau})
    total_count = 0
    total.each do |entry|
        total_count += entry.count
    end 
    total_count
  end
  
  def self.total_task_user(user)
    total = Statistic.find(:all, :conditions => {:user_id => user})
    total_count = 0
    total.each do |entry|
      total_count += entry.count
    end
    return total_count
  end
  
  def self.user_task_stats(task_name, user)
    stats_user = Statistic.find(:all, :conditions => {:user_id => user, :task_name => task_name})
    stat_count =0 
    stats_user.each do |entry|
      stat_count += entry.count
    end
    stat_count
  end

end
