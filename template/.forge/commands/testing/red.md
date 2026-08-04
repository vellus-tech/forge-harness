---
description: Protocolo Red-first de correção de defeito (rule testing/regression-red-first.md) — init escaffolda a evidência num change bugfix já existente (saída para brownfield), record declara o teste que reproduz o bug (test-path, test-id, command e failure-pattern obrigatórios), replay roda o motor real (worktree git efêmero, um teste, timeout explícito) e converte a declaração em evidência observada, waive dispensa com motivo tipado quando o Red for genuinamente inviável.
argument-hint: "init|record|replay|waive|status <change-id> [flags]"
---

# /forge:red — evidência de Red em correção de defeito

Argumentos: `$ARGUMENTS`. Sem subcomando, mostra `status` do change ativo.

> Vale só para changes `type: bugfix`. `evidence/red/red-evidence.json` nasce em
> `status: pending` no scaffold (`/forge:spec new --type bugfix`) — este comando é o único
> caminho para movê-lo. Ver `.forge/rules/testing/regression-red-first.md` para a norma
> completa e `bugfix.md §5` para o protocolo dentro do change.

## init — escaffoldar evidência num change já existente (saída para brownfield)

```bash
bash .forge/scripts/red-evidence.sh init <change-id>
```

Cria `evidence/red/red-evidence.json` (`status: pending`) quando o change `type: bugfix` já
existe mas nunca recebeu o scaffold — harness atualizado por cima de um change em andamento, ou
o arquivo apagado à mão. É a saída correta para esse caso: `/forge:spec new --type bugfix` cria
um change **novo**, não adiciona evidência a um já existente. Idempotente — no-op se o arquivo já
existir; falha se o change não existir ou não for `type: bugfix`.

## record — declarar o teste que reproduz o defeito

```bash
bash .forge/scripts/red-evidence.sh record <change-id> \
  --test-path <path/do/teste> --test-id "<nome do caso>" \
  --command "<comando que roda só esse teste>" \
  --failure-pattern "<regex ou substring esperada na falha>" \
  [--fix-files "arq1,arq2"] [--setup-command "<comando executado antes do teste no worktree>"] \
  [--reproduces "bugfix.md §1"] [--excerpt "<trecho, se já observou manualmente>"]
```

Grava a intenção — **nunca** marca `observed` sozinho. `status` fica (ou volta a) `pending` até
um `replay` bem-sucedido. `--test-path`, `--test-id`, `--command` e `--failure-pattern` são
**todos obrigatórios** (schema `red-evidence/v1`): sem `test_id`, a derivação da árvore base não
consegue ancorar no caso específico (só no arquivo de teste inteiro); sem `failure_pattern`, o
item 4 da rule nunca fica avaliável — campo ausente seria indistinguível de "gate desligado".

## replay — rodar o motor e observar de verdade

```bash
bash .forge/scripts/red-evidence.sh replay <change-id> [--timeout <segundos, default 120>]
```

Este é o passo que converte "presumido" em "observado" — sem ele a evidência é só uma
declaração que qualquer agente poderia fabricar. O motor (`lib/red-replay.mjs`):

1. **Deriva a árvore pré-correção** (nunca pergunta): ANCESTRY quando o commit que adicionou o
   teste é ancestral do commit de correção (fluxo TDD normal — bug, depois teste, depois fix);
   REVERT-SYNTHESIS quando teste e correção estão no mesmo commit (squash) — reverte só os
   `fix_files` num worktree em HEAD, mantendo o teste; NOT-POSSIBLE quando nenhuma das duas
   resolve (nunca trava mudo — vira um veredito válido que pede `waive`).
2. **Roda UM teste** — o `command` declarado, nunca a suíte — num worktree git efêmero, com
   timeout explícito, sempre limpo ao final (sucesso ou erro).
3. **Exige, para `observed`**: falha na base (exit≠0) + classificação `behavioral` (não
   `build-error`) + saída casando com `failure_pattern` quando declarado + passagem em HEAD
   (exit 0). Qualquer ausência vira `FAIL` com o item da rule citado, e a evidência **volta**
   para `pending` (nunca fica um `observed` falso na árvore).

Saídas: `OK replay` (grava `observed` + `base_commit`/`classification`/`excerpt`/
`excerpt_sha256`/`replayed_at`) · `FAIL replay (item N) — <motivo>` (volta a `pending`, exit 1)
· `NOT-POSSIBLE replay — <motivo>` (grava `not-possible`, exit 1 — próximo passo é `waive`).

## ci — a execução de referência, num runner que o autor não controla

```bash
bash .forge/scripts/red-evidence.sh ci
```

Varre **todo** change ativo `type: bugfix`, roda `ensure` em cada um e aplica o check estático,
agregando o veredito num exit code. É o que o workflow `red-first.yml` executa em cada pull
request — e é ele, não o `red-evidence.json` commitado, que decide se o Red foi observado.

Não aceita `<change-id>`, deliberadamente: quem define o escopo é o estado do repositório. Um
`ci --change X` devolveria a quem invoca a capacidade de apontar a verificação para o change que
lhe convém, que é o grau de controle que rodar no CI existe para tirar.

Change ativo de outro tipo é ignorado e repositório sem bugfix ativo sai `0` — ausência de
correção de defeito não é falha. O runner precisa de histórico completo (`fetch-depth: 0`) para o
motor derivar a árvore pré-correção, e das dependências instaladas antes, porque o worktree
efêmero nasce sem elas.

Saídas: `OK ci — N change(s) …` · `FAIL ci — …` com uma linha `OK`/`FAIL` por change verificado.

## status — one-liner não-bloqueante

```bash
bash .forge/scripts/red-evidence.sh status <change-id>
```

## waive — dispensar com motivo tipado

```bash
bash .forge/scripts/red-evidence.sh waive <change-id> --reason <motivo> [--note "<texto>"]
```

| `--reason` | Quando | Efeito |
|---|---|---|
| `non-behavioral` | Typo, copy, config, documentação | Recusado automaticamente se o diff tocar código presente no grafo |
| `no-test-infra` | Brownfield sem suíte utilizável | Abre deferral + dívida técnica no ledger |
| `external-unreproducible` | Depende de terceiro indisponível | Abre deferral |
| `hotfix-under-incident` | Incidente em produção, correção antes do teste | Deferral com `blocks: [archive]` |

Delega para a política já implementada em `check-red-first.sh waive` (Onda B) — uma fonte só de
regra de waiver, sem reimplementação aqui.

## Regras

- Não invente um teste para "passar no gate" — uma declaração fabricada é pior que a ausência
  declarada (mente para o próximo leitor). Prefira `waive` com motivo honesto.
- `replay` é caro (worktree + execução real) — nunca roda no `pre-push` (só o check estático,
  `check-red-first.sh`). Você o invoca aqui de forma explícita; `/forge:verify` e a transição
  para `verified` (`validate-spec.mjs`) chamam o mesmo motor por baixo via `red-evidence.sh
  ensure` — **sempre**, incondicionalmente, para todo change `type: bugfix`, sem ler `status` do
  artefato para decidir se executam. `ensure` não é um subcomando pensado para uso manual (por
  isso fora do `argument-hint` acima); ele existe para que nenhum `status: observed` sobreviva
  sem um replay real por trás, mesmo que o JSON tenha sido editado à mão.
- O resíduo honor-system que nenhum script fecha: que o motivo da falha seja **semanticamente**
  o defeito relatado, não uma quebra adjacente que por acaso casa com o padrão declarado. Isso
  continua sendo responsabilidade de quem escreve e de quem revisa.
