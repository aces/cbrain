namespace :setup do 
  namespace :install do
    desc "Install sys-proctable gem for your platform"
    task :proctable do 
      platform = `uname`  
      if  platform == "Linux\n"
        `gem install vendor/cbrain/gems/sys-proctable-0.9.0-x86-linux.gem`
      elsif platform == "Darwin\n"
        `gem install vendor/cbrain/gems/sys-proctable-0.9.0-x86-darwin-8.gem`
      elsif platform == "SunOS\n"
        `gem install vendor/cbrain/gems/sys-proctable-0.9.0-x86-solaris-2.10.gem`
      elsif platform == "FreeBSD\n"
        `gem install vendor/cbrain/gems/sys-proctable-0.9.0-x86-feebsd-7.gem`
      else 
        puts "C> Your platform is not supported by sys-proctable or cbrain"
      end
    end
  end
end
