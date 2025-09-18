#!/bin/bash
set -e

# Configuration
DB_NAME="p2p_core"
DB_USER="p2papp"
BACKUP_DIR="./backups"
CONTAINER_NAME1="db"  # Adjust if your postgres service is named differently

# If no file passed, pick the latest backup
if [ $# -lt 1 ]; then
  echo "No backup file specified. Auto-detecting most recent backup..."
  BACKUP_FILE=$(ls -t ${BACKUP_DIR}/${DB_NAME}_*.{dump,sql.gz,sql} 2>/dev/null | head -n 1)
  if [ -z "$BACKUP_FILE" ]; then
    echo "Error: No backup files found in $BACKUP_DIR."
    exit 1
  fi
else
  BACKUP_FILE="$1"
fi

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Error: Backup file '$BACKUP_FILE' not found."
  exit 1
fi

echo "Using backup file: $BACKUP_FILE"

# Terminate active connections and drop DB
echo "Terminating active connections to $DB_NAME..."
docker-compose exec -T $CONTAINER_NAME1 psql -U $DB_USER -d postgres -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${DB_NAME}' AND pid <> pg_backend_pid();"

echo "Dropping and recreating database '$DB_NAME'..."
docker-compose exec -T $CONTAINER_NAME1 psql -U $DB_USER -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME;"
docker-compose exec -T $CONTAINER_NAME1 psql -U $DB_USER -d postgres -c "CREATE DATABASE $DB_NAME;"

# Restore depending on file extension
if [[ "$BACKUP_FILE" == *.dump ]]; then
  echo "Restoring from custom-format dump..."
  docker-compose exec -T $CONTAINER_NAME1 pg_restore -U $DB_USER -d $DB_NAME < "$BACKUP_FILE"
elif [[ "$BACKUP_FILE" == *.sql.gz ]]; then
  echo "Restoring from compressed SQL file..."
  gunzip -c "$BACKUP_FILE" | docker-compose exec -T $CONTAINER_NAME1 psql -U $DB_USER -d $DB_NAME
elif [[ "$BACKUP_FILE" == *.sql ]]; then
  echo "Restoring from plain SQL file..."
  docker-compose exec -T $CONTAINER_NAME1 psql -U $DB_USER -d $DB_NAME < "$BACKUP_FILE"
else
  echo "Unknown file type for restore: $BACKUP_FILE"
  exit 1
fi

echo "✅ Restore completed successfully from $BACKUP_FILE"
