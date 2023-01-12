
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
        # TODO transparently handle .gz versions
        filename = Rails.root + "data_dumps" + "#{type.to_s}.#{timestamp}.yaml"
        if ! filename.exist?
          filename = Rails.root + "data_dumps" + "#{type.to_s}.#{timestamp}.yaml.gz"
          if ! filename.exist?
            printf "%36s : no dump found in %s\n", type.to_s, filename
            next
          end
        end

        if filename.to_s.ends_with? ".gz"
          attlist = YAML.load(IO.popen("gunzip -c #{filename.to_s.bash_escape}","r") { |fh| fh.read })
        else
          attlist = YAML.load(File.read(filename))
        end

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

    ####################
    # Task 'monthly'
    #
    # Re-insert monthly summaries from dumps from RAILS_ROOT/data_dumps
    #
    # Requires one argument, the class of the ResourceUsage to create summaries for.
    #
    #   klass => ResourceUsageSubclass
    #
    # The special value 'All' tells the task to process all four subclasses
    # (see the exampled below)
    #
    # All the matching class' .yaml or .yaml.gz files in the data_dumps directory will
    # be reloaded and a monthly summary records will be inserted or updated in the DB
    #
    # Syntax for the command-line:
    #
    #   rake cbrain:resource_usage:monthly[CputimeResourceUsageForCbrainTask]
    #   rake cbrain:resource_usage:monthly[WalltimeResourceUsageForCbrainTask]
    #   rake cbrain:resource_usage:monthly[SpaceResourceUsageForCbrainTask]
    #   rake cbrain:resource_usage:monthly[SpaceResourceUsageForUserfile]
    #   rake cbrain:resource_usage:monthly[All]
    #
    ####################

    desc "Insert or update resource usage monthly summaries"
    task :monthly, [:klass] => :environment do |t,args|

      allowed_klasses = %w(
        CputimeResourceUsageForCbrainTask
        WalltimeResourceUsageForCbrainTask
        SpaceResourceUsageForCbrainTask
        SpaceResourceUsageForUserfile )
      arg_name = args.klass.presence || ""
      raise "This task requires a ResourceUsage class name argument, or 'All'." unless
        (arg_name == 'All') || (allowed_klasses.include? arg_name)

      klass_names = arg_name == 'All' ? allowed_klasses : [ arg_name ]

      # Main processing loop for all classes
      klass_names.each do |klass_name|

        puts "\n-------------------------------------------------------"
        puts "Reloading ResourceUsage records for class #{klass_name}"

        # Find all files for klass_name
        globpattern = Rails.root + "data_dumps" + "#{klass_name}.*.yaml*" # matches .gz too
        files       = Dir.glob(globpattern)

        puts "Found #{files.size} files(s) to reload..."

        totyaml = []
        files.each do |filename|
          if filename.ends_with? ".gz"
            attlist = YAML.load(IO.popen("gunzip -c #{filename.to_s.bash_escape}","r") { |fh| fh.read })
          else
            attlist = YAML.load(File.read(filename))
          end
          # Notify user
          printf "%36s : %7d records from %s\n", klass_name.to_s, attlist.size, Pathname.new(filename).basename
          totyaml += attlist
        end

        if files.size > 1
          printf "%36s : %7d records TOTAL\n", klass_name.to_s, totyaml.size
        end
        totyaml.sort! { |a,b| a["created_at"] <=> b["created_at"] }

        monthly_klass      = ("Monthly"+klass_name).constantize
        grouped_attributes = monthly_klass::GroupedAttributes

        summaries = {}  # cache_key => MonthlyBlabBlah object
        totyaml.each_with_index_and_size do |record,idx,size|

          month=record["created_at"].beginning_of_month
          month_key = month.strftime("%Y-%m")
          puts "Processing (#{idx+1}/#{size}) at #{month_key}" if ((idx+1) % 10000) == 0

          # Build cache key: "2019-02|a|b|c|d|d" where a, b c are selected attributes values
          att_keys=grouped_attributes.map do |att|
            record[att]
          end.join("|")
          cache_key = month_key + "|" + att_keys

          # Find or create the summary and add the count value to it
          summary = summaries[cache_key]
          if !summary
            summary = monthly_klass.new(record.slice(*grouped_attributes))
            summary["created_at"]       = month
            summary["userfile_name"]    = "Summary #{month_key}" if klass_name == 'SpaceResourceUsageForUserfile'
            summary["cbrain_task_type"] = "Summary #{month_key}" if klass_name == 'CputimeResourceUsageForCbrainTask'
            summary["cbrain_task_type"] = "Summary #{month_key}" if klass_name == 'WalltimeResourceUsageForCbrainTask'
            summary["cbrain_task_type"] = "Summary #{month_key}" if klass_name == 'SpaceResourceUsageForCbrainTask'
            summaries[cache_key]  = summary
          end
          summary["value"] ||= 0
          summary["value"]  += record["value"]
        end

        puts "Deleting old summaries from database..."
        monthly_klass.delete_all

        summaries = summaries.values.reject { |s| s["value"] == 0 }
        puts "Writing #{summaries.size} new summaries to database..."
        summaries.each { |summary| summary.save }

      end # loop for each class

      true
    end # task monthly

  end # namespace :resource_usage
end # namespace :cbrain

