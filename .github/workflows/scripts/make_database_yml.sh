#!/bin/bash

# This scripts outputs in STDOUT the Rails
# DB configuration for the test environment

cat <<RAILS_DB_CONFIG_YML
${RAILS_ENV:-test}:
  adapter: mysql2
  host: localhost
  database: ${MARIADB_DATABASE:-cbrain_test}
  username: ${MARIADB_USER:-cbrain_user}
  password: ${MARIADB_PASSWORD:-no.such.thing}
  port: ${MARIADB_PORT:-3306}
RAILS_DB_CONFIG_YML

