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

  # Some methods to handle Pareto optimization in class Array
  class Array 
    def to_s
      s = "[ "
      each do |x| 
        s += "#{x} "
      end
      s+= "]"
      return s
    end

    def pareto_set
      pareto_set = Array.new
      n = length
      each  do |x| 
        pareto_set = pareto_set.add_to_pareto_set(x)
      end
      return pareto_set
    end

    def add_to_pareto_set(a)
      q = Array.new
      q << a
      each  do |x|
        if x.dominates? a then 
          return self 
        else
          if !a.dominates? x then
            q << x
          end
        end
      end
      return q
    end

    def bi_objective_min(lambda)
      qmin = self[0].get_performance
      qmax = qmin
      cmin = self[0].get_cost
      cmax = cmin
      each do |x|
        qmin = x.get_performance < qmin ? x.get_performance : qmin
        qmax = x.get_performance > qmax ? x.get_performance : qmax
        cmin = x.get_cost < cmin ? x.get_cost : cmin
        cmax = x.get_cost > cmax ? x.get_cost : cmax
      end

      best_bi_objective = bi_objective(self[0],lambda,qmin,qmax,cmin,cmax)
      best_element = self[0]
      each do |x|
        bo = bi_objective(x,lambda,qmin,qmax,cmin,cmax)
        puts "#{x} (#{bo})"
        if bo < best_bi_objective then 
          best_bi_objective = bo
          best_element = x 
        end
      end
      return best_element,best_bi_objective
    end
    def bi_objective(x,lambda,qmin,qmax,cmin,cmax)
      return lambda*(x.get_performance-qmin)/(qmax-qmin+0.0)+(1-lambda)*(x.get_cost-cmin)/(cmax-cmin+0.0)
    end
  end

class VmFactoryPareto < VmFactory
  
  def initialize(disk_image_id,tau,mu_plus,mu_minus,nu_plus,nu_minus,k_plus,k_minus,lambda)
    super(disk_image_id,tau,mu_plus,mu_minus,nu_plus,nu_minus,k_plus,k_minus)
    @lambda = lambda
  end

  # A generic class to represent 2-uples
  class PerformanceCostCouple
    def initialize(performance,cost)
      @q=performance
      @c=cost
    end
    def get_performance
      return @q
    end
    def get_cost
      return @c
    end
    def to_s
      return "(#{@q},#{@c})" 
    end
    def dominates?(x)
      if @q == x.get_performance and @c == x.get_cost then return false end
      if @q <= x.get_performance and @c <= x.get_cost then return true end
      return false
    end
  end

  class Site < PerformanceCostCouple
    def initialize(performance,cost,cost_overhead,name)
      @name = name
      @cost_overhead = cost_overhead
      super(performance,cost)
    end
    def get_name
      return @name
    end
    def get_cost_overhead
      return @cost_overhead
    end
    def to_s
      "#{@name} ; #{self.get_performance} ; #{self.get_cost}"
    end
  end

  # An action is a VM submission decision. 
  class Action < PerformanceCostCouple
    def initialize(sites)
      @name = ""
      @sites = sites.dup
      if sites.size == 0 then 
        super(Float::INFINITY,0) 
        return
      end    

      # determines performance and cost of the action
      # qmin and cmax 
      pmin = @sites[0].get_performance
      cmax = 0 
      sum_overheads = 0 
      @sites.each do |x|
        sum_overheads += x.get_cost_overhead
      end
      @sites.each do |s|
        @name += "#{s.get_name} "
        s_p = s.get_performance
        if s_p < pmin then pmin = s_p end
        #overhead of other sites also has to be added
        cost = s.get_cost + sum_overheads - s.get_overhead 
        if cost > cmax then cmax = cost end
      end
      # sum(pmin/pi)
      sum = 0 
      @sites.each do |s|
        sum += pmin/(0.0+s.get_performance)
      end
      p = (pmin/2.0)*(Math.exp(1-sum)+1)    
      super(p,cmax)
    end
    def to_s
      return "* #{@name} ; C=#{get_cost} ; P=#{get_performance}"
    end
    def get_sites
      return @sites
    end
  end
  
  def submit_vm
    
    update_site_queues
    update_site_booting_times
    update_site_performance_factors
    median_duration = get_median_task_durations_of_queued_tasks

    sites = Array.new
    0.upto(@site_names.length-1) do |i|
      #log_vm "Adding site with parameters #{@site_queues[i]}, #{@site_costs[i]}, #{@site_names[i]}"
      if Bourreau.find(@bourreau_ids[i]).online? then
        expected_on_cpu = @site_booting_times[i]+median_duration*@site_performance_factors[i]
        # site performance : queueing time + expected time on CPU
        # site cost : site cost factor * expected time on CPU
        # site overhead : site cost factor * booting time 
        sites << Site.new(@site_queues[i]+expected_on_cpu,@site_costs[i]*expected_on_cpu,@site_booting_times[i]*@site_costs[i],@site_names[i])
      else
        log_vm "Don't consider offline site #{@site_names[i]} in bi-objective optimization"
      end
    end
    
    # generate all actions
    # http://jeux-et-mathematiques.davalan.org/divers/parties/index.html
    actions = Array.new
    sites.each do |x|
      n_actions = actions.dup
      actions.each do |a| 
        n_actions << Action.new(a.get_sites + [x])
      end
      n_actions << Action.new([x]) 
      actions = n_actions
    end
    
    log_vm " == All actions == "
    actions.each do |a|
      log_vm "#{a}"
    end
    
    log_vm " == Pareto set == "
    pareto_set = actions.pareto_set
    pareto_set.each do |a|
      log_vm "#{a}"
    end
    
    if not pareto_set.blank? then
      puts " == Bi-objective minimization == "
      (best_action,best_bo) = pareto_set.bi_objective_min(@lambda) 
      log_vm " Best Action is #{best_action} (#{best_bo})"
      
      #now implement this action
      site_indexes = Array.new 
      best_action.get_sites.each do |x|
        site_indexes <<  @site_names.index(x.get_name)
      end
      submit_vm_and_replicate site_indexes
    end
  end
  
  #sites = [Site.new(32,11,"A"),Site.new(21,12,"B"),Site.new(1,3,"C"),Site.new(1,30,"D"),Site.new(11,31,"E"),Site.new(21,32,"F")]
  #alpha = 0.01
  #lambda = 1
  
  # # generate all actions
  # # http://jeux-et-mathematiques.davalan.org/divers/parties/index.html
  # actions = Array.new
  # sites.each do |x|
  #   n_actions = actions.dup
  #   actions.each do |a| 
  #     n_actions << Action.new(a.get_sites + [x],alpha)
  #   end
  #   n_actions << Action.new([x],alpha) 
  #   actions = n_actions
  # end

  # puts " == All actions == "
  # actions.each do |a|
  #   puts "#{a}"
  # end

  # puts " == Pareto set == "
  # pareto_set = actions.pareto_set
  # pareto_set.each do |a|
  #   puts "#{a}"
  # end

  # puts " == Bi-objective minimization == "
  # (best_action,best_bo) = pareto_set.bi_objective_min(lambda) 
  # puts " Best Action is #{best_action} (#{best_bo})"

  #set = [Couple.new(2,4),Couple.new(2,3), Couple.new(1,2), Couple.new(4,1.9)]
  #set.pareto_set.print
end

