
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
factory = VmFactoryRoundRobin.new
factory.disk_image_file_id = 240
factory.tau = tau
factory.mu_plus = mu_plus
factory.mu_minus = mu_minus
factory.nu_plus = nu_plus 
factory.nu_minus = nu_minus
factory.k_plus = k_plus
factory.k_minus = k_minus
factory.save!
factory.start


