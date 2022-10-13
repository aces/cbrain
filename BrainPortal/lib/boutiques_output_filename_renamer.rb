
#
# CBRAIN Project
#
# Copyright (C) 2008-2022
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

# This module adds the ability for a user to
# provide a pattern for naming output files.
#
# To include the module automatically at boot time
# in a task integrated by Boutiques, add a new entry
# in the 'custom' section of the descriptor, like this:
#
#   "custom": {
#       "cbrain:integrator_modules": {
#           "BoutiquesOutputFilenameRenamer": {
#             "outputid1": [ "file_inputid1", "outname_inputid1" ],
#             "outputid2": [ "file_inputid2", "outname_inputid2" ]
#           }
#       }
#   }
#
# The key "outname_inputid1" is the ID of an entry in
# the "output-files" section of the descriptor, and it indicates
# which physical file in the work directory will be saved with the
# newly generated name.
#
# In the associated value, there must be an array of two other IDs.
#
# The first value in the array, "file_inputid1" is an ID of a File input
# entry. The substring components of that file name can be used by the user
# to be substituted in a filename pattern.
#
# The second value in the array, "outname_inputid1" is the ID of a String
# input entry where the user provides that renaming pattern. Normally
# this is substituted somewhere in the command to provide a file
# or directory name. With this module, this string can become
# a pattern such as "hello-#{taskid}-{3}.out"
#
# NOTE 1: most of the times, this module will be used in a descriptor
# such that the value for 'value-key' of the input "outname_inputid1"
# matches exactly the value for 'path-template' for "outputid1". E.g.
#
#   "inputs": [
#     {
#       "id": "fileinput",
#       "name": "Input file to process",
#       "type": "File",
#       "value-key": "[INFILE]"
#     },
#     {
#       "id": "outname",
#       "name": "Name of output",
#       "type": "String",
#       "value-key": "[OUTPUT_FILE]"
#     },
#  (...)
#   "output-files" : [
#     {
#       "id" : "results1",
#       "name" : "Created data",
#       "path-template" : "[OUTPUT_FILE]",
#  (...)
#   "custom": {
#       "cbrain:integrator_modules": {
#           "BoutiquesOutputFilenameRenamer": {
#             "results1": [ "fileinput", "outname" ]
#           }
#       }
#   }
#
# NOTE 2: It is an error to configure this module
# with two entries that have the same String outname
# and a different File fileinput, e.g. like:
#
#           "BoutiquesOutputFilenameRenamer": {
#             "results1": [ "fileinput1", "outname" ]
#             "results2": [ "fileinput2", "outname" ]
#           }
module BoutiquesOutputFilenameRenamer

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  ##################################################
  # Portal side overrides
  ##################################################

  # Returns a descriptor extended with an explanation
  # about the pattern renaming capabilities added to
  # each configured String input fields.
  def descriptor_with_renaming_explanations(descriptor)
    descriptor = descriptor.dup
    config_map = descriptor.custom_module_info('BoutiquesOutputFilenameRenamer')

    uniq_outnames = {}

    config_map.each do |_, pair|
      fileinputid, outnameinputid = *pair

      next if uniq_outnames[outnameinputid]
      uniq_outnames[outnameinputid]=true

      outnameinput   = descriptor.input_by_id(outnameinputid)
      fileinput      = descriptor.input_by_id(fileinputid)
      fileinputname  = fileinput.name.presence || fileinputid
      outnameinput.description ||= ""
      outnameinput.description = outnameinput.description.sub(/\s*\z/,"\n\n")
      outnameinput.description  += <<-INFO # note: it looks good in the form to have ~80 chars per line
        The name provided here can contain patterns that will be substituted when the task
        is launched. These patterns look like "{something}". The basic list of patterns include:

        {date} : the date in format 2020-12-31
        {time} : the time as 12:23:45
        {task_id} : the numerical CBRAIN task ID
        {cluster} : the name of the execution server
        {run_number} : the task's run number

        Additionally, you can specify patterns such as {1}, {2}, {3} etc. These will
        extract alphanumerical sequences from the input file name specified
        in "#{fileinputname}".

        E.g. if your input file is named "hello_123-b626.txt" then {1} is "hello", {2} is "123",
        {3} is "b626" and {4} is "txt".

        Two more patterns exist to substitute most or all of your input file name:

        {full} : your input file name exactly (e.g. "hello_123-b626.txt")
        {full_noex} : your input file name without any extensions (e.g. "hello_123-b626")

        Important: Make sure the name generated does not crush any of your existing files!

        Important: if you launch several tasks out of a list of input files, make sure
        each task will generate a distinct, unique output file name. Using the {task_id}
        is a good way to ensure unique names.
      INFO
    end
    descriptor
  end

  def descriptor_for_form #:nodoc:
    descriptor_with_renaming_explanations(super)
  end

  def descriptor_for_show_params #:nodoc:
    descriptor_with_renaming_explanations(super)
  end

  # This method performs exactly the same thing as the
  # standard method, but it will attempt to validate
  # the pattern and inform the user if it seems improper.
  def after_form
    message    = super
    descriptor = descriptor_for_after_form
    config_map = descriptor.custom_module_info('BoutiquesOutputFilenameRenamer')
    config_map.each do |_, pair|  # pair = [ boutiques ID of input, filename for output ]
      _, outnameinputid = *pair
      outname_pattern = invoke_params[outnameinputid].presence || ""
      fake_inputname  = (1..100).to_a.join("-") # A string like "1-2-3-4...-100"
      fake_outname    = output_name_from_pattern(outname_pattern, fake_inputname)
      if not Userfile.is_legal_filename?(fake_outname)
        params_errors.add(outnameinputid, "is not a pattern that generates a proper output file name")
      elsif fake_outname =~ /[{}]/
        params_errors.add(outnameinputid, "is a pattern that seems to have unreplaced components")
      end
    end
    message
  end

  ##################################################
  # Cluster side overrides
  ##################################################

  # This method overrides the method in BoutiqiesClusterTask.
  # All it does is make the subtitutions in the value of the
  # string that contains the output file name, and stores the result
  # as the new effective value for the name.
  def setup
    descriptor = descriptor_for_setup
    config_map = descriptor.custom_module_info('BoutiquesOutputFilenameRenamer')
    config_map.each do |_, pair|
      fileinputid, outnameinputid = *pair
      input_userfile_id = invoke_params[fileinputid]
      input_userfile    = Userfile.find(input_userfile_id)
      outname_pattern   = invoke_params[outnameinputid]
      outname           = output_name_from_pattern(outname_pattern, input_userfile.name)
      if outname_pattern != outname
        self.addlog("BoutiquesOutputFilenameRenamer rev. #{Revision_info.short_commit}")
        self.addlog "Generating output name: \"#{outname_pattern}\" -> \"#{outname}\""
        self.invoke_params[outnameinputid] = outname # replace pattern with value
      end
    end
    self.save
    super
  end

  # This overrides the BoutiquesClusterTask method and replaces
  # the default behavor of adding an extension "-taskid" to output
  # filenames. Instead, we trust the user to have generated a proper filename
  # with the pattern system. The "type" value returned is the same as
  # whatever "super" method returned.
  def name_and_type_for_output_file(output, pathname)
    name, type = super # the standard names and types; the name will be replaced outright
    descriptor = descriptor_for_save_results
    config_map = descriptor.custom_module_info('BoutiquesOutputFilenameRenamer')
    config_map.each do |outputid, pair| # boutiques ID of outfile-files entry, pair
      next unless outputid == output.id
      _, outnameinputid = *pair
      name = invoke_params[outnameinputid] # just replace it
      break
    end
    [ name, type ]
  end

  ##################################################
  # Common to both Portal and Cluster sides
  ##################################################

  # Generates a new name from +pattern+, using the
  # alphanum components of +inputname+
  def output_name_from_pattern(pattern, inputname)
    # Standard keywords like {date} and {cluster} etc
    keywords = output_renaming_standard_keywords
    # Add support for {1}, {2} etc extracted from the input file name
    output_renaming_add_numbered_keywords(keywords, inputname, "")
    # Add '{full}', '{full_noex}'
    keywords['full']      = inputname
    keywords['full_noex'] = inputname.sub(/\..*/,"")
    outname = pattern.pattern_substitute(keywords)
    outname
  end

end
