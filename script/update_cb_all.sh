#!/bin/bash

VERSION=1.0

# With "-v" in first argument, will dump the output of each command run.
verbose=""
test $# -gt 0 && test "X$1" == "X-v" && shift && verbose="1"

#============================================================================
# USAGE
#============================================================================

function usage {
  cat <<USAGE

This is CBRAIN's $0 version $VERSION by Pierre Rioux

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

if test $# -ne 1 ; then
  usage
fi

cd "$1" || usage
base=$(basename $(pwd -P))

if test "X$base" != "XBrainPortal" -a "X$base" != "XBourreau" ; then
  echo "Error: first argument must be the path to BrainPortal or Bourreau directory to update."
  exit 20
fi

#============================================================================
# UTILITY FUNCTIONS
#============================================================================

function Step {
  echo ""
  # echo -e "\e[33;1mStep $@\e[0m"
  printf "\033[33;1m%s\033[0m\n" "Step $*"
}

function runcapture {
  eval "$@" >/tmp/capt.cb_up.$$ 2>&1
  if test $? -gt 0 ; then
    echo ""
    #echo -e "\e[31;1mError running command: \e[35;1m$@\e[33;1m"
    printf "\033[31;1mError running command: \033[35;1m%s\033[33;1m\n" "$*"
    echo ""
    cat /tmp/capt.cb_up.$$
    #echo -e "\e[0m"
    printf "\033[0m\n"
    rm -f /tmp/capt.cb_up.$$
    exit $?
  fi
  test -n "$verbose" && cat /tmp/capt.cb_up.$$
  rm -f /tmp/capt.cb_up.$$
}


#============================================================================
# ACTUAL UPDATE STEPS
#============================================================================

Step 1: GIT Update CBRAIN Base
runcapture "git pull"
runcapture "git fetch --tags"


#============================================================================
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


#============================================================================
Step 3: Bundle Install
runcapture "bundle install"


#============================================================================
Step 4: Re-install All Plugins
test "$base" == "BrainPortal" && runcapture "rake cbrain:plugins:clean:all"
test "$base" == "Bourreau"    && runcapture "rake cbrain:plugins:clean:plugins"
test "$base" == "BrainPortal" && runcapture "rake cbrain:plugins:install:all"
test "$base" == "Bourreau"    && runcapture "rake cbrain:plugins:install:plugins"


#============================================================================
if test "$base" == "BrainPortal" ; then
  Step 5: Database Migrations
  runcapture "rake db:migrate"
fi


#============================================================================
if test "$base" == "BrainPortal" ; then
  Step 6: Database Sanity Checks
  runcapture "rake db:sanity:check"
fi

#============================================================================
if test "$base" == "BrainPortal" ; then
  Step 7: Asset Compilations
  runcapture "rake assets:precompile"
  runcapture "chmod -R a+rX public"
fi

#============================================================================
Step All done. Yippeee.
exit 0

