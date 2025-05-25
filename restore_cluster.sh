#!/usr/local/bin/bash

DUMP_FILE=~/cluster_$DATE.sql
PGPORT=5432
PGDATA=tah70
OLD_TABLESPACE_DIR='/var/db/postgres0/new_vwp40'
NEW_TABLESPACE_DIR='/var/db/postgres0/new_vwp40'
DUMP_FILE="cluster_2025-05-25.sql"
PGUSER=postgres0

gzip -d "$DUMP_FILE".gz

pg_ctl stop -D "$PGDATA"
rm -rf "$PGDATA"/*
rm -rf "$NEW_TABLESPACE_DIR"


export PGDATA=$PGDATA

mkdir -p "$PGDATA"
chmod 700 "$PGDATA"

initdb -D "$PGDATA" --encoding=UTF8 --locale=C
pg_ctl -D "$PGDATA" -o "-p $PGPORT" -w start

mkdir -p "$NEW_TABLESPACE_DIR"
chmod 700 "$NEW_TABLESPACE_DIR"


OLD="LOCATION '$OLD_TABLESPACE_DIR'"
NEW="LOCATION '$NEW_TABLESPACE_DIR'"

sed -i '' "s|$OLD|$NEW|g" cluster_2025-05-25.sql

psql -U "$PGUSER" -p "$PGPORT" -d postgres -f "$DUMP_FILE"
