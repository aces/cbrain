#!/bin/bash
set -euo pipefail
umask 077

if [ "${1:-portal}" = slurm-node ]; then
  exec /opt/cbrain/deploy/apple-container/slurm/entrypoint.sh
fi

setup_app() {
  local app=$1
  mkdir -p "/opt/cbrain/$app/tmp/pids" "/opt/cbrain/$app/tmp/sockets" "/data/logs/$app"
  if [ ! -L "/opt/cbrain/$app/log" ]; then
    cp -a "/opt/cbrain/$app/log/." "/data/logs/$app/" 2>/dev/null || true
    rm -rf "/opt/cbrain/$app/log"
    ln -s "/data/logs/$app" "/opt/cbrain/$app/log"
  fi
  rm -f "/opt/cbrain/$app/tmp/pids/server.pid" "/opt/cbrain/$app/tmp/sockets/"*.sock
}

mkdir -p /data/ssh /run/sshd /root/.ssh
if [ ! -f /data/ssh/host_ed25519 ]; then
  ssh-keygen -q -t ed25519 -N '' -f /data/ssh/host_ed25519
fi
sshd_options=(-h /data/ssh/host_ed25519 -o PermitRootLogin=prohibit-password -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no)

if [ "${1:-portal}" = worker ]; then
  setup_app Bourreau
  mkdir -p /data/work /data/worker-cache
  # The portal supplies database.yml through the reverse SSH tunnel.
  rm -f /opt/cbrain/Bourreau/config/database.yml
  printf 'class CBRAIN\n  CBRAIN_RAILS_APP_NAME = "LocalBourreau"\nend\n' > /opt/cbrain/Bourreau/config/initializers/config_bourreau.rb
  printf '%s\n' "${CBRAIN_PORTAL_PUBLIC_KEY:?Missing portal public key}" > /root/.ssh/authorized_keys
  # SSH-launched shells need the image's Ruby and Bundler on PATH.
  # shellcheck disable=SC2016
  printf 'export PATH=/usr/local/bundle/bin:/usr/local/bin:$PATH\nexport GEM_HOME=/usr/local/bundle\n' > /root/.bashrc
  if [ "${CBRAIN_LOCAL_PROFILE:-unix}" = slurm ]; then
    mkdir -p /cluster/work /cluster/cache
    cd /opt/cbrain
    # shellcheck source=deploy/apple-container/slurm/start-munge.sh
    source deploy/apple-container/slurm/start-munge.sh
    printf 'export SLURM_CONF=/cluster/slurm.conf\n' >> /root/.bashrc
  fi
  exec /usr/sbin/sshd -D -e "${sshd_options[@]}"
fi

setup_app BrainPortal
mkdir -p /data/files /data/portal-cache /data/portal-log
cat > /opt/cbrain/BrainPortal/config/database.yml <<'YAML'
development:
  adapter: mysql2
  encoding: utf8
  host: <%= ENV.fetch('CBRAIN_DB_HOST') %>
  database: cbrain
  username: cbrain
  password: <%= ENV.fetch('MARIADB_PASSWORD').inspect %>
  pool: 20
YAML
cat > /opt/cbrain/BrainPortal/config/secrets.yml <<YAML
development:
  secret_key_base: "$SECRET_KEY_BASE"
YAML
printf 'class CBRAIN\n  CBRAIN_RAILS_APP_NAME = "LocalPortal"\nend\n' > /opt/cbrain/BrainPortal/config/initializers/config_portal.rb

if [ ! -f /data/ssh/id_cbrain_ed25519 ]; then
  ssh-keygen -q -t ed25519 -N '' -f /data/ssh/id_cbrain_ed25519
fi
cp /data/ssh/id_cbrain_ed25519* /root/.ssh/
cp /data/ssh/id_cbrain_ed25519.pub /root/.ssh/authorized_keys
# Serve LocalStorage to the Bourreau via SSH using the forwarded portal identity.
/usr/sbin/sshd "${sshd_options[@]}"
cd /opt/cbrain/BrainPortal
bundle exec rake db:local:prepare db:sanity:check
exec bundle exec puma -b tcp://0.0.0.0:3000 > /data/portal-log/server.log 2>&1
