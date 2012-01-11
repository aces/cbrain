class AddWorkdirArchivedToCbrainTask < ActiveRecord::Migration
  def self.up
    add_column    :cbrain_tasks, :workdir_archived,            :boolean
    add_column    :cbrain_tasks, :workdir_archive_userfile_id, :integer
  end

  def self.down
    remove_column :cbrain_tasks, :workdir_archived
    remove_column :cbrain_tasks, :workdir_archive_userfile_id
  end
end
