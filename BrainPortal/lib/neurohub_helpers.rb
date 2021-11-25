
#
# NeuroHub Project
#
# Copyright (C) 2020
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

# Helper for Neurohub interface
module NeurohubHelpers

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # For the user +user+, this method will return a proper
  # neurohub project (class WorkGroup) associated with +id_or_project+.
  # If +id_or_project_ is already a Group, it will make sure it's
  # a valid one. The WorkGroup is returned. If the validation fails,
  # an exception ActiveRecord::RecordNotFound is raised.
  def find_nh_project(user, id_or_project, options={ check_licenses: true, allow_own_group: true })
    id      = id_or_project.is_a?(Group) ? id_or_project.id : id_or_project.to_i
    return user.own_group if options[:allow_own_group] && user.own_group.id == id
    project = user.viewable_groups
                  .where(:type => 'WorkGroup')
                  .find(id)

    raise ActiveRecord::RecordNotFound unless project.can_be_accessed_by?(user)

    if options[:check_licenses] && user.unsigned_custom_licenses(project).present?
      raise CbrainLicenseException
    end

    project
  end

  # For the user +user+, this method will return
  # neurohub projects ('available' groups of class WorkGroup)
  def find_nh_projects(user, options = { allow_own_group: true })
    types  = [ 'WorkGroup' ]
    types += [ 'UserGroup' ] if options[:allow_own_group]
    user.listable_groups.where(:type => types)
  end

  # Make sure +projects+ are all assignable
  # projects (and return the sublist); if
  # +projects+ is a single project, will raise
  # an ActiveRecord::RecordNotFound just like
  # a failed find().
  def ensure_assignable_nh_projects(user, projects)
    can_assign_ids = user.assignable_group_ids
    # If argument 'projects' is a single group
    if projects.is_a?(Group)
      raise ActiveRecord::RecordNotFound unless can_assign_ids.include? projects.id
      return projects
    end
    # Modify relation
    return projects.where(:id => can_assign_ids) if projects.is_a?(ActiveRecord::Relation)
    # Subset array
    projects.select { |g| can_assign_ids.include?(g.id) }
  end

  # This function validates the page and per_page parameters
  # and store them in the session, if needed.
  def pagination_check(collection, modelkey)
    ppkey    = "#{modelkey}_per_page"
    page     = params[:page].presence.try(:to_i) || 1
    per_page = (params[:per_page].presence || session[ppkey].presence).try(:to_i) || 20
    per_page = 5 if per_page < 5 || per_page > 100

    # Compare page number with collection size and adjust if needed
    totsize  = collection.count # works for arrays or ActiveRecord relations
    offset   = (page-1)*per_page
    page     = ((totsize+per_page-1) / per_page) if offset >= totsize
    page     = 1 if page < 1 # when no entries

    # Make persistent in session
    session[ppkey] = per_page

    # Same back in params, in case someone fetches the info there (e.g. pagy)
    params[:page]     = page
    params[:per_page] = per_page

    # Return a sane page number and page size
    return [ page, per_page ]
  end

  # For +user+, return the private storage (DataProvider) named
  # by +id_or_dp+ which can be an ID or a DataProvider itself.
  def find_nh_storage(user, id_or_dp)
    id = id_or_dp.is_a?(DataProvider) ? id_or_dp.id : id_or_dp
    find_all_nh_storages(user).find(id)
  end

  # Returns all private storages (DataProviders) of +user+
  def find_all_nh_storages(user)
    UserkeyFlatDirSshDataProvider.where(:user_id => user.id)
  end

  # Returns a list of other data providers made availabel to NeuroHub users
  # by the admin (requires setting mmeta[:neurohub_service_dp_ids] on the
  # BrainPortal object of the NeuroHub server)
  def nh_service_storages(user)
    svc_ids = RemoteResource.current_resource.meta[:neurohub_service_dp_ids].presence || [ -999 ]
    DataProvider.find_all_accessible_by_user(user).where(:id => svc_ids)
  end

  # This method implements the 'search for anything' for the controller portal action +search+
  # for NeuroHub
  #
  # If +token+ looks like an ID, the models are searched by ID only.
  # Otherwise, models are searched by name, description.
  #
  # It returns a hash table with these keys:
  #
  #   {
  #     :tasks  => [],  # CbrainTask objects
  #     :groups => [],  # Group objects
  #     :files  => [],  # Userfile objects
  #   }
  def neurohub_search(token, limit=20, user=current_user)
    token      = token.to_s.presence  || "-9998877"          # -9998877 is a way to ensure we find nothing ...
    is_numeric = token =~ /\A\d+\z/   || token == "-9998877" # ... because we'll find by ID
    token      = is_numeric ? token.to_i : "%#{token}%"

    if is_numeric
      files    = Array(Userfile.find_all_accessible_by_user(user, :access_requested => :read).find_by_id(token))
      tasks    = Array(CbrainTask.find_all_accessible_by_user(user).find_by_id(token))
      projects = Array(user.viewable_groups.find_by_id(token))
    else
      files    = Userfile.find_all_accessible_by_user(user, :access_requested => :read).where([ "name like ? OR description like ?", token, token ]).limit(limit)
      tasks    = CbrainTask.find_all_accessible_by_user(user).where([ "description like ?", token ]).limit(limit)
      projects = user.viewable_groups.where([ "name like ? OR description like ?", token, token]).limit(limit)
    end

    report = {files: files, tasks: tasks, projects: projects}
    return report
  end

  # filter proper NeuroHub messages (no invites)
  def find_nh_messages(user = current_user)
    Message.where(:user_id => user.id,
                  :type => nil   # show only basic messages not invitations
                  ).order("last_sent DESC")
  end

  # valid possible message recipients (only co-members)
  def find_nh_message_recipients(user = current_user)
    # Projects that the user can assign to resources
    projs = find_nh_projects(user)
    projs = ensure_assignable_nh_projects(user, projs)
    # List of users in these projects
    user_ids    = (projs.to_a.map(&:user_ids).flatten + [user.id]).uniq
    user_logins = User.where(:id => user_ids).pluck(:login)
    # Same list as a set of UserGroup
    user_projs  = UserGroup.where(:name => user_logins)
    # The possible destinations are described by a set of Groups
    projs.to_a + user_projs.to_a
  end

end
