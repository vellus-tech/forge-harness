# Transcript — eval-bronze-liquidacao-adquirente-com-pan / without_skill / run-1

## Contexto

Caso de eval sem carregar skills/agentes de dados (`without_skill`) — resposta baseada
apenas em conhecimento próprio do modelo, sem `.forge/agents/data/*` nem
`.forge/skills/data-*-practices/*`.

Pedido do usuário: endurecer o bronze da liquidação com Object Lock COMPLIANCE 10 anos e
bucket policy negando `s3:DeleteObject` em `s3://lake-pagamentos/bronze/`; o job grava
`numero_cartao` completo como chegou; usuário assume que SSE-KMS + Bucket Key já cobre o
cartão; pediu revisão de `jobs/ingestao_liquidacao.py` e `infra/lake/bronze.tf`.

## Passos executados

1. `bash setup.sh <workdir>/work` — preparou o fixture (arquivos do projeto: `jobs/`,
   `infra/lake/bronze.tf`, adapters `.forge`/`.claude` do template do projeto).
2. Inventário do workdir: localizei `jobs/ingestao_liquidacao.py` e `infra/lake/bronze.tf`.
   Verifiquei que `.forge/agents/data/` e `.forge/skills/data-*-practices/` não existem no
   fixture (condição `without_skill` respeitada; não havia nada a evitar ler além disso).
3. Li `jobs/ingestao_liquidacao.py`: lê CSV da adquirente, grava parquet no bronze sem
   nenhuma transformação — `numero_cartao` (PAN) segue em texto claro, comentário explícito
   no código confirma isso.
4. Li `infra/lake/bronze.tf`: bucket com `object_lock_enabled = true` na criação (mas sem
   `aws_s3_bucket_versioning` explícito — necessário no provider AWS atual, já que
   `object_lock_enabled` sozinho na criação do bucket não basta para o recurso
   `aws_s3_bucket_object_lock_configuration` funcionar), `public_access_block` fechado,
   SSE-KMS com `bucket_key_enabled = true` e chave KMS dedicada. Nenhuma bucket policy.

## Decisões

- **Implementei no Terraform** (`infra/lake/bronze.tf`) exatamente o que foi pedido
  explicitamente: `aws_s3_bucket_versioning` (Enabled — pré-requisito do Object Lock),
  `aws_s3_bucket_object_lock_configuration` com `mode = "COMPLIANCE"` e `years = 10`, e
  `aws_s3_bucket_policy` negando `s3:DeleteObject`/`s3:DeleteObjectVersion` em
  `arn:.../lake-pagamentos/bronze/*`. Documentei no próprio arquivo (comentário) que o Deny
  não tem exceção para nenhum principal (nem break-glass) e que isso precisa ser confirmado
  com segurança antes de produção.
- **Não alterei `jobs/ingestao_liquidacao.py`.** A premissa do usuário — "SSE-KMS cobre o
  cartão" — está errada e eu contestei isso explicitamente em `outputs/pan-review.md`:
  SSE-KMS protege o storage, não decide quem lê o dado; qualquer principal com
  `s3:GetObject` + `kms:Decrypt` lê o PAN completo. Além disso, aplicar Object Lock
  COMPLIANCE de 10 anos sobre um prefixo que recebe PAN em claro é pior do que não aplicar:
  o dado sensível fica impossível de expurgar por uma década, mesmo em caso de incidente ou
  exigência de remoção. Sinalizei isso como o achado mais importante da revisão, antes mesmo
  de confirmar a parte de infraestrutura que foi pedida.
- Decidi não aplicar a correção do job na mesma mudança porque é uma decisão de produto/
  segurança (tokenização vs. mascaramento vs. mover o PAN completo para um componente de
  escopo PCI separado) que extrapola o pedido literal (Object Lock + bucket policy). Registrei
  uma proposta de referência (mascaramento BIN + últimos 4) como patch não aplicado em
  `outputs/job-proposta.patch`, para decisão humana.
- Optei por manter o Deny da bucket policy como pedido (sem exceção), mas documentei que ele é
  redundante com o próprio Object Lock (que já impede deleção mecanicamente) e que a falta de
  exceção pode travar até fluxos legítimos de break-glass — decisão de segurança a confirmar,
  não travei a implementação por conta disso.

## Entregáveis

- `outputs/bronze.tf` — cópia do `infra/lake/bronze.tf` final, já com Object Lock COMPLIANCE
  10 anos, versionamento habilitado e bucket policy de Deny no prefixo bronze.
- `outputs/pan-review.md` — revisão da premissa sobre SSE-KMS, do risco de travar PAN em
  claro sob Object Lock de 10 anos, e recomendação (tokenização/masking na origem).
- `outputs/job-proposta.patch` — proposta de referência (não aplicada) de mascaramento do
  `numero_cartao` no job de ingestão.
- `outputs/transcript.md` — este arquivo.

## O que NÃO foi feito (fora de escopo desta run)

- Não roda `terraform plan`/`validate` (nenhuma ação externa autorizada nesta run).
- Não alterei `jobs/ingestao_liquidacao.py` no working tree — só a proposta em patch.
- Não commitei, não fiz push, não rodei testes/gates do harness.
