#!/bin/bash
# Websites + MySQL backup script & RSYNC & Email notification
# Source https://github.com/petitsurfeur/backup-rsync
# Copyright (c) 2018-2020 petitsurfeur
# This script is licensed under GNU GPL version 2.0 or above

########   CONFIGURATION   ########
### System Setup ###
HOSTNAME=$(hostname -s)
WEB_DIR="/var/www"
NOW=$(date +"%Y-%m-%d")
DAY=$(date +"%A")
BACKUP_DIR=/tmp/backup.$NOW
VHOST_DIR="/etc/apache2/sites-available"

### MySQL Setup ###
MUSER=""
MPASS=""
MHOST="localhost"
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"
GZIP="$(which gzip)"

### RSYNC Setup ###
REMOTE_HOST=""
REMOTE_PORT="" # REMOTE SSH PORT
REMOTE_DIR="/srv/backup/"
REMOTE_USER=""

### MAIL Setup ###
MAIL_TO="admin@"

########  END CONFIGURATION  ########


### Create backup folder
[ ! -d $BACKUP_DIR ] && mkdir -p $BACKUP_DIR || : 


### Backup every website
cd $WEB_DIR
for website in * ; do
  if [[ -d $website && ! -L "$website" ]]; then
    echo "Found website folder: $website"
    date=$(date -I)
    tar -zcvf $BACKUP_DIR/website-$website.$NOW.tar.gz $website
  fi
done

### Backup vhosts
tar -zcvf $BACKUP_DIR/vhost.$(hostname -s).$NOW.tar.gz $VHOST_DIR

### Backup every SQL database
DBS="$($MYSQL -u $MUSER -h $MHOST -p$MPASS -Bse 'show databases')"
for db in $DBS
  do
    FILE=$BACKUP_DIR/mysql-$db.$NOW.gz
     $MYSQLDUMP -u $MUSER -h $MHOST -p$MPASS $db | $GZIP > $FILE
done

### Dump backup using RSYNC
status=0
rsync -e "ssh -p $REMOTE_PORT" -avzp $BACKUP_DIR $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR || status=$?
echo $status

### SEND MAIL & REMOVE TMP
if ((status != 0)); then
  echo "!! ALERT !! WEB/SQL Backup $HOSTNAME FAILED" | mail -s "!! ALERT !! WEB/SQL Backup $HOSTNAME FAILED" $MAIL_TO
  else
  ls $BACKUP_DIR |  mail -s "WEB/SQL Backup $HOSTNAME SUCCEDED" $MAIL_TO 
  rm $BACKUP_DIR -Rf
fi
