df.write.partitionBy("user_id").parquet("s3://lake/raw/eventos/")
