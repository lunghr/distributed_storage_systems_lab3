#!/usr/local/bin/bash

DATE=$(date +"%Y-%m-%d")
BACKUP_NAME="fargoldcity_$DATE.sql"

pg_dump -U postgres0 fargoldcity -p 9136 > ~/"$BACKUP_NAME"

gzip ~/"$BACKUP_NAME"

scp ~/"$BACKUP_NAME".gz postgres2@pg158.cs.ifmo.ru:~/backups

rm ~/"$BACKUP_NAME".gz