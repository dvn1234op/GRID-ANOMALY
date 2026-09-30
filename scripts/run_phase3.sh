#!/bin/bash
set -e

echo "=== Phase 3: Hive Warehouse ==="
mkdir -p results
mkdir -p logs

BEELINE_CMD="docker-compose -f docker/docker-compose.yml exec -T hive-server beeline -u jdbc:hive2://localhost:10000 -n root"

echo "1. Creating Tables & Loading ORC..."
cat hive/warehouse.hql | $BEELINE_CMD 2>&1 | tee logs/hive_warehouse.log

echo "2. Running Validations..."
cat hive/validation.hql | $BEELINE_CMD --outputformat=csv2 > results/validation_output.csv 2> logs/hive_validation.log

echo "3. Extracting Features (Window Functions)..."
cat hive/features.hql | $BEELINE_CMD 2>&1 | tee logs/hive_features.log

echo "4. Running Reporting Queries..."
cat hive/reporting.hql | $BEELINE_CMD --outputformat=csv2 > results/reporting_output.csv 2> logs/hive_reporting.log

echo "Done! Hive Phase complete. Check results/ and logs/."
