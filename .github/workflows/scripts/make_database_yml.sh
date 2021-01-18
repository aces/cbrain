#!/bin/bash

# This scripts outputs in STDOUT the Rails
# DB configuration for the test environment

cat <<RAILS_DB_CONFIG_YML
test:
  adapter: mysql2
  host: localhost
  database: $MARIADB_DATABASE
  username: $MARIADB_USER
  password: $MARIADB_PASSWORD
RAILS_DB_CONFIG_YML

