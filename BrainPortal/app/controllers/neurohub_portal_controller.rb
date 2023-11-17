
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

# Controller for the entry point into the system.
class NeurohubPortalController < NeurohubApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_action :login_required

  # Main welcome/dashboard page
  def welcome #:nodoc:
    @username = current_user.login
    bourreau_ids = Bourreau.find_all_accessible_by_user(current_user).raw_first_column("remote_resources.id")
    user_ids     = current_user.available_users.raw_first_column(:id)
    @tasks       = CbrainTask.real_tasks.not_archived.where(:user_id => user_ids, :bourreau_id => bourreau_ids).order( "updated_at DESC" ).limit(5).all
    @files       = Userfile.find_all_accessible_by_user(current_user).where(:hidden => false).order( "updated_at DESC" ).limit(5).all
    @dashboard_messages = Message
      .where(:message_type => 'neurohub_dashboard')
      .order("created_at desc")
      .to_a
      .select { |m| m.expiry.nil? || m.expiry > Time.now }
  end

  # This action searches among all sorts of models for IDs or strings,
  # and reports links to the matches found.
  def search
    @search   = params[:search]
    @limit     = 20 # used by interface only

    if @search.blank?
      #flash[:notice] = 'Blank search'
      redirect_to neurohub_path
      return
    end

    report    = neurohub_search(@search,@limit)

    @files    = report[:files]
    @tasks    = report[:tasks]
    @projects = report[:projects]
  end

  def nh_sign_license #:nodoc:
    @license = params[:license]
    unless params.has_key?(:agree) # no validation for info pages
      flash[:error] = "#Neurohub cannot be used without signing the End User Licence Agreement."
      redirect_to '/signout'
      return
    end
    num_checkboxes = params[:num_checkboxes].to_i
    if num_checkboxes > 0
      num_checks = params.keys.grep(/\Alicense_check/).size
      if num_checks < num_checkboxes
        flash[:error] = "There was a problem with your submission. Please read the agreement and check all checkboxes."
        redirect_to :action => :nh_show_license, :license => @license
        return
      end
    end
    current_user.accept_license_agreement @license
    redirect_to :action => :welcome
  end

  def nh_show_license #:nodoc:
    @license = params[:license].gsub(/[^\w-]+/, "")

    # NeuroHub signed licenses to be shown in NeuroHub, CBRAIN signed licenses to be shown in CBRAIN
    unless @license.start_with? 'nh-'
      flash[:error] = 'Redirecting to CBRAIN, this license is best viewed via CBRAIN'
      redirect_to :controller => :portal, :action => :show_license, :license => @license
      return
    end

    @is_signed = current_user.custom_licenses_signed.include?(@license_id)
    render :nh_show_infolicense if @license&.end_with? "_info" # info license does not require to accept it
  end

end
