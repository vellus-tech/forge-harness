# Revisão de object storage — exports, lake e comprovantes

Revisão do especialista `data-object-storage` sobre `infra/terraform/` (buckets `bilhetagem-exports-prd` e `bilhetagem-lake-prd`), `src/app/receiptLink.ts`, `src/exports/partnerDelivery.ts` e os jobs de ingestão do lake em `jobs/`, com o contexto de `docs/contexto-storage.md` (exports serve adquirentes e integradores como terceiros, lake é bronze/silver/gold restrito à VPC, comprovantes servem o app do próprio produto, ingestão grava ~40 milhões de validações/dia de ~3 milhões de cartões distintos). Escopo é o nível de objeto (bucket, prefixo, ciclo de vida, criptografia, acesso público, URL pré-assinada); formato e particionamento de tabela silver/gold ficam com o especialista analítico. Nenhum arquivo foi corrigido — só diagnóstico.

## Achados que bloqueiam o PR

### 1. `partnerDelivery.ts:10` — URL pré-assinada de 7 dias entregue a parceiro por e-mail (O-02, reprovado por H-02 (a))
`getSignedUrl(..., { expiresIn: 604800 })` gera uma URL válida por 7 dias e o corpo do e-mail a entrega diretamente ao adquirente/integrador. A regra do dono (H-02 (a)) só admite URL pré-assinada a terceiro com HTTPS, um único objeto nomeado, expiração em minutos, emissão por endpoint REST autenticado que autentica o parceiro, log de emissão e bucket privado. Este trecho viola três das cinco restrições ao mesmo tempo: expiração em dias (não minutos), emissão por job/e-mail em vez de endpoint REST que autentica o parceiro no momento da entrega, e nenhum log de emissão visível no código. Uma URL pré-assinada é um bearer token — qualquer pessoa que intercepte o e-mail ou o encaminhe tem acesso ao arquivo de conciliação por uma semana, sem nova autenticação. Corrigir para: endpoint REST autenticado (`GET /v1/parceiros/:id/conciliacao/:data`) que verifica a identidade do parceiro, gera a URL com `expiresIn` de poucos minutos e grava um log de emissão (quem, quando, qual chave); o e-mail passa a notificar que o arquivo está disponível, sem carregar o link de download diretamente.

### 2. `infra/terraform/storage.tf:14` — `block_public_policy = false` no bucket de exports (O-01, severidade alta)
O bucket `bilhetagem-exports-prd`, que guarda arquivo de conciliação para terceiros, tem `block_public_acls`, `ignore_public_acls` e `restrict_public_buckets` em `true`, mas `block_public_policy = false`. Isso deixa uma porta aberta: qualquer policy de bucket futura com `Principal: "*"` passaria a valer, mesmo que hoje não exista uma. É inconsistente com o restante da configuração (as outras três chaves já bloqueiam) e sem motivo aparente no código — nenhuma policy atual precisa dessa exceção. Corrigir para `true`; se algum caso legítimo exigir policy pública no futuro, ela deve ir num bucket separado de conteúdo estático atrás de CDN, nunca no bucket de dado de negócio.

## Achados de aviso (não bloqueiam, mas custam caro ou fogem do padrão)

### 3. `jobs/ingest_validacoes.py:12` — bronze sobrescrito a cada carga (O-13)
`df.write.partitionBy("cartao_id").mode("overwrite").parquet(BRONZE_PATH)` apaga e regrava a zona bronze inteira a cada execução. Bronze é o registro imutável do que chegou dos validadores; sem histórico append-only não há como reprocessar um dia específico nem auditar o que realmente foi recebido — se a ingestão de hoje tiver um bug, o dia anterior já foi substituído. Corrigir para escrita append-only, particionada por data de ingestão (`dt=AAAA-MM-DD/`), com uma política de bucket que negue `DeleteObject` no prefixo bronze (exceto no prefixo que eventualmente precisar de eliminação por retenção legal — ver item 5).

### 4. `jobs/ingest_validacoes.py:11` — partição por `cartao_id` no bronze (O-14, agravado pelo volume)
`partitionBy("cartao_id")` cria um diretório por cartão. Com ~3 milhões de cartões distintos e ~40 milhões de validações/dia (média de ~13 registros por cartão/dia), isso gera milhões de diretórios com poucos arquivos pequenos cada — listagem, abertura e metadado de objeto passam a dominar o custo, e a consulta fica lenta (O-12 como consequência colateral). Corrigir para partição por data de ingestão (`dt=AAAA-MM-DD/`) no bruto; se houver necessidade de acesso eficiente por cartão nas camadas de consumo, isso é clustering/liquid clustering na tabela silver/gold — decisão do especialista analítico, não do bronze.

### 5. `infra/terraform/storage.tf:23` — SSE-KMS sem Bucket Key no bucket de exports (O-08)
A chave `aws_kms_key.exports` está configurada com `sse_algorithm = "aws:kms"` mas sem `bucket_key_enabled = true`. Sem Bucket Key, cada objeto gravado ou lido chama o KMS individualmente — custo e risco de throttling crescem linearmente com o volume de conciliações diárias. Adicionar `bucket_key_enabled = true` no mesmo bloco (reduz as chamadas ao KMS em até 99%, sem mudar o nível de proteção).

## Pontos que o scanner não detecta e pedem decisão humana

Estes não aparecem no `scan.sh` porque exigem leitura do desenho completo, não de uma linha isolada — o relatório os inclui porque o protocolo pede uma linha por regra, inclusive as que dependem de revisão.

- **Nenhuma regra de ciclo de vida em nenhum dos dois buckets** (`storage.tf`, `lake.tf`): não há `aws_s3_bucket_lifecycle_configuration` em nenhum dos dois arquivos. Isso deixa três antipatterns em aberto: multipart incompleto nunca abortado (O-03), versões não correntes do bucket de exports acumulando para sempre já que o versionamento está ligado (O-04), e nenhuma transição para classe fria dos arquivos de conciliação antigos. Recomendo lifecycle com `AbortIncompleteMultipartUpload` (7 dias) e `NoncurrentVersionExpiration` alinhada à retenção contratual com os parceiros.
- **Bucket do lake sem Block Public Access explícito** (`lake.tf`): o acesso hoje é restrito por policy com `Condition` de VPC endpoint (o que é correto e por isso o scanner não aponta O-01), mas não há um recurso `aws_s3_bucket_public_access_block` explícito para esse bucket — hoje protegido pelo padrão de conta desde 2023, mas vale declarar explicitamente por defesa em profundidade, já que é o bucket que guarda o lake inteiro.
- **Sem inventário nem log de acesso configurado em nenhum bucket**: nem `aws_s3_bucket_logging` nem S3 Inventory aparecem no Terraform. Para o bucket de exports (terceiro lê arquivo de conciliação) e para o bronze com dado de cartão (item abaixo), log de acesso é a evidência de auditoria — vale abrir junto com o PR de storage ou registrar como débito explícito.
- **Classificação de dado de cartão não verificada (T-03) — pergunta em aberto, não achado fechado**: `docs/contexto-storage.md` descreve "validações... de cerca de 3 milhões de cartões distintos" chegando via `bilhetagem-landing-prd/validadores/` e caindo direto no bronze como JSON bruto (`ingest_validacoes.py:7-12`), sem nenhuma tokenização visível entre a leitura do landing e a escrita no bronze. Não dá para afirmar, só com os arquivos revisados, se `cartao_id` é um identificador de cartão de transporte (fora do escopo CDE) ou um PAN de cartão bancário usado em validação EMV open loop (dado de titular de cartão, sujeito a PCI DSS 3.5.1) — o projeto também não tem uma instância de `data-classification.json` preenchida (só o schema em `.forge/schemas/data-classification.schema.json`), então o campo está sem classificação declarada. Antes de abrir o PR, recomendo confirmar com quem é dono do domínio de pagamentos: se for PAN, a ingestão precisa tokenizar na borda (antes do bronze) ou cifrar em nível de campo/arquivo com chave fora do lake, porque SSE-KMS do bucket sozinho não atende PCI DSS 3.5.1.2 em mídia não removível; se for identificador de cartão de transporte sem dado de titular de cartão, este ponto fica resolvido e sai do escopo do PCI DSS.

## Limpo — regras verificadas sem achado

- **O-11 (MinIO comunitário arquivado)**: nenhuma imagem `minio/minio` no IaC revisado — `OK` no scan.
- **`receiptLink.ts` — URL pré-assinada de 5 minutos para o app do próprio produto**: `expiresIn: 300` é aceitável porque é cliente próprio (app/web do produto), não terceiro; a regra de minutos para terceiro (H-02 (a)) nem se aplica aqui, mas o valor já está dentro da faixa recomendada mesmo para cliente próprio.
- **Bucket de exports com versionamento habilitado** (`storage.tf:29-34`): protege contra sobrescrita acidental do arquivo de conciliação; falta só a expiração de versões não correntes (ver ponto de ciclo de vida acima).
- **Bucket do lake restrito por VPC endpoint com `Condition`** (`lake.tf:17-30`): o `Principal: "*"` na policy vem acompanhado de `Condition.StringEquals."aws:SourceVpce"`, então não é leitura anônima — o scanner corretamente não aponta O-01 aqui, e a revisão confirma que a condição é efetiva (chave de condição reconhecida pela AWS para VPC endpoint).
- **`silver_validacoes.py` — `overwrite` na tabela silver**: não é antipattern; o detector O-13 só olha escrita destrutiva em linha que cita `raw`/`bronze`, e reconstruir a silver inteira por dedupe é prática legítima nessa camada (escopo do especialista analítico, formato Delta já em uso).
- **`token.ts` (JWT de refresh)**: fora de escopo deste especialista — não é URL pré-assinada nem chave de storage; o detector O-02 explicitamente exclui linhas com `jwt`/`jsonwebtoken`.

## Tabela-resumo (uma linha por regra, id + arquivo:linha)

| Regra | Severidade | Status | Local |
|---|---|---|---|
| O-01 | alto | FOUND | `infra/terraform/storage.tf:14` |
| O-02 (com H-02 (a): reprovado para terceiro) | aviso no scan / reprovado no julgamento | FOUND | `src/exports/partnerDelivery.ts:10` |
| O-04 (sem detector estático) | aviso | revisão — sem `NoncurrentVersionExpiration` em nenhum bucket | `infra/terraform/storage.tf`, `infra/terraform/lake.tf` |
| O-03 (sem detector estático) | aviso | revisão — sem `AbortIncompleteMultipartUpload` em nenhum bucket | `infra/terraform/storage.tf`, `infra/terraform/lake.tf` |
| O-08 | aviso | FOUND | `infra/terraform/storage.tf:23` |
| O-11 | alto | OK | — |
| O-13 | aviso | FOUND | `jobs/ingest_validacoes.py:12` |
| O-14 | aviso | FOUND | `jobs/ingest_validacoes.py:11` |
| T-03 (sem detector estático) | não verificado | revisão — classificação de `cartao_id` pendente | `jobs/ingest_validacoes.py:7-12`, `.forge/schemas/data-classification.schema.json` |

## Recomendação de ordem para o PR

Os itens 1 e 2 (URL de 7 dias a terceiro e `block_public_policy = false`) são os únicos que, pela regra do dono e pelo catálogo, valem bloquear o PR — resolver antes de abrir. Os itens 3 a 5 (bronze mutável, partição de alta cardinalidade, KMS sem Bucket Key) são dívida que cresce com o volume atual (40 milhões de validações/dia) e vale corrigir no mesmo PR já que o código está sendo tocado, mas não impedem o merge. Os pontos de revisão (ciclo de vida ausente, Block Public Access explícito no lake, logging/inventário, classificação de `cartao_id`) pedem uma decisão de dono antes de fechar — em especial a classificação de `cartao_id`, porque muda o desenho da ingestão se for PAN.
