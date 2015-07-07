class RemoveIndexFromUserfiles < ActiveRecord::Migration
  def change
    remove_index(:userfiles, :name => 'index_userfiles_on_format_source_id_and_data_provider_id')
    remove_index(:userfiles, :name => 'index_userfiles_on_format_source_id_and_group_id')
    remove_index(:userfiles, :name => 'index_userfiles_on_format_source_id_and_type')
    remove_index(:userfiles, :name => 'index_userfiles_on_format_source_id_and_user_id')
  end

end
