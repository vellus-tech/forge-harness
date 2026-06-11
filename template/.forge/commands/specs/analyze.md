---
description: Análise cross-artifact do change ativo (proposal × requirements × design × tasks × constitution/rules) antes de implementar. Obrigatória em scale ≥ 3. Não altera artefatos — produz analysis.md.
argument-hint: "[<change-id>]"
---

# /forge:analyze — análise cross-artifact

Argumentos: `$ARGUMENTS` (change-id opcional; sem argumento, use o único change ativo).

Pré-condição: status `tasks-ready`. Obrigatória em **scale ≥ 3** antes de `/forge:implement`; recomendada em scale 2.

## Protocolo

Leia TODOS os artefatos do change + `.forge/constitution.md` + `.forge/rules/` aplicáveis e cruze:

1. **Cobertura ponta a ponta:** proposal §2 → REQ → design § → TASK. Liste qualquer elo quebrado nas duas direções (mudança sem task; task sem origem).
2. **Conflitos:** entre artefatos do change; entre o change e constitution/rules; entre tasks (paths que colidem em waves paralelas).
3. **Drift:** afirmações no design que contradizem o repo real (paths/contratos citados existem?); `affected_paths`/`affected_capabilities` do manifest coerentes com as tasks.
4. **Fases puladas:** se o scale exige fase ausente, confira `quick_plan` (enabled + justificativa) — ausente → achado bloqueante.
5. **Riscos operacionais:** tasks sem critério de verificação; dependências externas sem fallback; ausência de tasks de teste para REQs críticos.

## Saída

Grave `analysis.md` no change com:

```
# Analysis — <change-id>
## Status: PASS | FAIL
## Achados
| ID | Severidade (BLOCKER/HIGH/MEDIUM) | Tipo (coverage/conflict/drift/risk) | Onde | Recomendação |
## Síntese (2-3 linhas)
```

No chat: apenas o Status + contagem por severidade + próxima ação (BLOCKER → resolver antes de `/forge:implement`; sem BLOCKER → `/forge:implement` liberado). Não despeje a tabela no chat (§17.6).

## Regras

- **Não corrija nada** neste comando — achados são insumo; correções acontecem nos comandos de fase (ou via Review no gate correspondente).
- Sem transição de estado (analyze é checkpoint, não fase).
