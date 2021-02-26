#!/bin/bash

#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# This script runs the other script 'gen_local_rev_csv.sh' in the
# CBRAIN root directory, and once in each of the plugins packages
# found. It's a utility to allow easy refreshing of all the flat
# files of static revision numbers.

# Make sure we have GIT.
GIT_EXEC=`which git 2>/dev/null`
if test -z "$GIT_EXEC" ; then
  echo "You need access to GIT to run this script!"
  exit 10
fi

# Find the top-level of the current GIT repo;
# this should be the CBRAIN project itself.
GIT_TOP=`$GIT_EXEC rev-parse --show-toplevel 2>/dev/null`
if test -z "$GIT_TOP" ; then
  echo "This script is supposed to be run from a CBRAIN project under GIT control."
  exit 10
fi
cd "$GIT_TOP" || exit 20

# Make sure the cwd is OK.
if ! test -d BrainPortal -a -d Bourreau ; then
  echo "You must run this script from the ROOT of the CBRAIN project."
  exit 10
fi

# Generate main list for the CBRAIN platform
bash "$GIT_TOP/script/gen_local_rev_csv.sh" || exit 10

# Generate the lists for each plugin packages
if ! test -d "BrainPortal/cbrain_plugins" ; then
  echo "No 'BrainPortal/cbrain_plugins' directory found, stopping there."
  exit 10
fi

cd "BrainPortal/cbrain_plugins" || exit 20
for plugindir in `ls -1 | grep -v '^cbrain-plugins-base$'` ; do
  test -d "$plugindir"      || continue
  test -d "$plugindir/.git" || continue
  if ! test -e "$plugindir/cbrain_file_revisions.csv" ; then # adjust to match what gen_loc script create
    echo "Skipping plugin directory '$plugindir' : no cbrain_file_revisions.csv file already exist. Touch to force."
    continue
  fi
  cd $plugindir || exit 20
  local_root=`$GIT_EXEC rev-parse --show-toplevel 2>/dev/null`
  if test "$local_root" = `pwd` ; then
    bash "$GIT_TOP/script/gen_local_rev_csv.sh" || exit 10
  fi
  cd ..
done

echo "All done!"

