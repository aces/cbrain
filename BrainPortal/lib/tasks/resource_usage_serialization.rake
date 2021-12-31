
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

namespace :cbrain do
  namespace :resource_usage do

    ####################
    # Task 'dump'
    #
    # Saves ResourceUsage dumps in RAILS_ROOT/data_dumps
    #
    # Two arguments:
    #   destroy => 'no' or 'DESTROY_ALL'
    #     whether or not to destroy the records after they are dumped
    #   allrecords => 'no' or 'ALL'
    #     whether or not to dump just the ResourceUsage records for missing resources,
    #     or all ResourceUsage records
    #
    # Syntax for the command-line:
    #
    #   rake cbrain:resource_usage:dump                  # default
    #   rake cbrain:resource_usage:dump[no,no]           # default
    #   rake cbrain:resource_usage:dump[DESTROY_ALL]     # standard maintenance
    #   rake cbrain:resource_usage:dump[DESTROY_ALL,no]  # standard maintenance
    #   rake cbrain:resource_usage:dump[no,ALL]          # full backup
    #   rake cbrain:resource_usage:dump[DESTROY_ALL,ALL] # full reset
    ####################

    desc "Dump resource usage records"
    task :dump, [:destroy, :allrecords] => :environment do |t,args|

      args.with_defaults(:destroy    => 'no')
      args.with_defaults(:allrecords => 'no')
      destroy = args.destroy
      raise "This task's value for 'destroy' must be 'no' (default) or 'DESTROY_ALL'" unless
        destroy.match /\A(no|DESTROY_ALL)\z/
      allrecords = args.allrecords
      raise "This task's value for 'allrecords' must be 'no' (default) or 'ALL'" unless
        allrecords.match /\A(no|ALL)\z/

      timestamp=Time.zone.now.strftime("%Y-%m-%dT%H%M%S")
      type_to_nullmodel = {
        # Dump these records if...             ... this associated record is gone
        #----------------------------------    ----------------------------------
        CputimeResourceUsageForCbrainTask   => :cbrain_task,
        SpaceResourceUsageForCbrainTask     => :cbrain_task,
        WalltimeResourceUsageForCbrainTask  => :cbrain_task,
        SpaceResourceUsageForUserfile       => :userfile,
      }
      type_to_nullmodel.each do |type,nullmodel|

        # Identify what to dump
        old_records = type.all
        if allrecords != 'ALL' # default
          old_records = old_records
            .left_outer_joins(nullmodel)
            .where("#{nullmodel}s.id" => nil) # we must pluralize the table name
        end

        # Inform user
        count       = old_records.count
        filename    = Rails.root + "data_dumps" + "#{type.to_s}.#{timestamp}.yaml"
        printf "%36s : %7d records %s\n", type.to_s, count, (count == 0 ? "(nothing to dump)" : "dumped in #{filename}")
        next if count == 0

        # Dump records
        File.open(filename,"w") do |fh|
          fh.write(old_records.to_a.map(&:attributes).to_yaml)
        end

        # Destroy them
        if destroy == 'DESTROY_ALL'
          puts " -> destroying records in database..."
          if allrecords == 'ALL'
            type.delete_all
          else
            # Note: you can't .delete_all on a left_outer_join relation... :-(
            old_records.find_each do |obj|  # will do 1000 objects at time
              obj.delete
            end
          end
        end

      end

      true
    end # task :dump

    ####################
    # Task 'reload'
    #
    # Reloads ResourceUsage dumps from RAILS_ROOT/data_dumps
    #
    # One argument:
    #   timestamp => '2012-12-23T134500'
    #
    # Syntax for the command-line:
    #
    #   rake cbrain:resource_usage:reload[2012-12-23T134500]
    ####################

    desc "Reload resource usage records"
    task :reload, [:timestamp] => :environment do |t,args|

      timestamp = args.timestamp.presence || ""
      raise "This task requires a timestamp argument in the format yyyy-mm-ddThhmmss" unless
        timestamp =~ /\A20\d\d-[01]\d-[0123]\dT\d\d\d\d\d\d\z/

      types_to_reload = [
        CputimeResourceUsageForCbrainTask,
        SpaceResourceUsageForCbrainTask,
        WalltimeResourceUsageForCbrainTask,
        SpaceResourceUsageForUserfile,
      ]

      types_to_reload.each do |type|

        # Find dump file and reload it
        filename = Rails.root + "data_dumps" + "#{type.to_s}.#{timestamp}.yaml"
        if ! filename.exist?
          printf "%36s : no dump found in %s\n", type.to_s, filename
          next
        end
        attlist = YAML.load(File.read(filename))

        # Notify user
        printf "%36s : %7d records from %s\n", type.to_s, attlist.size, filename

        # Re-insert records
        objlist    = attlist.map { |attributes| type.new(attributes) }
        idlist     = objlist.map(&:id)
        exists_ids = (type.pluck(:id) & idlist).inject({}) { |h,id| h[id]=true;h }
        if exists_ids.size > 0
          puts " -> Skipping #{exists_ids.size} objects already in DB"
        end
        objlist
         .reject { |obj| exists_ids[obj.id] }
         .each   { |obj| obj.save! }

      end

      true
    end # task reload

  end # namespace :resource_usage
end # namespace :cbrain

