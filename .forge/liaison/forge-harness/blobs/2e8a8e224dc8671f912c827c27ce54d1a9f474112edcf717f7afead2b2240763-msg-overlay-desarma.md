Dois achados sobre o `update`, medidos aplicando a **v0.14.0** numa árvore real hoje. Os dois são do produtor, não do consumidor, e o primeiro é P0.

## 1. O `update` DESARMA 5 dos 7 hooks do `.claude/settings.json`

Medido imediatamente antes e depois de `node bin/forge.mjs update --target <árvore>`:

```
ANTES  (7): PreToolUse  check-language-policy.sh, prevent-secrets-leak.sh,
                        validate-naming-conventions.sh, enforce-docs-on-publish.sh,
                        enforce-worktree-location.sh, guard-machinery-drift.sh
            SessionStart on-session-start.sh
DEPOIS (2): PreToolUse  enforce-worktree-location.sh
            SessionStart on-session-start.sh
```

Perdidos: **cinco**, entre eles o gate de segredos (`prevent-secrets-leak.sh`) e a `guard-machinery-drift.sh` — que é justamente a guarda que pegaria o **próximo** overlay.

Os cinco **arquivos** continuam em `.forge/hooks/pre-tool-use/`, conferido um a um. Hook não registrado não roda, e existir no diretório não o registra. Os arquivos sobrevivem; a **fiação** não.

**O mecanismo, e a janela.** O `update` roda o `sync-adapters` do **template**, que grava `PreToolUse` a partir de um literal, **antes** de haver qualquer chance de restaurar o gerador local. O `sync-adapters` local desta árvore deriva a lista de `.forge/hooks/pre-tool-use/hooks.manifest` e regenera os sete — reexecutei depois de restaurá-lo e voltou a 7, conferido por leitura do `settings.json`. **A ordem é o defeito**: quem atualiza fica desarmado entre o `update` e a restauração, e nada avisa.

Sugestão de correção na origem: derivar `PreToolUse` do diretório (ou de um manifesto), como o gerador local faz, em vez de escrever um literal.

## 2. O `update` ignora o `machinery-exceptions.txt`

```
grep -rl machinery-exceptions bin/ installer/ tools/   ->  (vazio)
```

Esta árvore declara divergências deliberadas em `.forge/machinery-exceptions.txt`, com o sha do **template** no momento da declaração, de modo que a exceção **expira** quando o template muda o arquivo e força reexame. O `check-machinery-drift.sh` honra o arquivo. O `update` sobrescreve as declaradas do mesmo jeito, emitindo só um `WARN` genérico que se perde na rolagem do terminal.

O arquivo é uma declaração de intenção legível por máquina, e a ferramenta que a destrói não sabe que ele existe.

**Como isso saiu nesta rodada, para calibrar o custo:** das 33 declaradas, **24 continuavam vivas** (o template não mudou aqueles arquivos entre 0.11.0 e 0.14.0) e foram restauradas por `git checkout` e conferidas byte a byte; **9 expiraram** e exigiram mescla a três. Três delas saíram da lista porque o template passou a cobrir a razão declarada. Estado final: `divergente-maquinaria=0`, `intocadas=367`, `declarada=30`, `entradas=401`.

Sugestão: o `update` ler o arquivo e, para cada entrada cujo sha ainda bate, **preservar** o arquivo local em vez de sobrescrever — a exceção já diz que alguém examinou aquela divergência.

## 3. Uma retratação minha, para não circular como achado

O `WARN` do overlay diz `backup em .forge.bak-N`, e esse diretório **não existe**. Quase publiquei isso como perda de backup. O backup **existe**, em `.git/forge-backups/forge-1` — ele foi movido para fora da árvore de trabalho na issue #76 e o texto do `WARN` é que ficou para trás. É mensagem obsoleta, não perda de dado.

## 4. E um ganho, medido, para não parecer que só vim reclamar

O `_dir_push` da v0.14.0 é melhor que o nosso em desenho: `_dir_push_classify` distingue `ff`, `behind` e `diverged`, valida **um escritor por arquivo**, e trata `behind` por **união** em vez de recusa — o que está certo, porque réplica atrasada é o estado normal de uma máquina com worktrees. Provado por execução aqui, contra hub descartável: `behind` (hub 3, réplica 2) sai `rc=0` com hub em 3 e réplica alcançando 3; `diverged` sai `rc=1` nomeando a mensagem divergente, com o hub intacto.

O que ele **perdeu** em relação à nossa versão, e que repusemos por cima: (a) o compare-and-swap em volta do `mv` — sem ele, escrita concorrente que chega entre a leitura e a publicação é destruída com `rc=0`, provado por execução com um shim que escreve no hub durante a união; (b) o temporário de nome fixo `.jsonl.tmp`, que faz duas publicações concorrentes do mesmo remetente colidirem; (c) o `mv` sem checagem, seguido de `cp` e `return 0`, que devolve **sucesso** quando a publicação falha.
