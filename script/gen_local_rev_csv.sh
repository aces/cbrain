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

# This script examines all files in the CBRAIN project (or one of
# its plugin package) and creates a CSV file with the date, author and
# latest commit IDs for each one. When CBRAIN is deployed without GIT
# (using a tarball, for instance) this CSV file is used to provide
# run-time revision information about each code file.

# Normally, this script is not invoked manually, but rather the script
# make_all_rev_csv.sh is used instead, which calls it.

STATIC_REV_FILE="cbrain_file_revisions.csv"
CSV_SEP=" -#- " # careful, this is what is expected of cbrain_file_revision.rb !

# Make sure we have GIT.
GIT_EXEC=`which git 2>/dev/null`
if test -z "$GIT_EXEC" ; then
  echo "You need access to GIT to run this script!"
  exit 10
fi

# Find the top-level of the current GIT repo;
# this can be the CBRAIN project itself, or one of
# its plugin packages.
GIT_TOP=`$GIT_EXEC rev-parse --show-toplevel 2>/dev/null`
if test -z "$GIT_TOP" ; then
  echo "This script is supposed to be run from a project under GIT control."
  exit 10
fi
cd $GIT_TOP || exit 20

# Make sure the cwd is OK.
TOP_BASENAME=`basename $GIT_TOP`
LOCATION_TYPE="" # will be 'CBRAIN' or 'cbrain-plugins-xyz'
LOCATION_DESC="" # pretty description of where we are running
if test -n "`echo $TOP_BASENAME | grep ^cbrain-plugins-`" ; then
  LOCATION_TYPE="$TOP_BASENAME"
  LOCATION_DESC="Package $TOP_BASENAME"
elif test -d BrainPortal -a -d Bourreau ; then
  LOCATION_TYPE="CBRAIN"
  LOCATION_DESC="CBRAIN project top level"
else
  echo "You must run this script from the ROOT of the CBRAIN project, or within one of its plugin packages."
  exit 10
fi

echo "Generating the static list of revisions for '$LOCATION_DESC'..."
cp /dev/null "$STATIC_REV_FILE"

# These two values are only needed for the man CBRAIN project
CURRENT_DATE="`date \"+%F %T %z\"`"  # must be same ISO format as %ai of git log command below
if test "$LOCATION_TYPE" = "CBRAIN" ; then
  RELEASE_TAG_NUM="`BrainPortal/script/show_cbrain_rev`"
elif test -e ../../script/show_cbrain_rev ; then  # this is in "BrainPortal/script"
  RELEASE_TAG_NUM="`../../script/show_cbrain_rev -z`"  # -z makes default to "0.1.0-nnn"
else
  echo "Warning: cannot run 'show_cbrain_rev' to find release tag. Defaulting to 0.1.0." 1>&2
  RELEASE_TAG_NUM="0.1.0" # unknown?
fi

# This block's output is sent to the CSV file
{
  # These two statements generate the first two entries:
  # 1) an artificial __CBRAIN_TAG__ for the whole project, in format e.g. "4.4.0-123"
  echo "${RELEASE_TAG_NUM}${CSV_SEP}${CURRENT_DATE}${CSV_SEP}CBRAIN Team${CSV_SEP}__${LOCATION_TYPE}_TAG__"
  # 2) an artificial __CBRAIN_HEAD__ for the whole project.
  git log -n1 --format="%H${CSV_SEP}%ai${CSV_SEP}%an${CSV_SEP}__${LOCATION_TYPE}_HEAD__" -- .

  # This loop generates one entry per file in the project.
  for file in `$GIT_EXEC ls-files | sort` ; do
    $GIT_EXEC log -n1 --format="%H${CSV_SEP}%ai${CSV_SEP}%an${CSV_SEP}$file" -- "$file" | cat
  done

} > "$STATIC_REV_FILE"

echo "File list done: `pwd`/$STATIC_REV_FILE"

