
#
# CBRAIN Project
#
# Copyright (C) 2008-2024
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

# A BackgroundActivity model designed to clean up
# BackgroundActivity objects. How meta.
class BackgroundActivity::EraseBackgroundActivities < BackgroundActivity

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_save :must_be_on_portal!

  validates_dynamic_bac_presence_of_option :days_older

  def process(item)
    bac = BackgroundActivity.find(item)
    bac.destroy # a model callback will archive it in JSON in RAILS_ROOT/data_dumps/bacs/username.jsonl
  end

  def prepare_dynamic_items
    days = self.options[:days_older] || 7
    bacs = BackgroundActivity
      .where('updated_at < ?', days.to_i.days.ago)
      .unlocked
      .finished # this scope filters by type
    self.items = bacs.pluck(:id) # empty items list is okay, and will just make the BAC worker skip the cleanup
  end

end

