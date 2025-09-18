#!/bin/bash
docker-compose down
docker volume rm p2p-payments_db_data
./restore-db.sh
docker-compose build --no-cache && docker-compose up -d
docker-compose build --no-cache backend
docker-compose build --no-cache frontend
docker ps -a
echo "All containers have been built up, persistent data have been removed and db has been restored from the most recent backup dump"
