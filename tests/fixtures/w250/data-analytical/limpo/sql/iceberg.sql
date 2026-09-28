CREATE TABLE lake.silver.pedidos (id bigint, ts timestamp) USING iceberg PARTITIONED BY (days(ts));
