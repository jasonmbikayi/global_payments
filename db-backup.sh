#!/bin/bash
set -e

# Configuration
DB_NAME="p2p_core"
DB_USER="p2papp"
BACKUP_DIR="./backups/"
CONTAINER_NAME1="db"  # Adjust based on the docker-compose service name
#CONTAINER_NAME2="p2p_postgres"  # if run from inside db container using <docker-compose exec> method
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Method 1: SQL dump (recommended)
echo "Creating SQL backup..."
docker-compose exec $CONTAINER_NAME1 pg_dump -U $DB_USER -F c $DB_NAME > $BACKUP_DIR/${DB_NAME}_${DATE}.dump

# Method 2: SQL plain text backup
echo "Creating plain SQL backup..."
docker-compose exec $CONTAINER_NAME1 pg_dump -U $DB_USER $DB_NAME > $BACKUP_DIR/${DB_NAME}_${DATE}.sql

# Compress the plain SQL backup
gzip $BACKUP_DIR/${DB_NAME}_${DATE}.sql

echo "Backup completed:"
ls -la $BACKUP_DIR/${DB_NAME}_${DATE}.*

# Clean up old backups (keep last 7 days)
find $BACKUP_DIR -name "${DB_NAME}_*.dump" -mtime +7 -delete
find $BACKUP_DIR -name "${DB_NAME}_*.sql.gz" -mtime +7 -delete
echo "Old backups cleaned up."