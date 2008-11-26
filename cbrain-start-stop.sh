#!/bin/sh

#
# CBRAIN start/stop script
#
# Original author: Pierre Rioux
#
# $Id$
#

PATH=/bin:/usr/bin:/sbin:/usr/sbin

#---------------------------------------------------------------------------
# The following lines provide the necessary info for adding a startup script
# according to the Linux Standard Base Specification (LSB) which can
# be found at:
#
#    http://www.linuxfoundation.org/spec/booksets/LSB-Core-generic/LSB-Core-generic/initscrcomconv.html
#
### BEGIN INIT INFO
# Provides:       cbrain
# Required-Start: $network $remote_fs
# Required-Stop:
# Default-Start:  3 5
# Default-Stop: 0 1 2 6
# Description:  starts cbrain rails server
### END INIT INFO
#---------------------------------------------------------------------------

# Check for local installation
if [ -d BrainPortal -a -d Bourreau ] ; then
    export CBRAIN_ROOT=`pwd`
else
    echo "Error: need to configure CBRAIN root's location!"
    exit 20
    CBRAIN_ROOT="/path/to/cbrain_root"
fi

# Check for Grid Engine's location
if [ "X$SGE_ROOT" = "X" ] ; then
    echo "Error: Grid Engine's \$SGE_ROOT environment variable is not set!"
    exit 20
    export SGE_ROOT="/path/to/sge"
fi

# Make sure the LD_LIBRARY_PATH include Grid Engine's.
# This section is an updated part of Sun's Grid Engine
# startup scripts.
ARCH="`$SGE_ROOT/util/arch`"
shlib_path_name="`$SGE_ROOT/util/arch -lib`"
old_value="`eval echo '$'$shlib_path_name`"
if [ "X$old_value" = "X" ]; then
    eval $shlib_path_name="$SGE_ROOT/lib/$ARCH"
else
    eval $shlib_path_name="$old_value:$SGE_ROOT/lib/$ARCH"
fi
export $shlib_path_name


#---------------------------------------------------------------------------
usage()
{
    echo "CBRAIN start/stop script. Valid parameters are:"
    echo ""
    echo "   (no parameters): start all rails applications"
    echo "   \"start\"        start all rails applications"
    echo "   \"stop\"         stop all rails applications"
    echo ""
    echo "Only one of the parameters \"start\" or \"stop\" is allowed."
    echo
    exit 1
}


#---------------------------------------------------------------------------
# CBRAIN start
#

if [ "$#" -gt 1 -o "X$1" = "X-h" -o "$1" = "help" ]; then
    usage
fi

command="start"
if [ "$#" -eq 1 ] ; then
    command="$1"
fi

BrainPortal_PORT=3000
Bourreau_PORT=3050
jiv_PORT=3070

if [ "$command" = "start" ] ; then

    cd BrainPortal || exit 10
    if script/server -d -p $BrainPortal_PORT /dev/null 2>/dev/null ; then
        echo "BrainPortal started on port $BrainPortal_PORT"
    else
        echo "Could not start BrainPortal on port $BrainPortal_PORT"
        exit 10
    fi
    cd ..

    cd Bourreau || exit 10
    if script/server -d -p $Bourreau_PORT /dev/null 2>/dev/null ; then
        echo "Bourreau started on port $Bourreau_PORT"
    else
        echo "Could not start Bourreau on port $Bourreau_PORT"
        exit 10
    fi
    cd ..

    cd jiv || exit 10
    if script/server -d -p $jiv_PORT /dev/null 2>/dev/null ; then
        echo "jiv started on port $jiv_PORT"
    else
        echo "Could not start jiv on port $jiv_PORT"
        exit 10
    fi
    cd ..

fi

#---------------------------------------------------------------------------
# CBRAIN stop
#

if [ "$command" = "stop" ] ; then
    #echo stop not implemented yet
    killall -v -r '.*mongrel_rails.*'
fi

