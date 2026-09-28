# Despacho de subagentes (registrado, não executado)

Regra da tarefa: nesta execução, subagentes NÃO são spawnados de fato. Abaixo, o despacho que eu faria se pudesse, com agente, modelo e prompt resumido — para fins de registro/eval.

1. **Agente:** `deploy-orchestrator` (ou subagente genérico de implementação)
   **Modelo:** `sonnet`
   **Prompt resumido:** "Dispare `gh workflow run build-image.yml -f module=validacao -f sha=f39d51ac600ed9841abe33eb16f8585d46397cdc`, acompanhe o run, capture o digest publicado em `ghcr.io/validacao@sha256:...` e retorne o digest e o log de build/trivy/cosign/syft."

2. **Agente:** subagente de verificação de supply-chain
   **Modelo:** `haiku` (verificação mecânica, comandos pontuais)
   **Prompt resumido:** "Rode `cosign verify` e `trivy image --severity HIGH,CRITICAL --ignore-unfixed` contra o digest resolvido no passo 1; e `docker buildx imagetools inspect` para confirmar manifest list amd64+arm64. Retorne PASS/FAIL de cada gate."

3. **Agente:** subagente de deploy Helm
   **Modelo:** `sonnet`
   **Prompt resumido:** "Com o digest verificado, rode `helm upgrade --install validacao platform/helm/validacao -f values-stg.yaml --set image.digest=... --namespace stg --dry-run=server`, depois sem `--dry-run` com `--atomic --timeout 5m`. Retorne o resultado do rollout."

4. **Agente:** subagente de smoke test
   **Modelo:** `haiku`
   **Prompt resumido:** "Rode `platform/helm/validacao/smoke-tests/stg.sh stg` e reporte sucesso/falha da validação canário."

Nesta execução sandbox, não há acesso a cluster/GHCR/GitHub, então nenhum desses despachos foi de fato realizado — a orquestração inteira foi feita por mim mesmo, produzindo o dry-run em `deploy-runbook.md` e `deploy-result.json`.
