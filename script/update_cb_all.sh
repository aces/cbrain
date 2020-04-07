#!/bin/bash

VERSION=1.0

#============================================================================
# USAGE
#============================================================================

function usage {
  cat <<USAGE

This is CBRAIN's $0 version $VERSION by Pierre Rioux

Usage: $0 [-v] [-[1234567]] path_to_portal_or_bourreau

This script will attempt to update all the GIT repository for a CBRAIN
installation, including those in the plugins. It has to be invoked
with a single argument, the path to either the BrainPortal or the Bourreau
directory of the CBRAIN distribution. For a portal installation,
the script will also run several other rake tasks.

It is assumed that proper SSH keys are available (usually through a ssh
agent) when pulling GIT repos with the SSH protocol.

If anything goes wrong, the script will stop and the user will be required
to investigate and fix the problem manually.

The script can be re-launched as often as necessary.

These are the steps that are performed:

A) for both Bourreau and BrainPortal:

  - git pull of the main CBRAIN repo
  - git pull of each installed plugins
  - bundle install
  - rake cbrain:plugins:clean:all
  - rake cbrain:plugins:install:all

B) for BrainPortal only:

  - rake db:migrate
  - rake db:sanity:check
  - rake assets:precompile
  - chmod -R a+rX BrainPortal/public

Note: you might have to set your RAILS_ENV environment variable
for the rake tasks to work properly.
USAGE
  exit 20
}

#============================================================================
# VERIFY ARGUMENTS
#============================================================================

# With "-v" in first argument, will dump the output of each command run.
verbose=""
test $# -gt 0 && test "X$1" == "X-v" && shift && verbose="1"

# With a -number in argument, will skip to that step
skipto="1"
if test $# -gt 0 ; then
  if test "X$1" = "X-1" -o "X$1" = "X-2" -o "X$1" = "X-3" -o \
          "X$1" = "X-4" -o "X$1" = "X-5" -o "X$1" = "X-6" -o \
          "X$1" = "X-7" ; then # I'm too lazy to check with regex
    skipto=$( echo "$1" | tr -d - )
    shift
  fi
fi

# Verify we have a path to a CBRAIN install
if test $# -ne 1 ; then
  usage
fi

cd "$1" || usage
base=$(basename $(pwd -P))

if test "X$base" != "XBrainPortal" -a "X$base" != "XBourreau" ; then
  echo "Error: first argument must be the path to BrainPortal or Bourreau directory to update."
  exit 20
fi

# Colors for messages
printf_yellow="\033[33;1m"
printf_red="\033[31;1m"
printf_magenta="\033[35;1m"
printf_none="\033[0m"
if ! test -t 1 ; then
  printf_yellow=""
  printf_red=""
  printf_magenta=""
  printf_none=""
fi

#============================================================================
# UTILITY FUNCTIONS
#============================================================================

function Step {
  echo ""
  # echo -e "\e[33;1mStep $@\e[0m"
  printf "${printf_yellow}%s${printf_none}\n" "Step $*"
}

function runcapture {
  eval "$@" >/tmp/capt.cb_up.$$ 2>&1
  if test $? -gt 0 ; then
    echo ""
    #echo -e "\e[31;1mError running command: \e[35;1m$@\e[33;1m"
    printf "${printf_red}Error running command: ${printf_magenta}%s${printf_red}\n" "$*"
    echo ""
    cat /tmp/capt.cb_up.$$
    #echo -e "\e[0m"
    printf "${printf_none}\n"
    rm -f /tmp/capt.cb_up.$$
    exit $?
  fi
  test -n "$verbose" && cat /tmp/capt.cb_up.$$
  rm -f /tmp/capt.cb_up.$$
}


#============================================================================
# ACTUAL UPDATE STEPS
#============================================================================

if test -z "$skipto" -o "$skipto" -le "1" ; then

Step 1: GIT Update CBRAIN Base
runcapture "git pull"
runcapture "git fetch --tags"

fi


#============================================================================
if test -z "$skipto" -o "$skipto" -le "2" ; then

Step 2: GIT Update CBRAIN Plugins
pushd cbrain_plugins >/dev/null || exit
for plugin in * ; do
  test ! -d "$plugin"                       && continue
  test "X$plugin" == "Xinstalled-plugins"   && continue
  test "X$plugin" == "Xcbrain-plugins-base" && continue
  echo " => $plugin"
  pushd "$plugin" >/dev/null || exit 20
  runcapture "git pull"
  runcapture "git fetch --tags"
  popd >/dev/null || exit 20
done
popd >/dev/null || exit 20

fi

#============================================================================
if test -z "$skipto" -o "$skipto" -le "3" ; then

Step 3: Bundle Install
runcapture "bundle install"

fi

#============================================================================
if test -z "$skipto" -o "$skipto" -le "4" ; then

Step 4: Re-install All Plugins
test "$base" == "BrainPortal" && runcapture "rake cbrain:plugins:clean:all"
test "$base" == "Bourreau"    && runcapture "rake cbrain:plugins:clean:plugins"
test "$base" == "BrainPortal" && runcapture "rake cbrain:plugins:install:all"
test "$base" == "Bourreau"    && runcapture "rake cbrain:plugins:install:plugins"

fi

#============================================================================
if test -z "$skipto" -o "$skipto" -le "5" ; then

if test "$base" == "BrainPortal" ; then
  Step 5: Database Migrations
  runcapture "rake db:migrate"
fi

fi


#============================================================================
if test -z "$skipto" -o "$skipto" -le "6" ; then

if test "$base" == "BrainPortal" ; then
  Step 6: Database Sanity Checks
  runcapture "rake db:sanity:check"
fi

fi

#============================================================================
if test -z "$skipto" -o "$skipto" -le "7" ; then

if test "$base" == "BrainPortal" ; then
  Step 7: Asset Compilations
  runcapture "rake assets:precompile"
  runcapture "chmod -R a+rX public"
fi

fi

#============================================================================
Step All done. Yippeee.
exit 0

