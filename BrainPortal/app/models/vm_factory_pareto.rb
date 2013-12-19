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


class VmFactoryPareto < VmFactory
  
  def initialize(disk_image_id,tau,mu_plus,mu_minus,nu_plus,nu_minus,k_plus,k_minus,lambda)
    super(disk_image_id,tau,mu_plus,mu_minus,nu_plus,nu_minus,k_plus,k_minus)
    @lambda = lambda
  end

  # the only method called on objects of this class
  def submit_vm
    update_site_queues
    update_site_booting_times
    update_site_performance_factors
    median_duration = get_median_task_durations_of_queued_tasks
    
    log_vm "Median duration of queued tasks: #{median_duration}"
    log_vm "Site queuing times: #{@site_queues}"
    log_vm "Site booting times: #{@site_booting_times}"
    log_vm "Site performance factors: #{@site_performance_factors}"
    
    sites = Array.new
    0.upto(@site_names.length-1) do |i|
      #log_vm "Adding site with parameters #{@site_queues[i]}, #{@site_costs[i]}, #{@site_names[i]}"
      bourreau = Bourreau.find(@bourreau_ids[i])
      if bourreau.online? then
        if get_active_tasks(@bourreau_ids[i]) >= @max_active[i] then
          log_vm "Not".colorize(31)+" including bourreau "+"#{bourreau.name}".colorize(33)+" in Pareto optimization because it reached its max active tasks"
          next
        else
          log_vm "Bourreau "+"#{bourreau.name}".colorize(33)+" hasn't reached its max active tasks (#{get_active_tasks(@bourreau_ids[i])} < #{@max_active[i]}): including it in Pareto optimization."
        end
        expected_on_cpu = @site_booting_times[i]+median_duration*@site_performance_factors[i]
        # site performance : queueing time + expected time on CPU
        # site cost : site cost factor * expected time on CPU
        # site overhead : site cost factor * booting time 
        sites << Site.new(@site_queues[i]+expected_on_cpu,@site_costs[i]*expected_on_cpu,@site_booting_times[i]*@site_costs[i],median_duration*@site_performance_factors[i],@site_names[i])
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
    
    pareto_set = actions.pareto_set
    log_vm " == Pareto set (#{pareto_set.length} elements) == "
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
    def initialize(performance,cost,cost_overhead,expected_task_duration,name)
      @name = name
      @cost_overhead = cost_overhead
      @expected_task_duration = expected_task_duration
      super(performance,cost)
    end
    def get_name
      return @name
    end
    def get_cost_overhead
      return @cost_overhead
    end
    def get_expected_task_duration
      return @expected_task_duration
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
      q_and_b_min = @sites[0].get_performance
      cmax = 0 
      sum_overheads = 0 
      cpu_of_min_q_and_b = 0
      cost_of_min_q_and_b = 0
      @sites.each do |x|
        sum_overheads += x.get_cost_overhead
      end
      @sites.each do |s|
        @name += "#{s.get_name} "
        s_q_and_b = s.get_performance - s.get_expected_task_duration
        if s_q_and_b < q_and_b_min then 
          q_and_b_min = s_q_and_b 
          cpu_of_min_q_and_b = s.get_expected_task_duration
          cost_of_min_q_and_b = s.get_cost + sum_overheads - s.get_cost_overhead 
        end
       end
      # sum(pmin/pi)
      sum = 0 
      @sites.each do |s|
        sum += q_and_b_min/(0.0+s.get_performance-s.get_expected_task_duration)
      end
      q_and_b = (q_and_b_min/2.0)*(Math.exp(1-sum)+1)    
      super(q_and_b+cpu_of_min_q_and_b,cost_of_min_q_and_b)
    end
    def to_s
      return "* #{@name} ; C=#{get_cost} ; P=#{get_performance}"
    end
    def get_sites
      return @sites
    end
  end
  
  def get_median_task_durations_of_queued_tasks
    queued_all =  CbrainTask.where(:status => [ 'New'] ) - CbrainTask.where(:type => "CbrainTask::StartVM") 
    queued = queued_all.reject{ |x| (not Bourreau.find(x.bourreau_id).is_a? DiskImageBourreau) || (DiskImageBourreau.find(x.bourreau_id).disk_image_file_id != @disk_image_file_id)}    
    if queued.length == 0 then return 0 end
    durations = Array.new
    queued.each { |t| 
      durations << t.job_walltime_estimate
    }
    
    sorted_durations = durations.sort
    len = durations.length
    median_duration = len % 2 == 1 ? sorted_durations[len/2] : (sorted_durations[len/2 - 1] + sorted_durations[len/2]) / 2.0
    return median_duration
  end

end


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
    pmin = self[0].get_performance
    pmax = pmin
    cmin = self[0].get_cost
    cmax = cmin
    each do |x|
      pmin = x.get_performance < pmin ? x.get_performance : pmin
      pmax = x.get_performance > pmax ? x.get_performance : pmax
      cmin = x.get_cost < cmin ? x.get_cost : cmin
      cmax = x.get_cost > cmax ? x.get_cost : cmax
    end

    best_bi_objective = bi_objective(self[0],lambda,pmin,pmax,cmin,cmax)
    best_element = self[0]
    each do |x|
      bo = bi_objective(x,lambda,pmin,pmax,cmin,cmax)
      puts "#{x} (#{bo})"
      if bo < best_bi_objective then 
        best_bi_objective = bo
        best_element = x 
      end
    end
    return best_element,best_bi_objective
  end

  def bi_objective(x,lambda,pmin,pmax,cmin,cmax)
    perf_term = pmin==pmax ? lambda : lambda*(x.get_performance-pmin)/(pmax-pmin+0.0)
    cost_term = cmin==cmax ? 1-lambda : (1-lambda)*(x.get_cost-cmin)/(cmax-cmin+0.0)
    bio = perf_term + cost_term
    return bio
  end
end


