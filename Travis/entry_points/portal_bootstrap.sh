#!/bin/bash -e

source /home/cbrain/cbrain/Travis/entry_points/functions.sh

###############
# Main script #
###############

for volume in /home/cbrain/cbrain_data_cache \
         /home/cbrain/.ssh \
         /home/cbrain/plugins \
         /home/cbrain/data_provider
do
    echo "chowning ${volume}"
    chown cbrain:cbrain ${volume}
done
for volume in /home/cbrain/cbrain_data_cache \
         /home/cbrain/.ssh
do
    echo "changing permissions for ${volume}"
    chmod 700 ${volume}
done

id
exec su cbrain "/home/cbrain/cbrain/Travis/entry_points/portal.sh"
