#
# CBRAIN Bourreau Puma Configuration
#
# This config file setup up puma, the web server
# used by the CBRAIN Bourreau application,
# to listen exclusively on a local unix-domain socket,
# located in Bourreau/tmp/sockets/bourreau.sock .
#
# The only client that will connect to it is the portal,
# which does it through a SSH tunnel that points to
# the unix-domain socket.

# This is used for setting up paths etc.
require 'pathname'
bourreau_install_location = Pathname.new(__FILE__).parent.parent.realpath

# Specifies the `environment` that Puma will run in.
environment ENV.fetch("RAILS_ENV") { "development" }

# Puma can serve each request in a thread from an internal thread pool.
# The `threads` method setting takes two numbers a minimum and maximum.
# Any libraries that use thread pools should be configured to match
# the maximum value specified for Puma. Default is set to 5 threads for minimum
# and maximum, this matches the default thread size of Active Record.
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }.to_i
threads threads_count, threads_count

# Store the pid of the server in the file at "path".
pidfile "#{bourreau_install_location}/tmp/pids/server.pid"

# Redirect STDOUT and STDERR to files specified. The 3rd parameter
# ("append") specifies whether the output is appended, the default is
# "false".
stdout_redirect "#{bourreau_install_location}/log/bourreau.stdout",
                "#{bourreau_install_location}/log/bourreau.stderr", true

# Bourreau socket location; note that the URI starts with three slashes,
# like 'unix:///...'. One of those slashes is inside the
# variable 'bourreau_install_location'
bind "unix://#{bourreau_install_location}/tmp/sockets/bourreau.sock?umask=0111"

# Additional text to display in process listing
tag 'CBRAIN Bourreau'

