#!/bin/bash

# This script will produce a report about the state of the code
# in each plugin. The report can easily be compared with the
# report prepared in another install to indetified differences
# in the plugins.
#
# Note: doesn't work so well on MacOS because over there
# they dont' have "xargs -r" nor "md5sum".

# We can pass the path to the plugins dir in argument.
if test $# -eq 1 ; then
  cd "$1" || exit 2
fi

if ! test -d installed-plugins ; then
  echo "This program must be run from the cbrain_plugins directory"
  exit 2
fi

unset LANG # to make sorting deterministic in the reports

for dir in * ; do
  test $dir = 'cbrain-plugins-base' && continue
  #test $dir = 'installed-plugins'   && continue
  test -d $dir                      || continue

  cd $dir || exit 2
  echo ""
  echo "-------------------------------------------"
  echo ""

  (
    if ! test -d .git ; then

      # Case when a directory is not a GIT plugin

      echo "This plugin is not deployed with GIT; all files checksum provided"
      find . -type f -print0 | sort -z | xargs -r -0 md5sum
      find . -type l -print | sort | while read path ; do
        echo "Symlink: $path ->" $(readlink $path)
      done

    else

      # Case when a directory is a plugin controlled by GIT

      echo "==== Branches ===="
      git branch -v
      echo "==== Remotes ===="
      git remote -v
      echo "==== Status ===="
      git status -s
      echo "==== MD5 checksum of modified files ===="
      git status -s | cut -c4-99 | while read path ; do
        test -f "$path" || continue
        md5sum $path
      done

    fi
  ) | sed -e "s/^/$dir /"


  cd ..
done
