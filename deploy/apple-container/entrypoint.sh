#!/bin/bash
set -euo pipefail
umask 077
rm -f /tmp/cbrain-ready
mkdir -p /data/{files,work,portal-cache,worker-cache,ssh,portal-log,worker-log} /run/sshd /root/.ssh
for app in BrainPortal Bourreau; do
  mkdir -p /opt/cbrain/$app/tmp/{pids,sockets} /data/logs/$app
  if [ ! -L /opt/cbrain/$app/log ]; then
    cp -a /opt/cbrain/$app/log/. /data/logs/$app/ 2>/dev/null || true
    rm -rf /opt/cbrain/$app/log
    ln -s /data/logs/$app /opt/cbrain/$app/log
  fi
  rm -f /opt/cbrain/$app/tmp/pids/server.pid /opt/cbrain/$app/tmp/sockets/*.sock
  cat > /opt/cbrain/$app/config/database.yml <<'YAML'
development:
  adapter: mysql2
  encoding: utf8
  host: <%= ENV.fetch('CBRAIN_DB_HOST') %>
  database: cbrain
  username: cbrain
  password: <%= ENV.fetch('MARIADB_PASSWORD').inspect %>
  pool: 20
YAML
  cat > /opt/cbrain/$app/config/secrets.yml <<YAML
development:
  secret_key_base: "$SECRET_KEY_BASE"
YAML
done
# The portal supplies Bourreau database credentials through its SSH tunnel.
rm -f /opt/cbrain/Bourreau/config/database.yml
printf 'class CBRAIN\n  CBRAIN_RAILS_APP_NAME = "LocalPortal"\nend\n' > /opt/cbrain/BrainPortal/config/initializers/config_portal.rb
printf 'class CBRAIN\n  CBRAIN_RAILS_APP_NAME = "LocalBourreau"\nend\n' > /opt/cbrain/Bourreau/config/initializers/config_bourreau.rb
if [ ! -f /data/ssh/id_cbrain_ed25519 ]; then
  ssh-keygen -q -t ed25519 -N '' -f /data/ssh/id_cbrain_ed25519
fi
cp /data/ssh/id_cbrain_ed25519* /root/.ssh/
cp /data/ssh/id_cbrain_ed25519.pub /root/.ssh/authorized_keys
chmod 600 /root/.ssh/*
ssh-keygen -A
/usr/sbin/sshd
ssh-keyscan -H 127.0.0.1 > /root/.ssh/known_hosts 2>/dev/null
# SSH-launched Bourreau shells need the image's Ruby/bundler on PATH.
# Expand PATH in the SSH shell, not while writing its configuration.
# shellcheck disable=SC2016
printf 'export PATH=/usr/local/bundle/bin:/usr/local/bin:$PATH\nexport GEM_HOME=/usr/local/bundle\n' > /root/.bashrc
cd /opt/cbrain/BrainPortal
bundle exec rake db:local:prepare db:sanity:check
bundle exec puma -b tcp://0.0.0.0:3000 > /data/portal-log/server.log 2>&1 &
portal_pid=$!
trap 'kill "$portal_pid" 2>/dev/null || true; exit' TERM INT
for _attempt in {1..90}; do
  if curl -fsS http://127.0.0.1:3000/ >/dev/null 2>&1; then break; fi
  kill -0 "$portal_pid"
  sleep 2
done
bundle exec rake db:local:worker
touch /tmp/cbrain-ready
wait "$portal_pid"
