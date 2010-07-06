
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
  def to_la
    "cbrain_task[params][#{self}]"
  end

end

class String

  # Used by views for CbrainTasks to transform a
  # string sych as "abc" or "abc[def]" into a path to a
  # variable inside the params[] hash, as in
  # "cbrain_task[params][abc]" or "cbrain_task[params][abc][def]"
  def to_la
    key = self
    if key =~ /^(\w+)/
      newcomp = "[" + Regexp.last_match[1] + "]"
      key.sub!(/^(\w+)/,newcomp)
    end
    "cbrain_task[params]#{key}"
  end

end
