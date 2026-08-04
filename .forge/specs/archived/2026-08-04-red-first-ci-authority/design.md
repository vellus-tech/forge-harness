# Design — red-first-ci-authority

## Decisão central

O replay já existe e já é executado sempre (`ensure`, sem cache — Onda E). O que falta não é
capacidade de execução: é **onde** a execução que vale acontece. Este change não reescreve o motor;
acrescenta um ponto de entrada que varre o repositório inteiro e um lugar para chamá-lo.

## Alternativas consideradas

**(a) Um script novo `red-ci.sh`.** Descartada: duplicaria a resolução de `FORGE_ROOT`, o teto de
tempo e o tratamento de `node` ausente que `red-evidence.sh` já faz. Duas fontes para a mesma
política é como o `base_strategy` acabou duplicado entre validador e schema nesta mesma semana.

**(b) Subcomando `ci` no `red-evidence.sh`.** Escolhida. O parser de argumentos exige
`<change-id>` para todo subcomando; `ci` é a exceção deliberada — **não** aceita change-id, porque
quem escolhe o escopo tem de ser o estado do repositório. Um `ci --change X` daria ao autor a
capacidade de apontar o CI para o change que lhe convém.

**(c) Rodar `ensure` dentro do job de gates existente.** Descartada para consumidores: mistura o
veredito de Red-first com o da suíte do projeto, e um projeto sem suíte configurada perderia o
gate junto. Neste repositório o step vive no `ci.yml` porque a suíte e o harness são a mesma coisa.

## Fluxo

```
red-evidence.sh ci
  └─ para cada .forge/specs/active/*/manifest.yaml com type: bugfix
       ├─ red-evidence.sh ensure <id>     (executa o replay; nunca falha o script)
       └─ check-red-first.sh check <id>   (decide: observed|waived passam; resto reprova)
  └─ agrega: lista de (change, veredito) + exit 0/1
```

`ensure` continua sendo o que executa e `check-red-first` continua sendo o que decide — a mesma
divisão de `spec-verify.sh`. O subcomando novo é uma varredura em volta deles, não uma terceira
opinião.

## Fronteira do que isto fecha

Fecha: **ambiente controlado pelo autor** (o runner é definido pelo workflow, não pela máquina de
quem escreve) e **cache local** (execuções isoladas não têm entre o que cachear).

Não fecha, e a rule passa a dizer isso: **comando declarado arbitrário** (o `command` continua
vindo do artefato que o autor escreve), **defeito introduzido no próprio PR** e **waiver
inverificável**. Os três exigem revisão humana. Registrar a fronteira importa mais que o ganho:
um gate que parece fechar mais do que fecha é pior que a ausência do gate, porque desliga a
revisão que ainda é necessária.

## Impacto

- `template/.forge/scripts/red-evidence.sh` — subcomando `ci`.
- `.github/workflows/ci.yml` — step novo, depois do `npm ci`.
- `template/github/workflows/red-first.yml` — workflow para consumidores.
- `installer/install.sh` e `bin/forge.mjs` — materialização em paridade.
- `template/.forge/rules/testing/regression-red-first.md`, `template/.forge/commands/quality/red.md`.
- `tests/w109-red-ci-gate.sh` — gate novo.

Nenhum caminho existente muda de comportamento: `verify`, `archive` e pre-push continuam como estão.
