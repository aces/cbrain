#!/bin/bash
# Sourced by the Bourreau and scheduler entrypoints.
install -o munge -g munge -m 400 /cluster/munge.key /etc/munge/munge.key
install -d -o munge -g munge -m 755 /run/munge
runuser -u munge -- /usr/sbin/munged
