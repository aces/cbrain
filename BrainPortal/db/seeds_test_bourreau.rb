
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

#
# Seed for CBRAIN Bourreau Tests
#
# Create just the minimal necessary records for
# running tests on the bourreau code side.
#

require 'readline'
require 'socket'
require 'etc'

#
# ActiveRecord extensions for seeding
#
class ActiveRecord::Base

  def self.seed_record!(attlist, create_attlist = {}, options = { :info_name_method => :name })
    raise "Bad attribute list." if attlist.blank? || ! attlist.is_a?(Hash)

    top_superclass = self
    while top_superclass.superclass < ActiveRecord::Base
      top_superclass = top_superclass.superclass
    end

    exists = top_superclass.where(attlist).all

    # None exists? Create one.
    if exists.empty?
      new_record = self.new()
      attlist.merge(create_attlist).each do |att,val|
        new_record.send("#{att}=",val)
      end
      yield(new_record) if block_given?
      new_record.save!
      puts "#{new_record.class} '#{new_record.send(options[:info_name_method])}' : created." if options[:info_name_method]
      return new_record
    end

    # One exists? Check it.
    if exists.size == 1
      exist = exists[0]
      raise "Tried to seed a record of class #{self.name} but found one of class #{exist.class.name} !" unless exist.is_a?(self)
      create_attlist.each do |att,val|
        exist.send("#{att}=",val)
      end
      # Check other properties here?
      yield(exist) if block_given?
      exist.save!
      puts "#{exist.class} '#{exist.send(options[:info_name_method])}' : updated." if options[:info_name_method]
      return exist
    end

    # More than one exists? Die.
    raise "Several (#{exists.size}) #{top_superclass.name} objects already exists with these attributes."
  end

end

#------------------------------------------------
# Seeding steps starts here
#------------------------------------------------

trap('INT') { puts "\n\nInterrupt. Exiting."; exit(0) }
hostname = Socket.gethostname

myself = RemoteResource.current_resource
raise "You can only run this seeding process as a BrainPortal CBRAIN application!" unless
  myself.is_a?(BrainPortal)
myrailsenv = Rails.env || "production"
raise "You can only run this seeding process under a 'test' Rails environement!" unless
  myrailsenv =~ /test/

unix_user  = Etc.getpwuid(Process.uid).name rescue ENV['USER']
rails_home = Rails.root.to_s

print <<INTRO

===========================================================
CBRAIN seeding process for testing the Bourreau.

This code will install some records needed in a test
database such that the testing code for the bourreau side
can operated properly.

A standard seeding process of the test database should already
have been run (with "rake db:seed #{myrailsenv}").

You can run it multiple times without fear.
===========================================================
INTRO

puts <<BASE_DIR

All data files (Data Providers, cache directories, bourreau
work directories etc) will be created in? (enter a path or keep the supplied default)
BASE_DIR

default_support_dir     = "#{rails_home}/seeds_dev_support_dir"
print "[#{default_support_dir}] "
seeds_dev_support_dir   = STDIN.tty? ? STDIN.gets.strip.presence : nil
seeds_dev_support_dir ||= default_support_dir
Dir.mkdir(seeds_dev_support_dir) unless Dir.exists?(seeds_dev_support_dir)

puts <<STEP

----------------------------
Step 1: Bourreau Record
----------------------------

STEP

main_bourreau_dir       = (Pathname.new(rails_home).parent + "Bourreau").to_s # BrainPortal/../Bourreau
main_bourreau_gridshare = "#{seeds_dev_support_dir}/test_bourreau_gridshare"
main_bourreau_dp_cache  = "#{seeds_dev_support_dir}/test_bourreau_dp_cache"

Dir.mkdir(main_bourreau_gridshare) unless Dir.exists?(main_bourreau_gridshare)
Dir.mkdir(main_bourreau_dp_cache)  unless Dir.exists?(main_bourreau_dp_cache)

main_bourreau = Bourreau.seed_record!({
    :ssh_control_rails_dir => main_bourreau_dir,
    :cms_shared_dir        => main_bourreau_gridshare,
    :dp_cache_dir          => main_bourreau_dp_cache
  },
  {
    :name => "Test_Bourreau_Exec", :description => "Execution Server For Testing",
    :user_id => User.admin.id, :group_id => Group.everyone.id,
    :ssh_control_user => unix_user, :ssh_control_host => hostname,
    :tunnel_mysql_port  => 29732, :tunnel_actres_port => 29733,
    :online => true, :read_only => false,
    :cms_class => 'ScirUnix',
    :workers_instances => 1, :workers_chk_time => 60, :workers_log_to => 'combined', :workers_verbose => 1
  }
)

