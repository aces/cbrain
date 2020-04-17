
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

  include Pagy::Backend # lightweight pagination gem

  before_action :login_required

  rescue_from CbrainLicenseException, with: :redirect_show_license

  def new #:nodoc:
    @nh_project = WorkGroup.new
  end

  def create #:nodoc:
    attributes             = params.require_as_params(:nh_project).permit(:name, :description, :public, :editor_ids => [])

    @nh_project            = WorkGroup.new(attributes)
    @nh_project.creator_id = current_user.id

    if @nh_project.save
      @nh_project.user_ids = [ current_user.id ]
      @nh_project.addlog_context(self,"Created by #{current_user.login}")
      flash[:notice] = "Project #{@nh_project.name} was successfully created"
      redirect_to :action => :show, :id => @nh_project.id
    else
      flash[:error] = "Cannot create project #{@nh_project.name}"
      render :action => :new
    end
  end

  def index  #:nodoc:
    # Note: Should refactor to use session object instead of scope to store button state in the future.
    @pagy, @nh_projects = pagy(find_nh_projects(current_user), :items => items_per_page(:projects))

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

    attr_to_update = params.require_as_params(:nh_project).permit(:name, :description, :public, :editor_ids => [])
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
    @nh_project       = find_nh_project(current_user, params[:id])
    @current_licenses = @nh_project.custom_license_agreements # can be empty array
    @can_add_license  = @nh_project.creator_id == current_user.id
    @proj_dp_count    = @nh_project.data_providers.where(:user_id => current_user.id).count
  end

  def files #:nodoc:
    @nh_project   = find_nh_project(current_user, params[:id])
    @pagy, @files = pagy(@nh_project.userfiles, :items => items_per_page(:userfiles))
  end

  def new_license #:nodoc:
    @nh_project = find_nh_project(current_user, params[:id])
    if @nh_project.creator_id != current_user.id
      cb_error "Only owner can set licensing", :redirect => { :action => :show }
    end
  end

  def add_license #:nodoc:
    @nh_project = find_nh_project(current_user, params[:id], false) # false means no license check
    if @nh_project.creator_id != current_user.id
      cb_error "Only owner can set licensing", :redirect  => { :action => :show }
    end

    license_text = params[:license_text]
    cb_error 'Empty licenses are presently not allowed' if license_text.blank?

    timestamp  = Time.zone.now.strftime("%Y-%m-%dT%H:%M:%S")
    group_name = @nh_project.name.gsub(/[^\w]+/,"")
    file_name  = "license_#{group_name}_#{timestamp}.txt"
    @nh_project.register_custom_license(license_text, current_user, file_name)

    flash[:notice] = 'A license is added. You can force users to sign multiple license agreements if needed.'
    redirect_to :action => :show
  end

  def show_license #:nodoc:
    @nh_project       = find_nh_project(current_user, params[:id], false) # false means no license check
    @current_licenses = @nh_project.custom_license_agreements
    unsigned_licenses = current_user.unsigned_custom_licenses(@nh_project)

    if unsigned_licenses.empty?
      if @current_licenses.present?
        flash[:notice] = 'You already signed all licenses'
      else
        flash[:notice] = 'No licenses are defined for this project'
        redirect_to :action => :show
        return
      end
    end

    # What to show. If a license is given in params,
    # we make sure it's a registered one and we pick that.
    param_lic_id = params[:license_id].presence.try(:to_i) # can be nil
    if param_lic_id
      @license_id = @current_licenses.detect { |id| id == param_lic_id }
    end
    # If no valid license was given and there are unsigned licenses, pick the first
    @license_id ||= unsigned_licenses.first.try(:to_i)
    # Otherwise, show the first license.
    @license_id ||= @current_licenses.first

    # Load the text of the license
    userfile = Userfile.find(@license_id)
    userfile.sync_to_cache
    @license_text = userfile.cache_readhandle { |fh| fh.read }
  end

  def sign_license #:nodoc:
    @nh_project = find_nh_project(current_user, params[:id], false) # false means no license check
    @license_id = params[:license_id].to_i

    unless @nh_project.custom_license_agreements.include?(@license_id)
      flash[:error] = 'You are trying to access unrelated license. Try again or report the issue to the support.'
      redirect_to :action => :show
      return
    end

    if current_user.custom_licenses_signed.include?(@license_id)
      flash[:error] = 'You have already signed this license.'
      redirect_to :action => :show
      return
    end

    unless params.has_key?(:agree)
      flash[:error] = "You cannot access that project without signing the License Agreement first."
      redirect_to :action => :index
      return
    end

    if params[:license_check].blank? || params[:license_check].to_i == 0
      flash[:error] = "There was a problem with your submission. Please read the agreement and check the checkbox."
      redirect_to show_license_nh_project_path(@nh_project)
      return
    end

    license = Userfile.find(@license_id)

    current_user.add_signed_custom_license(license)
    current_user.addlog("Signed custom license agreement '#{license.name}' (ID #{@license_id}) for project '#{@nh_project.name}' (ID #{@nh_project.id}).")
    @nh_project.addlog("User #{current_user.login} signed license agreement '#{license.name}' (ID #{@license_id}).")

    if current_user.unsigned_custom_licenses(@nh_project).empty?
      flash[:notice] = 'You signed all the project licenses'
      redirect_to :action => :show, :id => @nh_project.id
    else
      flash[:notice] = 'This project has at least one other license agreement'
      redirect_to :action => :show, :id => @nh_project.id
      #redirect_to :action => show_license_nh_project_path(@nh_project)
    end
  end

  # GET /nh_projects/:id/new_file
  def new_file
    @nh_project  = find_nh_project(current_user, params[:id])
    @nh_projects = find_nh_projects(current_user)
    @nh_dps      = find_all_nh_storages(current_user).where(:group_id => @nh_project.id)
    if @nh_dps.count == 0
      flash[:notice] = 'You need to configure at least one storage for this project before you can upload files.'
      redirect_to :action => :show
    end
  end

  # POST /nh_projects/:id/upload_file
  def upload_file
    nh_project = find_nh_project(current_user, params[:id])
    # Get stream info
    upload_stream = params[:upload_file]
    cb_error "No file selected for uploading" if upload_stream.blank?

    # Get the data provider for the destination files.
    nh_storage = find_nh_storage(current_user, params[:nh_dp_id]) rescue nil
    cb_error "No storage selected for uploading" if nh_storage.blank?

    # Get basic attributes
    basename  = File.basename(upload_stream.original_filename)
    file_type = Userfile.suggested_file_type(basename) || SingleFile
    file_type = SingleFile unless file_type < Userfile
    new_group = if params[:file_nh_project_id].blank?
                  nh_storage.group
                else
                  find_nh_project(current_user, params[:file_nh_project_id])
                end

    # Temp file where the data is saved by rack
    rack_tempfile_path = upload_stream.tempfile.path
    rack_tempfile_size = upload_stream.tempfile.size

    # Create the file
    userfile = file_type.new(
      :name             => basename,
      :user_id          => current_user.id,
      :group_id         => new_group.id,
      :data_provider_id => nh_storage.id,
      :group_writable   => false,
      :size             => rack_tempfile_size,
      :num_files        => 1,
    )
    if ! userfile.save
      flash[:error] = "Could not save file in DB: " + userfile.errors.to_a.join(", ")
      redirect_to :action => :new_file
      return
    end

    # Upload content
    userfile.cache_copy_from_local_file(rack_tempfile_path)
    userfile.addlog("Uploaded by #{current_user.login} on storage '#{nh_storage.name}' and in project '#{new_group.name}'")

    # Tell user all's well that ends well or something
    flash[:notice] = 'File content being uploaded' # actually it's supposed to be all there by now
    redirect_to files_nh_project_path(new_group)

  end

  private

  # this function get a integer parameter that to be used to change page size
  def items_per_page(model='', field='items')
    key = "#{model}_per_page"
    items = params[field]
    if items.present? and items.is_a Integer then
      cbrain_session[key] = items if items?presence and 2...100 == items
    else
      Rails.logger.error "page size is not integer #{model} #{items}"
    end
    @items = items.presence || Pagy::VARS[:items]
  end

  def redirect_show_license
    if params[:id]
      redirect_to show_license_nh_project_path(params[:id])
    else
      redirect_to nh_projects_path
    end
  end

end

