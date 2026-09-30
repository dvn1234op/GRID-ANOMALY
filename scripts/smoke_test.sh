#!/bin/bash
set -e

echo "Waiting for namenode to exit safemode..."
docker-compose -f docker/docker-compose.yml exec -T namenode bash -c 'until hdfs dfsadmin -safemode wait; do echo waiting for safemode; sleep 2; done'

echo "=== Testing HDFS ==="
docker-compose -f docker/docker-compose.yml exec -T client hdfs dfs -mkdir -p /test
docker-compose -f docker/docker-compose.yml exec -T client hdfs dfs -touchz /test/hello.txt
docker-compose -f docker/docker-compose.yml exec -T client hdfs dfs -ls /test

echo "=== Testing Pig ==="
docker-compose -f docker/docker-compose.yml exec -T client bash -c 'echo "A = LOAD '\''/test/hello.txt'\'' USING PigStorage('\'','\''); DUMP A;" > /opt/project/pig/test.pig'
docker-compose -f docker/docker-compose.yml exec -T client pig -x mapreduce /opt/project/pig/test.pig

echo "Waiting for HiveServer2..."
docker-compose -f docker/docker-compose.yml exec -T hive-server bash -c 'while ! nc -z localhost 10000; do sleep 5; done'

echo "=== Testing Hive ==="
docker-compose -f docker/docker-compose.yml exec -T hive-server bash -c 'echo "CREATE TABLE IF NOT EXISTS test_table (id INT, name STRING); INSERT INTO test_table VALUES (1, '\''hello'\''); SELECT * FROM test_table;" > /tmp/test.hql'
docker-compose -f docker/docker-compose.yml exec -T hive-server /opt/hive/bin/beeline -u jdbc:hive2://localhost:10000 -n hive -p hive -f /tmp/test.hql

echo "=== Testing PySpark ==="
docker-compose -f docker/docker-compose.yml exec -T client bash -c 'cat << "PY" > /opt/project/spark/test.py
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName("SmokeTest").enableHiveSupport().getOrCreate()
df = spark.sql("SELECT * FROM test_table")
df.show()
PY'
docker-compose -f docker/docker-compose.yml exec -T client spark-submit /opt/project/spark/test.py

echo "=== SMOKE TEST SUCCESSFUL ==="
