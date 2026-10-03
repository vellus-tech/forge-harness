# Transcript — eval `revisao-armazenamento-comprovantes-pre-pr` (with_skill, run-1)

Papel assumido: agente `data-object-storage` (definição lida de `template/.forge/agents/data/data-object-storage.md`), com a skill `data-object-storage-practices` (lida de `template/.forge/skills/data-object-storage-practices/`, somente leitura).

## Bootstrap (verificação de diretório)

```
cd <worktree-do-eval> && pwd && git branch --show-current
```
→ `pwd` = `<worktree-do-eval>`, branch = `chore/evals-skills-agentes`. Confere com o esperado.

## Passo 0 — instante inicial e diretório do caso

```
date +%s > .../with_skill/run-1/.t0
mkdir -p .../with_skill/run-1/work
```

## Passo 1 — fixture

```
bash .forge/evals/agents/data-object-storage/fixtures/revisao-armazenamento-comprovantes-pre-pr/setup.sh .../with_skill/run-1/work
```

O script roda `node bin/forge.mjs init --target <work> -y --no-plugin`, copia o overlay do caso e remove `.forge/skills`, `.forge/agents`, `.claude/skills`, `.claude/agents` e `plugin/` do alvo (para não contaminar o baseline com o artefato sob avaliação), depois `git init` + commit inicial do estado da fixture. Confirmado que `work/` ficou com `infra/storage/comprovantes.tf`, `src/comprovantes/{gravar.ts,emitir-link.ts}` e `deploy/k8s/minio.yaml`.

## Passo 2 — leitura do artefato do agente

Lido `template/.forge/agents/data/data-object-storage.md` por completo: frontmatter (tools sem Write/Edit/Agent, skill `data-object-storage-practices`, hook de guarda no Bash), missão, escopo, protocolo de 6 passos, checklist, catálogo de antipatterns bloqueados, regra de integração (H-02 (a) para entrega a terceiro) e critério de devolução ao orquestrador.

## Passo 3 — leitura dos três arquivos do escopo do pedido

`cat` de `infra/storage/comprovantes.tf`, `src/comprovantes/gravar.ts`, `src/comprovantes/emitir-link.ts`, `deploy/k8s/minio.yaml`. Notado no comentário de `emitir-link.ts`: "Link usado pelo app e enviado por e-mail ao parceiro de conciliação no fechamento diário" — confirma o que o pedido do usuário já dizia.

## Passo 4 — leitura da skill (protocolo, passo 1 do agente: skill como contexto)

Lido `SKILL.md` da `data-object-storage-practices` (escopo, protocolo próprio, decisão H-02 (a) por extenso) e `references/antipatterns.md` (catálogo O-01 a O-14 + T-03, cinco campos por entrada, rótulos de detecção).

## Passo 5 — rules, ADRs e baseline do projeto (protocolo, passo 1)

```
ls work/.forge/rules/data        → data-cache.md, data-config-sql.md, data-governance.md,
                                    data-transactional-nosql.md, schema-evolution.md
ls work/.forge/rules/domain      → audit-immutability.md, money-as-cents.md, nbr-5891-rounding.md
ls work/.forge/rules/architecture → inclui internal-grpc-communication.md, pii-pci-classification.md
find work/.forge/product/current/adr → só .gitkeep (nenhum ADR aceito no baseline da fixture)
```

Lido `data-governance.md` (isolamento multi-tenant por store — não se aplica a bucket de objeto único por transação) e `conflict-handling.md` (ordem de precedência e o que torna um conflito bloqueante). Nenhuma rule ou ADR do projeto diverge da recomendação da skill para este caso (bucket privado, KMS com Bucket Key, ciclo de vida, URL pré-assinada restrita) — **sem `CONFLITO`** a devolver.

## Passo 6 — dado sensível (protocolo, passo 3)

```
find work -iname data-classification.json   → nenhum arquivo
bash .forge/scripts/check-data-governance.sh --path infra/storage/comprovantes.tf
  → FAIL data-governance/universo-vazio (0 arquivos examinados: .tf não está no universo do checker)
bash .forge/scripts/check-data-governance.sh --path src/comprovantes
  → OK data-governance/universo — 2 arquivos examinados; OK data-governance (0 .md, 2 código, no divergence)
bash .forge/scripts/check-data-governance.sh --path deploy/k8s
  → FAIL data-governance/universo-vazio (0 arquivos examinados: .yaml não está no universo do checker)
```

Pelo protocolo: as duas linhas `FAIL .../universo-vazio` significam "não verificado por este checker" (ele só lê `.go/.kt/.ts/.rego/.py/.md`), não aprovação nem achado — o Terraform e o YAML seguem só com o detector da skill e a revisão manual. `src/comprovantes` deu `OK` sem divergência — não há `data-classification.json` no projeto e o comprovante (PDF de transação) não é PAN/PII de cartão, então T-03 não se aplica a este caso (é dado de comprovante, não CHD).

## Passo 7 — varredura (protocolo, passo 4)

```
bash template/.forge/skills/data-object-storage-practices/scripts/scan.sh \
  --root infra/storage/comprovantes.tf --root src/comprovantes --root deploy/k8s
```
(rodado a partir de `work/`, apontando para o `scan.sh` do artefato sob avaliação em `template/.forge/`, já que o `setup.sh` removeu `.forge/skills` do projeto de trabalho para não contaminar o baseline.)

Saída:
```
FOUND O-01 [alto] 4 ocorrência(s) — infra/storage/comprovantes.tf:7,8,9,10 (as quatro chaves do Block Public Access em false)
FOUND O-02 [aviso] 1 ocorrência(s) — src/comprovantes/emitir-link.ts:9 (expiresIn: 60 * 60 * 24 * 7)
FOUND O-08 [aviso] 1 ocorrência(s) — infra/storage/comprovantes.tf:24 (aws:kms sem bucket_key_enabled)
FOUND O-11 [alto] 1 ocorrência(s) — deploy/k8s/minio.yaml:18 (image: quay.io/minio/minio:latest)
OK O-13, OK O-14
ARQUIVOS-VARRIDOS 4
```

## Passo 8 — julgamento (protocolo, passo 5)

- **O-01**: confirmado por leitura — as quatro chaves realmente estão `false` no recurso `aws_s3_bucket_public_access_block`, sem `Condition` que mitigasse. Achado real, não falso positivo.
- **O-08**: confirmado — o bloco `aws_s3_bucket_server_side_encryption_configuration` usa `aws:kms` sem `bucket_key_enabled` em lugar nenhum do arquivo.
- **O-02**: confirmado, e agravado pelo contexto do pedido do usuário — o mesmo link de 7 dias é enviado por e-mail ao parceiro de conciliação, o que é entrega a terceiro fora das restrições da decisão H-02 (a) (não é só expiração longa; é também canal/emissão fora do endpoint REST autenticado exigido). Julguei como achado de severidade alta no contexto, não só "aviso" genérico do scanner, porque envolve entrega a terceiro.
- **O-11**: confirmado — é a imagem comunitária arquivada. A correção não é trocar `latest` por uma tag fixa (isso não resolve a falta de patch de segurança); é plano de migração ou suporte comercial, como o catálogo prescreve.
- **Ciclo de vida (O-03/O-04)**: o scanner não detecta ausência de regra (só lê o que está escrito); constatado por leitura manual do `.tf` que não existe `aws_s3_bucket_lifecycle_configuration` nenhum, apesar de o bucket ter versionamento ligado — condição exata do O-04 (versões não correntes acumulando) e abertura para O-03 (multipart órfão).
- `gravar.ts`: lido, sem antipattern do catálogo; é o PUT do PDF, sem geração de URL nem escrita destrutiva em bronze/raw — fora do escopo dos achados.

## Passo 9 — resposta

Escrita a revisão completa com id do catálogo, `arquivo:linha` e correção pronta (trecho de Terraform/TypeScript) para cada achado, em `outputs/review.md`. Nenhum arquivo do projeto (`work/`) foi criado ou alterado — verificado com `git status --porcelain` (saída vazia) ao final. Não houve consulta ao context7 porque nenhuma recomendação dependia de confirmar versão corrente de um SDK/produto além do que já está fixado no catálogo da skill (S3 Block Public Access, SSE-KMS Bucket Key, ciclo de vida S3 e status do repositório MinIO são conhecimento coberto e datado na própria skill, com marca de evidência).

## Passo 10 — devolução ao orquestrador

Não se aplica devolução parcial: o pedido inteiro (bucket, URL pré-assinada, KMS, MinIO no k8s) é escopo de `data-object-storage`; nada aqui cruzou para tabela/partição (`data-analytical`), banco mutável ou fila/tópico de notificação ao parceiro (o pedido já usa REST/URL pré-assinada, que é escopo deste agente).

## Encerramento

```
t0=$(cat .../with_skill/run-1/.t0); t1=$(date +%s)
.../with_skill/run-1/timing.json escrito com duration_ms = (t1-t0)*1000
```

`work/` não passou de 20 MB (fixture pequena, sem `node_modules`/binários) — não foi apagado.
