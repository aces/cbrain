namespace :setup do 
  namespace :install do
    desc "Install sys-proctable gem for your platform"
    task :proctable do 
      platform = `uname`  
      if  platform == "Linux\n"
        system("gem install vendor/cbrain/gems/sys-proctable-0.9.0-x86-linux.gem")
      elsif platform == "Darwin\n"
        system("gem install vendor/cbrain/gems/sys-proctable-0.9.0-x86-darwin-8.gem")
      elsif platform == "SunOS\n"
        system("gem install vendor/cbrain/gems/sys-proctable-0.9.0-x86-solaris-2.10.gem")
      elsif platform == "FreeBSD\n"
        system("gem install vendor/cbrain/gems/sys-proctable-0.9.0-x86-feebsd-7.gem")
      else 
        puts "Your platform '#{platform}' is not supported by sys-proctable or by CBRAIN."
        raise "Cannot continue. Try to install sys-proctable using the gem commands and the files in the vendor directory, maybe?"
      end
      puts "CBRAIN-provided gem sys-proctable installed."
    end
  end
end
