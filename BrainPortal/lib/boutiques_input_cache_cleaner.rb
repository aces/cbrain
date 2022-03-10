
#
# CBRAIN Project
#
# Copyright (C) 2008-2021
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

# This module adds automatic verification of the
# type of files selected in a File input of a Boutiques Task.
#
# To include the module automatically at boot time
# in a task integrated by Boutiques, add a new entry
# in the 'custom' section of the descriptor, like this:
#
#   "custom": {
#       "cbrain:integrator_modules": {
#           "BoutiquesInputCacheCleaner": [
#             "my_input1",
#             "my_input2"
#           ]
#       }
#   }
#
# In the example above, any userfile cache selected for the file input
# named 'my_input1' or 'my_input2' will be deleted after task execution unless CBRAIN
# notices that another task uses same cache.
# CBRAIN tries to handle conflict between tasks that share same file based on timestamps.
# Yet this is a dangerous feature as it might not handle some of races, e.g. with legacy tools
module BoutiquesInputCacheCleaner

  def setup #:nodoc:
    self.meta[:setup_time] = Time.now
    super
  end

  def save_results #:nodoc:

    return fail unless super # call all the normal code

    setup_time = self.meta[:setup_time] || Time.now

    descriptor = self.descriptor_for_save_results
    inputs     = descriptor.custom_module_info('BoutiquesInputCacheCleaner')

    inputs.each do |inputid| # 'my_input1', 'my_input2'

      input = descriptor.input_by_id(inputid)

      Array(invoke_params[inputid]).map(&:presence).compact.each do |inputfileid|
        inputfile = Userfile.find(inputfileid)
        last_cache_access_time = inputfile.local_sync_status&.accessed_at        
        next if !last_cache_access_time  # cache is already deleted
        next if last_cache_access_time > setup_time  # skip, perhaps the file is being accessed by another task
        inputfile.cache_erase
        self.addlog("Boutiques Integrator's InputCacheCleaner deleted #{inputfile.name} file cache (parameter #{input.cb_invoke_name})")
      end

    end

  end

end
