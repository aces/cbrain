class AddInvitationGroupIdAndTypeAndActiveToMessages < ActiveRecord::Migration
  def self.up
    add_column :messages, :invitation_group_id, :integer
    add_column :messages, :type, :string
    add_column :messages, :active, :boolean
  end

  def self.down
    remove_column :messages, :type
    remove_column :messages, :invitation_group_id
    remove_column :messages, :active
  end
end
