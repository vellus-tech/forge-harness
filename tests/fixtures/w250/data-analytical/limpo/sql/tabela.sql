CREATE TABLE vendas (id bigint, dt date) USING DELTA CLUSTER BY (dt);
