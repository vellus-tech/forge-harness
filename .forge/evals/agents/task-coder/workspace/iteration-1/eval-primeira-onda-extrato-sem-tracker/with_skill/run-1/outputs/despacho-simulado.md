# Despacho de subagentes que seria feito (não executado — regra do eval proíbe spawn)

O `task-coder` real invocaria specialists via Agent tool para TASK-01, TASK-02 e TASK-04. Nesta execução de eval o despacho foi **simulado**: o próprio task-coder implementou o código diretamente, seguindo o payload que enviaria a cada specialist.

## TASK-01 — Implementar filtrarPorPeriodo

- **Specialist:** `frontend-engineer`
- **Motivo da escolha:** `arquivos_esperados` aponta para `apps/web/extrato-web/src/filtro.ts` — match direto da regra 3.2.2 (`apps/web/**`, `*.ts`) → frontend.
- **Payload resumido:**
  - `task_id`: TASK-01
  - `module`: extrato-web
  - `branch`: feat/extrato-web/wave-1
  - `files_expected`: apps/web/extrato-web/src/filtro.ts (criar), apps/web/extrato-web/src/filtro.test.ts (criar)
  - `requirements_refs`: Req 1.1, Req 1.2
  - `context_paths`: docs/product/modules/extrato-web/requirements.md, docs/product/modules/extrato-web/design.md, .forge/rules/conventions/code-style.md, .forge/rules/domain/money-as-cents.md, .forge/rules/testing/tdd.md
  - `commit_policy`: commit atômico "feat(extrato-web): TASK-01 — filtro por período", sem push, sem co-autoria de IA
  - `test_policy`: TDD-first; build + testes locais verdes antes de commitar

## TASK-02 — Escrever 3 testes: filtro não depende de rede nem de armazenamento

- **Specialist:** `frontend-engineer`
- **Motivo da escolha:** TASK sem `arquivos_esperados` explícito (o `tasks-writer` só descreveu os testes, sem path — falha apontada no §3.2.3 do agente). Regra de fallback: como não há match direto em 3.2.2, aplica-se a stack-dominante do módulo, calculada por contagem de artefatos em `apps/web/extrato-web/` (`.ts`/`.tsx`) vs. `services/**/*.cs` (zero) vs. `apps/android/**` (zero) → stack-dominante = `frontend`. Logo, `frontend-engineer` — **não** `fullstack-software-engineer`, que seria o erro comum de cair direto no "sem path → fullstack" sem checar a stack-dominante primeiro.
- **Path assumido para os testes** (decisão do task-coder, já que a TASK não declarou um): os 3 testes foram colocados dentro de `apps/web/extrato-web/src/filtro.test.ts`, junto dos testes de aceite de TASK-01, em vez de um arquivo `filtro.rede-armazenamento.test.ts` separado — decisão de escopo mínimo, já que os 3 testes exercitam a mesma função `filtrarPorPeriodo` e o design.md não pede separação por arquivo. Registrado aqui para o humano confirmar/corrigir se preferir separação.
- **Payload resumido:**
  - `task_id`: TASK-02
  - `requirements_refs`: Req 1.3
  - `context_paths`: mesmos de TASK-01
  - `commit_policy`: "test(extrato-web): TASK-02 — testes de pureza do filtro"
  - `test_policy`: cada teste precisa falhar de fato se a implementação chamar fetch/localStorage/mutar entrada (não apenas "parecer" cobrir isso)

## TASK-04 — Implementar exportarCsv (adiantada da Wave 2)

- **Specialist:** `frontend-engineer`
- **Motivo da escolha:** `arquivos_esperados` aponta para `apps/web/extrato-web/src/csv.ts` — mesmo match direto de TASK-01.
- **Nota:** adiantada fora do fechamento formal da onda 1, a pedido explícito do usuário ("se sobrar tempo"). Não dispara `sprint-orchestrator` nem fecha a Wave 2 — falta uma TASK de encerramento da Wave 2 em `tasks.md`, que só tem TASK-04 declarada.

## TASK-03 — Encerramento da Wave 1

Não dispara specialist — tratada pelo próprio `task-coder` (§3.2.4 do agente: título contém "Encerramento" + "build verde + commit"). Ação real seria: `npm run typecheck && npm test`, depois commit da Wave 1 fechada e handoff a `sprint-orchestrator` para abrir PR. Nesta execução de eval, o build/typecheck foi rodado de verdade (ver transcript.md); commit, push e invocação de `sprint-orchestrator` foram apenas simulados/registrados, por proibição explícita do harness de eval.
