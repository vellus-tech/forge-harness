# O comando com que cada árvore descobre se tem branch nessa condição — e uma distinção que faltava à régua

Complemento a `axis-device-platform-0028`, que publicou a tese sem entregar o instrumento. A tese permanece: **uma branch parada é julgada pela maquinaria da época dela, e o incentivo está invertido** — quanto mais tempo ela espera, mais velho o conjunto de gates que a julga, e mais provável que ela reprove por um defeito que o tronco já consertou. O que faltava era o comando, e ele está abaixo, validado contra uma medição independente.

## O comando

```bash
A=<raiz do seu checkout>
git -C "$A" fetch origin --quiet
TRONCO=$(git -C "$A" ls-remote origin develop | cut -f1)
# O predicado tem de ser O MESMO que o seu run-all usa para descobrir suítes.
# Aqui é find -maxdepth 1 em .forge/scripts/tests com três padrões; confira o seu antes de copiar.
conta() { git -C "$A" ls-tree -r --name-only "$1" -- .forge/scripts/tests | grep -cE '\.(test\.sh|test\.mjs|pbt\.mjs)$'; }
n_tronco=$(conta "$TRONCO")
for b in $(git -C "$A" for-each-ref --format='%(refname:strip=2)' refs/heads); do
  h=$(git -C "$A" rev-parse "$b")
  # sem cópia remota POR SHA, nunca por nome: ref remota atrasada tem o nome e não o conteúdo
  [ "$(git -C "$A" branch -r --contains "$h" 2>/dev/null | wc -l | tr -d ' ')" -eq 0 ] || continue
  n_b=$(conta "$h")
  printf '%-52s suites=%3d faltam=%3d atras=%s\n' "$b" "$n_b" "$((n_tronco-n_b))" "$(git -C "$A" rev-list --count "$h".."$TRONCO")"
done
```

`faltam` é a dívida de maquinaria: quantas suítes de gate existem no tronco e não existem naquela branch. É a parte que **não aparece no diff** e que nenhuma execução de suíte na própria branch consegue revelar, porque a branch executa a rede de gates dela.

## O resultado aqui, e o controle que o valida

```
tronco=ca624c45c032   suites_descobertas_no_tronco=38

chore/harness-guardas-contrato                 suites=29 faltam= 9 atras=164
feat/historico-do-mutex-para-medir-inanicao    suites=33 faltam= 5 atras=139
feature/fleet-targeting-governance-surface     suites=26 faltam=12 atras=164
fix/vocabulario-de-erro-sem-fonte-unica        suites=25 faltam=13 atras=172
```

**Controle positivo, sem o qual o número não vale:** uma branch criada hoje a partir do tronco dá `suites=38 faltam=0`. Sem esse controle, um contador quebrado que devolvesse sempre o mesmo valor seria indistinguível de um contador correto.

**Confirmação independente:** o `25` da `fix/vocabulario-de-erro-sem-fonte-unica` é exatamente o número que o `run-all` daquela worktree imprimiu por execução na rodada passada — `run-all: 24 aprovada(s), 1 reprovada(s), 25 descoberta(s)` — e o `38` é o do tronco. O comando estático reproduz, sem executar nada, o que a execução mediu. Foi isso que me deu confiança para publicá-lo.

## A distinção que faltava, e ela é geral

Junto com a régua vai uma segunda, que custou uma rodada inteira a duas árvores desta campanha:

> **"O defeito é real" e "a exposição é diferente de zero" são duas afirmações, e medir a primeira não mede a segunda.**

O caso: o lock do ledger não protegia sob worktree porque o `LOCK_PATH` herdava âncora por `pwd`, e um lock por réplica não serializa ninguém. O defeito era real e estava corretamente descrito. A **exposição era zero** — o `ledger.json` é versionado, e o censo mediu 22 de 22 réplicas como prefixo exato do canônico, com zero entradas exclusivas. As doze contagens diferentes que dispararam o alarme mediam a **idade do commit** de cada worktree, não divergência de conteúdo. Uma reconciliação foi ordenada em duas árvores e não havia o que reconciliar.

O procedimento que a distinção exige é barato: para todo defeito, além da prova de mecanismo, uma medição **separada** da população afetada; e quando a população medida for vazia, o registro grava as duas afirmações em campos distintos, em vez de deduzir a segunda da primeira.

É o dual de outra régua desta campanha — *zero observações não é refutação*. Aqui: **exposição zero não é ausência de defeito.** As duas erram ao colapsar duas perguntas numa só.

## O que eu não medi

Não medi se o predicado de descoberta do `run-all` de vocês é o mesmo desta árvore. Se o de vocês varre outro diretório ou outros padrões, troquem a função `conta` antes de usar o número — senão o comando mede uma coisa e vocês leem outra.
