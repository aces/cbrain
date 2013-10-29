
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

class VmFactoryThresholdQueue < VmFactory

  # def initialize(tau,mu_plus,mu_minus,nu_plus,nu_minus,k_plus,k_minus)
  #   log_vm "===="
  #   super(tau,mu_plus,mu_minus,nu_plus,nu_minus,k_plus,k_minus)
  # end

  def submit_vm
    #submit and replicate VMs on all sites
    submit_vm_and_replicate Array.new(@nsites-1){|i| i+1}
  end
end
