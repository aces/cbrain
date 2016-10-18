
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

class Signup < ActiveRecord::Base

  validate              :strip_blanks

  attr_accessible       :title, :first, :middle, :last,
                        :institution, :department, :position, :email,
                        :street1, :street2, :city, :province, :country, :postal_code,
                        :login, :time_zone, :comment

  validates_presence_of :first, :last,
                        :institution, :department, :position, :email,
                        :city, :province, :country, :confirm_token

  validates             :email, :format => { :with => /^(\w[\w\-\.]*)@(\w[\w\-]*\.)+[a-z]{2,}$|^\w+@localhost$/i }

  validate              :login_match_user_format

  def strip_blanks #:nodoc:
    [
      :title, :first, :middle, :last,
      :institution, :department, :position, :email,
      :street1, :street2, :city, :province, :country, :postal_code,
      :login, :comment
    ].each do |att|
      val = read_attribute(att) || ""
      write_attribute(att, val.strip)
    end
    self.login = (self.login.presence || "").downcase
    true
  end

  # Token inserted in email to new user to confirm their email
  def generate_token
    tok = ""
    tok += ("a".."z").to_a[rand(26)]
    19.times {
      c=sprintf("%d",rand(10)); tok += c
    }
    self.confirm_token = tok
  end

  def full #:nodoc:
    "#{title} #{first} #{middle} #{last}".strip.gsub(/  +/, " ")
  end

  alias full_name full

  def approved? #:nodoc:
    self.approved_by.present? && self.approved_at.present?
  end

  def dup_email? #:nodoc:
    User.exists?(:email => self.email)
  end

  def dup_login? #:nodoc:
    User.exists?(:login => self.login)
  end

  # Returns a new NormalUser (not saved in the DB yet) based
  # on the info in the current object.
  def to_user

    user = NormalUser.new

   #user.title                   = self.title
    user.full_name               = self.full.try :strip
    user.login                   = self.login.try :strip
    user.email                   = self.email.try :strip
   #user.institution             = self.institution
   #user.department              = self.department
   #user.position                = self.position
   #user.street1                 = self.street1
   #user.street2                 = self.street2
    user.city                    = self.city.try :strip
   #user.province                = self.province
    user.country                 = self.country.try :strip
   #user.postal_code             = self.postal_code
    user.time_zone               = self.time_zone
   #user.comment                 = self.comment

    user # do not save the object!
  end

  # Log additional info in user object log (until we find a place for it).
  # Here, +user+ is a properly created User object, presumably recently created.
  # This method is mostly used by the users controller, after a user is created
  # based on the information from the signup record.
  def add_extra_info_for_user(user) #:nodoc:
    [ :institution, :department, :position, :street1, :street2, :province, :postal_code ].each do |att|
      val = self[att]
      next if val.blank?
      user.addlog("#{att.to_s.capitalize}: #{val.strip}")
    end
  end

  #===============================================
  # ActiveRecord Callbacks
  #===============================================

  # This method invokes the User model's validators
  # to make suer the login provided by the user matches
  # the restrictions within CBRAIN.
  def login_match_user_format #:nodoc:
    return true if   self.login.blank?
    return true if ! self.login_changed?

    # Create a dummy user with only the login attribute
    dummy_user=User.new;dummy_user.login = self.login

    # Run the validations we have on the User model
    User.validators_on(:login).each do |validator|
      validator.validate(dummy_user)
    end

    # Copy error messages
    dummy_user.errors[:login].each { |m| self.errors[:login] = m }

    self.errors[:login].blank?
  end

end

