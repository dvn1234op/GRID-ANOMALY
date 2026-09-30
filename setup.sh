#!/bin/bash
mkdir -p docker/conf data scripts pig hive spark

cat << 'DOCKERFILE' > docker/Dockerfile
FROM eclipse-temurin:8-jdk-focal

ENV HADOOP_VERSION=3.3.6
ENV HIVE_VERSION=3.1.3
ENV PIG_VERSION=0.17.0
ENV SPARK_VERSION=3.3.2

RUN apt-get update && apt-get install -y wget curl netcat procps nano postgresql-client python3 && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt

RUN wget -qO- https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz | tar -xz && \
    ln -s hadoop-${HADOOP_VERSION} hadoop

RUN wget -qO- https://archive.apache.org/dist/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz | tar -xz && \
    ln -s apache-hive-${HIVE_VERSION}-bin hive

RUN wget -qO- https://archive.apache.org/dist/pig/pig-${PIG_VERSION}/pig-${PIG_VERSION}.tar.gz | tar -xz && \
    ln -s pig-${PIG_VERSION} pig

RUN wget -qO- https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz | tar -xz && \
    ln -s spark-${SPARK_VERSION}-bin-hadoop3 spark

RUN wget -q https://jdbc.postgresql.org/download/postgresql-42.2.27.jar -O /opt/hive/lib/postgresql.jar

RUN rm /opt/hive/lib/guava-*.jar && cp /opt/hadoop/share/hadoop/common/lib/guava-*.jar /opt/hive/lib/

ENV JAVA_HOME=/opt/java/openjdk
ENV HADOOP_HOME=/opt/hadoop
ENV HIVE_HOME=/opt/hive
ENV PIG_HOME=/opt/pig
ENV SPARK_HOME=/opt/spark
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$HIVE_HOME/bin:$PIG_HOME/bin:$SPARK_HOME/bin

ENV HDFS_NAMENODE_USER=root
ENV HDFS_DATANODE_USER=root
ENV HDFS_SECONDARYNAMENODE_USER=root
ENV YARN_RESOURCEMANAGER_USER=root
ENV YARN_NODEMANAGER_USER=root

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
DOCKERFILE

cat << 'ENTRYPOINT' > docker/entrypoint.sh
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
ENTRYPOINT

cat << 'CORE_SITE' > docker/conf/core-site.xml
<configuration>
    <property><name>fs.defaultFS</name><value>hdfs://namenode:8020</value></property>
    <property><name>hadoop.proxyuser.root.hosts</name><value>*</value></property>
    <property><name>hadoop.proxyuser.root.groups</name><value>*</value></property>
</configuration>
CORE_SITE

cat << 'HDFS_SITE' > docker/conf/hdfs-site.xml
<configuration>
    <property><name>dfs.replication</name><value>1</value></property>
    <property><name>dfs.namenode.rpc-bind-host</name><value>0.0.0.0</value></property>
    <property><name>dfs.namenode.servicerpc-bind-host</name><value>0.0.0.0</value></property>
    <property><name>dfs.permissions.enabled</name><value>false</value></property>
</configuration>
HDFS_SITE

cat << 'HIVE_SITE' > docker/conf/hive-site.xml
<configuration>
    <property><name>javax.jdo.option.ConnectionURL</name><value>jdbc:postgresql://postgres:5432/metastore</value></property>
    <property><name>javax.jdo.option.ConnectionDriverName</name><value>org.postgresql.Driver</value></property>
    <property><name>javax.jdo.option.ConnectionUserName</name><value>hive</value></property>
    <property><name>javax.jdo.option.ConnectionPassword</name><value>hive</value></property>
    <property><name>hive.metastore.uris</name><value>thrift://hive-metastore:9083</value></property>
    <property><name>hive.server2.enable.doAs</name><value>false</value></property>
</configuration>
HIVE_SITE

cat << 'COMPOSE' > docker/docker-compose.yml
version: '3.8'
services:
  namenode:
    build: .
    command: namenode
    hostname: namenode
    ports: ["9870:9870", "8020:8020"]
    environment: ["HADOOP_HEAPSIZE=512"]
    volumes:
      - ./conf/core-site.xml:/opt/hadoop/etc/hadoop/core-site.xml
      - ./conf/hdfs-site.xml:/opt/hadoop/etc/hadoop/hdfs-site.xml

  datanode:
    build: .
    command: datanode
    depends_on: [namenode]
    environment: ["HADOOP_HEAPSIZE=512"]
    volumes:
      - ./conf/core-site.xml:/opt/hadoop/etc/hadoop/core-site.xml
      - ./conf/hdfs-site.xml:/opt/hadoop/etc/hadoop/hdfs-site.xml

  postgres:
    image: postgres:13
    environment:
      POSTGRES_DB: metastore
      POSTGRES_USER: hive
      POSTGRES_PASSWORD: hive
    ports: ["5432:5432"]

  hive-metastore:
    build: .
    command: hive-metastore
    depends_on: [postgres, namenode, datanode]
    environment: ["HADOOP_HEAPSIZE=512"]
    ports: ["9083:9083"]
    volumes:
      - ./conf/core-site.xml:/opt/hadoop/etc/hadoop/core-site.xml
      - ./conf/hdfs-site.xml:/opt/hadoop/etc/hadoop/hdfs-site.xml
      - ./conf/hive-site.xml:/opt/hive/conf/hive-site.xml

  hive-server2:
    build: .
    command: hive-server2
    depends_on: [hive-metastore]
    environment: ["HADOOP_HEAPSIZE=512"]
    ports: ["10000:10000", "10002:10002"]
    volumes:
      - ./conf/core-site.xml:/opt/hadoop/etc/hadoop/core-site.xml
      - ./conf/hdfs-site.xml:/opt/hadoop/etc/hadoop/hdfs-site.xml
      - ./conf/hive-site.xml:/opt/hive/conf/hive-site.xml

  client:
    build: .
    command: client
    depends_on: [namenode, datanode, hive-metastore, hive-server2]
    volumes:
      - ./conf/core-site.xml:/opt/hadoop/etc/hadoop/core-site.xml
      - ./conf/hdfs-site.xml:/opt/hadoop/etc/hadoop/hdfs-site.xml
      - ./conf/hive-site.xml:/opt/hive/conf/hive-site.xml
      - ./conf/hive-site.xml:/opt/spark/conf/hive-site.xml
      - ../data:/opt/project/data
      - ../scripts:/opt/project/scripts
      - ../pig:/opt/project/pig
      - ../hive:/opt/project/hive
      - ../spark:/opt/project/spark
COMPOSE

cat << 'SMOKE' > scripts/smoke_test.sh
#!/bin/bash
set -e

echo "=== Testing HDFS ==="
docker-compose -f docker/docker-compose.yml exec -T client hdfs dfs -mkdir -p /test
docker-compose -f docker/docker-compose.yml exec -T client hdfs dfs -touchz /test/hello.txt
docker-compose -f docker/docker-compose.yml exec -T client hdfs dfs -ls /test

echo "=== Testing Pig ==="
cat << 'PIG' > pig/test.pig
A = LOAD '/test/hello.txt' USING PigStorage(',');
DUMP A;
PIG
docker-compose -f docker/docker-compose.yml exec -T client pig -x mapreduce /opt/project/pig/test.pig

echo "=== Testing Hive ==="
cat << 'HQL' > hive/test.hql
CREATE TABLE IF NOT EXISTS test_table (id INT, name STRING);
INSERT INTO test_table VALUES (1, 'hello');
SELECT * FROM test_table;
HQL
docker-compose -f docker/docker-compose.yml exec -T client beeline -u jdbc:hive2://hive-server2:10000 -n root -f /opt/project/hive/test.hql

echo "=== Testing PySpark ==="
cat << 'PY' > spark/test.py
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName("SmokeTest").enableHiveSupport().getOrCreate()
df = spark.sql("SELECT * FROM test_table")
df.show()
PY
docker-compose -f docker/docker-compose.yml exec -T client spark-submit /opt/project/spark/test.py

echo "=== SMOKE TEST SUCCESSFUL ==="
SMOKE

chmod +x scripts/smoke_test.sh
