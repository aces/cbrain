
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

# Controller for the Service.
# Implement actions as defined by the CANARIE Web Service Monitoring API.
#
# By default, all these actions are commented out in the route.rb file,
# so for most installations this controller is NOT USED at all.
class ServiceController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  api_available

  # Return basic identification and provenance
  # information about the platform
  def info
    @info = { :name            => "CBRAIN Data Service",
              :synopsis        => "A service that leverages the previously-funded
                                   \"Canadian Brain Research And Informatics Network\"
                                   platform to provide the research community with
                                   web-based access to powerful supercomputers across
                                   Canada and around the world.".gsub(/\s\s+/, " "),  # the ugly gsub is because of CANARIE
              :version         => CbrainFileRevision.cbrain_head_tag,
              :institution     => "McGill University",
              :releaseTime     => Time.parse(CbrainFileRevision.cbrain_head_revinfo.datetime).utc.iso8601,
              :researchSubject => "Multi-discipline",
              :supportEmail    => RemoteResource.current_resource.support_email,
              :category        => "Data Manipulation",
              :tags            => [ "neurology", "CBRAIN", "data transfer", "cluster",
                                    "supercomputer", "task", "data modeling", "visualization",
                                  ],
           }

    respond_to do |format|
      format.html
      format.xml  { render :xml  => @info }
      format.json { render :json => @info }
    end
  end

  # Return information about the usage of the platform.
  def stats
    stats             = RemoteResource.current_resource.meta[:stats] || {}
    (stats_by_client,stats_by_contr_action) = compile_total_stats(stats)

    @summary_stats                 = Hash[stats_by_client.collect { |client, counts| [ client , counts.sum ] } ]
    @last_reset                    = (RemoteResource.current_resource.meta.md_for_key(:stats).created_at || Time.at(0)).utc.iso8601
    authenticated_actions          = count_authenticated_actions(stats_by_contr_action)
    @summary_stats["TotalActions"] = authenticated_actions
    @summary_stats["lastReset"]    = @last_reset

    # CANARIE only wants TWO fields. :-(
    @json_stats = {
        "Total Actions" => authenticated_actions,
        "lastReset"     => @last_reset,
    }

    respond_to do |format|
      format.html
      format.xml  { render :xml  => @summary_stats }
      format.json { render :json => @json_stats }
    end
  end

  # Return the online documentation.
  def doc
    @doc = { :description => <<-DESCRIPTION,

             The CBRAIN Framework is a sophisticated piece of software
             that provides numerous layers for storing data sets,
             moving them about, launching tasks on supercomputers clusters
             and managing all of that through a Web interface or external APIs.

             DESCRIPTION
             :perl_doc_text   => "/doc/APIs/perl/CbrainPerlAPI.txt",    # must be a URL
             :perl_doc_html   => "/doc/APIs/perl/CbrainPerlAPI.html",   # must be a URL
             :ruby_doc_html   => "/doc/APIs/ruby/CbrainRubyAPI.html"    # must be a URL
           }

    respond_to do |format|
      format.html
      format.xml  { render :xml  => @doc }
      format.json { render :json => @doc }
    end
  end

  # Return release note describing the current version
  # of the platform APIs.
  def releasenotes
    redirect_to 'https://github.com/aces/cbrain-apis/blob/master/Release-Notes.md'
  end

  # Provides information on how to get support
  # for the platform.
  def support
    about_us_url =  url_for(:controller => :portal, :action => :about_us)
    @support     = { :supportEmail => RemoteResource.current_resource.support_email,
                     :aboutUs      => about_us_url,
                   }

    respond_to do |format|
      format.html
      format.xml  { render :xml  => @support }
      format.json { render :json => @support }
    end
  end

  # Return link to the source code of the APIs for the platform
  def source
    redirect_to 'https://github.com/aces/cbrain-apis'
  end

  # Redirects to the main login page.
  def tryme
    redirect_to 'https://github.com/aces/cbrain-apis/blob/master/demonstration.pdf'
  end

  # Allows users to view platform's
  # licencing/usage term.
  def licence
    respond_to do |format|
      format.html  { redirect_to :controller => :portal, :action => :about_us }
      format.xml   { head :not_acceptable }
      format.json  { head :not_acceptable }
    end
  end

  # Allows user to view the software provenance
  def provenance
    respond_to do |format|
      format.html  { redirect_to :controller => :portal, :action => :about_us }
      format.xml   { head :not_acceptable }
      format.json  { head :not_acceptable }
    end
  end


  # Return information about the usage of the platform.
  def detailed_stats
    @stats             = RemoteResource.current_resource.meta[:stats] || {}
    (@stats_by_client,@stats_by_contr_action) = compile_total_stats(@stats)
    @last_reset        = (RemoteResource.current_resource.meta.md_for_key(:stats).created_at || Time.at(0)).utc.iso8601
    @stats[:lastReset] = @last_reset

    respond_to do |format|
      format.html
      format.xml  { render :xml  => @stats }
      format.json { render :json => @stats }
    end
  end

  private

  # From the raw stats accumulated for all clients,
  # controllers and actions, compile two other
  # secondary stats: the sums by clients, and
  # the sums by pair "controller,service".
  def compile_total_stats(stats={}) #:nodoc:
    stats_by_client       = {}
    stats_by_contr_action = {}

    stats.each do |client, by_controller|
      next unless by_controller.is_a?(Hash)
      by_controller.each do |controller, by_action|
        next unless by_action.is_a?(Hash)
        by_action.each do |action, counts|
          next unless counts.is_a?(Array)
          # By client
          stats_by_client[client]    ||= [0,0]
          stats_by_client[client][0]  += counts[0]
          stats_by_client[client][1]  += counts[1]
          # By controller and action
          contr_action = "#{controller},#{action}"
          stats_by_contr_action[contr_action]      ||= [0,0]
          stats_by_contr_action[contr_action][0] += counts[0]
          stats_by_contr_action[contr_action][1] += counts[1]
        end
      end
    end

    return stats_by_client,stats_by_contr_action
  end

  # Returns a count of all actions that require
  # being authenticated; there is a built-in
  # exception list to ignore actions that can
  # be invoked externally without authentication
  # (for instance, /service/* or /portal/welcome)
  # Returns the sum of successful and unsuccessful
  # actions.
  def count_authenticated_actions(stats_by_contr_action = {}) #:nodoc:
    tot = 0;
    stats_by_contr_action.keys.sort.each do |contr_action|
      counts            = stats_by_contr_action[contr_action] || [0,0]
      next if contr_action == 'portal,welcome'
      next if contr_action == 'portal,credits'
      next if contr_action == 'portal,about_us'
      controller        = contr_action.split(",").first
      next if controller   == 'service'  # all of them
      next if controller   == 'controls' # show
      next if controller   == 'sessions' # new, show, destroy, create
      tot += counts[0] + counts[1] # OK + FAIL
    end
    tot
  end

end
