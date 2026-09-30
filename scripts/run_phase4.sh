#!/bin/bash
set -e

echo "=== Phase 4: Spark MLlib Forecasting ==="
mkdir -p results
mkdir -p logs

MODE=${1:-"--subset"}
echo "Running forecasting script in Spark ($MODE)..."
docker-compose -f docker/docker-compose.yml exec -T -e MODE=$MODE client /opt/spark/bin/spark-shell --driver-memory 8g --executor-memory 8g -i /opt/project/spark/forecasting.scala > logs/spark_forecasting.log 2>&1

echo "Extracting CSV outputs from container..."
docker cp $(docker-compose -f docker/docker-compose.yml ps -q client):/opt/project/results/. ./results/

# Move and rename Spark CSV output parts for easier viewing
for dir in forecast_metrics_by_acorn forecast_metrics_by_tariff forecast_metrics_by_hour; do
  if [ -d "results/$dir" ]; then
    mv results/$dir/*.csv results/${dir}.csv
    rm -rf results/$dir
  fi
done

echo "Done! Phase 4 complete. Check results/forecast_metrics_*.csv"
