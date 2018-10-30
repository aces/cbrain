
#
# This file shouldn't be run directly, but
# invoked through the rake task:
#
#   RAILS_ENV=test rake cbrain:api:client:test
#
# A prerequisite is to have run, first:
#
#   RAILS_EMV=test rake db:seed:test:api
#
# This file CAN be loaded into the Rails console, however,
# provided it was started in the test environment.

require File.expand_path('../lib/parse_req.rb',  __FILE__)

# We need to create two configs for two distinct users,
# and unfortunately the CbrainClient created by Swagger
# doesn't really support this. So we have to play with the
# internals a bit.

# These values must match what was seeded in the
# test DB.
NORMAL_TOKEN = '0123456789abcdeffedcba9876543210'
ADMIN_TOKEN =  '0123456789abcdef0123456789abcdef'
DEL_TOKEN   =  '0123456789abcdefffffffffffffffff'

# First, the default confif for the normal user
CbrainClient.configure do |config|
  # The key for 'normal user', as created in db:seed:test:api
  config.api_key['cbrain_api_token'] = NORMAL_TOKEN
  config.host                        = 'localhost:3000'
  config.scheme                      = 'http'
end

# Client for normal user
@normclient  = CbrainClient::ApiClient.new # Use the defaults

# Now whenever we want to use the API, by default we will
# use the normal credential above; if we ever want to act
# as an admin, we can just substitute the ApiClient we patch
# here below:
@adminclient = CbrainClient::ApiClient.new
adminconfig  = @adminclient.config = @adminclient.config.dup # replace config with a clone
adminconfig.api_key = adminconfig.api_key.merge({ 'cbrain_api_token' => ADMIN_TOKEN }) # replace hash

# Client for queries that delete its own token
@delclient    = CbrainClient::ApiClient.new
delconfig     = @delclient.config = @delclient.config.dup # replace config with a clone
delconfig.api_key = delconfig.api_key.merge({ 'cbrain_api_token' => DEL_TOKEN }) # replace hash

# Client for queries that are not authenticated at all
@noclient    = CbrainClient::ApiClient.new
noconfig     = @noclient.config = @noclient.config.dup # replace config with a clone
noconfig.api_key = noconfig.api_key.merge({ 'cbrain_api_token' => 'totally_invalid' }) # replace hash

# This will help map the tokens in the "req" files to the clients above
@client_switcher=Hash.new(@noclient)
  .merge 'ATOK' => @adminclient, 'DTOK' => @delclient, 'NTOK' => @normclient

# Find all req files
Dir.chdir("test_api")
reqfiles = IO.popen("find curltests -name \"*req\" -print","r") { |fh| fh.readlines }
reqfiles.map! { |x| x.chomp } # just line in Perl, almost
#puts "Reqfiles: #{reqfiles.inspect}"

filt = ARGV[1]
if filt
  puts "Filtering: #{filt}"
  reqfiles.select! { |x| x.index(filt) }
end

puts "Filt Reqfiles: #{reqfiles.inspect}"

def runtest(testfile)
  puts "Testing #{testfile}"
  parsed = ParseReq.new(testfile)
  puts_green "#{parsed.klass} | #{parsed.method} | #{parsed.reqid} | #{parsed.toktype}"
  begin
    client = @client_switcher[parsed.toktype]
    errors = parsed.runtest(client)
  rescue => ex
    errors = [ "Exception: #{ex.class} #{ex.message}" ]
  end
puts_yellow errors.join(", ")
  errors.empty?
end

reqfiles.each_with_index do |test,i|
  result = runtest(test)
break # temp
end

