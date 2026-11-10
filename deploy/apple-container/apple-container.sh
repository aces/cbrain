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
IMAGE="$prefix-local:dev"
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

# Reading saved credentials needs neither a compatible host nor the runtime.
case "${1:-up}" in
  build|up|stop|logs|status|smoke|shell) check_host ;;
  credentials) ;;
  *) echo 'Usage: deploy/apple-container/apple-container.sh {build|up|stop|status|logs|credentials|shell|smoke}' >&2; exit 2 ;;
esac
mkdir -p "$STATE"
chmod 700 "$STATE"
exists() { container inspect "$1" >/dev/null 2>&1; }
running() { container list --format json | python3 -c 'import json,sys; sys.exit(not any(c["configuration"]["id"] == sys.argv[1] for c in json.load(sys.stdin)))' "$1"; }
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

case "${1:-up}" in
  build)
    container system start
    container build --cpus 4 --memory 4G --build-arg "CBRAIN_SLURM=$slurm" -t "$IMAGE" -f "$ROOT/deploy/apple-container/Containerfile" "$ROOT"
    ;;
  up)
    container system start
    container image inspect "$IMAGE" >/dev/null 2>&1 || { echo "Build the app first: deploy/apple-container/apple-container.sh build" >&2; exit 1; }
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
    container network inspect "$network" >/dev/null 2>&1 || container network create "$network"
    container volume inspect "$db-data" >/dev/null 2>&1 || container volume create "$db-data"
    container volume inspect "$app-data" >/dev/null 2>&1 || container volume create "$app-data"
    container volume inspect "$worker-data" >/dev/null 2>&1 || container volume create "$worker-data"
    if ! exists "$db"; then
      container run -d --name "$db" --network "$network" --memory 1G \
        --env-file "$STATE/env" -v "$db-data:/var/lib/mysql" docker.io/library/mariadb:10.11
    elif ! running "$db"; then
      container start "$db"
    fi
    ready=false
    for _attempt in {1..60}; do
      if container exec "$db" healthcheck.sh --connect --innodb_initialized >/dev/null 2>&1; then ready=true; break; fi
      sleep 2
    done
    "$ready" || { echo "MariaDB did not become ready. Run container logs $db" >&2; exit 1; }
    db_ip=$(container_ip "$db")
    worker_mount=(-v "$worker-data:/data")
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
      container volume inspect "$node-data" >/dev/null 2>&1 || container volume create "$node-data"
      if exists "$node" && [ "$(container_env "$node" CBRAIN_DB_HOST)" != "$db_ip" ]; then
        if running "$node"; then container stop "$node"; fi
        container delete "$node"
      fi
      if ! exists "$node"; then
        container run -d --name "$node" --network "$network" --cpus 2 --memory 2G \
          -e "CBRAIN_DB_HOST=$db_ip" -e "SLURM_DB_PASSWORD=$slurm_db_password" \
          -v "$node-data:/data" -v "$STATE/cluster:/cluster" "$IMAGE" slurm-node
      elif ! running "$node"; then
        container start "$node"
      fi
      ready=false
      for _attempt in {1..60}; do
        if container exec -e SLURM_CONF=/cluster/slurm.conf "$node" sinfo -N -h -o '%t' 2>/dev/null |
          grep -Eq '^(idle|mix|alloc)$'; then
          ready=true
          break
        fi
        running "$node" || { container logs "$node"; exit 1; }
        sleep 2
      done
      "$ready" || { echo 'Slurm node did not register' >&2; container logs "$node"; exit 1; }
      worker_mount+=(-v "$STATE/cluster:/cluster")
    fi
    # Replace the legacy combined app container or refresh a changed DB address.
    if exists "$app"; then
      if [ "$(container_env "$app" CBRAIN_DB_HOST)" != "$db_ip" ] ||
         [ "$(container_env "$app" CBRAIN_SPLIT_PORTAL)" != 1 ]; then
        if running "$app"; then container stop "$app"; fi
        container delete "$app"
      fi
    fi
    # The worker's database socket belongs to the portal's SSH session.
    if ! running "$app" && running "$worker"; then
      container stop "$worker"
    fi
    if ! exists "$app"; then
      container run -d --name "$app" --network "$network" --cpus 4 --memory 4G \
        --env-file "$STATE/env" -e "CBRAIN_DB_HOST=$db_ip" -e CBRAIN_SPLIT_PORTAL=1 \
        -v "$app-data:/data" -p "127.0.0.1:$portal_port:3000" "$IMAGE"
    elif ! running "$app"; then
      container start "$app"
    fi
    ready=false
    for _attempt in {1..120}; do
      if curl -fsS "http://127.0.0.1:$portal_port/" >/dev/null 2>&1; then ready=true; break; fi
      running "$app" || { container logs "$app"; container exec "$app" tail -n 40 /data/portal-log/server.log || true; exit 1; }
      sleep 2
    done
    "$ready" || { echo 'Portal did not become ready; run deploy/apple-container/apple-container.sh logs' >&2; exit 1; }
    portal_ip=$(container_ip "$app")
    portal_key=$(container exec "$app" cat /data/ssh/id_cbrain_ed25519.pub)
    if exists "$worker" && [ "$(container_env "$worker" CBRAIN_PORTAL_PUBLIC_KEY)" != "$portal_key" ]; then
      if running "$worker"; then container stop "$worker"; fi
      container delete "$worker"
    fi
    if ! exists "$worker"; then
      container run -d --name "$worker" --network "$network" --cpus 2 --memory 2G \
        -e "CBRAIN_PORTAL_PUBLIC_KEY=$portal_key" -e "CBRAIN_LOCAL_PROFILE=$profile" \
        "${worker_mount[@]}" "$IMAGE" worker
    elif ! running "$worker"; then
      container start "$worker"
    fi
    ready=false
    for _attempt in {1..30}; do
      if container exec "$worker" test -s /data/ssh/host_ed25519.pub; then ready=true; break; fi
      running "$worker" || { container logs "$worker"; exit 1; }
      sleep 2
    done
    "$ready" || { echo 'Bourreau SSH host key was not created' >&2; exit 1; }
    worker_ip=$(container_ip "$worker")
    trust_host "$app" "$worker_ip" "$worker"
    trust_host "$app" "$portal_ip" "$app"
    trust_host "$worker" "$portal_ip" "$app"

    ready=false
    for _attempt in {1..30}; do
      if container exec "$app" ssh -i /root/.ssh/id_cbrain_ed25519 \
        -o BatchMode=yes -o ConnectTimeout=2 "root@$worker_ip" true; then
        ready=true
        break
      fi
      running "$worker" || { container logs "$worker"; exit 1; }
      sleep 2
    done
    "$ready" || { echo 'Bourreau did not become reachable over SSH' >&2; exit 1; }

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
    ;;
  stop)
    services=("$worker" "$app")
    if [ "$slurm" = 1 ]; then services+=("$node"); fi
    services+=("$db")
    for name in "${services[@]}"; do
      if exists "$name" && running "$name"; then container stop "$name"; fi
    done
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
  *) echo 'Usage: deploy/apple-container/apple-container.sh {build|up|stop|status|logs|credentials|shell|smoke}' >&2; exit 2 ;;
esac
