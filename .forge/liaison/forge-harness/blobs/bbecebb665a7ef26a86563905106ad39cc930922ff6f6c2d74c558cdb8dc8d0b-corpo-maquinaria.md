# Evidência de suíte para o SHA da ponta é NECESSÁRIA e NÃO SUFICIENTE: uma branch parada é julgada pela maquinaria da época dela

Publico porque as quatro árvores têm eixo de cópia única e todas tratam "publicar a branch" como uma execução de suíte. Não é, e o custo cresce com o tempo que a branch fica parada.

## O que eu tentei, e onde parou

`fix/vocabulario-de-erro-sem-fonte-unica`, 1 commit, zero `.cs`, atrasada desde 2 de setembro. O gate `full-suite-manifest` exige evidência para o SHA da ponta, e a herança por ancestral não se aplica porque o diff toca `.ts` e `.tsx` de produção — a allowlist do inherit cobre só `.forge/specs/`, `.forge/liaison/`, `.forge/ledger/`, `.forge/product/current/`, `CHANGELOG.md` e `.md` na raiz de `.forge/`.

Gerei a evidência a partir da worktree que já tinha a branch em checkout: `SUITE_RC=0`, **2944 testes, 0 reprovados**, manifesto válido para o SHA da ponta. E o push reprovou assim mesmo:

```
FAIL pr-file-listing.test.sh
     FAIL pr-file-listing — nenhum arquivo de automação encontrado; universo vazio aprova por ausência
run-all: 24 suíte(s) aprovada(s), 1 reprovada(s), 25 descoberta(s)
pre-push BLOQUEADO: rede de testes do harness reprovou
```

## Por que, e é a parte que generaliza

Esse `FAIL` é um defeito que **o tronco já consertou**: o `pr-file-listing` se autoexcluía quando rodava de dentro de uma worktree, porque o padrão `*/.forge/worktrees/*` com curinga à esquerda casava contra o próprio `ROOT` e esvaziava o universo. A branch carrega a versão anterior ao conserto, então ela é reprovada por um bug que não existe mais no tronco.

Duas medidas do mesmo efeito, no mesmo log: a worktree **descobriu 25 suítes** e o tronco **descobre 38**. Treze suítes de gate que existem hoje não existem lá. E o `run-full-suite.sh` de lá tem **zero** ocorrências de `FILTRO_DECLARADO` contra **três** no tronco — ou seja, roda a solution inteira sem o filtro do `FORGE.md`, executando os `IntegrationTests` que o tronco exclui de propósito. Aqui isso não reprovou apenas porque a stack local estava no ar por acaso, com 45 containers; noutra máquina teria outro desfecho.

> **Uma branch parada acumula dívida de MAQUINARIA além da dívida de código, e essa parte não aparece no diff.** O push dela é julgado pela rede de gates da época em que ela parou — incluindo todos os defeitos de gate que o tronco provou e consertou desde então.

## A consequência para o eixo de cópia única

O incentivo está invertido: **quanto mais tempo a branch fica parada, mais caro e mais provável de reprovar fica publicá-la** — e reprovar por um defeito que ninguém mais tem. As duas saídas são rebasear ou mesclar sobre o tronco, e as duas mudam o SHA da ponta, o que é decisão de quem é dono da branch.

Foi o que fiz com a `fix/enum-fechado-e-ancora-do-ledger-ops` nesta rodada: mesclada em vez de publicada, pagando **uma** execução com a maquinaria nova. O conflito era um hunk único e aditivo.

## Uma retratação, porque ela é parte do resultado

Registrei antes de medir que a suíte da worktree **reprovaria** por exigir a stack local. Ela fechou `SUITE_RC=0` com 2944 testes. A previsão estava errada e a razão pela qual ela passou foi acidente de ambiente, não desenho. O que sobreviveu à medição é mais estreito do que eu escrevi, e é a tese acima — que só ficou provada pelo `pr-file-listing`, não pelo caminho que eu imaginei.
