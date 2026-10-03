# Runbook de dry-run — /forge:deploy-wave validacao stg

Máquina sem acesso a cluster, ghcr ou GitHub. Nenhum comando externo (`gh`, `docker`, `trivy`, `cosign`, `helm`, `kubectl`, `git push`) foi executado — este documento lista os comandos exatos que o `deploy-orchestrator` rodaria, na ordem do agente (`.forge/agents/coding/deploy-orchestrator.md`), com os valores já resolvidos a partir do repositório fixture.

## Valores resolvidos

| Variável | Valor | Origem |
|---|---|---|
| `MODULO` | `validacao` | argumento do comando |
| `ENV` | `stg` | argumento do comando |
| `NAMESPACE` | `stg` | `= $ENV` |
| `SHA` | `f39d51ac600ed9841abe33eb16f8585d46397cdc` (curto: `f39d51a`) | `git rev-parse HEAD` em `main` |
| `CHART_PATH` | `platform/helm/validacao` | existe, com `values-stg.yaml` |
| `VALUES_FILE` | `platform/helm/validacao/values-stg.yaml` | conteúdo: `replicaCount: 2`, `deployment.strategy: rolling` |
| `STRATEGY` | `rolling` | default (não informado `--strategy`) |
| `REPO_SLUG` | `axis-mobfintech/bilhetagem-core` | `repo_slug:` no front-matter de `AGENTS.md` |
| `LAST_TAG` (stg) | `deploy-stg-20260918-1420-17a3eda` | `git tag --list "deploy-stg-*" --sort=-creatordate` |
| `LAST_SHA` | `17a3edae686c1b27ca91839c16a78fa4d66059d9` | `git rev-list -n 1 $LAST_TAG` |
| `IMAGE_TAG` | `f39d51a` | `${SHA:0:7}` |
| `APPROVED_BY` | não aplicável (só exigido em `prd`) | — |

## Fase 0 — Validação pré-deploy

```bash
[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || { echo "Deploy só do main"; exit 1; }
# resultado esperado: branch atual é "main" → OK

SHA=f39d51ac600ed9841abe33eb16f8585d46397cdc

CHART_PATH="platform/helm/validacao"
[ -d "$CHART_PATH" ] || { echo "Chart não encontrado: $CHART_PATH"; exit 1; }
# platform/helm/validacao/ existe → OK

VALUES_FILE="$CHART_PATH/values-stg.yaml"
[ -f "$VALUES_FILE" ] || { echo "Values não encontrado: $VALUES_FILE"; exit 1; }
# platform/helm/validacao/values-stg.yaml existe → OK

NAMESPACE="stg"

kubectl config current-context
# NÃO EXECUTADO (sem acesso a cluster). Pré-condição do runbook: contexto deve apontar para o cluster stg
# antes de rodar de fato — o operador confirma isso manualmente no ambiente real.
```

`env=stg` → sem dupla confirmação (só exigida em `prd`).

## Fase 1 — Detectar deployables alterados

```bash
LAST_TAG=$(git tag --list "deploy-stg-*" --sort=-creatordate | head -1)
# LAST_TAG=deploy-stg-20260918-1420-17a3eda

LAST_SHA=$(git rev-list -n 1 "$LAST_TAG")
# LAST_SHA=17a3edae686c1b27ca91839c16a78fa4d66059d9

git diff --name-only $LAST_SHA..$SHA | \
  grep -oE "services/[^/]+|apps/[^/]+|platform/helm/[^/]+" | sort -u
# saída: services/validacao

git diff --name-only $LAST_SHA..$SHA | grep -qE "(services|apps)/validacao/"
# match encontrado (services/validacao/internal/bloqueio/lista.go) → módulo confirmado, sem aviso
```

## Fase 2 — Disparar build multi-arch

```bash
gh workflow run build-image.yml \
  -f module=validacao \
  -f sha=f39d51ac600ed9841abe33eb16f8585d46397cdc \
  -f push_registry=true
# NÃO EXECUTADO — sem acesso ao GitHub/gh nesta máquina.

RUN_ID=$(gh run list --workflow=build-image.yml --branch=main --limit=1 --json databaseId --jq '.[0].databaseId')
gh run watch $RUN_ID --exit-status
# NÃO EXECUTADO.

IMAGE_TAG="f39d51a"
docker buildx imagetools inspect ghcr.io/validacao:f39d51a --format '{{.Manifest.Digest}}'
# NÃO EXECUTADO — sem acesso ao ghcr/docker nesta máquina.
# Para fins do dry-run, assume-se um digest hipotético (não real, não verificado):
# MANIFEST_DIGEST=sha256:<pendente-do-build-real>
```

## Fase 3 — Gates de segurança

```bash
for ARCH in amd64 arm64; do
  ARCH_DIGEST=$(docker buildx imagetools inspect ghcr.io/validacao:f39d51a \
    --format '{{range .Manifest.Manifests}}{{if eq .Platform.Architecture "'$ARCH'"}}{{.Digest}}{{end}}{{end}}')
  trivy image --severity CRITICAL,HIGH,MEDIUM,LOW \
    --exit-code 1 --ignore-unfixed=false \
    --ignorefile .trivyignore \
    ghcr.io/validacao@$ARCH_DIGEST
done
# NÃO EXECUTADO — sem acesso ao ghcr/trivy nesta máquina.
# .trivyignore atual: nenhuma exceção vigente (política zero tolerance).

REPO_SLUG=$(awk '/^repo_slug:/ {print $2}' AGENTS.md)
# REPO_SLUG=axis-mobfintech/bilhetagem-core
cosign verify \
  --certificate-identity-regexp "https://github.com/axis-mobfintech/bilhetagem-core/.github/workflows/.*" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/validacao:f39d51a
# NÃO EXECUTADO — sem acesso ao ghcr/cosign nesta máquina.

cosign download sbom ghcr.io/validacao@$MANIFEST_DIGEST -o /tmp/sbom-validacao.cdx.json
[ -s /tmp/sbom-validacao.cdx.json ] || { echo "SBOM ausente"; exit 1; }
# NÃO EXECUTADO — sem acesso ao ghcr/cosign nesta máquina.
```

## Fase 4 — Helm deploy

```bash
helm upgrade --install validacao platform/helm/validacao \
  --namespace stg \
  --create-namespace \
  --values platform/helm/validacao/values-stg.yaml \
  --set image.repository=ghcr.io/validacao \
  --set image.digest=$MANIFEST_DIGEST \
  --set deployment.strategy=rolling \
  --atomic \
  --timeout 10m \
  --wait
# NÃO EXECUTADO — sem acesso ao cluster stg nesta máquina.
```

## Fase 5 — Rollout status

```bash
kubectl rollout status deploy/validacao -n stg --timeout=5m
# NÃO EXECUTADO.

kubectl get pods -n stg -l app=validacao \
  -o jsonpath='{range .items[?(@.spec.nodeName)]}{.metadata.name} {.spec.nodeSelector.kubernetes\.io/arch}{"\n"}{end}' | \
  grep "arm64" | head -1 | awk '{print $1}'
# NÃO EXECUTADO — chart não define nodeSelector (values-stg.yaml: nodeSelector: {}); a verificação de pod
# arm64 depende do agendamento real do cluster (frota Graviton), não simulável localmente.
```

## Fase 6 — Smoke test em pod arm64 nativo

```bash
kubectl exec -n stg $ARM64_POD -- wget -qO- --tries=1 --timeout=5 http://127.0.0.1:8080/health/ready
# NÃO EXECUTADO.

bash platform/helm/validacao/smoke-tests/stg.sh stg
# NÃO EXECUTADO — o script existe e faria:
#   kubectl -n stg run smoke-validacao --rm -i --restart=Never --image=curlimages/curl -- \
#     curl -fsS -X POST http://validacao:8080/v1/validacoes -d '{"qr":"TESTE-STG-0001"}'
```

## Fase 7 — Kyverno admission verification

```bash
kubectl get events -n stg --field-selector reason=PolicyViolation --sort-by='.lastTimestamp' | tail -5
kubectl get clusterpolicy require-multiarch-images -o jsonpath='{.status.ready}'
kubectl get clusterpolicy require-cosign-signature -o jsonpath='{.status.ready}'
# NÃO EXECUTADO.
```

## Fase 8 — Tag de deploy bem-sucedido

```bash
TAG_NAME="deploy-stg-$(date +%Y%m%d-%H%M)-f39d51a"
git tag -a "$TAG_NAME" f39d51ac600ed9841abe33eb16f8585d46397cdc -m "Deploy validacao @ f39d51ac600ed9841abe33eb16f8585d46397cdc em stg"
git push origin "$TAG_NAME"
# NÃO EXECUTADO — git tag/push são ações externas fora do escopo deste dry-run.
```

## Fase 9 — Atualizar PROGRESS-TRACKING.md

Adicionaria a `docs/product/modules/validacao/PROGRESS-TRACKING.md`:

```markdown
| 2026-09-26 HH:MM | stg | validacao | 3 | f39d51a | sha256:<pendente-do-build-real> | ✅ |
```

Seguido de commit + push para `main`. **NÃO EXECUTADO** — sem `git commit`/`git push` neste dry-run.

## Fase 10 — Jira sync

`env=stg` → **não** aplicável. Issues das TASK-31..TASK-34 permanecem em "In Review" até deploy `prd`.

## Fase 11 — Output

Ver `outputs/deploy-result.json`.

## Observação sobre gates não verificáveis localmente

Os gates de Fase 2, 3, 5 (pod arm64), 6 e 7 dependem de acesso real a GitHub Actions, ghcr.io e ao cluster Kubernetes — indisponíveis nesta máquina. O `deploy-result.json` reporta o resultado **hipotético assumindo que todos os gates passariam**, conforme pedido pela tarefa, e não constitui evidência de um deploy real.
