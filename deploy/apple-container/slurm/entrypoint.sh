#!/bin/bash
set -euo pipefail
umask 077
cd /opt/cbrain
# shellcheck source=deploy/apple-container/slurm/start-munge.sh
source deploy/apple-container/slurm/start-munge.sh

node=$(hostname)
address=$(ip -4 -o addr show scope global | awk 'NR == 1 { sub(/\/.*/, "", $4); print $4 }')
: "${address:?Slurm node needs a network address}"
install -d -o slurm -g slurm -m 755 /data/slurmctld
mkdir -p /data/slurmd
export SLURM_CONF=/cluster/slurm.conf
cat > "$SLURM_CONF.tmp" <<CONF
ClusterName=cbrain-local
SlurmctldHost=$node($address)
SlurmUser=slurm
StateSaveLocation=/data/slurmctld
SlurmdSpoolDir=/data/slurmd
SlurmctldPidFile=/data/slurmctld/slurmctld.pid
SlurmdPidFile=/run/slurmd.pid
AuthType=auth/munge
ProctrackType=proctrack/linuxproc
TaskPlugin=task/none
JobAcctGatherType=jobacct_gather/linux
AccountingStorageType=accounting_storage/slurmdbd
AccountingStorageHost=$address
SelectType=select/cons_tres
SelectTypeParameters=CR_Core
ReturnToService=2
SlurmdParameters=config_overrides
NodeName=$node NodeAddr=$address CPUs=2 RealMemory=1024 State=UNKNOWN
PartitionName=cbrain Nodes=$node Default=YES MaxTime=60 State=UP
CONF
chmod 644 "$SLURM_CONF.tmp"
mv -f "$SLURM_CONF.tmp" "$SLURM_CONF"

# Slurm 20.11 finds slurmdbd.conf next to the selected slurm.conf.
install -m 644 "$SLURM_CONF" /etc/slurm/slurm.conf
dbd_config=/etc/slurm/slurmdbd.conf
cat > "$dbd_config" <<CONF
AuthType=auth/munge
DbdHost=$node
DbdAddr=$address
SlurmUser=slurm
PidFile=/data/slurmctld/slurmdbd.pid
StorageType=accounting_storage/mysql
StorageHost=${CBRAIN_DB_HOST:?Missing database address}
StorageLoc=slurm_acct_db
StorageUser=slurm
StoragePass=${SLURM_DB_PASSWORD:?Missing accounting database password}
CONF
chown slurm:slurm "$dbd_config"
chmod 600 "$dbd_config"

pids=()
stop_daemons() {
  if [ "${#pids[@]}" -gt 0 ]; then
    kill -TERM "${pids[@]}" 2>/dev/null || true
    wait "${pids[@]}" 2>/dev/null || true
  fi
}
trap stop_daemons EXIT
trap 'exit 0' TERM INT
SLURM_CONF=/etc/slurm/slurm.conf /usr/sbin/slurmdbd -D &
pids+=("$!")
ready=false
for _attempt in {1..30}; do
  kill -0 "${pids[0]}"
  if sacctmgr -n show cluster >/dev/null 2>&1; then ready=true; break; fi
  sleep 2
done
"$ready" || { echo 'Slurm accounting did not become ready' >&2; exit 1; }
/usr/sbin/slurmctld -D &
pids+=("$!")
/usr/sbin/slurmd -D &
pids+=("$!")
wait -n
