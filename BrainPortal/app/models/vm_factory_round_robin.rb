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

# VM submission done in round robin. 

class VmFactoryRoundRobin < VmFactory 

  
  def get_next_bourreau_id
    target_bourreau_ids = get_ids_of_target_bourreaux.sort
    return nil unless target_bourreau_ids.length >= 1

    n_bourreaux = target_bourreau_ids.length
    n_attempts = 1

    @last_bourreau_id ||=  target_bourreau_ids.first
    @last_bourreau_id = target_bourreau_ids[( target_bourreau_ids.index(@last_bourreau_id) + 1 ) % n_bourreaux ]
    
    bourreau = Bourreau.find(@last_bourreau_id)
    while (get_active_tasks(bourreau.id) >= bourreau.meta[:task_limit_total].to_i && n_attempts < n_bourreaux)  do
      @last_bourreau_id = target_bourreau_ids[( target_bourreau_ids.index(@last_bourreau_id) + 1 ) % n_bourreaux ]
      bourreau = Bourreau.find(@last_bourreau_id)
    end
    return @last_bourreau_id
  end

  def submit_vm  
    next_bourreau_id = get_next_bourreau_id 
    if next_bourreau_id.blank? then log_vm "Cannot find a bourreau where to submit VM.".colorize(32) else
      self.submit_vm_to_site next_bourreau_id
    end
  end

end
