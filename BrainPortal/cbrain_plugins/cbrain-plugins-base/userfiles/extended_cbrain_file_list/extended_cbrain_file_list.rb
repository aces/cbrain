
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
#   933,"hello.txt",3433434,"TextFile","SomeDP","jsmith","mygroup",{extra_param_3: value_3}
#
class ExtendedCbrainFileList < CbrainFileList

    Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

    # Structure of the CSV file; only the ID is used when this object is used as input to something else.
    # When displayed in a web page, the associations to other models are shown by name.
    ATTRIBUTES_LIST << :json_params

end
