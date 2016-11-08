
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

# Friendly Fast Finder
# Search for anything by ID or name.
# Sets variables in the console with the objects found:
#
#   @ff # array of Userfile objects
#   @tt # array of CbrainTask objects
#   @uu # array of User objects
#   @gg # array of Group objects
#   @rr # array of RemoteResource objects
#   @dd # array of DataProvider objects
#   @ss # array of Site objects
#   @oo # array of Tool objects
#   @cc # array of ToolConfig objects
#
# At the same time, if any of these arrays contain any entries
# a similar variable with a single letter name (e.g. @u, @t, @g etc) will
# be set to the first entry of the array.
#
# A special subject of @rr containing only objects of subclass Bourreau will
# be in @bb (with the similar @b also set).
def fff(token)

  results=no_log { ModelsReport.search_for_token(token,cu) }
  @ff = results[:files  ]; @f = @ff[0]
  @tt = results[:tasks  ]; @t = @tt[0]
  @uu = results[:users  ]; @u = @uu[0]
  @gg = results[:groups ]; @g = @gg[0]
  @rr = results[:rrs    ]; @r = @rr[0]
  @dd = results[:dps    ]; @d = @dd[0]
  @ss = results[:sites  ]; @s = @ss[0]
  @oo = results[:tools  ]; @o = @oo[0]
  @cc = results[:tcs    ]; @c = @cc[0]
  @bb = @rr.select { |r| r.is_a?(Bourreau) }; @b = @bb[0]

  report = lambda do |name,letter|  # ("User", 'u') will look into @uu and @u
    list = eval "@#{letter}#{letter}" # look up @uu or @ff etc
    next if list.size == 0
    if (list.size == 1)
      first = list[0]
      pretty = first.respond_to?(:to_summary) ? no_log { first.to_summary } : first.inspect[0..60]
      printf "%15s : @#{letter} = %s\n",name,pretty
    else
      printf "%15s : @#{letter}#{letter} contains %d results\n",
        ApplicationController.helpers.pluralize("2",name).sub(/\A[\s\d]+/,""), # ugleeee
        list.size
    end
  end

  report.("File",           'f')
  report.("Task",           't')
  report.("User",           'u')
  report.("Group",          'g')
  report.("DataProvider",   'd')
  report.("RemoteResource", 'r')
  report.("Site",           's')
  report.("Tool",           'o')
  report.("ToolConfig",     'c')
  report.("Bourreau",       'b')

end

#####################################################
# Add 'to_summary' methods to the objects that can
# be found by 'fff', for pretty reports.
#####################################################

# Make sure the classes are loaded
# Note that it's important to load PortalTask too, because of its own pre-loading of subclasses.
[ Userfile, CbrainTask, User, Group, DataProvider, RemoteResource, Site, Tool, ToolConfig, Bourreau ]
PortalTask.nil? rescue true
CluserTask.nil? rescue true


class Userfile
  def to_summary
    sprintf "<%s#%d> [%s:%s] S=%s N=\"%s\" DP=%s",
      self.class.to_s, self.id,
      user.login,      group.name,
      size ? size : "unk",
      name,            data_provider.name
  end
end

class CbrainTask
  def to_summary
    sprintf "<%s#%d> [%s:%s] S=%s B=%s",
      self.class.to_s, self.id,
      user.login,      group.name,
      cluster_workdir_size.presence || "unk",
      bourreau.name
  end
end

class User
  def to_summary
    sprintf "<%s#%d> L=%s F=\"%s\" S=%s",
      self.class.to_s, self.id,
      login,      full_name,
      site.try(:name) || "(No site)"
  end
end

class Group
  def to_summary
    sprintf "<%s#%d> N=\"%s\" C=%s",
      self.class.to_s, self.id,
      name,
      creator.try(:login) || "(No creator)"
  end
end

class DataProvider
  def to_summary
    sprintf "<%s#%d> [%s:%s] N=\"%s\"",
      self.class.to_s, self.id,
      user.login,      group.name,
      name
  end
end

class RemoteResource
  def to_summary
    sprintf "<%s#%d> [%s:%s] N=\"%s\"",
      self.class.to_s, self.id,
      user.login,      group.name,
      name
  end
end

class Site
  def to_summary
    sprintf "<%s#%d> N=\"%s\"",
      self.class.to_s, self.id,
      name
  end
end

class Tool
  def to_summary
    sprintf "<%s#%d> [%s:%s] N=\"%s\" C=%s",
      self.class.to_s, self.id,
      user.login,      group.name,
      name,
      cbrain_task_class_name
  end
end

class ToolConfig
  def to_summary
    sprintf "<%s#%d> [%s] T=%s B=%s V=\"%s\"",
      self.class.to_s, self.id,
      group.name,
      try(:tool).try(:name)     || "(No tool)",
      try(:bourreau).try(:name) || "(No bourreau)",
      version_name.presence     || "(No version)"
  end
end

(CbrainConsoleFeatures ||= []) << <<FEATURES
========================================================
Feature: fast finder for anything
========================================================
  Activate with: fff 'string' ; fff id
FEATURES

