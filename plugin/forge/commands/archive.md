---
description: Incorpora um change VERIFICADO ao baseline — pré-flight §13.1, dry-run, delta apply atômico (modify = substituição integral), move para archived e atualiza index/CHANGELOG. Gate HITL human_archive_approval.
argument-hint: "<change-id>"
---

# /forge:archive — incorporar o change ao baseline

Argumentos: `$ARGUMENTS` (change-id obrigatório; liste os ativos `verified` se ambíguo).

## 1. Preparação do delta

Pré-condição: status `verified`. Confira se `spec-delta.yaml` existe e carrega o **payload estruturado** (`requirement:` na forma da capability) em toda op `add/modify` — sem ele o apply determinista recusa. Se faltar, construa-o agora a partir do artefato de requirements (id/title/normative/scenarios/contracts/tests) e valide com `bash .forge/scripts/validate-spec.sh <change-id>`.

## 2. Gate HITL — `human_archive_approval` (§12.1)

Apresente via `AskUserQuestion` um resumo de 2-3 linhas do delta (capabilities afetadas, nº de ops por tipo, version bumps esperados): **Approve** / **Review** / **Reject** / **Block**.

```bash
bash .forge/scripts/approval-log.sh <change-id> --gate human_archive_approval --decision <decision> [--reason "<motivo>"] --scope "spec-delta.yaml"
```

Só prossiga com **Approve** (o pré-flight verifica o gate no manifest).

## 3. Execução (determinista)

```bash
bash .forge/scripts/budget-preflight.sh --stage archive --change <change-id> --outputs product/current/CHANGELOG.md,evidence/runs
```

```bash
bash .forge/scripts/archive-spec.sh <change-id>
```

O script roda: pré-flight §13.1 → dry-run em memória (falha = **nada** é gravado) → apply atômico em `product/current/capabilities/**` → metadata + move para `specs/archived/YYYY-MM-DD-<change-id>/` → `archived/index.yaml` + `product/current/CHANGELOG.md` + `run-manifest/v1` dentro da pasta arquivada.

## 4. Relatório e publicação

2-3 linhas: capabilities atualizadas (+versões), pasta de histórico, entrada do CHANGELOG. Ofereça `/forge:publish-docs` para refletir o baseline em `docs/product/` (publicação gerada — §8.2).

## Conflito no índice (README/index)

`archived/index.yaml` (e qualquer ADR README tocado pelo delta) é **append-only por natureza** —
em conflito de merge, a resolução correta é **união das entradas** dos dois lados (nunca
`git checkout --ours`/`--theirs` cego, que descarta entradas de um dos lados silenciosamente),
seguida de reordenação por número/data e revalidação de que a numeração/sequência ficou
consistente. Ver detalhamento em `.forge/commands/docs/adr.md`.

## Pós-archive (procedimentos formais — §12)

- **reopened:** divergência/regressão descoberta → exige motivo, baseline afetado e **nova spec corretiva** (ou rollback). Registre a decisão em `approvals.yaml` da pasta arquivada e abra o change corretivo.
- **rolled-back:** reversão formal → aplicar o delta inverso via novo change (`modify`/`remove` espelhados), arquivá-lo, e marcar o original como `rolled-back` com entrada no CHANGELOG. Nunca editar o baseline à mão.
