
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

# Controller for managing DiskImageConfig objects.
class DiskImageConfigsController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:
  
  def new
    disk_image_bourreau_id = params[:disk_image_bourreau_id]
    bourreau_id = params[:bourreau_id]
    cb_error "Need one disk image bourreau ID and one bourreau ID." unless disk_image_bourreau_id || bourreau_id

    @disk_image_config = DiskImageConfig.new(:disk_image_bourreau_id => disk_image_bourreau_id, :bourreau_id => bourreau_id )

    respond_to do |format|
      format.html { render :action => :edit }
      format.xml  { render :xml => @disk_image_config }
    end
  end

  def edit #:nodoc:
    id           = params[:id]
    @disk_image_config = DiskImageConfig.find(id)
   
    respond_to do |format|
      format.html # edit.html.erb
      format.xml  { render :xml => @disk_image_config }
    end
  end
  
  def update #:nodoc:
    id                = params[:id] || "NEW" # can be 'new' if we create()
    id                = nil if id == "NEW"
    form_disk_image_config  = DiskImageConfig.new(params[:disk_image_config]) # just to store the new attributes
    form_disk_image_id      = form_disk_image_config.disk_image_bourreau_id.presence
    form_bourreau_id  = form_disk_image_config.bourreau_id.presence

    @disk_image_config   = nil
    @disk_image_config   = DiskImageConfig.find(id) unless id.blank?
    cb_error "Need at least one of disk image ID or bourreau ID." if @disk_image_config.blank? && form_disk_image_id.blank? && form_bourreau_id.blank?
    @disk_image_config ||= DiskImageConfig.where( :disk_image_bourreau_id => form_disk_image_id, :bourreau_id => form_bourreau_id ).first if form_disk_image_id.blank? || form_bourreau_id.blank?
    @disk_image_config ||= DiskImageConfig.new(   :disk_image_bourreau_id => form_disk_image_id, :bourreau_id => form_bourreau_id )

    # Security: no matter what the form says, we use the ids from the DB if the object existed.
    form_disk_image_config.disk_image_bourreau_id     = @disk_image_config.disk_image_bourreau_id
    form_disk_image_config.bourreau_id = @disk_image_config.bourreau_id

    # Update everything else
    @disk_image_config[:open_stack_disk_image_id] = form_disk_image_config[:open_stack_disk_image_id]
    
    respond_to do |format|
      if @disk_image_config.save_with_logging(current_user, %w( open_stack_disk_image_id ))
        flash[:notice] = "Disk Image configuration was successfully updated."
        format.html {
                    if @disk_image_config.disk_image_bourreau_id
                      redirect_to bourreau_path(@disk_image_config.disk_image_bourreau)
                    else
                      redirect_to bourreau_path(@disk_image_config.bourreau)
                    end
                    }
        format.xml  { head :ok }
      else        
        format.html { render :action => "edit" }
        format.xml  { render :xml => @disk_image_config.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy #:nodoc:
    id = params[:id]
    @disk_image_config = DiskImageConfig.find(id)
    @disk_image_config.destroy

    flash[:notice] = "Disk Image configuration deleted."

    respond_to do |format|
      format.html { 
                    if @disk_image_config.disk_image_bourreau_id
                      redirect_to bourreau_path(@disk_image_config.disk_image_bourreau)
                    else
                      redirect_to bourreau_path(@disk_image_config.bourreau)
                    end
                  }
      format.xml  { head :ok }
    end
  end


end
