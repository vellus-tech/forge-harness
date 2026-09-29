# Contexto de armazenamento — bilhetagem

O bucket `bilhetagem-exports-prd` guarda os arquivos diários de conciliação entregues a adquirentes e integradores (terceiros). O bucket `bilhetagem-lake-prd` guarda o lake medallion (bronze, silver, gold) e só é acessado de dentro da VPC. O bucket de comprovantes serve PDFs ao app do próprio produto. A ingestão grava cerca de 40 milhões de validações por dia, de cerca de 3 milhões de cartões distintos.
