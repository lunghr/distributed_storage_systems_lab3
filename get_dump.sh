#!/usr/local/bin/bash

DATE=$(date +"%Y-%m-%d")
BACKUP_NAME="cluster_$DATE.sql.gz"
BACKUP_DIR=~
REMOTE_USER=postgres0
REMOTE_HOST=pg155.cs.ifmo.ru

ssh "$REMOTE_USER@$REMOTE_HOST" "bash dump_cluster.sh" > "$BACKUP_DIR/$BACKUP_NAME"
find "$BACKUP_DIR" -name "cluster_*.sql.gz" -type f -mtime +28 -exec rm -f {} \;