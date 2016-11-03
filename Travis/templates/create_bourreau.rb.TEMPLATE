# Create a UNIX Bourreau based on the configuration used in docker-compose.yml

b=Bourreau.new({:name                  => "Bourreau",
                :user_id               => 1,
                :group_id              => 1,
                :ssh_control_user      => "cbrain",
                :ssh_control_host      => "cbrain-bourreau",
                :ssh_control_port      => 22,
                :ssh_control_rails_dir => "/home/cbrain/cbrain/Bourreau",
                :tunnel_mysql_port     => 1234,
                :tunnel_actres_port    => 1235,
                :dp_cache_dir          => "/home/cbrain/cbrain_data_cache",
                :cms_class             => "ScirUnix",
                :cms_shared_dir        => "/home/cbrain/cbrain_task_directories",
                :workers_instances     => 1,
                :workers_chk_time      => 5,
                :workers_log_to        => "combined",
                :workers_verbose       => 1
               })
b.save!
