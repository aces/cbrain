
class String
  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end
end


def log(object)
  t = Time.new
  logfile = "log/factory.log"
  text = object.respond_to?("message") ? "#{object.message}  #{object.backtrace}".colorize(32) : "#{object}"
  time = "[ #{t.to_i} #{t.inspect} ]"
  prompt = "VM>"
  out = "#{prompt.colorize(36)} #{time.colorize(36)} #{text}\n"
  File.open(logfile, 'a') {|f| f.write(out) }
end

log("test")

# VM parameters
tau = 10
mu_plus = 1.3
mu_minus = 0.5
nu_plus = 5
nu_minus = 5
k_plus = 1
k_minus = 1
#
#   # start basic VM factory
CBRAIN.spawn_with_active_records("VM factory")  do
  log "Launching VM factory ("+"Basic".colorize(33)+") for disk image "+"240".colorize(33)
  begin
    VmFactoryRoundRobin.new(240, #disk_image_file_id
                            tau,
                            mu_plus,
                            mu_minus,
                            nu_plus,
                            nu_minus,
                            k_plus,
                            k_minus
                            ).start 
  rescue => ex
    log ex
  end
end

