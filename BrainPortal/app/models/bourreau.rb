
#
# CBRAIN Project
#
# Original author: Pierre Rioux
#
# $Id$
#


#This model represents a remote execution server.
class Bourreau < RemoteResource

  Revision_info="$Id$"

  class BourreauInfo < ActiveResource::Base
  end

  # Checks if this Bourreau is available or not.
  def is_alive?
    self.update_info
    return false if @info.name == "???"
    true
  rescue
    false
  end

  # Returns this Bourreau's url.
  def site
    "http://" + remote_host + (remote_port && remote_port > 0 ? ":#{remote_port}" : "") + remote_dir
  end

  # Connects to the Bourreau's information channel and
  # get a record of run-time information. It is usually
  # better to call the info method instead, which will
  # cache the result if necessary.
  def update_info
    BourreauInfo.site    = self.site
    BourreauInfo.timeout = 10
    infos = BourreauInfo.find(:all)
    @info = infos[0]
    rescue
    @info = BourreauInfo.new(
      :name               => "???",
      :id                 => 0,
      :host_uptime        => "???",
      :bourreau_cms       => "???",
      :bourreau_cms_rev   => Object.revision_info,
      :bourreau_uptime    => "???",
      :tasks_max          => "???",
      :tasks_tot          => "???",
      :ssh_public_key     => "???",

      # Svn info
      :revision           => "???",
      :lc_author          => "???",
      :lc_rev             => "???",
      :lc_date            => "???",

      :dummy              => "hello"
    )
  end

  # Returns and cache a record of run-time information about the bourreau.
  # This method automatically calls update_info if the information has
  # not been cached yet.
  def info
    @info ||= self.update_info
    @info
  end

end
