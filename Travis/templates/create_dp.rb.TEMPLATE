# Creates a local DataProvider

d=DataProvider.new({:name => "MyStorage",
                    :type => "SshDataProvider",
                    :user_id => 1,
                    :group_id => 1,
                    :remote_user => "cbrain",
                    :remote_host => "data-provider",
                    :remote_port => 22,
                    :remote_dir => "/home/cbrain/data",
                    :description => "ssh data provider",
                    :online => true})
d.type = "SshDataProvider"
d.save!
