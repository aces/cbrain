class RenameMessageGroupIdToInvitationGroupId < ActiveRecord::Migration[5.0]
  def up
    # Add invitation_group_id if neither column exists.
    unless column_exists?(:messages, :group_id) || column_exists?(:messages, :invitation_group_id)
      add_column :messages, :invitation_group_id, :integer
      return
    end
    
    # Rename if old column exists and new doesn't.
    if column_exists?(:messages, :group_id) && !column_exists?(:messages, :invitation_group_id)
      rename_column :messages, :group_id, :invitation_group_id
    end
  end

  def down
    # Add group_id if neither column exists.
    unless column_exists?(:messages, :group_id) || column_exists?(:messages, :invitation_group_id)
      add_column :messages, :group_id, :integer
      return
    end
    
    # Rename if new column exists and old doesn't.
    if column_exists?(:messages, :invitation_group_id) && !column_exists?(:messages, :group_id)
      rename_column :messages, :invitation_group_id, :group_id
    end
  end
end 
