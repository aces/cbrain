#
# Seed for CBRAIN
#

require 'readline'
require 'socket'

#
# ActiveRecord extensions for seeding
#
class ActiveRecord::Base

  def self.seed_record!(attlist, create_attlist = {}) # some gems like "seed_fu" already define a "seed" method
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
      return exist
    end

    # More than one exists? Die.
    raise "Several (#{exists.size}) #{top_superclass.name} objects already exists with these attributes."
  end

end

#
# Seeding steps starts here
#

raise "The seeding process must be run by a process connected to a terminal" unless
  STDIN.tty? && STDOUT.tty? && STDERR.tty?

print <<INTRO

-----------------------------------------------------------
CBRAIN seeding process.

This code will install the minimum amount of information
in CBRAIN to get a working system.

You can run it multiple times without fear.
-----------------------------------------------------------

INTRO

# Interactive questions.
puts "Enter a name (a simple identifier) for the portal."
puts ""
print "Portal name: "
portal_name = Readline.readline
raise "Invalid name for the portal." if portal_name.blank? || portal_name !~ /^[a-z]\w+$/i

puts "Enter a password for the admin user. If the admin user"
puts "already exists, this will reset it. Leave blank to leave"
puts "the existing password unchanged."
print "Admin's password: "
passwd = Readline.readline #todo : noecho

# Create the 'everyone' group.
everyone = SystemGroup.seed_record!(
  {
     :name  => "everyone"
  }
)

# Create admin user.
admin = User.seed_record!(
  {
    :login     => 'admin',
    :role      => 'admin'
  },
  {
    :full_name             => "CBRAIN Administrator",
    :email                 => "nobody@#{Socket.gethostname}"
  }
) do |u|
  unless passwd.blank?
    u.password              = passwd
    u.password_confirmation = passwd
  end
end

# Update creator ID for the two system groups
admin.own_group.update_attributes!(:creator_id => admin.id)
everyone.update_attributes!(:creator_id => admin.id)

# Create portal object
portal = BrainPortal.seed_record!(
  {
    :user_id     => admin.id,
    :group_id    => everyone.id
  },
  {
    :name        => portal_name,
    :online      => true,
    :read_only   => false,
    :description => 'CBRAIN BrainPortal on host ' + Socket.gethostname
  }
)

