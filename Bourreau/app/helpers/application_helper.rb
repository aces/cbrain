# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

end

require 'pathname'

#
# This class provides a way to execute aribitrary bash commands
# or ruby instructions in a temporary directory in /tmp, garanteed
# to not collide with existing temporary files there.
# Commands and instructions are executed with the current working
# directory changed to the temporary location. A cleanup
# is performed when the destroy() method is called.
#
# Original author: Pierre Rioux
#
class SandboxTmp

  Revision_info="$Id$"

  public

  # TODO make protected/private or attr_reader some of these
  attr_accessor :tmpdirbase, :tmpfulldirname, :savecwd
  attr_accessor :stdout,     :stderr

  # This method creates a temp directory where execution
  # can proceed. There is a single option, :tmpdirbase,
  # which allows you to specify a simple identifier for the
  # tmp directory name (it will be used as part of the full
  # name). For instance,
  #
  #     new( :tmpdirbase => "myProg" )
  #
  # will create a temporary dir such as "/tmp/myProg.1234-98765"
  # where 1234 is Ruby's process ID and 98765 is this object's ID
  def initialize(options = {})

    tmpdirbase = options[:tmpdirbase] || "work"
    raise "Illegal work directory basename '#{tmpdirbase}'" unless tmpdirbase.match(/^\w[\w\.+\-\+\,]*$/)
    tmpdirbase += ("." + $$.to_s + self.object_id.to_s)
    tmpfulldirname = (Pathname.new(Dir.tmpdir) + tmpdirbase).to_s
    Dir.mkdir(tmpfulldirname,0700)
    self.tmpdirbase     = tmpdirbase
    self.tmpfulldirname = tmpfulldirname

  end

  # Run a ruby block with the current directory changed
  # to the object's temp dir. After execution, the current
  # directory is restored. The block can receive two arguments,
  # |dir,fulldir|, where dir is the basename of the temporary
  # directory and fulldir is the full path to it.
  def ruby()
    self.save_cwd_and_chdir
    ret = yield(self.tmpdirbase,self.tmpfulldirname)
    self.restore_cwd
    ret
  end

  # Run an aribitrary bash command in the temp dir.
  # Options are :capout and :caperr; if set to true
  # the stdout and stderr will be capture and stored
  # in the object's stdout and stderr's attribute
  def bash(command,options = {})
    command = command.gsub(/'/,"'\\\\''")

    base = self.tmpdirbase
    stdout  = options[:capout] ? ".out.#{base}" : "&1"
    stderr  = options[:caperr] ? ".err.#{base}" : "&2"

    command = "/bin/bash -c '( #{command} ) >#{stdout} 2>#{stderr}'"
    self.save_cwd_and_chdir
    retcode = system(command)
    if options[:capout] && File.exists?(stdout)
      self.stdout = File.read(stdout)
      File.delete(stdout)
    end
    if options[:caperr] && File.exists?(stderr)
      self.stderr = File.read(stderr)
      File.delete(stderr)
    end

    self.restore_cwd
    retcode
  end

  # This method destroy the temporary directory and
  # all its content
  def destroy
    system("/bin/rm -rf \"#{self.tmpfulldirname}\"")
  end

  protected

  def save_cwd_and_chdir
    self.savecwd = Dir.getwd
    Dir.chdir(self.tmpfulldirname)
  end

  def restore_cwd
    Dir.chdir(self.savecwd)
  end

end
