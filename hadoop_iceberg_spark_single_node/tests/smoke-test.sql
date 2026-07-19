CREATE NAMESPACE IF NOT EXISTS spark_catalog.compose_smoke;

DROP TABLE IF EXISTS spark_catalog.compose_smoke.iceberg_test;

CREATE TABLE spark_catalog.compose_smoke.iceberg_test (
  id BIGINT,
  message STRING,
  created_at TIMESTAMP
)
USING iceberg;

INSERT INTO spark_catalog.compose_smoke.iceberg_test
VALUES (1, 'docker compose works', current_timestamp());

SELECT *
FROM spark_catalog.compose_smoke.iceberg_test;

SELECT snapshot_id, committed_at, operation
FROM spark_catalog.compose_smoke.iceberg_test.snapshots
ORDER BY committed_at DESC;
