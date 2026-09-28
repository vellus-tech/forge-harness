"""Ingestão diária das validações dos validadores embarcados na zona bronze do lake."""
from pyspark.sql import SparkSession

BRONZE_PATH = "s3://bilhetagem-lake-prd/bronze/validacoes/"

spark = SparkSession.builder.appName("ingest-validacoes").getOrCreate()
df = spark.read.json("s3://bilhetagem-landing-prd/validadores/")

(
    df.write
    .partitionBy("cartao_id")
    .mode("overwrite").parquet(BRONZE_PATH)
)
