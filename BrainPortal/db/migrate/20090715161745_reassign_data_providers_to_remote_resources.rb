class ReassignDataProvidersToRemoteResources < ActiveRecord::Migration
  def self.up

    raise "Error: this migration can only be performed when DataProviders is a subclass of RemoteResource !" unless DataProvider < RemoteResource

    # Prepare to rename bourreaux
    oldBourreaux = []  # list of attribute hashes from old Bourreaux
    RemoteResource.all.each do |rr|
      raise "Error! Unknown object if type '#{rr.class.to_s}' in RemoteResource!" unless rr.is_a?(Bourreau)
      allatt   = rr.attributes
      oldBourreaux << allatt
    end

    drop_table   :remote_resources
    rename_table :data_providers,   :remote_resources

    bourreaux_old2new = {}  # remember how bourreau IDs change
    oldBourreaux.each do |att|
      oldid    = att["id"]
      record   = Bourreau.create!(att)
      bourreaux_old2new[oldid] = record.id
    end

    ActRecTask.all.each do |task|
      oldid = task.bourreau_id
      next unless oldid
      newid = bourreaux_old2new[oldid]
      task.update_attributes( { :bourreau_id => newid } )
    end

    UserPreference.all.each do |up|
      oldid = up.bourreau_id
      next unless oldid
      newid = bourreaux_old2new[oldid]
      up.update_attributes( { :bourreau_id => newid } )
    end

  end

  def self.down

    raise "Error: this migration can only be performed when DataProviders is a subclass of RemoteResource !" unless DataProvider < RemoteResource

    # Prepare to rename bourreaux
    oldBourreaux = []  # list of attribute hashes from old Bourreaux
    RemoteResource.all.each do |b|
      next unless b.is_a?(Bourreau)
      allatt   = b.attributes
      oldBourreaux << allatt
      Bourreau.delete(b.id)
    end

    rename_table :remote_resources, :data_providers
    create_table :remote_resources do |t|
      t.string  :name
      t.string  :type          # for polymorphism
      t.integer :user_id
      t.integer :group_id

      t.string  :remote_user
      t.string  :remote_host
      t.integer :remote_port
      t.string  :remote_dir

      t.boolean :online
      t.boolean :read_only

      t.string  :description

      t.timestamps
    end

    bourreaux_old2new = {}  # remember how bourreau IDs change
    oldBourreaux.each do |att|
      oldid    = att["id"]
      record   = Bourreau.create!(att)
      bourreaux_old2new[oldid] = record.id
    end

    ActRecTask.all.each do |task|
      oldid = task.bourreau_id
      next unless oldid
      newid = bourreaux_old2new[oldid]
      task.update_attributes( { :bourreau_id => newid } )
    end

    UserPreference.all.each do |up|
      oldid = up.bourreau_id
      next unless oldid
      newid = bourreaux_old2new[oldid]
      up.update_attributes( { :bourreau_id => newid } )
    end

  end

end
