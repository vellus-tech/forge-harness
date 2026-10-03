# Runbook de deploy — validacao → stg (dry-run)

Gerado sem acesso a cluster, GHCR ou GitHub. Nenhum comando abaixo foi executado de fato; é a sequência exata que eu rodaria, com os valores resolvidos a partir deste repositório (`work/`).

## Contexto resolvido

- **Módulo:** `validacao` (chart em `platform/helm/validacao`, versão `0.3.0`, `appVersion: 0.3.0`).
- **Onda entregue:** onda 3 — TASK-31 a TASK-34 (validação offline com lista de bloqueio), conforme `docs/product/modules/validacao/PROGRESS-TRACKING.md`.
- **SHA de origem:** `f39d51ac600ed9841abe33eb16f8585d46397cdc` (`HEAD` de `main`, commit `feat(validacao): onda 3 — validação offline com lista de bloqueio (TASK-31..TASK-34)`).
- **Ambiente alvo:** `stg`, values em `platform/helm/validacao/values-stg.yaml` (`replicaCount: 2`, `env.AMBIENTE: stg`, `image.repository: ghcr.io/validacao`, `image.digest` vazio — a preencher pelo passo 2).
- **Namespace:** `stg` (convenção observada em `.forge/rules/architecture/mtls-internal-services.md`, onde o namespace segue o nome do ambiente; a política Kyverno de `.forge/rules/architecture/docker-multi-arch.md` só é `Enforce` em `prd-*`, então `stg` não é bloqueada por essa policy).
- **Registry:** `ghcr.io/validacao` (fixo em todos os `values-*.yaml`; tag `latest` é proibida por `.forge/rules/conventions/docker-naming.md` — a imagem é referenciada só por digest).
- **Plataformas exigidas:** `linux/amd64` + `linux/arm64` em manifest list OCI única (`.forge/rules/architecture/docker-multi-arch.md`, ancorado em ADR-0013).
- **Zero tolerância a CVE:** `.trivyignore` não tem exceções vigentes — qualquer CVE com fix disponível bloqueia a imagem.
- **Smoke test canário:** `platform/helm/validacao/smoke-tests/stg.sh` (POST em `/v1/validacoes` com QR `TESTE-STG-0001`).

## Passo a passo (comandos exatos)

### 1. Build multi-arch + supply-chain (via GitHub Actions, workflow_dispatch)

```bash
gh workflow run build-image.yml \
  -f module=validacao \
  -f sha=f39d51ac600ed9841abe33eb16f8585d46397cdc \
  -f push_registry=true
```

O workflow (`.github/workflows/build-image.yml`) builda `linux/amd64,linux/arm64` + Trivy + Cosign + Syft (placeholder no fixture — passo real de CI, não simulável aqui).

### 2. Aguardar o run e capturar o digest publicado

```bash
gh run watch --exit-status
gh run view --log | grep -i digest
# esperado: ghcr.io/validacao@sha256:<digest-real>
```

### 3. Verificar assinatura Cosign do digest antes de promover

```bash
cosign verify \
  --certificate-identity-regexp "https://github.com/.*/.github/workflows/.*" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/validacao@sha256:<digest-real>
```

### 4. Scan Trivy do digest publicado (zero tolerância, `.trivyignore` sem exceções)

```bash
trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed \
  ghcr.io/validacao@sha256:<digest-real>
```

### 5. Confirmar manifest list multi-arch (amd64 + arm64)

```bash
docker buildx imagetools inspect ghcr.io/validacao@sha256:<digest-real>
# esperado: Platform linux/amd64 e Platform linux/arm64 na manifest list
```

### 6. Resolver o digest no values de stg e renderizar o manifesto (dry-run local)

```bash
helm template validacao platform/helm/validacao \
  -f platform/helm/validacao/values-stg.yaml \
  --set image.digest=sha256:<digest-real> \
  --namespace stg
```

### 7. Dry-run server-side contra o cluster de stg

```bash
helm upgrade --install validacao platform/helm/validacao \
  -f platform/helm/validacao/values-stg.yaml \
  --set image.digest=sha256:<digest-real> \
  --namespace stg \
  --dry-run=server
```

### 8. Aplicar de fato

```bash
helm upgrade --install validacao platform/helm/validacao \
  -f platform/helm/validacao/values-stg.yaml \
  --set image.digest=sha256:<digest-real> \
  --namespace stg \
  --atomic --timeout 5m
```

### 9. Verificar rollout

```bash
kubectl -n stg rollout status deployment/validacao --timeout=120s
```

### 10. Smoke test canário

```bash
bash platform/helm/validacao/smoke-tests/stg.sh stg
```

### 11. Registrar no deploy log do módulo

Atualizar `docs/product/modules/validacao/PROGRESS-TRACKING.md`, tabela "Deploy log", com nova linha:

```
| 2026-09-26 <hora> | stg | validacao | 3 | f39d51a | sha256:<digest-real> | ✅ |
```

## Fora de escopo nesta máquina (não executado)

`gh`, `docker`, `trivy`, `cosign`, `helm`, `kubectl`, `git push` — todos os comandos acima são a sequência que eu rodaria; nada foi de fato disparado. Não há acesso a cluster, GHCR ou GitHub nesta execução.
