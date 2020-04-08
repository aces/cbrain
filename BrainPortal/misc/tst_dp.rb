
#
# A quick method to test DataProvider behaviors.
# Provided with no guarantees.
#
# Mostly useful in the console.
#

def tst_dpv(dp_id, options={})
  tst_dp(dp_id, options.merge(:showlog => true))
end

def tst_dp(dp_id, options={})

   if options[:showlog]
     Aws.config.update(:logger => Logger.new($stdout))
   else
     Aws.config.update(:logger => nil)
   end

   dp   = DataProvider.find(dp_id)
   user = options[:user] || User.admin


   compare_lists = lambda { |title, gotlist, explist|
     if gotlist.sort != explist.sort
       puts "Difference in lists: #{title}"
       puts "Got: #{gotlist.sort.inspect}"
       puts "Exp: #{explist.sort.inspect}"
     end
   }

   ################################################
   puts "====== DP and User ======"
   puts "DP   : #{dp.to_summary}"
   puts "User : #{user.to_summary}"
   ################################################

   ################################################
   puts "====== Creating Test Files ======"
   ################################################

   system <<BASH.gsub("\n"," ; ")
rm -rf /tmp/fileco /tmp/ls-la.txt
mkdir -p /tmp/fileco/a /tmp/fileco/b /tmp/fileco/b/empty
echo hello >/tmp/fileco/hello.txt
echo world >/tmp/fileco/a/world.txt
echo foo   >/tmp/fileco/b/foo.txt
ln -s hello.txt /tmp/fileco/hello_symlink.txt
ls -la     >/tmp/ls-la.txt
BASH

   ################################################
   puts "====== DB Cleanup ======"
   ################################################

   Userfile.where(:data_provider_id => dp_id, :name => [ 'fileco1', 'regul1' ] )
     .each do |x|
        x.destroy rescue nil
        x.delete  rescue nil
     end

   ################################################
   puts "====== Upload FileCollection ======"
   ################################################
   fileco1 = FileCollection.new( :name             => 'fileco1',
                                 :data_provider_id => dp_id,
                                 :user_id          => user.id,
                                 :group_id         => user.own_group.id,
                               )
   fileco1.save!
   fileco1.cache_prepare
   fileco1.cache_copy_from_local_file("/tmp/fileco")

   ################################################
   puts "====== Upload TextFile ======"
   ################################################
   regul1 = TextFile.new( :name             => 'regul1',
                          :data_provider_id => dp_id,
                          :user_id          => user.id,
                          :group_id         => user.own_group.id,
                        )
   regul1.save!
   regul1.cache_prepare
   regul1.cache_copy_from_local_file("/tmp/ls-la.txt")

   ################################################
   puts "====== Erase Cache ======"
   ################################################
   fileco1.cache_erase
   regul1.cache_erase

   ################################################
   puts "====== Sync To Cache ======"
   ################################################
   fileco1.sync_to_cache
   regul1.sync_to_cache

   ################################################
   puts "====== Diff FileCo Original Vs Cache ======"
   ################################################
   c1=fileco1.cache_full_path
   system "diff -r /tmp/fileco #{c1}"

   ################################################
   puts "====== Diff TextFile Original Vs Cache ======"
   ################################################
   r1=regul1.cache_full_path
   system "diff -r /tmp/ls-la.txt #{r1}"

   ################################################
   puts "====== Browse ======"
   ################################################
   if ! dp.is_browsable?(user)
     puts "Skipped: DP is not browsable by #{user.login}"
   else
     entries = dp.provider_list_all(user)
     totentries=entries.size
     puts "Found: #{totentries} entries"
     expect = entries
       .select do |e|
         (e.name == 'fileco1' && e.symbolic_type == :directory) ||
         (e.name == 'regul1' && e.symbolic_type == :regular)
       end

     if expect.size != 2
       raise "Cannot find our two entries when browsing? Found #{expect.size}"
     else
       puts "Found:\n#{expect.map(&:inspect).join("\n")}"
     end
   end

   ################################################
   puts "===== Col Index All ====="
   ################################################
   if ! dp.is_browsable?(user)
     puts "Skipped: DP is not browsable by #{user.login}"
   else
     fileco1.cache_erase
     regul1.cache_erase
     f_entries = fileco1.provider_collection_index(:all, :regular)
     d_entries = fileco1.provider_collection_index(:all, :directory)
     f_expect = [ "fileco1/hello.txt", "fileco1/a/world.txt", "fileco1/b/foo.txt" ]
     f_entries_n = f_entries.map(&:name)
     d_expect = [ "fileco1/a", "fileco1/b", "fileco1/b/empty" ]
     d_entries_n = d_entries.map(&:name)
     compare_lists.('files',       f_entries_n, f_expect)
     compare_lists.('directories', d_entries_n, d_expect)

     ################################################
     puts "===== Col Index Level B ====="
     ################################################
     f_entries = fileco1.provider_collection_index("b", :regular)
     d_entries = fileco1.provider_collection_index("b", :directory)
     f_expect = [ "fileco1/b/foo.txt" ]
     f_entries_n = f_entries.map(&:name)
     d_expect = [ "fileco1/b/empty"   ]
     d_entries_n = d_entries.map(&:name)
     compare_lists.('files',       f_entries_n, f_expect)
     compare_lists.('directories', d_entries_n, d_expect)
   end

   ################################################
   puts "====== Type Change Tests (upload) ======"
   ################################################
   fileco1.sync_to_cache
   fileco1.cache_is_newer
   system <<BASH.gsub("\n"," ; ")
cd \"#{c1}\"
rm -rf a/world.txt b hello_symlink.txt
mkdir    a/world.txt
touch    a/world.txt/planet
echo x > a/world.txt/express
echo super > b
echo nope  > hello_symlink.txt
mkdir -p /tmp/mutated_fileco
rsync -a -H --delete ./ /tmp/mutated_fileco
BASH
   fileco1.sync_to_provider
   fileco1.cache_erase
   fileco1.sync_to_cache
   system "diff -r /tmp/mutated_fileco #{c1}"

   if ! dp.is_browsable?(user)
     puts "Skipped: DP is not browsable by #{user.login}"
   else
     f_entries = fileco1.provider_collection_index(:all, :regular)
     d_entries = fileco1.provider_collection_index(:all, :directory)
     f_expect = [ "fileco1/hello.txt", "fileco1/a/world.txt/planet", "fileco1/a/world.txt/express", "fileco1/b", "fileco1/hello_symlink.txt" ]
     f_entries_n = f_entries.map(&:name)
     d_expect = [ "fileco1/a", "fileco1/a/world.txt" ]
     d_entries_n = d_entries.map(&:name)
     compare_lists.('files',       f_entries_n, f_expect)
     compare_lists.('directories', d_entries_n, d_expect)
   end

   ################################################
   puts "====== Type Change Tests (download) ======"
   ################################################
   fileco1.provider_is_newer
   system <<BASH.gsub("\n"," ; ")
rsync -a -H --delete /tmp/fileco/ "#{c1}"
BASH
   fileco1.sync_to_cache
   system "diff -r /tmp/mutated_fileco #{c1}"

   if ! dp.is_browsable?(user)
     puts "Skipped: DP is not browsable by #{user.login}"
   else
     f_entries = fileco1.provider_collection_index(:all, :regular)
     d_entries = fileco1.provider_collection_index(:all, :directory)
     f_expect = [ "fileco1/hello.txt", "fileco1/a/world.txt/planet", "fileco1/a/world.txt/express", "fileco1/b", "fileco1/hello_symlink.txt" ]
     f_entries_n = f_entries.map(&:name)
     d_expect = [ "fileco1/a", "fileco1/a/world.txt" ]
     d_entries_n = d_entries.map(&:name)
     compare_lists.('files',       f_entries_n, f_expect)
     compare_lists.('directories', d_entries_n, d_expect)
   end


   ################################################
   if options[:skip_destroy]
     puts "Skipping destroy tests."
   ################################################
     puts "For inspection:"
     puts " * orig   data is in /tmp/fileco and /tmp/ls-la.txt"
     puts " * copy of mutated fileco is in /tmp/mutated_fileco"
     puts " * cached data is in #{fileco1.cache_full_path} and #{regul1.cache_full_path}"
     return
   end

   ################################################
   puts "====== Destroy ======"
   ################################################
   fileco1.destroy
   regul1.destroy

   ################################################
   puts "====== Check Destroy With Browse ======"
   ################################################
   if ! dp.is_browsable?(user)
     puts "Skipped: DP is not browsable"
   else
     entries = dp.provider_list_all(user)
       .select do |e|
         (e.name == 'fileco1' && e.symbolic_type == :directory) ||
         (e.name == 'regul1' && e.symbolic_type == :regular)
       end
     if entries.size > 0
       raise "Error: entries still exist on remote DP"
     end
   end

end

