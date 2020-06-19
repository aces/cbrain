
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

# Simple controller for creating/editing access profiles, which are
# an admin-only resource.
class AccessProfilesController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_action :login_required
  before_action :admin_role_required

  def index #:nodoc:

    @scope = scope_from_session
    scope_default_order(@scope, 'name')

    @base_scope       = AccessProfile.where({})
    @access_profiles  = @scope.apply(@base_scope)

    respond_to do |format|
      format.html # index.html.erb
    end
  end

  def show #:nodoc:
    @access_profile = AccessProfile.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
    end
  end

  def new #:nodoc:
    @access_profile = AccessProfile.new
    respond_to do |format|
      format.html { render :action => :show           }  # show is also new/create
      format.xml  { render :xml    => @access_profile }
    end
  end

  def create #:nodoc:
    @access_profile = AccessProfile.new(access_profile_params)

    respond_to do |format|
      if @access_profile.save
        flash[:notice] = 'AccessProfile was successfully created.'
        format.html  { redirect_to :action => :index }
      else
        format.html  { render :action  => :show }
      end
    end
  end

  def update #:nodoc:
    @access_profile = AccessProfile.find(params[:id])

    # Remember 'before' state for the two main associations
    old_group_ids = @access_profile.group_ids.sort
    old_user_ids  = @access_profile.user_ids.sort

    # The success variable will be false for errors on ordinary attributes;
    # for the group_ids and user_ids list, these are always updated with no errors or logging... :-(
    success = @access_profile.update_attributes_with_logging(access_profile_params, current_user)

    # Adjust groups and users, and log differences
    new_group_ids = @access_profile.group_ids.sort
    new_user_ids  = @access_profile.user_ids.sort
    @access_profile.addlog_object_list_updated("Projects", Group, old_group_ids, new_group_ids, current_user)
    @access_profile.addlog_object_list_updated("Users",    User,  old_user_ids,  new_user_ids,  current_user, :login)

    # Group list has changed? Apply to each affected user
    if old_group_ids != new_group_ids
      ap_removed_gids = old_group_ids - new_group_ids # what disappeared in the current AP
      affected_users = User.where(:id => params[:affected_user_ids]).all
      affected_users.each do |user|
        orig_user_gids = user.group_ids
        user.apply_access_profiles(remove_group_ids: ap_removed_gids) # (re)add all groups from all APs of the user, minus lost groups
        user.addlog_object_list_updated("Updated Access Profile '#{@access_profile.name}', Projects",
                                        Group, orig_user_gids, user.group_ids, current_user)
      end
    end

    # New users added to the the AP? Adjust their groups
    added_uids   = new_user_ids - old_user_ids
    User.find(added_uids).each do |user|
      orig_user_gids = user.group_ids
      user.apply_access_profiles() # add all groups in all APs of the user, including the current one
      user.addlog_object_list_updated("Added Access Profile '#{@access_profile.name}', Projects",
                                      Group, orig_user_gids, user.group_ids, current_user)
    end

    # Some users lost access to the the AP? Adjust their groups
    removed_uids = old_user_ids - new_user_ids
    User.find(removed_uids).each do |user|
      orig_user_gids = user.group_ids
      user.apply_access_profiles(remove_group_ids: new_group_ids) # try removing all groups in current AP
      user.addlog_object_list_updated("Removed Access Profile '#{@access_profile.name}', Projects",
                                      Group, orig_user_gids, user.group_ids, current_user)
    end

    respond_to do |format|
      if success
        flash[:notice] = 'AccessProfile was successfully updated.'
        format.html { redirect_to :action => "show" }
        format.xml  { head :ok }
      else
        # @access_profile.reload
        format.html { render :action => "show" }
      end
    end
  end

  def destroy #:nodoc:
    @access_profile = AccessProfile.find(params[:id])
    orig_user_ids   = @access_profile.user_ids
    orig_group_ids =  @access_profile.group_ids
    @access_profile.destroy
    User.find(orig_user_ids).each do |user|
      orig_user_gids = user.group_ids
      user.apply_access_profiles(remove_group_ids: orig_group_ids) # try removing all groups in current AP
      user.addlog_object_list_updated("Destroyed Access Profile '#{@access_profile.name}', Projects",
                                      Group, orig_user_gids, user.group_ids, current_user)
    end

    respond_to do |format|
      format.html { redirect_to :action => :index, :status => 303 }
    end
  end

  private

  def access_profile_params
    params.require(:access_profile).permit(:name, :color, :description, :group_ids => [], :user_ids => [])
  end

end
