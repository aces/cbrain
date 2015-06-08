class RmoveAnotherIndexFromUserfile < ActiveRecord::Migration
  def change
    remove_index(:userfiles, :name => 'index_userfiles_on_format_source_id_and_id')
  end
end
