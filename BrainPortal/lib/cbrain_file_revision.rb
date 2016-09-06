
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

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
#   Revision_info=CbrainFileRevision[__FILE__] #:nodoc:
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
# or self_update() explicitely.
#
# Examples:
#
#   # At the top of a class:
#   class Abcd
#     Revision_info=CbrainFileRevision[__FILE__] #:nodoc:
#   end
#
#   # Then later on, all these calls are similar:
#   puts Abcd::Revision_info.to_s # <short_commit> <author> <date> by default
#   puts Abcd::Revision_info.format("%s %a %d") # selects <short_commit> <author> <date> to put in the string
#   puts Abcd.revision_info.to_s  # using CBRAIN's revision_info method
#   puts x.revision_info.short_commit # using attributes
#
#   # If at least once to_s(), format(), or self_update() has been called,
#   # the the attributes can also be accessed directly:
#   Abcd::Revision_info.self_update
#   puts Abcd::Revision_info.author
#

require 'csv'
require 'pathname'

class CbrainFileRevision

  # Basename of flatfiles for revision info, which are
  # fallbacks when the app is not installed with GIT.
  # One such file is found at the top of the CBRAIN platform,
  # and one can optionally be found in each plugin package.
  FLATFILE_BASENAME="cbrain_file_revisions.csv" #:nodoc:

  # Default tag reporting value for plugins
  DEFAULT_TAG="0.1.0" #:nodoc:

  # Attributes for linking the object to a disk file
  attr_accessor :fullpath # this one is filled when the object is initialized
  attr_accessor :basename

  # Official attributes
  attr_accessor :author, :commit, :short_commit, :date, :time

  def initialize(fullpath) #:nodoc:
    @fullpath = fullpath.to_s
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

  # Returns a formatted string representing the last change to the file in git
  # Format: <short_commit> <author> <date>
  def to_s
    self.format("%f %s %d %t %a")
  end

  # Returns a formatted string representing the last change to the file in git
  # Format is determined by passing the desired details you want in the returned string
  # as a string:
  # %a = author
  # %f = filename
  # %c = commit
  # %s = short_commit
  # %d = date
  # %t = time
  # Defaults to: <short_commit> <author> <date>
  def format(rev_info = "%s %a %d")
    self_update()

    rev_info = rev_info.gsub(/(%[afcsdt])/, {
        "%a" => @author,
        "%f" => @basename,
        "%c" => @commit,
        "%s" => @short_commit,
        "%d" => @date,
        "%t" => @time
    })

    return rev_info
  end

  # Returns the date and time of the revision info, separated by a space.
  #
  #   "2010-03-25 17:26:05 -0400"
  def datetime
    self_update()
    "#{@date} #{@time}"
  end

  def short_commit #:nodoc:
    self_update
    @short_commit
  end

  def commit #:nodoc:
    self_update
    @commit
  end

  def author #:nodoc:
    self_update
    @author
  end

  def date #:nodoc:
    self_update
    @date
  end

  def time #:nodoc:
    self_update
    @time
  end

  def basename #:nodoc:
    self_update
    @basename
  end

  # Inspect the revision object but will not trigger a self_update(),
  # so the returned string might contain all blank fields.
  def inspect
    "<#{self.class.to_s}##{self.object_id} @basename=#{@basename.inspect} @short_commit=#{@short_commit.inspect} @date=#{@date.inspect} @time=#{@time.inspect} @author=#{@author.inspect}>"
  end

  # Make the object act as a string
  def method_missing(name,*args) #:nodoc:
    # 'name' will be provided by Ruby as :myattr or :myattr=
    String.method_defined?(name) ? self.to_s.send(name,*args) : super
  end

  def =~(*args) #:nodoc:
    self.to_s.=~(*args)
  end

  # Makes the class access the GIT repository and
  # updates its attributes to represent the current
  # file's GIT state.
  #
  # +mode+ can be one of :auto, :git, or :static,
  # which indicates which source of revision info
  # will be used: :git means to run some 'git' commands
  # on the file that represents the revision object,
  # whereas :static means to load the info from
  # a static file installed in the CBRAIN root
  # directory.
  #
  # When +force+ is true, the revision info will
  # be refreshed even if it had been cached before.
  def self_update(mode=:auto, force=nil)
    @commit=nil if force
    self.get_git_rev_info(mode)
  end

  # Loads the flatfiles ; one of them in the root of
  # the main CBRAIN repo, and one in each plugins package.
  def self.load_all_static_revision_files #:nodoc:
    return true if @_static_revision_hash.present? # already done
    @_static_revision_hash = {}

    # Main platform flatfile
    rails_root         = Pathname.new(Rails.root)
    cbrain_root        = rails_root.parent
    rails_app_basename = rails_root.basename
    main_path          = cbrain_root + FLATFILE_BASENAME
    self.load_static_revision_file(main_path)

    # Each plugin package now
    Dir.chdir(rails_root + "cbrain_plugins") do # TODO use CBRAIN::Plugins_Dir ?
      Dir.glob("cbrain-plugins-*").each do |package|
        Dir.chdir(package) do
          if File.exists?(FLATFILE_BASENAME)
            self.load_static_revision_file(FLATFILE_BASENAME, rails_app_basename + "cbrain_plugins" + package)
          end
        end
      end
    end
    true
  end

  # Class method. Slurps a static file of revision info
  # and caches it.
  def self.load_static_revision_file(path,relprefix="") #:nodoc:
    relprefix = Pathname.new(relprefix) if relprefix.present?
    CSV.foreach(path.to_s, :col_sep => ' -#- ') do |row|
      # 7f6bb2f24f6afb3d3b355d6c0ad630cdf353e1fe -#- 2011-07-18 17:16:57 -0400 -#- Pierre Rioux -#- Bourreau/README
      commit   = row[0]
      datetime = row[1]
      author   = row[2]
      relpath  = row[3]
      relpath  = (relprefix + relpath).to_s if relprefix.present? && relpath !~ /\A__/ # adds plugins relative prefix if needed
      @_static_revision_hash[relpath] = [ commit, datetime, author ] unless relpath.blank?
      #puts_blue "-> #{@_static_revision_hash[relpath].inspect}"
    end
    true
  end

  def self.static_revision_for_relpath(relpath) #:nodoc:
    @_static_revision_hash[relpath]
  end

  def self.git_available? #:nodoc:
    return @_git_available == :yes unless @_git_available.blank?
    test = `bash -c "which git 2>/dev/null"`
    @_git_available = (test.blank? ? :no : :yes)
    if @_git_available == :yes
      Dir.chdir(Rails.root) do
        test2 = `git rev-parse --show-toplevel 2>/dev/null`
        @_git_available = :no if test2.blank?
        if @_git_available == :yes
          test3 = `git log -n 1 . 2>/dev/null`
          @_git_available = :no if test3.blank?
        end
      end
    end
    @_git_available == :yes
  end

  # If the current app was deployed using GIT, returns the current GIT branch name.
  def self.git_branch_name
    return "" unless git_available?
    IO.popen("git rev-parse --abbrev-ref HEAD") do |fh|
      fh.gets.strip
    end
  end

  def self.for_relpath(relpath, mode = :auto) #:nodoc:
    cbrain_root = Pathname.new(Rails.root).parent
    rev = self.new("#{cbrain_root}/#{relpath}") # TODO: find the object originally registered IN its file?
    rev.get_git_rev_info(mode)
    rev
  end

  # Populates the @commit, @date, @time and @author fields with default values
  def self.unknown_rev_info
    @dummy ||= self.new("").self_update
  end

  # mode is :git, :static, or :auto
  def get_git_rev_info(mode = :auto) #:nodoc:
    return self if @commit.present? # don't do anything if we already cached the info

    # Alright, here's a set of default values in case anything goes wrong.
    @commit       = "UnknownId"
    @date         = "1970-01-01"
    @time         = "00:00:00"
    @author       = "UnknownAuthor"
    @short_commit = "UnknownId"

    # We need to fetch the info of the REAL file if the original
    # target was a symlink, because symlink don't change much in GIT!
    @fullpath = File.exists?(@fullpath) ? Pathname.new(@fullpath).realpath.to_s : @fullpath.to_s
    @basename = File.basename(@fullpath)

    return self if @basename.blank?

    if mode == :auto
      mode = self.class.git_available? ? :git : :static
    end

    if mode == :git
      self.get_git_rev_info_from_git
    else
      self.get_git_rev_info_from_static_file
    end

    self
  rescue => oops # this method should be as resilient as possible
    puts "Exception in get_git_rev_info: #{oops.class} #{oops.message}"
    self
  ensure
    self.adjust_short_commit
  end

  def adjust_short_commit #:nodoc:
    return unless @commit
    @short_commit = @commit
    @short_commit = @commit[0..7] if @commit =~ /\A[0-9a-f]{40}\z/i # if it a SHA-1 hash
    self
  end

  # Returns the artifical revision info for
  # the head of the CBRAIN code base (internally known
  # as __CBRAIN_HEAD__) or of one of the plugins packages
  # (known as e.g. __cbrain-plugins-xyz_HEAD__)
  # The keyword 'what' indicates what to fetch, either
  # the string 'CBRAIN' or the name of a plugins package.
  def self.cbrain_head_revinfo(what = 'CBRAIN') #:nodoc:

    @_head_info ||= {} # cache
    head_key = "__#{what}_HEAD__"

    # Static value
    return @_head_info[what] if @_head_info[what]
    if ! self.git_available?
      @_head_info[what] = self.for_relpath(head_key, :static)
      return @_head_info[what]
    end

    # Live value
    rails_root = Pathname.new(Rails.root)
    what_root  = what == 'CBRAIN' ? rails_root.parent : Pathname.new(CBRAIN::Plugins_Dir) + what
    Dir.chdir(what_root.to_s) do
      head_rev = self.new("#{what_root}/#{head_key}")
      return head_rev if `git rev-parse --show-toplevel 2>/dev/null`.strip != what_root.to_s
      head_info = `git log -n1 --format="%H -#- %ai -#- %an"`.strip.split(' -#- ')
      head_rev.basename = head_key
      head_rev.commit   = head_info[0]
      head_rev.author   = head_info[2]
      if head_info[1] =~ /(\d\d\d\d-\d\d-\d\dT?)\s*(\d\d:\d\d:\d\dZ?)(\s*[+-][\d:]+)?/
        head_rev.date = Regexp.last_match[1]
        head_rev.time = Regexp.last_match[2]
        head_rev.time = "#{head_rev.time}#{Regexp.last_match[3]}" if ! Regexp.last_match[3].blank?
      end
      head_rev.adjust_short_commit
      return head_rev # not cached, so it's live
    end
  end

  # Returns the artifical tag name info for
  # the CBRAIN code base (internally known
  # as __CBRAIN_TAG__) or of one of the plugins packages
  # (known as e.g. __cbrain-plugins-xyz_TAG__)
  # The keyword 'what' indicates what to fetch, either
  # the string 'CBRAIN' or the name of a plugins package.
  #
  # The tag name looks likes "1.2.3-456" where the 1.2.3
  # part is the GIT tag closest the the HEAD, and the
  # 456 is the numebr of commits between that tag and HEAD.
  # If the string returned is in parenthesis, it means the
  # value was not fetched live using GIT commands, but was
  # instead obtained from a flatfile of revision info.
  def self.cbrain_head_tag(what = 'CBRAIN') #:nodoc:

    @_cbrain_tag ||= {} # cache
    head_key = "__#{what}_TAG__"

    # Static value
    return @_cbrain_tag[what] if @_cbrain_tag[what]
    if ! self.git_available?
      tag_info = self.for_relpath(head_key, :static)
      @_cbrain_tag[what] = "(#{tag_info.try(:short_commit) || "???"})" # parentheses mean it's not live!
      return @_cbrain_tag[what]
    end

    # Live value
    git_tag    = nil
    seen       = {}
    rails_root = Pathname.new(Rails.root)
    what_root  = what == 'CBRAIN' ? rails_root.parent : Pathname.new(CBRAIN::Plugins_Dir) + what
    Dir.chdir(what_root.to_s) do
      return DEFAULT_TAG if `git rev-parse --show-toplevel 2>/dev/null`.strip != what_root.to_s
      tags_set = `git tag -l`.split.shuffle # initial list: all tags we can find
      git_tag = tags_set.shift unless tags_set.empty? # extract one as a starting point
      seen[git_tag] = true
      while tags_set.size > 0
        tags_set = `git tag --contains #{git_tag.bash_escape}`.split.shuffle.reject { |v| seen[v] }
        git_tag = tags_set.shift unless tags_set.empty? # new first
        seen[git_tag] = true
      end
      if git_tag
        num_new_commits = `git rev-list '#{git_tag}..HEAD'`.split.size
      elsif DEFAULT_TAG # fallback for plugins
        num_new_commits = `git rev-list HEAD`.split.size
        git_tag = DEFAULT_TAG
      end
      if git_tag
        git_tag += "-#{num_new_commits}" if num_new_commits > 0
      end
    end

    git_tag # not cached, so it's really live

  end

  protected

  def get_git_rev_info_from_static_file #:nodoc:
    self.class.load_all_static_revision_files

    cbrain_root = Pathname.new(Rails.root).parent
    relpath     = @fullpath ; relpath["#{cbrain_root}/"] = ""  # transforms "/path/to/root/a/b/c" -> "a/b/c"
    revinfo     = self.class.static_revision_for_relpath(relpath)

    if !revinfo # if the root of the app has been renamed... try BrainPortal
      relpath.sub!(/\A[^\/]+\//,"BrainPortal/")
      revinfo  = self.class.static_revision_for_relpath(relpath)
    end

    if !revinfo # if the root of the app has been renamed... try Bourreau
      relpath.sub!(/\A[^\/]+\//,"Bourreau/")
      revinfo  = self.class.static_revision_for_relpath(relpath)
    end

    return self unless revinfo # not much else to do

    @commit   = revinfo[0]
    datetime  = revinfo[1]
    if datetime =~ /(\d\d\d\d-\d\d-\d\dT?)\s*(\d\d:\d\d:\d\dZ?)(\s*[+-][\d:]+)?/
      @date   = Regexp.last_match[1]
      @time   = Regexp.last_match[2] + (Regexp.last_match[3] || "")
    end
    @author   = revinfo[2]

    self
  end

  def get_git_rev_info_from_git #:nodoc:

    dirname   = File.dirname(@fullpath)

    # 9f4c0900fa3e6c87131d830194d0276acb1ce595 2011-06-28 17:50:26 -0400 Pierre Rioux
    git_last_commit_info = ""

    Dir.chdir(dirname) do
      # If symlink, try to deref
      target = File.symlink?(@basename) ? File.readlink(@basename) : @basename
      File.popen("git rev-list --max-count=1 --date=iso --pretty=format:'%H %ad %an' HEAD -- ./#{target.to_s.bash_escape} 2>/dev/null","r") do |fh|
        line = fh.readline.strip rescue ""
        if line =~ /\d\d\d\d-\d\d-\d\d/
          git_last_commit_info = line
        else
          line = fh.readline.strip rescue ""
          git_last_commit_info = line if line =~ /\d\d\d\d-\d\d-\d\d/
        end
      end
    end

    if git_last_commit_info =~ /\A(\S+) (\d\d\d\d-\d\d-\d\dT?)\s*(\d\d:\d\d:\d\dZ?)(\s*[+-][\d:]+)? (\S.*\S)\s*\z/
      @commit = Regexp.last_match[1]
      @date   = Regexp.last_match[2]
      @time   = Regexp.last_match[3] + (Regexp.last_match[4] || "")
      @author = Regexp.last_match[5]
    end

    self
  end

end

