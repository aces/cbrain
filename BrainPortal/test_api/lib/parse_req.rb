
# This class is used by the API testing framework to
# parse the "req" files, which are simple description
# of an API request. The files were originally designed
# to be parsed by a Perl script to build 'curl' commands,
# but are used here to match the request to a CbrainClient
# API class and method.
#
# The file usually contain a single line, like one of these:
#
#   POST /users?ATOK
#   GET /userfiles/1?NTOK
#   POST /userfiles/delete_files
#   GET /userfiles/2/content?NTOK
#
# These will be matched to the CbrainClient classes resp:
#
#   CbrainClient::UsersApi.users_post
#   CbrainClient::UserfilesApi.userfiles_id_get
#   CbrainClient::UserfilesApi.userfiles_delete_files_delete
#   CbrainClient::UserfilesApi.userfiles_id_content_get
#
# These method names are created by convention by the
# Swagger API client generator for Ruby.
#
# In the case of the last example, the object created in this
# class will have the following attributes:
#
#   klass   == CbrainClient::UserfilesApi
#   method  == :userfiles_id_content_get
#   reqid   == 2
#   toktype == 'NTOK'  # optional
#
class ParseReq

  attr_accessor :klass, :method, :reqid, :toktype

  # Parse a 'req' file
  def initialize(testfile)
    req = File.read(testfile)
    # E.g.
    # POST /users?ATOK
    # GET /userfiles/1?NTOK
    # POST /userfiles/delete_files
    # GET /userfiles/2/content
    unless req.match( /
                      \A
                      (\S+)        # CAPT 1: verb "POST" "GET" etc
                      \s+          # space
                      \/           # slash
                      (\w+)        # CAPT 2: "controller"
                        (?:          # grouping, not capturing
                          (\/\d+)?      # CAPT 3: "slash number"
                          (\/[a-z]\w+)? # CAPT 4: "slash action"
                        )?           # end group
                      (\?[AND]TOK)? # CAPT 5: "?ATOK" or "?NTOK" or "?DTOK"
                      $
                      /x
                    )
      raise "Oh oh bad unparsable red line in '$testfile': #{req}"
    end

    verb, controller, @reqid, action, @toktype = Regexp.last_match[1,5]

    #puts "MATCH: #{verb} | #{controller} | #{reqid.inspect} | #{action.inspect} | #{an_token.inspect}"

    # Clean up our captures #3, #4 and #5
    @reqid.gsub!("/","")   if @reqid.present?
    action.gsub!("/","")   if action.present?
    @toktype.gsub!("?","") if @toktype.present?

    # Figure out the full class name
    controller_klass = controller.classify.pluralize # "tool_configs" => "ToolConfigs"
    @klass    = "CbrainClient::#{controller_klass}Api".constantize rescue nil
    raise "Cannot figure out API class for request in '#{testfile}'. Got '#{controller_klass}' which is not a constant of CbrainClient." if ! @klass

    # Figure out the full method name
    @method  = controller
    @method += "_id"        if @reqid.present?
    @method += "_#{action}" if action.present?
    @method += "_#{verb.downcase}"
    @method = @method.to_sym
    #puts_green "=======> #{klass}.#{@method}"

    # Verify that the method exists for the class
    handler = klass.new
    unless handler.respond_to? @method
      raise "Error parsing testfile '#{testfile}: class #{klass} has not method '#{@method}'"
    end

    self
  end

end

