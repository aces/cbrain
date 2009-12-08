
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
  
  has_many :user_preferences,  :dependent => :nullify

  # Start a Bourreau remotely. As a requirement for this to work,
  # we need the following attributes set in the Bourreau
  # object:
  #
  # *ssh_control_user*:: Mandatory
  # *ssh_control_host*:: Mandatory
  # *ssh_control_port*:: Optional, default 22
  # *ssh_control_rails_dir*:: Mandatory
  #
  # If DB and/or ActiveResource tunneling is enabled, the
  # remote Bourreau will be told to use the tunnels. This
  # implies that the remote database.yml will be rewritten
  # and the "-p port" option will be set to the value
  # of *tunnel_actres_port* instead of *actres_port*
  def start
    return false unless self.has_remote_control_info?
    return false unless RemoteResource.current_resource.is_a?(BrainPortal)
    bourreau_rails_home = self.ssh_control_rails_dir

    self.start_tunnels

    # If we tunnel the DB, we get a non-blank yml file here
    yml  = self.has_db_tunneling_info?     ? self.build_db_yml_for_tunnel : ""

    # What port the Rails Bourreau will listen to?
    port = self.has_actres_tunneling_info? ? self.tunnel_actres_port : self.actres_port

    # What environment will it run under?
    myrailsenv = ENV["RAILS_ENV"] || "production"

    # SSH command to start it up; we pipe to it either a new database.yml file
    # which will be installed, or "" which means to use whatever
    # yml file is already configured at the other end.
    captfile    = "/tmp/start.out.#{$$}"
    ssh_options = self.ssh_master.ssh_shared_options
    startcmd    = "ruby #{bourreau_rails_home}/script/cbrain_remote_ctl " +
                  "start -e #{myrailsenv} -p #{port}"
    dash_n      = yml.blank? ? "-n" : ""
    sshcmd = "ssh -x #{dash_n} #{ssh_options} #{startcmd} >'#{captfile}' 2>&1"
    IO.popen(sshcmd,"w") { |pipe| pipe.write(yml) }
    out = File.read(captfile) rescue ""
    File.unlink(captfile) rescue true
    return true if out =~ /Bourreau Started/i # output of 'cbrain_remote_ctl'
    false
  end

  # Stop a Bourreau remotely. The requirements for this to work are
  # the same as with start().
  def stop
    return false unless self.has_remote_control_info?
    return false unless RemoteResource.current_resource.is_a?(BrainPortal)
    bourreau_rails_home = self.ssh_control_rails_dir

    self.start_tunnels  # tunnels must be STARTed in order to STOP the Bourreau!

    # SSH command to start it up
    ssh_options = self.ssh_master.ssh_shared_options
    stopcmd = "ruby #{bourreau_rails_home}/script/cbrain_remote_ctl stop"
    sshcmd  = "ssh -n -x #{ssh_options} #{stopcmd}"
    confirm = ""
    IO.popen(sshcmd,"r") { |pipe| confirm = pipe.read }
    return true if confirm =~ /Bourreau Stopped/i # output of 'cbrain_remote_ctl'
    false
  end

  # This method adds Bourreau-specific information fields
  # to the RemoteResourceInfo object normally returned 
  # by the RemoteResource class method of the same name.
  def self.remote_resource_info
    info = super

    queue_tasks_tot_max = Scir::Session.session_cache.queue_tasks_tot_max
    queue_tasks_tot     = queue_tasks_tot_max[0]
    queue_tasks_max     = queue_tasks_tot_max[1]

    BourreauWorker.rescan_workers
    workers = BourreauWorker.all
    workers_pids = workers.map(&:pid).join(",")

    worker_revinfo    = BourreauWorker.revision_info
    worker_lc_rev     = worker_revinfo.svn_id_rev
    worker_lc_author  = worker_revinfo.svn_id_author
    worker_lc_date    = worker_revinfo.svn_id_datetime

    info.merge!(
      # Bourreau info
      :bourreau_cms       => CBRAIN::CLUSTER_TYPE,
      :bourreau_cms_rev   => Scir::Session.session_cache.revision_info,
      :tasks_max          => queue_tasks_max,
      :tasks_tot          => queue_tasks_tot,

      :worker_pids        => workers_pids,
      :worker_lc_rev      => worker_lc_rev,
      :worker_lc_author   => worker_lc_author,
      :worker_lc_date     => worker_lc_date
    )

    return info
  end

  protected

  def build_db_yml_for_tunnel #:nodoc:
    myrailsenv = ENV["RAILS_ENV"] || "production"
    myconfigs  = ActiveRecord::Base.configurations
    myconfig   = myconfigs[myrailsenv].dup

    myconfig["host"]   = "127.0.0.1"
    myconfig["port"]   = self.tunnel_mysql_port
    myconfig.delete("socket")

    yml = "\n" +
          "#\n" +
          "# File created automatically on Portal Side\n" +
          "# by " + self.revision_info.svn_id_pretty_file_rev_author_date + "\n" +
          "#\n" +
          "\n" +
          "#{myrailsenv}:\n"
    myconfig.each do |field,val|
       yml += "  #{field}: #{val.to_s}\n"
    end
    yml += "\n"
   
    yml
  end

end
