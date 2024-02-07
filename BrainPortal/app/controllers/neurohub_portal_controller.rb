
#
# NeuroHub Project
#
# Copyright (C) 2020-2023
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
  def news #:nodoc:
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

  def welcome
    @username = current_user.login
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

end

