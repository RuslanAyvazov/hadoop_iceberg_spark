FROM eclipse-temurin:17-jre-jammy

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG HADOOP_VERSION=3.3.6
ARG SPARK_VERSION=3.5.4
ARG HIVE_VERSION=3.1.3
ARG ICEBERG_VERSION=1.6.1
ARG POSTGRES_JDBC_VERSION=42.7.4

ENV JAVA_HOME=/opt/java/openjdk \
    HADOOP_HOME=/opt/hadoop \
    HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop \
    HADOOP_LOG_DIR=/opt/hadoop/logs \
    HADOOP_PID_DIR=/tmp/hadoop-pids \
    HIVE_HOME=/opt/hive-metastore \
    SPARK_HOME=/opt/spark \
    SPARK_CONF_DIR=/opt/spark/conf \
    PATH=/opt/java/openjdk/bin:/opt/hadoop/bin:/opt/hadoop/sbin:/opt/hive-metastore/bin:/opt/spark/bin:/opt/spark/sbin:$PATH

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       ca-certificates curl gettext-base netcat-openbsd procps python3 tini \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid 10001 bigdata \
    && useradd --uid 10001 --gid 10001 --create-home --shell /bin/bash bigdata

RUN set -eux; \
    download() { \
      local output="$1"; shift; \
      for url in "$@"; do \
        rm -f "${output}.part"; \
        if curl -4 -fL --retry 8 --retry-all-errors --retry-delay 2 --connect-timeout 30 --speed-time 90 --speed-limit 1024 -o "${output}.part" "${url}"; then \
          mv "${output}.part" "${output}"; \
          return 0; \
        fi; \
      done; \
      return 1; \
    }; \
    download /tmp/hadoop.tar.gz \
      "https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz" \
      "https://repo.huaweicloud.com/apache/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz"; \
    tar -xzf /tmp/hadoop.tar.gz -C /opt; \
    mv "/opt/hadoop-${HADOOP_VERSION}" "${HADOOP_HOME}"; \
    rm -f /tmp/hadoop.tar.gz

RUN set -eux; \
    download() { \
      local output="$1"; shift; \
      for url in "$@"; do \
        rm -f "${output}.part"; \
        if curl -4 -fL --retry 8 --retry-all-errors --retry-delay 2 --connect-timeout 30 --speed-time 90 --speed-limit 1024 -o "${output}.part" "${url}"; then \
          mv "${output}.part" "${output}"; \
          return 0; \
        fi; \
      done; \
      return 1; \
    }; \
    download /tmp/spark.tgz \
      "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz" \
      "https://repo.huaweicloud.com/apache/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz"; \
    tar -xzf /tmp/spark.tgz -C /opt; \
    mv "/opt/spark-${SPARK_VERSION}-bin-hadoop3" "${SPARK_HOME}"; \
    rm -f /tmp/spark.tgz

RUN set -eux; \
    download() { \
      local output="$1"; shift; \
      for url in "$@"; do \
        rm -f "${output}.part"; \
        if curl -4 -fL --retry 8 --retry-all-errors --retry-delay 2 --connect-timeout 30 --speed-time 90 --speed-limit 1024 -o "${output}.part" "${url}"; then \
          mv "${output}.part" "${output}"; \
          return 0; \
        fi; \
      done; \
      return 1; \
    }; \
    download /tmp/hive.tar.gz \
      "https://archive.apache.org/dist/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz" \
      "https://repo.huaweicloud.com/apache/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz"; \
    tar -xzf /tmp/hive.tar.gz -C /opt; \
    mv "/opt/apache-hive-${HIVE_VERSION}-bin" "${HIVE_HOME}"; \
    rm -f /tmp/hive.tar.gz

RUN rm -f "${HIVE_HOME}"/lib/guava-*.jar "${HIVE_HOME}"/lib/postgresql-*.jar \
    && cp "${HADOOP_HOME}/share/hadoop/common/lib/guava-27.0-jre.jar" "${HIVE_HOME}/lib/" \
    && curl -4 -fL --retry 8 --retry-all-errors --retry-delay 2 --connect-timeout 30 --speed-time 60 --speed-limit 1024 \
       "https://repo.maven.apache.org/maven2/org/postgresql/postgresql/${POSTGRES_JDBC_VERSION}/postgresql-${POSTGRES_JDBC_VERSION}.jar" \
       -o "${HIVE_HOME}/lib/postgresql-${POSTGRES_JDBC_VERSION}.jar" \
    && mkdir -p "${SPARK_HOME}/extra-jars" \
    && curl -4 -fL --retry 8 --retry-all-errors --retry-delay 2 --connect-timeout 30 --speed-time 60 --speed-limit 1024 \
       "https://repo.maven.apache.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/${ICEBERG_VERSION}/iceberg-spark-runtime-3.5_2.12-${ICEBERG_VERSION}.jar" \
       -o "${SPARK_HOME}/extra-jars/iceberg-spark-runtime-3.5_2.12-${ICEBERG_VERSION}.jar" \
    && curl -4 -fL --retry 8 --retry-all-errors --retry-delay 2 --connect-timeout 30 --speed-time 60 --speed-limit 1024 \
       "https://repo.maven.apache.org/maven2/org/apache/iceberg/iceberg-hive-runtime/${ICEBERG_VERSION}/iceberg-hive-runtime-${ICEBERG_VERSION}.jar" \
       -o "${SPARK_HOME}/extra-jars/iceberg-hive-runtime-${ICEBERG_VERSION}.jar"

COPY conf/hadoop/ ${HADOOP_HOME}/etc/hadoop/
COPY conf/spark/ ${SPARK_HOME}/conf/
COPY --chown=bigdata:bigdata conf/hive/hive-site.xml.template /opt/bigdata/templates/hive-site.xml.template
COPY --chown=bigdata:bigdata scripts/entrypoint.sh scripts/healthcheck.sh /opt/bigdata/bin/
COPY --chown=bigdata:bigdata tests/ /opt/bigdata/tests/

RUN mkdir -p \
      /data/hdfs/namenode \
      /data/hdfs/datanode \
      /data/hdfs/namesecondary \
      /data/yarn/local \
      /data/yarn/logs \
      /data/hadoop-tmp \
      /opt/bigdata/templates \
      /opt/bigdata/logs \
      "${HADOOP_LOG_DIR}" \
      "${HIVE_HOME}/logs" \
      "${SPARK_HOME}/logs" \
      "${HADOOP_PID_DIR}" \
    && chmod +x /opt/bigdata/bin/*.sh \
    && chown -R bigdata:bigdata \
      /data \
      /opt/bigdata \
      "${HADOOP_LOG_DIR}" \
      "${HIVE_HOME}/conf" \
      "${HIVE_HOME}/logs" \
      "${SPARK_HOME}/logs" \
      "${HADOOP_PID_DIR}"

USER bigdata
WORKDIR /home/bigdata

EXPOSE 4040 8032 8042 8088 9083 9820 9864 9866 9867 9870 10000 18080

ENTRYPOINT ["/usr/bin/tini", "--", "/opt/bigdata/bin/entrypoint.sh"]
