# Analysis — deepspec-provenance (scale 3)

> Cross-artifact retroativo. Substitui `/forge:analyze`/`/forge:impact` (grafo não materializado na
> raiz do harness-source). Baseado na auditoria factual (sonnet, ferramentas reais) que precedeu este
> retrofit — não presume, testa.

## Consistência REQ ↔ design ↔ tasks

| REQ | Design | Task | Status |
|---|---|---|---|
| REQ-01 | §2.1 | TASK-01 | OK |
| REQ-02 | §2.1 | TASK-01 | OK |
| REQ-03 | §2.2 | TASK-02 | OK |
| REQ-04 | §2.2 | TASK-02 | OK |
| REQ-05 | §2.3 | TASK-03 | OK |
| REQ-06 | §2.3 | TASK-03 | OK |
| REQ-07 | §2.4 | TASK-04 | OK |
| REQ-08 | §2.4 | TASK-04 | OK |
| REQ-09 | §2.5 | TASK-03 | OK |
| REQ-10 | §2.5 | TASK-04 | OK |
| REQ-11 | §2.6 | TASK-03 | OK |
| REQ-12 | §4 | TASK-05/06 | OK |

Sem REQ órfão, sem task sem rastreio.

## Evidência da auditoria prévia (não re-derivada aqui)

- `npm test`: PASS=40 FAIL=0 (gates w90-w93 + suíte existente).
- Segurança: nenhum caminho persiste diff bruto; teste w90 injeta segredo real e confirma ausência.
- Integração real (não só prosa): `spec-verify.sh`/`archive-spec.sh` de fato chamam
  `run-manifest.sh write` + `validate-stage-contract.sh check`.
- `--set` restrito a 3 scripts (run-manifest/budget-preflight/benchmark-eval), sem vazamento.
- Documentação presente em 5 arquivos (CHANGELOG, doc de referência, catálogo, README×2, help do bin).

## Impacto (manual)

- **`validate-harness.sh`** — agora falha se contratos/schemas novos estiverem ausentes/inválidos;
  afeta todo projeto que roda o gate geral do harness. Mitigado: os artefatos são distribuídos junto
  (overlay de `forge update` traz `contracts/`/`schemas/` novos automaticamente).
- **`spec-verify.sh`/`archive-spec.sh`** — comportamento bloqueante novo (falha de contrato aborta).
  Risco de quebrar projetos legados sem os artefatos esperados pelo contrato — mitigado por contratos
  tolerantes (design §6) e cobertos pelo gate w91.
- **Plugin** — 5 comandos existentes modificados, contagem inalterada (51); `plugin-sync-gate` verde.

## Ordem de execução / dependências

TASK-01 → TASK-02 → TASK-03 → TASK-04 → TASK-05 → TASK-06, todas sequenciais (cada wave depende da
anterior). Sem ciclo. Já executadas nessa ordem (commits reais seguem essa sequência).

## Riscos residuais

Ver design §6. Nenhum bloqueia verify — já mitigados no código existente e cobertos por teste.
