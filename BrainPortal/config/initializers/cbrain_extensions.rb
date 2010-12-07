
#
# CBRAIN Project
#
# CBRAIN extensions
#
# Original author: Pierre Rioux
#
# $Id$
#

###################################################################
# CBRAIN ActiveRecord extensions
###################################################################
class ActiveRecord::Base

  ###################################################################
  # ActiveRecord Added Behavior For MetaData
  ###################################################################
  include ActRecMetaData
  after_destroy :destroy_all_meta_data

  ###################################################################
  # ActiveRecord Added Behavior For Logging
  ###################################################################
  include ActRecLog
  after_destroy :destroy_log

  alias original_to_xml to_xml
  
  def to_xml(options = {})
    options[:root] ||= self.class.to_s.gsub("::", "-")
    original_to_xml(options)
  end
end



###################################################################
# CBRAIN Kernel extensions
###################################################################
module Kernel

  # Raises a CbrainNotice exception, with a default redirect to
  # the current controller's index action.
  def cb_notify(message = "Something may have gone awry.", redirect = nil )
    raise CbrainNotice.new(message, redirect)
  end
  alias cb_notice cb_notify

  # Raises a CbrainError exception, with a default redirect to
  # the current controller's index action.
  def cb_error(message = "Some error occured.",  redirect = nil )
    raise CbrainError.new(message, redirect)
  end

end


###################################################################
# CBRAIN Patches To Mongrel
###################################################################
module Mongrel

  #
  # CBRAIN patches to its HTTP Server.
  #
  # These patches are mostly required by the CBRAIN methods
  # spawn_with_active_records(), spawn_with_active_records_if()
  # and spawn_fully_independent().
  #
  class HttpServer

    alias original_configure_socket_options configure_socket_options
    alias original_process_client           process_client

    # This is a patch to Mongrel::HttpServer to make sure
    # that Mongrel's internal listen socket is configured
    # with the close-on-exec flag.
    def configure_socket_options
      @socket.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC) rescue true
      @@cbrain_socket = @socket
      original_configure_socket_options
    end

    # This is a patch to Mongrel::HttpServer to make sure
    # that Mongrel's internal listen socket is configured
    # with the close-on-exec flag. We also record the two
    # socket endpoints of the server's HTTP channel, so
    # that we can quickly close them in the patch method
    # cbrain_force_close_server_socket()
    def process_client(client)
      @@cbrain_client_socket ||= {}
      @@cbrain_client_socket[Thread.current.object_id] = client
      original_process_client(client)
      @@cbrain_client_socket.delete(Thread.current.object_id)
    end

    # This CBRAIN patch method allows explicitely to close
    # Mongrel's main acceptor socket (stored in a class variable)
    # and the client's socket (stored in a class hash, by thread).
    def self.cbrain_force_close_server_socket
      begin
        @@cbrain_socket.close                                  rescue true
        @@cbrain_client_socket[Thread.current.object_id].close rescue true
      rescue
      end
    end
  
  end
end



###################################################################
# CBRAIN Extensions To Core Types
###################################################################

class Symbol

  # Used by views for CbrainTasks to transform a
  # symbol sych as :abc into a path to a variable
  # inside the params[] hash, as "cbrain_task[params][abc]".
  #
  # CBRAIN adds a similar method in the String class.
  def to_la
    "cbrain_task[params][#{self}]"
  end

end

class String

  # Used by views for CbrainTasks to transform a
  # string sych as "abc" or "abc[def]" into a path to a
  # variable inside the params[] hash, as in
  # "cbrain_task[params][abc]" or "cbrain_task[params][abc][def]"
  #
  # CBRAIN adds a similar method in the Symbol class.
  def to_la
    key = self
    if key =~ /^(\w+)/
      newcomp = "[" + Regexp.last_match[1] + "]"
      key.sub!(/^(\w+)/,newcomp)
    end
    "cbrain_task[params]#{key}"
  end

  # Considers self as a pattern to with substitutions
  # are to be applied; the substitutions are found in
  # self by recognizing keywords surreounded by
  # '{}' (curly braces) and those keywords are looked
  # up in the +keywords+ hash.
  #
  # Example:
  #
  #  mypat  = "abc{def}-{mach-3}{ext}"
  #  mykeys = {  :def => 'XYZ', 'mach-3' => 'fast', :ext => '.zip' }
  #  mypat.pattern_substitute( mykeys ) # return "abcXYZ-fast.zip"
  #
  # Note that keywords are limited to sequences of lowercase
  # characters and digits, like 'def', '3', or 'def23' or the same with
  # a number extension, like '4-34', 'def-23' and 'def23-3'.
  #
  # Options:
  #
  # :allow_unset, if true, allows substitution of an empty
  # string if a keyword is defined in the pattern but not
  # in the +keywords+ hash. Otherwise, an exception is raised.
  def pattern_substitute(keywords, options = {})
    pat_comps = self.split(/(\{(?:[a-z0-9_]+(?:-\d+)?)\})/i)
    final = ""
    pat_comps.each_with_index do |comp,i|
      if i.even?
        final += comp
      else
        comp.gsub!(/[{}]/,"")
        val = keywords[comp.downcase] || keywords[comp.downcase.to_sym]
        cb_error "Cannot find value for keyword '{#{comp.downcase}}'." if val.nil? && ! options[:allow_unset]
        final += val.to_s
      end
    end
    final
  end

end

class Array

  # Converts the array into a complex hash.
  # Runs the given block, passing it each of the
  # elements of the array; the block must return
  # a key that will be given to build a hash table.
  # The values of the hash table will be the list of
  # elements of the original array for which the block
  # returned the same key. The method returns the
  # final hash.
  #
  #   [0,1,2,3,4,5,6].hashed_partition { |n| n % 3 }
  #
  # will return
  #
  #   { 0 => [0,3,6], 1 => [1,4], 2 => [2,5] }
  def hashed_partition
    partitions = {}
    self.each do |elem|
       key = yield(elem)
       partitions[key] ||= []
       partitions[key] << elem
    end
    partitions
  end
  alias hashed_partitions hashed_partition
  
  def to_xml(options = {})
    raise "Not all elements respond to to_xml" unless all? { |e| e.respond_to? :to_xml }
    require 'builder' unless defined?(Builder)
  
    options = options.dup
    options[:root]     ||= "records"
    options[:indent]   ||= 2
    options[:builder]  ||= Builder::XmlMarkup.new(:indent => options[:indent])
  
    root     = options.delete(:root).to_s
    children = options.delete(:children)
  
    if !options.has_key?(:dasherize) || options[:dasherize]
      root = root.dasherize
    end
  
    options[:builder].instruct! unless options.delete(:skip_instruct)
  
    opts = options.clone
  
    xml = options[:builder]
    if empty?
      xml.tag!(root, options[:skip_types] ? {} : {:type => "array"})
    else
      xml.tag!(root, options[:skip_types] ? {} : {:type => "array"}) {
        yield xml if block_given?
        each { |e| e.to_xml(opts.merge({ :skip_instruct => true })) }
      }
    end
  end
  
end



