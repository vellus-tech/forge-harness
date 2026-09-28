# Transcript — eval-revisao-cache-tarifa-api / with_skill / run-1

## Tarefa

Revisar o uso de Redis no tarifa-api (`services/tarifa-api/src/cache/tarifaCache.ts` + `services/tarifa-api/infra/`) antes de subir para produção, projeto multi-tenant (cada operadora é um tenant), e gravar o diagnóstico em `docs/revisao-cache.md`. Sem alterar código.

## Passos e comandos, em ordem

1. Bootstrap da árvore: `cd .../worktrees/evals-100 && pwd && git branch --show-current` — confirmou diretório e branch `chore/evals-skills-agentes` esperados.
2. Gravado `.t0` com `date +%s`.
3. `mkdir -p .../run-1/work` e execução de `bash fixtures/revisao-cache-tarifa-api/setup.sh .../run-1/work` — materializou o projeto fixture (adapters `.forge`, rules, `services/tarifa-api/*`).
4. Inventário do fixture: `find .../work/services/tarifa-api -type f` — achou `src/cache/tarifaCache.ts`, `src/db.ts`, `infra/redis/redis.conf`, `infra/terraform/redis.tf`, `README.md`.
5. Leitura da skill carregada: `template/.forge/skills/data-cache-practices/SKILL.md` — protocolo fixo: (1) escopo, (2) rules do projeto, (3) detecção via `check-data-governance.sh` + `scan.sh`, (4) julgamento, (5) relatório por regra.
6. Leitura dos cinco arquivos do fixture (`tarifaCache.ts`, `redis.conf`, `redis.tf`, `README.md`, `db.ts`) para montar o escopo e a fonte de verdade de cada chave.
7. Passo 1 do protocolo (escopo): identifiquei três chaves com fonte de verdade em PostgreSQL (`db.tarifas`, `db.parametros`, `db.linhas`) — todas legítimas para cache.
8. Passo 2 do protocolo (rules do projeto): li `.forge/rules/data/data-cache.md` (namespace por tenant obrigatório, TTL explícito, classes proibidas, invalidação, serialização versionada, degradação graciosa) e `.forge/rules/data/data-governance.md` (isolamento multi-tenant é decisão única; para Redis o mecanismo é namespacing de chave).
9. Passo 3 do protocolo (detecção), dentro de `work/`:
   - `bash .forge/scripts/check-data-governance.sh --path services/tarifa-api` → `OK data-governance/universo — 3 arquivo(s) examinado(s)`, `OK data-governance (1 .md, 2 código, no divergence)`. Sem `data-classification.json` no projeto, então cobriu o universo disponível, sem achado de PAN/PII.
   - `bash <skill-dir>/scripts/scan.sh --root services/tarifa-api` (script lido só do artefato do harness, em `template/.forge/`, apontado contra o fixture em `work/`) → achados: C-02 (aviso, 2 ocorrências: `tarifaCache.ts:23,32`), C-09 (aviso, 1: `tarifaCache.ts:46`), C-10 (alto, 2: `redis.conf:5,6`), C-11 (alto, 1: `redis.conf:4`), C-16 (aviso, 1: `redis.tf:21`); C-08, C-15, C-17 limpos.
10. Passo 4 do protocolo (julgamento): cruzei cada `FOUND` com a rule do projeto; identifiquei manualmente um achado sem detector estático — `linhas:grupo:{grupoId}` em `getLinhasDoGrupo` sem prefixo `tenant:{id}:`, item de revisão obrigatório citado explicitamente no texto da skill ("O que o scanner não faz"). Também revisei manualmente ordem de invalidação em `atualizarTarifa` (`DEL` antes do commit, não depois — antipattern C-01 por definição textual, sem detector), ausência de tratamento de erro do cliente Redis, e ausência de versionamento de serialização.
11. Passo 5 do protocolo (relatório): escrevi `work/docs/revisao-cache.md` com uma linha por regra (inclusive as limpas), achados citando `arquivo:linha`, seção de bloqueantes e seção de observações não bloqueantes, sem alterar nenhum arquivo de código ou infra.
12. Copiei o diagnóstico para `outputs/revisao-cache.md` e escrevi este transcript.

## Decisões e critério de severidade

- O protocolo da skill marca C-02/C-09/C-16 como severidade `aviso` no scanner (heurístico), mas na revisão eu os elevo a bloqueante por regra do projeto: `data-cache.md` exige TTL explícito "em toda entrada" sem ressalva de severidade, `KEYS` bloqueia thread única compartilhada por todos os tenants (impacto direto em multi-tenant), e a exposição de rede junto com a exposição de autenticação (achado #5) forma um caso composto sem nenhuma camada de defesa. Isso é julgamento da revisão, não do detector — registrado explicitamente no relatório para não confundir com o `aviso` original do `scan.sh`.
- `getParametros` tem TTL (via `.expire()` separado) mas não atômico com o `SET` — tratei como achado por causa da janela de crash entre as duas chamadas, distinto de `getLinhasDoGrupo`, que não tem TTL algum.
- Não classifiquei a ausência de try/catch como achado confirmado (FOUND), porque não há evidência de que não existe tratamento em camada superior (middleware) — registrei como item de revisão manual, coerente com "quem revisa decide" do texto da skill.

## Regras de execução respeitadas

- Nenhum `git commit/push/checkout/stash`, nenhum teste/build, nenhum `gh`, nenhuma escrita fora do diretório designado.
- Nenhum código do fixture foi alterado — só leitura e a escrita do diagnóstico em `docs/revisao-cache.md`.
- Nenhum subagente foi spawnado (não havia necessidade neste caso; a skill não manda spawnar subagentes).
- Scripts do artefato do harness (`template/.forge/skills/data-cache-practices/scripts/scan.sh`) foram apenas lidos/executados, nunca escritos.
