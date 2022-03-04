
#
# CBRAIN Project
#
# Copyright (C) 2008-2022
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
  namespace :models do

    ####################
    # Task 'broken'
    #
    # Reports statistics about broken associations
    ####################

    desc "Report Broken ActiveRecord Associations"
    task :broken, [:destroy] => :environment do |t,args|

      args.with_defaults(:destroy => 'no')
      destroy = args.destroy
      raise "This task's value for 'destroy' must be 'no' (default), 'yes' or 'ask'" unless
        destroy.match /\A(no|yes|ask)\z/

      # This loads the 'to_summary' methods for many AR classes
      load "config/console_rc/lib/fast_finder.rb"

      # Asks a question. Always prints at least a new line.
      yesno = ->() do
        if destroy == 'yes'
          puts " | (Destroying)"
          true
        elsif destroy == 'ask'
           print " | Destroy records? (y/n) "
           answer = STDIN.readline
           answer.to_s =~ /^\s*[yY]/
        else
           puts ""
           false
        end
      end

      # These two have special multi-table connections using their attributes
      # ar_id and ar_table_name
      [ ActiveRecordLog, MetaDataStore ].each do |mainmodel|
        puts "\nChecking #{mainmodel.name}"
        tablenames = mainmodel.group(:ar_table_name).pluck(:ar_table_name) # 'access_profiles', 'userfiles' etc
        tablenames.each do |tablename|
          model   = tablename.camelize.singularize.constantize # the classes: AccessProfile, Userfile etc
          all_ids = model.pluck(:id)
          log_ids = mainmodel.where(:ar_table_name => tablename).pluck(:ar_id).uniq
          spurious_ids = log_ids - all_ids
          next if spurious_ids.empty?
          printf " -> %20s : %6d spurious entries", model.name, spurious_ids.size
          if yesno.()
            mainmodel.where(:ar_table_name => tablename, :ar_id => spurious_ids).delete_all
          end
        end
      end

      puts "\nChecking TaskWorkdirArchive"
      all_ids = TaskWorkdirArchive.pluck(:id)
      t_ids   = CbrainTask.pluck(:workdir_archive_userfile_id).compact
      spurious_ids = all_ids - t_ids
      if spurious_ids.present?
        printf " -> %6d spurious entries", spurious_ids.size
        if yesno.()
          puts "Hit RETURN at any time to stop the loop which erases these files"
          TaskWorkdirArchive.where(:id => spurious_ids).to_a.each_with_index do |t,i|
            if IO.select([STDIN],nil,nil,0.1).present?
              puts "#{Time.now.strftime('%H:%M:%S')} HALT"
              return
            end
            puts "#{Time.now.strftime('%H:%M:%S')} #{i+1}/#{spurious_ids.count} #{t.to_summary}"
            t.destroy
          end
        end
      end

      # Pairs must be listed in alphabetical order because the link table name
      # maintained by Rails is constructed that way.
      [ [ Group, User ], [ AccessProfile, User ], [ AccessProfile, Group ], [ Tag, Userfile] ].each do |pair|
        mod1,mod2 = *pair
        puts "\nChecking #{mod1.name}<->#{mod2.name} link table"
        linkmod = Class.new(ApplicationRecord)
        linkmod.table_name = mod1.name.underscore.pluralize + '_' + mod2.name.underscore.pluralize # e.g. groups_users
        m1_ids = mod1.pluck(:id)
        m2_ids = mod2.pluck(:id)
        mod1sym = (mod1.name.underscore + "_id").to_sym # :user_id
        mod2sym = (mod2.name.underscore + "_id").to_sym
        spurious_m1_ids = linkmod.group(mod1sym).pluck(mod1sym) - m1_ids
        spurious_m2_ids = linkmod.group(mod2sym).pluck(mod2sym) - m2_ids
        if spurious_m1_ids.present?
          printf " -> %6d spurious #{mod1.name} entries", spurious_m1_ids.size
          if yesno.()
            linkmod.where(mod1sym => spurious_m1_ids).delete_all
          end
        end
        if spurious_m2_ids.present?
          printf " -> %6d spurious #{mod2.name} entries", spurious_m2_ids.size
          if yesno.()
            linkmod.where(mod2sym => spurious_m2_ids).delete_all
          end
        end
      end

      puts "\nAll checks finished"
      true
    end # task :dump

  end # namespace :models
end # namespace :cbrain

