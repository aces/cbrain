
#
# CBRAIN Project
#
# Copyright (C) 2022
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

# This class is an intermediate class between BoutiquesPortalTask and
# BoutiquesToolConfigurator. It provides special functionality
# to allow the interface to dynamically show the list of ToolConfigs.
class BoutiquesToolConfiguratorHandler < BoutiquesPortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.properties #:nodoc:
    super.merge(
      :no_presets            => true,
      :read_only_input_files => true,
    )
  end

  # The normal code validates the number of selected files vs number of input files in the
  # descriptor, but we override this by not making any verifications.
  def before_form
    ""
  end

  def descriptor_for_form
    desc = super.dup
    add_visible_tcs(desc)
    add_all_input_notes(desc)
    desc
  end

  def descriptor_for_after_form
    desc = super.dup
    fix_value_choices_for_tool_configs(desc)
    desc
  end

  def refresh_form
    old_tc       = selected_old_tool_config
    new_tc       = selected_new_tool_config
    old_file     = old_tc&.container_image
    current_file = new_tc&.container_image

    change = ->(param, newvalue, message) do
      newvalue = "0" if newvalue.is_a?(FalseClass) # boolean in html are these strings
      newvalue = "1" if newvalue.is_a?(TrueClass) # boolean in html are these strings
      if self.invoke_params[param] != newvalue
#puts_red "C=#{param} A='#{self.invoke_params[param].inspect}' B='#{newvalue.inspect}'"
        self.invoke_params[param] = newvalue
        self.errors.add(:base, "(Not an error) Please review: #{message}")
      end
    end

    if (old_tc && new_tc)
      change.(:copy_group_id, (old_tc.group_id != new_tc.group_id), "the flag to copy the project ID")
      change.(:copy_qsub,     old_tc.extra_qsub_args.present?,      "the flag to copy the extra QSUB args")
      change.(:copy_env,      old_tc.env_array.present?,            "the flag to copy the environment variables")
      change.(:copy_bash,     (old_tc.script_prologue.present? || old_tc.script_epilogue.present?),  "the flag to copy the bash prologue and epilogue")
      change.(:copy_overlays,
         (old_tc.singularity_overlays_specs.present? ||
          old_tc.container_exec_args.present? ||
          (old_tc.singularity_use_short_workdir? != new_tc.singularity_use_short_workdir?)
         ),
         "the flag to copy miscellaneous Apptainer options")
    end

    docker_name  = new_tc&.containerhub_image_name.presence
    if new_tc && ! docker_name # when the TC has blanks but the BTQ descriptor has a value
      docker_name = new_tc.boutiques_descriptor.container_image&.image.presence # from BTQ
    end

    # What the user selected to do in the 'build' group
    selected_build = self.invoke_params['docker_source']

    # Extract the first two values in the select box:
    #   "(Do not build..."
    #   "(Use existing..."
    do_not_build, use_old_image =
      self.boutiques_descriptor.input_by_id('docker_source').value_choices[0..1]

    if current_file
      if selected_build != do_not_build
        self.errors.add(:base, "(Not an error) The current NEW tool config already has an Apptainer image, so the build form was reset to 'Do Not Build'")
      end
      self.invoke_params['docker_source']  = do_not_build
      self.invoke_params['docker_name']    = nil
      self.invoke_params['apptainer_name'] = nil
      return super
    end

    if selected_build == use_old_image
      if ! old_file
        self.errors.add(:base, "The OLD ToolConfig does not have an Apptainer image configured. Resetting the build options.")
        self.invoke_params['docker_source']  = do_not_build
      end
      self.invoke_params['docker_name']    = nil
      self.invoke_params['apptainer_name'] = nil
      return super
    end

    if docker_name.present? && selected_build.to_s =~ /^docker/
      change.(:docker_name, docker_name, "the Docker image name")
      change.(:apptainer_name, docker_name_to_sif_name(docker_name), "the Apptainer image name")
    end

    super
  end

  def after_form
    message = super
    return message if self.errors.present?

    old_tc = selected_old_tool_config
    new_tc = selected_new_tool_config
    return message if old_tc.blank? || new_tc.blank? # framework will provide messages

    descriptor = descriptor_for_after_form

    selected_build = self.invoke_params['docker_source']

    # Extract the first two values in the select box:
    #   "(Use existing..."
    use_old_image =
      descriptor.input_by_id('docker_source').value_choices[1]

    if selected_build == use_old_image
      params_errors.add(:docker_source, "requires a OLD ToolConfig with an Apptainer image already configured") if
        old_tc.container_image.blank?
    end

    if selected_build.to_s =~ /\Adocker/ # docker, docker-daemon
      dname = invoke_params[:docker_name].presence.to_s
      aname = invoke_params[:apptainer_name].presence.to_s
      params_errors.add(:docker_name,    "is missing") if dname.blank?
      params_errors.add(:apptainer_name, "is missing") if aname.blank?
      params_errors.add(:docker_name,    "is not correct") if dname !~ /\A[a-z]\w+\/[a-z]\w*:[\w\.]+\z/
      params_errors.add(:apptainer_name, "is not correct") if ! Userfile.is_legal_filename?(aname) || aname !~ /\.sif\z/
    end

    errors.add(:base, "Check messages") if params_errors.present?

    # Perform the copy of all attributes if there are no errors
    if errors.empty?
      copy_attributes
      if selected_build.to_s !~ /\Adocker/ # if not build was asked, we want ot return to the form
        errors.add(:base, "(Not an error) Attributes (if any) have been copied to the NEW ToolConfig; please verify them.")
      end
      return message
    end

    return message
  end

  def copy_attributes
    descriptor   = descriptor_for_after_form

    old_tc       = selected_old_tool_config
    new_tc       = selected_new_tool_config

    # This stupid lambda handles all possible conventions
    # for booleans we have in all the layers, I hate it
    bool = ->(val) do
      return true  if val.is_a?(TrueClass)
      return false if val.is_a?(FalseClass)
      return true  if val.to_s == '1'
      return false  if val.to_s == '0'
      val.present?
    end

    if bool.(invoke_params[:copy_group_id])
      new_tc.group_id = old_tc.group_id
    end
    if bool.(invoke_params[:copy_qsub])
      new_tc.extra_qsub_args = old_tc.extra_qsub_args
    end
    if bool.(invoke_params[:copy_env])
      new_tc.env_array = old_tc.env_array
    end
    if bool.(invoke_params[:copy_bash])
      new_tc.script_prologue = old_tc.script_prologue
      new_tc.script_epilogue = old_tc.script_epilogue
    end
    if bool.(invoke_params[:copy_overlays])
      new_tc.singularity_overlays_specs    = old_tc.singularity_overlays_specs
      new_tc.singularity_use_short_workdir = old_tc.singularity_use_short_workdir
      new_tc.container_exec_args           = old_tc.container_exec_args
    end

    selected_build = self.invoke_params['docker_source']
    use_old_image  = descriptor.input_by_id('docker_source').value_choices[1]

    if selected_build == use_old_image
      new_tc.container_image_userfile_id = old_tc.container_image_userfile_id
      new_tc.containerhub_image_name     = old_tc.containerhub_image_name
      new_tc.container_engine            = old_tc.container_engine
      new_tc.container_index_location    = old_tc.container_index_location
    end

    new_tc.save_with_logging((self.user || CoreAdmin.admin),
      # The indentation below is to highlight the groups of params
      %i(
            extra_qsub_args
          env_array
            script_prologue
            script_epilogue
          singularity_overlays_specs
          singularity_use_short_workdir
          container_exec_args
            container_image_userfile_id
            containerhub_image_name
            container_engine
            container_index_location
      )
    )

  end

  def final_task_list
    selected_build = self.invoke_params['docker_source']
    return [] if selected_build !~ /^docker/ # zap array, don't build
    [ self ] # go to cluster for real build
  end

  protected

  # NOTE: Modifies the desc !
  def fill_tool_configs_arrays(desc, which, tool_id = nil) #:nodoc:
    tcs = ToolConfig.all
      .joins(:tool,:bourreau)
      .order('tools.name','tool_configs.created_at')
      .where('tools.cbrain_task_class_name like "BoutiquesTask::%"')
    tcs = tcs
      .where('tools.id' => tool_id) if tool_id
    selections = tcs.pluck('tool_configs.id')
    desc.input_by_id('old_tool_config_id').value_choices = selections if which == :old || which == :both
    desc.input_by_id('new_tool_config_id').value_choices = selections if which == :new || which == :both
    desc
  end

  # NOTE: Modifies the desc !
  def add_visible_tcs(desc) #:nodoc:
    old_tc = selected_old_tool_config
    new_tc = selected_new_tool_config
    if old_tc && ! new_tc
      fill_tool_configs_arrays(desc, :old)
      fill_tool_configs_arrays(desc, :new, old_tc.tool_id)
      tool_name = old_tc.tool.name
      errors.add(:base, "(Not an error) The list of TCs to configure has been filtered to only show configs for tool '#{tool_name}'")
    elsif !old_tc && new_tc
      fill_tool_configs_arrays(desc, :new)
      fill_tool_configs_arrays(desc, :old, new_tc.tool_id)
      tool_name = new_tc.tool.name
      errors.add(:base, "(Not an error) The list of OLD TCs has been filtered to only show configs for tool '#{tool_name}'")
    else
      fill_tool_configs_arrays(desc, :both)
    end
  end

  # NOTE: Modifies the desc !
  def add_all_input_notes(descriptor) #:nodoc:
    old_tc              = selected_old_tool_config
    new_tc              = selected_new_tool_config
    old_tc = nil if old_tc&.id == new_tc&.id

    old_desc            = old_tc&.boutiques_descriptor
    new_desc            = new_tc&.boutiques_descriptor
    old_apptainer_image = old_tc&.container_image&.presence
    new_apptainer_image = new_tc&.container_image&.presence
    old_docker_name     = old_tc&.containerhub_image_name&.presence
    new_docker_name     = new_tc&.containerhub_image_name&.presence
    old_btq_docker_name = old_desc&.container_image&.image&.presence
    new_btq_docker_name = new_desc&.container_image&.image&.presence
    old_btq_docker_name = nil if old_btq_docker_name == old_docker_name
    new_btq_docker_name = nil if new_btq_docker_name == new_docker_name

    dn = descriptor.input_by_id('docker_name')
    dn.cbrain_input_notes = []
    dn.cbrain_input_notes << "The OLD descriptor currently has '#{old_btq_docker_name}'" if old_btq_docker_name
    dn.cbrain_input_notes << "The OLD ToolConfig currently has '#{old_docker_name}'" if old_docker_name
    dn.cbrain_input_notes << "The NEW descriptor currently has '#{new_btq_docker_name}'" if new_btq_docker_name
    dn.cbrain_input_notes << "The NEW ToolConfig currently has '#{new_docker_name}'" if new_docker_name

    an = descriptor.input_by_id('apptainer_name')
    an.cbrain_input_notes = []
    an.cbrain_input_notes << "The OLD ToolConfig currently uses the file named '#{old_apptainer_image.name}' (ID ##{old_apptainer_image.id})" if old_apptainer_image
    an.cbrain_input_notes << "The NEW ToolConfig currently uses the file named '#{new_apptainer_image.name}' (ID ##{new_apptainer_image.id})" if new_apptainer_image

    cp_proj = descriptor.input_by_id('copy_group_id')
    cp_proj.cbrain_input_notes = []
    cp_proj.cbrain_input_notes << "Project of OLD ToolConfig: #{old_tc.group.name} (ID ##{old_tc.group.id})" if old_tc
    cp_proj.cbrain_input_notes << "Project of NEW ToolConfig: #{new_tc.group.name} (ID ##{new_tc.group.id})" if old_tc

    cp_qsub = descriptor.input_by_id('copy_qsub')
    cp_qsub.cbrain_input_notes = []
    cp_qsub.cbrain_input_notes << "Args of OLD ToolConfig: '#{old_tc.extra_qsub_args}'" if old_tc&.extra_qsub_args.present?
    cp_qsub.cbrain_input_notes << "Args of NEW ToolConfig: '#{new_tc.extra_qsub_args}'" if new_tc&.extra_qsub_args.present?

    cp_env = descriptor.input_by_id('copy_env')
    cp_env.cbrain_input_notes = []
    cp_env.cbrain_input_notes << "OLD ToolConfig has #{old_tc.env_array.size} variable(s)" if old_tc&.env_array.present?
    cp_env.cbrain_input_notes << "NEW ToolConfig has #{new_tc.env_array.size} variable(s)" if new_tc&.env_array.present?

    cp_bash = descriptor.input_by_id('copy_bash')
    cp_bash.cbrain_input_notes = []
    cp_bash.cbrain_input_notes << "OLD ToolConfig has a script prologue" if old_tc&.script_prologue.present?
    cp_bash.cbrain_input_notes << "OLD ToolConfig has a script epilogue" if old_tc&.script_epilogue.present?
    cp_bash.cbrain_input_notes << "NEW ToolConfig has a script prologue" if new_tc&.script_prologue.present?
    cp_bash.cbrain_input_notes << "NEW ToolConfig has a script epilogue" if new_tc&.script_epilogue.present?

    cp_ovrl = descriptor.input_by_id('copy_overlays')
    cp_ovrl.cbrain_input_notes = []
    cp_ovrl.cbrain_input_notes << "OLD ToolConfig has overlays" if old_tc&.singularity_overlays_specs.present?
    cp_ovrl.cbrain_input_notes << "OLD ToolConfig uses short workdirs" if old_tc&.singularity_use_short_workdir?
    cp_ovrl.cbrain_input_notes << "OLD ToolConfig uses special container options" if old_tc&.container_exec_args.present?
    cp_ovrl.cbrain_input_notes << "NEW ToolConfig has overlays" if new_tc&.singularity_overlays_specs.present?
    cp_ovrl.cbrain_input_notes << "NEW ToolConfig uses short workdirs" if new_tc&.singularity_use_short_workdir?
    cp_ovrl.cbrain_input_notes << "NEW ToolConfig uses special container options" if new_tc&.container_exec_args.present?

  end

end

