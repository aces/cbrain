
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
#   puts Abcd::Revision_info.to_s # in SVN-like format
#   puts Abcd::Revision_info.svn_id_rev # using CBRAIN's svn_id_rev parser
#   puts Abcd.revision_info.svn_id_rev  # using CBRAIN's revision_info method
#   x = Abcd.new
#   puts x.revision_info.svn_id_rev
#   puts x.revision_info.short_commit # using attributes
#
#   # If at least once to_s() or self_update() has been called,
#   # the the attributes can also be accessed directly:
#   Abcd::Revision_info.self_update
#   puts Abcd::Revision_info.author  # faster than svn_id_author()
#

require 'csv'
require 'pathname'

class CbrainFileRevision

  # Attributes for linking the object to a disk file
  attr_accessor :fullpath # this one is filled when the object is initialized
  attr_accessor :basename

  # Official attributes
  attr_accessor :author, :commit, :short_commit, :date, :time

  # Fake SVN ID
  attr_accessor :fake_svn_id_string

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

  # Returns the revision info in a fake 'svn' format:
  #   "$Id: en_cbrain_local_data_provider.rb 12ab34 2010-03-25 17:26:05Z prioux $"
  # Note that this triggers a self_update() call, if necessary, the first time.
  def to_s
    return @fake_svn_id_string if ! @fake_svn_id_string.nil? # Cached; no need to fetch git info every time.
    self_update()
    @fake_svn_id_string = "$Id: #{@basename} #{@short_commit} #{@date} #{@time} #{@author} $"
    @fake_svn_id_string
  end

  # Returns the date and time of the revision info, separated by a space.
  #
  #   "2010-03-25 17:26:05 -0400"
  def datetime
    self_update()
    "#{@date} #{@time}"
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

  # Class method. Slurps a static file of revision info
  # and caches it.
  def self.load_static_revision_file(path=nil) #:nodoc:
    return true unless @_static_revision_hash.blank?
    cbrain_root   = Pathname.new(Rails.root).parent
    path        ||= cbrain_root + "cbrain_file_revisions.csv"
    @_static_revision_hash = {}

    CSV.foreach(path.to_s, :col_sep => ' -#- ') do |row|
      # 7f6bb2f24f6afb3d3b355d6c0ad630cdf353e1fe -#- 2011-07-18 17:16:57 -0400 -#- Pierre Rioux -#- Bourreau/README
      commit   = row[0]
      datetime = row[1]
      author   = row[2]
      relpath  = row[3]
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

  # mode is :git, :static, or :auto
  def get_git_rev_info(mode = :auto) #:nodoc:
    return self unless @commit.nil? # don't do anything if we already cached the info

    # Alright, here's a set of default values in case anything goes wrong.
    @commit   = "UnknownId"
    @date     = "1970-01-01"
    @time     = "00:00:00"
    @author   = "UnknownAuthor"

    # We need to fetch the info of the REAL file if the original
    # target was a symlink, because symlink don't change much in GIT!
    @fullpath = File.exists?(@fullpath) ? Pathname.new(@fullpath).realpath.to_s : @fullpath.to_s
    @basename = File.basename(@fullpath)

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
    @short_commit = @commit[0..7] if @commit =~ /^[0-9a-f]{40}$/i # if it a SHA-1 hash
    self
  end

  def self.cbrain_head_revinfo #:nodoc:

    # Static value
    return @_head_info if @_head_info
    if ! self.git_available?
      @_head_info = self.for_relpath('__CBRAIN_HEAD__', :static)
      return @_head_info
    end

    # Live value
    cbrain_root = Pathname.new(Rails.root).parent
    Dir.chdir(cbrain_root) do
      head_info = `git log -n1 --format="%H -#- %ai -#- %an"`.strip.split(' -#- ')
      head_rev = self.new("#{cbrain_root}/__CBRAIN_HEAD__")
      head_rev.basename = '__CBRAIN_HEAD__'
      head_rev.commit   = head_info[0]
      head_rev.author   = head_info[2]
      if head_info[1] =~ /(\d\d\d\d-\d\d-\d\dT?)\s*(\d\d:\d\d:\d\dZ?)(\s*[+-][\d:]+)?/
        head_rev.date = Regexp.last_match[1]
        head_rev.time = Regexp.last_match[2]
        head_rev.time = "#{head_rev.time}#{Regexp.last_match[3]}" if ! Regexp.last_match[3].blank?
      end
      head_rev.adjust_short_commit
      return head_rev
    end
  end

  def self.cbrain_head_tag #:nodoc:

    # Static value
    return @_cbrain_tag if @_cbrain_tag
    if ! self.git_available?
      tag_info = self.for_relpath('__CBRAIN_TAG__', :static)
      @_cbrain_tag = "(#{tag_info.commit})" # parentheses mean it's not live!
      return @_cbrain_tag
    end

    # Live value
    git_tag = nil
    seen = {}
    Dir.chdir(Rails.root.to_s) do
      tags_set = `git tag -l`.split.shuffle # initial list: all tags we can find
      git_tag = tags_set.shift unless tags_set.empty? # extract one as a starting point
      seen[git_tag] = true
      while tags_set.size > 0
        tags_set = `git tag --contains #{git_tag.bash_escape}`.split.shuffle.reject { |v| seen[v] }
        git_tag = tags_set.shift unless tags_set.empty? # new first
        seen[git_tag] = true
      end
      if git_tag
        num_new_commits = `git rev-list #{git_tag.bash_escape}..HEAD`.split.size
        git_tag += "-#{num_new_commits}" if num_new_commits > 0
      end
    end

    git_tag

  end

  protected

  def get_git_rev_info_from_static_file #:nodoc:
    self.class.load_static_revision_file

    cbrain_root = Pathname.new(Rails.root).parent
    relpath     = @fullpath ; relpath["#{cbrain_root}/"] = ""  # transforms /path/to/root/a/b/c -> /a/b/c"
    revinfo     = self.class.static_revision_for_relpath(relpath)

    if !revinfo # if the root of the app has been renamed... try BrainPortal
      relpath.sub!(/^[^\/]+\//,"BrainPortal/")
      revinfo  = self.class.static_revision_for_relpath(relpath)
    end

    if !revinfo # if the root of the app has been renamed... try Bourreau
      relpath.sub!(/^[^\/]+\//,"Bourreau/")
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

    if git_last_commit_info =~ /^(\S+) (\d\d\d\d-\d\d-\d\dT?)\s*(\d\d:\d\d:\d\dZ?)(\s*[+-][\d:]+)? (\S.*\S)\s*$/
      @commit = Regexp.last_match[1]
      @date   = Regexp.last_match[2]
      @time   = Regexp.last_match[3] + (Regexp.last_match[4] || "")
      @author = Regexp.last_match[5]
    end

    self
  end

end

