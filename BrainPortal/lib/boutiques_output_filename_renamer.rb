
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
#             "outname_inputid1": "file_inputid1",
#             "outname_inputid2": "file_inputid2"
#           }
#       }
#   }
#
# The keys "outname_inputid1" are IDs of input entries
# where the user provides a name for an output. The values
# "file_inputid1" are IDs of input entries for actual
# file inputs. To repeat, both keys are values are
# IDs of INPUT entries in the descriptor, the first
# for a String and the second for a File.
#
# NOTE: this module can only work properly if in the descriptor,
# the value for 'value-key' of the input "outname_inputid1"
# matches exactly the value for 'path-template' of an
# "output-files" entry in the descriptor. E.g.
#
#   "inputs": [
#     {
#       "id": "file_inputid1",
#       "name": "Input file to process",
#       "type": "File",
#       "value-key": "[INFILE]"
#     },
#     {
#       "id": "outname_inputid1",
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
#
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
    input_maps = descriptor.custom_module_info('BoutiquesOutputFilenameRenamer')
    input_maps.each do |outnameinputid, fileinputid|
      outnameinput  = descriptor.input_by_id(outnameinputid)
      fileinput     = descriptor.input_by_id(fileinputid)
      fileinputname = fileinput.name.presence || fileinputid
      outnameinput.description ||= ""
      outnameinput.description = outnameinput.description.sub(/\s*\z/,"\n\n")
      outnameinput.description  += <<-INFO
        The name provided here can contain patterns that will be substituted at when the task
        is launched. These patterns look like "{something}". The basic list of patterns include:

        {date} : the date in format 2020-12-31
        {time} : the time as 12:23:45
        {task_id} : the numerical CBRAIN task ID
        {cluster} : the name of the execution server
        {run_number} : the task's run number

        and additionally, alphanumerical sequences extracted from the input file specified
        in "#{fileinputname}" as {1}, {2}, {3} etc.

        E.g. if your inputfile is named "hello_123-b626.mnc" then {1} is "hello", {2} is "123",
        {3} is "b626" and {4} is "mnc".

        Important: if you launch several tasks out of a list of input files, make sure
        each task will generate a distinct unique filename here!
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
    input_maps = descriptor.custom_module_info('BoutiquesOutputFilenameRenamer')
    input_maps.each do |outnameinputid, _|  # boutiques ID of input with filename for output
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
    input_maps = descriptor.custom_module_info('BoutiquesOutputFilenameRenamer')
    input_maps.each do |outnameinputid, inputfileid| # boutiques IDs of input containing filename for output, File input
      input_userfile_id = invoke_params[inputfileid]
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
    name, type = super # the standard names and types; the name will be replaced
    descriptor = descriptor_for_save_results
    input_maps = descriptor.custom_module_info('BoutiquesOutputFilenameRenamer')
    input_maps.each do |outnameinputid, _| # boutiques ID of input containing filename for output
      outnameinput = descriptor.input_by_id(outnameinputid)
      next unless outnameinput.value_key == output.path_template
      name = invoke_params[outnameinputid] # just replace it; this removes the standard task ID extension too
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
    outname = pattern.pattern_substitute(keywords)
    outname
  end

end
