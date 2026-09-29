# Runbook de dry-run — /forge:deploy-wave recarga prd

> Gerado pelo `deploy-orchestrator` em modo dry-run. Nesta sessão não há cluster Kubernetes,
> registry GHCR nem MCP do Atlassian conectados — nenhum comando abaixo foi executado de fato.
> Este arquivo lista os comandos e operações exatos, na ordem, que seriam executados com acesso
> real, com todas as variáveis já resolvidas para este deploy específico.

## Contexto resolvido

| Variável | Valor | Origem |
|---|---|---|
| `MODULO` | `recarga` | argumento do comando |
| `ENV` | `prd` | argumento do comando |
| `SHA` | `21fbd0f` (HEAD de `main`) | `git rev-parse HEAD` |
| `LAST_TAG` (prd) | `deploy-prd-20260910-1430-f922ba7` | `git tag --list "deploy-prd-*"` |
| `LAST_SHA` (prd) | `f922ba7` (onda 3 — Pix) | resolvido de `LAST_TAG` |
| `CHART_PATH` | `platform/helm/recarga` | existe no repo |
| `VALUES_FILE` | `platform/helm/recarga/values-prd.yaml` | existe no repo |
| `NAMESPACE` | `prd` | = `ENV` |
| `REPO_SLUG` | `axis-mobfintech/bilhetagem-core` | `AGENTS.md` (`repo_slug`) |
| `IMAGE_TAG` | `21fbd0f` (7 chars do SHA) | Fase 2 |
| `STRATEGY` | `rolling` | `deployment.strategy` em `values-prd.yaml` |
| `APPROVED_BY` | `Carla Mendes (gerente de plataforma)` | aprovação no CAB de hoje |
| `JIRA_KEY` | `BIL` | `AGENTS.md` (`jira_key`) |

Onda em questão: **onda 4 — recarga via cartão de crédito tokenizado** (TASK-41..TASK-44), já
rodando em `stg` desde 2026-09-22 (tag `deploy-stg-20260922-1610-21fbd0f`) sem incidente, conforme
`docs/product/modules/recarga/PROGRESS-TRACKING.md`.

## Fase 0 — Validação pré-deploy

```bash
[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || { echo "Deploy só do main"; exit 1; }
# resultado esperado: branch atual é "main" → OK

SHA=$(git rev-parse HEAD)
# resultado esperado: 21fbd0f... (commit da onda 4)

CHART_PATH="platform/helm/recarga"
[ -d "$CHART_PATH" ] || { echo "Chart não encontrado: $CHART_PATH"; exit 1; }
# resultado esperado: diretório existe → OK

VALUES_FILE="$CHART_PATH/values-prd.yaml"
[ -f "$VALUES_FILE" ] || { echo "Values não encontrado: $VALUES_FILE"; exit 1; }
# resultado esperado: arquivo existe → OK

NAMESPACE="prd"

kubectl config current-context
# NÃO EXECUTADO — sem cluster conectado nesta sessão.
```

Dupla confirmação obrigatória em `prd`:

```bash
echo "⚠️  DEPLOY EM PRODUÇÃO: recarga @ 21fbd0f"
echo "Confirme com 'CONFIRMO DEPLOY PRD' (5s) ou aborto."
APPROVED_BY="Carla Mendes"
[ -n "$APPROVED_BY" ] || { echo "APPROVED_BY não definido — abortando deploy prd"; exit 1; }
# resultado esperado: aprovação do CAB registrada — Carla Mendes, gerente de plataforma → OK
```

## Fase 1 — Detectar deployables alterados

```bash
LAST_TAG=$(git tag --list "deploy-prd-*" --sort=-creatordate | head -1)
# deploy-prd-20260910-1430-f922ba7

LAST_SHA=$(git rev-list -n 1 "$LAST_TAG")
# f922ba7 (onda 3)

git diff --name-only f922ba7..21fbd0f | \
  grep -oE "services/[^/]+|apps/[^/]+|platform/helm/[^/]+" | sort -u
# resultado esperado: services/recarga (onda 4 tocou tokenização, autorização/captura,
# antifraude e conciliação — TASK-41..TASK-44)

git diff --name-only f922ba7..21fbd0f | grep -qE "(services|apps)/recarga/"
# resultado esperado: match → módulo recarga está entre os alterados, segue sem alerta
```

## Fase 2 — Disparar build multi-arch

```bash
gh workflow run build-image.yml \
  -f module=recarga \
  -f sha=21fbd0f \
  -f push_registry=true
# NÃO EXECUTADO — sem GHCR/CI conectado nesta sessão.

RUN_ID=$(gh run list --workflow=build-image.yml --branch=main --limit=1 --json databaseId --jq '.[0].databaseId')
gh run watch $RUN_ID --exit-status
# NÃO EXECUTADO

IMAGE_TAG="21fbd0f"
MANIFEST_DIGEST=$(docker buildx imagetools inspect \
  ghcr.io/recarga:21fbd0f --format '{{.Manifest.Digest}}')
# NÃO EXECUTADO — dry-run usa placeholder sha256:<pendente-build>
```

## Fase 3 — Gates de segurança

```bash
for ARCH in amd64 arm64; do
  ARCH_DIGEST=$(docker buildx imagetools inspect \
    ghcr.io/recarga:21fbd0f \
    --format '{{range .Manifest.Manifests}}{{if eq .Platform.Architecture "'$ARCH'"}}{{.Digest}}{{end}}{{end}}')

  trivy image --severity CRITICAL,HIGH,MEDIUM,LOW \
    --exit-code 1 \
    --ignore-unfixed=false \
    --ignorefile .trivyignore \
    ghcr.io/recarga@$ARCH_DIGEST
done
# NÃO EXECUTADO — política zero tolerance (.trivyignore: "nenhuma exceção vigente"),
# gate exige 0C0H0M0L para ambas as arquiteturas antes de prosseguir.

REPO_SLUG=$(awk '/^repo_slug:/ {print $2}' AGENTS.md)
# axis-mobfintech/bilhetagem-core

cosign verify \
  --certificate-identity-regexp "https://github.com/axis-mobfintech/bilhetagem-core/.github/workflows/.*" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/recarga:21fbd0f
# NÃO EXECUTADO

cosign download sbom ghcr.io/recarga@$MANIFEST_DIGEST -o /tmp/sbom-recarga.cdx.json
[ -s /tmp/sbom-recarga.cdx.json ] || { echo "SBOM ausente"; exit 1; }
# NÃO EXECUTADO
```

## Fase 4 — Helm deploy

```bash
helm upgrade --install recarga platform/helm/recarga \
  --namespace prd \
  --create-namespace \
  --values platform/helm/recarga/values-prd.yaml \
  --set image.repository=ghcr.io/recarga \
  --set image.digest=$MANIFEST_DIGEST \
  --set deployment.strategy=rolling \
  --atomic \
  --timeout 10m \
  --wait
# NÃO EXECUTADO — sem cluster conectado. values-prd.yaml atual: replicaCount=4,
# deployment.strategy=rolling, env.AMBIENTE=prd.
```

## Fase 5 — Rollout status

```bash
kubectl rollout status deploy/recarga -n prd --timeout=5m
# NÃO EXECUTADO

kubectl get pods -n prd -l app=recarga \
  -o jsonpath='{range .items[?(@.spec.nodeName)]}{.metadata.name} {.spec.nodeSelector.kubernetes\.io/arch}{"\n"}{end}' | \
  grep "arm64" | head -1 | awk '{print $1}'
# NÃO EXECUTADO — gate exige ao menos 1 pod arm64 Running antes de prosseguir.
```

## Fase 6 — Smoke test em pod arm64 nativo

```bash
kubectl exec -n prd $ARM64_POD -- \
  wget -qO- --tries=1 --timeout=5 http://127.0.0.1:8080/health/ready
# NÃO EXECUTADO

# Nenhum smoke test canário específico do módulo: platform/helm/recarga/smoke-tests/ não existe,
# então apenas o health endpoint padrão acima seria executado.
```

## Fase 7 — Kyverno admission verification

```bash
kubectl get events -n prd \
  --field-selector reason=PolicyViolation \
  --sort-by='.lastTimestamp' | tail -5
# NÃO EXECUTADO

kubectl get clusterpolicy require-multiarch-images -o jsonpath='{.status.ready}'
kubectl get clusterpolicy require-cosign-signature -o jsonpath='{.status.ready}'
# NÃO EXECUTADO
```

## Fase 8 — Tag de deploy bem-sucedido

```bash
TAG_NAME="deploy-prd-$(date +%Y%m%d-%H%M)-21fbd0f"
git tag -a "$TAG_NAME" 21fbd0f -m "Deploy recarga @ 21fbd0f em prd"
git push origin "$TAG_NAME"
# NÃO EXECUTADO — nenhuma escrita/push real feita nesta sessão de dry-run.
```

## Fase 9 — Atualizar PROGRESS-TRACKING.md

Bloco que seria adicionado à tabela "Deploy log" de
`docs/product/modules/recarga/PROGRESS-TRACKING.md`:

```markdown
| 2026-09-26 HH:MM | prd | recarga | 4 | 21fbd0f | sha256:<pendente-build> | ✅ |
```

Seguido de commit + push para `main` — **NÃO EXECUTADO** (dry-run; commit/push são vedados nesta
sessão).

## Fase 10 — Jira sync (env=prd)

Para cada task da onda 4 (TASK-41, TASK-42, TASK-43, TASK-44), o fluxo seria:

```
1. searchJiraIssuesUsingJql: JQL "project = BIL AND labels = task:TASK-41 AND status = 'In Review'"
   (repetir para task:TASK-42, task:TASK-43, task:TASK-44)
2. getTransitionsForJiraIssue(issueKey) → localizar id da transição para "Done"
3. transitionJiraIssue(issueKey, transitionId) → mover para "Done"
4. addCommentToJiraIssue(issueKey, comentário):
   "🚀 deploy-orchestrator: Promovido para PRODUÇÃO em 2026-09-26 HH:MM.
    Manifest: ghcr.io/recarga@sha256:<pendente-build>
    Aprovador: Carla Mendes (CAB de hoje)."
```

**NÃO EXECUTADO** — MCP do Atlassian não está conectado nesta sessão. As chaves reais das issues
(`BIL-NNN`) não puderam ser resolvidas sem consulta ao Jira; o runbook usa o rótulo `task:TASK-4x`
como critério de busca, igual à Fase 10 da definição do agente.

## Resumo

Todas as fases 0 e 1 (validação e diff) foram checadas contra o estado real do repositório de
trabalho e passaram. As fases 2 a 10 dependem de cluster, GHCR e Jira — nenhuma delas foi
executada; os comandos acima são o plano exato que o `deploy-orchestrator` executaria caso esses
sistemas estivessem conectados.
