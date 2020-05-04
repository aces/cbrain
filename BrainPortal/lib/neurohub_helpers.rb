
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

  # For the user +user+, this method will return a proper
  # neurohub project (class WorkGroup) associated with +id_or_project+.
  # If +id_or_project_ is already a Group, it will make sure it's
  # a valid one. The WorkGroup is returned. If the validation fails,
  # an exception ActiveRecord::RecordNotFound is raised.
  def find_nh_project(user, id_or_project, check_license=true)
    id      = id_or_project.is_a?(Group) ? id_or_project.id : id_or_project
    project = user.viewable_groups
                  .where(:type => 'WorkGroup')
                  .where(:invisible => false)
                  .find(id)

    raise ActiveRecord::RecordNotFound unless project.can_be_accessed_by?(user)

    if check_license && user.unsigned_custom_licenses(project).present?
      raise CbrainLicenseException
    end

    project
  end

  # For the user +user+, this method will return
  # neurohub projects ('available' groups of class WorkGroup)
  def find_nh_projects(user)
    user.viewable_groups
        .where(:type      => 'WorkGroup')
        .where(:invisible => false)
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
  def neurohub_search(token, limit=nil, user=current_user)
    token      = token.to_s.presence || "-9998877"           # -9998877 is a way to ensure we find nothing ...
    is_numeric = token =~ /\A\d+\z/   || token == "-9998877" # ... because we'll find by ID
    ptoken    = "%#{token}%"

    workgroup_public_ids = WorkGroup.where(:public => true).pluck(:id)

    # Find files
    files_accessible_by_user_ids = Userfile.find_all_accessible_by_user(current_user).pluck(:id)
    files_in_public_group_ids    = Userfile.where(:group_id => workgroup_public_ids).pluck(:id)
    files_ids                    = (files_accessible_by_user_ids + files_in_public_group_ids).uniq

    file_scope                   = Userfile.where(:id => files_ids)

    files = is_numeric ?
                Array(file_scope.find_by_id(token)) :
                file_scope.where([ "name like ? OR description like ?", ptoken, ptoken])
    files = files.limit(limit) if files.is_a?(ActiveRecord::Relation) && limit

    # Find tasks
    tasks_accessible_by_user_ids = CbrainTask.find_all_accessible_by_user(current_user).pluck(:id)
    tasks_in_public_group_ids    = CbrainTask.where(:group_id => workgroup_public_ids).pluck(:id)
    tasks_ids                    = (tasks_accessible_by_user_ids + tasks_in_public_group_ids).uniq
    
    task_scope                   = CbrainTask.where(:id => tasks_ids)

    tasks = is_numeric ?
                Array(task_scope.find_by_id(token)) :
                task_scope.where([ "description like ?", ptoken])

    tasks = tasks.limit(limit) if tasks.is_a?(ActiveRecord::Relation) && limit


    # Find groups
    workgroup_ids = WorkGroup.pluck(:id)
    project_scope = current_user.viewable_groups.order(:name)

    projects = is_numeric ?
                        Array(project_scope.find_by_id(token)) :
                        project_scope.where( ["name like ? OR description like ?", ptoken, ptoken ]).where(:id => workgroup_ids).limit(limit)
  
    projects = projects.limit(limit) if projects.is_a?(ActiveRecord::Relation) && limit

    report = {files: files, tasks: tasks, projects: projects}
    return report
  end

end
