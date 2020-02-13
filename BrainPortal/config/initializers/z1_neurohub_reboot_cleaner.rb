
if CBRAIN.is_app_NEUROHUB?

  # Record this for "neurohub#reboot" route (temporary dev)
  CBRAIN.const_set :NH_PUMA_PID, Process.pid

  if File.exists? "public/reboot.txt"
    system "mv -f public/reboot.txt public/previous_reboot.txt"
  end

end

