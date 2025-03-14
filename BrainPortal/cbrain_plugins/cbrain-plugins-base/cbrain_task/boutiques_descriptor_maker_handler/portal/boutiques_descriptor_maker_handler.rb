
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
# BoutiquesDescriptorMaker. It provides special functionality
# to allow the interface to dynamically show and render a JSON for
# a boutiques descriptor.
class BoutiquesDescriptorMakerHandler < BoutiquesPortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  attr_accessor :bosh_validation_messages, :bosh_command_preview

  # This method overrides the default method of BoutiquesPortalTask.
  # It handles different moments in the lifecycle of the task's interface.
  #
  # 1) When the form is initially rendered, we create a descriptor
  # based on the BoutiquesDescriptorMakerHandler own descriptor, but with
  # pretty user-friendly modifications. This is provided
  # by initial_descriptor_for_user().
  #
  # 2) When the JSON posted by the user is syntactically unparsable, we return
  # a trimmed-down descriptor with basically only the input for the JSON text.
  # This is provided by descriptor_when_json_error().
  #
  # 3) Otherwise, we take the descriptor as supplied by the user but we
  # re-insert the input structure to describe the text area itself.
  def descriptor_for_form
    text_user_posted = self.descriptor_text_from_posted_form
    if ! text_user_posted # initial render, or text area blanked out
      new_desc  = self.initial_descriptor_for_user
      text_user_posted = JSON.pretty_generate(new_desc)
      self.invoke_params[:_bdm_json_descriptor] = text_user_posted
    end
    desc_user_posted = self.descriptor_from_posted_form
    if ! desc_user_posted
      self.errors.add(:base, "Your descriptor has syntax errors")
      desc_user_posted = self.descriptor_when_json_error
    end
    desc_user_posted.delete(:groups) if desc_user_posted.groups.blank?
    added_input = self.boutiques_descriptor.input_by_id('_bdm_json_descriptor').dup
    desc_user_posted.inputs.unshift(added_input)
    desc_user_posted
  end

  # The normal behavior is to compare the number of submitted files
  # to the number of file inputs in the descriptor, but we bypass and
  # ignore all of that now.
  def before_form
    return ""
  end

  # This method receives the descriptor from the user and performs
  # checks on it, and produces error messages as needed.
  #
  # In all cases it's designed to trick the CBRAIN framework into
  # thinking that the task is NEVER ready to launch, because of course
  # there is nothing to launch.
  def after_form
    desc = descriptor_for_form

    if self.errors.empty?
      self.bosh_validation_messages = generate_validation_messages(desc)
      if self.bosh_validation_messages.to_s.strip != "OK"
        self.errors.add(:base, "This descriptor has validation errors")
      else
        self.bosh_command_preview = generate_command_preview(desc, self.invoke_params)
      end
    end

    if self.errors.empty? && (params[:_bdm_reorder] == 'on' || params[:_bdm_pad] == 'on')
      btq    = descriptor_from_posted_form
      btq    = btq.pretty_ordered    if params[:_bdm_reorder] == 'on'
      btq.delete(:groups) if btq.groups.blank?
      json   = btq.super_pretty_json if params[:_bdm_pad]     == 'on'
      json ||= JSON.pretty_generate(btq)
      self.invoke_params[:_bdm_json_descriptor] = json
    end

    if self.errors.empty?
      # We must add at least one error to prevent CBRAIN from attempting to launch something.
      self.errors.add(:base, <<-ALL_OK
         This is not an error. This descriptor is OK.
         Once you are satisfied with it, copy the text of the
         descriptor somewhere else for safe keeping.
         ALL_OK
      )
    end

    ""
  end

  def self.properties #:nodoc:
    super.merge(
      :no_submit_button      => true,
      :no_presets            => true,
      :read_only_input_files => true,
    )
  end

  protected

  def descriptor_text_from_posted_form #:nodoc:
    text = self.invoke_params[:_bdm_json_descriptor].presence || ""
    text.strip!
    return text.presence
  end

  def descriptor_from_posted_form #:nodoc:
    text = descriptor_text_from_posted_form
    return nil unless text
    desc = BoutiquesSupport::BoutiquesDescriptor.new_from_string(text) rescue nil

    # Check for something bosh doesn't verify: input IDs mentioned in groups
    # that do not exist
    zap_it = false
    (desc&.groups || []).each do |group|
      members = group.members || []
      badid = members.detect { |inputid| (desc.input_by_id(inputid) rescue nil).nil? }
      if badid
        self.errors.add(:base, "The group '#{group.name}' has a member input id '#{badid}' which doesn't exist")
        zap_it = true
      end
    end
    desc = nil if zap_it

    desc
  end

  # Invokes bosh to validate the descriptor text
  def generate_validation_messages(desc) #:nodoc:
    tmpfile       = "/tmp/desc.#{Process.pid}.#{rand(100000)}"
    adjusted_desc = desc_adjuster(desc)
    File.open(tmpfile,"w") { |fh| fh.write JSON.pretty_generate(adjusted_desc) }
    out = IO.popen("bosh validate #{tmpfile.bash_escape}","r") { |fh| fh.read }
    out
  rescue Errno::ENOENT => ex
    return "Cannot validate: bosh is not installed on this portal"
  rescue => ex
    return "Bosh validation failed: #{ex.class} #{ex.message}"
  ensure
    File.unlink(tmpfile) rescue nil
  end

  # Invokes bosh to generate a command preview.
  def generate_command_preview(desc, invoke_struct) #:nodoc:
    tmpdesc = "/tmp/desc.#{Process.pid}.#{rand(100000)}"
    tmpdata = "/tmp/data.#{Process.pid}.#{rand(100000)}"
    adjusted_desc   = desc_adjuster(desc)
    adjusted_invoke = invoke_struct_adjuster(desc, invoke_struct)
    File.open(tmpdesc,"w") { |fh| fh.write JSON.pretty_generate(adjusted_desc) }
    File.open(tmpdata,"w") { |fh| fh.write JSON.pretty_generate(adjusted_invoke) }
    out = IO.popen("bosh exec simulate -i #{tmpdata.bash_escape} #{tmpdesc.bash_escape}","r") { |fh| fh.read }
    out.sub!(/^\s*generated command.*\n/i,"")
    out
  rescue Errno::ENOENT => ex
    return "Cannot render command: bosh is not installed on this portal"
  rescue => ex
    return "Bosh command rendering failed: #{ex.class} #{ex.message}"
  ensure
    File.unlink tmpdesc
    File.unlink tmpdata
  end

  # Returns a descriptor that's adjusted for bosh's peculiarities
  def desc_adjuster(desc)
    desc = desc.dup
    desc.delete :groups if desc.groups.blank?
    desc
  end

  # Returns a JSON invoke structure that's adjusted for bosh's peculiarities
  # In CBRAIN, some input type don't store the values in the same
  # way as in the JSON that bosh expects.
  def invoke_struct_adjuster(desc, invoke_struct)
    invoke_struct = invoke_struct.dup
    desc.inputs.each do |input|
      next unless invoke_struct.has_key? input.id
      value = invoke_struct[input.id]
      if input.type == 'Flag'
        invoke_struct[input.id] = true  if value == '1'
        invoke_struct[input.id] = false if value == '0'
      end
      if input.type == 'File'
        name   = Userfile.where(:id => value).first.try(:name)
        name ||= "userfile:#{value}"
        invoke_struct[input.id] = name
      end
      if input.type == 'Number'
        invoke_struct[input.id] = value.to_i if   input.integer
        invoke_struct[input.id] = value.to_f if ! input.integer
      end
    end
    invoke_struct
  end

  # We use the BoutiquesDecriptorMaker's own descriptor
  # as a basis for the sample descriptor that users see.
  # This method returns it in a cleaner form.
  def initial_descriptor_for_user #:nodoc:
    desc = self.boutiques_descriptor.dup # the one configured in the plugins

    # Modify it to present ot the user a bare descriptor with some
    # examples of about everything
    desc.inputs.reject! { |input| input.id == '_bdm_json_descriptor' }

    desc.name                    = "SimpleNameOfTool"
    desc.description             = "Enter a description of the tool"
    desc.author                  = "Name of tool author <email@here>"
    desc.descriptor_url          = "https://0.0.0.0/info/about/tool"

    desc.custom['cbrain:author'] = "#{self.user.full_name} <#{self.user.email}>"
    desc.custom.delete "cbrain:inherits-from-class"
    desc
  end

  # This returns a placeholder decriptor that only has inputs
  # for the JSON text area.
  def descriptor_when_json_error
    desc = self.boutiques_descriptor.dup # the one configured in the plugins
    desc.name         = "BadJSONDescriptor"
    desc.inputs       = []  # the textarea will be re-inserted later
    desc.groups       = []
    desc.output_files = []
    desc.custom       = {}
    desc
  end

end

