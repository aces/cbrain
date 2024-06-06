
# Rails Boot-Time Custom Bash Script Directory

This folder is provided empty (except for this README.md) in the
standard CBRAIN distribution. Admins and installers of the CBRAIN
system can create here bash scripts that will be invoked at the end
of the application's boot sequence. The following rules apply:

* Scripts must end with the ".sh" extension (although within them
  you are free too invoke programs in other languages)
* Scripts will be executed in alphabetical order.
* A script will be invoked with "bash","/full/path/to/scriptname.sh",
  so the script don't have to have their execute permissions set.
* Scripts must return a zero (0, success) return code. Whatever they
  print will be ignored, but found in the Rails boot log.
* Scripts that return a non-zero (1 or more) code will interrupt the
  boot sequence. Presumably, the admin can look at what is printed
  in the Rails boot log to figure out what happened.
* It is better to keep your scripts as silent as possible when
  everything is OK, so as not to pollute the boot logs. At boot
  time, the name of the script being executed will be logged already.
* Note that these scripts will also be executed during the Rails console
  boot sequence, and can therefore also prevent it from finishing. But
  this is also a way to test them, too.

## About The Boot Scripts Folders

There are two similar folders in a CBRAIN distribution: one for the
portal and one for the Bourreau, in

CBRAIN_ROOT/BrainPortal/boot_checks

and

CBRAIN_ROOT/Bourreau/boot_checks

## What can this be used for?

* Checking that certain critical filesystems are mounted
* Preparing run time configruation files that change dynamically
  (caveat, these scripts are executed at the END of the rest of
  the Rails boot sequence!)
* Checking anything, really

## What should not be executed here?

* Anything that takes a long time and slows down the boot process
* Anything that can blocks infinitely (which is also a 'long time')
* Rails Rake tasks
* Things that interfere with the DB socket
* Things that try to access the main HTTP socket of the Portal app
* Things that try to access the ActiveResource socket of the Bourreau App

## Author

Pierre Rioux <pierre.rioux@mcgill.ca>, June 2024
