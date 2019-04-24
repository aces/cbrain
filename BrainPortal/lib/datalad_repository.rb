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

# Implements a DataProvider that can get files from a Datalad Repository
#
# To explore a Datalad Repository, a separate cached version of the repo
# with the git annex links is to be maintained separately so that we can
# explore it to find the file metadate.
#
# This library will create that cache and use it separately to maintain
# the file metadata and initiate any datalad or git annex calls that are
# needed to facilitate the data provider capability

require 'fileutils'

class DataladRepository

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Establish a connection and install the initial image of the datalad repo in a
  # Temporary cache directory

  def initialize(datalad_repository_url, datalad_relative_path,
                 dp_id="", cr_id="")
                 #local_repository_directory, local_cache_file_name)

    @prefix = File.join(datalad_repository_url,datalad_relative_path)
    @path_prefix = datalad_relative_path

    # Here we will give a unique name to this repository's cache directory
    # and assign it a Userfile to be able to maintain it, as this is related
    # to a dataprovider, the dataprovider information can be used to build the
    # directory name.
    dp_id_here = dp_id.blank? ? "aaa" : dp_id
    cr_id_here = cr_id.blank? ? "bbb" : cr_id
    prefix_clean = @prefix.dup.tr(":/.","_")
    @cache_dir_name = "Datalad.rr=#{cr_id_here}.dp=#{dp_id_here}.pre=#{prefix_clean}"

    @cache_userfile = DataladSystemSubset.find_or_create_as_scratch(:name => @cache_dir_name) do |cache_dir| end
    @cache_path = @cache_userfile.cache_full_path
    self
  end

  def connected?
    ### need to figure out how to tell if I can get stuff from datalad
    install_repository rescue false
    true
  end
  ####################################################################
  # accessor methods
  ####################################################################
  def get_prefix
    @prefix
  end

  def get_cache_path
    @cache_path
  end

  def get_cache_userfile
    @cache_userfile
  end

  ####################################################################
  # path manipulation methods
  ####################################################################

  def get_url(relative_path="")
    relative_path == "" ? @prefix : File.join(@prefix,relative_path)
  end

  def get_full_cache_path
    @cache_path
  end

  def get_full_cache_with_prefix(relative_path="")
    relative_path == "" ? File.join(@cache_path,File.basename(@path_prefix))
                        : File.join(@cache_path,File.basename(@path_prefix),relative_path)
  end

  def get_full_cache_path_for_userfile(userfile="")
    if userfile == @cache_userfile
      return @cache_userfile.cache_full_path
    else
      return userfile.cache_full_path
    end
  end
  ####################################################################
  # datalad installation methods
  ####################################################################

  def install_repository
   raise "Datalad Repository at #{@prefix} cache_directory not set prior to install" if @cache_path.nil?
    system("
           mkdir -p #{get_full_cache_path}
           cd #{get_full_cache_path}
           datalad install -r -s #{get_url.bash_escape}
           "
      )
  end

  ####################################################################
  # Listing files
  ####################################################################

  def list_contents(recursive=true, path="")
    #This is slow, I can potentially make faster by bulk operations
    install_repository
    dllist = []

    glob_string = recursive ? "#{get_full_cache_with_prefix(path)}/**/*": "#{get_full_cache_with_prefix(path)}/*"
    Dir.glob(glob_string) do |fname|
      bname = File.basename(fname)
      dname = File.dirname(fname)
      name = fname.gsub("#{get_full_cache_with_prefix}/","")

      next if name == "." || name == ".." || name == ".git" || name == ".datalad"
      # get metadata that you can only get from git-annex
      type = File.symlink?(fname) ? :symlink : File.stat(fname).ftype.to_sym rescue nil
      size = type.to_sym == :file ? File.stat(fname).size.to_i : 0

      if type.to_sym == :symlink
        ## This seems the most stable wy to get this stuff, go to the directory and git annex info it there
        git_annex_json_text = IO.popen("cd #{dname}; git annex info #{bname} --fast --json --bytes") { |fh| fh.read }
        git_annex_json = JSON.parse(git_annex_json_text)

        type = git_annex_json.key?("key") ? :gitannexlink : type

        ### now we parse
        size = git_annex_json.key?("size") ? git_annex_json['size'].to_i : 0
      end
      dllist << {:name => name, :size_in_bytes => size,:type => type}
    end
    dllist
  end

  ####################################################################
  # Getting the files
  ####################################################################

  def get_files_into_directory(src_path,dest_path,cache_rootdir_string="")
    #install_repository

    dl_command_string =  "cd #{dest_path.parent.to_s.bash_escape} ; "
    dl_command_string += "datalad install -r -g -s #{get_url(src_path)} #{dest_path.to_s.bash_escape}; "
    dl_command_string += "cd #{dest_path}; git annex uninit; chmod -R u+rwx .git"
    if cache_rootdir_string.blank?
      system(dl_command_string)
    else
      with_modified_env('SINGULARITY BINDPATH' => cache_rootdir_string) do
        system(dl_command_string)
      end
    end
  end
end



