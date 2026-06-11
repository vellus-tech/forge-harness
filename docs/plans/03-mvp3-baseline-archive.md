# Plano MVP3 — Baseline + Schemas + Archive

| | |
|---|---|
| **Versão** | 1.1 |
| **Data** | 2026-06-10 |
| **Status** | Aprovado para desenvolvimento |
| **Fases do doc** | Fase 5 (§22.6) |
| **MVP** | MVP3 (§23.3) |
| **Depende de** | MVP2 (W2.2) |
| **Backlog (§24)** | #3 (schemas restantes), #11, #12, #13, #14 + comandos de governança (resolução I3) |

## Objetivo

Implementar a operação central do Forge: o **baseline de produto** (`.forge/product/current/` em capabilities com IDs estáveis) e o **archive com delta apply determinista** — a mudança verificada é incorporada ao baseline e a pasta vira histórico. Inclui os validadores deterministas da §19 e os comandos de governança documental.

## Escopo

**Inclui:** schemas de delta/capability/traceability/state-machine, estrutura `product/current/` e `published/`, validadores §19.1–19.4, `/forge:archive` completo, ingestão de `docs/product/` legado, `/forge:publish-docs`, `/forge:adr new`, `/forge:constitution`, `/forge:backlog`.

**Não inclui:** `forge validate graph` (§19.5 — MVP4), impact no pré-flight (entra como ponto de integração no MVP4/W4.2).

---

## Waves

### W3.0 — Schemas do baseline

- **Objetivo:** contratos machine-readable do archive.
- **Entregáveis:**
  - `schemas/spec-delta.schema.json` (§10.4) — operações `add_requirement`, `modify_requirement` (**substituição integral**, nunca patch parcial), `remove_requirement` (com reason + migration), `add_contract`.
  - `schemas/baseline-capability.schema.json` (§10.5) — capability com requirements (id, title, normative, scenarios Given/When/Then, contracts, tests) + history.
  - `schemas/traceability.schema.json` — requisitos → design → tasks → evidências.
  - `schemas/archive-state-machine.schema.json` (§10.7) — estados, transições, gates, exceções (`archived` só após `verified`, salvo `close`). **Inclui as transições para `rejected`** a partir dos estados com gate de revisão (`proposed`…`tasks-ready`) — fechamento da lacuna L3 do master plan (`rejected` é usado em §12/§13/§14.2 mas ausente das transições formais da §10.7).
  - Templates: `spec-delta.yaml`, `traceability.yaml`, `approvals.yaml` (§10.10), `verification.yaml`.
  - `templates/product/` (§8): templates da unidade de baseline — capability `spec.yaml` (§10.5), entrada de `CHANGELOG.md`, ADR.
  - Estrutura `template/.forge/product/current/{capabilities,prd,frd-nfrd,ddd,trd,adr,glossary}/` + `CHANGELOG.md` + `product/published/`.
- **Depende de:** W2.2
- **Gate:** os exemplos canônicos do doc de referência (§10.4, §10.5, §10.10) validam contra cada schema (ajv).

### W3.1 — Validadores deterministas (§19.1–19.4)

- **Objetivo:** checagens objetivas e reprodutíveis, complementares aos loops probabilísticos.
- **Entregáveis (em `.forge/scripts/`):**
  - `validate-harness.sh` (§19.1): FORGE.md existe; AGENTS.md é projeção válida; symlinks/cópias corretos; forge.yaml válido; adapters batem com manifest; **paths `.claude` não vazam na fonte canônica** (gate permanente da W1.1); lockfiles batem com hashes; smokes dos adapters.
  - `validate-spec.sh` **completo** (§19.2): manifest válido; artefatos exigidos por tipo e scale; headings obrigatórios; requirements com cenários/testabilidade; sem placeholders; status coerente; traceability coerente; `spec-delta.yaml` válido quando a spec atualiza baseline.
  - `validate-archive.sh` (§19.3): estado `verified`; spec-delta/approvals/verification presentes e válidos; baseline resultante válido antes de gravar; ausência de mudança em `docs/product/` sem origem em `product/current/`.
  - `validate-frontmatter.sh` (§19.4): **consolidação** do script antecipado na W1.1 (onde foi gate da migração) — integração à suíte, casos PASS/FAIL por regra, checagem de corpo idealmente < 500 linhas.
- **Depende de:** W3.0
- **Gate:** suíte bats dos validadores com casos **PASS e FAIL por regra** (cada regra tem pelo menos um caso negativo).

### W3.2 — Archive com delta apply — **caminho crítico**

- **Objetivo:** a operação que dá sentido ao lifecycle (§13).
- **Entregáveis:**
  - `.forge/scripts/archive-spec.sh` + `lib/delta-apply.mjs`, implementando a operação da §13.2:
    1. Validar change ativo (pré-flight §13.1 completo: manifest válido, sem `NEEDS CLARIFICATION`, tasks 100%, verification presente, approvals quando `human_gate_required`, traceability válida, checks executados ou justificados, contract tests p/ mudança de contrato, aprovação humana explícita p/ domínio regulado).
    2. Ler e validar `spec-delta.yaml`.
    3. **Dry-run:** aplicar deltas em memória, sem gravar.
    4. Validar o baseline resultante contra `baseline-capability.schema.json`.
    5. Aplicar em `product/current/capabilities/**` (write-temp + rename atômico; `modify` = substituição integral).
    6. Atualizar PRD/FRD/NFRD/TRD/DDD agregados quando o manifest indicar impacto.
    7. (Ponto de integração MVP4: atualizar graph se código mudou.)
    8. Registrar archive metadata.
    9. Mover para `specs/archived/YYYY-MM-DD-<change-id>/`.
    10. Atualizar `archived/index.yaml` + `product/current/CHANGELOG.md`.
  - `/forge:archive <change-id>` — com gate HITL `human_archive_approval` (AskUserQuestion §12.1).
  - Ingestão de `docs/product/` existente em repos legados **sem apagar nada** (§22.6): importar para `product/current/` preservando o original.
  - Estados laterais completos da §12 (`reopened`, `rolled-back`, `superseded`) registrados na state machine; rollback formal documentado (reversão de deltas + entrada no CHANGELOG).
- **Depende de:** W3.1
- **Gate (bats):** archive com tasks incompletas → `FAIL` com mensagem clara; archive válido → baseline contém o requisito novo, pasta movida, index e CHANGELOG atualizados; dry-run que falha na validação **não deixa nenhum arquivo modificado**.

### W3.3 — Docs e governança (paralela a W3.2)

- **Objetivo:** visibilidade humana e comandos de governança (resolução I3).
- **Entregáveis:**
  - `/forge:publish-docs` — espelha `product/current/` → `docs/product/` (publicação gerada, nunca fonte; §8.2).
  - `/forge:adr new` — ADR em `product/current/adr/`.
  - `/forge:constitution` — cria/atualiza `constitution.md`.
  - `/forge:backlog` — gera backlog/Jira/GitHub Issues **após gate humano** (§14.4).
  - **Reescrita semântica das refs `docs/product` remanescentes** (parte das 689 do inventário W0.2 que sobrou após W2.1) nos agents/rules de specification — caso a caso, usando o `path-inventory.txt`: saída de pipeline → change ativo; leitura de estado vigente → `product/current/`. Gate grep: nenhuma ref `docs/product` na fonte canônica fora de `publish-docs` e das rules que descrevem a publicação humana.
- **Depende de:** W3.0
- **Gate:** `validate-archive` detecta mudança em `docs/product/` sem origem no baseline (round-trip de publish é íntegro).

---

## Definition of Done do MVP3

1. 4 schemas + templates YAML criados; exemplos canônicos do doc validam.
2. Validadores §19.1–19.4 com casos PASS/FAIL testados por regra.
3. `/forge:archive` executa pré-flight §13.1 completo, dry-run, apply atômico, move e index.
4. `/forge:close` e `/forge:archive` cobrem juntos todos os fins de vida da §12.
5. `publish-docs`/`adr`/`constitution`/`backlog` funcionais.

## Verificação end-to-end

- **Cenário canônico da §8.1, literal:** change `add-card-tokenization` com `spec-delta.yaml` adicionando `REQ-TOK-001` à capability `tokenization`; após `/forge:archive`, `product/current/capabilities/tokenization/spec.yaml` contém REQ-TOK-001 com cenário SCN-TOK-001-A, history referencia o change, e a pasta está em `specs/archived/YYYY-MM-DD-add-card-tokenization/`.
- Fixture brownfield com `docs/product/` legado: ingestão preserva o original e popula `product/current/`.
- Dogfooding: arquivar o primeiro sub-change real do próprio workspace (ex.: um change pequeno de documentação) para exercitar o fluxo fora de fixture.

## Notas de execução (2026-06-11 — MVP3 code-complete)

- **Reescrita semântica das refs `docs/product` remanescentes (W3.3) ADIADA** com decisão registrada: (a) o piloto azim-crm usa ativamente o pipeline scale-4 sobre `docs/product` — reescrever os 35 agents agora quebraria o piloto; (b) é trabalho semântico caso a caso que merece revisão humana (mesmo padrão da revisão W1.5); (c) o dual-read exige baseline populado, que só agora começa a existir. O gate da W3.3 (round-trip do publish íntegro) foi entregue; a reescrita vira sub-wave própria (sugerida: W3.3b com HITL) antes do MVP5. Mitigação já ativa: `validate-archive` flagra qualquer edição manual em `docs/product` pós-publish.
- **Decisões de implementação:** remove = remoção física + note no history (não tombstone); semver bump por capability (remove: major; add: minor; modify/contract: patch; capability nova nasce 0.1.0 sem bump); `add_contract` exige capability+requirement_id para apply determinista; approvals.schema v2 aceita a forma legada §10.10 via oneOf (exemplo canônico do doc valida).
- **Descobertas do dogfooding real** (change `baseline-spec-lifecycle` arquivado no workspace — baseline ganhou a capability `spec-lifecycle` com REQ-SLC-001/002): bug do parser yaml-lite com retorno a lista externa após listas aninhadas (corrigido com pilha de listas); `FORGE_ROOT` padronizado em TODOS os scripts de spec (dados no root alvo; templates/config na instalação); guards para FORGE.md/CHANGELOG ausentes (baseline criado on-demand).
- **validate-frontmatter endurecido:** `description` obrigatória em todo arquivo com frontmatter (era só skills).

## Controle de versão do documento

- Milton Silva - 2026-06-10 - Versão 1.0: plano inicial do MVP3.
- Milton Silva - 2026-06-10 - Versão 1.1: review crítico — state machine inclui `rejected` (lacuna L3); adicionados `templates/product/` (§8) e a reescrita semântica das refs `docs/product` remanescentes na W3.3 (com gate grep); `validate-frontmatter` corrigido para consolidação (script nasce na W1.1). Aprovado para desenvolvimento.
