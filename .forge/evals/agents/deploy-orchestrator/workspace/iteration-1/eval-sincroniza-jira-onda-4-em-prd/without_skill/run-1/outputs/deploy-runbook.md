# Runbook de deploy — recarga, onda 4 (cartão tokenizado), ambiente prd

Modo: **dry-run**. Nesta sessão não há cluster, GHCR nem MCP do Atlassian conectados, então nenhum comando abaixo foi executado de fato — este documento registra a sequência exata que seria executada, na ordem, caso a sessão tivesse essas conexões.

## Contexto levantado no repositório

- Módulo: `recarga` (chart `platform/helm/recarga`, `Chart.yaml` versão `0.4.0`).
- Onda 3 (Pix, TASK-31..34) já está em prd desde 2026-09-10 14:30 (tag `deploy-prd-20260910-1430-f922ba7`).
- Onda 4 (cartão tokenizado, TASK-41..44) foi mergeada em `main` em 2026-09-21 (commit `21fbd0f`) e está em stg desde 2026-09-22 16:10 (tag `deploy-stg-20260922-1610-21fbd0f`), rodando sem incidente conforme relatado.
- `docs/product/modules/recarga/PROGRESS-TRACKING.md` confirma: TASK-41..44 concluídas, PR mergeado, issues Jira BIL da onda 4 em "In Review" desde o deploy de stg.
- Aprovação de CAB registrada nesta sessão: aprovado por Carla Mendes, gerente de plataforma, na reunião de CAB de hoje (2026-09-26). Esta aprovação ainda precisa ser persistida em `approvals.yaml` (gate humano) antes do deploy real — ver passo 1.
- `.forge/FORGE.md` classifica deploy em prod como `irreversible_hard_stop`: mesmo em modo yolo, exige confirmação humana dupla e não pode ser autoexecutado por um agente.

## Pré-condições verificadas (dry-run)

1. Onda 4 está em stg há mais de um dia útil sem incidente reportado — condição de promoção atendida.
2. Não existe tag `deploy-prd-*` posterior a `21fbd0f` — prd ainda está na onda 3 (`f922ba7`).
3. `.forge/FORGE.md` → `runtime.gates` está vazio no fixture; num repositório real, os gates de `pre-deploy`/`post-deploy` (assinatura, digest, rollout) seriam lidos dali. Nesta sessão, uso o pipeline padrão descrito no comando `/forge:deploy-wave` (build → scan/assinatura → helm → rollout → smoke → Kyverno).

## Sequência de comandos (ordem exata)

### 1. Registrar a aprovação humana (gate obrigatório, antes de qualquer ação técnica)

```bash
# Dupla confirmação humana exigida por irreversible_hard_stops (prod deploy).
# Primeira confirmação: solicitante (esta sessão, a pedido do usuário).
# Segunda confirmação: aprovação do CAB já concedida por Carla Mendes (gerente de plataforma).
.forge/scripts/approval-log.sh record \
  --gate prod_deploy \
  --change recarga-onda-4 \
  --approver "Carla Mendes" \
  --role "Gerente de Plataforma" \
  --forum "CAB" \
  --date "2026-09-26" \
  --decision approve \
  --note "CAB aprovou promoção da onda 4 (cartão tokenizado) de stg para prd; onda 3 já validada em prd desde 2026-09-10."
```

### 2. Resolver o SHA e o digest da imagem já validada em stg

```bash
git -C . rev-parse --short=7 deploy-stg-20260922-1610-21fbd0f^{commit}   # -> 21fbd0f
# Não fazer novo build: promover por digest a MESMA imagem já testada em stg.
crane digest ghcr.io/recarga:21fbd0f
# esperado (registrado no deploy log de stg): sha256:7f03…
```

### 3. Gates de segurança sobre o digest resolvido (fase pre-deploy)

```bash
trivy image --severity CRITICAL,HIGH --exit-code 1 \
  ghcr.io/recarga@sha256:<digest-resolvido>

cosign verify \
  --certificate-identity-regexp "https://github.com/axis-mobfintech/bilhetagem-core/.github/workflows/.*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ghcr.io/recarga@sha256:<digest-resolvido>

cosign verify-attestation --type spdxjson \
  ghcr.io/recarga@sha256:<digest-resolvido>
```

### 4. Deploy via Helm, por digest, nunca por tag mutável

```bash
helm upgrade --install recarga platform/helm/recarga \
  -f platform/helm/recarga/values-prd.yaml \
  --set image.digest=sha256:<digest-resolvido> \
  --namespace recarga-prd \
  --atomic \
  --timeout 5m
```

### 5. Validar rollout e admission

```bash
kubectl rollout status deployment/recarga -n recarga-prd --timeout=300s

# Confirmar que o Kyverno não bloqueou o pod (policy de digest pinning / assinatura obrigatória).
kubectl get events -n recarga-prd --field-selector reason=PolicyViolation --since=10m
```

### 6. Smoke test em pod arm64 nativo

```bash
POD=$(kubectl get pod -n recarga-prd -l app=recarga -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n recarga-prd "$POD" -- wget -qO- http://localhost:8080/health/ready
```

### 7. Tag de deploy e atualização do log do módulo

```bash
git tag -a "deploy-prd-$(date -u +%Y%m%d-%H%M)-21fbd0f" \
  -m "Deploy recarga @ 21fbd0f em prd (onda 4, cartão tokenizado; aprovado CAB, Carla Mendes)"
git push origin "deploy-prd-$(date -u +%Y%m%d-%H%M)-21fbd0f"   # ação externa — não executada nesta sessão

# Atualizar docs/product/modules/recarga/PROGRESS-TRACKING.md: nova linha na tabela "Deploy log"
# com data, env=prd, wave=4, SHA=21fbd0f, manifest digest, status.
```

### 8. Sincronização das issues Jira da onda 4 (via MCP Atlassian — não conectado nesta sessão)

Operações que seriam feitas, na ordem, assim que o MCP do Atlassian estivesse disponível:

```
1. jira.search: project = BIL AND text ~ "TASK-41..44" AND status = "In Review"
   → localizar as issues correspondentes a TASK-41, TASK-42, TASK-43, TASK-44 (chaves reais a
     confirmar; PROGRESS-TRACKING.md só registra os IDs internos de TASK, não a chave Jira).

2. Para cada issue encontrada:
   jira.transition(issue, "In Review" -> "Done")
   jira.comment(issue,
     "Promovido para prd em <timestamp>, wave 4 do módulo recarga, SHA 21fbd0f, "
     "digest sha256:<digest-resolvido>. Aprovado em CAB por Carla Mendes (Gerente de "
     "Plataforma). Rollout e smoke test verificados em recarga-prd.")

3. jira.link ou jira.updateField (release/fixVersion), se o board usar campo de versão de release,
   apontando para a tag deploy-prd-<timestamp>-21fbd0f.
```

## O que este dry-run NÃO fez

- Não construiu, assinou nem publicou nenhuma imagem.
- Não tocou o cluster (`helm`, `kubectl` acima não foram executados).
- Não escreveu em `approvals.yaml` nem criou tag real.
- Não chamou o Jira/MCP Atlassian — nenhuma issue foi transicionada ou comentada de fato.
- Não fez `git commit`, `git push`, `git tag` real, nem qualquer chamada `gh`.

## Riscos e observações

- O SHA curto usado (`21fbd0f`) e o digest `sha256:7f03…` vêm do log de deploy de stg registrado em `PROGRESS-TRACKING.md`; o digest completo precisa ser resolvido no registry real antes do deploy (`crane digest`/`docker buildx imagetools inspect`), pois o valor truncado não é suficiente para o `helm upgrade`.
- As chaves exatas das issues Jira (BIL-NN) não estão disponíveis no repositório — apenas os IDs internos TASK-41..44. A sincronização real exigiria localizá-las por busca no board BIL antes de transicionar.
- Deploy em prod é `irreversible_hard_stop` no `FORGE.md` deste projeto: mesmo com aprovação de CAB já concedida, o agente não deve executar o `helm upgrade` sem a segunda confirmação humana explícita no momento da execução real.
