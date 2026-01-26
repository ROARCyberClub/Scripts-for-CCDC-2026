#!/bin/bash

WEBROOT="/var/www/html" #Location of website
BACKUP="/opt/web_backup"

if [ ! -d "$BACKUP" ]; then
    echo "Creating Backup"
    mkdir -p $BACKUP
    cp -r $WEBROOT/* $BACKUP/
fi

echo "Monitoring web files for defacement..."

while true; do
    DIFF=$(diff -r $WEBROOT $BACKUP)

    if [ "$DIFF" != "" ]; then
        echo "Defacement detected at $(date)" | tee -a /var/log/defacement.log
        
        # Restore
        rsync -a --delete $BACKUP/ $WEBROOT/
        echo "[+] Website restored."

    fi

    sleep 10
done
