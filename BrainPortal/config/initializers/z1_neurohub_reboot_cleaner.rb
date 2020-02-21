
# Temporary cleanup step while we have a reboot system in development
# This file will not be part of the final neurohub codebase

if CBRAIN.is_app_NEUROHUB?

  # These are created in #reboot in NeurohubPortalController
  if File.exists? "public/reboot.txt"
    system "cp -f public/reboot.txt public/previous_reboot.txt"
    system "rm -f public/reboot_in_progress"
  end

end

