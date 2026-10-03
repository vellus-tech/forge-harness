"""Reconstrói a tabela silver de validações a partir do bronze (dedupe por id_validacao)."""
from pyspark.sql import SparkSession

SILVER_PATH = "s3://bilhetagem-lake-prd/silver/validacoes/"

spark = SparkSession.builder.appName("silver-validacoes").getOrCreate()
df = spark.read.parquet("s3://bilhetagem-lake-prd/bronze/validacoes/").dropDuplicates(["id_validacao"])
df.write.format("delta").mode("overwrite").save(SILVER_PATH)
