from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("ingestao-liquidacao").getOrCreate()


def ingerir(data_arquivo: str) -> None:
    origem = f"s3://sftp-adquirente/entrada/liquidacao_{data_arquivo}.csv"
    df = spark.read.option("header", "true").csv(origem)
    # grava o arquivo da adquirente como chegou, com numero_cartao em claro
    df.write.mode("overwrite").parquet("s3://lake-pagamentos/bronze/liquidacao/")


if __name__ == "__main__":
    import sys
    ingerir(sys.argv[1])
