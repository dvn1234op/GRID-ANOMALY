#!/bin/bash
set -e

MODE=${1:-"--subset"}

echo "=========================================="
echo " Running Grid Anomaly Pipeline ($MODE)    "
echo "=========================================="

echo "[1/4] Loading Data to HDFS..."
./scripts/load_hdfs.sh $MODE

echo "[2/4] Running Pig ETL Phase..."
docker-compose -f docker/docker-compose.yml exec -T -e PIG_OPTS="-Xmx4g" client pig -x local /opt/project/pig/etl.pig
./scripts/log_counts.sh

echo "[3/4] Running Hive Warehouse Phase..."
./scripts/run_phase3.sh

echo "[4/4] Running Spark MLlib Forecasting Phase..."
./scripts/run_phase4.sh $MODE

echo "[5/5] Running Anomaly Detection Phase..."
docker-compose -f docker/docker-compose.yml exec -T client /opt/spark/bin/spark-shell --driver-memory 4g -i /opt/project/spark/anomaly_prep.scala > logs/spark_anomaly_prep.log 2>&1
docker cp $(docker-compose -f docker/docker-compose.yml ps -q client):/opt/project/results/. ./results/
python3 scripts/phase5_anomalies.py

echo "Pipeline executed successfully up to Phase 5."
