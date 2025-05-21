#!/usr/local/bin/bash

DUMP_FILE=~/backups/fargoldcity_2025-05-21.sql
TABLESPACE_DIR=~/vwp40
PGPORT=5432
PGUSER=postgres0
DBNAME=fargoldcity

mkdir -p "$TABLESPACE_DIR"
chmod 700 "$TABLESPACE_DIR"

psql -U "$PGUSER" -p "$PGPORT" -d postgres -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'cityuser') THEN CREATE ROLE cityuser LOGIN PASSWORD '1234'; END IF; END \$\$;"

psql -U "$PGUSER" -p "$PGPORT" -d postgres -c "SELECT 1 FROM pg_tablespace WHERE spcname = 'index_space';" | grep -q 1
if [ $? -ne 0 ]; then
  psql -U "$PGUSER" -p "$PGPORT" -d postgres -c "CREATE TABLESPACE index_space LOCATION '$TABLESPACE_DIR';"
fi

psql -U "$PGUSER" -p "$PGPORT" -d postgres -c "SELECT 1 FROM pg_database WHERE datname = '$DBNAME';" | grep -q 1
if [ $? -ne 0 ]; then
  createdb -U "$PGUSER" -p "$PGPORT" -O "$PGUSER" "$DBNAME"
fi

psql -U "$PGUSER" -p "$PGPORT" -d "$DBNAME" < "$DUMP_FILE"
