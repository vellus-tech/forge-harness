---
description: Checkpoint review guiado do change implementado — confere REQ a REQ contra o código, roda os checks do FORGE.md via script, grava verification.md + verification.yaml + run-manifest/v1 e (após HITL) transiciona para verified.
argument-hint: "[<change-id>]"
---

# /forge:verify — verificação do change

Argumentos: `$ARGUMENTS` (change-id opcional; sem argumento, use o único change ativo).

Pré-condição: status `implemented` (tasks 100% `[X]`). Em `implementing`, a metade determinista vai falhar por tasks abertas — termine `/forge:implement` primeiro.

## 1. Metade determinista (script)

```bash
bash .forge/scripts/budget-preflight.sh --stage verify --change <change-id> --outputs verification.yaml,evidence/runs
```

```bash
bash .forge/scripts/spec-verify.sh <change-id>
```

O script confere tasks completas, roda os checks do `FORGE.md runtime:` (test/typecheck/lint, timeout 300s, logs em `/tmp/forge-verify-*`) e grava `verification.yaml` (§10.10) + `evidence/runs/*/run-manifest.json`. `FAIL` → corrija e re-rode antes de prosseguir (leia só o `tail -20` dos logs).

## 2. Checkpoint review guiado (sua parte)

Releia requirements/design/tasks do change e confirme **contra o código real**:

- cada `REQ-NN` (ou invariante do refactor / regressão do bugfix): implementado onde? testado por quê? — spot-check de código e teste, não confiança no tracker;
- critérios de aceite verificáveis: verificados (rode-os quando executáveis);
- comportamento "fora de escopo"/"inalterado" preservado;
- desvios entre design e implementação: listar (desvio não é necessariamente erro — é registro).

Grave `verification.md` no change:

```
# Verification — <change-id>
## Resultado: APROVADO | RESSALVAS | REPROVADO
## Evidências por requisito
| REQ | Implementado em | Verificado por | Status |
## Checks deterministas
(resumo do verification.yaml + paths dos logs)
## Desvios e observações
```

## 2.5. Spec delta — autoria com o contexto quente (§10.4)

O script da etapa 1 já gerou um **esqueleto** de `spec-delta.yaml` (determinista: REQ-NN do artefato de requirements + `affected_capabilities` do manifest; nunca sobrescreve delta já autorado). Sua parte é preencher os payloads **agora** — você acabou de conferir requirements × código REQ a REQ, e o delta é subproduto direto dessa conferência (deixá-lo para a sessão de archive obriga alguém a reconstruir tudo frio):

- confirme a `op` de cada entrada (`add_requirement` vs `modify_requirement` — modify é **substituição integral**, nunca patch parcial) e a `capability` alvo;
- substitua todo marcador `<scaffold: ...>` por conteúdo real: `scenarios` given/when/then observáveis, `tests` com os paths dos testes que acabou de conferir, `contracts` quando houver;
- valide: `bash .forge/scripts/validate-spec.sh <change-id>`;
- commite o `spec-delta.yaml` junto com `verification.md`/`verification.yaml`.

Marcadores `<scaffold: ...>` remanescentes **bloqueiam a transição para `verified`** (o `validate-spec` reprova a partir desse status) e o pré-flight do archive — o gate `human_archive_approval` continua lá; o que muda é que a *autoria* do delta acontece aqui. Se o change não altera o baseline (raro — ex.: bugfix puramente comportamental já coberto pela spec), remova o arquivo e registre o porquê em `verification.md`.

## 3. Gate HITL — `implementation_verified` (§12.1)

`AskUserQuestion` (resumo 2-3 linhas: resultado, checks, desvios, delta pronto?): **Approve** / **Review** / **Reject** / **Block**.

```bash
bash .forge/scripts/approval-log.sh <change-id> --gate implementation_verified --decision <decision> [--reason "<motivo>"] --scope "verification.md"
```

- **Approve** → `bash .forge/scripts/spec-transition.sh <change-id> verified`. Informe o fim de ciclo atual: o archive (`/forge:archive`, aplica deltas ao baseline) chega no MVP3 — até lá o change permanece `verified`, ou encerra via `/forge:close --reason superseded`.
- **Review** → corrija conforme o motivo (pode reabrir `/forge:implement` para tasks novas) e re-rode este comando.
- **Reject**/**Block** → registre e pare.

## Modo autônomo (--yolo)

Se `autonomy.mode: yolo` (`forge.yaml`) ou `--yolo` na invocação, este gate não para no `AskUserQuestion`: invoque o agent `yolo-gate` (model **opus**, effort **high**) sobre `verification.md`/`verification.yaml` — ele confere REQ a REQ contra o código, decide (approve/review/reject/block) e registra em `approvals.yaml` com `autonomous: true` via `approval-log.sh --autonomous`. Falhas de execução continuam parando (não são gates). Ver `.forge/rules/conventions/autonomy-yolo.md`.
