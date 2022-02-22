
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
  api_available :only => %i( file_list_maker csv_data_maker )

  # POST /loris_hooks/file_list_maker
  #
  # Receives:
  #  {
  #    source_basenames:         [ "abc.nii.gz", "def.mnc.gz" ],
  #    source_data_provider_id:  123, # optiona, can be name
  #    result_filename:          "hello.csv",
  #    result_data_provider_id:  123, # optional, can be name
  #    result_group_id:          123, # optional, can be name
  #  }
  #
  # Produces: a CbrainFileList userfile. Basenames are looked
  # up among all userfiles visible by the current user, and can
  # be restricted to those in source_data_provider_id .
  def file_list_maker

    # Parameters for source files
    source_basenames = params[:source_basenames] # array of userfiles names
    source_dp_id     = params[:source_data_provider_id].presence # can be nil, can be id or name

    # List of online DPs that user can access
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

    # Create CbrainFileList content and save it to DP
    cblist_content = CbrainFileList.create_csv_file_from_userfiles(userfiles)

    # Save result file
    result = create_file_for_request(CbrainFileList, "Loris-DQT-List.cbcsv", cblist_content)

    # Report back to client
    render_created_file_report(result)

  end

  # POST /loris_hooks/csv_data_maker
  #
  # Receives:
  #  {
  #    table_content:            [ [a, b, c], [d, e, f]... ],
  #    result_filename:          "hello.csv",
  #    result_data_provider_id:  123, # optional, can be name
  #    result_group_id:          123, # optional, can be name
  #  }
  #
  # Produces: a CSVFile userfile
  def csv_data_maker

    # Main params
    table_content = params[:table_content]
    cb_error "No CSV content provided." if table_content.blank?

    # CSV content as text
    #csv_content = CSV.generate do |csv|
    #  table_content.each do |row|
    #    csv << row
    #  end
    #end

    # Darn CSV class is dumb, I have to write my own CSV dumper
    string_quoter = -> (x) { '"' + x.gsub('"','""') + '"' }
    csv_content = table_content.map do |row|
      row.map { |v| v.is_a?(String) ? string_quoter.(v) : v.to_s }
         .join(",")
    end.join("\n") + "\n"

    # Save result file
    result = create_file_for_request(CSVFile, "Data.csv", csv_content)

    # Report back to client
    render_created_file_report(result)

  end

  private

  # Creates a file of class +userfile_class+.
  # Other attrivutes are fetched from the request params
  # (result_filename, result_data_provider_id, result_group_id).
  # If not provided in params, user-specific default are used.
  def create_file_for_request(userfile_class, default_name, file_content = nil)

    # Parameters for result file to create
    result_dp_id     = params[:result_data_provider_id].presence # can be nil, can be id or name
    result_group_id  = params[:result_group_id].presence # nil, id or name
    result_filename  = params[:result_filename].presence

    # Build filename
    timestamp         = Time.zone.now.strftime("%Y-%m-%d-%H:%M:%S")
    result_filename   = nil if result_filename && ! Userfile.is_legal_filename?(result_filename)
    result_filename ||= default_name
    result_filename.sub!(/(\.\w+)?$/i,".#{timestamp}\\1") # insert timestamp before ext

    # List of online DPs that user can write to
    user_dps = DataProvider.find_all_accessible_by_user(current_user)
                           .where(:online => true, :read_only => false)

    # Find the DP for the result file
    pref_dp_id  = current_user.meta[:pref_data_provider_id].presence
    result_dp   = user_dps.where_id_or_name(result_dp_id).first if result_dp_id
    result_dp ||= user_dps.where(:id => pref_dp_id).first       if pref_dp_id
    result_dp ||= user_dps.first # poor guess

    # Find the group for the result file
    result_group   = current_user.assignable_groups
                                 .where_id_or_name(result_group_id).first if result_group_id
    result_group ||= current_user.own_group

    # Construct file
    result = userfile_class.new(
      :name             => result_filename,
      :user_id          => current_user.id,
      :data_provider_id => result_dp.id,
      :group_id         => result_group.id,
    )

    # Register it in the DB
    if ! result.save
      messages = result.errors.full_messages.join(", ")
      cb_error "Cannot create file list: #{messages}"
    end

    # Upload content to Data Provider
    begin
      result.cache_writehandle { |fh| fh.write(file_content) }
    rescue => ex
      result.destroy rescue nil # clean DB of now junky entry
      cb_error "Cannot write CSV content to data provider #{result_dp.name}: #{ex.class} #{ex.message}"
    end

    result
  end

  # Given a newly created +result+ userfile, renders
  # a JSON request with information about it. The HTTP
  # status :created is returned to the client.
  def render_created_file_report(result)

    json_report = {
      :message            => "#{result.pretty_type} created",
      :userfile_id        => result.id,
      :userfile_name      => result.name,
      :userfile_type      => result.type,
      :userfile_size      => result.size,
      :group_id           => result.group.id,
      :group_name         => result.group.name,
      :data_provider_id   => result.data_provider.id,
      :data_provider_name => result.data_provider.name,
      :cbrain_url         => userfile_url(result),
    }

    response.headers["Location"] = userfile_url(result)
    render :json => json_report, :status => :created
  end

end
