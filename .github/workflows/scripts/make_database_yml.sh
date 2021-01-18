#!/bin/bash

# This scripts outputs in STDOUT the Rails
# DB configuration for the test environment

cat <<RAILS_DB_CONFIG_YML
${RAILS_ENV:-bad_test}:
  adapter: mysql2
  host: 127.0.0.1
  database: ${MARIADB_DATABASE:-bad_cbrain_test}
  username: ${MARIADB_USER:-bad_cbrain_user}
  password: ${MARIADB_PASSWORD:-bad_no_such_thing}
  port: ${MARIADB_PORT:-13306}
RAILS_DB_CONFIG_YML

