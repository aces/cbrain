#
#
# CBRAIN Project
#
# This is a replacement for the drmaa.rb library; this particular subclass
# of class Scir implements the SGE interface.
#
# Original author: Pierre Rioux
#
# $Id$
#

require 'scir'

class ScirSgeSession < Scir::Session

  Scir.session_subclass = self.to_s

  def job_ps(jid)
    IO.popen("qstat -xml 2>/dev/null","r") do |input|
      paragraphs = input.read.split(/(<\/?job_list)/)
      paragraphs.each_index do |i|
        if paragraphs[i] == "<job_list"
          if paragraphs[i+1] =~ /<JB_job_number>([^<]+)/ && Regexp.last_match[1] == jid
            if paragraphs[i+1] =~ /<state>(\w+)/
              state = Regexp.last_match[1]
              # The ORDER of these things is important here
              return Scir::STATE_RUNNING        if state =~ /r/i
              return Scir::STATE_USER_SUSPENDED if state =~ /s/i
              return Scir::STATE_USER_ON_HOLD   if state =~ /h/i
              return Scir::STATE_QUEUED_ACTIVE  if state =~ /q/i
            end
            return Scir::STATE_UNDETERMINED
          end
        end
      end
      return Scir::STATE_UNDETERMINED
    end
  end

  def hold(jid)
    IO.popen("qhold #{shell_escape(jid)} 2>&1") do |i|
      p = i.read
      raise "Error holding: #{p}" unless p =~ /modified hold of/i
      return
    end
  end

  def release(jid)
    IO.popen("qrls #{shell_escape(jid)} 2>&1") do |i|
      p = i.read
      raise "Error releasing: #{p}" unless p =~ /modified hold of/i
      return
    end
  end

  def suspend(jid)
    raise "There is no 'suspend' action implemented yet for SGE clusters"
  end

  def resume(jid)
    raise "There is no 'resume' action implemented yet for SGE clusters"
  end

  def terminate(jid)
    IO.popen("qdel #{shell_escape(jid)} 2>&1") do |i|
      p = i.read
      raise "Error deleting: #{p}" unless p =~ /has deleted job|has registered/i
      return
    end
  end

  private

  def qsubout_to_jid(i)
    id = i.read
    if id && id =~ /Your job (\d+)/i
      return Regexp.last_match[1]
    end
    raise "Cannot find job ID from qsub output"
  end

end

class ScirSgeJobTemplate < Scir::JobTemplate

  Scir.jobtemplate_subclass = self.to_s

  def qsub_command
    raise "Error, this class only handle 'command' as /bin/bash and a single script in 'arg'" unless
      self.command == "/bin/bash" && self.arg.size == 1
    raise "Error: stdin not supported" if self.stdin

    command  = ""
    command += "qsub "
    command += "-wd #{shell_escape(self.wd)} "    if self.wd
    command += "-N #{shell_escape(self.name)} "   if self.name
    command += "-o #{shell_escape(self.stdout)} " if self.stdout
    command += "-e #{shell_escape(self.stderr)} " if self.stderr
    command += "-j y "                            if self.join
    command += "#{shell_escape(self.arg[0])}"

    command
  end

end
