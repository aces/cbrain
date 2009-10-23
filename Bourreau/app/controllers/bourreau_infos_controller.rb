
#
# CBRAIN Project
#
# Info Controller for Bourreau
#
# $Id$
#

# A simple controller that returns run-time information about
# the current Bourreau.
class BourreauInfosController < ApplicationController

  Revision_info="$Id$"

  before_filter :start_bourreau_workers

  # GET /bourreau_infos.xml
  # The only supported HTTP call is 'GET /bourreau_infos.xml', which
  # returns an array of a single XML object of type BourreauInfo
  def index #:nodoc:

    @info = generate_info
    @infos = [ @info ]

    respond_to do |format|
      format.html { head :method_not_allowed }
      format.xml  { render :xml => @infos.to_xml }
    end
  end

  #######################################################################
  private
  #######################################################################

  def generate_info
    me = Bourreau.find_by_name(CBRAIN::BOURREAU_CLUSTER_NAME)

    home = CBRAIN::Rails_UserHome
    
    host_uptime    = `uptime 2>/dev/null`.strip   # TODO make more robust
    elapsed        = Time.now.localtime - CBRAIN::Startup_LocalTime
    ssh_public_key = `cat #{home}/.ssh/id_rsa.pub 2>/dev/null`   # TODO make more robust

    queue_tasks_tot_max = Scir::Session.session_cache.queue_tasks_tot_max
    queue_tasks_tot     = queue_tasks_tot_max[0]
    queue_tasks_max     = queue_tasks_tot_max[1]

    revinfo = { 'Revision'            => 'unknown',
                'Last Changed Author' => 'unknown',
                'Last Changed Rev'    => 'unknown',
                'Last Changed Date'   => 'unknown'
              }

    IO.popen("svn info #{RAILS_ROOT} 2>/dev/null","r") do |fh|
      fh.each do |line|
        if line.match(/^Revision|Last Changed/i)
          comps = line.split(/:\s*/,2)
          field = comps[0]
          value = comps[1]
          revinfo[field]=value
        end
      end
    end

    BourreauWorker.rescan_workers
    workers = BourreauWorker.all
    workers_pids = workers.map(&:pid).join(",")

    info = BourreauInfo.new.merge(   # not an active record
      :name               => CBRAIN::BOURREAU_CLUSTER_NAME,
      :id                 => me.id,
      :bourreau_cms       => CBRAIN::CLUSTER_TYPE,
      :bourreau_cms_rev   => Scir::Session.session_cache.revision_info,
      :host_uptime        => host_uptime,
      :bourreau_uptime    => elapsed,
      :tasks_max          => queue_tasks_max,
      :tasks_tot          => queue_tasks_tot,
      :ssh_public_key     => ssh_public_key,
      :worker_pids        => workers_pids,

      # Svn info
      :revision           => revinfo['Revision'],
      :lc_author          => revinfo['Last Changed Author'],
      :lc_rev             => revinfo['Last Changed Rev'],
      :lc_date            => revinfo['Last Changed Date'],

      :dummy              => 'hello'
    )

    return info
  end

end
