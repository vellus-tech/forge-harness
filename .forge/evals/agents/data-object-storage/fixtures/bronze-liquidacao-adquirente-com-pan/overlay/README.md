# lake-pagamentos

Lake da operação de pagamentos em `s3://lake-pagamentos/` com zonas `bronze/`, `silver/` e `gold/`. A fonte `liquidacao` recebe diariamente o arquivo de liquidação da adquirente (CSV com `numero_cartao` completo, `valor_centavos`, `data_venda`, `nsu`) e o job `jobs/ingestao_liquidacao.py` grava no bronze.
