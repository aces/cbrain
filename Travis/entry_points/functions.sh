#!/bin/bash

############################
# Common utility functions #
############################

# Prints a message and exits with a non-zero code.
function die {
    echo $*
    exit 2
}

# Generate Host keys, if required
function generate_ssh_host_keys {
    local RSA_KEY=/etc/ssh/ssh_host_rsa_key
    local DSA_KEY=/etc/ssh/ssh_host_dsa_key
    local KEYGEN=/usr/bin/ssh-keygen

    if [ ! -s $RSA_KEY ]; then
        echo -n "Generating SSH2 RSA host key: "
        rm -f $RSA_KEY
        if test ! -f $RSA_KEY && $KEYGEN -q -t rsa -f $RSA_KEY -C '' -N '' >&/dev/null; then
            chmod 600 $RSA_KEY
            chmod 644 $RSA_KEY.pub
            if [ -x /sbin/restorecon ]; then
                /sbin/restorecon $RSA_KEY.pub
            fi
        else
            die "RSA key generation failed"
        fi
    fi

    if [ ! -s $DSA_KEY ]; then
        echo -n "Generating SSH2 DSA host key: "
        rm -f $DSA_KEY
        if test ! -f $DSA_KEY && $KEYGEN -q -t dsa -f $DSA_KEY -C '' -N '' >&/dev/null; then
            chmod 600 $DSA_KEY
            chmod 644 $DSA_KEY.pub
            if [ -x /sbin/restorecon ]; then
                /sbin/restorecon $DSA_KEY.pub
            fi
        else
            die $"DSA key generation failed"
        fi
    fi
}
