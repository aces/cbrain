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
      qmin = self[0].get_queue 
      qmax = qmin
      cmin = self[0].get_cost
      cmax = cmin
      each do |x|
        qmin = x.get_queue < qmin ? x.get_queue : qmin
        qmax = x.get_queue > qmax ? x.get_queue : qmax
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
      return lambda*(x.get_queue-qmin)/(qmax-qmin+0.0)+(1-lambda)*(x.get_cost-cmin)/(cmax-cmin+0.0)
    end
  end

class VmFactoryPareto < VmFactory
  
  def initialize(tau,mu_plus,mu_minus,nu_plus,nu_minus,k_plus,k_minus,alpha,lambda)
    super(tau,mu_plus,mu_minus,nu_plus,nu_minus,k_plus,k_minus)
    @alpha = alpha
    @lambda = lambda
  end

  # A generic class to represent 2-uples
  class QueueCostCouple
    def initialize(queue,cost)
      @q=queue
      @c=cost
    end
    def get_queue
      return @q
    end
    def get_cost
      return @c
    end
    def to_s
      return "(#{@q},#{@c})" 
    end
    def dominates?(x)
      if @q == x.get_queue and @c == x.get_cost then return false end
      if @q <= x.get_queue and @c <= x.get_cost then return true end
      return false
    end
  end

  class Site < QueueCostCouple
    def initialize(q,c,name)
      @name = name
      super(q,c)
    end
    def get_name
      return @name
    end
    def to_s
      "#{@name} ; #{self.get_queue} ; #{self.get_cost}"
    end
  end

  # An action is a VM submission decision. 
  class Action < QueueCostCouple
    def initialize(sites,alpha)
      @name = ""
      @sites = sites.dup
      if sites.size == 0 then 
        super(Float::INFINITY,0) 
        return
      end    

      # determines queue and cost of the action
      # determines q
      # qmin and cmax and sum(ci)
      qmin = @sites[0].get_queue
      cmax = @sites[0].get_cost
      sum_c = 0
      @sites.each do |s|
        @name += "#{s.get_name} "
        s_q = s.get_queue
        if s_q < qmin then qmin = s_q end
        s_c = s.get_cost
        sum_c += s_c
        if s_c > cmax then cmax = s_c end
      end
      # sum(qmin/qi)
      sum = 0 
      @sites.each do |s|
        sum += qmin/(0.0+s.get_queue)
      end
      q = (qmin/2.0)*(Math.exp(1-sum)+1)    
      # determines c
      c = cmax + alpha*(sum_c-cmax)
      super(q,c)
    end
    def to_s
      return "* #{@name} ; C=#{get_cost} ; Q=#{get_queue}"
    end
    def get_sites
      return @sites
    end
  end
  
  def submit_vm
    
    update_site_queues

    sites = Array.new
    0.upto(@site_names.length-1) do |i|
      #log_vm "Adding site with parameters #{@site_queues[i]}, #{@site_costs[i]}, #{@site_names[i]}"
      sites << Site.new(@site_queues[i],@site_costs[i],@site_names[i])
    end
    
    # generate all actions
    # http://jeux-et-mathematiques.davalan.org/divers/parties/index.html
    actions = Array.new
    sites.each do |x|
      n_actions = actions.dup
      actions.each do |a| 
        n_actions << Action.new(a.get_sites + [x],@alpha)
      end
      n_actions << Action.new([x],@alpha) 
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

