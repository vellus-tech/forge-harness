# Transcript — eval-grada-ab-revisao-migracao / with_skill / run-1

## Bootstrap

1. `cd <worktree-do-eval> && pwd && git branch --show-current` — confirmou diretório e branch `chore/evals-skills-agentes` conforme esperado pelo prompt.

## Preparação

2. `date +%s > .../run-1/.t0` — registrou instante inicial.
3. `mkdir -p .../run-1/work .../run-1/outputs`.
4. `bash .../fixtures/grada-ab-revisao-migracao/setup.sh .../run-1/work` — exit 0. Materializou um projeto fixture completo (git repo, `.forge/`, `AGENTS.md`, `CLAUDE.md`, `.claude/settings.json`) dentro de `work/`.

## Leitura da definição do agente

5. Li `template/.forge/agents/quality/grader.md` (agente `eval-grader`, modelo sonnet, ferramentas Read/Write). Protocolo: para cada caso de teste e cada expectativa, avaliar baseline e variant **separadamente**, sem ancoragem cruzada, com `passed` booleano e `evidence` (trecho literal, mínimo 5 palavras, ou declaração explícita de ausência). Regra: expectativa ambígua = `passed: false`. Não corrigir outputs, só avaliar. Validar `grading.json` contra `schemas/grading.schema.json` antes de gravar.
6. Li `template/.forge/schemas/grading.schema.json` (somente leitura) — confirmei que `test_cases[].expectations[]` é uma lista de `{text, passed, evidence}` sem campo para distinguir baseline/variant. Como o protocolo do agente exige avaliação separada de baseline e variant por expectativa, usei o prefixo `[baseline]` / `[variant]` no campo `text` de cada entrada para preservar a distinção dentro do schema existente (decisão registrada aqui por não haver campo dedicado no schema).

## Insumos do caso

7. Li `work/.forge/evals/skills/revisao-migracao-postgres/evals.json` — 2 casos (TC-01, TC-02), 3 expectativas cada.
8. Li `work/.forge/evals/skills/revisao-migracao-postgres/workspace/iteration-1/eval-1/results.json` — outputs de baseline e variant para os dois casos, com `duration_ms`, `tokens`, `exit_code`.

## Avaliação (ceticismo: "passou" exige evidência explícita no texto, não intenção)

### TC-01 (índice em `validacoes.cartao_id`)

- Baseline não menciona lock, `CONCURRENTLY` ou bloqueio de escrita em nenhum momento — texto só sugere renomear o índice. As três expectativas de TC-01 falham para baseline.
- Variant aponta explicitamente o lock `SHARE` e o bloqueio de INSERT/UPDATE (expectativa 1 = passa), propõe `CREATE INDEX CONCURRENTLY` fora de transação via `flyway:executeInTransaction=false` (expectativa 2 = passa).
- Expectativa 3 ("Rodou o squawk... e reportou o resultado") — o variant diz apenas "vou rodar o squawk... para confirmar" — é **intenção futura**, não execução realizada nem resultado reportado. Marquei `passed: false` mesmo para o variant, por rigor com o texto literal da expectativa (verbo no passado + resultado reportado, nenhum dos dois presente no output).

### TC-02 (drop de `codigo_legado`)

- Baseline alerta corretamente sobre quebra de rolling deploy (expectativa 1 = passa) e recomenda separar em duas releases (expectativa 2 = passa), mas não menciona verificar dependências (view/índice/constraint) antes do drop (expectativa 3 = falha).
- Variant cobre as três expectativas, incluindo a checagem explícita via `pg_depend` e `information_schema.view_column_usage` (expectativa 3 = passa).

## Agregado

- `baseline_pass_rate` = 2/6 = 0.3333333333333333
- `variant_pass_rate` = 5/6 = 0.8333333333333334
- `delta_pass_rate` = 0.5
- `baseline_duration_mean_ms` = (4000+5000)/2 = 4500; `variant_duration_mean_ms` = (6100+6500)/2 = 6300; `delta_duration_ms` = 1800
- `baseline_tokens_mean` = (310+330)/2 = 320; `variant_tokens_mean` = (540+610)/2 = 575; `delta_tokens` = 255

## Gravação e validação

9. Escrevi `work/.forge/evals/skills/revisao-migracao-postgres/workspace/iteration-1/eval-1/grading.json`.
10. Validei com `python3 -c "jsonschema.validate(...)"` contra `template/.forge/schemas/grading.schema.json` — resultado: `VALID`.

## Subagentes

O agente `eval-grader` (grader.md) não instrui spawn de subagentes — é um papel único que lê `results.json` e grava `grading.json` diretamente. Nenhum despacho de subagente foi necessário; nada a registrar em `outputs/dispatch.md`.

## Entregáveis copiados para `outputs/`

- `.forge/evals/skills/revisao-migracao-postgres/evals.json` (insumo, cópia para referência)
- `.forge/evals/skills/revisao-migracao-postgres/workspace/iteration-1/eval-1/results.json` (insumo, cópia para referência)
- `.forge/evals/skills/revisao-migracao-postgres/workspace/iteration-1/eval-1/grading.json` (entregável, validado contra o schema)

## Fechamento

11. `du -sh work` para checar o limite de 20 MB antes de decidir se apago `work/`.
