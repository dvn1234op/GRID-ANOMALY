#!/bin/bash
echo "=== Phase 2 ETL Counts ==="
echo "Cleaned records in /clean:"
docker-compose -f docker/docker-compose.yml exec -T client bash -c 'hdfs dfs -cat /clean/part* 2>/dev/null | wc -l' || echo "0"

echo "Rejected records (NULL or Empty energy):"
docker-compose -f docker/docker-compose.yml exec -T client bash -c 'hdfs dfs -cat /rejects/null/part* 2>/dev/null | wc -l' || echo "0"

echo "Rejected records (Negative energy):"
docker-compose -f docker/docker-compose.yml exec -T client bash -c 'hdfs dfs -cat /rejects/negative/part* 2>/dev/null | wc -l' || echo "0"

echo "Done."
