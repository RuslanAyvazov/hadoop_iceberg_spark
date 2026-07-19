export JAVA_HOME=/opt/java/openjdk
export HADOOP_HOME=/opt/hadoop
export HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop
export HADOOP_LOG_DIR=/opt/hadoop/logs
export HADOOP_PID_DIR=/tmp/hadoop-pids

export HDFS_NAMENODE_OPTS="-Xms256m -Xmx512m ${HDFS_NAMENODE_OPTS:-}"
export HDFS_DATANODE_OPTS="-Xms128m -Xmx256m ${HDFS_DATANODE_OPTS:-}"
export HDFS_SECONDARYNAMENODE_OPTS="-Xms128m -Xmx256m ${HDFS_SECONDARYNAMENODE_OPTS:-}"

export HADOOP_OPTS="--add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.lang.reflect=ALL-UNNAMED --add-opens=java.base/java.io=ALL-UNNAMED --add-opens=java.base/java.net=ALL-UNNAMED --add-opens=java.base/java.nio=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED --add-opens=java.base/java.util.concurrent=ALL-UNNAMED --add-opens=java.base/sun.nio.ch=ALL-UNNAMED --add-opens=java.base/sun.security.action=ALL-UNNAMED"

