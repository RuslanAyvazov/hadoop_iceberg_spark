FROM eclipse-temurin:17-jre-jammy

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG SPARK_VERSION=3.5.4
ARG ICEBERG_VERSION=1.6.1
ARG OZONE_VERSION=2.2.1
ARG HADOOP_COMPAT_VERSION=3.4.2

ENV JAVA_HOME=/opt/java/openjdk \
    SPARK_HOME=/opt/spark \
    SPARK_CONF_DIR=/opt/spark/conf \
    PATH=/opt/java/openjdk/bin:/opt/spark/bin:/opt/spark/sbin:$PATH

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       ca-certificates curl netcat-openbsd procps python3 tini \
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
    download /tmp/spark.tgz \
      "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz" \
      "https://repo.huaweicloud.com/apache/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz"; \
    tar -xzf /tmp/spark.tgz -C /opt; \
    mv "/opt/spark-${SPARK_VERSION}-bin-hadoop3" "${SPARK_HOME}"; \
    rm -f /tmp/spark.tgz

RUN set -eux; \
    download_jar() { \
      local group_path="$1" artifact="$2" version="$3"; \
      curl -4 -fL --retry 8 --retry-all-errors --retry-delay 2 --connect-timeout 30 --speed-time 60 --speed-limit 1024 \
        "https://repo.maven.apache.org/maven2/${group_path}/${artifact}/${version}/${artifact}-${version}.jar" \
        -o "${SPARK_HOME}/jars/${artifact}-${version}.jar"; \
    }; \
    download_jar org/apache/iceberg iceberg-spark-runtime-3.5_2.12 "${ICEBERG_VERSION}"; \
    download_jar org/apache/ozone ozone-filesystem-hadoop3 "${OZONE_VERSION}"; \
    download_jar org/apache/hadoop hadoop-common "${HADOOP_COMPAT_VERSION}"

ENV JUPYTER_HOME=/opt/jupyter \
    PATH=/opt/jupyter/bin:/opt/java/openjdk/bin:/opt/spark/bin:/opt/spark/sbin:$PATH

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       python3-pip python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv "${JUPYTER_HOME}" \
    && "${JUPYTER_HOME}/bin/pip" install --no-cache-dir \
       "jupyterlab==4.6.3" \
       "nbconvert==7.17.1" \
       "apache-toree==0.5.0" \
    && "${JUPYTER_HOME}/bin/jupyter" toree install \
       --sys-prefix \
       --spark_home="${SPARK_HOME}" \
       --interpreters=Scala \
       --spark_opts='--master=local[*]'

COPY conf/spark/ ${SPARK_HOME}/conf/
COPY --chown=bigdata:bigdata scripts/entrypoint.sh scripts/healthcheck.sh scripts/start-jupyter.sh scripts/healthcheck-jupyter.sh /opt/lab/bin/
COPY --chown=bigdata:bigdata examples/ /opt/lab/examples/
COPY --chown=bigdata:bigdata notebooks/ /opt/lab/notebooks/
COPY --chown=bigdata:bigdata tests/ /opt/lab/tests/

RUN mkdir -p /data/spark /opt/lab/bin /home/bigdata/work "${SPARK_HOME}/logs" \
    && chmod +x /opt/lab/bin/*.sh \
    && chown -R bigdata:bigdata /data/spark /opt/lab /home/bigdata/work "${SPARK_HOME}/logs"

USER bigdata
WORKDIR /home/bigdata

EXPOSE 10000 4040 8888

ENTRYPOINT ["/usr/bin/tini", "--", "/opt/lab/bin/entrypoint.sh"]
