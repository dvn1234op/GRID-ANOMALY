#!/bin/bash
set -e

MODE=${1:-"--subset"}
LOG_FILE="logs/hdfs_load.log"
mkdir -p logs

echo "Starting HDFS load in $MODE mode..." | tee -a $LOG_FILE

# Clear /raw in HDFS if it exists
docker-compose -f docker/docker-compose.yml exec -T client hdfs dfs -rm -r -f /raw || true
docker-compose -f docker/docker-compose.yml exec -T client hdfs dfs -mkdir -p /raw/halfhourly
docker-compose -f docker/docker-compose.yml exec -T client hdfs dfs -mkdir -p /raw/metadata

# Which blocks to load?
if [ "$MODE" = "--full" ]; then
    BLOCKS_DIR="data/halfhourly_dataset"
else
    BLOCKS_DIR="data/subset_halfhourly_dataset"
fi

echo "Counting rows in $BLOCKS_DIR..." | tee -a $LOG_FILE
cat $BLOCKS_DIR/*.csv | wc -l | awk '{print "Total rows in halfhourly blocks: " $1}' | tee -a $LOG_FILE
wc -l data/*.csv | tee -a $LOG_FILE

# Load files to HDFS
echo "Loading blocks to HDFS /raw/halfhourly..." | tee -a $LOG_FILE
START_TIME=$(date +%s)
docker-compose -f docker/docker-compose.yml exec -T client bash -c 'hdfs dfs -put /opt/project/'"$BLOCKS_DIR"'/*.csv /raw/halfhourly/'
END_TIME=$(date +%s)
echo "Time to load blocks: $(($END_TIME - $START_TIME)) seconds" | tee -a $LOG_FILE

echo "Loading metadata to HDFS /raw/metadata..." | tee -a $LOG_FILE
START_TIME=$(date +%s)
docker-compose -f docker/docker-compose.yml exec -T client bash -c 'hdfs dfs -put /opt/project/data/*.csv /raw/metadata/'
END_TIME=$(date +%s)
echo "Time to load metadata: $(($END_TIME - $START_TIME)) seconds" | tee -a $LOG_FILE

echo "HDFS Load Complete." | tee -a $LOG_FILE
docker-compose -f docker/docker-compose.yml exec -T client hdfs dfs -ls -R /raw
