
#
# CBRAIN Project
#
# Copyright (C) 2008-2023
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

# This DataProvider class implements a remote SSH-accessible data provider
# using the EnCbrainSshDataProvider file structure, but with an added
# functionality:
#
# 1) the content of any FileCollection will be locally
# squashed with the command 'mksquashfs' before being sent to the
# data provider side (aka synchronizing to the provider).
#
# 2) Conversely a FileCollection's content will be unsquashed with
# the command 'unsquashfs' when synchronizing to the cache.
#
# This DP requires the Rails application to have access to these
# two commands, of course.
#
# Note that this DP cannot be made into a 'Smart' version, since the
# content on the DP side is always different from the content on th
# cache side, even when working with both under the same host. So
# there will always be a SSH upload and download operation whenever
# syncing to or from the cache.
#
# TODO refactor to avoid code duplication. That would require creating a new
# base-class abstract method cache_full_path_for_upload() and
# cache_full_path_for_download() (suggested names) that DP subclasses
# would use to implement their data transfer methods, distinct from
# cache_full_pathname()
class SquashifierEnCbrainSshDataProvider < EnCbrainSshDataProvider

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Name of the squashfs file that will contain a filecollection's squashified content
  # This is a constant name independant of what the collection's own name is.
  SQ_BASENAME = "CBRAIN_SquashedContent.squashfs"

  # This returns the category of the data provider
  def self.pretty_category_name #:nodoc:
    "Squashifier Enhanced SSH CBRAIN"
  end

  def impl_sync_to_cache(userfile) #:nodoc:
    return super if userfile.is_a?(SingleFile)

    # Normal code will fetch (remote) basename/basename.sqs into (local) basename/basename.sqs
    super

    # Then we unsquash it all
    fullpath    = cache_full_path(userfile) # path to dir; in it is the .sqs file
    cacheparent = fullpath.parent
    basename    = userfile.name
    tmpdirbase  = ".tmp.unsq.#{Process.pid}"
    unsqu_out   = bash_this(
      "cd #{cacheparent.to_s.bash_escape} && " +
      "mv #{basename.bash_escape} #{tmpdirbase} && " +
      "unsquashfs -f -n -p 1 -no-xattrs -d #{basename.bash_escape} #{tmpdirbase.bash_escape}/#{SQ_BASENAME.bash_escape} 2>&1 1>/dev/null && " +
      "rm -rf #{tmpdirbase}"
    )
    # Perform cleanup of expected messages (stupid unsquashfs program is too verbose)
    #[
    #  # In the following regexps, the trailing .* match anything to NL (but not including it)
    #  /^Parallel unsquashfs: Using \d+ processor.*/i,
    #  /^\d+ inodes.*to write.*/i,
    #  /^created \d+.*/i,
    #].each { |regex| unsqu_out.sub!(regex,"") }
    unsqu_out.strip! # remove all blanks on each side, whatever's left is the culprit
    cb_error "Error syncing userfile ##{userfile.id} to local cache, unsquashfs commands returned:\n#{unsqu_out}" unless unsqu_out.blank?
    true
  end

  def impl_sync_to_provider(userfile) #:nodoc:
    return super if userfile.is_a?(SingleFile)

    fullpath    = cache_full_path(userfile) # without SQEXT
    cacheparent = fullpath.parent
    basename    = userfile.name
    tmpdirbase  = ".tmp.mksq.#{Process.pid}"
    # Note about the mksquashfs command: by supplying a single source argument ('basename'), the
    # *content* of that directory is put directly at the top of the created squashfs filesystem.
    mem_opt     = self.class.mksquashfs_has_mem_option? ? "-mem 64m" : ""
    mksqu_out   = bash_this(
      "cd #{cacheparent.to_s.bash_escape} && " +
      "mkdir -p #{tmpdirbase.bash_escape} && " +
      "mksquashfs #{basename.bash_escape} #{tmpdirbase.bash_escape}/#{SQ_BASENAME.bash_escape} -processors 1 -no-progress -noappend -no-xattrs -noD -noI -noF #{mem_opt} 2>&1 1>/dev/null || echo mksquashfs command failed"
    )
    # Perform cleanup of expected messages (stupid mksquashfs program is too verbose)
    #[
    #  # In the following regexps, the trailing .* match anything to NL (but not including it)
    #  /^created \d+.*/i,
    #].each { |regex| unsqu_out.sub!(regex,"") }
    mksqu_out.strip!
    cb_error "Error syncing userfile ##{userfile.id} to provider, mksquashfs commands returned:\n#{mksqu_out}" unless mksqu_out.blank?

    # Invoke the normal code; duplicated from superclasses unfortunately

    # -------
    # Prep code from EnCbrainSshDataProvider (simplified a little)
    # -------
    threelevels   = cache_subdirs_from_id(userfile.id)
    remcachedir   = Pathname.new(remote_dir) + threelevels[0] + threelevels[1] + threelevels[2]
    mkdir_command = "mkdir -p #{remcachedir.to_s.bash_escape} >/dev/null 2>&1"
    remote_bash_this(mkdir_command)
    # -------
    # End of EnCbrainSshDataProvider code
    # -------

    # -------
    # rsync upload code from SshDataProvider, adjusted
    # -------
    localfull   = cacheparent + tmpdirbase
    remotefull  = provider_full_path(userfile)
    cb_error "Error: directory #{localfull} does not exist in local cache!" unless File.exist?(localfull)

    sourceslash = "/" # constant this time
    rsync       = rsync_over_ssh_prefix(userfile.user, userfile)

    # Double escaping for old rsyncs
    dest_escaped = remote_shell_escape(remotefull)
    # As of rsync 3.1.2, rsync does the escaping of the remote path properly itself
    dest_escaped = remotefull.to_s.bash_escape if self.class.local_rsync_protects_args?

    # It's IMPORTANT that the destination be specified with a bare ':' in front.
    text = bash_this("#{rsync} -a -l --no-g --chmod=u=rwX,g=rX,Dg+s,o=r --delete #{self.rsync_excludes} #{shell_escape(localfull)}#{sourceslash} :#{dest_escaped} 2>&1")
    cb_error "Error syncing userfile ##{userfile.id} to data provider, rsync returned:\n#{text}" unless text.blank?
    unless self.provider_file_exists?(userfile).to_s =~ /file|dir/
      cb_error "Error syncing userfile ##{userfile.id} to data provider: no destination file found after rsync?\n" +
               "Make sure you are running rsync 3.0.6 or greater!\n"
    end
    # -------
    # End of SshDataProvider code
    # -------

    true
  ensure
    # Cleanup local squashfs file no matter what
    if cacheparent.to_s.present? && tmpdirbase.present? && File.directory?("#{cacheparent.to_s.bash_escape}/#{tmpdirbase.bash_escape}")
      system "rm -rf #{cacheparent.to_s.bash_escape}/#{tmpdirbase.bash_escape}"
    end
  end

  # Check the capabilities of the local mksquashfs program.
  # Returns true if it has -mem . Value cached in class variable.
  def self.mksquashfs_has_mem_option?
    return @_mksquashfs_mem_ if defined?(@_mksquashfs_mem_)
    system "mksquashfs 2>&1 | grep -e -mem >/dev/null"
    @_mksquashfs_mem_ = $?.success?
    @_mksquashfs_mem_
  end

end

