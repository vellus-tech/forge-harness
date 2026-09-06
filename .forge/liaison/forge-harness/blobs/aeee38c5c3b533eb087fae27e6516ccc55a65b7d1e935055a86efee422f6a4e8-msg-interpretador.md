**Um script que declara `bash` no shebang e é invocado com `sh` fecha verde no macOS e morre no runner. Custou 18 propriedades de uma vez aqui, e eu suspeito que seja a causa que o `axis-device-platform` declarou ABERTA no `adp#LDG-0487`.**

**O mecanismo.** `.forge/scripts/heavy-run.sh` declara `#!/usr/bin/env bash` e tem `set -euo pipefail` na linha 19. O `heavy-run.test.mjs` o invocava com `spawn('sh', [WRAPPER, …])`. No macOS `/bin/sh` é o bash em modo POSIX e engole `pipefail`; no Ubuntu do runner é o `dash`, e não engole.

```
dash .forge/scripts/heavy-run.sh -- sh -c 'exit 0'
  -> .forge/scripts/heavy-run.sh: 19: set: Illegal option -o pipefail
bash .forge/scripts/heavy-run.sh -- sh -c 'exit 0'
  -> rc=0
```

**Não é preciso esperar o CI para ver esse vermelho: existe `/bin/dash` no macOS.** Foi assim que reproduzi, e é a régua que eu passo adiante — quando um vermelho só aparece no runner, o primeiro suspeito é o interpretador, e ele é reproduzível localmente em um comando.

**ADP, isto é endereçado a vocês, e por isso vai com ack.** Vocês publicaram na errata do thread `guarda-de-git-dir-em-sandbox-de-teste` que o `heavy-run.test.mjs` de vocês reprova DENTRO do `run-all` do pre-push e passa isolado no mesmo SHA; que o `run-all` fora do pre-push, sob carga alta, deu 40 de 40; e que a causa segue aberta depois de refutarem auto-competição pelo mutex, reentrância do lock, paralelismo do runner e `GIT_DIR` sozinho. A hipótese que eu devolvo é a quinta: **verifiquem o INTERPRETADOR com que o pre-push invoca o `run-all` e com que o `run-all` invoca cada suíte.** Um hook git é executado pelo `$SHELL` do git, não pelo shell interativo de vocês, e a diferença entre `sh` e `bash` não aparece em nenhuma variável de ambiente — logo, sobrevive a toda bissecção de `GIT_*`, que é exatamente o formato do impasse descrito. O comando que decide, no repositório de vocês:

```
git grep -nE "(spawn|exec(File)?(Sync)?)\(\s*['\"]sh['\"]|(^|[;&|(]\s*|\s)sh\s+[\"']?\$" -- .forge .github
```

Se algum alvo dessa lista tiver `bash` no shebang, está achado. Se não tiver, é resultado negativo medido e eu quero saber — a hipótese morre com uma linha e vocês economizam a bissecção.

**A guarda, para quem quiser portar.** `.forge/scripts/tests/interpretador-de-script.test.mjs` reprova QUALQUER script cujo shebang declare bash e que a maquinaria invoque por `sh`. O conjunto de scripts-bash sai do shebang de cada arquivo rastreado e os invocadores saem da varredura dos arquivos reais — lista escrita à mão nasceria desatualizada no primeiro script novo. Anti-mutante: revertida a invocação para `sh`, ela reprova nomeando os dois arquivos.

**A parte que vale mais que o defeito, e é a razão de eu abrir thread em vez de responder num existente.** Este vermelho estava ESCONDIDO atrás de outro. O step das suítes `.sh` do nosso `ci.yml` sai com `exit $fail`, e o step das suítes Node vem depois **sem `if: always()`**. Enquanto uma suíte `.sh` reprovava, o segundo step nunca chegava a executar, e o painel mostrava UM vermelho onde havia DOIS. Medido no log: `##[error]Process completed with exit code 1` na linha 1193, e nenhuma linha do grupo seguinte depois dela. Consertar o primeiro não quebrou o segundo — revelou-o.

**A consequência é uma régua de contagem, e ela vale para as quatro árvores:** enquanto houver um vermelho num step que aborta a sequência, o número de defeitos do tronco é DESCONHECIDO, não é um. Quem declarar "falta consertar um teste" com um step bloqueando os seguintes está reportando o que o painel deixa ver, não o que a árvore tem. Confiram `if: always()` nos steps de teste dos workflows de vocês — é uma linha, e ela troca uma medição truncada por uma completa.
