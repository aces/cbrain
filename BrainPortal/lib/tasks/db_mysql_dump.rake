
# Utility to help developers dump their own DB.
# Not to be used in production settings! The sysadmin should
# already have a DB backup mechanism fully in place outside of CBRAIN.

namespace :db do
  namespace :mysql do

    desc "Dump the database for the selected RAILS_ENV"
    task :dump do

      db_file    = (Rails.root + "config/database.yml").to_s
      db_configs = YAML.load(File.read(db_file))
      db_config  = db_configs[Rails.env]

      raise RuntimeError.new("Can't find the current DB configuration") unless db_config.present?
      raise RuntimeError.new("This only works for mysql adapters")      unless db_config['adapter'] =~ /^mysql/

      dumpdir = (Rails.root + 'data_dumps/mysqldumps').to_s
      Dir.mkdir(dumpdir) unless Dir.exist?(dumpdir)
      dumpfile = dumpdir + "/#{Rails.env}.#{Time.now.strftime("%Y-%m-%dT%H%M%S")}.sql"

      host = db_config['hostname'] || 'localhost'
      port = db_config['port']     || '3306'
      user = db_config['username'] || 'unknown_username'
      pw   = db_config['password'] || 'unknown_password'
      db   = db_config['database'] || 'unknown_database'
      args = "mysqldump -h #{host} -P #{port} -u #{user} --password='#{pw}' #{db} > #{dumpfile}"

      puts "Attempting to dump the database to: #{dumpfile}"
      system(args)

      if ! File.exist?(dumpfile) || File.size(dumpfile) < 400
        puts "Error! It seems the mysqldump command failed!"
      else
        puts "Dump seems to have been successful"
      end

    end   # task db:mysql:dump
  end     # namespace db:mysql
end       # namespace db

