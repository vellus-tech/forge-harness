# Analysis — add-liaison-native-bridge

## Status: PASS

## Achados

| ID | Severidade (BLOCKER/HIGH/MEDIUM) | Tipo (coverage/conflict/drift/risk) | Onde | Recomendação |
|---|---|---|---|---|
| A-01 | HIGH | risk | design §2.7 (recusa por ancestral `claude`); TASK-12 | Resolvido na rodada 2: lógica de escrita testada pela API de `native-allowlist.mjs`, recusa do CLI à parte, CLI completo uma vez com `env -i` e `ps` de fixture no `PATH` (contorno declarado, coerente com "a recusa não é fronteira"). |
| A-02 | HIGH | conflict | REQ-05 critério 2 e REQ-06 × design §2.5 | Resolvido: emendas datadas nas Notas do REQ-05 e do REQ-06, com origem no gate `design_reviewed`. |
| A-03 | HIGH | conflict | design §10 × constitution §9 | Resolvido: TASK-27 cria o ADR no baseline antes da TASK-26. |
| A-04 | HIGH | risk | TASK-22/23 (ledger tronco × branch) | Resolvido: ledger da branch com `FORGE_ROOT=<worktree>`, afastamento da rule `machinery-propagation` declarado na TASK-23; `.forge/ledger/` e `.forge/product/current/adr/` no `affected_paths`. |
| A-05 | MEDIUM | coverage | REQ-11 e checklist de superfície | Resolvido: `pin` e `containment` no REQ-11 e na tabela; linha do REQ-11 acrescentada. |
| A-06 | MEDIUM | drift | design §9 × tasks | Resolvido: nomes sem ordinal, linhas do `native-containment-wiring-gate.sh` e do `native-readers-gate.sh`, nota de divisão. |
| A-07 | MEDIUM | drift | design §2.7 (`hook-unwired`) | Resolvido: detector usa o wrapper exportado `preToolUseWiring`; derivação `unresolved` (manifesto corrompido) vira rc 2 (TASK-12). |
| A-08 | MEDIUM | risk | design §2.4 passo 3 | Resolvido: `FORGE_CLAUDE_PROJECTS_DIR` para fixtures, sem redirecionar `HOME`. |
| A-09 | MEDIUM | risk | preâmbulo das tasks | Resolvido: execução estritamente sequencial; vermelho esperado do `w200` até a TASK-25 declarado. |

## Pendências operacionais (não bloqueiam o artefato)

- Commitar as emendas de fase com `impact.json`, `.forge/graph/` e este `analysis.md` antes de `/forge:implement` — destino: handoff (feito no commit desta análise).
- Reconferir `impact-freshness` depois do commit, porque o `manifest.yaml` ganhou dois `affected_paths` — destino: handoff.
- `last_reviewed` das duas rules de liaison pendente — destino: TASK-23.

## Síntese (2-3 linhas)

Cobertura proposal → REQ → design → TASK fechada nas duas direções, sem drift contra o repositório real nem conflito G1; checagens determinísticas limpas (data-governance OK, impact `fresh`, validate-spec sem WARN SRF-01). Os quatro HIGH e cinco MEDIUM da rodada 1 foram corrigidos nos artefatos de fase; as três notas de convergência da rodada 2 (`unresolved` no detector, justificativa do ledger na branch, item do ADR aceito resolvido) foram incorporadas às tasks.

## Revisão

Revisor: general-purpose (claude-opus-5-5), rodadas 1 e 2 | Transcrito por: sessão orquestradora do change
