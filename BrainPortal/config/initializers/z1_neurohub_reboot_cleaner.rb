
if CBRAIN.is_app_NEUROHUB?

  if File.exists? "public/reboot.txt"
    system "mv -f public/reboot.txt public/previous_reboot.txt"
  end

end

