
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

#####################################################
# Current User / Current Project Utility Methods
#####################################################

def current_user #:nodoc:
  $_current_user
end

def current_project #:nodoc:
  $_current_project
end

# Sets the current user. Invoke on the
# console's command line with:
#
#   cu 'name'
#   cu id
#   cu /regex/
def cu(user=:show)
  return $_current_user if user == :show
  if user.nil? || user.is_a?(User)
    $_current_user = user
  elsif user.is_a?(Fixnum) || (user.is_a?(String) && user =~ /\A\d+\z/)
    $_current_user = User.find(user)
  elsif user.is_a?(String)
    $_current_user = User.where([ "(login like ?) OR (full_name like ?)", "%#{user}%", "%#{user}%" ]).first
  elsif user.is_a?(Regexp)
    $_current_user = User.all.detect { |u| (u.login =~ user) || (u.full_name =~ user) }
  else
    raise "Need a ID, User object, regex, or a string."
  end
  puts "Current user is now: #{$_current_user.try(:login) || "(nil)"}"
end

# Sets the current project. Invoke on the
# console's command line with:
#
#   cp 'name'
#   cp id
#   cp /regex/
def cp(group='show me')
  return $_current_project if group == 'show me'
  if group.nil? || group.is_a?(Group)
    $_current_project = group
  elsif group.is_a?(Fixnum) || (group.is_a?(String) && group =~ /\A\d+\z/)
    $_current_project = Group.find(group)
  elsif group.is_a?(Regexp)
    $_current_project = Group.all.detect { |g| g.name =~ group }
  elsif group.is_a?(String)
    $_current_project = Group.where([ "name like ?", "%#{group}%" ]).first
  else
    raise "Need a ID, Group object, regex or a string."
  end
  puts "Current project is now: #{$_current_project.try(:name) || "(nil)"}"
end

(CbrainConsoleFeatures ||= []) << <<FEATURES
========================================================
Feature: changing the current_user and current_group
========================================================
  Change user with      : cu 'name' ; cu id ; cu regex
  Change group with     : cp 'name' ; cp id ; cp regex
  Show current settings : cu ; cp
FEATURES

cu User.admin
cp nil

