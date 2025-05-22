#!/usr/local/bin/bash

export PGDATA="/var/db/postgres0/tah70"
ARCHIVE_DIR="/var/db/postgres0/wal"
PGUSER="postgres0"
BACKUP_DIR="/var/db/postgres0/backups/base"
BACKUP_FILE="2025-05-22"
WAL="/var/db/postgres0/backups/wal"
PGPORT=9136
TABLESPACE_DIR="/var/db/postgres0/new_vwp40"
TIME='2025-05-23 00:05:54.390419+03'


pg_ctl stop

rm -rf "$TABLESPACE_DIR"
mkdir -p "$TABLESPACE_DIR"
chown -R "$PGUSER":postgres "$TABLESPACE_DIR"
rm -rf "$PGDATA"/*
mkdir -p "$PGDATA"
chown -R "$PGUSER":postgres "$PGDATA"

chmod 700 "$PGDATA"

tar -xzf "$BACKUP_DIR/$BACKUP_FILE/base.tar.gz" -C "$PGDATA"
tar -xzf "$BACKUP_DIR/$BACKUP_FILE/pg_wal.tar.gz" -C "$ARCHIVE_DIR"
mv -n "$WAL"/* "$ARCHIVE_DIR"

tar -xzf "$BACKUP_DIR/$BACKUP_FILE/16385.tar.gz" -C "$TABLESPACE_DIR"

rm -rf "$PGDATA"/pg_tblspc/*
rm -f "$PGDATA"/pg_tablespace_map/*
ln -s "$TABLESPACE_DIR" "$PGDATA"/pg_tblspc/16385

CONF="$PGDATA/postgresql.conf"
sed -i '' '/^[[:space:]]*#*[[:space:]]*archive_mode/d' "$CONF"
sed -i '' '/^[[:space:]]*#*[[:space:]]*archive_command/d' "$CONF"
sed -i '' '/^[[:space:]]*#*[[:space:]]*recovery_target_timeline/d' "$CONF"
sed -i '' '/^[[:space:]]*#*[[:space:]]*recovery_target_time/d' "$CONF"
sed -i '' '/^[[:space:]]*#*[[:space:]]*restore_command/d' "$CONF"


cat >> "$CONF" <<EOF
archive_mode = 'off'
archive_command = ''
restore_command= 'cp $ARCHIVE_DIR/%f %p'
recovery_target_time = '$TIME'
recovery_target_action = 'promote'
EOF

rm -rf $PGDATA/postgresql.auto.conf
touch $PGDATA/recovery.signal

chown -R $PGUSER:postgres $PGDATA
chmod 700 $PGDATA
pg_ctl start