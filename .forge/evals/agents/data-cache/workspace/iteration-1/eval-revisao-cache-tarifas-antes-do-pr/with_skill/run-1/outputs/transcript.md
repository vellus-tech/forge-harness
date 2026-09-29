# Transcript — eval-revisao-cache-tarifas-antes-do-pr / with_skill / run-1

Papel assumido: agente `data-cache` (definição em `template/.forge/agents/data/data-cache.md`), seguindo o protocolo de 6 passos e a skill `data-cache-practices`.

## Passos, comandos e decisões

1. **Bootstrap.** `cd .../worktrees/evals-100 && pwd && git branch --show-current` — confirmou diretório e branch `chore/evals-skills-agentes` esperados.
2. **Preparação do caso de eval.**
   - `date +%s > .t0`
   - `mkdir -p work`
   - `bash .../fixtures/revisao-cache-tarifas-antes-do-pr/setup.sh work` — populou `work/` com o projeto fixture (services/tarifas, infra/redis, template `.forge/` completo). Exit 0.
3. **Leitura da definição do agente.** Li `template/.forge/agents/data/data-cache.md` — confirmei: sem `Write`/`Edit`/`Agent`; protocolo de 6 passos (rules → conflito → dado sensível → varredura → julgamento → resposta); checklist e catálogo de antipatterns; bloco `CONFLITO` só para divergência de autoridade entre rule/ADR e skill/base, não para bug de código.
4. **Passo 1 do protocolo — rules e decisões do projeto.** Li:
   - `template/.forge/rules/data/data-cache.md` — tenant namespacing obrigatório, TTL explícito, classes de dado proibidas (segredo, PAN/CVV, PII sem máscara), invalidação explícita, degradação graciosa.
   - `template/.forge/rules/domain/money-as-cents.md` — registrado como fora do escopo pedido pelo usuário (revisão só de cache).
   - Localizei também `rules/architecture/internal-grpc-communication.md` e `rules/conventions/conflict-handling.md` (não precisaram ser aplicados: não há decisão de comunicação entre serviços nem divergência de autoridade neste escopo).
5. **Leitura dos arquivos-alvo.**
   - `work/services/tarifas/README.md` — confirmou: Postgres é fonte da verdade, Redis só cache de leitura, multi-tenant por operadora, e o dado crítico "duas operadoras podem ter uma linha com o mesmo id" (motivou o achado 1).
   - `work/services/tarifas/src/tarifa/servico.ts` — `atualizarTarifa` (del antes do commit + set final sem TTL) e `chavesDoTenant` (`redis.keys`).
   - `work/services/tarifas/src/linha/servico.ts` — `buscarLinha` com chave `linha:${id}` sem prefixo de tenant.
   - `work/infra/redis/redis.conf` — `bind 0.0.0.0`, `protected-mode no`, `maxmemory 0`, `maxmemory-policy noeviction`, sem `requirepass`.
6. **Passo 2 do protocolo — checagem de conflito.** Rule do projeto e skill concordam entre si (nenhuma diverge sobre namespace de tenant, TTL, invalidação ou exposição). Decisão: nenhum bloco `CONFLITO` a emitir; os achados são violação de código contra rule+skill, não disputa de autoridade.
7. **Passo 3 do protocolo — dado sensível.** Únicos dois comandos que o `Bash` deste agente pode rodar (hook nega qualquer outro):
   - `bash template/.forge/scripts/check-data-governance.sh --path services/tarifas/src` → `OK data-governance (0 .md, 2 código, no divergence)`, exit 0.
   - `bash template/.forge/scripts/check-data-governance.sh --path infra/redis/redis.conf` → `FAIL data-governance/universo-vazio — 0 arquivo(s) examinado(s)`, exit 1. Interpretado pelo protocolo (passo 3, terceira causa listada): `.conf` está fora das extensões que o script examina (`.go/.kt/.ts/.rego/.py/.md`) — "não verificado por ele", não é aprovação nem conflito. Registrado como tal na resposta.
8. **Passo 4 do protocolo — varredura.**
   - `bash template/.forge/skills/data-cache-practices/scripts/scan.sh --root services/tarifas/src --root infra/redis/redis.conf` (sem `--json`, um único comando com os dois roots dos dois paths afetados).
   - Resultado: `FOUND C-02` (tarifa/servico.ts:8, set sem TTL), `FOUND C-09` (tarifa/servico.ts:12, KEYS), `FOUND C-10` (redis.conf:5-6, maxmemory 0/noeviction), `FOUND C-11` (redis.conf:3-4, bind 0.0.0.0 + protected-mode no); `OK` para C-08, C-15, C-16, C-17. `ARQUIVOS-VARRIDOS 3`, exit 1 (esperado quando há FOUND).
9. **Passo 5 do protocolo — julgamento.** Cada `FOUND` foi lido no arquivo e na linha e confrontado com `references/antipatterns.md` da skill (li o catálogo completo: C-01 a C-17, T-01, T-04) antes de aceitar como achado real — todos os quatro `FOUND` do scanner se confirmaram como antipattern genuíno, sem falso positivo.
   - Além do que o scanner cobre (que é só estática), apliquei julgamento de **revisão** (rótulo `revisão` no catálogo, não coberto por `scan.sh`) para dois achados que o scanner não vê:
     - **C-01** (ordem de invalidação) em `atualizarTarifa`: `del` antes do `db.update`, e `set` em vez de `delete` no fim — detectável só por leitura da ordem das linhas, como o próprio catálogo documenta (`Detecção: revisão`).
     - **Ausência de namespace de tenant** em `buscarLinha` (achado 1, o mais grave): não está no catálogo fechado C-01..C-17 como id numerado — é a violação direta e literal da regra "toda chave inclui o tenant" da `data-cache.md`, elevada a bloqueante pelo próprio README do serviço (colisão de id entre operadoras confirmada como cenário real do produto, não hipotético).
10. **Passo 6 do protocolo — resposta.** Escrevi `outputs/revisao-cache-tarifas.md` com os 5 achados (ordenados por severidade: 2 bloqueantes, 2 altos que se resolvem pela mesma correção, 1 médio), cada um com arquivo:linha, id do catálogo quando aplicável, porquê, e correção em trecho de código — sem tocar em nenhum arquivo de `work/` (o agente não escreve; quem aplica é o `task-coder`, conforme a missão do agente). Seção "não avaliado" cobrindo o que ficou fora do escopo pedido (money-as-cents, stampede/hotkey/cross-slot, PAN — todos sem evidência de aplicabilidade ou fora do que foi pedido).
11. **Sem spawn de subagente.** O protocolo do agente não pede subagente — não houve dispatch a registrar.
12. **Fechamento.** `t0=$(cat .t0); t1=$(date +%s)`; gravado `timing.json`; conferido tamanho de `work/` (bem abaixo de 20 MB, sem necessidade de apagar).

## Decisões de escopo

- Não investiguei `money-as-cents.md` a fundo porque o usuário pediu explicitamente "revisão só do uso de cache antes" — mencionar teria sido escopo não pedido: registrei apenas como nota de "não avaliado", sem bloquear a resposta nisso.
- Não usei `mcp__context7__resolve-library-id`/`query-docs`: não afirmei nenhum default específico de versão de produto além do que o catálogo da skill já documenta com marca de evidência (C-02 TTL, C-09 SCAN, C-10 maxmemory/eviction, C-11 bind/protected-mode/requirepass são comandos/config estáveis do Redis, não específicos de uma versão em particular).
- Não emiti bloco `CONFLITO`: confirmei que rule do projeto e skill não divergem entre si neste caso: os achados são o código violando as duas, o que é revisão normal, não escalonamento de autoridade.
