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

# This script examines all files in the CBRAIN project and creates
# a CSV file with the date, author and latest commit IDs for each one.
# This CSV file is used instead of GIT commands when CBRAIN is deployed
# without GIT (using a tarball, for instance).

STATIC_REV_FILE="cbrain_file_revisions.csv"
CSV_SEP=" -#- " # careful, this is what is expected of cbrain_file_revision.rb !

# Make sure we have GIT.
GIT_EXEC=`which git 2>/dev/null`
if test -z "$GIT_EXEC" ; then
  echo "You need access to GIT to run this script!"
  exit 10
fi

# Make sure the cwd is OK.
if ! test -d BrainPortal -a -d Bourreau ; then
  echo "You must run this script from the ROOT of the CBRAIN project."
  exit 10
fi

# Make sure we are deployed with GIT.
cd `$GIT_EXEC rev-parse --show-toplevel` || exit 10

echo "Generating the static list of revisions for all CBRAIN files..."
cp /dev/null "$STATIC_REV_FILE"
CBRAIN_REV_NUM="`BrainPortal/script/show_cbrain_rev`"
CURRENT_DATE="`date \"+%F %T %z\"`"  # must be same ISO format as %ai of git log command below

# This block's output is sent to the CSV file
{
  # These two statements generates the first entry, an artifical __CBRAIN_TAG__ for the whole project.
  echo "${CBRAIN_REV_NUM}${CSV_SEP}${CURRENT_DATE}${CSV_SEP}CBRAIN Team${CSV_SEP}__CBRAIN_TAG__"
  git log -n1 --format="%H${CSV_SEP}%ai${CSV_SEP}%an${CSV_SEP}__CBRAIN_HEAD__" -- .

  # This loop generates one entry per file in the project.
  for file in `$GIT_EXEC ls-files | sort` ; do
    $GIT_EXEC log -n1 --format="%H${CSV_SEP}%ai${CSV_SEP}%an${CSV_SEP}$file" -- "$file" | cat
  done

} | tee -a "$STATIC_REV_FILE"

echo "All done."

