
#
# CBRAIN Project
#
# CbrainTask subclass
#
# Original author: Pierre Rioux
#
# $Id$
#

#A dummy task (subclass of CbrainTask::ClusterTask) that simply sleeps for a few seconds.
class CbrainTask::Snoozer < CbrainTask::ClusterTask

  Revision_info="$Id$"

  def setup #:nodoc:
    io = File.new("testsetup.txt","w")
    io.puts "Snoozing\n"
    io.close
    true
  end

  def cluster_commands #:nodoc:
    params  = self.params
    howlong = params[:howlong] || 20
    [
      "pwd",
      "env",
      "cat testsetup.txt",
      "ls /does/not/exist",
      "sleep #{howlong}"
    ]
  end

  def save_results #:nodoc:
    system("tar -cpf /tmp/snoozer#{self.object_id}.tar .")
    true
  end

end

