class CreateTagsUserfilesJoin < ActiveRecord::Migration
  def self.up
    create_table :tags_userfiles, :id => false do |t|
      t.integer   :tag_id
      t.integer   :userfile_id
    end
  end

  def self.down
    drop_table :tags_userfiles
  end
end
