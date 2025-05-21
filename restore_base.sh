#!/usr/local/bin/bash

PGPORT=9136
PGUSER=postgres0
DBNAME=fargoldcity
DUMP_FILE=~/fargoldcity_2025-05-22.sql
NEW_TABLESPACE_DIR=~/new_vwp40
TABLESPACE_NAME=index_space


mkdir -p "$NEW_TABLESPACE_DIR"
chmod 700 "$NEW_TABLESPACE_DIR"

psql -U "$PGUSER" -p "$PGPORT" -d postgres -tc "SELECT 1 FROM pg_roles WHERE rolname='cityuser'" | grep -q 1 || \
psql -U "$PGUSER" -p "$PGPORT" -d postgres -c "CREATE ROLE cityuser LOGIN PASSWORD '1234';"

psql -U "$PGUSER" -p "$PGPORT" -d postgres -tc "SELECT 1 FROM pg_tablespace WHERE spcname='$TABLESPACE_NAME'" | grep -q 1 || \
psql -U "$PGUSER" -p "$PGPORT" -d postgres -c "CREATE TABLESPACE $TABLESPACE_NAME LOCATION '$NEW_TABLESPACE_DIR';"

psql -U "$PGUSER" -p "$PGPORT" -lqt | cut -d \| -f 1 | grep -qw "$DBNAME" || \
psql -U "$PGUSER" -p "$PGPORT" -d postgres -c "CREATE DATABASE $DBNAME OWNER $PGUSER TEMPLATE template1;"

gzip -d "$DUMP_FILE".gz

psql -U "$PGUSER" -p "$PGPORT" -d "$DBNAME" < "$DUMP_FILE"
psql -U "$PGUSER" -p "$PGPORT" -d "$DBNAME" -c '\dt'
