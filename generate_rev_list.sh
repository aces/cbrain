#!/bin/bash

GIT_EXEC=`which git 2>/dev/null`
if test -z "$GIT_EXEC" ; then
  echo "You need access to GIT to run this script!"
  exit 10
fi

cd `$GIT_EXEC rev-parse --show-toplevel` || exit 10

if ! test -d BrainPortal -a -d Bourreau ; then
  echo "You must run this script from the ROOT of the CBRAIN project."
  exit 10
fi

echo "Generating the static list of revisions for all CBRAIN files..."
{
for n in `$GIT_EXEC ls-files` ; do $GIT_EXEC log -n1 --format="%H -#- %ai -#- %an -#- $n" -- "$n" | cat ; done
} | tee "cbrain_file_revisions.csv"
echo "Done."

