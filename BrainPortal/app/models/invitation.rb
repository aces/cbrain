
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

# A type of message specifically sent out by one user to invite another
# user to their project.
class Invitation < Message

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  belongs_to    :group, foreign_key: :invitation_group_id

  before_create :make_active

  after_create  :add_description  #Need to put the id in there.

  # Send an invitation to project +group+ from +sender+ to +users+.
  def self.send_out(sender, group, users)
    # Invitations are persisted and emailed in each recipient's saved language.
    find_users_for_destination(users).flat_map do |recipient|
      locale = recipient.meta[:locale].to_s.to_sym
      locale = I18n.default_locale unless I18n.available_locales.include?(locale)
      I18n.with_locale(locale) do
        send_message(recipient,
          :message_type        => "notice",
          :header              => I18n.t('project_invitations.subject', sender: sender.full_name, project: group.name),
          :invitation_group_id => group.id,
          :send_email          => true,
          :sender_id           => sender.id,
          :description         => I18n.t('project_invitations.email', sender: sender.full_name, project: group.name)
        )
      end
    end
  end

  private

  def make_active #:nodoc:
    self.active = true
  end

  def add_description #:nodoc:
    locale = user.meta[:locale].to_s.to_sym
    locale = I18n.default_locale unless I18n.available_locales.include?(locale)
    I18n.with_locale(locale) do
      self.description = I18n.t('project_invitations.description', project: group.name, sender: sender.full_name) +
        "\n\n[[#{I18n.t('project_invitations.accept')}][/invitations/#{id}][put]]"
    end
    self.save!
  end

end
