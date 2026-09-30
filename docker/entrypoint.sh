#!/bin/bash
set -e

ROLE=$1

if [ "$ROLE" = "namenode" ]; then
    if [ ! -d "/tmp/hadoop-root/dfs/name" ]; then
        echo "Formatting namenode..."
        hdfs namenode -format -force -nonInteractive
    fi
    exec hdfs namenode
elif [ "$ROLE" = "datanode" ]; then
    exec hdfs datanode
elif [ "$ROLE" = "hive-metastore" ]; then
    while ! nc -z postgres 5432; do sleep 2; done
    if ! schematool -dbType postgres -info; then
        schematool -dbType postgres -initSchema
    fi
    exec hive --service metastore
elif [ "$ROLE" = "hive-server2" ]; then
    exec hive --service hiveserver2
elif [ "$ROLE" = "client" ]; then
    tail -f /dev/null
else
    exec "$@"
fi
