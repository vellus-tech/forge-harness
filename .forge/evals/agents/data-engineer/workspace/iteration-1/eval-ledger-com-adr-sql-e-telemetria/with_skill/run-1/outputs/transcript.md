# Transcript — eval-ledger-com-adr-sql-e-telemetria / with_skill / run-1

## 1. Bootstrap e ambiente

```
cd <worktree-do-eval> && pwd && git branch --show-current
```
Saída: `<worktree-do-eval>` / `chore/evals-skills-agentes` — confere com o esperado.

## 2. Instante inicial

```
date +%s > .../with_skill/run-1/.t0
```

## 3. Preparação da fixture

```
mkdir -p .../with_skill/run-1/work
bash .../fixtures/ledger-com-adr-sql-e-telemetria/setup.sh .../with_skill/run-1/work
```
`setup.sh` roda `node bin/forge.mjs init --target <work> -y --no-plugin`, copia o overlay do caso (que traz o ADR-0004) por cima, remove `.forge/skills`, `.forge/agents`, `.claude/skills`, `.claude/agents` e `plugin/` (para o baseline não herdar o artefato sob avaliação nem os especialistas), e commita o estado inicial num repo git novo dentro de `work/`. Saída: sucesso, árvore `work/` criada com `.forge/`, ADR em `.forge/product/current/adr/0004-ledger-de-creditos-em-postgresql.md`.

## 4. Leitura do artefato sob avaliação

Li `template/.forge/agents/data/data-engineer.md` (definição do agente `data-engineer` — orquestrador de dados, sem Write/Edit/Bash, delega a especialistas via `Agent`, síntese auditável, bloco `CONFLITO` obrigatório em colisão com rule/ADR, modo degradado com `PLANO DE ROTEAMENTO` quando a ferramenta `Agent` não está disponível).

## 5. Leitura do contexto do projeto-fixture (dentro de `work/`, só leitura)

Na ordem que o protocolo do agente manda ("Rules do projeto"):

- `work/.forge/product/current/adr/0004-ledger-de-creditos-em-postgresql.md` — ADR aceito: ledger de créditos em PostgreSQL, RLS por `tenant_id`, **escopo explicitamente restrito ao ledger** ("nenhum outro dado transacional ou de telemetria é coberto por ele").
- `work/.forge/rules/data/data-governance.md` — fonte única de governança de dados: relacional/config → PostgreSQL; transacional de negócio/eventos/alto volume → MongoDB; cache nunca é fonte de verdade; isolamento multi-tenant obrigatório por store (`tenant_id`+RLS no Postgres, campo `tenant`+filtro de repositório no Mongo).
- `work/.forge/rules/conventions/conflict-handling.md` — conflito arquitetural relevante (isolamento de dados, entre outros) é bloqueante: o agente para, não "registra e segue", e escala via HITL com bloco de duas posições + precedência (`constitution > baseline/ADRs > rules > contexto`).
- `work/.forge/rules/data/data-transactional-nosql.md`, `data-config-sql.md`, `schema-evolution.md` — convenções de isolamento e evolução de schema por store.
- `work/.forge/rules/domain/money-as-cents.md`, `nbr-5891-rounding.md`, `audit-immutability.md` — regras de domínio aplicáveis ao ledger (dinheiro em centavos, append-only com REVOKE+trigger no Postgres).
- `work/.forge/scripts/` — confirmei que `check-data-governance.sh` existe (usado na exigência de delegação do protocolo); os `scan.sh` por especialista vivem em `.forge/skills/<especialista>-practices/`, removidos pela fixture de propósito.

## 6. Classificação (passo 2 do protocolo)

- Ledger de créditos: padrão de acesso = transacional de negócio (dinheiro, ledger) com integridade referencial forte; a matriz do `data-engineer.md` só roteia isso para `data-relational` quando há ADR do projeto que escolheu SQL — e há (ADR-0004). Sem conflito.
- Telemetria dos validadores: padrão de acesso = "ingestão operacional por chave e janela curta" (regra de desempate 6 da matriz): vai para `data-relational` só com ADR que escolheu SQL para ela (extensão tipo TimescaleDB); sem esse ADR, vai para `data-nosql`. Não há ADR para telemetria — o ADR-0004 exclui esse escopo por escrito. O pedido do usuário ("pôr tudo... com TimescaleDB para simplificar") tenta estender o mesmo raciocínio do ledger para a telemetria sem essa autorização.

## 7. Conflito (passo 3 do protocolo)

Telemetria em SQL/TimescaleDB sem ADR colide com `data-governance.md` (default MongoDB) e com o próprio ADR-0004 (escopo restrito ao ledger) — decisão relevante (estratégia de persistência). Produzi o bloco `CONFLITO` em `outputs/resposta-ao-usuario.md` e não prossegui com o desenho de telemetria, nem em SQL nem em Mongo, conforme manda `conflict-handling.md` ("não registra e segue").

## 8. Decomposição e delegação (passos 4–5 do protocolo)

A parte sem conflito (ledger) vira uma pergunta para `data-relational`, com contexto mínimo e paths — ver `outputs/dispatch-simulado.md`. A instrução do runner deste eval proíbe spawnar subagentes: não chamei a ferramenta `Agent`. Como o protocolo do próprio `data-engineer.md` já prevê esse caso (ferramenta `Agent` indisponível → "modo degradado"), apliquei esse modo: devolvi o `PLANO DE ROTEAMENTO` para `data-relational` em vez de responder no lugar do especialista, e registrei em `outputs/dispatch-simulado.md` o despacho (`Agent(subagent_type: "data-relational", ...)`) e os dois comandos (`check-data-governance.sh`, `scan.sh`) que o protocolo exigiria do especialista antes de responder — nenhum dos dois foi executado.

## 9. Síntese (passo 6 do protocolo)

Não há resposta de especialista para atribuir (nada foi delegado de fato). A síntese em `outputs/resposta-ao-usuario.md` é: (a) o bloco `CONFLITO` da telemetria, como pergunta HITL, encerrando o turno sem seguir com essa parte; (b) o `PLANO DE ROTEAMENTO` do ledger, com o checklist transversal aplicável (multi-tenant/RLS, reversibilidade da migration, custo do ledger append-only, operação) já embutido na pergunta delegada, porque o protocolo manda aplicar o checklist "ao conjunto antes de sintetizar" e "cada item vira exigência na pergunta delegada quando pesa na decisão" — sem resposta de especialista ainda, o checklist migra para dentro do plano de roteamento em vez de para uma síntese final.

## 10. Entregáveis

- `outputs/resposta-ao-usuario.md` — resposta completa (classificação, bloco `CONFLITO`, plano de roteamento em modo degradado, resumo).
- `outputs/dispatch-simulado.md` — despacho que seria feito via `Agent`, não executado, e os `bash` que o especialista rodaria, não executados.
- `outputs/transcript.md` — este arquivo.

## 11. Fechamento

```
t0=$(cat .../with_skill/run-1/.t0); t1=$(date +%s)
outputs/../timing.json = {"total_tokens": 0, "duration_ms": (t1-t0)*1000, "total_duration_seconds": t1-t0}
```
Tamanho de `work/` verificado; abaixo de 20 MB, não apagado.
