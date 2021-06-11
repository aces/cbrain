
#
# CBRAIN Project
#
# Copyright (C) 2008-2021
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

# A subclass of CbrainTask to launch SimpleFileExtractor.
class CbrainTask::SimpleFileExtractor < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # RDOC comments here, if you want, although the method
  # is created with #:nodoc: in this template.
  def self.default_launch_args #:nodoc:
    {
      :patterns => {}, # keys are numeric, values are the patterns
    }
  end

  def before_form #:nodoc:
    params = self.params
    ids    = params[:interface_userfile_ids].presence || []

    self.validate_input_ids(ids)
    ""
  end

  def after_form #:nodoc:
    params = self.params
    ids    = params[:interface_userfile_ids].presence || []

    self.validate_input_ids(ids) # just like we did in before_form

    # Validate output file name
    out_name = params[:output_file_name].presence
    self.params_errors.add(:output_file_name, "provided contains some unacceptable characters.") unless
      FileCollection.is_legal_filename?(out_name)

    # Clean up pattern list
    patterns = patterns_as_array(params[:patterns].presence || {})
    patterns = patterns.map(&:presence).compact
    patterns = patterns.map { |pat| Pathname.new(pat).cleanpath }
    params[:patterns] = patterns_as_hash(patterns.map(&:to_s)) # write back cleaned list

    # Validate them and report errors; note that here the array contains Pathname objects
    #
    # Expect things like:
    #
    #   */*txt
    #   */subdir/abc.txt
    #   */subdir/*/*.txt
    #   FileColName*/*/*.txt
    patterns.each_with_index do |pat,idx|
      if ! pat.relative?
        self.params_errors.add("patterns[#{idx}]", "is not a relative path")
      end
      if ! pat.to_s.index('/') # must contain at least 2 components
        self.params_errors.add("patterns[#{idx}]", "does not contain at least two levels")
      end
      if pat.to_s.start_with? "../"
        self.params_errors.add("patterns[#{idx}]", "cannot map outside of collections")
      end
    end

    ""
  end

  def final_task_list #:nodoc:
    return [ self ] # default behavior
  end

  def untouchable_params_attributes #:nodoc:
    { :output_file_id => true }
  end

  # Verifies that all +ids+ are FileCollections
  # that the user has the permissions to read.
  def validate_input_ids(ids)
    cb_error "No files selected" if ids.size == 0
    selected_inputs = Userfile.find_all_accessible_by_user(self.user, :access_requested => :read).where( 'userfiles.id' => ids )

    # Make sure user can access the content of all these files
    accessible_count = selected_inputs.count
    if accessible_count != ids.size
      cb_error "You do not have read access to all the selected files (only #{accessible_count} out of #{ids.count})"
    end

    # Make sure they are all FileCollections
    # TODO support CbrainFileLists ?
    fc_count = FileCollection.where(:id => ids).count
    if fc_count != ids.size
      cb_error "This task requires all inputs to be FileCollections (or subclasses of FileCollection)"
    end
  end

end

