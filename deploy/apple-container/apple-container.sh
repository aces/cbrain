#!/bin/bash
# Local CBRAIN deployment using Apple's container CLI (no Docker daemon).
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
STATE="$ROOT/.local/apple-container"
IMAGE=cbrain-local:dev

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
    container build --cpus 4 --memory 4G -t "$IMAGE" -f "$ROOT/deploy/apple-container/Containerfile" "$ROOT"
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
      } > "$STATE/env"
    fi
    container network inspect cbrain-local >/dev/null 2>&1 || container network create cbrain-local
    container volume inspect cbrain-db-data >/dev/null 2>&1 || container volume create cbrain-db-data
    container volume inspect cbrain-app-data >/dev/null 2>&1 || container volume create cbrain-app-data
    container volume inspect cbrain-bourreau-data >/dev/null 2>&1 || container volume create cbrain-bourreau-data
    if ! exists cbrain-db; then
      container run -d --name cbrain-db --network cbrain-local --memory 1G \
        --env-file "$STATE/env" -v cbrain-db-data:/var/lib/mysql docker.io/library/mariadb:10.11
    elif ! running cbrain-db; then
      container start cbrain-db
    fi
    ready=false
    for _attempt in {1..60}; do
      if container exec cbrain-db healthcheck.sh --connect --innodb_initialized >/dev/null 2>&1; then ready=true; break; fi
      sleep 2
    done
    "$ready" || { echo 'MariaDB did not become ready; run container logs cbrain-db' >&2; exit 1; }
    db_ip=$(container_ip cbrain-db)
    # Replace the legacy combined app container or refresh a changed DB address.
    if exists cbrain-app; then
      if [ "$(container_env cbrain-app CBRAIN_DB_HOST)" != "$db_ip" ] ||
         [ "$(container_env cbrain-app CBRAIN_SPLIT_PORTAL)" != 1 ]; then
        if running cbrain-app; then container stop cbrain-app; fi
        container delete cbrain-app
      fi
    fi
    # The worker's database socket belongs to the portal's SSH session.
    if ! running cbrain-app && running cbrain-bourreau; then
      container stop cbrain-bourreau
    fi
    if ! exists cbrain-app; then
      container run -d --name cbrain-app --network cbrain-local --cpus 4 --memory 4G \
        --env-file "$STATE/env" -e "CBRAIN_DB_HOST=$db_ip" -e CBRAIN_SPLIT_PORTAL=1 \
        -v cbrain-app-data:/data -p 127.0.0.1:3000:3000 "$IMAGE"
    elif ! running cbrain-app; then
      container start cbrain-app
    fi
    ready=false
    for _attempt in {1..120}; do
      if curl -fsS http://127.0.0.1:3000/ >/dev/null 2>&1; then ready=true; break; fi
      running cbrain-app || { container logs cbrain-app; container exec cbrain-app tail -n 40 /data/portal-log/server.log || true; exit 1; }
      sleep 2
    done
    "$ready" || { echo 'Portal did not become ready; run deploy/apple-container/apple-container.sh logs' >&2; exit 1; }
    portal_ip=$(container_ip cbrain-app)
    portal_key=$(container exec cbrain-app cat /data/ssh/id_cbrain_ed25519.pub)
    if exists cbrain-bourreau && [ "$(container_env cbrain-bourreau CBRAIN_PORTAL_PUBLIC_KEY)" != "$portal_key" ]; then
      if running cbrain-bourreau; then container stop cbrain-bourreau; fi
      container delete cbrain-bourreau
    fi
    if ! exists cbrain-bourreau; then
      container run -d --name cbrain-bourreau --network cbrain-local --cpus 2 --memory 2G \
        -e "CBRAIN_PORTAL_PUBLIC_KEY=$portal_key" -v cbrain-bourreau-data:/data "$IMAGE" worker
    elif ! running cbrain-bourreau; then
      container start cbrain-bourreau
    fi
    ready=false
    for _attempt in {1..30}; do
      if container exec cbrain-bourreau test -s /data/ssh/host_ed25519.pub; then ready=true; break; fi
      running cbrain-bourreau || { container logs cbrain-bourreau; exit 1; }
      sleep 2
    done
    "$ready" || { echo 'Bourreau SSH host key was not created' >&2; exit 1; }
    worker_ip=$(container_ip cbrain-bourreau)
    trust_host cbrain-app "$worker_ip" cbrain-bourreau
    trust_host cbrain-app "$portal_ip" cbrain-app
    trust_host cbrain-bourreau "$portal_ip" cbrain-app

    ready=false
    for _attempt in {1..30}; do
      if container exec cbrain-app ssh -i /root/.ssh/id_cbrain_ed25519 \
        -o BatchMode=yes -o ConnectTimeout=2 "root@$worker_ip" true; then
        ready=true
        break
      fi
      running cbrain-bourreau || { container logs cbrain-bourreau; exit 1; }
      sleep 2
    done
    "$ready" || { echo 'Bourreau did not become reachable over SSH' >&2; exit 1; }

    # Preserve the old worker's work directories and cache on first upgrade.
    # shellcheck disable=SC2016
    container exec cbrain-app bash -e -c '
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

    container exec -w /opt/cbrain/BrainPortal -e "CBRAIN_WORKER_HOST=$worker_ip" \
      -e "CBRAIN_STORAGE_HOST=$portal_ip" cbrain-app bundle exec rake db:local:worker
    echo 'CBRAIN: http://localhost:3000 — login: admin'
    echo "Initial password: deploy/apple-container/apple-container.sh credentials (change on first login)"
    ;;
  stop)
    for name in cbrain-bourreau cbrain-app cbrain-db; do
      if exists "$name" && running "$name"; then container stop "$name"; fi
    done
    ;;
  logs)
    container logs cbrain-app
    container exec cbrain-app tail -n 80 /data/portal-log/server.log
    container logs cbrain-bourreau
    ;;
  status) container list ;;
  smoke) container exec -w /opt/cbrain/BrainPortal cbrain-app bundle exec rake db:local:smoke ;;
  credentials) sed -n 's/^CBRAIN_ADMIN_PASSWORD=/Initial admin password: /p' "$STATE/env" ;;
  shell) container exec -it -w /opt/cbrain/BrainPortal cbrain-app bash ;;
  *) echo 'Usage: deploy/apple-container/apple-container.sh {build|up|stop|status|logs|credentials|shell|smoke}' >&2; exit 2 ;;
esac
