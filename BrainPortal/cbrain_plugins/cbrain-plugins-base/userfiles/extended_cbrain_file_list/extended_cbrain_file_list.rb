
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

# This class extand the attributes_list array used by the
# CbrainFileList by adding an extra key that correspond
# to the last column of the CSV file.
#
# Example of file content:
#
#   232123,"myfile.txt",425,"TextFile","MainStoreProvider","jsmith","mygroup","{extra_param_1: value_1}"
#   112233,"plan.pdf",3894532,"SingleFile","SomeDP","jsmith","secretproject", "{extra_param_2: value_2}"
#   0,,,,,,,
#   933,"hello.txt",3433434,"TextFile","SomeDP","jsmith","mygroup","{extra_param_3: value_3}"
#
class ExtendedCbrainFileList < CbrainFileList

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Structure of the CSV file; only the ID is used when this object is used as input to something else.
  # When displayed in a web page, the associations to other models are shown by name.
  ATTRIBUTES_LIST = superclass::ATTRIBUTES_LIST + [ :json_params ]

  def self.pretty_type #:nodoc:
    "Extended CBRAIN List of files"
  end

  # Returns an hash extract from the last column of the Extended CBCsv file
  # as extracted by cached_csv_array(). Value will be a hash (can be empty)
  #
  #  [ {key_param_1_task_1: value_for_param_1_task_1, key_param_2_task_1: value_for_param_2_task_1},
  #    {key_param_1_task_1: value_for_param_1_task_1},
  #    {},
  #    {},
  #    {key_param_1_task_5: value_for_param_1_task_5, key_param_2_task_5: value_for_param_2_task_5}
  #  ]
  #
  # Note that this method caches internally its result. To clear the
  # cache (if the userfile's content has changed for instance) call
  # the method flush_internal_caches().
  #
  def ordered_params()
    @extra_params ||= cached_csv_array.map do |row|
      JSON.parse(row[-1])
    end

    @extra_params
  end

  # Many methods of this class cache their result internally
  # to avoid reduplicating costly work. If the content of
  # the CSV file change, calling flush_internal_caches() will
  # clean these caches so they return new, accurate results.
  #
  # Methods that currently cache information are:
  #
  # cached_csv_array, ordered_raw_ids, userfiles_accessible_by_user and extra_params!
  def flush_internal_caches
    @ids_with_zeros_and_nils = nil
    @userfiles               = nil
    @rows                    = nil
    @extra_params            = nil
  end

  # "a/b/c" -> {"a" => ["a/b/c", "a/d/f"]}
  def self.relpath_to_root_and_base(relpaths)
    # Special situation when a file with a path
    # is specified instead of just a basename.
    relpaths.inject({}) do |results,relpath|
      filenames =  Pathname.new(relpath).each_filename.to_a
      # E.g: root == sub-123
      parent_dir = filenames.first
      res = results[parent_dir] ||= []
      res << relpath if filenames.size != 1
      results
    end
  end

  # add json_params reader method to userfile object
  def self.extend_userfile_json_params_reader(userfile,json_params_value)
    userfile.define_singleton_method(:json_params) {
      json_params_value
    }
  end

  # userfile_name => {Id: values}
  def self.extended_userfiles_by_name(userfiles,id_to_values)
    userfiles.to_a.each do |userfile|
      extend_userfile_json_params_reader(userfile,id_to_values[userfile.name])
    end
    userfiles
  end
end
