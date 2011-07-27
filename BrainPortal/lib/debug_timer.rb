# CBRAIN Project
#
# Original author: Tarek Sherif
#
# $Id$
#

class DebugTimer
  
  Revision_info=CbrainFileRevision[__FILE__]
  
  def self.start(message = "Timer starting at: #{Time.now}")
    puts message
    puts self.timer.reset
  end
  
  def self.reset
    self.timer.reset
  end
  
  def self.timed_puts(*args)
    self.timer.timed_puts(*args)
  end
  
  def initialize
    @base_time      = Time.now
    @last_timepoint = @base_time
  end
  
  def reset
    @base_time      = Time.now
    @last_timepoint = @base_time
  end 
  
  def timed_puts(message, colour)
    method = "puts"
    if colour
      method = "puts_#{colour}"
    end
    send method, prepare_string(message)
  end
  
  def prepare_string(message)
    current_time = Time.now
    cumul_time = current_time - @base_time
    dif_time = current_time - @last_timepoint
    message += ": diff=#{dif_time}s / cumul=#{cumul_time}s"
    
    @last_timepoint = current_time
    message
  end
  
  private
  
  def self.timer
    @@timer ||= self.new
  end
end