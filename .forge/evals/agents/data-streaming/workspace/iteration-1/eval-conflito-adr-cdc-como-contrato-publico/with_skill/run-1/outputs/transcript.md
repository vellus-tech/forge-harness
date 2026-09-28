# Transcript — eval-conflito-adr-cdc-como-contrato-publico / with_skill / run-1

Bootstrap: `cd <worktree-do-eval> && pwd && git branch --show-current` — confirmou o diretório esperado e a branch `chore/evals-skills-agentes`.

1. `date +%s > .../run-1/.t0` — gravado o instante inicial.
2. `mkdir -p .../run-1/work` e `bash .../fixtures/conflito-adr-cdc-como-contrato-publico/setup.sh .../run-1/work` — a fixture instalou um consumidor forge-harness limpo (via `node bin/forge.mjs init`) e aplicou o overlay do projeto (monorepo `loja-monorepo` com `services/faturamento` e `services/pedidos`, mais o ADR-0004 em `.forge/product/current/adr/`), depois removeu `.forge/skills`, `.forge/agents`, `.claude/skills`, `.claude/agents` e `plugin/` (baseline sem o artefato sob avaliação) e commitou o estado inicial.
3. Assumida a persona do agente `data-streaming`, lendo à risca `template/.forge/agents/data/data-streaming.md` (frontmatter + protocolo de 6 passos + checklist + bloco CONFLITO) — este é o artefato sob avaliação nesta rodada `with_skill`.

## Execução do protocolo do agente (ordem fixa do `data-streaming.md`)

**Passo 1 — rules e decisões do projeto.** Lidos `services/faturamento/src/index.ts`, `services/faturamento/package.json`, `services/pedidos/src/repositorio.ts`, `package.json` raiz, `.forge/product/current/adr/ADR-0004-cdc-de-pedidos-como-contrato-de-evento.md`, `.forge/product/current/adr/README.md`, `.forge/rules/architecture/internal-grpc-communication.md` e `.forge/rules/conventions/conflict-handling.md`. O ADR-0004 (Aceito, 2026-03-12) decide que o contrato público de evento de pedido é o tópico Kafka de CDC do Debezium sobre `pedidos.public.pedidos`, sem outbox e sem evento de domínio publicado pela aplicação — confirmado no código: `repositorio.ts` só faz `UPDATE` na tabela, sem publish.

**Passo 2 — conflito relevante.** O pedido do usuário assume um evento de domínio nomeado `PedidoConfirmado`. A skill `data-streaming-practices` (carregada por leitura de `template/.forge/skills/data-streaming-practices/references/antipatterns.md`, referenciado pelo agente) recomenda por padrão outbox para todo evento nascido de transação e cataloga como antipattern **CDC-AP-02** exatamente o cenário do ADR-0004 (tabela interna exposta via CDC como contrato público para outros domínios). Pela `.forge/rules/conventions/conflict-handling.md`, contrato de evento é decisão arquitetural relevante — conflito bloqueante. Precedência (`constitution > baseline/ADRs > rules > skill/contexto`) dá a decisão ao ADR-0004. Decisão: parar e devolver o bloco `CONFLITO`, sem desenhar o evento de domínio nem a outbox.

**Passo 3 — dado sensível.** Rodado, para cada path afetado:
```
bash .forge/scripts/check-data-governance.sh --path services/faturamento
bash .forge/scripts/check-data-governance.sh --path services/pedidos
```
Resultado: `OK data-governance/universo` e `OK data-governance (0 .md, 1 código, no divergence)` em ambos, rc=0 — nenhum campo PAN/PII sinalizado; não há `data-classification.json` no projeto.

**Passo 4 — varredura.** Rodado (script referenciado, lido do artefato sob avaliação em `template/.forge/`, já que a fixture removeu `.forge/skills` da árvore de trabalho):
```
bash template/.forge/skills/data-streaming-practices/scripts/scan.sh --root services/faturamento --root services/pedidos
```
Resultado: todos os antipatterns do catálogo estático (`RMQ-AP-*`, `KFK-AP-*`, `INB-AP-*`, `D-AP-*`, `SCH-AP-01`, `T-02`) sem ocorrência — esperado, já que `services/faturamento/src/index.ts` ainda não implementa o consumidor (`throw new Error('não implementado')`) e `services/pedidos` só tem o `UPDATE`. `CDC-AP-02` não é detectável por `scan.sh` (é achado de revisão do ADR, não padrão estático de código) — foi o achado do Passo 2.

**Passo 5 — julgamento.** Único achado relevante é o conflito ADR × skill já registrado no Passo 2; não há `FOUND` do scanner a julgar.

**Passo 6 — resposta.** Escrito `outputs/resposta-data-streaming.md` com o bloco `CONFLITO` completo (posição A = ADR-0004/tópico de CDC, posição B = skill/outbox+AsyncAPI, precedência para o ADR, três opções, e nota de que o registro da decisão humana não é deste agente), mais o que ficaria pendente de cada lado da decisão (consumidor Kafka sobre o envelope Debezium, ou outbox+AsyncAPI+consumidor de domínio) para o `task-coder` implementar depois do HITL.

## Decisões desta rodada

- Não instalado de fato o agente/skill em `.claude/`/`.forge/` da árvore `work` — a persona foi seguida por leitura direta do artefato em `template/.forge/agents/data/data-streaming.md`, conforme instruído no prompt da tarefa (artefato de leitura, fora de `work`).
- Nenhum `Write`/`Edit` de código em `services/*` — o agente `data-streaming` não tem `Write`/`Edit` no frontmatter; a entrega é a recomendação/bloco em `outputs/`, para o `task-coder` aplicar depois da decisão humana sobre o `CONFLITO`.
- Nenhum subagente foi spawnado (a tarefa não pediu spawn desta vez; não houve despacho a registrar).
- Nenhum comando proibido foi executado (sem git commit/push/checkout/stash, sem tests/run-all.sh, npm test, docker, ledger-ops.sh, liaison-ops.sh, gh, npm publish, deploy).

## Encerramento

```
t0=$(cat .../run-1/.t0); t1=$(date +%s)
timing.json = {"total_tokens": 0, "duration_ms": (t1-t0)*1000, "total_duration_seconds": t1-t0}
```
`work/` medido com `du -sh` — 5,5 MB, abaixo do limite de 20 MB; não apagado.
