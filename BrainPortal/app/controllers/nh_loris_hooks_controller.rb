
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

# Controller for special LORIS hooks for NeuroHub.
# All the actions implemented in this controller
# are API actions using JSON.
class NhLorisHooksController < NeurohubApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_action :login_required
  api_available :file_list_maker

  # POST /loris_hooks/file_list_maker
  def file_list_maker

    # Parameters for source files
    source_basenames = params[:source_basenames] # array of userfiles names
    source_dp_id     = params[:source_data_provider_id].presence # can be nil, can be id or name

    # Parameters for result file list
    result_dp_id     = params[:result_data_provider_id].presence # can be nil, can be id or name
    result_filename  = params[:result_filename].presence
    result_group_id  = params[:result_group_id].presence # nil, id or name

    user_dps = DataProvider.find_all_accessible_by_user(current_user)
                           .where(:online => true)

    # Find the files for the list
    cb_error "No basenames provided." if source_basenames.blank?
    s_dp = user_dps.where_id_or_name(source_dp_id).first if source_dp_id
    base = Userfile.where(nil) # As seen in userfiles_controller
    base = Userfile.restrict_access_on_query(current_user, base, :access_requested => :read)
    userfiles = base.where(:name => source_basenames)
    userfiles = userfiles.where(:data_provider_id => s_dp.id) if s_dp

    # It is an error not to find exactly the same number of files as in
    # the params' basenames array
    file_count = userfiles.count
    exp_count  = Array(source_basenames).size
    if file_count != exp_count
      cb_error "Could not find an exact match for the files. Found #{file_count} of #{exp_count} files"
    end

    # Construct attributes for result file
    pref_dp_id  = current_user.meta[:pref_data_provider_id].presence
    result_dp   = user_dps.where_id_or_name(result_dp_id).first if result_dp_id
    result_dp ||= user_dps.where(:id => pref_dp_id).first       if pref_dp_id
    result_dp ||= user_dps.first # poor guess

    timestamp         = Time.zone.now.strftime("%Y-%m-%d-%H:%M:%S")
    result_filename   = nil if result_filename && ! Userfile.is_legal_filename?(result_filename)
    result_filename ||= "Loris-DQT-List"
    result_filename.sub!(/(\.csv)?$/i,".#{timestamp}.csv")

    result_group   = current_user.assignable_groups
                                 .where_id_or_name(result_group_id).first if result_group_id
    result_group ||= current_user.own_group

    # Construct file list
    result = CbrainFileList.new(
      :name             => result_filename,
      :user_id          => current_user.id,
      :data_provider_id => result_dp.id,
      :group_id         => result_group.id,
    )
    if ! result.save
      messages = result.errors.full_messages.join(", ")
      cb_error "Cannot create file list: #{messages}"
    end

    # Create CSV content and save it to DP
    csv_content = CbrainFileList.create_csv_file_from_userfiles(userfiles)
    begin
      result.cache_writehandle { |fh| fh.write(csv_content) }
    rescue => ex
      result.destroy rescue nil
      cb_error "Cannot write CSV content to data provider #{result_dp.name}: #{ex.class} #{ex.message}"
    end

    # All good, let's report back to client
    json_report = {
      :message            => "CbrainFileList file created",
      :userfile_id        => result.id,
      :userfile_name      => result.name,
      :group_id           => result_group.id,
      :group_name         => result_group.name,
      :data_provider_id   => result_dp.id,
      :data_provider_name => result_dp.name,
      :cbrain_url         => userfile_url(result),
    }

    render :json => json_report, :status => :created

  end

end
