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
  perl -pe 's/^\s*(.*?\S)\s*[:=]/ $x=$1; $x =~ s#\s+#_#g; $x =~ s#[^\w\.\-]+##g; "$x="/e; $_="" if /=\s*$|^\s*$/'
}

# Header info
basename=$(basename $0)

# This tool's version
# For git log and git describe to work, we need to temporarily cd
pushd $(dirname $0) >/dev/null
version=$(git log -n1 --format="%h by %an at %ai" "$basename" 2>/dev/null)
cb_version=$(git describe 2>/dev/null)
popd >/dev/null

# Pretty header
echo ""
echo "#"
echo "# Captured run-time information generated automatically"
echo "# by $basename rev ${version:-unknown}"
echo "#"
echo ""

# Internal version tracking
echo "cbrain_version = ${cb_version:-unknown}"
echo "cbrain_runtime_info_version = ${version:-unknown}"
echo "cbrain_capture_date = $(date '+%Y-%m-%dT%H:%M:%S%z')"

# Basic UNIX stuff
echo "hostname =" $(hostname)
if test -n "$(type -p singularity)" ; then
  echo ""
  echo "singularity_version =" $(singularity version 2>/dev/null | head -1)
fi

if test -n "$(type -p docker)" ; then
  echo ""
  echo "docker_version =" $(docker -v 2>/dev/null | head -1)
fi

# LINUX: os-release (all systemd systems have that)
if test -f /etc/os-release ; then
  echo ""
  echo "# From /etc/os-release"
  cat /etc/os-release            | \
    grep -v _URL                 | \
    grep -v ANSI_COLOR           | \
    underscore_keys              | \
    sed -e  's/^ */os_release_/'
fi

# LINUX: cpuinfo
if test -e /proc/cpuinfo ; then
  echo ""
  echo "# From /proc/cpuinfo"
  cat /proc/cpuinfo              | \
  sort                           | \
  uniq                           | \
  egrep '^(vendor_id|flags|cache size|cpu cores|model name|microcode)' | \
  sed -e  's/^ */proc_cpuinfo_/' | \
  underscore_keys
fi

# LINUX: numactl
if test -n "$(type -p numactl)" ; then
  echo ""
  echo "# From numactl"
  numactl -s                | \
  sort                      | \
  uniq                      | \
  sed -e  's/^ */numactl_/' | \
  underscore_keys
fi

# MacOS stuff
if test -n "$(type -p sw_vers)" ; then
  echo ""
  echo "# From sw_vers"
  sw_vers 2>/dev/null | underscore_keys
fi

if test -n "$(type -p system_profiler)" ; then
  echo ""
  echo "# From system_profiler"
  system_profiler SPSoftwareDataType SPHardwareDataType 2>/dev/null | underscore_keys
fi

