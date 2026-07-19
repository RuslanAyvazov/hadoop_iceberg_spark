CREATE NAMESPACE IF NOT EXISTS spark_catalog.compose_smoke;

DROP TABLE IF EXISTS spark_catalog.compose_smoke.iceberg_test;

CREATE TABLE spark_catalog.compose_smoke.iceberg_test (
  id BIGINT,
  message STRING,
  created_at TIMESTAMP
)
USING iceberg;

INSERT INTO spark_catalog.compose_smoke.iceberg_test
SELECT id, concat('distributed row ', CAST(id AS STRING)), current_timestamp()
FROM range(1, 13);

SELECT COUNT(*) AS row_count, MIN(id) AS min_id, MAX(id) AS max_id
FROM spark_catalog.compose_smoke.iceberg_test;

SELECT snapshot_id, committed_at, operation
FROM spark_catalog.compose_smoke.iceberg_test.snapshots
ORDER BY committed_at DESC;

SET spark.master;
SET spark.submit.deployMode;
SET spark.executor.instances;

