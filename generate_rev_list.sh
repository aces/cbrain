#!/bin/bash

GIT_EXEC=`which git 2>/dev/null`
if test -z "$GIT_EXEC" ; then
  echo "You need access to GIT to run this script!"
  exit 10
fi

STATIC_REV_FILE="cbrain_file_revisions.csv"
CSV_SEP=" -#- " # careful, this is what is expected of cbrain_file_revision.rb !

cd `$GIT_EXEC rev-parse --show-toplevel` || exit 10

if ! test -d BrainPortal -a -d Bourreau ; then
  echo "You must run this script from the ROOT of the CBRAIN project."
  exit 10
fi

echo "Generating the static list of revisions for all CBRAIN files..."
cp /dev/null "$STATIC_REV_FILE"
CBRAIN_REV_NUM="`BrainPortal/script/show_cbrain_rev`"
CURRENT_DATE="`date \"+%F %T %z\"`"  # must be same ISO format as %ai of git log command below
{
echo "${CBRAIN_REV_NUM}${CSV_SEP}${CURRENT_DATE}${CSV_SEP}CBRAIN Team${CSV_SEP}__CBRAIN_TAG__"
git log -n1 --format="%H${CSV_SEP}%ai${CSV_SEP}%an${CSV_SEP}__CBRAIN_HEAD__" -- .
for n in `$GIT_EXEC ls-files` ; do $GIT_EXEC log -n1 --format="%H${CSV_SEP}%ai${CSV_SEP}%an${CSV_SEP}$n" -- "$n" | cat ; done
} | tee -a "$STATIC_REV_FILE"
echo "Done."

