FROM bde2020/hadoop-namenode:2.0.0-hadoop3.2.1-java8

COPY pig-0.17.0.tar.gz /opt/
RUN sed -i s/deb.debian.org/archive.debian.org/g /etc/apt/sources.list && \
    sed -i s/security.debian.org/archive.debian.org/g /etc/apt/sources.list && \
    sed -i s/stretch-updates/stretch/g /etc/apt/sources.list && \
    apt-get update -o Acquire::Check-Valid-Until=false && apt-get install -y python3 && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    tar -xzf /opt/pig-0.17.0.tar.gz -C /opt/ && \
    ln -s /opt/pig-0.17.0 /opt/pig && \
    rm /opt/pig-0.17.0.tar.gz

COPY spark-3.5.8-bin-hadoop3.tgz /opt/
RUN tar -xzf /opt/spark-3.5.8-bin-hadoop3.tgz -C /opt/ && \
    ln -s /opt/spark-3.5.8-bin-hadoop3 /opt/spark && \
    rm /opt/spark-3.5.8-bin-hadoop3.tgz

ENV PIG_HOME=/opt/pig
ENV SPARK_HOME=/opt/spark
ENV PATH=$PATH:$PIG_HOME/bin:$SPARK_HOME/bin

CMD ["tail", "-f", "/dev/null"]
