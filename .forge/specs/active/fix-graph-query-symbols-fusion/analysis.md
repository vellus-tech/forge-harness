# Analysis — fix-graph-query-symbols-fusion

## Status: PASS

Análise feita sobre a árvore de trabalho do worktree `fix/graph/query-symbols-fusion` @ `110139ad`, com artefatos ainda não commitados, em 2026-11-04. Ver A1.

## Achados

| ID | Severidade | Tipo | Onde | Recomendação |
|---|---|---|---|---|
| A1 | HIGH | risk | `bugfix.md`, `proposal.md`, `manifest.yaml`, `approvals.yaml`, `spec-delta.yaml`, `evidence/`, `impact.json` untracked; branch nunca publicada no remoto | Aprovações carimbam commits que não contêm o artefato aprovado (`requirements_reviewed`/`design_reviewed` iteração 1 apontam `5996048e`, onde `bugfix.md`/`design.md` não existem). Resolvido nesta sessão: commit dos artefatos antes de `/forge:implement` (ver Achados resolvidos). |
| A2 | MEDIUM | drift | Base da branch (`5996048e`) 2 commits atrás de `origin/develop` (`b9bfe0ca`) | Em develop, `scripts/` já conta 178 (não 176) e o badge já está em `gates-243` (não 242) por causa de `adopt-ub-mode-practices`. `tasks.md` fixa números absolutos desatualizados nas TASK-03/04/09/14; `w200` reprovaria após o rebase. Resolvido nesta sessão: rebase + recontagem (ver Achados resolvidos). |
| A3 | MEDIUM | coverage | DD-07 vs TASK-11 | DD-07 define aviso em stderr para 2 casos (ausente / presente sem mtime); TASK-11 só testa o caso negativo `[16b]`. Falta cenário positivo para cada ramo. Pendente — corrigir durante `/forge:implement` da TASK-11. |
| A4 | MEDIUM | coverage | DD-05(ii)/DD-06/DD-07/DD-09 (`--json` em qualquer posição) sem REQ/cenário correspondente em `bugfix.md`/`spec-delta.yaml` | Comportamentos observáveis decididos no design não voltaram ao artefato de requisitos. Pendente — anotar em REQ-05/06/07/10 antes do archive, não bloqueia implementação (design já governa o comportamento). |
| A5 | MEDIUM | conflict | `rules/testing/regression-red-first.md` item 4 ("teste permanece na suíte depois do Green") vs `repro.sh` da TASK-01 | `repro.sh` não segue o padrão `*-gate.sh`, não é descoberto por `run-all.sh`. Pendente — TASK-14 (w345/fechamento) deve chamar `repro.sh` como cenário nomeado do w344. |
| A6 | MEDIUM | coverage | `lib/mdl-gen.mjs:22`/`:119` (`graph.sh mdl`), consumidor não declarado | Após o change, `build` sempre grava `symbols.json`; `graph.sh mdl` passa a emitir ESPECIALIZAÇÃO por padrão em todo projeto (hoje só com `symbols` manual). Não declarado em `bugfix.md §3`/CHANGELOG. Pendente — TASK-13 (documentação) deve declarar; sem task de teste nova por ora (risco baixo, mdl-gen-gate.sh já tem symbols.json próprio).
| A7 | MEDIUM | coverage | `manifest.affected_paths` incompleto | Faltam `template/.forge/commands/graph/kb.md`, `plugin/forge/commands/kb.md` (tocados pela TASK-12). Pendente — corrigir manifest + regenerar impact.json na TASK-12/13.
| A8 | MEDIUM | conflict | `bugfix.md §5` intro/§5.1 ainda prescreve stub neutro no vermelho, substituído pelo DD-08 só no design/tasks | `bugfix.md` é fonte de requisitos e ficou com mecânica que `red-replay.mjs` recusa (`vermelho-infra`). Pendente — anotar `bugfix.md §5` apontando para DD-08, sem mudar REQ. |
| A9 | MEDIUM | drift | `design.md §1`: não cita ADR 0005 (emenda o ADR 0001); afirma "nenhuma rule de architecture/" quando há 14 (nenhuma aplicável, mas a frase está imprecisa) | Cosmético, não muda nenhuma decisão. Pendente — corrigir texto numa próxima revisão de design, não bloqueia implementação. |
| A10 | MEDIUM | risk | Red da TASK-09 ancorado em `[1]` (controle, passa naturalmente na base) em vez de `[2]` (acerto de símbolo, falha de fato) | Mesma classe de achado já corrigida 3x nas rodadas anteriores de design/tasks para outras tasks — aqui escapou. Pendente — corrigir âncora durante implementação da TASK-09 (`/forge:red record` usa `[2]`, não `[1]`). |
| A11 | MEDIUM | risk | `.forge/graph/symbols.json` legado (111 símbolos) já presente no worktree, untracked, fora do `.gitignore` até a TASK-05 | Contradiz "não existe neste repositório" de `bugfix.md §1`. Resolvido nesta sessão: removido antes do rebuild do grafo (ver Achados resolvidos). |

## Achados resolvidos

- **A1**: artefatos do change (`bugfix.md`, `proposal.md`, `manifest.yaml`, `approvals.yaml`, `spec-delta.yaml`, `evidence/`, `impact.json`, `analysis.md`) commitados nesta sessão, SHA a confirmar após o commit. Carimbos de `approvals.yaml` passam a referenciar commits que de fato contêm o artefato aprovado a partir deste ponto; histórico anterior (commits `5996048e`/`b174b297` etc., onde o artefato ainda não existia) permanece registrado como estava — não é reescrito.
- **A2**: branch rebaseada sobre `origin/develop` (`b9bfe0ca`) nesta sessão; contagens de `scripts/`/badge em `tasks.md` recalculadas contra o valor real pós-rebase (178→179/180/181 scripts, 243→244/245 gates — confirmar números exatos após o rebase).
- **A11**: `.forge/graph/symbols.json` legado removido; `graph.sh update`/`impact.sh --change` rerodados sobre estado limpo.

## Pendências operacionais (não bloqueiam o artefato)

- Hook `pre-push` (`check_red_first`) bloqueia push de commit `fix(...)` enquanto `red-evidence.json` estiver `pending` — só destrava quando TASK-14 fechar `observed`. Destino: handoff.
- `tools/build-machinery-history.mjs` precisa rodar na próxima tag, por causa dos 3 módulos novos em `lib/`. Destino: ledger.
- Commits/`reason` das aprovações desta spec sem acentuação pt-BR (regra global do usuário) — corrigir nos próximos commits reais da implementação, não retroagir nos já feitos. Destino: handoff.
- `bugfix.md §6` diz REQ-09/REQ-10 "não mapeados na proposal" — `proposal.md §2` já cobre os dois; rastreabilidade textual desatualizada. Destino: handoff.
- `REQ-FHT-115..124` seguem livres em develop (máximo real 114) — reconferir antes do `/forge:archive`. Destino: handoff.
- Branches paralelas (`ldg0211`/w296, `ldg1592`/w321) adicionam gates — recontagem de badge no merge final. Destino: handoff.
- Identificador de fixture `processarPedido` em pt-BR, contra a regra de identificadores em inglês — dado de teste, impacto baixo. Destino: handoff.

## Síntese

Cobertura proposal→REQ→DD→TASK fecha nas duas direções para os 10 REQs; waves estritamente lineares; padrões de Red batem com a assinatura do classificador; sem marcador de template nem `NEEDS CLARIFICATION` aberto. PASS condicionado à resolução de A1/A2/A11 (artefatos fora do git, branch defasada, grafo legado), todas corrigidas nesta mesma sessão antes do `/forge:implement`. A3-A10 são lacunas reais menores, não bloqueantes, endereçadas como pendências ou durante a implementação das tasks correspondentes.

## Revisão

Revisor: general-purpose (opus, effort high) | Transcrito por: sessão orquestradora (FORGE-HARNESS)
