# RASCUNHO — não aplicado na árvore (agente consultivo, não tem Write/Edit).
# Quem aplica é o agente de engenharia ou o task-coder.
#
# Duas correções sobre jobs/ingestao_liquidacao.py:
#   1. O-13 (bronze mutável): overwrite -> append-only, particionado por data/lote de ingestão.
#   2. T-03 (bronze com dado de cartão): numero_cartao não pode continuar em claro. Como o
#      arquivo da adquirente provavelmente precisa ser preservado como chegou (reconciliação e
#      disputa), a correção aplicada aqui é criptografia de campo com chave do CDE (fora do KMS
#      do bucket), não tokenização de borda — ver outputs/resposta.md para a decisão pendente
#      entre as duas alternativas de T-03.
#
# NEEDS CLARIFICATION: nome/mecanismo real do serviço de criptografia de campo do CDE
# (client-side encryption com a chave aws_kms_key.chd_liquidacao, ou um serviço de tokenização
# dedicado). O trecho abaixo assume uma função `cifrar_campo_chd(coluna, kms_key_id)` que já
# existe ou precisa ser criada pelo time de plataforma/segurança — não é deste agente decidir a
# implementação de criptografia de campo, só apontar que ela precisa existir antes da escrita.

from pyspark.sql import SparkSession
from pyspark.sql.functions import current_date, date_format

spark = SparkSession.builder.appName("ingestao-liquidacao").getOrCreate()

CHD_KMS_KEY_ID = "alias/chd-liquidacao"  # aws_kms_key.chd_liquidacao — fora do KMS do bucket


def ingerir(data_arquivo: str) -> None:
    origem = f"s3://sftp-adquirente/entrada/liquidacao_{data_arquivo}.csv"
    df = spark.read.option("header", "true").csv(origem)

    # T-03: numero_cartao não sai em claro para o bronze. Criptografia de campo com chave do CDE
    # (distinta da chave SSE-KMS do bucket) — placeholder da função real, a criar/localizar com
    # o time de plataforma/segurança.
    df = df.withColumn(
        "numero_cartao",
        cifrar_campo_chd("numero_cartao", CHD_KMS_KEY_ID),  # noqa: F821 — placeholder, ver acima
    )

    # O-13: append-only na zona bronze, particionado por dia de ingestão (não por numero_cartao
    # nem por outro identificador de alta cardinalidade — O-14).
    df = df.withColumn("dt_ingestao", date_format(current_date(), "yyyy-MM-dd"))
    (
        df.write.mode("append")
        .partitionBy("dt_ingestao")
        .parquet("s3://lake-pagamentos/bronze/liquidacao/")
    )


if __name__ == "__main__":
    import sys

    ingerir(sys.argv[1])
