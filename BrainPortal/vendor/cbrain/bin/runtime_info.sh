#!/bin/bash

# This script dumps simple KEY=VAL lines,
# trying to capture as much information
# as possible about the current run environment
# (excluding things such as UID, GID, PWD, etc).
#
# We want to record any and all information that
# helps reproducibility (CPU time, RAM, limits, etc).
#
# When extending this script, make sure it works properly
# on both MacOS and Linux

# Given lines such as
#   Some name : some value
#   Some name = some value
# will change the key part to
#   Some_name = some value
function underscore_keys() {
  perl -pe 's/^\s*(.*?\S)\s*[:=]/ $x=$1; $x =~ s#\s+#_#g; "$x="/e'
}

# Header
basename=$(basename $0)
version=$(git log -n1 --format="%h %ai %an" $0 2>/dev/null)
echo ""
echo "#"
echo "# Captured run-time information generated automatically"
echo "# by $basename $version"
echo "#"
echo ""

# Internal version tracking
echo "runtime_info_version = $version"

# Basic UNIX stuff
echo "hostname =" $(hostname)
echo ""

# LINUX: os-release (all systemd systems have that)
if test -f /etc/os-release ; then
  cat /etc/os-release | underscore_keys
fi

# LINUX: cpuinfo
if test -e /proc/cpuinfo ; then
  cat /proc/cpuinfo | sort | uniq | \
  egrep '^(vendor_id|flags|cache size|cpu cores|model name|microcode)' | \
  underscore_keys
fi

# MacOS
sw_vers 2>/dev/null | underscore_keys

# MacOS
system_profiler SPSoftwareDataType SPHardwareDataType 2>/dev/null | underscore_keys

