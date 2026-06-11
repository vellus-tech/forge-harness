# Plano Mestre de Execução — Forge Project Harness

| | |
|---|---|
| **Versão** | 1.1 |
| **Data** | 2026-06-10 |
| **Autor** | Milton Silva |
| **Status** | Aprovado para desenvolvimento |
| **Fonte de verdade** | `docs/refer/forge-project-harness.md` (v3.1, Aprovado) |
| **Escopo** | Plano de execução de todo o projeto: Fase 0 (pré-trabalho) + MVPs 1–5 + Fase 8 (qualidade, pilotos e rollout) |

> **Convenção.** Corpo em português brasileiro; nomes de artefatos, scripts e código em inglês. Cada plano detalhado vive em `docs/plans/0N-*.md`. Este master plan consolida visão geral, mapeamento, sequência, marcos e riscos.

---

## 1. Sumário Executivo

O projeto evolui o `/init-project` atual (template `~/.claude/templates/project-bootstrap/`, 87 arquivos) para o **Forge Project Harness**: harness SDD agnóstico de agente, raiz `.forge/`, fonte canônica `FORGE.md`, interface `AGENTS.md` gerada, lifecycle `active → archived`, baseline de produto, adaptadores gerados e camada de qualidade quantitativa.

A execução segue **5 MVPs + Fase 0 (pré-trabalho) + Fase 8 (qualidade/pilotos/rollout)**, decompostos em **24 waves** com dependências explícitas e gates deterministas — aplicando ao próprio projeto a disciplina que o Forge prescreve (§17.2 do doc de referência).

**Decisões de execução já tomadas (2026-06-10):**

1. **Estrutura de planos:** master + 1 arquivo por MVP (este diretório).
2. **Dogfooding:** a partir do MVP2 (wave W2.0), o tracking de execução migra de `docs/plans/` para `.forge/specs/active/create-forge-project-harness/` (manifest, waves.json, progress.json, deferrals.json) — o workspace vira o primeiro consumidor do harness.
3. **Git completo desde a Fase 0:** `git init`, branch `develop` como integração, `feature/<wave-id>` por wave, espelhando §20.1. GitHub Actions (se/quando houver remote) só em promoção para `staging` (§20.2).

---

## 2. Layout do Workspace

O repo `forge-harness` é o **repositório do template Forge** — não um projeto que usa o Forge (até o dogfooding do MVP2). Estrutura-alvo:

```text
forge-harness/
├── docs/
│   ├── refer/forge-project-harness.md   # fonte de verdade (v3.1)
│   └── plans/                           # estes planos
├── snapshot/                            # Fase 0: referência congelada (read-only por convenção)
│   ├── project-bootstrap/               # cópia fiel do template atual (87 arquivos)
│   ├── init-project.md                  # cópia do comando atual
│   ├── MANIFEST.sha256                  # 88 entradas (arquivo + hash)
│   └── path-inventory.txt               # inventário das 979 refs (290 .claude/ + 689 docs/product)
├── contracts/
│   └── claude-adapter-contract.md       # contrato de compatibilidade Claude (Fase 0)
├── template/                            # o que /forge:init instala num projeto-alvo
│   ├── .forge/                          # árvore canônica completa (§8 do doc)
│   ├── gitignore.patch                  # paths locais (§20)
│   └── github/workflows/staging.yml     # CI econômico (§20.2)
├── installer/
│   └── forge-init.md                    # novo comando /forge:init (sucessor do init-project.md)
├── tools/
│   └── rewrite-paths.sh                 # mapa determinista de reescrita de paths (uso interno)
└── tests/
    ├── fixtures/{greenfield,brownfield,feature-only}/
    ├── snapshot/                        # verify-manifest.sh + claude-contract.bats
    └── *.bats                           # suíte por MVP (bats-core)
```

---

## 3. Reconciliação: Fases (§22) ↔ MVPs (§23) ↔ Backlog (§24)

| Fase (§22) | Conteúdo | MVP dono | Itens do backlog (§24) |
|---|---|---|---|
| **Fase 0** — Congelar snapshot | snapshot, inventário de paths, contrato Claude, teste de snapshot | pré-MVP1 (waves W0.x) | sem item dedicado (**L1**) — absorve parte de #5 e #20 |
| **Fase 1** — `.forge` canônico | FORGE.md, forge.yaml, context.md, migração de rules/agents/commands/skills/hooks/doctor | **MVP1** | #1*, #2, #3 (parcial), #7, #8 |
| **Fase 2** — Adapter Claude | sync-adapters, gerar `.claude/**`, des-hardcodar paths | **MVP1** | #4, #5 |
| **Fase 3** — AGENTS.md + multi-adapters | projeção AGENTS.md, symlinks, Codex/Qwen/Kiro/`.agents/skills` | **MVP1** (W1.4 — ver I1) | #6 |
| **Fase 4** — Lifecycle active/archive | spec new, manifests, verify, close | **MVP2** | #9, #10 |
| **Fase 5** — Baseline de produto | product/current, schemas, archive, publish-docs | **MVP3** | #3 (schemas), #11, #12, #13, #14 |
| **Fase 6** — Brownfield graph | inventário mínimo, graph, impact, onboard | **MVP4** (inventário lite antecipado p/ MVP2/W2.3) | #15 |
| **Fase 7** — Dev Loop & Quality | shard, loops builder→validator, eval harness, meta-eval | **MVP5** | #16, #17 (ver I2), #18, #19 |
| **Fase 8** — Qualidade e testes | fixtures, suíte, pilotos, delegação do template global | transversal + waves W8.x | #20, #21, #22 |

\* O item #1 (criar a spec `create-forge-project-harness`) é executado na W2.0, quando `/forge:spec new` passa a existir (dogfooding).

### 3.1 Inconsistências do documento e resoluções adotadas

- **I1 — Fase 3 sem MVP dono.** O §23.1 (MVP1) cobre `AGENTS.md` + symlinks, mas os adaptadores Codex/Qwen/Forge CLI/Kiro/`.agents/skills` (Fase 3, item #6) não constam de nenhum MVP. **Resolução:** viram a wave **W1.4** do MVP1, paralela à W1.3, entregue após o gate de compatibilidade Claude — sem bloquear o início do MVP2.
- **I2 — Loop builder→validator citado em dois lugares.** O §23.2 (MVP2) exige `/forge:requirements` e `/forge:design` **com** loop; a Fase 7 (§22.8) e o item #17 colocam os loops no Dev Loop & Quality. **Resolução:** o mecanismo (builder + validator + relatório `[MISS]/[CONFLICT]/[CLARIFY]` + max 3 iterações) entra no **MVP2** — os agentes validadores já existem no template atual. O MVP5 apenas o **mede** (meta-avaliação). O item #17 é satisfeito no MVP2.
- **I3 — Comandos do §14 sem MVP atribuído.** `status`, `clarify`, `analyze`, `implement`, `constitution`, `adr new`, `backlog`. **Resolução:** `status` → MVP1 (W1.3); `clarify`/`analyze`/`implement` → MVP2 (W2.1/W2.2); `constitution`/`adr new`/`backlog` → MVP3 (W3.3).
- **I4 — Itens v3 fora do backlog.** O backlog de 22 itens é herdado da v2 e não absorveu `/forge:wave`, `/forge:progress`, `/forge:defer`, `/forge:resolve-deferrals`, `/forge:c4`, `/forge:dev` nem os hooks Git da §20.4. **Resolução (alocação):** wave/progress/defer/resolve-deferrals + skills especialistas (§17.7) → **MVP5** (W5.1); c4 + overview.html (§16.5) → **MVP4** (W4.3); `/forge:dev` + hooks pre-commit/pre-push/post-merge/worktree-guard + `staging.yml` → **MVP1** (W1.3).
- **L1 — Fase 0 sem item de backlog.** Tratada como item 0 implícito: git init + snapshot + contrato + teste de snapshot (waves W0.1–W0.3).
- **L2 — `runners.yaml` na raiz `.forge/` (§8) mas só usado no MVP5.** Criado como **stub** no MVP1 (W1.0) para a árvore ficar estável; implementação real na W5.2.
- **L3 — `rejected` fora da state machine (§10.7).** Os estados laterais (§12), o `/forge:close` (§13) e a tabela §14.2 usam `rejected`, mas as transições formais da §10.7 não o incluem. **Resolução:** o `archive-state-machine.schema.json` (W3.0) adiciona transições para `rejected` a partir dos estados com gate de revisão (`proposed`…`tasks-ready`), mantendo as transições da §10.7 como subconjunto válido.

### 3.2 Rastreabilidade do backlog (§24, itens 1–22)

| Item | Wave | Item | Wave | Item | Wave | Item | Wave |
|---|---|---|---|---|---|---|---|
| #1 | W2.0 | #7 | W1.1 | #13 | W3.2 | #19 | W5.3 |
| #2 | W1.0 | #8 | W1.1 | #14 | W3.3 | #20 | W8.0 (+bats por MVP) |
| #3 | W1.0+W3.0 | #9 | W2.0 | #15 | W2.3+W4.1/W4.2 | #21 | W8.1+W8.2 |
| #4 | W1.2 | #10 | W2.2 | #16 | W5.0 | #22 | W8.3 |
| #5 | W0.2/W0.3+W1.2 | #11 | W3.0 | #17 | W2.1 | | |
| #6 | W1.4 | #12 | W3.0 | #18 | W5.2 | | |

---

## 4. Sequência de Execução e Caminho Crítico

```text
W0.1 → W0.2 → W0.3
  → W1.0 → W1.1 → W1.2 → { W1.3 ∥ W1.4 }
  → W2.0 → W2.1 → W2.2 ( ∥ W2.3 )
  → W3.0 → W3.1 → { W3.2 ∥ W3.3 }
  → W4.0 → W4.1 → { W4.2 ∥ W4.3 }
  → W5.0 → W5.1 → W5.2 → W5.3
  → W8.0 → W8.1 → W8.2 → W8.3
```

Dependências cruzadas relevantes: W5.2 (eval harness) depende também de W1.4 (runners precisam dos adapters) e W3.1 (validadores); W5.3 depende de W2.1 (loops a medir).

**Caminho crítico:** `W1.1 (migração + rewrite das 290 refs .claude/) → W1.2 (sync-adapters) → W3.2 (archive/delta apply)`. São as três entregas onde erro custa mais caro; o restante é paralelizável ou adiável. Em particular, **W4.3 (`/forge:c4`) e `/forge:dev` são desacopláveis** e podem ser adiados para v0.2 sem quebrar a DoD dos MVPs 1–3.

---

## 5. Decisões Técnicas de Implementação

1. **Linguagem dos scripts — bash como entry point; Node ≥20 para dados estruturados.** Gates de uma linha, hooks, doctor, validate-frontmatter e wrappers: **bash** (consistente com o template atual; zero dependências no projeto-alvo). Operações sobre YAML/JSON (sync-adapters, delta apply, validação de schema, atualização de waves/progress/deferrals.json): **arquivos `.mjs` únicos** em `.forge/scripts/lib/`, sem build step — alinhado ao Forge CLI (Node/TS) e evitando a dependência Python que o doc rejeita no Spec Kit. Os entry points da §8 (`sync-adapters.sh`, `archive-spec.sh`, …) permanecem `.sh` e delegam ao `.mjs` quando precisam de parsing real. Artefatos críticos de máquina preferem JSON; YAML fica para arquivos editados por humanos.
2. **sync-adapters dirigido por manifesto + lockfile.** Cada `adapters/<a>.yaml` declara `generates`, `supports`, mapeamentos de path e regras de rewrite; o script copia/transforma, grava `source_hashes` em `<a>.lock.yaml` e o `doctor` detecta drift por sha256. Symlink primeiro; cópia materializada com header §7.4 como fallback. **Idempotência é requisito testado** (rodar 2× = diff vazio).
3. **Reescrita de paths por mapa determinista, nunca manual — e faseada.** `tools/rewrite-paths.sh` com tabela explícita derivada do `path-inventory.txt` (W0.2) + gate grep-negativo pós-migração. **No MVP1 (W1.1) o mapa cobre apenas as 290 refs `.claude/*`; as 689 refs `docs/product` são preservadas** — o pipeline atual continua escrevendo lá, exigência do contrato de compatibilidade (§22.1) e da regra §8.1 (`product/current/` só é alterado pelo archive, que nasce no MVP3). A transição de `docs/product` é semântica e faseada: MVP2/W2.1 (commands de spec passam a escrever no change ativo, §22.5) e MVP3/W3.3 (agents reescritos contra baseline/change, §22.6). Casos especiais nominais: `settings.json` (`$CLAUDE_PROJECT_DIR/.claude/hooks/...` → gerado pelo adapter apontando `.forge/hooks/`), `doctor.sh` (recalcular `ROOT` para o novo nível de diretório), `enforce-worktree-location.sh` (`.claude/worktrees` → `.forge/worktrees`).
4. **Schemas — JSON Schema draft 2020-12**, validados com `ajv` (dev-dependency apenas do workspace; no projeto-alvo a validação roda via `lib/validate.mjs` vendorizado).
5. **Archive (delta apply) com dry-run obrigatório.** Carregar baseline + delta, aplicar em memória, validar resultado contra `baseline-capability.schema.json`, só então gravar (write-temp + rename atômico) e mover a pasta. `modify_requirement` = substituição integral (§10.4). Transições verificadas contra `archive-state-machine.schema.json` antes de qualquer escrita.
6. **Testes — bats-core + fixtures + snapshot (shift-left).** Cada MVP entrega seus bats junto; a Fase 8 consolida. Fixtures como mini-repos versionados. O teste de snapshot da Fase 0 é guarda permanente de compatibilidade Claude. Testes que exigem LLM (loops, eval) têm camada **estrutural** determinista (artefatos/schemas/exit codes) rodando sempre, e camada **semântica** manual nos pilotos (W8.1/W8.2).
7. **Graph (MVP4):** recomendação default — subset local (AST determinista + LLM só para summaries), decisão formalizada por ADR na W4.0 conforme critérios da §22.7.

---

## 6. Git e Dogfooding

- **W0.1:** `git init`; commit inicial (docs) em `main`; criar `develop` como branch de integração. Trabalho por wave em `feature/<wave-id>` (ex.: `feature/w1.1-migracao-87-arquivos`), merge em `develop` após gate da wave. Sem co-autoria de IA em commits.
- **Promoção/staging:** aplica-se quando houver remote + pipeline; até lá, `develop` é a integração e os gates locais carregam a verificação (espírito da §20.2).
- **Dogfooding (a partir da W2.0):** criar `.forge/specs/active/create-forge-project-harness/` no próprio workspace com `manifest.yaml` (type: greenfield, rigor: spec-anchored, scale: 3), e migrar o tracking das waves restantes para `waves.json`/`progress.json`/`deferrals.json`. Os planos em `docs/plans/` permanecem como referência de planejamento; o estado vivo passa a ser o change ativo. Pendências entre waves usam o ledger (`/forge:defer`) assim que existir; antes disso, seção "Pendências" no plano do MVP corrente.

---

## 7. Marcos e Definition of Done por MVP

| Marco | DoD (resumo) | Verificação end-to-end |
|---|---|---|
| **M0 — Fase 0** | Workspace git; snapshot congelado com MANIFEST; contrato Claude aprovado (HITL); bats do contrato passa contra o snapshot | `tests/snapshot/verify-manifest.sh` → OK |
| **M1 — MVP1** | Árvore `.forge` completa instala via `/forge:init`; zero refs `.claude/` na fonte canônica; `AGENTS.md` gerado + 3 symlinks; adapter Claude passa o contrato; sync idempotente com lockfiles; doctor detecta drift; adapters Codex/Qwen/agents-skills/Kiro com smoke verde | Fixture greenfield: `init` → `doctor` exit 0 → **teste manual obrigatório em Claude Code real** (commands/agents/skills/hook funcionando) |
| **M2 — MVP2** | `spec new` cria change válido por schema; requirements/design com loop (≤3 iterações, escalonamento HITL); verify grava `verification.{md,yaml}`; close move sem tocar baseline; discover-lite gera manifest; spec de dogfooding ativa | Fixture feature-only percorre `spec new → … → verify` (estado final alcançável no MVP2); `close` coberto em spec separada (`abandoned` a partir de `tasks-ready`, §10.7); bats cobre transições proibidas |
| **M3 — MVP3** | 4 schemas + validadores §19.1–19.4 com casos PASS/FAIL; archive com pré-flight §13.1 completo, dry-run, apply, move e index; publish-docs espelha sem virar fonte | Cenário canônico §8.1 (`add-card-tokenization`/REQ-TOK-001) roda por script; archive com tasks incompletas é recusado |
| **M4 — MVP4** | graph build/validate/query/impact/onboard na fixture brownfield; update incremental por fingerprint; c4 + overview.html | Diff conhecido → `impact` lista paths esperados; `validate graph` verde; pré-flight do archive consome impact |
| **M5 — MVP5** | shard gera stories válidas; waves/progress/deferrals operados só por scripts; projeto não fecha com deferral aberto; eval A/B com `grading.json` schemado + mean±stddev; optimize com holdout por test score; um caso de meta-avaliação completo | Sessão longa simulada: shard → wave plan → 2 waves com 1 deferral → resolve-deferrals → DONE; eval real de uma skill existente |
| **M8 — Release v0.1.0** | `tests/run-all.sh` 100%; pilotos greenfield e brownfield com um change arquivado cada; `/init-project` global delegando ao Forge; tag `v0.1.0` | Diff de hashes entre instalação via comando global e `template/` taggeado = vazio |

---

## 8. Riscos de Execução (além da §25 do doc)

| Risco | Impacto | Mitigação |
|---|---|---|
| Resíduos sutis na reescrita das 979 refs de path — 290 `.claude/` (mecânicas, W1.1) + 689 `docs/product` (semânticas, MVPs 2–3) — em exemplos dentro de rules, YAML do AGENTS.md, settings.json | Alto — adapter aponta para arquivo inexistente e falha silenciosamente | Inventário por arquivo (W0.2); rewrite por mapa determinista; gate grep-negativo permanente no `validate-harness`; reescrita de `docs/product` caso a caso (saída → change ativo; leitura → baseline); casos especiais tratados nominalmente |
| Referências cruzadas entre os 87 arquivos quebrarem com migração parcial | Médio | W1.1 é **wave atômica** (rules → agents → commands → skills/hooks), gate só no fim; nunca entregar `.forge/` parcial |
| Drift entre template global (`~/.claude/templates/`) e workspace durante o desenvolvimento (Milton segue usando `/init-project` em projetos reais) | Alto — duas fontes de verdade temporárias | Snapshot congelado define a base; mudança no template global durante o projeto é proibida ou replicada via PR no workspace; `verify-manifest.sh` denuncia divergência; delegação só na W8.3 |
| Migração do YAML de identidade (AGENTS.md → FORGE.md §9) quebrar o protocolo de bootstrap de identidade dos agents | Médio | Mapeamento de campos documentado (W1.0); o `AGENTS.md` gerado mantém bloco YAML compatível; assert no contrato Claude |
| Symlinks (`CLAUDE.md → AGENTS.md`) mal suportados em Windows/ferramentas da equipe | Médio | Fallback de cópia já previsto (§25); adicionalmente `doctor` verifica equivalência por hash e `sync-adapters` rematerializa |
| Namespace `/forge:*` mudar o nome invocável dos 8 commands atuais, quebrando hábito/automação | Baixo/Médio | Wrappers temporários com nomes antigos (previstos na §22.1) gerados pelo adapter com aviso de deprecação; remoção só após W8.3 |
| Escopo do MVP5 inflar com itens v3 não orçados no backlog | Médio — atraso do release | Alocação explícita feita (I4); `c4` e `dev` são desacopláveis e adiáveis para v0.2 sem quebrar DoD dos MVPs 1–3 |
| Testes dependentes de LLM não-determinísticos (loops, eval, pilotos) | Médio | Camada estrutural (determinista, sempre) vs semântica (pilotos manuais); gates sempre em exit code |
| `doctor.sh`/hooks assumirem profundidade de diretório antiga após mover para `.forge/scripts|hooks` | Baixo | Caso nominal na W1.1; bats dedicado executando os scripts do novo local |

---

## 9. Índice dos Planos Detalhados

| Plano | Escopo | Waves |
|---|---|---|
| [01-mvp1-forge-canonico.md](01-mvp1-forge-canonico.md) | Fase 0 + Fases 1–3 (MVP1) | W0.1–W0.3, W1.0–W1.4 |
| [02-mvp2-spec-lifecycle.md](02-mvp2-spec-lifecycle.md) | Fase 4 (MVP2) + dogfooding | W2.0–W2.3 |
| [03-mvp3-baseline-archive.md](03-mvp3-baseline-archive.md) | Fase 5 (MVP3) | W3.0–W3.3 |
| [04-mvp4-brownfield-graph.md](04-mvp4-brownfield-graph.md) | Fase 6 (MVP4) + C4 | W4.0–W4.3 |
| [05-mvp5-devloop-quality.md](05-mvp5-devloop-quality.md) | Fase 7 (MVP5) + itens v3 | W5.0–W5.3 |
| [06-qualidade-piloto-rollout.md](06-qualidade-piloto-rollout.md) | Fase 8 + release | W8.0–W8.3 |
| [guardrail-governanca-dados.md](guardrail-governanca-dados.md) | Guardrail de conflito de fontes (G1–G4) + fonte da verdade de dados — **CONCLUÍDO 2026-06-11** (gates gw1/gw2/gw3) | GW.1–GW.3 |

> Os planos `0N` cobrem os MVPs originais. `guardrail-governanca-dados.md` é um change adicional originado no piloto azim-crm (achado 2026-06-11), registrado na fila para execução após o MVP4.

---

## Controle de versão do documento

- Milton Silva - 2026-06-10 - Versão 1.0: plano mestre inicial derivado do doc de projeto v3.1.
- Milton Silva - 2026-06-10 - Versão 1.1: review crítico — corrigidas contagens reais (8 commands; 979 refs = 290 `.claude/` + 689 `docs/product`); reescrita de paths faseada (MVP1 só `.claude/`, preservando compatibilidade §22.1/§8.1); E2E do MVP2 corrigido (termina em `verified`; close testado à parte); adicionada lacuna L3 (`rejected` fora da state machine §10.7). Aprovado para desenvolvimento.
