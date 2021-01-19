#!/bin/bash

# This script outputs in STDOUT the Rails
# DB configuration for the test environment

cat <<RAILS_DB_CONFIG_YML
${RAILS_ENV:-bad_test}:
  adapter:  mysql2
  host:     ${MARIADB_HOST:-localhost}
  database: ${MARIADB_DATABASE:-bad_cbrain_test}
  username: ${MARIADB_USER:-bad_cbrain_user}
  password: ${MARIADB_PASSWORD:-bad_no_such_thing}
  port:     ${MARIADB_PORT:-bad_port}
RAILS_DB_CONFIG_YML

