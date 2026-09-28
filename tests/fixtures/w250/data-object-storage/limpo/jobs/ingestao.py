df.write.mode("append").parquet("s3://lake/raw/vendas/")
spark.sql("MERGE INTO silver.vendas t USING atualizacoes s ON t.id = s.id WHEN MATCHED THEN UPDATE SET *")
grafico.overwrite(draw_area)
df.write.partitionBy("dt").parquet("s3://lake/raw/eventos/")
