
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
class ServiceController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  api_available

  # Return basic identification and provenance
  # information about the platform
  def info
    @info = { :name            => "CBRAIN Data Service",
              :synopsis        => "Focus on data movement using the CBRAIN platform",
              :version         => CbrainFileRevision.cbrain_head_tag,
              :institution     => "McGill University",
              :releaseTime     => Time.parse(CbrainFileRevision.cbrain_head_revinfo.time).utc.iso8601,
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
    @stats      = RemoteResource.current_resource.meta[:stats]
    @last_reset = (RemoteResource.current_resource.meta.md_for_key(:stats).created_at || Time.at(0)).utc.iso8601

    respond_to do |format|
      format.html
      format.xml  { render :xml  => @stats }
      format.json { render :json => @stats }
    end
  end

  # Return the online documentation.
  def doc
    @doc = { :description => "TODO",                # must be text
             :perl_doc    => "/service/doc#TODO",   # must be a URL
             :ruby_doc    => "/service/doc#TODO"    # must be a URL
           }

    respond_to do |format|
      format.html
      format.xml  { render :xml  => @doc }
      format.json { render :json => @doc }
    end
  end

  # Return release note describing the current version
  # of the platform.
  def releasenotes
    respond_to do |format|
      text = "Coming soon; will point to GitHub's release notes."
      format.html { render :text => text }
      format.xml  { render :xml  => { :text => text } }
      format.json { render :json => { :text => text } }
    end

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

  # Return link to the code source of the platform.
  def source
    # TODO Eventually, redirect to GitHub
    render :nothing => true, :status => 204
  end

  # Redirects to the main login page.
  def tryme
    respond_to do |format|
      format.html  { redirect_to login_path }
      format.xml   { render :nothing => true, :status => 406 }
      format.json  { render :nothing => true, :status => 406 }
    end
  end

  # Allows users to view platform's
  # licencing/usage term.
  def licence
    respond_to do |format|
      format.html  { redirect_to :controller => :portal, :action => :about_us }
      format.xml   { render :nothing => true, :status => 406 }
      format.json  { render :nothing => true, :status => 406 }
    end
  end

  # Allows user to view the software provenance
  def provenance
    respond_to do |format|
      format.html  { redirect_to :controller => :portal, :action => :about_us }
      format.xml   { render :nothing => true, :status => 406 }
      format.json  { render :nothing => true, :status => 406 }
    end
  end

end