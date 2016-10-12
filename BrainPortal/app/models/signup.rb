
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

  # This is the method that actually creates the user in CBRAIN's database
  def after_approval

    res             = ApprovalResult.new

    unless self.valid?
      res.diagnostics = "Account request invalid:\n" + self.errors.full_messages.join("\n")
      return res
    end

    if self.dup_login?
      res.diagnostics = "Failed to create user '" + self.login + "', as it already exists."
      return res
    end

    # Attempt to create the user
    pass = User.random_string

    u = User.new
    #u.title                   = self.title
    u.full_name               = self.full.try :strip
    u.login                   = self.login.try :strip
    u.email                   = self.email.try :strip
    #u.institution             = self.institution
    #u.department              = self.department
    #u.position                = self.position
    #u.street1                 = self.street1
    #u.street2                 = self.street2
    u.city                    = self.city.try :strip
    #u.province                = self.province
    u.country                 = self.country.try :strip
    #u.postal_code             = self.postal_code
    u.time_zone               = self.time_zone
    #u.comment                 = self.comment
    u.type                    = 'NormalUser'
    u.password                = pass
    u.password_confirmation   = pass
    u.password_reset          = true

    if ! u.save()
      res.diagnostics = "Could not save user:\n" + u.errors.full_messages.join("\n")
      return res
    end

    # Log additional info in user object log (until we find a place for it).
    [ :institution, :department, :position, :street1, :street2, :province, :postal_code ].each do |att|
      val = self[att]
      next if val.blank?
      u.addlog("#{att.to_s.capitalize}: #{val.strip}")
    end

    # Returns information about the success
    res.plain_password = pass
    res.diagnostics    = "Created as UID #{u.id}"
    res.user           = u
    res.success        = true

    res
  end

  # Used internally to represent the result of
  # trying to approve one signup request,
  class ApprovalResult #:nodoc:
    attr_accessor :diagnostics, :plain_password, :success
    attr_accessor :user

    def initialize #:nodoc:
      self.success     = false
      self.diagnostics = ""
    end

    def to_s #:nodoc:
      self.diagnostics.presence.to_s
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

