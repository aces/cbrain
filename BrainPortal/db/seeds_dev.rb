#
# Seed for CBRAIN developers
# 
# Create lots and lots of records
#
# * Fake Users
# * Fake Groups
# * Fake Sites
# * Fake DataProviders
# * Fake Bourreaux
# * Fake Tasks
# * Fake Files
#

require 'readline'
require 'socket'

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

raise "The seeding process must be run by a process connected to a terminal" unless
  STDIN.tty? && STDOUT.tty? && STDERR.tty?
stty_save = `stty -g`.chomp
trap('INT') { system('stty', stty_save) ; puts "\n\nInterrupt. Exiting."; exit(0) }
hostname = Socket.gethostname

print <<INTRO

===========================================================
CBRAIN seeding process for developers.

This code will install lots of records in the DB to
create a system with enough data to actually help
develop it.

You can run it multiple times without fear.
===========================================================

INTRO



puts <<STEP
----------------------------
Step 1: Sites
----------------------------

STEP

long_site = Site.seed_record!(
 { :name => 'Longbourne' },
 { :description => "Hertfordshire\n\nA nice little place in the countryside" }
)
nether_site = Site.seed_record!(
 { :name => 'Netherfield Park' },
 { :description => "Hertfordshire\n\nA larger place in the countryside" }
)
pember_site = Site.seed_record!(
 { :name => 'Pemberley' },
 { :description => "Devonshire\n\nA great place in the countryside" }
)
puts ""



puts <<STEP
----------------------------
Step 2: Users
----------------------------

STEP

[ "Mr", "Jane", "Elizabeth", "Catherine", "Mary", "Lydia" ].each do |first|
  login = first == "Mr" ? "mrbennet" : "#{first[0].downcase}bennet"
  User.seed_record!(
    { :full_name => "#{first} Bennet",
      :login     => login
    },
    {
      :email     => "#{login}@localhost",
      :role      => (first == "Mr" ? :site_manager : :user),
      :site_id   => long_site.id,
      :time_zone => 'UTC',
      :city      => 'Meryton',
      :country   => 'England',
      :account_locked => (first == "Lydia")
    },
    { :info_name_method => :login }
  ) do |u|
    u.password              = u.login
    u.password_confirmation = u.login
  end
end

[ "Charles Bingley", "Caroline Bingley" ].each do |full|
  names=full.split(/ /)
  first = names[0]
  last  = names[1]
  login = "#{first[0,2].downcase}#{last.downcase}"
  User.seed_record!(
    { :full_name => full,
      :login     => login,
    },
    {
      :email     => "#{login}@localhost",
      :role      => (full == "Charles Bingley" ? :site_manager : :user),
      :site_id   => nether_site.id,
      :time_zone => 'UTC',
      :city      => 'Meryton',
      :country   => 'England',
      :account_locked => false
    },
    { :info_name_method => :login }
  ) do |u|
    u.password              = u.login
    u.password_confirmation = u.login
  end
end

[ "Mr Darcy", "Georgiana Darcy", "George Wickham" ].each do |full|
  names=full.split(/ /)
  first = names[0]
  last  = names[1]
  login = "#{first[0,2].downcase}#{last.downcase}"
  User.seed_record!(
    { :full_name => full,
      :login     => login,
    },
    {
      :email     => "#{login}@localhost",
      :role      => (full == "Mr Darcy" ? :site_manager : :user),
      :site_id   => pember_site.id,
      :time_zone => 'UTC',
      :city      => 'Pemberley',
      :country   => 'England',
      :account_locked => (full == "George Wickham")
    },
    { :info_name_method => :login }
  ) do |u|
    u.password              = u.login
    u.password_confirmation = u.login
  end
end

[ "Charlotte Lucas", "William Collins", "Mr Gardiner" ].each do |full|
  names=full.split(/ /)
  first = names[0]
  last  = names[1]
  login = "#{first[0,2].downcase}#{last.downcase}"
  User.seed_record!(
    { :full_name => full,
      :login     => login,
    },
    {
      :email     => "#{login}@localhost",
      :role      => :user,
      :site_id   => nil,
      :time_zone => 'UTC',
      :city      => nil,
      :country   => 'England',
      :account_locked => false
    },
    { :info_name_method => :login }
  ) do |u|
    u.password              = u.login
    u.password_confirmation = u.login
  end
end


