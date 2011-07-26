
# This class encapsulates an information record about
# the revision control history of a file. It was created
# as a transition mechanism between SVN and GIT. In SVN
# all classes used to define a constant called Revision_info
# whose value would be initialized by the programmer to the
# string'$Id$' but would be substituted, by SVN, for a
# longer description of the file's name, commit ID,
# commit author and date. As a replacement, we now
# require programmers to add this at the beginning of
# their classes:
#
#   Revision_info=CbrainFileRevision[__FILE__]
#
# This initalize the constant to a handler object of
# class CbrainFileRevision which records the file path
# in one of its internal attribute. Later one, if
# a piece of code wants to extract from it its revision
# ID (or author name etc) then a 'git' command will be
# issued to extract the info, and it will be cached in
# the object. The process is 'lazy' in that the git
# command is only executed the first time a to_s() is
# invoked.
#
# Objects of this class, otherwise, belong much like
# strings, but sometimes you might want to call to_s()
# explicitely.
#
# Examples:
#
#   # At the top of a class:
#   class Abcd
#     Revision_info=CbrainFileRevision[__FILE__]
#   end
#
#   # Then later on, all these calls are similar:
#   puts Abcd::Revision_info.to_s # in SVN-like format
#   puts Abcd::Revision_info.svn_id_rev # using CBRAIN's svn_id_rev parser
#   puts Abcd.revision_info.svn_id_rev  # using CBRAIN's revision_info method
#   x = Abcd.new
#   puts x.revision_info.svn_id_rev
#   puts x.revision_info.short_commit # using attributes
class CbrainFileRevision

  attr_accessor :fullpath
  attr_accessor :basename
  attr_accessor :fake_svn_id_string
  attr_accessor :git_last_commit_info
  attr_accessor :author, :commit, :short_commit, :date, :time

  def initialize(fullpath) #:nodoc:
    self.fullpath = fullpath
  end

  # Same as new() method. This allows you to
  # initialize an object in a prettier way:
  #
  #   # Standard:
  #   Revision_info = CbrainRevisionInfo.new(__FILE__)
  #
  #   # Prettier:
  #   Revision_info = CbrainRevisionInfo[__FILE__]
  def self.[](fullpath)
    self.new(fullpath)
  end

  # Returns the revision info in a fake 'svn' format:
  #   "$Id: en_cbrain_local_data_provider.rb 961 2010-03-25 17:26:05Z prioux $"
  def to_s
    return @fake_svn_id_string if ! @fake_svn_id_string.nil? # Cached; no need to fetch git info every time.
    get_git_rev_info()
    @fake_svn_id_string = "$Id: #{@basename} #{@short_commit} #{@date} #{@time} #{@author} $"
    @fake_svn_id_string
  end

  # Make the object act as a string
  def method_missing(name,*args) #:nodoc:
    # 'name' will be provided by Ruby as :myattr or :myattr=
    self.to_s.send(name,*args)
  end

  def =~(*args) #:nodoc:
    self.to_s.=~(*args)
  end

  private

  def get_git_rev_info #:nodoc:
    return unless @git_last_commit_info.nil?

    # 9f4c0900fa3e6c87131d830194d0276acb1ce595 2011-06-28 17:50:26 -0400 Pierre Rioux
    @git_last_commit_info = "" # now that it's no longer nil, will not try to fetch again

    dirname   = File.dirname(@fullpath)
    @basename = File.basename(@fullpath)
    @commit   = "UnknownId" ; @short_commit = @commit
    @date     = "0000-00-00"
    @time     = "00:00"
    @author   = "UnknownAuthor"

    Dir.chdir(dirname) do
      File.popen("git rev-list --max-count=1 --date=iso --pretty=format:'%H %ad %an' HEAD -- ./'#{@basename}' 2>/dev/null","r") do |fh|
        line = fh.readline.strip rescue ""
        if line =~ /\d\d\d\d-\d\d-\d\d/
          @git_last_commit_info = line
        else
          line = fh.readline.strip rescue ""
          @git_last_commit_info = line if line =~ /\d\d\d\d-\d\d-\d\d/
        end
      end
    end

    if @git_last_commit_info =~ /^(\S+) (\d\d\d\d-\d\d-\d\dT?)\s*(\d\d:\d\d:\d\dZ?)(\s*[+-][\d:]+)? (\S.*\S)\s*$/
      @commit = Regexp.last_match[1] ; @short_commit = @commit[0..5]
      @date   = Regexp.last_match[2]
      @time   = Regexp.last_match[3] + (Regexp.last_match[4] || "")
      @author = Regexp.last_match[5]
    end
  end

end
