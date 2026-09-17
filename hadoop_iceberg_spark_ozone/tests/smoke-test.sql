CREATE NAMESPACE IF NOT EXISTS ozone.demo;

DROP TABLE IF EXISTS ozone.demo.events;

CREATE TABLE ozone.demo.events (
    id BIGINT,
    message STRING,
    created_at TIMESTAMP
)
USING iceberg;

INSERT INTO ozone.demo.events
VALUES
    (1, 'Spark writes Iceberg metadata and Parquet files to Ozone', current_timestamp()),
    (2, 'The same table is readable through JDBC', current_timestamp());

SELECT * FROM ozone.demo.events ORDER BY id;

SELECT COUNT(*) AS ozone_row_count FROM ozone.demo.events;

SELECT snapshot_id, operation
FROM ozone.demo.events.snapshots
ORDER BY committed_at DESC;
