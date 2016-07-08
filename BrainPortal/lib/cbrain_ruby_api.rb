
require 'active_support/core_ext'
require 'httpclient'
require 'xmlsimple'

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
# GNU General Public License for more details.query
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# == SYNOPSIS
#
#   require 'cbrain_ruby_api'
#   puts "This is CbrainRubyAPI version #{CbrainRubyAPI::VERSION}"
#
# == DESCRIPTION
#
# The CbrainRubyAPI class is a ruby class that provides a simple
# user agent for connecting to CBRAIN portal servers.
#
#
#
# == SIMPLE USAGE
#
#   require 'cbrain_ruby_api'
#
#   # Create our API user agent
#   agent = CbrainRubyAPI.new(
#      :cbrain_server_url => "https://example.com:abcd/",
#   )
#
#   # Login
#   agent.login("username","my*Pass*Word")
#
#   # Register a file named 'abcd.txt' as a CBRAIN 'TextFile',
#   # which happens to be visible on CBRAIN SshDataProvider #6 .
#   # This assumes the files is there, and the DP is online
#   # and accessible to the current user.
#   agent.register_file('abcd.txt', 'TextFile', 6)
#
class CbrainRubyAPI

  # Version number of this API
  VERSION = "1.2"

  # This is a wrapper class to hold the HTTP connection parameters
  # until we are ready to do the request proper using 'httpclient'.
  # This class stores and provides methods to access attributes
  # such as method, url, params etc.
  # See the request() method of httpclient for more information,
  # since this is utilimately what these attributes are for.
  #
  # Typical usage:
  #
  #   ua  = httpclient.new(stuff)
  #   req = CbrainHttpRequest.new(:get, "/users")
  #   req.params.merge! :page => 2
  #   # fetches  http://stuff/users?page=2
  #   reply = req.request(ua)  # returns a HttpMessage from httpclient lib
  #
  # The attributes headers, params and body can all be strings or arrays
  # or hashes, as is supported by httpclient. Choose one and stick to it.
  class CbrainHttpRequest

    # Method name, usually a symbol such as :post or :GET (case insensitive)
    attr_accessor :method

    # Relative URL, such as '/users' or /groups/2'
    attr_accessor :url

    # Also known as query params, will be appended to URI. Default is empty hash.
    attr_accessor :params

    # Special headers for your request, default is empty hash
    attr_accessor :headers

    # Custom body, default is nil
    attr_accessor :body

    # When creating a new CbrainHttpRequest, you need to supply
    # two arguments:
    #
    #   method is one of :get, :post, :delete etc
    #   url    is the base of the httpclient service you plan to use
    #
    # other arguments are optional, and will be passed on to
    # the httpclient#request method as-is.
    #
    # All of them are accessible as object attributes.
    def initialize(method, url, params = {}, headers = {}, body = nil)
      @method  = method
      @url     = url
      @params  = params
      @headers = headers
      @body    = body
    end

    # Given a httpclient object ua, invokes its request() method
    # with the content of the internal instance variables.
    def httpclient_request(ua)
      #puts "METHOD=#{@method} URL=#{@url} PARAMS=#{@params.inspect} HEADERS=#{@headers.inspect}"
      ua.request(@method, @url, @params, @body, @headers)
    end
  end

  # After invoking the request() method, the returned HttpMessage object
  # can be found here.
  attr_accessor :raw_reply



  # Creates a new CBRAIN user agent. The first argument is required and must be
  # the prefix to the server's web site.
  #
  # Options:
  #
  # cookie_store_file:: a text file where cookies will be stored. By
  #                     default, the module will save them in a temporary file in /tmp.
  #
  # Example:
  #
  #   agent = CbrainRubyAPI.new( 'http://example.com:3000/',
  #              cookie_store_file => "$HOME/my_persistent_store.txt",
  #           )
  def initialize(cbrain_server_url, options = {})
    options      = { :cookie_store => options } if options.is_a?(String)
    cookie_store = options[:cookie_store] || "/tmp/cbrain_cookies.#{$$}.txt"
    @user                 = nil
    @ua                   = nil
    @auth_token           = nil
    @cbrain_server_url    = cbrain_server_url.sub(/\/*$/,"/") # force just one single / at the end
    @cookie_store_file    = cookie_store
    reset_status
    self
  end



  # Connects to the server, supplies the credentials
  # and maintains the tokens necessary for the session.
  #
  # Example:
  #
  #   res = agent.login('jack', '&jill')
  def login(user,password)
    @ua = HTTPClient.new(nil, user_agent_string())
    @ua.set_cookie_store(@cookie_store_file)

    # Login to CBRAIN
    prep_req(:get, '/session/new')
    unless request()
      @cbrain_error_message = "Cannot connect to server: #{@raw_reply.reason}"
      return false
    end

    # Extract token
    logform_content = @raw_reply.content
    if logform_content.blank? || ! logform_content.match(/<authenticity_token>(.+)<\/authenticity_token>/)
      @cbrain_error_message = "Cannot obtain authentication token?!? Server response:\n#{logform_content}"
      return false
    end
    @auth_token = Regexp.last_match[1]

    # Post login/password
    prep_req(:post, '/session')
    add_params( :login => user, :password => password )
    unless request()
      @cbrain_error_message = "Cannot login: #{@raw_reply.reason}"
      return false
    end

    @user           = user
    @cbrain_success = true
    true
  end



  # Disconnect from the server.
  #
  # Example:
  #
  #  agent.logout();
  #
  def logout
    prep_req(:get, '/logout')
    unless request()
      @cbrain_error_message = "Cannot logout: #{@raw_reply.reason}"
      return false
    end
    destroy_cookie_store()
    @cbrain_success = true
    @user           = nil
    @ua             = nil
    true
  end

  def destroy_cookie_store #:nodoc:
    unlink @cookie_store_file rescue false
  end



  # Creates a new user. Returns the ID of the created user.
  #
  #   att = {
  #     "full_name"             => 'Mack The Knife',
  #     "login"                 => "mtheknife",
  #     "email"                 => 'pierre.rioux@mcgill.ca',
  #     "city"                  => 'Paris',
  #     "country"               => 'France',
  #     "time_zone"             => 'Mazatlan',
  #     "type"                  => 'NormalUser',
  #     "password"              => 'qwer1234ABC',
  #     "password_confirmation" => 'qwer1234ABC'
  #     }
  #   uid = agent.create_user( att )
  def create_user(attributes)
    prep_req(:post, '/users')
    rails_att = Hash[attributes.map { |k,v| [ "user[#{k}]", v ] }] # [ [ "user[login]", 'prioux' ],  [ "user[email]", 'a@b.c' ] ... ]
    add_params(rails_att)
    add_params(:no_password_reset_needed => 1)
    unless request()
      @cbrain_error_message = "Cannot create user: #{@raw_reply.reason}"
      return nil
    end
    xml_content = @raw_reply.content
    if xml_content.blank? || ! xml_content.match(/>(\d+)<\/id>/)
      @cbrain_error_message = "Cannot find ID of created user: #{xml_content}"
      return nil
    end
    id = Regexp.last_match[1].to_i
    @cbrain_success = true
    return id
  end



  # Destroy a user.
  #
  #   agent.destroy_user(123)
  def destroy_user(id)
    prep_req(:delete, "/users/#{id.to_i}")
    unless request()
      @cbrain_error_message = "Cannot delete user: #{@raw_reply.reason}"
      return false
    end
    @cbrain_success = true
    return true
  end



  # Fetch the user structure associated with a user ID. The
  # result is a hash table created by XmlSimple to represent
  # the structure.
  #
  #   uinfo = agent.show_user(2)
  #   puts "Full name: ", uinfo['full-name']"
  def show_user(id)
    prep_req(:get, "/users/#{id.to_i}")

    unless request
      @cbrain_error_message = "Cannot get user: #{@raw_reply.reason}"
      return false
    end

    # Parse XML
    begin
      parsed = XmlSimple.xml_in(@raw_reply.content)
    rescue => e
      @cbrain_error_message = "Cannot parse XML for user: #{e.message}"
      return false
    end

    return parsed
  end



  # Fetch a list of users. Optionally, fitlers can be passed in
  # to restrict the list to some subset. Each entry in the returned
  # list is a structure as created by XmlSimple .
  #
  #   users = agent.index_users( :city => "Montreal" )
  def index_users(filters = {})
    prep_req(:get, "/users/")
    add_params(filters)
    add_params(:update_filter => :filter_hash, :clear_filter => :filter_hash)

    unless request
      @cbrain_error_message = "Cannot get users: #{@raw_reply.reason}"
      return false
    end

    # Parse XML
    begin
      parsed  = XmlSimple.xml_in(@raw_reply.content)
      array   = parsed["object"] || parsed["core-admin"] || parsed["site-manager"] || parsed["normal-user"] || []
    rescue => e
      @cbrain_error_message = "Cannot parse XML for user: #{e.message}"
      return false
    end

    return array
  end



  # Returns true if the last operation succeeded.
  def cbrain_success
    @cbrain_success
  end



  # Returns an informative error message about
  # the last operation that failed.
  def error_message
    @cbrain_error_message
  end



  # Resets the internal values for the two API status
  # methods, the error_message() and the cbrain_success().
  # This method is mostly called internally by other methods
  # that do interesting stuff.
  def reset_status
    @cbrain_success        = false
    @cbrain_error_message  = ""
    @raw_reply             = nil
  end



  private

  # Prepares a request for the CBRAIN server. The first argument
  # must be a HTTP action (one of :POST, :GET, :PUT or :DELETE).
  # The second argument is relative path to append to the URL of
  # the CBRAIN agent main's URI.
  def prep_req(action, path)
    raise "Not logged in."       unless @ua
    reset_status
    path = path.sub(/^\/*/,"") # remove leading "/"
    uri  = "#{@cbrain_server_url}#{path}"
    @_cur_req = CbrainHttpRequest.new(action, uri)
    @_cur_req.headers.merge! 'Accept' => 'text/xml'
    @_cur_req
  end



  # Once a request has been prepared with prep_req() and
  # parameters added to it with add_params(),
  # the request can be sent to the CBRAIN server by calling
  # this method. The returned value is true or false
  # based on the HTTP request's status.
  #
  #   ok = agent.request()
  def request
    raise "Not logged in."       unless @ua
    raise "No request prepared." unless @_cur_req
    if @_cur_req.method.to_s =~ /GET|HEAD/i
      # nothing special to do for the moment
    else # POST, DELETE etc
      @_cur_req.headers.merge! 'Content-Type' => 'application/x-www-form-urlencoded'
      @_cur_req.body        ||= {}
      @_cur_req.body.merge! 'authenticity_token' => @auth_token
    end
    @raw_reply     = @_cur_req.httpclient_request(@ua)
    @_cur_req      = nil
    @raw_reply.ok?
  end



  def user_agent_string #:nodoc:
    return @_user_agent_string if @_user_agent_string
    os_name             =  `uname -s 2>/dev/null`.strip.presence || "UnknownOS"
    rev_name            =  `uname -r 2>/dev/null`.strip.presence || "UnknownRev"
    @_user_agent_string = "#{self.class}/#{VERSION} #{os_name}/#{rev_name}"
  end



  # Once a request has been prepared with prep_req(),
  # this method can be use to add parameters to it.
  # This method can be called several times to add as
  # many parameters as necessary.
  #
  #   agent.add_params( :paramname        => "somevalue" )
  #   agent.add_params( "user[full_name]" => "Pierre Rioux" )
  #
  # Parameters will automatically be included in the BODY of
  # the HTTP request of it is a POST, PUT or DELETE, and
  # automatically appended to the request URI if it is a GET
  # or HEAD.
  def add_params(params)
    raise "Not logged in."       unless @ua
    raise "No request prepared." unless @_cur_req
    if @_cur_req.method.to_s =~ /GET|HEAD/i
      uri_escape_params(params)
    else
      content_escape_params(params)
    end
  end



  def uri_escape_params(params) #:nodoc:
    raise "Not logged in."       unless @ua
    raise "No request prepared." unless @_cur_req
    @_cur_req.params.merge! params
    self
  end



  def content_escape_params(params) #:nodoc:
    raise "Not logged in."       unless @ua
    raise "No request prepared." unless @_cur_req
    @_cur_req.body        ||= {}
    @_cur_req.body.merge! params
    self
  end

end
