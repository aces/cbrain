#!/bin/bash
# Local CBRAIN deployment using Apple's container CLI (no Docker daemon).
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
STATE="$ROOT/.local/apple-container"
profile=${CBRAIN_LOCAL_PROFILE:-unix}
case "$profile" in
  unix) prefix=cbrain; portal_port=3000; slurm=0 ;;
  slurm) prefix=cbrain-slurm; portal_port=3003; slurm=1; STATE="$STATE/slurm" ;;
  *) echo 'CBRAIN_LOCAL_PROFILE must be unix or slurm' >&2; exit 1 ;;
esac
# Use the canonical tag written by container build.
IMAGE="docker.io/library/$prefix-local:dev"
app="$prefix-app"
worker="$prefix-bourreau"
db="$prefix-db"
network="$prefix-local"
node="$prefix-node"

check_host() {
  if [ "$(uname -s)" != Darwin ]; then
    echo 'Error: Apple container requires macOS on an Apple silicon Mac.' >&2
    exit 1
  fi
  # A shell running under Rosetta reports x86_64 even on Apple silicon.
  if [ "$(uname -m)" != arm64 ] && [ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" != 1 ]; then
    echo 'Error: Apple container requires Apple silicon; Intel Macs are not supported.' >&2
    exit 1
  fi
  local macos_version macos_major
  macos_version=$(sw_vers -productVersion)
  macos_major=${macos_version%%.*}
  if [[ ! "$macos_major" =~ ^[0-9]+$ ]] || [ "$macos_major" -lt 26 ]; then
    echo "Error: This deployment requires macOS 26 or newer (found $macos_version)." >&2
    exit 1
  fi
  if ! command -v container >/dev/null 2>&1; then
    echo 'Error: Apple container CLI is not installed or is not on PATH.' >&2
    echo 'Install the signed package from https://github.com/apple/container/releases, then retry.' >&2
    exit 1
  fi
}

usage() {
  echo 'Usage: deploy/apple-container/apple-container.sh {up|rebuild|build|stop|status|logs|credentials|shell|smoke}' >&2
  exit 2
}

# Reading saved credentials needs neither a compatible host nor the runtime.
case "${1:-up}" in
  up|rebuild|build|stop|logs|status|smoke|shell) check_host ;;
  credentials) ;;
  *) usage ;;
esac
exists() { container inspect "$1" >/dev/null 2>&1; }
running() { container list --quiet | grep -Fx "$1" >/dev/null; }
container_ip() {
  container inspect "$1" | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["status"]["networks"][0]["ipv4Address"].split("/")[0])'
}

container_env() {
  container inspect "$1" | python3 -c 'import json,sys; env=json.load(sys.stdin)[0]["configuration"]["initProcess"]["environment"]; prefix=sys.argv[1]+"="; print(next((v[len(prefix):] for v in env if v.startswith(prefix)), ""))' "$2"
}

trust_host() {
  local client=$1 address=$2 server=$3 key
  key=$(container exec "$server" cat /data/ssh/host_ed25519.pub)
  # Expand the arguments inside the client container.
  # shellcheck disable=SC2016
  container exec "$client" sh -c '
    ssh-keygen -R "$1" >/dev/null 2>&1 || true
    printf "%s %s\n" "$1" "$2" >> /root/.ssh/known_hosts
  ' sh "$address" "$key"
}

start_service() {
  local service=$1 data_dir=$2
  shift 2
  if ! exists "$service"; then
    container volume inspect "$service-data" >/dev/null 2>&1 || container volume create "$service-data"
    container run -d --name "$service" --network "$network" -v "$service-data:$data_dir" "$@"
  elif ! running "$service"; then
    container start "$service"
  fi
}

stop_service() {
  if running "$1"; then container stop "$1"; fi
}

remove_service() {
  if exists "$1"; then
    stop_service "$1"
    container delete "$1"
  fi
}

wait_for() {
  local service=$1 attempts=$2 message=$3 attempt
  shift 3
  for ((attempt = 0; attempt < attempts; attempt++)); do
    if "$@" >/dev/null 2>&1; then return 0; fi
    if ! running "$service"; then break; fi
    sleep 2
  done
  echo "$message" >&2
  container logs "$service" >&2 || true
  if [ "$service" = "$app" ]; then
    container exec "$app" tail -n 40 /data/portal-log/server.log >&2 || true
  fi
  return 1
}

slurm_ready() {
  container exec -e SLURM_CONF=/cluster/slurm.conf "$node" sinfo -N -h -o '%t' |
    grep -Ex 'idle|mix|alloc'
}

build_image() {
  container build --cpus 4 --memory 4G --build-arg "CBRAIN_SLURM=$slurm" -t "$IMAGE" -f "$ROOT/deploy/apple-container/Containerfile" "$ROOT"
}

check_start_tools() {
  if ! command -v python3 >/dev/null 2>&1; then
    echo 'Error: Starting the deployment requires Python 3 to read Apple container metadata.' >&2
    exit 1
  fi
}

services=("$worker" "$app")
if [ "$slurm" = 1 ]; then services+=("$node"); fi

prepare_state() {
  # Container names are shared across checkouts, but this file lives in the checkout.
  if exists "$db" || { [ ! -s "$STATE/env" ] && container volume inspect "$db-data" >/dev/null 2>&1; }; then
    if [ ! -s "$STATE/env" ] ||
       [ "$(sed -n 's/^MARIADB_PASSWORD=//p' "$STATE/env")" != "$(container_env "$db" MARIADB_PASSWORD)" ]; then
      echo "Error: $db-data needs the credentials from its original checkout. Restore $STATE/env before starting it." >&2
      return 1
    fi
  fi
  mkdir -p "$STATE"
  chmod 700 "$STATE"
  if [ ! -f "$STATE/env" ]; then
    umask 077
    {
      echo "MARIADB_DATABASE=cbrain"
      echo "MARIADB_USER=cbrain"
      echo "MARIADB_PASSWORD=$(openssl rand -hex 24)"
      echo "MARIADB_ROOT_PASSWORD=$(openssl rand -hex 24)"
      echo "CBRAIN_ADMIN_PASSWORD=Cb1!$(openssl rand -hex 16)"
      echo "SECRET_KEY_BASE=$(openssl rand -hex 64)"
      if [ "$slurm" = 1 ]; then
        echo "SLURM_DB_PASSWORD=$(openssl rand -hex 24)"
      fi
    } > "$STATE/env"
  fi
}

start_profile() {
  local db_ip portal_ip portal_key worker_ip slurm_db_password
  local worker_options=(-e "CBRAIN_LOCAL_PROFILE=$profile")
  container network inspect "$network" >/dev/null 2>&1 || container network create "$network"
  start_service "$db" /var/lib/mysql --memory 1G --env-file "$STATE/env" docker.io/library/mariadb:10.11
  wait_for "$db" 60 'MariaDB did not become ready' \
    container exec "$db" healthcheck.sh --connect --innodb_initialized
  db_ip=$(container_ip "$db")
  if [ "$slurm" = 1 ]; then
    mkdir -p "$STATE/cluster"
    if [ ! -s "$STATE/cluster/munge.key" ]; then
      (umask 077; openssl rand -out "$STATE/cluster/munge.key" 32)
    fi
    slurm_db_password=$(sed -n 's/^SLURM_DB_PASSWORD=//p' "$STATE/env")
    [[ "$slurm_db_password" =~ ^[a-f0-9]{48}$ ]] || { echo 'Invalid Slurm database password' >&2; exit 1; }
    # Use a separate accounting schema and user in this profile's MariaDB.
    # shellcheck disable=SC2016
    container exec -i "$db" sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb -uroot' <<SQL
CREATE DATABASE IF NOT EXISTS slurm_acct_db;
CREATE USER IF NOT EXISTS 'slurm'@'%' IDENTIFIED BY '$slurm_db_password';
GRANT ALL ON slurm_acct_db.* TO 'slurm'@'%';
SQL
    if exists "$node" && [ "$(container_env "$node" CBRAIN_DB_HOST)" != "$db_ip" ]; then
      remove_service "$node"
    fi
    start_service "$node" /data --cpus 2 --memory 2G \
      -e "CBRAIN_DB_HOST=$db_ip" -e "SLURM_DB_PASSWORD=$slurm_db_password" \
      -v "$STATE/cluster:/cluster" "$IMAGE" slurm-node
    wait_for "$node" 60 'Slurm node did not register' slurm_ready
    worker_options+=(-v "$STATE/cluster:/cluster")
  fi
  # Replace the legacy combined app container or refresh a changed DB address.
  if exists "$app"; then
    if [ "$(container_env "$app" CBRAIN_DB_HOST)" != "$db_ip" ] ||
       [ "$(container_env "$app" CBRAIN_SPLIT_PORTAL)" != 1 ]; then
      remove_service "$app"
    fi
  fi
  # The worker's database socket belongs to the portal's SSH session.
  if ! running "$app"; then stop_service "$worker"; fi
  start_service "$app" /data --cpus 4 --memory 4G \
    --env-file "$STATE/env" -e "CBRAIN_DB_HOST=$db_ip" -e CBRAIN_SPLIT_PORTAL=1 \
    -p "127.0.0.1:$portal_port:3000" "$IMAGE"
  wait_for "$app" 120 'Portal did not become ready' curl -fsS --max-time 2 "http://127.0.0.1:$portal_port/"
  portal_ip=$(container_ip "$app")
  portal_key=$(container exec "$app" cat /data/ssh/id_cbrain_ed25519.pub)
  if exists "$worker" && [ "$(container_env "$worker" CBRAIN_PORTAL_PUBLIC_KEY)" != "$portal_key" ]; then
    remove_service "$worker"
  fi
  start_service "$worker" /data --cpus 2 --memory 2G \
    -e "CBRAIN_PORTAL_PUBLIC_KEY=$portal_key" \
    "${worker_options[@]}" "$IMAGE" worker
  wait_for "$worker" 30 'Bourreau SSH host key was not created' \
    container exec "$worker" test -s /data/ssh/host_ed25519.pub
  worker_ip=$(container_ip "$worker")
  trust_host "$app" "$worker_ip" "$worker"
  trust_host "$app" "$portal_ip" "$app"
  trust_host "$worker" "$portal_ip" "$app"

  wait_for "$worker" 30 'Bourreau did not become reachable over SSH' \
    container exec "$app" ssh -i /root/.ssh/id_cbrain_ed25519 \
    -o BatchMode=yes -o ConnectTimeout=2 "root@$worker_ip" true

  # Preserve the old worker's work directories and cache on first upgrade.
  if [ "$slurm" = 0 ]; then
    # shellcheck disable=SC2016
    container exec "$app" bash -e -c '
    target="root@$1"
    ssh_options=(-i /root/.ssh/id_cbrain_ed25519 -o BatchMode=yes -o ConnectTimeout=5)
    if ! ssh "${ssh_options[@]}" "$target" test -f /data/.legacy-worker-imported; then
      for dir in /data/work /data/worker-cache; do
        if [ -d "$dir" ]; then
          rsync -a -e "ssh ${ssh_options[*]}" "$dir/" "$target:$dir/"
        fi
      done
      ssh "${ssh_options[@]}" "$target" touch /data/.legacy-worker-imported
    fi
    ' bash "$worker_ip"
  fi

  container exec -w /opt/cbrain/BrainPortal -e "CBRAIN_WORKER_HOST=$worker_ip" \
    -e "CBRAIN_STORAGE_HOST=$portal_ip" -e "CBRAIN_LOCAL_PROFILE=$profile" "$app" bundle exec rake db:local:worker
  echo "CBRAIN: http://localhost:$portal_port — login: admin"
  echo "Initial password: deploy/apple-container/apple-container.sh credentials (change on first login)"
}

case "${1:-up}" in
  build)
    container system start
    build_image
    ;;
  up|rebuild)
    check_start_tools
    container system start
    prepare_state
    if [ "${1:-up}" = rebuild ]; then
      build_image
      for service in "${services[@]}"; do remove_service "$service"; done
    elif ! container image inspect "$IMAGE" >/dev/null 2>&1; then
      build_image
    fi
    start_profile
    ;;
  stop)
    for service in "${services[@]}" "$db"; do stop_service "$service"; done
    ;;
  logs)
    container logs "$app"
    container exec "$app" tail -n 80 /data/portal-log/server.log
    container logs "$worker"
    if [ "$slurm" = 1 ]; then container logs "$node"; fi
    ;;
  status) container list ;;
  smoke) container exec -w /opt/cbrain/BrainPortal "$app" bundle exec rake db:local:smoke ;;
  credentials) sed -n 's/^CBRAIN_ADMIN_PASSWORD=/Initial admin password: /p' "$STATE/env" ;;
  shell) container exec -it -w /opt/cbrain/BrainPortal "$app" bash ;;
  *) usage ;;
esac
