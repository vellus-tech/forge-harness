# Revisão de object storage — bilhetagem

Escopo: `infra/terraform/storage.tf` e `infra/terraform/lake.tf` (buckets `bilhetagem-exports-prd` e `bilhetagem-lake-prd`), `src/exports/partnerDelivery.ts`, `src/app/receiptLink.ts`, `jobs/ingest_validacoes.py` e `jobs/silver_validacoes.py`. Contexto: `docs/contexto-storage.md` (exports vai para adquirentes/integradores terceiros, lake é medallion bronze/silver/gold só via VPC, comprovantes servem o app; ingestão de ~40 milhões de validações/dia de ~3 milhões de cartões distintos).

## Achados críticos

### 1. Job de ingestão bronze apaga o histórico todo dia (`jobs/ingest_validacoes.py`)
`mode("overwrite")` grava em `s3://bilhetagem-lake-prd/bronze/validacoes/` sem nenhuma partição por data de ingestão. Cada execução diária sobrescreve o path inteiro, ou seja, o bronze só contém o resultado da última carga — o histórico de dias anteriores é destruído toda madrugada. Como a silver é reconstruída a partir do bronze (`silver_validacoes.py` lê o bronze inteiro com `dropDuplicates`), a perda se propaga: silver e, por consequência, gold nunca vão conter mais que o último dia carregado. Isso é uma perda de dados silenciosa (não falha, só sobrescreve) num pipeline que alimenta reconciliação para terceiros.
Por quê importa: para um lake que precisa reter histórico (conciliação, auditoria), overwrite sem partição de data é o erro mais caro possível — não aparece em teste funcional do dia, só quando alguém precisar de dado de duas semanas atrás e ele não existir mais.
Sugestão de direção (sem aplicar agora): particionar bronze por data de ingestão (ex.: `dt=YYYY-MM-DD/`) e trocar `overwrite` do path inteiro por `overwrite` só da partição do dia (`insertInto` com partition overwrite dinâmico, ou grava explicitamente em `bronze/validacoes/dt=.../`).

### 2. `cartao_id` como partition key da bronze é cardinalidade alta demais para object storage (`jobs/ingest_validacoes.py`)
`partitionBy("cartao_id")` com ~3 milhões de cartões distintos por dia gera até 3 milhões de "diretórios" (prefixos) no S3, cada um com poucos arquivos pequenos — o clássico small-file problem em data lake. Isso encarece list/GET no S3 (cobrado por request), deixa o writer do Spark lento (task por partição), e torna qualquer leitura futura da bronze (inclusive a da silver) dolorosa em performance e custo. Partição por chave de alta cardinalidade é um antipadrão conhecido de object storage para lakes.
Sugestão de direção: particionar por data (baixa cardinalidade, alinhada ao padrão de leitura incremental) e deixar `cartao_id` como coluna normal dentro do parquet/delta, não como partição.

### 3. Presigned URL de 7 dias entregue por e-mail a terceiros (`src/exports/partnerDelivery.ts`)
`deliverReconciliation` gera uma signed URL com `expiresIn: 604800` (7 dias) para o arquivo de conciliação e manda por e-mail ao parceiro. Um link válido por uma semana, distribuído por um canal que o operador não controla (e-mail pode ser encaminhado, ficar em caixa comprometida, cair em backup de terceiro), é uma janela de exposição desnecessária para um arquivo que contém dado de conciliação financeira. Contraste com `receiptLink.ts`, que usa 300s (5 min) para um caso de uso interno autenticado — o padrão correto já existe no próprio repositório, só não foi aplicado ao fluxo de terceiros.
Sugestão de direção: reduzir a validade ao necessário para o parceiro baixar uma vez (ex.: algumas horas), e considerar não embutir a URL pronta no e-mail — mandar um link para um endpoint autenticado que gera a signed URL sob demanda, com log de quem baixou.

### 4. Bucket do lake sem `aws_s3_bucket_public_access_block` explícito (`infra/terraform/lake.tf`)
O bucket `bilhetagem-lake-prd` depende só da bucket policy (condição `aws:SourceVpce`) para restringir acesso — não existe o recurso `aws_s3_bucket_public_access_block` que o bucket de exports tem. Bucket policy restringe quem pode chamar a API via essa policy específica, mas não bloqueia, por exemplo, uma ACL pública adicionada depois por engano ou por outra policy/role com permissão de `s3:PutBucketPolicy`. É a mesma proteção que o time já aplicou no bucket de exports — falta replicar no lake, que guarda o dado bruto de todas as validações.

### 5. Bucket do lake sem versionamento (`infra/terraform/lake.tf`)
`bilhetagem-lake-prd` não tem `aws_s3_bucket_versioning`, diferente do bucket de exports que tem `Enabled`. Sem versionamento, um `overwrite` indevido (como o achado #1) ou uma exclusão acidental não tem como ser revertida — não há como recuperar a versão anterior do objeto. Para um lake que é fonte de conciliação e auditoria, essa é uma rede de segurança que falta.

## Achados médios

### 6. `block_public_policy = false` no bucket de exports (`infra/terraform/storage.tf`)
O `aws_s3_bucket_public_access_block` do bucket de exports bloqueia ACLs públicas (`block_public_acls = true`, `ignore_public_acls = true`) mas explicitamente permite policies públicas (`block_public_policy = false`). Para um bucket que guarda arquivo de conciliação entregue a terceiros só via signed URL — nunca deveria precisar de bucket policy pública — não há razão aparente para deixar essa porta aberta. Parece herança de um template padrão sem revisão específica para este bucket.
Sugestão de direção: mudar para `true`, a menos que exista um caso de uso documentado que dependa de uma bucket policy pública (nenhum aparece no código atual).

### 7. Nenhuma lifecycle policy nos dois buckets
Nem `storage.tf` nem `lake.tf` definem `aws_s3_bucket_lifecycle_configuration`. Para o bucket de exports, arquivos de conciliação diária para terceiros provavelmente têm uma janela de retenção definida (contratual/fiscal) — sem lifecycle, eles ficam para sempre em Standard, sem transição para storage classes mais baratas nem expiração. Para o lake, a um ritmo de 40 milhões de linhas/dia, a ausência de lifecycle (ou de uma política de compactação/tiering entre bronze e gold) tende a virar custo de armazenamento crescente sem controle, agravado pelo achado #2 (excesso de arquivos pequenos).
Sugestão de direção: definir regras de expiração/transição de acordo com a política de retenção de cada bucket (a definir com o time de dados/jurídico, já que a revisão não encontrou a política de retenção documentada).

## Achados menores / observações

### 8. `bucket_key_enabled` só configurado no lake, não nos exports
`lake.tf` usa `bucket_key_enabled = true` na configuração de SSE-KMS (reduz custo de chamadas ao KMS). `storage.tf` não define o mesmo campo para o bucket de exports, que também usa `aws:kms`. Não é um problema de segurança, é uma oportunidade de custo menor deixada de fora — bom padronizar entre os dois.

### 9. `receiptLink.ts` e `token.ts` — sem achados relevantes de storage
`receiptLink.ts` usa signed URL de 5 minutos para um endpoint autenticado do próprio produto — dentro do esperado. `token.ts` assina JWT de refresh com RS256 e não interage com object storage; fora do escopo desta revisão.

## Resumo priorizado

| # | Achado | Severidade | Arquivo |
|---|---|---|---|
| 1 | Overwrite diário apaga histórico da bronze | Crítico | jobs/ingest_validacoes.py |
| 2 | `cartao_id` como partition key (alta cardinalidade) | Crítico | jobs/ingest_validacoes.py |
| 3 | Presigned URL de 7 dias para terceiro por e-mail | Crítico | src/exports/partnerDelivery.ts |
| 4 | Lake sem public access block explícito | Crítico | infra/terraform/lake.tf |
| 5 | Lake sem versionamento | Crítico | infra/terraform/lake.tf |
| 6 | `block_public_policy = false` nos exports | Médio | infra/terraform/storage.tf |
| 7 | Sem lifecycle policy em nenhum dos buckets | Médio | infra/terraform/storage.tf, lake.tf |
| 8 | `bucket_key_enabled` ausente nos exports | Menor | infra/terraform/storage.tf |

Nenhum arquivo foi corrigido nesta revisão, conforme solicitado — apenas diagnóstico.
