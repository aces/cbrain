
#
# NeuroHub Project
#
# Copyright (C) 2020
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

# Project management for NeuroHub
class NhProjectsController < NeurohubApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_action :login_required

  rescue_from CbrainLicenseException, with: :show_license

  def new #:nodoc:
    @nh_project = WorkGroup.new
  end

  def create #:nodoc:
    attributes             = params.require_as_params(:nh_project).permit(:name, :description)

    @nh_project            = WorkGroup.new(attributes)
    @nh_project.creator_id = current_user.id

    if @nh_project.save
      @nh_project.user_ids = [ current_user.id ]
      @nh_project.addlog_context(self,"Created by #{current_user.login}")
      flash[:notice] = "Project #{@nh_project.name} is successfully created"
      redirect_to :action => :show, :id => @nh_project.id
    else
      flash[:error] = "Cannot create project #{@nh_project.name}"
      render :action => :new
    end
  end

  def index  #:nodoc:
    # Note: Should refactor to use session object instead of scope to store button state in the future.
    @nh_projects = find_nh_projects(current_user)
    @scope = scope_from_session
    @scope.custom[:button] = true if
      current_user.has_role?(:normal_user) && @scope.custom[:button].nil?
  end

  def edit #:nodoc:
    @nh_project = find_nh_project(current_user, params[:id])
    @can_add_license = @nh_project.creator_id == current_user.id
  end

  def update #:nodoc:
    @nh_project = find_nh_project(current_user, params[:id])

    unless @nh_project.can_be_edited_by?(current_user)
      flash[:error] = "You don't have permission to edit this project."
      redirect_to :action => :show
      return
    end

    attr_to_update = params.require_as_params(:nh_project).permit(:name, :description, :editor_ids => [])
    attr_to_update["editor_ids"] = [] if !attr_to_update["editor_ids"]
    success        = @nh_project.update_attributes_with_logging(attr_to_update,current_user)

    if success
      flash[:notice] = "Project #{@nh_project.name} is successfully updated."
      redirect_to :action => :show
    else
      flash.now[:error] = "Project #{@nh_project.name} is not successfully updated."
      render :action => :edit
    end
  end

  def show #:nodoc:
    @nh_project = find_nh_project(current_user, params[:id])
    @can_add_license = @nh_project.creator_id == current_user.id
  end

  def files #:nodoc:
    @nh_project = find_nh_project(current_user, params[:id])
    @files      = @nh_project.userfiles
  end

  def new_license #:nodoc:
    @nh_project = find_nh_project(current_user, params[:id] || params[:nh_project_id], false)

    unless @nh_project.creator_id == current_user.id
      cb_error "Only owner can set licensing", :redirect  => :neurohub
    end
  end

  def add_license #:nodoc:
    content = params[:meta][:license_description]
    @nh_project = find_nh_project(current_user, params[:id] || params[:nh_project_id], false)
    cb_error 'Presently empty licenses are not allowed' if content.blank?
    unless @nh_project.creator_id == current_user.id
      cb_error "Only owner can set licensing", :redirect  => :neurohub
    end
    @nh_project = find_nh_project(current_user, params[:id], false)
    @nh_project.create_license_file(content, current_user)
    flash['message'] = 'A license is added. You can force users to sign multiple license agreements if needed'
    redirect_to :action => :show
  end

  def show_license #:nodoc:
    @nh_project = find_nh_project(current_user, params[:id], false)
    @unsigned_licenses = current_user.o_unsigned_custom_licenses(@nh_project)
    if @unsigned_licenses.empty?
      if @nh_project.license_agreements.present?
        flash[:error] = 'You already signed all license'
      else
        flash[:error] = 'No license is defined for this project'
        redirect_to :action => :show
        return
      end
    end
    @license = @unsigned_licenses[0]
    @userfile = Userfile.find(@license)
    set_viewer(@license)
  end

  def sign_license #:nodoc:
    @nh_project = find_nh_project(current_user, params[:id], false)
    @unsigned_licenses = current_user.o_unsigned_custom_licenses(@nh_project)
    @license = params[:license]
    unless @nh_project.license_agreements.include?(@license)
      flash['error'] = 'You are trying to access unrelated license. Try again or report the issue to the support.'
      redirect_to :action => :show
      return
    end
    if current_user.all_custom_licenses_signed.include?(@license)
      flash['error'] = 'You cannot sign the license because you have already signed it.'
      redirect_to :action => :show
      return
    end
    @userfile = Userfile.find(@license)
    unless params.has_key?(:agree)
      flash[:error] = "You cannot access that project without signing the End User Licence Agreement first."
      redirect_to "/neurohub"
      return
    end

    if params.keys.grep(/\Alicense_check/).size < 1
        flash[:error] = "There was a problem with your submission. Please read the agreement and check all checkboxes."
        redirect_to :action => :show
        return
    end

    current_user.all_custom_licenses_signed = current_user.all_custom_licenses_signed << @license
    current_user.addlog("Signed custom license agreement '#{@license}'.")

    if current_user.o_unsigned_custom_licenses(@nh_project).empty?
      flash['message'] = 'You signed all the project licences'      
    else
      flash['message'] = 'please sign another agreement'      
    end
    redirect_to :action => :show, :id => @nh_project.id
  end

  private

  def set_viewer(userfile_id)
    @userfile = Userfile.find(userfile_id)

    viewer_name           = 'text_file'
    viewer_userfile_class = @userfile.class

    # Try to find out viewer among those registered in the classes
    @viewer      = viewer_userfile_class.find_viewer(viewer_name)
    @viewer    ||= (viewer_name.camelcase.constantize rescue nil).try(:find_viewer, viewer_name) rescue nil

    # If no viewer object is found but the argument "viewer_name" correspond to a partial
    # on disk, then let's create a transient viewer object representing that file.
    # Not an officially registered viewer, but it will work for the current rendering.
    if @viewer.blank? && viewer_name =~ /\A\w+\z/
      partial_filename_base = (viewer_userfile_class.view_path + "_#{viewer_name}.#{request.format.to_sym}").to_s
      if File.exists?(partial_filename_base) || File.exists?(partial_filename_base + ".erb")
        @viewer = Userfile::Viewer.new(viewer_userfile_class, :partial => viewer_name)
      end
    end

    # Some viewers return error(s) for some specific userfiles
      @viewer.apply_conditions(@userfile) if @viewer

    begin
      if @viewer
        if @viewer.errors.present?
          render :partial => "viewer_errors"
        else
          render :action => :show_license
        end
      else
        render :html => "<div>Could not find license viewer.</div>", :status  => "404"
      end
    rescue ActionView::Template::Error => e
      exception = e.original_exception

      raise exception unless Rails.env == 'production'
      ExceptionLog.log_exception(exception, current_user, request)
      Message.send_message(current_user,
                           :message_type => 'error',
                           :header => "Could not render a license #{@userfile.name}".html_safe,
                           :description => "An internal error occurred when trying to display the contents of #{@userfile.name}.".html_safe
      )

      render :html => "<div>Error generating view code for viewer.</div>", :status => "500"
    end
  end

end

