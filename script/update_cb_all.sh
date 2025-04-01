#!/bin/bash

VERSION=1.0

#============================================================================
# USAGE
#============================================================================

function usage {
  cat <<USAGE

This is CBRAIN's $0 version $VERSION by Pierre Rioux

Usage: $0 [-v] [[-|+][1234567]] path_to_portal_or_bourreau

This script will attempt to update all the GIT repositories for a CBRAIN
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

  1 - git pull of the main CBRAIN repo
  2 - git pull of each installed plugins
  3 - bundle install
  4 - rake cbrain:plugins:install:all

B) for BrainPortal only:

  5 - rake db:migrate
  6 - rake db:sanity:check
  7 - rake assets:precompile
    - chmod -R a+rX BrainPortal/public

Note: you might have to set your RAILS_ENV environment variable
for the rake tasks to work properly.

With option -v, the outputs of the commands run will be shown.

With option -N, where N is a number between 1 and 7, the script
will run be starting from step N.

With option +N, where N is a number between 1 and 7, the script
will run ONLY the step N.
USAGE
  exit 20
}

#============================================================================
# VERIFY ARGUMENTS
#============================================================================

# With "-v" in first argument, will dump the output of each command run.
verbose=""
test $# -gt 0 && test "X$1" == "X-v" && shift && verbose="1"

# Which steps to execute
skipto="1"   # first step to execute
stopat="99"  # last step to execute

# With a -number in argument, will skip to that step
if test $# -gt 0 ; then
  if test "X$1" = "X-1" -o "X$1" = "X-2" -o "X$1" = "X-3" -o \
          "X$1" = "X-4" -o "X$1" = "X-5" -o "X$1" = "X-6" -o \
          "X$1" = "X-7" ; then # I'm too lazy to check with regex
    skipto=$( echo "$1" | tr -d - )
    shift
  fi
fi

# With a +number in argument, execute ONLY that step
if test $# -gt 0 ; then
  if test "X$1" = "X+1" -o "X$1" = "X+2" -o "X$1" = "X+3" -o \
          "X$1" = "X+4" -o "X$1" = "X+5" -o "X$1" = "X+6" -o \
          "X$1" = "X+7" ; then # I'm too lazy to check with regex
    skipto=$( echo "$1" | tr -d + )
    stopat=$skipto
    shift
  fi
fi

# Verify we have a path to a CBRAIN install
if test $# -ne 1 ; then
  usage
fi

cd "$1" || usage
base=$(basename "$(pwd -P)")

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
  evalstatus=$?
  if test $evalstatus -gt 0 ; then
    echo ""
    #echo -e "\e[31;1mError running command: \e[35;1m$@\e[33;1m"
    printf "${printf_red}Error running command: ${printf_magenta}%s${printf_red}\n" "$*"
    echo ""
    cat /tmp/capt.cb_up.$$
    #echo -e "\e[0m"
    printf "${printf_none}\n"
    rm -f /tmp/capt.cb_up.$$
    exit $evalstatus
  fi
  test -n "$verbose" && cat /tmp/capt.cb_up.$$
  rm -f /tmp/capt.cb_up.$$
}


#============================================================================
# ACTUAL UPDATE STEPS
#============================================================================

step=1
if test $step -ge $skipto -a $step -le $stopat ; then

Step $step: GIT Update CBRAIN Base
runcapture "git pull --verbose"
runcapture "git fetch --tags"

fi


#============================================================================
step=2
if test $step -ge $skipto -a $step -le $stopat ; then

Step $step: GIT Update CBRAIN Plugins
pushd cbrain_plugins >/dev/null || exit
for plugin in * ; do
  test ! -d "$plugin"                       && continue
  test "X$plugin" == "Xinstalled-plugins"   && continue
  test "X$plugin" == "Xcbrain-plugins-base" && continue
  test ! -d "$plugin/.git"                  && continue
  echo " => $plugin"
  pushd "$plugin" >/dev/null || exit 20
  runcapture "git pull --verbose"
  runcapture "git fetch --tags"
  popd >/dev/null || exit 20
done
popd >/dev/null || exit 20

fi

#============================================================================
step=3
if test $step -ge $skipto -a $step -le $stopat ; then

Step $step: Bundle Install
runcapture "bundle install"

fi

#============================================================================
step=4
if test $step -ge $skipto -a $step -le $stopat ; then

Step $step: Update All Plugins Symlinks
test "$base" == "BrainPortal" && runcapture "rake cbrain:plugins:install:all"
test "$base" == "Bourreau"    && runcapture "rake cbrain:plugins:install:plugins"

fi

#============================================================================
step=5
if test $step -ge $skipto -a $step -le $stopat ; then

if test "$base" == "BrainPortal" ; then
  Step $step: Database Migrations
  runcapture "rake db:migrate"
fi

fi


#============================================================================
step=6
if test $step -ge $skipto -a $step -le $stopat ; then

if test "$base" == "BrainPortal" ; then
  Step $step: Database Sanity Checks
  runcapture "rake db:sanity:check"
fi

fi

#============================================================================
step=7
if test $step -ge $skipto -a $step -le $stopat ; then

if test "$base" == "BrainPortal" ; then
  Step $step: Asset Compilations
  runcapture "rake assets:precompile"
  runcapture "chmod -R a+rX public"
fi

fi

#============================================================================
Step All done. Yippeee.
exit 0

