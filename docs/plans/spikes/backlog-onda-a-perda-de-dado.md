# Onda A — perda de dado silenciosa (especificação implementável)

Autor: especificador da Onda A. Data: 2026-09-07. Revisão 5, depois do veredito da revisão 4. Base medida: branch `fix/strix-achados-medios` em `c41eead`, `v0.14.0` publicada no npm.

Escopo: issue **#120** (`handoff-render.mjs` sobrescreve `.forge/HANDOFF.md` inteiro, com `exit 0` e sem backup) e **LDG-0175** (gate corrompe arquivo rastreado de `template/`, que é distribuído no pacote npm). O critério que junta os dois é o do plano-mestre: alguma coisa destrói trabalho já feito e sai com código zero.

Esta especificação é para ser executada, não lida. Toda afirmação numérica abaixo traz o comando que a produziu. Nenhum gate da suíte foi executado na sua elaboração — `feedback-suite-sem-concorrencia` registra que gate manual concorrente produz falha fantasma em gate alheio.

**Regra de método desta revisão, e ela é a invariante 19 do plano-mestre.** Uma especificação não prescreve mecanismo que ela não executou. O que a especificação declara é a **propriedade** que precisa valer e o **contrafactual** que a mutação tem de produzir; quem escolhe o primitivo é o implementador, que executa, e ele tem a obrigação de **provar que o primitivo escolhido discrimina** — com controle e recontrole, e com repetição quando o sinal for temporal. Comando exato só permanece nesta spec quando veio de uma execução minha, com a saída colada. A varredura de comandos que estabeleceu a regra está em §7, e a desta revisão em §8.

Aviso operacional que precede qualquer reprodução desta spec, e ele custou um bloqueador na revisão 1: **toda reprodução acontece com o `cwd` DENTRO da fixture**, jamais a partir da árvore do `forge-harness`. O motivo está medido em §1.3 — `on-session-end.sh:4` resolve a raiz por `git rev-parse --show-toplevel` sem `-C` e **descarta** o `FORGE_ROOT` que o chamador passou, então rodar o hook a partir daqui destrói o `.forge/HANDOFF.md` rastreado deste repositório com `rc=0` e sem uma linha de saída.

---

## 0. Resumo do que muda

| Peça | Arquivo | Natureza |
|---|---|---|
| Recusa, backup, escrita condicional e slot delimitado pelo último `:END` | `template/.forge/scripts/lib/handoff-render.mjs` | comportamento novo, retrocompatível no caminho feliz |
| Parsing de flags, guarda de `node` e tabela de rc | `template/.forge/scripts/handoff-gen.sh` | contrato de saída ampliado (`3` e `4` novos) |
| Hook passa a honrar `FORGE_ROOT` | `template/.forge/hooks/session/on-session-end.sh` | correção de defeito de raiz errada, medida em §1.3 |
| Sentinela de integridade de árvore | `template/.forge/scripts/check-tree-integrity.sh` (novo) | maquinaria nova, distribuída |
| Fiação da sentinela no canal real | `tests/run-all.sh` | não distribuído (fora de `package.json:files`) |
| Gate do defeito #120 | `tests/w<NNN>-handoff-destructive-write-gate.sh` (novo) | ordinal alocado pelo orquestrador |
| Gate do defeito LDG-0175 | `tests/w<NNN>-tree-integrity-sentinel-gate.sh` (novo) | ordinal alocado pelo orquestrador |

Ordinais: o máximo publicado é **w207**, medido em todas as refs com `for b in origin/develop origin/main fix/strix-achados-medios origin/wip/deepspec-run-manifest-ldg-0165 origin/wip/upgrade-safety-ldg-0131; do git ls-tree -r --name-only "$b" tests/ | grep -oE '/w[0-9]+' | sed 's|/w||' | sort -n | tail -1; done` → `207, 207, 207, 80, 154`. Os dois ordinais desta onda **não são alocados aqui**: a invariante 10 do plano-mestre atribui a alocação ao orquestrador, no momento de escrever o arquivo, contra `origin/*` **e** contra as branches em voo desta rodada.

---

## 1. ITEM 1 — issue #120

### 1.1 O defeito, reproduzido — roteiro completo, sem nada elidido

A revisão 1 não conseguiu reproduzir os bytes exatos porque os corpos `node -e` do roteiro anterior estavam resumidos com reticências. O roteiro abaixo é integral: copiar, colar, e os números aparecem. O corpo é gerado por laço de shell justamente para não depender de citação aninhada.

```bash
WS=<raiz do forge-harness>
T="$(mktemp -d "${TMPDIR:-/tmp}/repro-120.XXXXXX")"; R="$T/r"
mkdir -p "$R/.forge/specs/active/2026-09-07-fixture"
cd "$R"; git init -q .; git config user.email a@b.c; git config user.name t
printf 'id: 2026-09-07-fixture\ntype: feature\nscale: 2\nstatus: implementing\n' > .forge/specs/active/2026-09-07-fixture/manifest.yaml
printf 'x\n' > z.txt; git add z.txt; git commit -qm base
{ printf '# HANDOFF escrito à mão\n\n'
  i=1; while [ $i -le 400 ]; do printf '## R%d — rodada %d\n\nTexto humano da rodada %d, com acentuação.\n\n' "$i" "$i" "$i"; i=$((i+1)); done
} > .forge/HANDOFF.md
wc -c < .forge/HANDOFF.md
FORGE_ROOT="$R" bash "$WS/template/.forge/scripts/handoff-gen.sh" 2026-09-07-fixture; echo "rc=$?"
wc -c < .forge/HANDOFF.md
ls "$(git rev-parse --git-common-dir)"/forge-backups 2>/dev/null | wc -l
grep -c '^## R200' .forge/HANDOFF.md
```

Saída medida hoje, com esse roteiro exato:

```
ANTES:  28103 bytes; marcadores=0
OK <R>/.forge/HANDOFF.md
rc=0
DEPOIS:  2675 bytes
backups: 0
R200 sobreviveu? 0
```

**28.103 bytes viraram 2.675, com `rc=0`, com a palavra `OK` na saída, e sem um único arquivo de backup.** O tamanho de entrada é função do corpus gerado (400 seções); o que a asserção do gate mede é o comportamento — rc zero, arquivo encolhido, zero backup —, não o literal `28103`.

Reproduzi também a metade que a issue não mede — o caso em que os marcadores **estão** presentes, com texto antes do `:START` e depois do `:END`:

```bash
S='<!-- FORGE:NARRATIVE-DELTA:START -->'; E='<!-- FORGE:NARRATIVE-DELTA:END -->'
{ printf '# HANDOFF\n\n## 0. Seção manual ANTES do marcador\n\nTexto humano que ninguém autorizou a apagar.\n\n'
  printf '%s\n' "$S"; printf 'delta narrativo real da rodada anterior\n'; printf '%s\n\n' "$E"
  i=1; while [ $i -le 200 ]; do printf '## R%d — rodada %d\n\nTexto humano depois do marcador de fim.\n\n' "$i" "$i"; i=$((i+1)); done
} > .forge/HANDOFF.md
```

```
ANTES: 12995 bytes
rc=0
DEPOIS: 2511 bytes
delta do slot sobreviveu? 1
secao manual ANTES do marcador sobreviveu? 0
R200 (depois do marcador) sobreviveu? 0
```

A guarda das linhas 56-68 preserva **exclusivamente** o miolo do par de marcadores. Tudo que estiver antes do `:START` ou depois do `:END` é descartado com a mesma indiferença. Isso muda o diagnóstico: o defeito não é "a guarda nunca dispara", é "a guarda, mesmo disparando, preserva a minoria do documento".

### 1.2 A exposição hoje, medida nos consumidores

O número de 290.761 bytes da issue **não é desta árvore** — aqui o `.forge/HANDOFF.md` tem 8.320 bytes no HEAD (`git cat-file -s $(git rev-parse HEAD:.forge/HANDOFF.md)`) e tem os marcadores. Ele veio de um consumidor. Remedi hoje os seis repositórios de `~/Documents/projects` que têm `.forge/HANDOFF.md`, aplicando o mesmo cálculo que o código faz (`prev.indexOf(START)` / `prev.indexOf(END)`), e imprimindo também o `mtime` porque estes são arquivos vivos:

| Repositório | bytes | pares START/END | preservado | descartado | perda | mtime (UTC) |
|---|---:|---:|---:|---:|---:|---|
| axis-fare-validator | 314.192 | 1/1 | 288.936 | 25.256 | 8,04% | 2026-09-07 14:23 |
| **axis-go-cloud** | 8.090 | **0/0** | 0 | 8.090 | **100,00%** | 2026-09-07 14:46 |
| **Axis.PadSimulator** | 6.729 | **0/0** | 0 | 6.729 | **100,00%** | 2026-09-07 14:35 |
| azim-crm | 6.360 | 1/1 | 3.943 | 2.417 | 38,00% | 2026-08-30 23:15 |
| collatra | 4.216 | 1/1 | 1.951 | 2.265 | 53,72% | 2026-07-14 13:17 |
| forge-harness | 8.320 | 1/1 | 5.830 | 2.490 | 29,93% | 2026-08-19 19:11 |

Comando, integral: `node -e 'const fs=require("fs"),path=require("path");const base=process.env.HOME+"/Documents/projects";const S="<!-- FORGE:NARRATIVE-DELTA:START -->",E="<!-- FORGE:NARRATIVE-DELTA:END -->";for(const d of fs.readdirSync(base)){const p=path.join(base,d,".forge","HANDOFF.md");if(!fs.existsSync(p))continue;const t=fs.readFileSync(p,"utf8"),n=Buffer.byteLength(t);const ps=t.indexOf(S),pe=t.indexOf(E);let pres=0;if(ps>=0&&pe>ps)pres=Buffer.byteLength(t.slice(ps+S.length,pe).trim());console.log([d,n,pres,n-pres,((n-pres)/n*100).toFixed(2)+"%",fs.statSync(p).mtime.toISOString()].join(" | "));}'`.

Três linhas mudaram desde a revisão 1 (`axis-fare-validator` 312.079 → 314.192, `axis-go-cloud` 8.008 → 8.090, `Axis.PadSimulator` 7.366 → 6.729) porque os três arquivos foram reescritos hoje por sessões em andamento. A conclusão não muda: **seis de seis perdem dado numa próxima execução; dois de seis perdem tudo.**

Uma correção de contagem que o revisor levantou e que eu refuto com comando, porque a diferença é a diferença entre o que o código procura e o que um `grep` frouxo encontra. O veredito registra 3 ocorrências de `START` para 1 de `END` no `axis-fare-validator`; o código procura o **literal completo** `<!-- FORGE:NARRATIVE-DELTA:START -->`, e desse literal há exatamente **uma**:

```
$ F=~/Documents/projects/axis-fare-validator/.forge/HANDOFF.md
$ grep -o 'FORGE:NARRATIVE-DELTA:START' "$F" | wc -l                     → 3
$ grep -o -- '<!-- FORGE:NARRATIVE-DELTA:START -->' "$F" | wc -l         → 1
$ grep -o -- '<!-- FORGE:NARRATIVE-DELTA:END -->' "$F" | wc -l           → 1
$ grep -n 'NARRATIVE-DELTA' "$F" | cut -c1-60
84:<!-- FORGE:NARRATIVE-DELTA:START -->
86:**Estes marcadores `NARRATIVE-DELTA` foram acrescentados à
120:**E o gerador do HANDOFF tem a MESMA doença (`#120`).** A úni
2526:<!-- FORGE:NARRATIVE-DELTA:END -->
```

As duas ocorrências extras são prosa entre crases, dentro do corpo do delta, e `indexOf` não casa com elas. O par continua 1/1 e a linha da tabela está certa. O achado real dessa inspeção é outro e vai para §1.7: o corpo do delta de um consumidor **fala sobre os marcadores**, que é exatamente o espaço de entrada que a propriedade precisa cobrir.

### 1.3 O canal por onde o defeito chega

Dois canais, e eles se comportam de forma diferente — o que decide o desenho.

1. **Manual:** `/forge:handoff` roda `bash .forge/scripts/handoff-gen.sh <change-id>` (`template/.forge/commands/harness/handoff.md:21`). Aqui um `exit` diferente de zero e uma mensagem chegam a um humano.
2. **Hook de fim de sessão:** `template/.forge/hooks/session/on-session-end.sh:6` roda `FORGE_ROOT="$ROOT" bash "$ROOT/.forge/scripts/handoff-gen.sh" >/dev/null 2>&1 || true`. Aqui **nenhum código de saída e nenhuma mensagem sobrevivem** — stdout e stderr vão para `/dev/null` e o `|| true` engole o rc.

Medi a exposição do canal 2: `handoff.auto` está `false` em todos os oito consumidores que declaram a chave, e ausente em quatro (comando: `awk` sobre o bloco `handoff:` de cada `.forge/forge.yaml`). Ou seja, **hoje o canal destrutivo em produção é o manual**, e uma recusa com código de saída de fato chega a alguém. Isso é sorte de configuração, não desenho: o hook existe, é `opt-in` documentado, e no dia em que um consumidor o ligar a recusa morre no `/dev/null`. É por isso que a recusa **não pode ser a única proteção**.

E o hook tem um segundo defeito, que a revisão 1 encontrou e que eu confirmei em bancada com fixtures próprias, duas, isoladas em `$TMPDIR`. `on-session-end.sh:4` é `ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0`: sem `-C`, resolvendo pelo `cwd`, e **sobrescrevendo** o `FORGE_ROOT` recebido. Medi:

```
$ # fixtures a/ e b/, cada uma repositório git com .forge/ copiado do template e HANDOFF.md de 73 bytes
$ cd "$T/b" && FORGE_ROOT="$T/a" bash "$WS/template/.forge/hooks/session/on-session-end.sh"; echo "rc=$?"
rc=0
antes:  a=73  b=73
depois: a=73  b=2650
a intacto? 1 | b intacto? 0
```

O `FORGE_ROOT` apontava para `a`, e quem foi destruído foi `b` — o repositório do `cwd`. É a mesma classe de #120 (escrita destrutiva silenciosa) por um vetor diferente: escrever no repositório errado. Entra nesta onda como D17, porque está no mesmo arquivo, no mesmo canal, e é literalmente a armadilha que fez a revisão 1 exigir esta seção.

E `on-session-end.sh:5` é `[ -x "$ROOT/.forge/scripts/handoff-gen.sh" ] || exit 0`: quando o script não existe, o hook sai `0` sem ter executado nada. Medi:

```
$ # fixture c/ com .forge/HANDOFF.md de 15 bytes e SEM .forge/scripts/
$ cd "$T/c" && bash "$WS/template/.forge/hooks/session/on-session-end.sh"; echo "rc=$?"
rc=0, handoff=15 bytes, conteúdo intacto
```

Uma asserção de canal escrita como "o hook sai 0 **e** o arquivo sobreviveu" é satisfeita por esse hook que não fez nada. É o verde vácuo que D19 fecha com um sinal positivo de execução.

### 1.4 Decisões de desenho — FECHADAS

**D1. O gatilho da recusa é a ausência do par de marcadores, e o gerador recusa com `exit 4`.**

A pergunta que o gerador precisa responder antes de escrever é "eu sei o que estou descartando?". Sem os marcadores ele não tem modelo nenhum do arquivo que está lendo: não sabe qual parte é andaime dele e qual parte é texto humano. Escrever nesse estado é escrever às cegas, e é literalmente o gatilho que a issue pede ("a impossibilidade de mapear o arquivo existente").

*Alternativa descartada — inserir os marcadores automaticamente.* Inserir marcador é decidir onde o conteúdo humano começa e termina, e o gerador não tem essa informação. Uma inserção no lugar errado deixa o texto humano **fora** do slot e o torna descartável na rodada seguinte, agora com a bênção de um marcador plantado pelo próprio gerador — a perda volta a ser silenciosa e ganha aparência de conformidade. A mensagem de recusa diz ao humano onde inserir; a decisão é dele.

*Alternativa descartada — guarda de proporção (item 3 da issue).* Um limiar percentual é um número escolhido a dedo, sem defesa. As perdas medidas nos seis consumidores vão de **8,04% a 100%**: qualquer limiar posto entre esses extremos aprova a destruição de alguém, e o consumidor que perde 8,04% perde 25.256 bytes — mais que o arquivo inteiro de quatro dos outros. O backup incondicional de D2 cobre a mesma preocupação sem escolher número.

**D2. O backup é incondicional, não fica atrás de flag, e acontece sempre que o destino existe e o conteúdo vai mudar.**

O backup é o que protege o canal 2, onde a recusa morre no `/dev/null`. Ele também protege o caso em que a recusa **não** dispara — os quatro consumidores com marcador, que perdem de 29,93% a 53,72% legitimamente, do ponto de vista do código atual.

Isso não é invenção desta onda; é o idioma já estabelecido do harness em situação análoga, e essa é a resposta à pergunta "o que o resto do harness faz":

- `installer/install.sh:57-59` — `--force` move a árvore anterior para `.forge.bak-N` antes de instalar, "no data loss" em letra no cabeçalho.
- `bin/forge.mjs:594-608` — o `update` faz backup **por cópia** antes de editar in place, e o move para **fora da árvore de trabalho** (`.git/forge-backups/forge-N`), porque o backup dentro do repositório fazia os gates de varredura acusarem conflito no próprio backup (issue #76; o comentário do arquivo conta o caso inteiro).
- `template/.forge/scripts/spec-new.sh:9` — "refuses to overwrite an existing change (exit 3, tree untouched)".
- `template/.forge/scripts/node-baseline.sh:8` e `dotnet-baseline.sh:79` — "o script nunca escreve por cima" de decisão do projeto; `--force` é obrigatório e explícito.
- `template/.forge/scripts/spec-transition.sh:134-145` — `cp` para `.bak`, e `mv` de volta quando a validação falha.

O padrão do harness é **recusar por padrão, exigir `--force` explícito, e fazer backup fora da árvore**. #120 é o único sítio que escreve por cima sem nenhum dos três. O desenho aqui não inventa política: aplica a que já existe.

**D3. O backup vai para `<git-common-dir>/forge-backups/handoff/HANDOFF-<sha256-do-conteúdo-anterior>.md`, e o diretório tem política de expurgo.**

Fora da árvore de trabalho, pelo motivo da issue #76 citado acima — um `.forge/HANDOFF.md.bak-<timestamp>` dentro da árvore seria visto por todo gate de varredura e por `git status`, e `template/.forge/scripts/lib/scan-exclude.sh:6` documenta exatamente esse estrago. Pelo `--git-common-dir` e não pelo `--show-toplevel`, seguindo `conventions/machinery-propagation.md` ("estado de projeto mora no tronco") — assim o backup feito de dentro de um worktree sobrevive à remoção dele.

Nome endereçado por conteúdo (sha256 do texto anterior), não por timestamp: duas execuções consecutivas sem mudança de estado não produzem dois backups, o que preserva o determinismo exigido por NFR-02 e testado por `w60[2]`.

A resolução é `git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir`, com o `-C` **explícito e obrigatório**, e o galho de fallback dispara quando **`$ROOT` não é repositório git**, jamais quando o `cwd` não é. Isto não é zelo: medi que sem o `-C`, com o `cwd` na árvore do `forge-harness` e `$ROOT` num diretório avulso de `$TMPDIR`, o comando devolve `/Users/milton/Documents/projects/forge-harness/.git`, e `tests/w60-handoff-gen-gate.sh:14,33` roda o gerador exatamente nesse arranjo — o backup cairia dentro do `.git` deste repositório a cada execução da suíte, que é a mesma classe de defeito que D17 conserta, entrando pela porta do remédio. A asserção que fixa isso está em `[7]`.

Fallback quando `$ROOT` não é repositório git (o caso das fixtures, e de um `FORGE_ROOT` avulso): `${TMPDIR:-/tmp}/forge-handoff-backups/`, com o caminho **impresso em stderr**. É o mesmo galho que `bin/forge.mjs:598-608` já implementa, incluindo o aviso quando o backup ficou em lugar diferente do habitual.

**Expurgo, porque o galho de `TMPDIR` roda a cada `npm test` e a revisão 1 tem razão em dizer que ele acumula.** O gerador, ao criar um backup no fallback, remove do mesmo diretório os arquivos com mais de 14 dias de `mtime`, e só ali — nunca no galho de `<git-common-dir>`, onde o backup é o registro durável que a issue #76 quer preservar. A poda é do próprio gerador, não de cron nem de gate, para não depender de ninguém lembrar; e é limitada ao diretório endereçado por conteúdo que ele mesmo criou.

**D4. Quando `content` é byte-idêntico ao arquivo existente, o gerador não escreve nada.**

Hoje o `writeFileSync` da linha 70 é incondicional mesmo quando não há mudança. Deixar de escrever nesse caso é gratuito, torna o gerador idempotente no nível do sistema de arquivos (preserva mtime, não suja `git status`) e é o que impede o backup de D2 de virar ruído em execução repetida.

**D5. O hook de fim de sessão continua engolindo o rc e continua sem imprimir — e é por isso que ele ganha D17 e D19.**

*Alternativa descartada — fazer o hook falhar ruidosamente.* `SessionEnd` roda quando a sessão está terminando; não há quem leia, e uma falha ali só produz ruído no encerramento. A proteção de bytes nesse canal é D2, e é por isso que D2 não pode ficar atrás de `--force`.

O que muda em relação à revisão 1 é o reconhecimento de que "silencioso" não pode significar "sem rastro": um canal que engole tudo precisa deixar prova de que executou, senão nenhum teste consegue distinguir "rodou e recusou" de "não rodou". Essa prova é D19.

**D6. `--force` existe, não recebe valor, e faz backup mesmo assim.**

`--force` desativa a recusa de D1, nunca o backup de D2. Por não receber valor, é imune à classe de #103 (`forge_require_value` aceitando `--title` como valor de `--detail`), que a Onda E fecha — vale dizer isso em letra para que a revisão adversarial não gaste tempo procurando o defeito ali.

Nota de implementação obrigatória: `handoff-gen.sh:19` faz `ID="${1:-}"` sem parsing. `handoff-gen.sh --force` hoje gravaria a string `--force` como change-id. O parsing precisa separar flags de posicional antes de resolver o `ID`.

**D16. O slot é delimitado pelo PRIMEIRO `:START` e pelo ÚLTIMO `:END`.**

Esta decisão é nova e existe porque a revisão 1 derrubou, com medição, a afirmação de que um corpo que cite o marcador trunca o documento. Ele não trunca o documento; ele apaga, **dentro do slot**, tudo que vem depois da primeira ocorrência do literal `:END`. Remedi em fixture (o roteiro está em §1.7) e o resultado é inequívoco: 5 seções `## ` antes e 5 depois, seção `## 5.` presente, prefixo e sufixo do documento byte-idênticos (2.445 bytes fora do slot intactos), e a linha do corpo posterior ao literal desaparecida.

O código faz `prev.indexOf(END)`, que casa a primeira ocorrência. Trocar por `prev.lastIndexOf(END)` — mantendo `indexOf(START)` para o início — faz o slot ir do primeiro início ao último fim, e com isso um corpo que cite o literal é preservado inteiro e **volta a fechar o ciclo**: escrito assim, na leitura seguinte o `lastIndexOf` reencontra o mesmo fim, e a propriedade P3 de §1.7 passa a valer para todo corpo.

*Alternativa descartada — recusar quando o corpo contém o literal.* Recusar por isso proibiria exatamente o delta que descreve este trabalho, e o `axis-fare-validator` já tem um corpo que fala sobre os marcadores (medido em §1.2). Um harness que não consegue documentar o próprio marcador dentro do próprio documento é um defeito, não uma guarda.

*Alternativa descartada — escapar o literal na escrita.* Escapar muda o formato do documento, e §3 declara em letra que esta onda não muda o formato. `lastIndexOf` resolve sem tocar no formato.

Consequência que precisa ser dita, porque é mudança de comportamento observável: hoje o texto que estiver **depois** do `:END` é descartado (medido em §1.1 — `R200 sobreviveu? 0`); com D16 esse texto passa a ser absorvido para dentro do slot e **preservado**, se e somente se contiver o literal `:END`. Nos demais casos o comportamento é idêntico ao de hoje. Trocar destruição por preservação é a direção certa desta onda, e o cenário `[9]` fixa isso em asserção.

**D17. O hook honra `FORGE_ROOT` quando ele está definido.**

`ROOT="${FORGE_ROOT:-$(git -C "$(pwd)" rev-parse --show-toplevel 2>/dev/null)}"`, alinhando o hook ao contrato que o próprio gerador publica no cabeçalho (`handoff-gen.sh:7` — "FORGE_ROOT overrides the repo root"). O defeito está medido em §1.3: com `FORGE_ROOT` apontando para `a` e o `cwd` em `b`, quem foi reescrito foi `b`. Um hook que ignora a raiz que lhe passaram e escreve na raiz do diretório corrente é escrita destrutiva no repositório errado, que é a mesma classe desta onda.

*Alternativa descartada — deixar como está e apenas documentar.* Documentar não impede o dano, e a própria revisão 1 mostrou o custo: a armadilha quase entrou nesta spec como roteiro recomendado. Além disso, sem D17 os cenários `[5]`, `[6]` e `[12]` do gate só podem ser escritos com `cd` para dentro da fixture, o que os torna dependentes de disciplina do autor — e "o esquecimento é a falha que se quer eliminar" é o argumento que o próprio `tests/run-all.sh:34-36` já escreveu.

O `cd` para dentro da fixture continua obrigatório nos cenários, mesmo com D17 — cinto e suspensório, porque o gate roda contra o hook **antes** da correção quando o vermelho é observado.

**D18. `node` ausente no PATH é o terceiro estado, e ele sai `3` com o token `INCONCLUSIVO`.**

`handoff-gen.sh:61` invoca `node` sob `set -euo pipefail`; sem `node` no PATH, o script morre com `127` e sem uma palavra que distinga "não consegui verificar" de "falhei". A invariante 2 do plano-mestre proíbe exatamente esse colapso, e LDG-0157 é a instância que a Onda D fecha. A propriedade é: sem `node` no PATH, o gerador sai `3`, imprime um token que nomeia o estado, e **não toca no arquivo**. A guarda é `command -v node >/dev/null 2>&1 || { echo "INCONCLUSIVO (…)"; exit 3; }` imediatamente antes do bloco de invocação, e a saída que reexecutei em revisão anterior, com a guarda plantada num script de bancada, é esta:

```
node no PATH reduzido? NAO
com guarda: rc=3 saida=INCONCLUSIVO (node ausente no PATH — handoff NÃO regenerado, arquivo intacto)
sem guarda: rc=127 saida=…/semguarda.sh: line 2: node: command not found
```

O contrafactual de M10 é exatamente essa segunda linha: sem a guarda, `rc=127` e nenhuma palavra que distinga "não consegui verificar" de "falhei".

**E o `PATH` da fixture é uma propriedade, não um diretório contado.** A revisão 4 me pegou aqui: eu escrevia "um diretório com `bash` e sem `node`" e colava uma saída que só sai de um `PATH` com os utilitários externos do script. Com um diretório que só tem `bash`, o gerador morre na linha 12 por falta de `dirname` e sai `1` — a medição das três montagens está na nota de `[11]` em §1.5. O que a fixture precisa é `node` ausente **e** presente todo utilitário externo invocado antes da guarda (piso medido hoje: `dirname`, `find`, `wc`, `tr`, `basename`, mais `awk` quando a fixture tem `.forge/FORGE.md`), e o implementador prova o vermelho — `rc=127` na invocação de `node` — antes de escrever a asserção. Um `PATH` vazio continua sendo o erro oposto e mata o interpretador antes do script, produzindo `rc=127` pelo motivo errado.

Isto não é invenção: é a absorção upstream do patch local que o `Axis.PadSimulator` já aplicou por conta própria em `.forge/scripts/handoff-gen.sh` (medido em §1.10), com o rc corrigido de `1` para `3` para respeitar os três estados.

**D19. Recusa e inconclusivo deixam recibo fora da árvore.**

Quando o gerador recusa (`4`) ou fica inconclusivo (`3`), ele escreve `<git-common-dir>/forge-backups/handoff/RECUSA-<sha256-do-arquivo-intacto>.txt` — ou o fallback de `TMPDIR` de D3 —, com três linhas: o motivo tipado, o caminho do destino e o sha256 do arquivo que ficou intacto. Endereçado por conteúdo pelo mesmo motivo de D3: sessões repetidas sobre o mesmo estado não acumulam recibos, e a mesma política de expurgo de 14 dias vale no galho de `TMPDIR`.

O recibo existe por uma razão de teste que é também uma razão de operação: no canal 2 nada sobrevive ao `/dev/null`, então sem ele **nenhuma asserção consegue distinguir "o hook rodou e recusou" de "o hook não rodou"** — e §1.3 mede que o hook sai `0` sem executar nada quando o gerador está ausente. Em operação, o recibo é o que permite a um humano descobrir que o hook vem recusando há semanas em vez de supor que o handoff está atualizado.

### 1.5 O VERMELHO, antes do verde

Gate novo `tests/w<NNN>-handoff-destructive-write-gate.sh`. A afirmação da revisão 2 de que "cada cenário abaixo falha hoje pela ausência real da funcionalidade" era falsa para dois deles, e a coluna nova diz isso em letra, como a tabela do gate 2 já fazia: `[10]` é o contador de controle do próprio gate e `[13]` é a sentinela do próprio gate — os dois nascem verdes por construção, contam no `DECLARADOS=13` e não têm vermelho a observar no passo 3. Onze dos treze falham hoje por ausência real. Todo cenário que envolve o hook executa com `cd` para dentro da fixture, sem exceção, e o cenário `[13]` é a guarda que prova que essa disciplina foi respeitada.

Todo número que aparece na coluna "Mensagem do vermelho hoje" é o valor medido na fixture desta spec e serve para o implementador reconhecer o vermelho quando o vir. **Nenhum deles é literal no fonte do gate:** a mensagem do gate imprime os tamanhos e os `rc` que ele mesmo mediu naquela execução, e a asserção é sobre a propriedade (recusou, não escreveu, encolheu, deixou backup), nunca sobre o número.

| # | Cenário | Estado exato da fixture | Asserção | Mensagem do vermelho hoje | Por que falha por ausência real |
|---|---|---|---|---|---|
| [1] | destino existe, **sem** marcadores, corpo real de 28 KB | fixture git com change ativo (`.forge/specs/active/<id>/manifest.yaml`) e `.forge/HANDOFF.md` com centenas de seções e zero marcadores | `rc = 4` e arquivo **byte-idêntico** ao anterior (`cmp -s`) | `FAIL [1]: o gerador escreveu por cima de um HANDOFF que ele não sabe mapear (rc=0, 28103 → 2675 bytes)` | o gerador não tem recusa nenhuma — `handoff-render.mjs:70` escreve incondicionalmente |
| [2] | mesmo estado de [1], com `--force` | idem [1] | `rc = 0`, arquivo reescrito, **e** backup com o sha256 do conteúdo anterior | `FAIL [2]: --force não é reconhecido (virou change-id) e nenhum backup em <git-common-dir>/forge-backups/handoff` | `--force` não existe e `handoff-gen.sh:19` não faz parsing de flag |
| [3] | destino **com** marcadores, texto antes do `:START` e depois do `:END` | o corpus de 12.995 bytes de §1.1 | backup criado antes da escrita, e o conteúdo anterior recuperável **byte a byte** do backup | `FAIL [3]: 12995 → 2511 bytes e nenhum backup` | não há chamada de backup em sítio nenhum do gerador |
| [4] | duas execuções consecutivas sem mudança de estado | fixture git com change ativo, destino já regenerado | **propriedade:** a segunda execução não escreve o destino, e não cria backup novo. O sinal de "não escreveu" é escolhido pelo implementador e **provado discriminante** — ver a nota de `[4]` abaixo da tabela, que mede por que o primitivo óbvio não serve | `FAIL [4]: segunda execução reescreveu o arquivo sem mudança de conteúdo` | a escrita da linha 70 é incondicional, sem comparar com o conteúdo atual |
| [5] | CANAL — `on-session-end.sh` real, `cd` dentro da fixture, `.forge/HANDOFF.md` **sem** marcadores | fixture git com change ativo (`manifest.yaml`) e com `.forge/scripts/handoff-gen.sh` **presente e executável** | o hook sai 0 (contrato dele), o arquivo sobrevive ao `cmp -s`, **e** existe o recibo de recusa de D19 com o sha256 do arquivo intacto | `FAIL [5]: o hook de fim de sessão destruiu o handoff (73 → 2650 bytes)` | D1 e D19 não existem; o hook chama um gerador que sempre escreve |
| [6] | CANAL — mesmo hook, com marcadores presentes | fixture git com change ativo, destino com marcadores e conteúdo que muda | escreve, **e** o backup existe com o sha do anterior | `FAIL [6]: escreveu pelo hook sem deixar backup` | D2 não existe |
| [7] | `FORGE_ROOT` fora de repositório git, destino **com** marcadores e conteúdo que vai mudar | diretório avulso em `$TMPDIR`, sem `git init`, com change ativo, e `.forge/HANDOFF.md` com par de marcadores e texto adicional depois do `:END` | backup no fallback de `TMPDIR`, com o caminho impresso em stderr, **e** o conjunto de arquivos sob `<repo-real>/.git/forge-backups/` idêntico antes e depois do cenário (delta vazio, nunca ausência absoluta) | `FAIL [7]: sem git e sem backup — a única cópia era a memória do operador` | D2/D3 não existem, e não há galho de fallback |
| [8] | CONTRATO de saída | — | tabela de rc: `0` sucesso; `1` erro, **inclusive change ausente e change inexistente**; `2` change **ambíguo** (mais de um ativo e nenhum id); `3` inconclusivo; `4` recusa por não-mapeável. Os três primeiros são o contrato de hoje, medido em §7 e **não alterado** por esta onda | `FAIL [8]: rc 3 e rc 4 não são produzidos em cenário nenhum` | os `rc` 3 e 4 não são produzidos por sítio nenhum |
| [9] | PBT — corpo contendo os literais dos marcadores | ver §1.7 | o slot renderizado contém o corpo verbatim | `FAIL [9]: corpo de delta que cita o literal :END perde, DENTRO do slot, tudo que vem depois da citação (documento e seções intactos — a perda é do corpo)` | o código faz `prev.indexOf(END)`, medido em §1.7 |
| [10] | CONTADOR DE CONTROLE | — | ver §1.8 | — | **não falha por ausência** — é o contador do próprio gate, verde por construção desde a primeira execução |
| [11] | `node` ausente do PATH | fixture git com change ativo e destino com conteúdo real, e **`PATH` sem `node` e COM todos os utilitários externos que o script invoca antes da guarda** — a nota de `[11]` abaixo da tabela mede por que "um diretório que tem `bash`" não serve, e fixa a obrigação de provar o vermelho antes da asserção | `rc = 3`, token `INCONCLUSIVO` na saída, arquivo **byte-idêntico** | `FAIL [11]: sem node o gerador sai 127 e não distingue "não consegui verificar" de "falhei"` | `handoff-gen.sh:61` invoca `node` sem guarda, sob `set -e` |
| [12] | CANAL — hook com `FORGE_ROOT=<fixture-a>` e `cwd` em `<fixture-b>` | duas fixtures git, cada uma com change ativo e `.forge/HANDOFF.md` contendo **o par de marcadores** e um corpo de delta próprio e distinto, de modo que a regeneração de fato mude o conteúdo — ver a nota abaixo da tabela, que mede por que o par é obrigatório | `sha256` de `a/.forge/HANDOFF.md` **muda** e `b/.forge/HANDOFF.md` fica **byte-idêntico** (`cmp -s` contra a cópia de `t0`) | `FAIL [12]: o hook ignorou FORGE_ROOT e reescreveu o repositório do cwd (b: 73 → 2650 bytes; a intacto)` | `on-session-end.sh:4` descarta `FORGE_ROOT` e resolve pelo `cwd`, medido em §1.3 |
| [13] | SENTINELA DO PRÓPRIO GATE | — | `sha256` de `<repo>/.forge/HANDOFF.md` e a saída de `git -C <repo> diff --name-only HEAD -- template/` são idênticos no início e no fim do gate | `FAIL [13]: o gate mexeu na árvore real` | **não falha por ausência** — é a sentinela do próprio gate, verde enquanto o gate se comportar; o vermelho dela é um defeito do gate, não do produto |

**Por que a fixture de `[12]` precisa do par de marcadores — medido, não deduzido.** A revisão 2 escrevia "duas fixtures git, cada uma com handoff próprio de 73 bytes", e um handoff de 73 bytes escrito à mão não tem os marcadores: D1 então recusa com `exit 4`, o handoff de `a` **não** é regenerado, a asserção "o handoff de `a` é o regenerado" fica vermelha contra a implementação correta, e a mutação M9 vira no-op. Remedi as quatro células em bancada sob `$TMPDIR`, com a maquinaria real copiada, D1 e D16 aplicados no `handoff-render.mjs` e D17 aplicado no hook, `cwd` sempre dentro de `b` e `FORGE_ROOT` apontando para `a`:

| fixtures | com D17 (implementação correta) | sob M9 (desfaz D17) |
|---|---|---|
| **sem** o par de marcadores | `a mudou? NAO \| b mudou? NAO` | `a mudou? NAO \| b mudou? NAO` — **mutação no-op** |
| **com** o par de marcadores | `a mudou? SIM \| b mudou? NAO` | `a mudou? NAO \| b mudou? SIM` |

Recontrole, com D17 restaurado por `cp` e `cmp -s` byte a byte: `a mudou? SIM | b mudou? NAO`. A célula de cima à direita é exatamente o modo de falha de LDG-0164 e de `feedback-mutacao-fantasma-restore` — o `cmp` confirma que o arquivo mudou enquanto o comportamento não muda —, e é a mesma classe do B8 da revisão 1 reaparecendo no cenário que a revisão 2 criou. Com o par de marcadores nas duas fixtures a mutação morde e a asserção discrimina, e é por isso que a coluna de estado de `[12]` fixa o par em letra, junto com a exigência de que o corpo do delta de cada fixture seja distinto para que a regeneração de fato mude o conteúdo.

**Por que a fixture de `[11]` não pode ser "um diretório com `bash`" — medido nesta revisão, e a medição desmente a minha própria de duas revisões atrás.** O revisor da revisão 4 está certo inteiramente, e o defeito é meu: a célula de estado dizia `PATH` reduzido a um diretório que tem `bash` e não tem `node`, enquanto a saída que eu colei em §1.6 (`rc=127`, `line 51: node: command not found`) só sai de um `PATH` que também tem os utilitários externos do script. Remedi as três montagens, com o `cwd` dentro da fixture:

```
== A: PATH=<dir só com bash> ==
  handoff-gen.sh: line 12: dirname: command not found
  FAIL (template ausente: …/onda-a-rev5/templates/handoff/HANDOFF.md)
  rc=1
== B: PATH=/usr/bin:/bin (coreutils completos, node em /opt/homebrew/bin e portanto fora) ==
  handoff-gen.sh: line 51: node: command not found
  rc=127   arquivo intacto? SIM
== C: PATH=<dir com bash dirname find wc tr basename>, sem node, sem awk, sem git ==
  handoff-gen.sh: line 51: node: command not found
  rc=127   arquivo intacto? SIM
```

Com a montagem A o gerador morre na linha 12, na resolução do `SCRIPT_DIR`: sem `dirname`, `SCRIPT_DIR` colapsa para o `cwd`, o `TPL` derivado não existe e a linha 17 sai `1` com `FAIL (template ausente: …)` — muito antes da invocação de `node`. Duas consequências, e as duas são exatamente o que o veredito descreve: a asserção `rc = 3` de `[11]` ficaria **vermelha contra a implementação correta**, com D18 aplicado, porque a guarda nem chega a ser avaliada; e M10 viraria **no-op**, porque com e sem a guarda o `rc` é `1`.

A propriedade, então, é sobre o que o `PATH` precisa **ter**, não sobre quantos diretórios ele tem: **`node` ausente e todo utilitário externo que o script invoca antes da guarda presente.** O piso medido hoje é `bash`, `dirname`, `find`, `wc`, `tr` e `basename` — montagem C, `rc=127` na linha 51 —, e ele é piso e não lista fechada por dois motivos medidos. O primeiro é que a lista depende do **estado da fixture**: com `.forge/FORGE.md` presente, `fm_field` chama `awk` três vezes antes do `node` (medido: três linhas `line 44: awk: command not found` e ainda assim `rc=127`, porque a falha do `awk` acontece dentro de uma substituição de comando em prefixo de atribuição e não mata o script). O segundo é que a lista depende de **onde o implementador põe a guarda**: quanto mais cedo ela entrar, menos utilitários precisam existir. Um piso literal escrito no gate envelhece na primeira linha que alguém acrescentar ao gerador.

Daí a obrigação, e ela é a mesma disciplina que `[3]` e `[4]` já impõem: **antes de rodar a asserção, o implementador prova que o vermelho de hoje é `rc=127` na invocação de `node`, e não `rc` de um passo anterior.** A prova é uma execução do gerador de hoje, sem a guarda, dentro da fixture montada, e a saída vai para o PR junto com a de M10. Sem ela, `[11]` mede a ausência de `dirname` e chama isso de ausência de `node`.

**Por que `[4]` não pode prescrever `mtime` — medido nesta revisão, e o resultado é pior que "gate morto".** O sinal óbvio de "não escreveu" é o `mtime` do destino, e o primitivo óbvio no macOS é `stat -f %m`. Ele tem granularidade de **segundo**, e duas execuções consecutivas do gerador numa fixture cabem folgadamente dentro de um segundo. Rodei doze pares de escrita separados por 18 ms e contei quantos pares colidiram no mesmo `%m`:

```
run01 %m=1788798091->1788798092 (difere) | %Fm=1788798091.903064498->1788798092.004915312 (difere)
run02 %m=1788798092->1788798092 (IGUAL)  | %Fm=1788798092.173074776->1788798092.543829522 (difere)
run03 %m=1788798093->1788798093 (IGUAL)  | %Fm=1788798093.492681310->1788798093.545619886 (difere)
run04 %m=1788798093->1788798093 (IGUAL)  | %Fm=1788798093.606532139->1788798093.685554270 (difere)
run05 %m=1788798093->1788798094 (difere) | %Fm=1788798093.967971026->1788798094.028134395 (difere)
run06 %m=1788798094->1788798094 (IGUAL)  | %Fm=1788798094.150422157->1788798094.241791973 (difere)
run07 %m=1788798094->1788798094 (IGUAL)  | %Fm=1788798094.317673651->1788798094.384128260 (difere)
run08 %m=1788798094->1788798094 (IGUAL)  | %Fm=1788798094.429251829->1788798094.663188102 (difere)
run09 %m=1788798094->1788798094 (IGUAL)  | %Fm=1788798094.757970709->1788798094.899728031 (difere)
run10 %m=1788798094->1788798095 (difere) | %Fm=1788798094.986110707->1788798095.184870152 (difere)
run11 %m=1788798095->1788798095 (IGUAL)  | %Fm=1788798095.251377721->1788798095.335604621 (difere)
run12 %m=1788798095->1788798095 (IGUAL)  | %Fm=1788798095.450887300->1788798095.613306905 (difere)
colisoes de %m em 12: 9
```

Nove pares em doze colidiram, e nenhum dos doze colidiu em `%Fm`. A leitura que importa não é "o gate estaria morto": é que ele estaria **intermitente**, verde em cerca de três quartos das execuções e vermelho no resto, o que é o pior desfecho possível — quem rodar uma vez conclui que funciona, e a mutação M3 aparecerá como no-op ou como efeito real conforme o relógio. Daí as três obrigações que `[4]` impõe ao implementador, e nenhuma delas nomeia um comando:

1. O sinal de "não escreveu" tem de ter resolução **abaixo de um segundo**, ou não ser temporal.
2. A discriminação tem de ser provada por **repetição**, não por uma execução: sob M3 a asserção reprova em N de N execuções, com N ≥ 10. Uma prova de execução única não distingue um sinal correto de um sinal que acertou por sorte.
3. O primitivo tem de valer nas duas plataformas em que a suíte roda. `stat -f %Fm` é do BSD/macOS e não existe no `stat` do GNU, onde o equivalente é outra coisa; um `[4]` que passe aqui e morra no CI é o mesmo gate morto com outro endereço.

**A saída "escolha um sinal não temporal" que a revisão 4 oferecia está retirada, e a retirada é medida.** A frase antiga dizia que quem escolhesse "inode mais tamanho mais checksum, ou o próprio recibo do gerador" ficava dispensado das obrigações 1 e 3. O revisor mediu que as duas alternativas nomeadas não servem, e reproduzi as duas. A primeira é no-op sob M3, que é a classe exata que esta nota existe para eliminar, oferecida dentro dela:

```
antes : inode=258385210 tam=9 sha256=30e58096…ef8d ctime=1788799865
depois: inode=258385210 tam=9 sha256=30e58096…ef8d ctime=1788799866
inode+tam+sha IDÊNTICOS -> sinal NO-OP sob M3
```

`writeFileSync` com bytes idênticos trunca e reescreve **o mesmo inode**, com o mesmo tamanho e o mesmo checksum; só o `ctime` muda, e em granularidade de segundo, portanto sujeito à mesma loteria que derrubou o `%m`. Um `[4]` escrito sobre esse sinal é gate morto e M3 é mutação no-op. A segunda alternativa não existe no caminho que `[4]` percorre: D19 escreve recibo **apenas** em `rc 3` e `rc 4`, e `[4]` é o caminho `rc 0`, onde `handoff-gen.sh:63` imprime a mesma linha `OK <path>` escrevendo ou não. Usá-la exigiria desenho novo — um sinal positivo de "não escrevi" emitido no caminho feliz — e essa é decisão que esta onda **não** abre: acrescentaria superfície de saída ao gerador, que é fronteira publicada, e reabriria a tabela de rc de `[8]` e a varredura de strings de §2.6 para comprar o que a obrigação abaixo já compra de graça.

**A regra que fica no lugar dela, e ela é mais curta do que a que saiu:** nenhum sinal dispensa nenhuma obrigação. Qualquer candidato, temporal ou não, tem de ser provado discriminante sob M3 em N de N com N ≥ 10, e a prova exige **controle e recontrole** — o sinal muda quando o gerador escreve e **não** muda quando ele não escreve, na mesma fixture e no mesmo estado. As obrigações 1 e 3 caem apenas para um sinal que seja de fato não temporal, e só depois de ele passar por essa prova; um sinal que dependa de `ctime` continua temporal, com resolução de segundo, e a obrigação 1 o elimina.

Que o caminho não é vazio, medi — e isto é prova de existência, não prescrição, porque o primitivo continua sendo escolha do implementador. Doze pares de escrita separados por 18 ms, com o `mtime` lido em milissegundos pelo mesmo `node` que o gerador já exige (portanto sem a divisão BSD/GNU da obrigação 3):

```
par01 mtimeMs=1788799879981.637->1788799880000.4534 | segundo difere | mtimeMs difere
par02 mtimeMs=1788799880004.7378->1788799880023.1724 | segundo IGUAL | mtimeMs difere
…
par12 mtimeMs=1788799880192.4739->1788799880210.213 | segundo IGUAL | mtimeMs difere
colisoes em 12: segundo=11  mtimeMs=0
```

Onze pares em doze colidem na granularidade de segundo e nenhum colide em milissegundos. O implementador que escolher esse caminho ainda deve as três provas — resolução, repetição em N de N sob M3, e portabilidade —, e a última é justamente o que muda de figura quando o relógio é lido pelo `node` em vez de por dois `stat` diferentes.

**Comparação de caminho de fixture é por identidade de arquivo, nunca por string — medido.** Em `$TMPDIR` no macOS, `/var` é link simbólico para `/private/var`, e `git rev-parse --show-toplevel` devolve o caminho real enquanto `mktemp -d` devolveu o caminho pelo link:

```
$ FX=$TMPDIR/onda-a-rev4/fx ; cd "$FX"
$ echo "$FX"                        → /var/folders/ns/…/T//onda-a-rev4/fx
$ git rev-parse --show-toplevel     → /private/var/folders/ns/…/T/onda-a-rev4/fx
$ [ "$FX" = "$(git rev-parse --show-toplevel)" ]  → NAO
$ [ "$FX" -ef "$(git rev-parse --show-toplevel)" ] → SIM
```

Vale para os dois gates e para toda asserção que confronte o caminho de uma fixture com um caminho que o `git` devolveu — `[7]`, `[12]`, `[13]` e os cenários de canal do gate 2. A propriedade é "é o mesmo diretório", e o teste de string a nega em bancada macOS por um motivo que nada tem a ver com o produto.

**Uma asserção a mais em `[7]`, e ela nasce de uma medição desta revisão.** O fallback de `TMPDIR` de D3 dispara quando **`$ROOT` não é repositório git**, nunca quando o `cwd` não é, e a resolução do diretório de backup é `git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir`, com `-C` explícito. Medi o custo de não dizer isso: com o `cwd` na árvore do `forge-harness` e `$ROOT` num diretório avulso de `$TMPDIR`, `git rev-parse --path-format=absolute --git-common-dir` sem `-C` devolve `/Users/milton/Documents/projects/forge-harness/.git`, enquanto `git -C "$ROOT" rev-parse …` devolve `fatal: not a git repository`. E esse arranjo não é hipotético: `tests/w60-handoff-gen-gate.sh:14,33` roda o gerador com `FORGE_ROOT` num `mktemp -d /tmp/forge-handoff.XXXXXX` e o `cwd` na árvore real, de modo que um backup resolvido pelo `cwd` escreveria dentro do `.git` **deste** repositório a cada execução da suíte — a mesma classe do defeito que D17 conserta, entrando pela porta do remédio. `[7]` passa a exigir, além do backup no fallback e do caminho impresso em stderr, que **o conjunto de arquivos sob `<repo-real>/.git/forge-backups/` seja idêntico antes e depois do cenário** — delta vazio, nunca ausência absoluta, porque esse diretório é propriedade de `forge update` e pode existir legitimamente na bancada de quem roda a suíte.

**Nota de `[7]` — ele precisa de uma âncora que não sobreviva à execução anterior, senão passa por contaminação — o revisor da revisão 4 levantou isso e a leitura procede.** O fallback de D3 é `${TMPDIR:-/tmp}/forge-handoff-backups/`, o nome do arquivo é endereçado por conteúdo e o expurgo só remove aos 14 dias. Junte as três coisas: se o corpus da fixture for o mesmo em toda execução, o backup deixado pela suíte de ontem tem exatamente o sha que `[7]` procura, e a asserção "o backup existe com o sha do anterior" fica satisfeita **mesmo sob M2**, que remove a chamada de backup — a mutação vira no-op e a linha da matriz mente. As três saídas são equivalentes e a escolha é do implementador, com a mesma obrigação de sempre: provar que M2 morde em `[7]`. A primeira é ancorar a asserção no **caminho impresso em stderr naquela invocação**, que não existe se a chamada de backup não aconteceu. A segunda é apontar `TMPDIR` para dentro da própria fixture, o que dá um diretório de fallback novo a cada execução. A terceira é dar ao corpus da fixture um **nonce por execução**, o que muda o sha e portanto o nome do arquivo. Sem uma das três, `[7]` mede o que a execução de ontem deixou.

O `[13]` não é decoração: a revisão 1 mediu que o idioma ensinado pela revisão anterior desta spec destruiria os 8.320 bytes rastreados de `.forge/HANDOFF.md` deste repositório, e a sentinela do item 2 **não veria**, porque D15 limita o escopo dela a `template/`. O `[13]` é o `w201` aplicado a este gate, e cobre o buraco.

Ordem de trabalho obrigatória: **escrever o gate inteiro primeiro, executá-lo, colar a saída vermelha no PR, e só então tocar `handoff-render.mjs`.** A invariante 1 do plano-mestre trata vermelho não observado como achado da revisão adversarial.

### 1.6 Prova de mutação, com controle e recontrole

Alvos: `template/.forge/scripts/lib/handoff-render.mjs`, `template/.forge/scripts/handoff-gen.sh` e `template/.forge/hooks/session/on-session-end.sh`.

A coluna **Estado** é a lição que a revisão 2 não aplicou: uma linha de matriz de mutação só vale depois de a mutação ter sido rodada e o efeito observado, e duas linhas desta spec declaravam efeito errado justamente por terem sido escritas por dedução. `MEDIDO` significa que a mutação foi executada em bancada sob `$TMPDIR` nesta revisão, com a saída colada abaixo da tabela; `A MEDIR` significa que o alvo ainda não existe hoje e a linha é **hipótese**, a ser confirmada no passo 6 — e a regra é explícita: quando o efeito medido divergir da linha, **quem está errada é a linha**, que se corrige no PR, e não a implementação, que se conserta só se a divergência for defeito dela.

**A regra tem uma exceção, e ela é obrigatória.** Quando a mutação sai **no-op** — o gate continua verde com a mutação aplicada —, quem se corrige **não** é a linha: é o **cenário**, cujo sinal não discrimina. Enfraquecer a linha nesse caso é registrar por escrito que a guarda foi testada quando ela não foi, e é o padrão de LDG-0164 e de `feedback-mutacao-fantasma-restore` pela quarta rodada. A ordem de trabalho é: primeiro provar que a mutação **morde** (mudando o estado da fixture, o sinal observado, ou os dois); só depois, se ela morder e derrubar um conjunto diferente do declarado, corrigir a linha. Um no-op nunca é evidência sobre a implementação; é evidência sobre o teste.

| Mutação | Alvo | O gate tem de dizer | Estado | Recontrole |
|---|---|---|---|---|
| M1 — remover a recusa (voltar a escrever quando não há marcador) | render | `FAIL [1]` e `FAIL [5]`, nomeando o `rc` obtido e o tamanho antes/depois | **MEDIDO** — `[1]` | restaurar e `[1]`/`[5]` voltam a passar |
| M2 — remover a chamada de backup, mantendo a recusa | render | `FAIL [2]`, `FAIL [3]`, `FAIL [6]` **e `FAIL [7]`** — os quatro cenários que afirmam backup, e `[7]` é o do galho de fallback; `[1]` e `[5]` continuam verdes | A MEDIR — e em `[7]` a mutação só morde com a âncora da nota de `[7]` em §1.5, sem a qual um backup de execução anterior a satisfaz | restaurar e os quatro voltam a passar |
| M3 — tornar a escrita incondicional de novo (desfazer D4) | render | `FAIL [4]` apenas, **em N de N execuções com N ≥ 10** — sob M3 o gerador reescreve bytes idênticos, então D2 não dispara (o conteúdo não muda) e o único observável é o sinal de escrita de `[4]`; uma mutação que derrube `[4]` em parte das execuções não está medida, está sorteada | A MEDIR — e a nota de `[4]` em §1.5 mede por que o sinal óbvio a torna no-op intermitente | restaurar e `[4]` volta a passar em N de N |
| M8 — trocar `lastIndexOf(END)` de volta por `indexOf(END)` **no cálculo do fim do slot**, deixando intacta a detecção do par que D1 usa | render | `FAIL [9]` apenas; `[1]` e `[3]` medidos verdes, `[2]`, `[4]`, `[5]` e `[6]` a medir | **MEDIDO** — `[1]`, `[3]`, `[9]` | restaurar e `[9]` volta a passar |
| M9 — devolver o hook a `ROOT="$(git rev-parse --show-toplevel)"` (desfazer D17) | hook | `FAIL [12]` apenas; `[5]` e `[6]` continuam verdes, porque neles o `cwd` já está dentro da fixture | **MEDIDO** — `[12]`, e **só morde com a fixture de `[12]` corrigida** | restaurar e `[12]` volta a passar |
| M10 — remover a guarda de `node` (desfazer D18) | gen | `FAIL [11]` apenas | **MEDIDO** — o estado de hoje, sem a guarda, é `rc=127` na invocação de `node` com o arquivo intacto, **e só com a fixture de `[11]` corrigida**: com um `PATH` que só tem `bash`, o `rc` é `1` na linha 12 com e sem a guarda, e a mutação é no-op (nota de `[11]` em §1.5) | restaurar e `[11]` volta a passar |

Cada mutação isola **uma** asserção ou um grupo declarado, e as demais permanecem verdes — mutação que derruba tudo não distingue as guardas. Que M9 derrube só o `[12]` é o que prova que `[5]` e `[6]` medem o canal e não a resolução de raiz, **e isso só é verdade com o par de marcadores nas duas fixtures**, pela medição da nota de `[12]` em §1.5.

Saída da bancada desta revisão, com a maquinaria real copiada para `$TMPDIR`, D1 e D16 aplicados no `handoff-render.mjs`, e as fixtures em três estados (sem marcadores; com marcadores e corpo simples; com marcadores e corpo que cita o literal `:END`):

```
--- IMPLEMENTAÇÃO (D1 recusa + D16 lastIndexOf)
  [1 sem-marc]   rc=4 intacto? SIM
  [3 com-marc]   rc=0 corpo? SIM | cauda? NAO
  [9 corpo-cita] rc=0 ANTES? SIM | DEPOIS? SIM
--- SOB M8
  [1 sem-marc]   rc=4 intacto? SIM
  [3 com-marc]   rc=0 corpo? SIM | cauda? NAO
  [9 corpo-cita] rc=0 ANTES? SIM | DEPOIS? NAO
  restauração byte a byte OK
--- RECONTROLE
  [9 corpo-cita] rc=0 ANTES? SIM | DEPOIS? SIM

--- M1 (remover a recusa de D1), fixture sem marcadores
  ANTES(impl): rc=4 intacto? SIM
  SOB M1     : rc=0 intacto? NAO (bytes agora: 2595)
  restauração OK
  RECONTROLE : rc=4 intacto? SIM

--- node ausente do PATH, contra o gerador de HOJE (sem D18)
  sem node   : rc=127 intacto? SIM
```

Uma retratação sobre esse bloco, e ela é minha: a última linha reproduz, mas **não** com o `PATH` que a revisão 4 descrevia na fixture de `[11]`. Ela veio de um `PATH` com os utilitários externos do script — reencenei as três montagens nesta revisão e a saída está na nota de `[11]` em §1.5. Com um `PATH` que só tem `bash` o `rc` é `1`, na linha 12, e não `127`. A saída acima continua valendo para o que ela diz (sem `node`, o gerador de hoje sai `127` e não toca no arquivo); o que estava errado era a célula da fixture, que descrevia um estado diferente do estado medido.

Duas leituras dessa saída entram na spec como fato, e nenhuma delas era dedutível. A primeira é que `cauda? NAO` em `[3]` confirma, contra a implementação **corrigida**, que o texto depois do último `:END` continua descartado — D16 preserva o que passa a ficar **dentro** do slot, não o que fica depois dele, e nenhuma asserção pode prometer o contrário. A segunda é que M8 precisa ser ancorada no cálculo do fim do slot e não escrita como `s/lastIndexOf/indexOf/g`: a detecção do par que D1 faz também usa `lastIndexOf(END)`, e uma mutação global mudaria as duas coisas de uma vez, o que a tornaria menos discriminante sem que ninguém percebesse.

Mecânica obrigatória, e ela é onde este programa já se enganou três vezes:

```bash
ORIG="$T/handoff-render.mjs.orig"
cp "$ALVO" "$ORIG"          # CONTROLE VEM DA ÁRVORE DE TRABALHO, NUNCA DO HEAD.
# mutação — aspas SIMPLES no perl, e '$' do lado direito SEMPRE escapado.
# LDG-0164: `perl -0pi -e "s/a/$x/"` com aspas duplas interpola $x do PERL (vazio) e a mutação
# vira no-op silencioso, que mede o engano em vez do código.
perl -0pi -e 's/<padrão>/<substituto com \$ escapado>/' "$ALVO"
# ... roda as asserções, observa o FAIL esperado ...
cp "$ORIG" "$ALVO"
cmp -s "$ALVO" "$ORIG" || { echo "FAIL: restauração não bateu byte a byte"; exit 1; }
# RECONTROLE — sem isto a prova não vale (feedback-mutacao-fantasma-restore):
# um restore quebrado deixa a mutação eterna e ninguém vê.
<reexecuta a asserção que a mutação derrubou; ela TEM de voltar a passar>
```

O bloco acima é **idioma do repositório**, não invenção desta spec: a exigência de aspas simples no `perl -0pi` está registrada em LDG-0164, e a de recontrole em `feedback-mutacao-fantasma-restore`. O que a spec fixa são as três propriedades, e o implementador prova cada uma: a mutação **muda o comportamento** e não apenas os bytes (um `cmp` que acusa diferença não é prova de que a mutação mordeu — a matriz de quatro células de `[12]` em §1.5 é o contraexemplo medido); a restauração devolve o arquivo **byte a byte**; e a asserção derrubada **volta a passar** depois dela. Antes de escrever qualquer linha da matriz, o implementador roda a mutação e observa o `FAIL`; uma linha escrita sobre um no-op é pior que uma linha ausente, porque afirma cobertura que não existe.

`cp "$ALVO" "$ORIG"` e não `git show HEAD:<path> > "$ORIG"`, e a diferença é a diferença entre restaurar e destruir. A revisão 1 acertou em cheio: como §4 executa as mutações no passo 5, **depois** de implementar no passo 4, um controle vindo do HEAD é a versão **pré-implementação** — o `cp "$ORIG" "$ALVO"` apagaria a implementação não commitada, e o `cmp -s` confirmaria alegremente que a restauração bateu byte a byte. É a mutação fantasma de `feedback-mutacao-fantasma-restore` por um caminho novo, e o recontrole só a pegaria depois de o trabalho já ter sido perdido.

Os três alvos são arquivos **rastreados sob `template/`**, que é justamente o que a sentinela do item 2 existe para proibir — e vale aqui a mesma nota que §2.4 faz para M5/M7, pelo mesmo motivo e com o mesmo fecho: não há contradição, porque a sentinela compara **depois** de o gate terminar e o gate restaura antes de terminar; e se a restauração falhar, quem pega é a própria sentinela, no gate seguinte da suíte. Os dois gates entram na mesma onda e a disciplina é a mesma nos dois.

### 1.7 PBT — onde há espaço de entrada

O espaço de entrada aqui é o **corpo do delta narrativo**, texto livre escrito por um modelo, e a função sob teste é a preservação entre marcadores. Três exemplos escolhidos a dedo (o que `w60[4]` faz hoje) não cobrem esse espaço.

Ferramenta: `template/.forge/scripts/lib/pbt.mjs` — harness zero-dep já entregue e coberto por `w121`, com `forAll`, `gen`, shrinking e seed reprodutível. Não se importa fast-check aqui: o contrato do template é zero dependência.

O que a revisão 1 derrubou, e ela estava certa: a propriedade P3 da revisão anterior ("o documento resultante não perde bytes fora do slot") **passa hoje**, contra o código defeituoso, e por isso não media nada. Remedi antes de reescrever, com este roteiro:

```bash
# fixture git com change ativo, gerada como em §1.1; cwd DENTRO dela
FORGE_ROOT="$R" bash "$WS/template/.forge/scripts/handoff-gen.sh" 2026-09-07-fx >/dev/null
node -e 'const fs=require("fs");const p=".forge/HANDOFF.md";const S="<!-- FORGE:NARRATIVE-DELTA:START -->",E="<!-- FORGE:NARRATIVE-DELTA:END -->";let d=fs.readFileSync(p,"utf8");const a=d.indexOf(S),b=d.indexOf(E);const body="LINHA-ANTES-DO-LITERAL\nfalando da issue #120 o marcador "+E+" aparece aqui\nLINHA-DEPOIS-DO-LITERAL\n";d=d.slice(0,a+S.length)+"\n"+body+d.slice(b);fs.writeFileSync(p,d);'
cp .forge/HANDOFF.md "$T/antes.md"
FORGE_ROOT="$R" bash "$WS/template/.forge/scripts/handoff-gen.sh" 2026-09-07-fx >/dev/null
grep -c '^## ' "$T/antes.md"; grep -c '^## ' .forge/HANDOFF.md
grep -c 'LINHA-ANTES-DO-LITERAL' .forge/HANDOFF.md; grep -c 'LINHA-DEPOIS-DO-LITERAL' .forge/HANDOFF.md
node -e 'const fs=require("fs");const S="<!-- FORGE:NARRATIVE-DELTA:START -->",E="<!-- FORGE:NARRATIVE-DELTA:END -->";const a=fs.readFileSync(process.argv[1],"utf8"),b=fs.readFileSync(".forge/HANDOFF.md","utf8");const pre=d=>d.slice(0,d.indexOf(S)+S.length),suf=d=>d.slice(d.lastIndexOf(E));console.log("prefixo idêntico:",pre(a)===pre(b),"sufixo idêntico:",suf(a)===suf(b),"bytes fora do slot:",Buffer.byteLength(pre(b))+Buffer.byteLength(suf(b)));' "$T/antes.md"
```

Resultado medido: 5 seções `## ` antes e **5 depois**, `LINHA-ANTES-DO-LITERAL` presente, `LINHA-DEPOIS-DO-LITERAL` **ausente**, seção `## 5.` presente, e `prefixo idêntico: true | sufixo idêntico: true | bytes fora do slot: 2445`. O documento não trunca; o que se perde está inteiramente **dentro do corpo do slot**. A frase da revisão anterior — "um delta que mencione o marcador trunca o documento no meio" — era a única frase não medida do documento e era falsa.

Propriedades reescritas sobre o **slot**, que é onde a perda ocorre, sobre corpo gerado que inclua deliberadamente acentuação, `$`, crases, CRLF, linhas vazias, e **os literais dos próprios marcadores**:

- **P1 — idempotência:** renderizar duas vezes com o mesmo estado produz saída byte-idêntica.
- **P2 — preservação verbatim do slot, sem exceção de conteúdo:** para todo corpo `b` não vazio e distinto do placeholder, **inclusive os que contêm os literais `:START` e `:END`**, escrever `b` no slot e regenerar produz um documento cujo miolo entre o primeiro `:START` e o último `:END` é exatamente `b` (a menos do `trim` das bordas, que o código já aplica hoje e D16 não muda).
- **P3 — fechamento do ciclo:** para todo corpo `b`, o documento produzido pela regeneração, lido de novo pelo mesmo leitor, devolve o mesmo `b` — ou seja, o que o gerador escreve ele consegue reler.

P2 está **medida como vermelha hoje**, e a medição está acima: o corpo com o literal `:END` volta sem `LINHA-DEPOIS-DO-LITERAL`. P3 é o que impede a correção preguiçosa de preservar o corpo numa rodada e perdê-lo na seguinte. A propriedade antiga sobre "bytes fora do slot" sai do conjunto por ter sido medida verde e portanto inútil.

### 1.8 Contador de controle, denominador fixo

O gate publica, e reprova em zero:

```
OK handoff-destructive-write/universo — 13 cenário(s) executado(s) de 13 declarado(s)
```

Denominador **fixo e literal** no fonte (`DECLARADOS=13`), conferido contra o contador incrementado por cenário. Um cenário que deixe de rodar por `case` que não casa, por `continue` ou por variável vazia derruba o gate em vez de sumir do log. O universo do PBT tem contador próprio (`runs` do `forAll`, com `seed` impressa), porque um PBT que rodou zero casos aprova por não ter olhado.

Denominador literal aqui é correto e não colide com a invariante 3, porque o universo deste gate é a lista de cenários que o próprio arquivo declara — é fechado e conhecido em tempo de escrita. O denominador que **não** pode ser literal é o da sentinela do item 2, cujo universo é a árvore e muda com a entrega; §2.6 trata disso.

Chave de allowlist: **nenhuma**. O universo deste gate é literal e nunca é legitimamente vazio; não há entrada a declarar em `empty-universe-allowlist.txt`.

E a consequência disso precisa ser dita, porque a varredura de strings desta revisão a expôs: o gate 1 **não** usa `forge_universe_check`, justamente por não ter vazio legítimo, e por isso a grafia da sua linha de contador é a que está acima e não a da lib. A sentinela do item 2 faz o contrário — usa a lib, porque o vazio dela **é** legítimo num consumidor sem `template/` —, e é por isso que as duas grafias diferem de propósito. Um implementador que uniformizasse as duas em qualquer direção quebraria uma das duas coisas: ou tiraria do gate 1 um contador que não tem allowlist a consultar, ou tiraria da sentinela o terceiro estado que `w144` cobra.

### 1.9 Níveis de teste — onde cada um entra, e onde não se aplica

- **Unitário:** os cenários `[1]`-`[4]`, `[7]` e `[11]`, sobre o gerador em fixture de `mktemp -d`.
- **PBT:** §1.7, sobre a função de preservação do slot.
- **Contrato:** `[8]`. `handoff-gen.sh` é fronteira publicada — o cabeçalho do script declara a tabela de rc, e `template/.forge/commands/harness/handoff.md` e `plugin/forge/commands/handoff.md` documentam a invocação. Os três arquivos do gerador estão registrados no `machinery.lock` dos consumidores, e isso eu remedi nesta revisão: o lock existe, mora em `.forge/cache/machinery.lock` (profundidade 4, não 3) e está presente nos 8 consumidores com `.forge/` completo — `find ~/Documents/projects -maxdepth 5 -name machinery.lock`. Acrescentar `3` e `4` é mudança de contrato e precisa de asserção que morda se alguém reciclar o código para outra coisa.
- **Integração:** `[5]`, `[6]` e `[12]`. É o `on-session-end.sh` real, executado de verdade num fixture git com `cd` para dentro dela, não o script do gerador invocado direto. É a exigência de `testing/gate-delivery-channel.md`: a prova acontece pelo canal pelo qual o gate roda em produção, e distingue "não encontrei violação" de "não rodei" por um **sinal positivo de execução**. Em `[6]` esse sinal é o backup com o sha esperado; em `[5]`, onde a recusa impede qualquer escrita, é o **recibo de D19** — e é exatamente por isso que D19 existe, porque sem ele `[5]` seria satisfeito por um hook que saiu 0 sem executar nada, o que §1.3 mede acontecer quando o gerador está ausente.
- **E2E — não se aplica, com o motivo medido.** O `/forge:handoff` completo é protocolo híbrido: `template/.forge/commands/harness/handoff.md` é markdown executado por um modelo, e só o núcleo determinístico é script. Não há E2E roteirizável sobre o passo do modelo, e fingir um seria teatro. A fronteira scriptável termina em `[5]`/`[6]`/`[12]`, e ela cobre o canal por onde o dano de #120 aconteceu.

### 1.10 Retrocompatibilidade — refeita sobre medição própria

A revisão 1 acusou esta seção de importar da "Nota operacional" da issue #120 a frase "os sha256 locais batem com o lock: é código stock, sem patch local". A acusação procede quanto ao essencial e eu a aceito: **a frase é falsa**. Remedi tudo do zero, com dois comandos, e o resultado corrige tanto a spec quanto uma parte do veredito.

**O lock existe.** O veredito afirma que `machinery.lock` não existe em nenhum consumidor, com base em `find ~/Documents/projects -maxdepth 3 -name machinery.lock`. Esse comando não encontra porque o caminho tem quatro níveis:

```
$ find ~/Documents/projects -maxdepth 3 -name machinery.lock | wc -l      → 0
$ find ~/Documents/projects -maxdepth 5 -name machinery.lock | wc -l      → 20 (medição datada — inclui .forge.bak-N, worktrees aninhados e um diretório de backup fora dos 8 consumidores)
$ for d in axis-fare-validator axis-go-cloud Axis.AcqSimulator Axis.PadSimulator azim-crm collatra docuseal lionclaw; do
    printf '%s: %s entradas\n' "$d" "$(wc -l < "$HOME/Documents/projects/$d/.forge/cache/machinery.lock")"; done
axis-fare-validator: 403 | axis-go-cloud: 404 | Axis.AcqSimulator: 285 | Axis.PadSimulator: 398
azim-crm: 341 | collatra: 341 | docuseal: 298 | lionclaw: 403
```

O `20` é medição datada e não pertence a asserção nenhuma — o que a spec afirma é a propriedade "os 8 consumidores com `.forge/` completo têm `.forge/cache/machinery.lock`", e ela é verificada pelo laço das oito linhas acima, cujas contagens reproduzem exatamente. Onze dos vinte caminhos estão sob `.forge.bak-N`, dois vêm de repositórios aninhados (`axis-go-cloud/axis-device-platform`, `secret-weapon/Axis.SecretWeapon`) e quatro de um diretório de backup avulso (`.axis-fare-validator-forge-bak`); nenhum deles é consumidor ativo, e o número muda a cada `forge update` de qualquer um dos oito, porque cada update cria um `.forge.bak-N` novo.

Os 8 consumidores têm lock, e os quatro arquivos do gerador estão em todos eles (`grep -E 'handoff' <lock>` devolve `commands/harness/handoff.md`, `scripts/handoff-gen.sh`, `scripts/lib/handoff-render.mjs` e `templates/handoff/HANDOFF.md`). A referência de §1.9 ao lock **fica**, agora medida.

**Mas há patch local, e ele está exatamente nos dois consumidores que vão passar a recusar.** Comparação por sha256 do arquivo local contra o template desta branch **e** contra a entrada do próprio lock do consumidor — o segundo é o que distingue "patch local" de "template velho", e é a distinção que o veredito não fez:

| arquivo | resultado medido |
|---|---|
| `scripts/lib/handoff-render.mjs` | **stock em 8 de 8** (`==lock` e `==template`) — é o arquivo que esta onda mais altera |
| `commands/harness/handoff.md` | stock em 8 de 8 |
| `scripts/handoff-gen.sh` | **patch local em 2** — `axis-go-cloud` e `Axis.PadSimulator` divergem do template **e do próprio lock**; os outros 6 são stock |
| `templates/handoff/HANDOFF.md` | diverge do template em 5, mas em 4 deles (`Axis.AcqSimulator`, `azim-crm`, `collatra`, `docuseal`) o local **bate com o próprio lock**: é template velho, não customização; só `lionclaw` diverge do lock |

Comando: `for f in scripts/handoff-gen.sh scripts/lib/handoff-render.mjs templates/handoff/HANDOFF.md commands/harness/handoff.md; do tpl=$(shasum -a 256 "$WS/template/.forge/$f" | awk '{print $1}'); for d in <os 8>; do loc=$(shasum -a 256 "$HOME/Documents/projects/$d/.forge/$f" | awk '{print $1}'); lk=$(awk -v k="$f" '$2==k{print $1}' "$HOME/Documents/projects/$d/.forge/cache/machinery.lock"); printf '%s %s %s %s\n' "$f" "$d" "$([ "$loc" = "$lk" ] && echo ==lock || echo '!=LOCK')" "$([ "$loc" = "$tpl" ] && echo ==tpl || echo '!=tpl')"; done; done`.

**Os dois patches, nomeados, com `diff -u`:**

- `axis-go-cloud` — bloco `forge:path-anchoring (LDG-0403)`: troca `TPL="$(cd "$SCRIPT_DIR/..")/templates/handoff/HANDOFF.md"` por resolução via `git rev-parse --path-format=absolute --git-common-dir`, para que o gerador encontre o template do tronco quando roda de dentro de um worktree. `mtime` local de hoje 11:08 — é patch novo, aplicado nesta rodada.
- `Axis.PadSimulator` — uma linha: `command -v node >/dev/null 2>&1 || { echo "FAIL (node >= 20 required)"; exit 1; }`. `mtime` local de hoje 11:17.

**O que a release desta onda faz com eles, medido no código do update, não suposto.** `scripts` está em `MACHINERY_DIRS` (`bin/forge.mjs:307`) e **fora** de `ENRICHABLE_DIRS` (`:352`), então o overlay sobrescreve. Mas a sobrescrita **não é silenciosa**: `bin/forge.mjs:628-629` compara o local contra o lock e contra o template novo e, quando os três diferem, empilha o caminho em `driftWarned`; `:642-643` imprime `WARN: drift local em <path> sobrescrito pelo template (fix local em maquinaria? faça upstream; backup em .forge.bak-N)`. E `:594-608` já copiou o `.forge` inteiro para `.git/forge-backups/forge-N` antes de qualquer escrita. Ou seja: o patch é perdido da árvore ativa, com aviso nominal e com cópia recuperável — o que é o comportamento desenhado, não um defeito novo desta onda.

**As três providências, e elas são parte da entrega, não recomendação:**

1. **O patch do `Axis.PadSimulator` é absorvido upstream nesta onda**, como D18, com o rc corrigido de `1` para `3` — o consumidor deixa de ter patch, e o campo ganha o terceiro estado. É a resposta certa para um fix local em maquinaria, e o próprio `WARN` do update a recomenda em letra.
2. **O patch do `axis-go-cloud` NÃO é absorvido aqui**, e digo o motivo em vez de fingir que não existe: ele é uma instância de LDG-0171 (`SCRIPT_DIR/../..`, medido em 37 sítios), que é Onda F, e absorver um sítio isolado num arquivo que esta onda já reescreve criaria duas grafias de resolução de raiz no mesmo repositório. A consequência é declarada: quando a release desta onda for aplicada no `axis-go-cloud`, o `WARN` de drift aparece, o patch sai da árvore ativa e fica em `.git/forge-backups/forge-N`, e o gerador volta a resolver o template por `SCRIPT_DIR/..` até a Onda F. Cabe ao release avisar antes.
3. **Item de ledger novo, aberto por esta onda:** "absorver upstream o `path-anchoring` do `axis-go-cloud` em `handoff-gen.sh` (LDG-0171/Onda F) e avisar o consumidor pelo canal de liaison antes da release da Onda A". Sem ele, a onda que existe para impedir perda silenciosa entrega uma perda silenciosa de patch alheio.

**O que quebra para o adotante.** Nos dois consumidores sem marcadores — `axis-go-cloud` e `Axis.PadSimulator` — um comando que hoje "funciona" passa a **recusar** com `exit 4`. É mudança de comportamento visível e é deliberada: o que ele perde é a destruição de 8.090 e 6.729 bytes. A mensagem de recusa precisa ser acionável em uma linha — dizer que o arquivo não tem os marcadores, onde inseri-los, e que `--force` escreve com backup.

**O que não quebra.** `w60[1]` cria o arquivo do zero (destino inexistente ⇒ escrita permitida); `w60[2]` exige diff vazio entre duas execuções, e D4 fortalece isso em vez de violá-lo; `w60[4]` monta o delta **depois** de gerar, então o documento tem marcadores e a recusa não dispara. `w62`, `w63` e `w101` não exercitam a escrita destrutiva. D16 só muda o comportamento de documentos cujo corpo contenha o literal `:END`, e nenhum dos quatro casos do `w60` contém. Nenhuma asserção existente precisa ser afrouxada, e afrouxar alguma delas na implementação é achado da revisão adversarial.

**Dependência externa, nomeada.** Enquanto a issue #101 não fechar (Onda C), `scripts` está em `MACHINERY_DIRS` e fora de `ENRICHABLE_DIRS`, e `forge update` sobrescreve o diretório inteiro. A consequência prática é a que a própria issue #120 registra: **correção aplicada no consumidor é revertida pelo próximo overlay**, então a correção tem de ser aqui, upstream, e chegar por release. Esta onda não depende da #101; só não deve prometer ao campo uma correção que o campo possa aplicar sozinho.

---

## 2. ITEM 2 — LDG-0175

### 2.1 O que o ledger afirma, e o que a varredura refeita mostra

O LDG-0175 afirma que `w146-suite-invocation-gate.sh` "usa `template/.forge/scripts/tests/run-all.sh` — arquivo rastreado e distribuído no pacote — como fixture de invocação e não restaura".

**Confirmei os fatos do dano.** Os dois arquivos existem, estão rastreados e têm exatamente os tamanhos que o ledger cita:

```
$ wc -l template/.forge/scripts/tests/run-all.sh template/.forge/empty-universe-allowlist.txt
      70 template/.forge/scripts/tests/run-all.sh
      32 template/.forge/empty-universe-allowlist.txt
$ git ls-files --error-unmatch <os dois>   → ambos RASTREADOS
$ git ls-files template/ | wc -l           → 434 arquivos rastreados sob template/ hoje
```

E confirmei que são distribuídos: `package.json:files` inclui `template/`.

**Não consegui confirmar o mecanismo, e digo isso em letra: a atribuição do LDG-0175 ao `w146` está errada como diagnóstico de código.** Li o gate inteiro. A linha 82 é `cp -R "$WS/template/.forge" "$R5/.forge"`, com `R5="$T/r5"` e `T="$(mktemp -d /tmp/forge-w146.XXXXXX)"`; as escritas das linhas 92 e 107 — as que produzem `w01-x-gate.sh` e o stub com `MARCA-SUITE-INVOCADA` — vão para `$R5`, dentro de `/tmp`, nunca para a árvore. Auditei **todas as quatro versões do arquivo na história** (`for r in d7d4ad4 6dd3952 0d95a0a efe99e9; do git show "$r:tests/w146-suite-invocation-gate.sh" | grep -nE 'R5=|cp -R|MARCA-SUITE-INVOCADA|w01-x-gate'; done`) e as quatro escrevem em `$R5`. O mesmo vale para a segunda impressão digital: `printf 'ai-attribution\n' > "$R3/.forge/empty-universe-allowlist.txt"` é `tests/w144-gate-control-counter-gate.sh:155`, produz exatamente o arquivo de **uma linha** que o ledger encontrou, e `R3="$T/r3"` também está em `/tmp`.

**A varredura da revisão 1 estava errada, e a correta é bem maior.** Eu havia escrito "9 invocações em 7 arquivos, 7 sem `FORGE_ROOT`; as quatro scripts alvo têm ZERO sítios de escrita", sem publicar o comando. A revisão 1 refez e achou mais; refiz de novo, mais amplo que os dois, e publico cada comando:

Todos os números abaixo são **medições datadas de hoje**, publicadas com o comando para serem refeitas, e nenhum deles é literal em asserção — o único que a revisão 2 deixou escapar para dentro de um cenário era o `132` do varredor de `[15]`, e §2.3 o converteu em denominador derivado.

```
$ ls tests/*.sh | wc -l                                                          → 132   (131 são *-gate.sh; o 132º é o próprio run-all.sh)
$ grep -lE '\$\{?WS\}?/template/' tests/*.sh | wc -l                             → 115 arquivos
$ grep -nE '\$\{?WS\}?/template/' tests/*.sh | wc -l                             → 344 linhas
# (A) invocação direta `bash|sh $WS/template/.forge/scripts/...`
$ grep -nE '(bash|sh) +"?\$(WS|\{WS\})"?/template/\.forge/scripts/' tests/*.sh | wc -l   → 10 sítios
$   ... | cut -d: -f1 | sort -u | wc -l                                          → 8 arquivos
# (B) atribuição a variável depois executada
$ grep -nE '^[A-Z_]+="\$WS/template/\.forge/scripts/' tests/*.sh | wc -l         → 48 sítios
$   ... | sed -E 's#.*scripts/##; s/".*//' | sort -u | wc -l                     → 33 scripts distintos
# (C) SUPERCONJUNTO — toda referência a script real do template, em qualquer forma
$ grep -nE '\$\{?WS\}?/template/\.forge/scripts/' tests/*.sh | wc -l             → 119 sítios
$   ... | cut -d: -f1 | sort -u | wc -l                                          → 62 arquivos
$   ... | sed -E 's#.*template/\.forge/scripts/##; s#["'"'"' ].*##' | sort -u | wc -l → 57 tokens
```

Dos 57 tokens, 4 são indireção por variável (`$g.sh`, `$ref`) ou prefixo de diretório (`lib`, `lib/`), restando **53 nomes de script reais do template alcançados a partir de `tests/`** — entre eles `handoff-gen.sh`, `ledger-ops.sh`, `liaison-ops.sh`, `wave-ops.sh`, `spec-new.sh`, `spec-close.sh`, `archive-spec.sh`, `worktree-reconcile.sh`, `heavy-run.sh`, `pentest-ops.sh` e `tests/run-all.sh`, que é o arquivo exato que o LDG-0175 encontrou reduzido a um stub. **Nenhum deles aparecia na varredura da revisão 1, e a lista de "quatro scripts alvo" era arbitrária.**

E a varredura por operador de escrita com destino literal sob `$WS/template/`, que é a única forma que um `grep` decide, devolve zero em todas as grafias:

```
$ grep -nE '>>?[[:space:]]*"?\$\{?WS\}?/template/' tests/*.sh | wc -l                        → 0
$ grep -nE '<<[-~]?[A-Za-z_'"'"'"]+ *>>? *"?\$\{?WS\}?/template/' tests/*.sh | wc -l         → 0
$ grep -nE '^[[:space:]]*(cp|mv|install|ln)[[:space:]]' tests/*.sh \
    | awk -F: '{l=$0; sub(/^[^:]*:[0-9]*:/,"",l); n=split(l,f," "); if (f[n] ~ /\$\{?WS\}?\/template\//) print}' | wc -l → 0
$ grep -nE '(rm|sed +-i|perl +-[0-9]*p?i|truncate|tee|chmod)[^|]*\$\{?WS\}?/template/' tests/*.sh | wc -l → 0
```

**Onde a conclusão muda de verdade.** A afirmação "zero sítios de escrita" **não está estabelecida e eu a retiro**. Dos 119 sítios, **115 não trazem `FORGE_ROOT`, `--path`, `--repo` nem `-C` na mesma linha** (`grep -nE '\$\{?WS\}?/template/\.forge/scripts/' tests/*.sh | grep -vE 'FORGE_ROOT|--path|--repo|-C ' | wc -l` → 115, em 61 arquivos), e desses, 7 são execução direta. Auditei os 7 um a um: `tests/w112-liaison-session-gate.sh:154` roda `validate-rules.sh` **sem argumento e sem raiz fixada**, o que o faz operar sobre esta árvore real; `tests/w153-upgrade-safety-gate.sh:101` roda o `template/.forge/scripts/tests/run-all.sh` real com `--path "$T/vazio"`; `tests/mermaid-drawio-gate.sh:75` roda `infra-scan.mjs`, que **escreve** (`writeFileSync` em `:112` e `:141`), fixado por `--out "$T/repo/out"`; os demais são `validate-frontmatter.sh`, `eval-trigger-metrics.sh` e `gate-phase.mjs`, sem sítio de escrita (`grep -nE 'cp |mv |rm |sed -i|tee |mkdir |>[^&]' <script>` devolve só linhas de comentário e de uso). Hoje nenhum dos 7 escreve nesta árvore; **mas isso é auditoria de 7 sítios, não uma prova sobre 119, e o alvo de escrita em shell é uma variável resolvida em tempo de execução.**

Essa é, aliás, a prova empírica direta de que a abordagem estática não basta: **a varredura por operador de escrita devolve zero num repositório onde o dano ocorreu.** Quem procurar o sítio no fonte não acha.

**Consequência para o escopo da onda, e ela reverte a decisão da revisão 1.** Eu havia declarado a metade (i) "um nulo verificado" e a descartado. O plano-mestre diz em letra que "a correção de LDG-0175 tem duas metades e as duas são obrigatórias", e a varredura em que apoiei o descarte estava errada. **A metade (i) volta**, e volta em forma verificável, dividida em duas partes que a tornam mais que uma promessa:

- **(i-a) — o nulo, agora com comando publicado.** `w146` e `w144` já copiam para `$TMPDIR` em **todas** as versões commitadas; o comando de auditoria está acima e o cenário `[9]` do gate o registra em teste, executando os dois gates sob a sentinela. Não há correção a fazer nesses dois arquivos, e inventar uma seria teatro.
- **(i-b) — a guarda estática sobre a forma literal, que é a única que um `grep` decide.** Um cenário novo (`[15]`) varre `tests/*.sh` procurando operador de escrita cujo destino literal esteja sob `$WS/template/`, reprova nomeando arquivo e linha, e publica quantos arquivos varreu. Ela é **necessária e insuficiente** por construção, e é justamente por isso que não substitui a sentinela: fecha a forma que alguém escreveria por descuido amanhã, e deixa a forma variável para D7.

### 2.2 Decisões de desenho — FECHADAS

**D7. A guarda é dinâmica: observa a árvore antes e depois de cada gate, e nomeia o gate culpado.**

*Alternativa descartada — guarda estática que reprove um gate cujo fonte contenha escrita em caminho sob `template/`, como único mecanismo.* Medido em §2.1: alvo de escrita em shell é variável, a varredura devolve zero num repositório onde o dano ocorreu, e um gate legítimo precisa copiar de `template/` — na medição datada de hoje, **115 dos 132** arquivos de `tests/` referenciam `$WS/template/`, e o que a decisão usa é a proporção esmagadora, não o par de números, que muda a cada gate novo. Como mecanismo único produziria falso-negativo no caso real e, se ampliada para "menciona `template/`", falso-positivo em massa. Como complemento sobre a forma literal, ela entra — é a metade (i-b).

**D8. A guarda vive em `template/.forge/scripts/check-tree-integrity.sh` (maquinaria distribuída), e `tests/run-all.sh` é o chamador.**

Assinatura: `check-tree-integrity.sh --path <repo> --scope <pathspec> [--baseline <arquivo>] [--baseline-write] [--label <texto>]`.

Dois desfechos de uso que a revisão 3 deixou sem resposta, e os dois são de letra. **`--baseline <arquivo>` apontando para arquivo inexistente** não é erro de uso e não é divergência: é a primeira execução da suíte, e a sentinela não tem com o que comparar. O desfecho é `INCONCLUSIVO tree-integrity/sem-baseline`, com `rc 2`, na mesma família de `sem-git` e `sem-head` e pelo mesmo motivo — não conseguir verificar não é verificar. **Um consumidor que declare `check-tree-integrity.sh` em `runtime.gates` sem passar `--baseline`** cai no galho sem linha de base, e nele a sentinela compara com o HEAD cru; pelo desenho de D9 isso reprovaria todo trabalho legítimo não commitado, então o galho sem `--baseline` **não emite veredito de divergência**: ele emite o contador de universo — que continua valendo, porque não depende de linha de base — e em seguida `INCONCLUSIVO tree-integrity/sem-baseline`. A sentinela só reprova por divergência quando alguém lhe deu o antes contra o qual comparar, e é por isso que o argumento "declarável em `runtime.gates`" de D8 vale para o contador e não para o veredito.

E uma colisão de código de saída que está declarada e merece a frase que impede alguém de "consertá-la" depois: o idioma do harness para argumento inválido é `rc 2` (`check-suite-wiring.sh:31-34`), e aqui `rc 2` é `INCONCLUSIVO`. A colisão foi resolvida a favor do desfecho, não do idioma — quem lê o rc da sentinela é o `run-all.sh`, que precisa separar "não verifiquei" de "reprovei" e não precisa separar "você me chamou errado" de "achei divergência", porque as duas exigem intervenção humana imediata. Erro de uso fica em `rc 1` junto da divergência, com mensagem distinta.

`--baseline-write` estava declarado em D10 e em §5 e **fora** da assinatura publicada e do cenário de contrato — que é exatamente a classe da ressalva de `--snapshot`, invertida: em vez de um interruptor publicado sem leitor, um leitor sem interruptor publicado. Ele entra na assinatura e no cenário `[10]`, com a semântica de D10: escreve o arquivo indicado por `--baseline` a partir do estado atual e não emite veredito; exige `--baseline`; é escrito **uma vez**, no início da suíte, e é erro de uso (`rc 1`) invocá-lo sem `--baseline` ou junto de um veredito.

`--snapshot` **sai da assinatura**. A revisão 1 tem razão: ele era um interruptor publicado sem leitor declarado e sem cenário que o exercitasse, que é a classe de LDG-0008/w192 e da Onda E. Os dois que ficam têm semântica e cenário: `--baseline <arquivo>` é o arquivo de linha de base descrito em D9, lido em toda invocação e escrito uma única vez por `--baseline-write`, e é exercitado pelo cenário `[14]`; `--label <texto>` é o nome que aparece na mensagem de divergência (o nome do gate que acabou de rodar) e é exercitado por `[6]` e `[7]`, que exigem que a saída **nomeie o gate culpado**.

*Alternativa descartada — colocar a guarda direto em `tests/run-all.sh`.* `tests/` não é distribuído (`package.json:files` = `bin/`, `template/`, três arquivos do `installer/`, `CHANGELOG.md`); uma guarda escrita ali morre neste repositório. Como script de `template/.forge/scripts/`, ela é testável isoladamente, hermética, e fica disponível para um consumidor declarar em `runtime.gates`.

**D9. O veredito é UM estágio e ele compara com o HEAD, nunca com o índice.**

Esta decisão foi reaberta e trocada. O desenho da revisão 1 usava `git diff-files --name-only` como estágio 1 e `git diff --quiet -- <path>` como estágio 2, e **os dois comparam a árvore de trabalho contra o ÍNDICE**. Reproduzi o falso-verde em fixture própria, e ele é exatamente o estado que o LDG-0175 descreve:

```bash
T=$(mktemp -d "${TMPDIR:-/tmp}/onda-a-b1.XXXXXX"); cd "$T"; git init -q .
mkdir -p template/.forge; printf '#!/usr/bin/env bash\necho real\n' > template/.forge/f7.txt
git add -A; git commit -qm base
printf '#!/usr/bin/env bash\nexit 1\n' > template/.forge/f7.txt   # corrompe
git add template/.forge/f7.txt                                   # e estagia
git diff-files --name-only -- template/                          # → VAZIO
git diff --quiet -- template/.forge/f7.txt; echo "rc=$?"         # → rc=0
git diff --name-only HEAD -- template/                           # → template/.forge/f7.txt
git status --porcelain -uno -- template/                         # → M  template/.forge/f7.txt
cat template/.forge/f7.txt                                       # → exit 1  (corrompido no disco)
```

Com o desenho antigo a sentinela imprimiria `OK` sobre um arquivo de `template/` corrompido e estagiado — o falso-verde que a invariante 2 do plano-mestre proíbe, e o estado que precede o dano ("um commit por cima desse estado publica maquinaria quebrada"). O plano-mestre pede guarda que reprove "quando a árvore de `template/` diverge do HEAD", e o desenho antigo não comparava com o HEAD em estágio nenhum.

**O primitivo do veredito passa a ser `git diff --name-status -z HEAD -- <scope>`**, que é content-based, pega o caso estagiado, pega remoção de rastreado, traz a letra de status para a mensagem, e é `-z` para sobreviver a caminho com espaço ou quebra de linha. Confirmei em fixture que ele não sofre do falso positivo de `mtime` que motivava o estágio 2 antigo:

```
$ touch template/.forge/f7.txt        # sem mudar conteúdo
$ git diff --name-only HEAD -- template/     → vazio
$ git status --porcelain -uno -- template/   → vazio
$ git checkout ... ; rm template/.forge/outro.txt
$ git diff --name-only HEAD -- template/     → template/.forge/outro.txt   (remoção pega)
```

**O custo deixou de ser o critério, e essa é a segunda correção desta decisão.** A revisão 1 registrava `git status --porcelain --untracked-files=all -- template/` custando 0,79s a 1,61s e o descartava por caro; remedi hoje, três execuções de cada, e a ordem de grandeza não existe. As medições saíram **sob carga** — `load averages` entre 19,4 e 31,1, porque a suíte roda em outro processo e a invariante 9 me proíbe de interrompê-la —, o que só reforça o ponto: mesmo sob carga alta os números são estes.

| Primitivo | 3 execuções (s) | leitura |
|---|---|---|
| `git status --porcelain --untracked-files=all -- template/` | 0,28 / 0,04 / 0,05 | o 0,28 é cache frio da primeira execução |
| `git diff-files --name-only -- template/` | 0,03 / 0,05 / 0,04 | descartado por correção, não por custo |
| `git ls-files --others --exclude-standard -- template/` | 0,05 / 0,05 / 0,04 | barato o bastante para rodar por gate |
| `git diff --name-only HEAD -- template/` | 0,05 / 0,03 / 0,03 | — |
| `git status --porcelain -uno -- template/` | 0,04 / 0,03 / 0,03 | alternativa equivalente |
| `git diff --name-status -z HEAD -- template/` | 0,10 / 0,03 / 0,02 | **escolhido** |
| ciclo completo da sentinela (diff + `ls-files \| wc -l`) | 0,09 / 0,10 / 0,07 | — |
| variante com `git hash-object` por caminho divergente | 0,17 / 0,15 / 0,13 | usada só quando a divergência não bate com o baseline |

Comando de cada linha: `for i in 1 2 3; do /usr/bin/time -p sh -c '<primitivo> >/dev/null' 2>&1 | awk '/^real/{printf "%s ", $2}'; done`. A dispersão entre execuções do **mesmo** comando (0,02 a 0,28) é maior que a diferença entre comandos distintos, então **custo não discrimina entre as estratégias e a escolha é por correção**. Registro como pendência do implementador, e ela entra na definição de pronto: remedir os seis primitivos em bancada ociosa, com a suíte parada, e colar as três execuções no PR — se em bancada ociosa algum primitivo destoar por ordem de grandeza, a decisão volta à mesa, mas nenhum candidato incorreto volta por ser rápido.

Extrapolação agregada, declarada como extrapolação **e com o multiplicador derivado, não literal**: o número de chamadas é `ls tests/*-gate.sh | wc -l` no momento da execução, mais as duas desta onda, e a conferência é sobre a propriedade "o acréscimo de tempo da sentinela é menos de 5% do tempo total da suíte", nunca sobre um total em segundos. O valor medido hoje é **131** gates (`ls tests/*-gate.sh | wc -l` → 131; `ls tests/*.sh | wc -l` → 132, e a diferença é o próprio `run-all.sh`, que não é gate), e essa contagem envelhece **nesta mesma onda**, que a leva a 133. A 0,07-0,10s por chamada, 133 chamadas dão de 9 a 13s, contra um registro histórico de `PASS=74 FAIL=0 SKIP=0 (325s)` que, linearizado, fica na casa das centenas de segundos. Não pôde ser conferida porque a suíte não foi executada nesta etapa, e a conferência entra no passo 2.

**D10. Não rastreado é verificado a cada gate, contra a linha de base — e não mais uma vez ao fim da suíte.**

A revisão 1 desta spec adiava o exame de não rastreados para o fim da suíte "porque a varredura custa até 0,91s". Remedi: `git ls-files --others --exclude-standard -- template/` custa **0,05 / 0,05 / 0,04s**. Com o custo real, adiar não compra nada e custa a informação que mais importa — **qual gate** criou o arquivo. Passa a rodar por gate, comparado ao conjunto capturado na linha de base: um caminho não rastreado que já existia em `t0` é ignorado (trabalho legítimo em voo), e um que apareceu **durante** a execução reprova nomeando o gate e o caminho.

**A linha de base, que é o que torna D9 utilizável neste repositório.** Comparar com o HEAD, cru, faria a sentinela reprovar desde o primeiro gate sempre que houvesse trabalho em voo sob `template/`. Aqui vale uma correção de fato desta revisão, e ela é a razão de a linha de base existir e não a razão de ela não existir: a revisão 3 escrevia que `git diff --name-status HEAD -- template/` devolvia dois arquivos do pentest, e **hoje ele devolve vazio** — a Fase 0 foi commitada em `c41eead`, e remedi (`git status --porcelain -- template/` → nenhuma linha; `git diff --name-status HEAD -- template/` → nenhuma linha). A propriedade que sustenta D10 não é "a árvore está suja agora", que é medição datada e já venceu, e sim "a árvore **pode** estar legitimamente suja no instante em que alguém roda a suíte", que é permanente. Uma sentinela que só funciona com a árvore limpa reprova a primeira pessoa que rodar `npm test` no meio de um trabalho, e é exatamente a guarda que o §3 descarta por irrealizável. O baseline é capturado **uma vez**, no início da suíte, com `--baseline-write`, e contém **quatro** coisas: o número de arquivos rastreados no escopo, a lista de caminhos divergentes do HEAD com o `git hash-object` de cada um, a lista de não rastreados, e o **sha do HEAD**. A sentinela reprova quando, comparado a esse baseline, aparece caminho novo, some caminho, um caminho divergente muda de hash, ou o HEAD muda.

O sha do HEAD é a quarta entrada por um motivo medido, e ele fecha o único buraco que o revisor apontou como fora do desenho — um gate que **commite** sob `template/` fica invisível a `git diff HEAD`, porque depois do commit a saída é vazia. Medi as três formas em que isso pode acontecer, e duas já eram pegas pelas outras três entradas do baseline:

| o gate falso… | rastreados | divergentes | HEAD | pega? |
|---|---|---|---|---|
| adiciona arquivo novo sob `template/` e commita | 1 → **2** | `[]` → `[]` | muda | sim, pelo contador de universo |
| commita por cima de uma divergência que já existia em `t0` | 1 → 1 | `[M template/.forge/f.txt]` → **`[]`** | muda | sim, pela lista de divergentes |
| altera um rastreado limpo e commita, sem adicionar nem remover | 1 → 1 | `[]` → `[]` | **muda** | **só pelo sha do HEAD** |

A terceira linha é o buraco real, e ele é estreito mas não hipotético: o disco fica com `corrompido` e os dois primeiros sinais são byte a byte idênticos aos de `t0` — remedi a linha inteira nesta revisão, e a saída está colada em D11. Gravar o sha do HEAD custa `git rev-parse HEAD`, medido em **0,04 / 0,02 / 0,03s**, e a mensagem é própria (`FAIL tree-integrity/head-mudou — <gate> moveu o HEAD de <sha-t0> para <sha-agora>`, `rc 1`), porque "o gate commitou" é um diagnóstico diferente de "o gate sujou a árvore". O desfecho é o nono de D11 e tem cenário próprio, `[19]`, que é o que a revisão 4 cobrou com razão: até ela, a quarta entrada do baseline existia sem galho enumerado e sem cenário, e M15 apontava para um cenário que não existia. Um gate da suíte não tem por que mover o HEAD do repositório real em nenhuma circunstância, e o `--gates-dir` de D14 existe justamente para que a fixture seja outro repositório. É o que distingue "sujo desde antes" de "sujo por causa deste gate", e é o único uso de `--baseline`.

**D11. NOVE desfechos, e cada rodada de revisão derrubou a enumeração da anterior por medição.**

A revisão 2 listava cinco desfechos como se fossem exaustivos, e dois estados reais não casavam com nenhum. O primeiro é o que a troca de primitivo do B1 abriu: **repositório git sem nenhum commit**. O segundo é o vazio da isenção declarada, que a `lib/gate-universe.sh` já implementa e que a lista ignorava. Medi os dois:

```bash
T=$(mktemp -d "${TMPDIR:-/tmp}/n3.XXXXXX"); cd "$T"; git init -q .
mkdir -p template/.forge; printf 'x\n' > template/.forge/x.txt
git diff --name-status -z HEAD -- template/ ; echo "rc=$?"   # → fatal: bad revision 'HEAD'   rc=128
git status --porcelain -uno -- template/                      # → (vazio)   rc=0
git ls-files -- template/ | wc -l                             # → 0
git add template/.forge/x.txt
git diff --name-status -z HEAD -- template/ ; echo "rc=$?"   # → fatal: bad revision 'HEAD'   rc=128
git status --porcelain -uno -- template/                      # → A  template/.forge/x.txt
git ls-files -- template/ | wc -l                             # → 1
```

O diretório **é** repositório git, então o galho `sem-git` não dispara; com `git add` o universo é 1, então `universo-vazio` também não dispara; e o primitivo escolhido sai `128`. As duas implementações que nasceriam disso são igualmente ruins, e é por isso que o desfecho precisa ser declarado: capturar a saída com `|| true` produz saída vazia e imprime o `OK` do universo, que é falso-verde sobre árvore não verificada; não capturar mata o script sob `set -e` com `rc 128`, que a suíte lê como divergência. Sem `git add` o quadro é ainda pior de outro jeito: `git ls-files` devolve `0` e a guarda de universo vazio dispararia com o motivo **errado**, dizendo "não há arquivo rastreado no escopo" quando a causa é "não há HEAD contra o que comparar". Daí a ordem de avaliação ser fixada em letra.

**Ordem de avaliação, obrigatória e nessa sequência:** `sem-git` → `sem-head` → universo (com a isenção declarada) → `sem-baseline` → `head-mudou` → divergência → não rastreado. A primeira condição que casar decide o **veredito**, e nenhuma condição posterior é avaliada. O contador de universo é a exceção deliberada: ele imprime antes de `sem-baseline` porque vacuidade é achado mais forte que ausência de linha de base, e porque um consumidor sem baseline ainda quer saber que o escopo dele está vazio.

`head-mudou` vem **antes** de divergência e de não rastreado, e o motivo é a medição da tabela de D10, logo acima: quando o HEAD se moveu, os outros dois sinais foram calculados contra uma base diferente da que o baseline gravou, então o veredito que eles produziriam descreve o defeito errado — na medição, os dois ficam byte a byte idênticos aos de `t0` enquanto o disco está corrompido. "O gate commitou" é o diagnóstico mais específico disponível naquele estado, e é o que a ordem faz prevalecer.

O oitavo desfecho é `sem-baseline`, acrescentado na revisão 4 pela mesma razão que os outros dois inconclusivos: existe estado real que não casava com desfecho nenhum. São dois estados que colapsam num só desfecho — `--baseline` apontando para arquivo que ainda não existe (primeira execução da suíte) e invocação sem `--baseline` (o consumidor que declara a sentinela em `runtime.gates`). Nos dois a sentinela não tem o "antes" contra o qual comparar, e emitir veredito de divergência ali seria reprovar todo trabalho legítimo não commitado, que é exatamente o que D10 existe para evitar.

**O nono desfecho é `head-mudou`, e ele entra nesta revisão porque a revisão 4 o criou em D10 sem o pôr na enumeração.** O revisor da revisão 4 está certo e a acusação é literal: D10 gravava o sha do HEAD como quarta entrada do baseline e declarava a mensagem própria, M15 existia para provar que sem ela o caso escapa, e o desfecho não estava nem nesta lista, nem na ordem de avaliação, nem no vocabulário de `[10]`, nem entre os cenários. Pela regra que esta mesma spec escreveu três vezes, um galho sem cenário é indistinguível de um galho que não existe — e M15 apontava para um cenário inexistente. Remedi o galho antes de fechar, em fixture nova sob `$TMPDIR`, com o gate falso alterando um rastreado limpo e commitando:

```
rastreados : 1 -> 1  IGUAL
divergentes: [vazio] -> [vazio]  IGUAL
nao-rastr. : [vazio] -> [vazio]  IGUAL
HEAD       : 2f00ae3 -> 26c7094  MUDOU
disco      : corrompido
```

Os três primeiros sinais do baseline são byte a byte idênticos aos de `t0` com o disco corrompido; só o sha do HEAD muda. O desfecho fica, entra na enumeração, na ordem de avaliação, no vocabulário literal de `[10]` e ganha o cenário `[19]`, e o denominador do gate 2 vai junto — de `18` para `19`. O `rc` dele é **`1`**, junto de `divergencia` e `nao-rastreado`, e não `2`: a sentinela verificou, e o que ela achou foi violação, não impossibilidade de verificar. Os três galhos de `rc 2` continuam sendo exatamente `sem-git`, `sem-head` e `sem-baseline`. A alternativa que o veredito oferece (tirar a quarta entrada do baseline e M15 da matriz) está descartada pela medição acima: sem ela o caso escapa inteiro, e ele é o único que escapa.

O vocabulário é o da `template/.forge/scripts/lib/gate-universe.sh`, **literalmente**, e não uma grafia inventada aqui — a revisão 2 escrevia `— N arquivo(s) rastreado(s) comparado(s) (template/)`, e a lib emite `— <count> <item> examinado(s) (<scope>)`. Um cenário de contrato que fixasse a grafia inventada reprovaria a implementação canônica, então a sentinela **usa** `forge_universe_check tree-integrity <count> "arquivo(s) rastreado(s)" "<scope>"` e o cenário `[10]` afirma o que a lib produz:

```
OK           tree-integrity/universo — N arquivo(s) rastreado(s) examinado(s) (template/)
OK           tree-integrity/universo-vazio — 0 arquivo(s) rastreado(s) examinado(s) (template/); justificativa declarada: <motivo>
FAIL         tree-integrity/universo-vazio — 0 arquivo(s) rastreado(s) examinado(s) (template/): o gate não examinou nada.
FAIL         tree-integrity/divergencia — <gate> alterou N arquivo(s) rastreado(s): <lista>
FAIL         tree-integrity/nao-rastreado — <gate> criou N arquivo(s) não rastreado(s): <lista>
FAIL         tree-integrity/head-mudou — <gate> moveu o HEAD de <sha-t0> para <sha-agora>
INCONCLUSIVO tree-integrity/sem-git — <path> não é repositório git; integridade NÃO verificada
INCONCLUSIVO tree-integrity/sem-head — <path> é repositório git sem nenhum commit (git diff HEAD sai 128); integridade NÃO verificada
INCONCLUSIVO tree-integrity/sem-baseline — sem linha de base para comparar (<arquivo> ausente, ou --baseline não informado); divergência NÃO verificada
```

Usar a lib em vez de reimplementar a mensagem é o que dá o terceiro estado da allowlist de graça, e é o que `w144` vigia — os três estados de vacuidade que ele cobra (`OK universo`, `FAIL universo-vazio`, `OK universo-vazio … justificativa declarada`) são exatamente os três primeiros da lista acima.

`INCONCLUSIVO` existe porque o script é distribuído e um consumidor pode rodá-lo fora de um repositório git (tarball do npm, por exemplo) ou logo depois de um `git init` que ainda não commitou — estado real, não hipotético. Ele **não** é verde: `testing/gate-delivery-channel.md` diz em letra que um gate que não pôde rodar não pode ser reportado como aprovado e também não pode bloquear quem não tem o ambiente. Concretamente: `check-tree-integrity.sh` sai `2` nos **três** galhos de inconclusivo (distinto do `1`, que cobre divergência, não rastreado, `head-mudou` e erro de uso), com o token `sem-git`, `sem-head` ou `sem-baseline` distinguindo a causa; `run-all.sh` conta num contador próprio e imprime `SENTINELA=inconclusiva (<motivo>)` na linha de resultado, e o rc final da suíte não muda por causa dele. Neste repositório o `sem-baseline` ocorre uma vez por execução da suíte, na chamada que **antecede** o `--baseline-write`, e os outros dois não ocorrem; o gate tem cenário dedicado para cada um — `[5]` para `sem-git`, `[16]` para `sem-head` e `[18]` para `sem-baseline` — porque um galho sem cenário é um galho que ninguém sabe se existe.

**D12. A sentinela roda depois de cada gate, inclusive quando o gate FALHOU — e a saída dela é silenciosa no verde.**

O estado sujo é mais provável quando o gate morre no meio, antes de restaurar. O `run_one` de `tests/run-all.sh:71-84` já captura o rc; a chamada da sentinela vai depois dele, fora do condicional.

Uma consequência disso que precisa estar em letra, porque ela decide como a definição de pronto confere a fiação: `run_one` é também o laço das duas suítes `bats` (`tests/run-all.sh:97-99`), então a sentinela roda depois de **cada item que o `run_one` executa**, gate ou suíte `bats`. É deliberado — uma suíte `bats` não tem mais licença para sujar `template/` do que um gate —, e é por isso que a propriedade da fiação é "uma vez por item do `run_one`" e não "uma vez por gate". Sob `--gates-dir` as suítes `bats` são suprimidas (D14), de modo que nas execuções aninhadas dos cenários de canal os itens são só os gates falsos.

A saída da sentinela é capturada pelo `run_one` e **ecoada sob duas condições, e só elas**: quando a sentinela não conclui limpo (divergência, não rastreado, HEAD movido, ou qualquer um dos três inconclusivos), sempre; e quando a suíte roda em `-v`, também no verde. Sem essa regra a suíte imprimiria uma linha `OK tree-integrity/universo` por gate em toda execução — mais de uma centena de linhas de ruído no caminho feliz, num runner cuja saída normal é uma linha por gate. É a mesma economia que o `run_one` já faz com o log do gate, e a definição de pronto de §4 foi corrigida para dizer isso: a revisão 3 escrevia que a linha aparece "no modo `-v`" sem que nada na fiação a condicionasse.

**D13. A fiação mora em `tests/run-all.sh`, não em cada gate.**

A propriedade medida hoje é que **exatamente um** arquivo de `tests/` traz sentinela própria — `tests/w201-flag-como-valor-gate.sh:35` e `:378`, `REPO_SNAPSHOT_BEFORE`/`AFTER` sobre `git status --porcelain` do repositório inteiro —, e é a propriedade que importa, não a fração: `grep -rl 'REPO_SNAPSHOT_BEFORE\|sentinela' tests/*.sh` devolve só esse arquivo, contra os 132 de `ls tests/*.sh | wc -l` na medição de hoje. O denominador envelhece nesta mesma onda (vai a 134) e não pertence a asserção nenhuma; o que sustenta D13 é o numerador ser um. O `w201` é a arte prévia e é boa; o problema é que ela depende de cada autor lembrar. O próprio `tests/run-all.sh:34-36` já escreveu o argumento, a propósito de `GIT_CONFIG_COUNT`: *"É também a razão de estar AQUI e não em cada gate — o esquecimento é a falha que se quer eliminar."* A sentinela segue o mesmo idioma, no mesmo arquivo, pelo mesmo motivo.

**D14. `tests/run-all.sh` ganha `--gates-dir <dir>`, e é dele que a sentinela deriva o repositório a julgar. `FORGE_SUITE_ROOT` não existe.**

Isto é o que torna a prova de canal possível sem recursão: o gate cria um repositório git de fixture em `$T`, com um `template/` rastreado próprio e um diretório de gates falsos, e executa **o `tests/run-all.sh` real** apontado para lá.

**A variável de ambiente saiu, e é a correção mais importante desta decisão.** A revisão 3 publicava `FORGE_SUITE_ROOT` em três lugares — no título desta decisão, no parágrafo de dívida e em §2.8 — sem dizer o que ela faz, sem leitor declarado e sem cenário que a exercitasse. É a classe de `--snapshot` que a revisão 1 reprovou (LDG-0008/w192) e que eu mesmo removi da assinatura de D8, reintroduzida no runner. Ela sai da spec inteira. O que ela existia para resolver continua existindo e passa a ser resolvido **por derivação**, sem segundo botão.

**A derivação, declarada como propriedade.** `tests/run-all.sh:13-14` resolve `WS` pelo próprio `BASH_SOURCE` e faz `cd "$WS"`, sem override nenhum, de modo que o runner sempre opera com `WS` igual ao repositório real. A sentinela, porém, tem de julgar **o repositório que contém os gates que estão rodando** — do contrário os cenários `[6]`, `[7]` e `[8]` sujam o `template/` da fixture e a sentinela olha para o repositório real, o que os deixa vermelhos contra a implementação correta, ou pior, faz um gate julgar a árvore de trabalho de quem rodou a suíte. A regra é: **o repositório que a sentinela julga é o repositório git que contém o diretório de gates em execução** — que é `$WS` na invocação normal e a fixture quando `--gates-dir` é passado. Quando esse diretório não está em repositório git, a sentinela recebe esse fato e devolve `INCONCLUSIVO tree-integrity/sem-git`, que é o desfecho de D11 e não um caso especial do runner.

A comparação entre o caminho derivado e o caminho da fixture é **por identidade de arquivo, nunca por string** — a medição de §1.5 mostra `/var/…` contra `/private/var/…` para o mesmo diretório em `$TMPDIR`.

Nota mecânica, e esta veio de bancada: o parser de hoje é `for a in "$@"` com `*) echo "arg desconhecido: $a" >&2; exit 2` e **sem `shift`** (`tests/run-all.sh:18-24`), então uma flag com valor exige reestruturar o laço para `while [ $# -gt 0 ]` com `shift`. A grafia aceita é `--gates-dir <dir>`, com espaço; `--gates-dir=<dir>` **não** é aceita, e o cenário de contrato exige que ela caia no `arg desconhecido` com `exit 2`, para que a segunda grafia não nasça por acidente.

E `run-all.sh:14` faz `cd "$WS"` logo no início, então um `--gates-dir` relativo aponta para o lugar errado depois dele. Das duas saídas possíveis, a spec escolhe a segunda e diz por quê: **capturar o `PWD` original numa variável imediatamente antes da linha 14, e resolver `--gates-dir` contra ela**, em vez de mover o bloco de parsing para antes do `cd`. Mover o parsing reordena o cabeçalho do arquivo, e o cabeçalho contém o bloco `GIT_CONFIG_*` cuja contagem `w80[7]` afirma e a resolução de `WS` de que tudo depende; capturar o `PWD` é uma linha, não move nada, e não toca em nenhuma das duas coisas. Montei a cabeça do runner com essa forma em bancada e medi as três grafias:

```
== relativo, cwd na fixture ==
GATES_DIR=/var/folders/ns/…/T/onda-a-rev4/fx/gates-falsos
existe? SIM
toplevel derivado: /private/var/folders/ns/…/T/onda-a-rev4/fx
== absoluto ==
GATES_DIR=/var/folders/ns/…/T//onda-a-rev4/fx/gates-falsos
existe? SIM
toplevel derivado: /private/var/folders/ns/…/T/onda-a-rev4/fx
== grafia com = (tem de recusar) ==
arg desconhecido: --gates-dir=/var/folders/ns/…/T//onda-a-rev4/fx/gates-falsos
rc=2
```

**`--gates-dir` também suprime as suítes `bats`.** Sem isso, a execução aninhada dos cenários `[6]`, `[7]` e `[8]` rodaria `validators.bats` e `claude-contract.bats` do repositório real de dentro de um gate — caro, e capaz de contaminar a asserção `rc ≠ 0` com uma falha alheia ao gate falso plantado. A supressão é parte da semântica da flag, não uma otimização, e o cenário `[10]` a fixa: com `--gates-dir`, a linha `-- suítes bats (N) --` não aparece.

*Alternativa descartada — o gate reimplementar o laço do `run-all.sh`.* É exatamente o erro que `testing/gate-delivery-channel.md` nomeia: provar o alvo e não o canal. Um laço reimplementado passa nas duas versões do `run-all.sh`, com e sem a sentinela, e não distingue gate vivo de gate morto.

Acrescentar **um** botão só usado por teste é dívida, e ela fica registrada: `--gates-dir` é superfície pública nova do runner, documentada no cabeçalho do arquivo, e o cenário `[10]` a exercita nas três grafias — o que a impede de apodrecer. Era o botão de que a prova de canal precisa; o segundo, que a revisão 3 publicou sem leitor, foi removido em vez de documentado.

**D15. O escopo desta onda é `template/`, e só.**

Não se estende a sentinela ao runner do consumidor (`template/.forge/scripts/tests/run-all.sh`, 70 linhas, distribuído) nesta onda. Lá o escopo natural seria `.forge/`, e decidir o que é edição legítima de um consumidor durante a própria suíte é trabalho com decisão de produto dentro. Vira item de ledger.

A consequência do escopo estreito está medida e precisa ser dita: a sentinela **não** veria o dano do `.forge/HANDOFF.md` deste repositório, que é o que o cenário `[13]` do gate 1 cobre por conta própria.

### 2.3 O VERMELHO, antes do verde

Gate novo `tests/w<NNN>-tree-integrity-sentinel-gate.sh`. O fixture é um repositório git em `$T` com `template/arquivo-rastreado.txt` commitado, e um `--gates-dir` com gates falsos escritos por `printf`.

O mesmo preâmbulo que §1.5 ganhou vale aqui, e a revisão 3 o deixou implícito: **`[11]` (PBT) e `[12]` (contador de controle) nascem verdes por construção**, contam no `DECLARADOS=19` e **não têm vermelho a observar no passo 3** — a tabela os marca com `—` nas duas últimas colunas, o que é correto e silencioso demais para uma regra que a invariante 1 trata como achado. Dos dezenove, dezessete falham hoje por ausência real. E `[15]` é o caso à parte já declarado abaixo da tabela: o vermelho dele vem de um corpus plantado, não da ausência de funcionalidade no produto.

| # | Cenário | Asserção | Mensagem do vermelho hoje | Por que falha por ausência real |
|---|---|---|---|---|
| [1] | UNIDADE — árvore limpa | `rc = 0` e a linha `OK tree-integrity/universo — N arquivo(s)` com N > 0 | `bash: check-tree-integrity.sh: No such file` | o script não existe |
| [2] | UNIDADE — rastreado alterado no disco, **não** estagiado | `rc = 1`, saída **nomeia o caminho** | idem [1] | idem |
| [3] | UNIDADE — rastreado **stat-dirty** e de conteúdo intacto: o `mtime` mudou de forma que um primitivo stat-based **reporte**, e o conteúdo é byte-idêntico ao do HEAD. Provar esse estado é obrigação do implementador, e a nota de `[3]` abaixo da tabela mede por que o `touch` ingênuo não o produz | `rc = 0`, e **contrafactual:** sob M11 este cenário reprova | idem [1] | idem; o veredito de D9 é content-based e este é o cenário que o prova |
| [4] | UNIDADE — escopo sem nenhum arquivo rastreado | `rc = 1` e o token `universo-vazio` | idem [1] | idem |
| [5] | UNIDADE — `--path` fora de repositório git | `rc = 2` e o token `INCONCLUSIVO`/`sem-git`, distinto do `FAIL` de [2] | idem [1] | idem |
| [6] | **CANAL REAL** — `tests/run-all.sh` com `--gates-dir` de fixture, contendo gate falso que suja `template/` do fixture | `rc ≠ 0` e a saída **nomeia o gate falso** | `PASS=1 FAIL=0` — a suíte aprova com a árvore corrompida | é o defeito do LDG-0175 na forma pura; nada no harness compara `template/` com o HEAD |
| [7] | **CANAL REAL** — gate falso que **falha** e deixa a árvore suja | reprova nomeando **as duas** coisas: o gate falhou **e** sujou | `rc ≠ 0` pela falha, sem uma palavra sobre a sujeira | a sentinela não roda depois de gate que falhou porque não existe |
| [8] | **CANAL REAL** — gate falso que cria arquivo **não rastreado** sob `template/` | reprova **no gate**, nomeando o gate e o caminho | ninguém olha | D10 não existe |
| [9] | REGRESSÃO DE INTEGRIDADE — o próprio `w146` e o `w144`, executados sob a sentinela, não alteram `template/` | rodar cada um sob a sentinela e observar `OK` | não aplicável — hoje passaria por vacuidade | é o registro em teste da medição do §2.1, e é a metade (i-a) |
| [10] | CONTRATO | vocabulário literal (`tree-integrity/universo`, `/divergencia`, `/nao-rastreado`, `/head-mudou`, `/universo-vazio`, `/sem-git`, `/sem-head`, `/sem-baseline`), tabela de rc `0/1/2`, assinatura completa de D8 incluindo `--baseline-write`, e a semântica inteira de `--gates-dir`: grafia `--gates-dir <dir>` aceita, `--gates-dir=<dir>` recusada com `exit 2`, caminho relativo resolvido contra o `PWD` de invocação e não contra `$WS`, sentinela julgando o repositório git que contém o diretório de gates, e suítes `bats` suprimidas | tokens e flag não existem | consumidos por `run-all.sh` e por um consumidor via `runtime.gates` |
| [11] | PBT | ver §2.5 | — | — |
| [12] | CONTADOR DE CONTROLE | ver §2.6 | — | — |
| [13] | **STAGED** — rastreado corrompido no disco **e** `git add` aplicado | `rc = 1`, saída nomeia o caminho | `rc = 0` no desenho anterior — o falso-verde medido em §2.2 | é o estado que precede o dano do LDG-0175, e o índice o esconde |
| [14] | BASELINE — caminho já divergente do HEAD em `t0` | esse caminho **não** reprova; o **mesmo** caminho alterado de novo depois de `t0` reprova | não há baseline | D10 não existe; sem ele a sentinela reprovaria a própria rodada que a introduz |
| [15] | VARREDURA ESTÁTICA (metade i-b) — corpus de fixture com um gate falso que escreve em destino literal sob `$WS/template/` | o varredor **acusa** arquivo e linha no corpus de fixture, devolve **zero** no corpus real de `tests/`, e publica quantos arquivos varreu — denominador **derivado no momento da execução**, asserção `> 0`, nunca um literal | o varredor não existe | o vermelho vem do corpus plantado, não da ausência de violação real |
| [16] | INCONCLUSIVO `sem-head` — `--path` aponta para repositório git **sem nenhum commit**, com um arquivo sob `template/` já `git add`ado | `rc = 2` e o token `sem-head`, distinto do `sem-git` de `[5]` e do `universo-vazio` de `[4]`; a saída **não** contém `OK` | idem [1] | idem; e o galho não existia no desenho da revisão 2, que enumerava cinco desfechos |
| [17] | ISENÇÃO DECLARADA — escopo sem arquivo rastreado **e** entrada `tree-integrity  # motivo: <texto>` na `empty-universe-allowlist.txt` do fixture | `rc = 0` e a linha `OK tree-integrity/universo-vazio — 0 … justificativa declarada: <texto>`, distinta tanto do `OK …/universo` de `[1]` quanto do `FAIL …/universo-vazio` de `[4]`; e a mesma entrada **sem** `# motivo:` reprova | idem [1] | idem; é o terceiro estado que `w144` cobra e que a revisão 2 documentava na allowlist sem cenário que o exercitasse |
| [18] | INCONCLUSIVO `sem-baseline` — duas invocações: `--baseline <arquivo inexistente>`, e sem `--baseline` nenhum | nas duas, `rc = 2` e o token `sem-baseline`, distinto de `sem-git` e de `sem-head`; a linha do contador de universo **aparece** nas duas (ela não depende de linha de base) e nenhuma saída contém `FAIL …/divergencia`, mesmo com um rastreado alterado no disco | idem [1] | idem; é o oitavo desfecho de D11, acrescentado na revisão 4, e sem cenário ele seria indistinguível de um galho que não existe |
| [19] | **CANAL REAL** — gate falso que **altera um rastreado limpo de `template/` do fixture e commita**, sem adicionar nem remover arquivo | `rc ≠ 0` e a saída traz o token `head-mudou`, nomeia o gate falso e imprime os dois shas; e a saída **não** traz `divergencia` nem `nao-rastreado`, porque no estado medido esses dois sinais são idênticos aos de `t0` | `PASS=1 FAIL=0` — a suíte aprova com o rastreado corrompido e commitado | é o nono desfecho de D11 e o único caso que os outros três sinais do baseline não pegam, medido em D11; nada no harness compara o sha do HEAD antes e depois de um gate |

**Por que `[3]` não pode prescrever `touch` — medido nesta revisão, e a revisão 3 fechou este ponto na direção errada.** O cenário existe para provar que o veredito de D9 é **content-based**: um rastreado cujo `mtime` mudou sem que o conteúdo mudasse não é divergência. Ele só prova isso se o primitivo **errado** — o stat-based que M11 instala — reprovar ali. Montei a fixture na sequência que o gate de fato constrói (`git init`; arquivo sob `template/`; `git add -A`; `git commit`; `touch`; e o primitivo como **primeiro** comando git depois do `touch`), três fixtures novas, git 2.50.1:

```
fixture-nova run1: diff-files=[] | diff-HEAD=[]
fixture-nova run2: diff-files=[] | diff-HEAD=[]
fixture-nova run3: diff-files=[] | diff-HEAD=[]
```

O primitivo errado devolve **vazio**, igual ao certo. A causa é a regra *racy-clean* do git: o índice gravou o `stat` no mesmo segundo do `touch`, então o git desconfia do `stat`, recompara o conteúdo, acha idêntico e não reporta. Com o `touch` ingênuo, `[3]` passa com o primitivo certo e com o errado — é gate morto —, e M11 é no-op nele. A regra que a revisão 3 acrescentou (a sentinela tem de ser o primeiro comando git depois do `touch`) é **necessária e insuficiente**: ela protege contra o refresh do índice que o `git diff HEAD` provoca, não contra o racy-clean, que acontece antes de qualquer outro comando.

Medi então os candidatos a estado de fixture, três execuções de cada, fixture nova a cada vez, e **dois dos quatro que o veredito da revisão 3 sugere não servem** (medição da revisão 4; a linha da reescrita de mesmo conteúdo está retificada logo abaixo do bloco, com a medição da revisão 5):

```
touch -t futuro(2090)     diff-files=[template/.forge/arquivo-rastreado.txt] diff-HEAD=[]
touch -t antigo(1990)     diff-files=[template/.forge/arquivo-rastreado.txt] diff-HEAD=[]
touch apos folga 1.2s     diff-files=[template/.forge/arquivo-rastreado.txt] diff-HEAD=[]
reescrita mesmo conteudo  diff-files=[]                                      diff-HEAD=[]
chmod 755                 diff-files=[template/.forge/arquivo-rastreado.txt] diff-HEAD=[template/.forge/arquivo-rastreado.txt]
```

**Refuto dois pontos do veredito da revisão 3, com a medição acima, e corrijo um dos dois pela metade na revisão 5.** A reescrita com o mesmo conteúdo não serve de estado de fixture, e isso continua de pé — mas o motivo correto é "intermitente", não "nunca reporta", e a correção é do revisor da revisão 4, que mediu o primitivo reportando na bancada dele. Remedi em seis fixtures novas: `diff-files` devolveu vazio em 4 e reportou o caminho em 2, com `diff-HEAD` vazio nas seis.

```
  run1: diff-files=[vazio]                        diff-HEAD=[vazio]
  run2: diff-files=[template/.forge/f.txt]        diff-HEAD=[vazio]
  run3: diff-files=[vazio]                        diff-HEAD=[vazio]
  run4: diff-files=[vazio]                        diff-HEAD=[vazio]
  run5: diff-files=[template/.forge/f.txt]        diff-HEAD=[vazio]
  run6: diff-files=[vazio]                        diff-HEAD=[vazio]
```

É loteria de racy-clean, e loteria serve ainda **menos** como estado de fixture do que um sinal que nunca dispara: um estado que discrimina em parte das execuções produz exatamente o gate intermitente que a nota de `[4]` descreve. O mesmo vale para o `touch` ingênuo, e aqui a medição desta revisão foi mais dura que a da revisão 4: vazio em **10 de 10** fixtures novas na minha bancada, contra 1 de 5 reportando na do revisor — as duas medições dizem a mesma coisa, que o estado não é determinístico. O contraste com o remédio é limpo: `touch -t 209001010101` deu `diff-files` reportando e `diff-HEAD` vazio em **10 de 10**. E o `chmod` faz o primitivo **certo** reportar também, porque o modo do arquivo faz parte da entrada de árvore e `git diff HEAD` o vê: com `chmod`, `[3]` ficaria vermelho contra a implementação correta, que é vermelho fabricado, exatamente o que a invariante 1 proíbe. Dos quatro remédios sugeridos, sobrevivem dois — `touch -t` com data distante e `touch` com folga real de `mtime` —, e o resto do veredito procede inteiro.

**O que a spec fixa, então, e o que ela deixa para o implementador.** A propriedade é: o rastreado de `[3]` está em estado **stat-dirty com conteúdo intacto** — o `mtime` divergiu do que o índice registrou, de forma que um primitivo stat-based o reporte, e o conteúdo é byte-idêntico ao do HEAD. O contrafactual é: com o veredito de D9, `rc = 0`; sob M11, `[3]` reprova. Quem escolhe como produzir esse estado é o implementador, e ele tem duas obrigações: provar que o estado é stat-dirty **antes** de rodar a asserção (o primitivo stat-based reporta o caminho), e provar que a mutação morde, em N de N execuções. Essa prova de estado é a exceção explícita da regra de ordem de §2.4, e é exceção medida: `git diff-files` não refresca o índice, então chamá-lo antes da sentinela não apaga o sinal — a saída está em §2.4. As duas medições vão para o PR. O `touch` sozinho não satisfaz a primeira, e é isso que esta nota registra para que ninguém o reescreva no gate por parecer óbvio.

O cenário `[6]` é o vermelho central e ele falha pela ausência real: `grep -rn 'diff-files\|diff .*HEAD\|status --porcelain' tests/*.sh template/.forge/hooks/` mostra que nenhum sítio compara `template/` contra o HEAD ao fim de um gate. Não há o que desligar para forjar o vermelho — a funcionalidade simplesmente não existe.

**O denominador de `[15]` é derivado, e o literal que a revisão 2 pôs ali envelhece no dia da entrega.** A revisão 2 escrevia "publica quantos arquivos varreu (132 hoje)", que é o mesmo mecanismo do `434 → 435` pelo qual o B6 reprovou a revisão 1, num cenário criado pela revisão 2. Medi: `ls tests/*.sh | wc -l` → **132** hoje, e esta onda acrescenta dois arquivos a `tests/` (`w<NNN>-handoff-destructive-write-gate.sh` e `w<NNN>-tree-integrity-sentinel-gate.sh`), de modo que o número correto na entrega é **134**, e 135 na primeira onda seguinte que criar um gate. O varredor conta o que ele mesmo abriu, no momento em que abre, a asserção é `> 0` mais a propriedade "zero violação no corpus real e exatamente a violação plantada no corpus de fixture", e nenhum total aparece no fonte do gate. O `132` desta linha é medição datada, como o `434` de §2.6 — serve para o leitor reconhecer a ordem de grandeza e para nada mais.

O cenário `[15]` merece a nota que a invariante 1 exige, porque é o único cujo vermelho não vem da ausência de funcionalidade no produto: ele vem de um **corpus de fixture plantado**, com uma violação real que o varredor tem de acusar. O varredor não existe hoje, então o cenário falha primeiro por ausência; depois de implementado, o corpus plantado é o que o mantém honesto, e a varredura do corpus real de `tests/` é a regressão. Um `[15]` que só varresse o corpus real seria verde permanente e não valeria nada — é a diferença entre "não encontrei violação" e "não sei procurar".

### 2.4 Prova de mutação, com controle e recontrole

A coluna **Estado** vale aqui pelo mesmo motivo de §1.6, e a linha de M11 é a prova de que ela é necessária: a revisão 2 declarou o efeito de M11 por dedução e errou.

| Mutação | Alvo | O gate tem de dizer | Estado | Recontrole |
|---|---|---|---|---|
| M4 — remover a chamada da sentinela do laço de `run_one` | `tests/run-all.sh` | `FAIL [6]`, `[7]`, `[8]` — o canal morreu; `[1]`-`[5]` continuam **verdes**, provando que o teste de unidade sozinho não vê a morte do canal | A MEDIR | restaurar por `cp` + `cmp -s`, e reexecutar `[6]` |
| M5 — fazer o veredito sempre concluir "limpo" | `check-tree-integrity.sh` | `FAIL [2]`, `[6]` e `[13]`; `[3]` continua verde (é o cenário do falso positivo) | A MEDIR | restaurar + `cmp -s` + reexecutar `[2]` |
| M6 — mover a chamada da sentinela para dentro do ramo de sucesso do `run_one` | `tests/run-all.sh` | `FAIL [7]` apenas | A MEDIR | restaurar + `cmp -s` + reexecutar `[7]` |
| M7 — remover a guarda de universo vazio | `check-tree-integrity.sh` | `FAIL [4]` **e `[17]`** — a mesma guarda decide os dois vazios, e a isenção declarada é galho dela; `[1]` continua verde | A MEDIR | restaurar + `cmp -s` + reexecutar `[4]` e `[17]` |
| M11 — trocar o veredito de D9 por um primitivo **stat-based**, que compara a árvore com o índice em vez do HEAD | `check-tree-integrity.sh` | **`FAIL [3]` e `FAIL [13]`**; `[2]` e `[6]` continuam **verdes** | **MEDIDO** para `[2]`, `[3]` e `[13]`, com a ressalva da nota de `[3]` em §2.3: com a fixture de `touch` ingênuo a mutação é **no-op** em `[3]`, e a obrigação de provar que ela morde é do implementador | restaurar + `cmp -s` + reexecutar `[3]` e `[13]` |
| M12 — ignorar o baseline e reprovar toda divergência | `check-tree-integrity.sh` | `FAIL [14]` apenas | A MEDIR | restaurar + `cmp -s` + reexecutar `[14]` |
| M13 — fazer o varredor estático devolver sempre vazio | `check-tree-integrity.sh` | `FAIL [15]` apenas | A MEDIR | restaurar + `cmp -s` + reexecutar `[15]` |
| M14 — capturar o `rc 128` do HEAD inexistente com `\|\| true` e seguir para o veredito | `check-tree-integrity.sh` | `FAIL [16]` apenas — a saída vira `OK` sobre árvore não verificada, que é o falso-verde que o galho existe para impedir | A MEDIR | restaurar + `cmp -s` + reexecutar `[16]` |
| M16 — fazer o galho `sem-baseline` emitir veredito de divergência em vez de inconclusivo | `check-tree-integrity.sh` | `FAIL [18]` apenas — a saída passa a trazer `FAIL …/divergencia` sobre uma árvore que ninguém autorizou a julgar, e `[2]`, `[13]` e `[14]` continuam verdes | A MEDIR | restaurar + `cmp -s` + reexecutar `[18]` |
| M15 — não gravar o sha do HEAD no baseline | `check-tree-integrity.sh` | `FAIL [19]` apenas — os outros três sinais do baseline ficam byte a byte idênticos no cenário `[19]` (medido em D11) e nada mais o pega; `[2]`, `[13]` e `[14]` continuam verdes | A MEDIR | restaurar + `cmp -s` + reexecutar `[19]` |

Que M4 derrube `[6]`-`[8]` e **não** derrube `[1]`-`[5]` é a asserção mais importante do conjunto: é ela que demonstra, dentro do próprio gate, que a prova de canal e a prova de alvo medem coisas diferentes.

**M11 derruba `[3]` também, e isso está medido, não deduzido.** A revisão 2 escrevia "`FAIL [13]` apenas; `[2]` e `[6]` continuam verdes", e o revisor da revisão 2 acertou ao dizer que `[3]` cai junto. Remedi em fixture:

```
### [3] — touch sem mudar conteúdo, o cenário que exige rc=0
  git diff-files --name-only -- template/      → template/.forge/f7.txt      (M11: reprovaria)
  git diff --name-status -z HEAD -- template/  → (vazio)                     (D9: rc=0, correto)
### [2] — conteúdo alterado, NÃO estagiado
  git diff-files --name-only                   → template/.forge/outro.txt
  git diff --name-status -z HEAD               → M template/.forge/outro.txt
### [13] — corrompido E estagiado
  git diff-files --name-only                   → (vazio)                     (M11: falso-verde)
  git diff --name-status -z HEAD               → M template/.forge/outro.txt
```

A correção fortalece a mutação em vez de enfraquecê-la: M11 passa a provar que o primitivo escolhido é ao mesmo tempo **content-based** (`[3]`) e **ancorado no HEAD** (`[13]`), e que nenhum dos dois sozinho basta. Um implementador que seguisse a linha antiga ao pé da letra ou registraria observação falsa, ou trataria o `FAIL [3]` extra como defeito da própria implementação.

**E uma condição de ordem que a mutação precisa respeitar, ou ela vira no-op — também medida.** `git diff HEAD` **refresca o índice em disco**, e com isso limpa o estado *stat-dirty* que o `touch` criou; um `git diff-files` executado **depois** dele devolve vazio. Medi as duas ordens na mesma fixture:

```
### ORDEM A — diff-files primeiro
  diff-files                     → template/.forge/f7.txt
  diff --name-status -z HEAD     → (vazio)
  diff-files (depois do diff HEAD) → (vazio)      <- o refresh apagou o sinal
### ORDEM B — diff HEAD primeiro
  diff --name-status -z HEAD     → (vazio)
  diff-files                     → (vazio)        <- M11 vira no-op
```

As duas ordens acima foram medidas numa fixture cujo arquivo **já estava stat-dirty**; sem isso a `ORDEM A` também devolve vazio, e é o que a nota de `[3]` em §2.3 mede. Junte as duas medições e a regra fica com dois lados, ambos necessários e nenhum suficiente sozinho:

1. **Estado:** o rastreado de `[3]` precisa estar stat-dirty de verdade, e o implementador prova isso com o primitivo stat-based **antes** de rodar a asserção. O `touch` ingênuo não produz esse estado, pela regra racy-clean.
2. **Ordem:** entre o estado produzido e a invocação da sentinela não pode haver **nenhum comando git que refresque o índice** — `git diff HEAD`, `git status` e parentes —, porque o refresh grava o `stat` novo no índice e apaga o sinal. A prova de estado da obrigação 1 é **exceção explícita**, e ela é exceção medida, não concedida: `git diff-files` **não** refresca o índice, então chamá-lo antes da sentinela não mata o sinal.

A redação anterior desta regra — "a sentinela tem de ser o primeiro comando git depois do estado" — colidia de letra com a obrigação 1, que manda rodar o primitivo stat-based antes da asserção. O revisor da revisão 4 mediu que o conflito é de letra e não de efeito, e reproduzi: com o arquivo em `touch -t 209001010101`, duas chamadas seguidas de `git diff-files` reportam o caminho nas duas, em 3 de 3 fixtures, e o sinal só some depois de um `git diff --name-only HEAD`:

```
  run1: 1a=[template/.forge/f.txt] 2a=[template/.forge/f.txt] diffHEAD=[vazio] apos-diffHEAD=[vazio]
  run2: 1a=[template/.forge/f.txt] 2a=[template/.forge/f.txt] diffHEAD=[vazio] apos-diffHEAD=[vazio]
  run3: 1a=[template/.forge/f.txt] 2a=[template/.forge/f.txt] diffHEAD=[vazio] apos-diffHEAD=[vazio]
```

A regra reescrita nomeia o que de fato importa — refresh do índice —, em vez de proibir por posição um comando que não faz mal nenhum. As duas obrigações passam a ser cumpríveis juntas, que é como elas sempre precisaram ser.

Sem os dois, M11 é no-op em `[3]` e a linha da matriz volta a mentir por um caminho que nenhum `cmp` detecta, que é o padrão de LDG-0164 e de `feedback-mutacao-fantasma-restore`. A regra fica no cabeçalho do cenário e é conferida por leitura no PR.

Mecânica idêntica à do §1.6 — controle por `cp` da árvore de trabalho, nunca do HEAD; `perl -0pi` com aspas simples e `$` escapado (LDG-0164); `cmp -s` depois do `cp`; e recontrole obrigatório.

M5, M7, M11, M12 e M13 mutam um arquivo **rastreado sob `template/`**, que é justamente o que a sentinela existe para proibir. Não há contradição — a sentinela compara **depois** de o gate terminar, e o gate restaura antes de terminar. E o fecho é bonito: **se a restauração falhar, quem pega é a própria sentinela**, no gate seguinte da suíte. A guarda protege contra o modo de falha do teste que a testa, que é exatamente o cenário de `feedback-mutacao-fantasma-restore`.

### 2.5 PBT

Superfície de entrada: o `pathspec` de `--scope` e a ordem dos caminhos.

- **P4 — invariância de grafia:** para todo conjunto gerado de arquivos sujos, o conjunto de caminhos reportado é o mesmo para `template/`, `template` e `./template/`. É normalização de caminho, e a invariante 5 do plano-mestre nomeia normalizador de caminho como superfície obrigatória de PBT (`w132[15]` já faz isso para `normalizePath`, e o idioma se copia de lá).
- **P5 — idempotência do baseline:** dois baselines consecutivos capturados sem escrita entre eles são iguais byte a byte.
- **P6 — insensibilidade a caminho hostil:** para todo caminho gerado com espaço, acento ou `$` no nome, um arquivo sujo com esse nome é reportado com o nome íntegro. É o que justifica o `-z` de D9 e o que um teste com três nomes bem-comportados nunca pegaria.

Sem PBT sobre "o conteúdo divergiu", que é decidido pelo `git` e não por código nosso — testar isso seria testar o `git`.

### 2.6 Contador de controle, e o denominador que NÃO pode ser literal

Dois contadores independentes, e o segundo é o que impede aprovação por vacuidade:

1. **Do gate:** `19 cenário(s) executado(s) de 19 declarado(s)`, denominador literal no fonte — universo fechado, conhecido em tempo de escrita, e a única categoria de literal que a invariante 3 permite, porque a divergência entre executados e declarados **é** o achado. Eram 15 na revisão 2, 17 na 3, 18 na 4 com a entrada de `[18]` (`sem-baseline`), e `[19]` (`head-mudou`) entra nesta revisão junto com o nono desfecho de D11; o denominador vai junto — um denominador que não acompanha os cenários é o próprio defeito que o contador existe para pegar, e foi exatamente esse defeito, na forma de um desfecho sem cenário, que a revisão 4 pegou.
2. **Da sentinela, a cada invocação:** o número de arquivos **rastreados** dentro do escopo, obtido com `git ls-files -- <scope> | wc -l`. Zero reprova (`tree-integrity/universo-vazio`), salvo isenção declarada com motivo, que é o galho de `[17]`.
3. **Do varredor estático de `[15]`:** o número de arquivos de `tests/` que ele abriu, **contado no momento em que abre**, com asserção `> 0`. Nunca literal no fonte: hoje `ls tests/*.sh | wc -l` → 132, esta onda o leva a 134, e a onda seguinte que criar um gate o leva a 135.

O denominador da sentinela é **capturado no baseline, no início da suíte, e nunca escrito literalmente no fonte**. A revisão 1 desta spec fixava `434` em prosa e na definição de pronto, e a revisão 1 do revisor pegou o erro: D8 cria `template/.forge/scripts/check-tree-integrity.sh`, arquivo novo e rastreado sob `template/`, então o número correto **no dia da entrega é 435** — e amanhã é outro. Medi: `git ls-files template/ | wc -l` → **434** hoje, 435 depois desta onda, e nenhum dos dois pertence ao código. Um contador cujo denominador é literal e cuja entrega o invalida é o contador de denominador derivado-invertido que a invariante 3 proíbe.

Regra, então: o baseline grava o número; cada invocação recompara; se o número mudar durante a execução da suíte, isso **é** a violação (alguém adicionou ou removeu arquivo rastreado sob `template/` no meio da suíte) e reprova nomeando a diferença, com o número de antes e o de depois.

Chave de allowlist: `tree-integrity` passa a ser documentada na lista de gate-keys do cabeçalho de `template/.forge/empty-universe-allowlist.txt` (linhas 18-28), **sem entrada de isenção** — a documentação da chave é o que permite a um consumidor com `template/` inexistente declarar a isenção com motivo, em vez de descobrir na marra que a chave não é reconhecida. E a documentação sozinha não bastava: a revisão 2 documentava a chave sem cenário que exercitasse o galho, e um galho sem cenário é indistinguível de um galho que não existe. O cenário `[17]` fecha isso, exercitando os dois lados do que a `forge_universe_waiver` decide — com `# motivo:` o estado é `OK tree-integrity/universo-vazio … justificativa declarada: <texto>` e o rc é `0`; sem `# motivo:` a lib reprova por isenção anônima, e o cenário exige as duas metades.

**Varredura de strings de produção, e ela é o que impede esta onda de deixar gate alheio vermelho.** Todo token que esta onda faz a produção imprimir, ou que ela toca num arquivo cuja saída algum gate afirma, foi grepado em `tests/` antes de entrar na spec, e o resultado é a lista abaixo — nominal, porque uma lista genérica não serve de nada no PR:

| o que a onda toca | quem afirma em `tests/` | veredito |
|---|---|---|
| vocabulário `tree-integrity/*` | ninguém hoje; `w144` afirma a **forma** dos três estados de vacuidade | por isso a sentinela usa `forge_universe_check` e não uma grafia própria |
| bloco de comentário da `empty-universe-allowlist.txt` | `w109`, `w144`, `w151`, `w171` — todos escrevem allowlist **própria em fixture**, nenhum afirma o cabeçalho do arquivo do template | seguro |
| parser de `tests/run-all.sh` (`--gates-dir`, `while`/`shift`) | `w80[3]` (`--list` enumera todos os `*-gate.sh`), `w80[4]` (sem recursão), `w80[7]` (`grep -cE 'GIT_CONFIG_KEY_[0-9]+='` conferido contra `GIT_CONFIG_COUNT`), `w146[7]` (`--list` contém a faixa `w19*` e os quatro fixos) | a reestruturação **não** pode mexer no bloco `GIT_CONFIG_*` nem mudar o formato do `--list`; os quatro cenários entram na definição de pronto. A supressão das suítes `bats` de D14 é condicionada a `--gates-dir` e portanto invisível a `w80` e a `w146`, que invocam o runner sem a flag — e é por isso que ela é condicionada em vez de global |
| `handoff-gen.sh` (D6 parsing, D18 guarda de `node`) | `w101[4]` afirma a string literal `WARN: drift local em scripts/handoff-gen.sh`, e usa o arquivo como cobaia de drift em fixture; `w63[e]` só confere existência | seguro — a onda não muda a string do `WARN` nem o caminho do arquivo |
| `handoff-render.mjs` (D1, D2, D4, D16) | `w60[1]`-`[4]` | seguro pelo que §1.10 já mede, com uma ressalva nova: `w60` roda com `FORGE_ROOT` em `/tmp` e o `cwd` na árvore real, e é por isso que D3 exige `git -C "$ROOT"` |
| `on-session-end.sh` (D17) | nenhum gate afirma a saída do hook (ele não imprime nada) | seguro |
| string `OK <path>` do `handoff-gen.sh` | `grep -n 'OK .*HANDOFF' tests/*.sh` → nenhum | seguro; a onda a preserva de todo modo |

Nenhuma string de produção existente **muda** nesta onda: o que há são acréscimos (`INCONCLUSIVO`, a mensagem de recusa, o vocabulário novo da sentinela). Se a implementação precisar mudar alguma delas, a mudança só entra junto com a edição nominal dos gates que a afirmam, e a lista dos gates editados entra na definição de pronto — é a regra que quase deixou quatro gates rastreados vermelhos numa onda vizinha.

### 2.7 Níveis de teste

- **Unitário:** `[1]`-`[5]`, `[13]`, `[16]`, `[17]` e `[18]`, sobre `check-tree-integrity.sh` em fixture hermético. `[16]`, `[17]` e `[18]` são os três desfechos que a enumeração original de D11 não cobria — repositório git sem HEAD, vazio com isenção declarada e ausência de linha de base —, e cada um tem cenário próprio porque um galho sem cenário é indistinguível de um galho que não existe.
- **PBT:** §2.5.
- **Contrato:** `[10]`. `check-tree-integrity.sh` nasce como maquinaria distribuída, declarável em `runtime.gates` por um consumidor; o vocabulário de saída (o da `lib/gate-universe.sh`, literal), a tabela de rc `0/1/2`, a assinatura completa incluindo `--baseline-write`, e a grafia das flags do runner são a fronteira.
- **Integração / E2E:** `[6]`, `[7]`, `[8]`, `[14]` e `[19]` — o `tests/run-all.sh` real, executando gates reais (falsos, mas gates), sobre um repositório git real, com veredito real. É o que `gate-delivery-channel.md` exige e é o que faltou no `w146`, que prova o alvo (`check-suite-wiring.sh`) muito bem e nunca provou que ninguém suja a árvore ao provar isso.
- **`[9]` é regressão de fato medido**, não teste de nível: registra em código a medição do §2.1, para que a atribuição errada do LDG-0175 não seja "redescoberta" numa rodada futura. É a metade (i-a).
- **`[15]` é varredura de corpus**, com corpus plantado para o vermelho e corpus real para a regressão. É a metade (i-b).

### 2.8 Retrocompatibilidade

**`tests/run-all.sh` não é distribuído.** `package.json:files` = `bin/`, `template/`, `installer/gitignore.patch`, `installer/gitattributes.patch`, `installer/install.sh`, `installer/removed-files.txt`, `CHANGELOG.md`. Mudança ali afeta este repositório e mais nada. `--gates-dir` é adição; sem ela o comportamento é idêntico ao de hoje, e `--list` (do qual `w146[7]` depende) não muda de formato. A reestruturação do parser para `while`/`shift` precisa preservar `-v`, `--verbose` e `--list` com a mesma semântica, e o cenário `[10]` fixa isso.

**`check-tree-integrity.sh` é arquivo novo.** Chega aos consumidores no próximo `update` como maquinaria; não substitui nada, não muda comportamento de nada, e não é declarado em `runtime.gates` de ninguém por padrão. Ele acrescenta **um** arquivo rastreado sob `template/` — delta de `+1`, medido pelo par `ANTES`/`DEPOIS` de §4, sobre a base datada de 434 de hoje — e `npx-pack-gate` continua verde, porque sua guarda é um **piso** (`forgeCount < 200` reprova), e um arquivo a mais só afasta o valor do piso.

**`empty-universe-allowlist.txt` muda só no bloco de comentário** (a lista de gate-keys documentadas). O arquivo é lido por `forge_universe_waiver` (`lib/gate-universe.sh`), que ignora linhas iniciadas por `#`; nenhuma isenção existente é afetada.

**O que fica devendo, declarado:** um consumidor que rode a própria suíte por `template/.forge/scripts/tests/run-all.sh` continua sem sentinela nenhuma. É D15, e vira item de ledger nesta onda.

---

## 3. O que a Onda A explicitamente NÃO faz

- **Não cria guarda de pre-commit ou pre-push que proíba mudança sob `template/`.** É o que o LDG-0175 sugere em letra ("um guard que reprove commit quando `template/` tem modificação não intencional") e é irrealizável: `template/` **é o código-fonte do produto**, intenção não é observável no commit, e a medição prova o ponto — quando escrevi a revisão 3, `git status --porcelain -- template/` devolvia `M template/.forge/commands/waves/pentest.md` e `M template/.forge/scripts/pentest-ops.sh`, trabalho legítimo da Fase 0, e uma guarda de pre-commit teria reprovado aquela rodada. Hoje esse mesmo comando devolve vazio, porque a Fase 0 foi commitada em `c41eead` — o que muda o exemplo e **não** muda o argumento: a guarda seria acionada por qualquer rodada seguinte que voltasse a tocar em `template/`, e é isso que uma guarda de intenção não observável faz. O que **é** observável é a mudança durante a execução de um gate, contra uma linha de base capturada antes dela, e é isso que D7 e D10 vigiam.
- **Não estende a sentinela ao runner do consumidor** (D15).
- **Não converte o `.forge/HANDOFF.md` de nenhum consumidor**, nem insere marcadores em arquivo existente (D1). Migração é decisão de quem escreveu o texto.
- **Não absorve o `path-anchoring` do `axis-go-cloud`** (§1.10, providência 2) — é LDG-0171 e Onda F, com item de ledger e aviso ao consumidor antes da release.
- **Não toca em LDG-0171** (`SCRIPT_DIR/../..`, medido em **37 sítios** com `grep -rn 'SCRIPT_DIR/\.\./\.\.' template/.forge/scripts/ | wc -l`), embora esse padrão seja um caminho plausível para escrita acidental em `template/`. É Onda F, e a sentinela desta onda pega o efeito independentemente da causa.
- **Não toca em #119, #106 nem LDG-0157**, mesmo #120 sendo declaradamente da mesma classe ("não consegui ler" virando "não há nada"). É Onda D. Aqui a classe é fechada só para o gerador de handoff, e o terceiro estado que D18 acrescenta vale só para ele.
- **Não toca em #101.** A dependência está nomeada em §1.10 e não bloqueia esta onda.
- **Não altera o formato do documento de handoff** — nem o template, nem as cinco seções, nem a semântica dos marcadores. D16 muda **onde o leitor procura o fim do slot**, não o que o documento contém. As asserções `w60[1]`, `[2]`, `[3]` e `[4]` continuam valendo palavra por palavra.

---

## 4. Ordem de execução e definição de pronto

1. Alocar os dois ordinais com o orquestrador (invariante 10), contra `origin/*` **e** contra as branches em voo desta rodada. Máximo publicado hoje: **w207** — medição datada, a ser refeita no momento da alocação, contra `origin/*` e contra as branches em voo.
2. Remedir, **em bancada ociosa e com a suíte parada**, os seis primitivos da tabela de D9, três execuções cada, e colar as 18 linhas no PR. A decisão de D9 é por correção e não muda com o número; o que muda é a extrapolação de custo agregado, que hoje é declaradamente extrapolação.
3. Escrever os dois gates **inteiros**, com todos os cenários, os contadores de controle e as mutações. Executar. **Colar a saída vermelha no PR.**
4. Implementar `check-tree-integrity.sh` e fiá-lo no `tests/run-all.sh`; verde de `[1]`-`[19]` do gate 2.
5. Implementar no gerador: recusa (D1), backup com expurgo (D2/D3), escrita condicional (D4), `--force` com parsing (D6), slot pelo último `:END` (D16), `FORGE_ROOT` no hook (D17), guarda de `node` (D18) e recibo (D19); verde de `[1]`-`[13]` do gate 1.
6. Executar as dezesseis mutações (M1-M16), observar cada `FAIL` esperado, restaurar por `cp` da árvore de trabalho + `cmp -s`, e **recontrolar** cada uma. Antes de registrar qualquer linha, provar que a mutação **morde**: uma mutação no-op corrige o cenário, nunca a linha (§1.6).
7. Suíte inteira verde, com `bash -n` limpo em tudo que foi tocado (invariante 8, bash 3.2 — sem `declare -A`, `${var,,}`, `${var^^}`, `mapfile`, `readarray`).
8. `CHANGELOG.md`, e registro no ledger: LDG-0175 `resolved` com a **correção do diagnóstico** do §2.1 escrita no campo `detail` (fechar por reclassificação silenciosa é o que o plano-mestre proíbe); item novo de D15; e item novo do `path-anchoring` do `axis-go-cloud` (§1.10, providência 3).
9. PR contra `develop`, sem texto de coautoria de IA.

**Definição de pronto, verificável por comando:**

```
bash tests/w<NNN>-handoff-destructive-write-gate.sh   → PASS, com o contador 13/13
bash tests/w<NNN>-tree-integrity-sentinel-gate.sh     → PASS, com o contador 19/19
npm test                                              → suíte 100% verde. Sem -v a sentinela é
                                                        silenciosa no verde; sob -v a linha
                                                        "OK tree-integrity/universo — <N> arquivo(s)"
                                                        aparece. A conferência é da PROPRIEDADE de
                                                        D12, não de uma contagem — ver a nota abaixo
                                                        do bloco, que mede por que contar ocorrências
                                                        na saída da suíte não fecha
bash tests/w80-suite-gate.sh                          → PASS  (o parser novo do run-all.sh preserva
bash tests/w146-suite-invocation-gate.sh              → PASS   --list, -v e o bloco GIT_CONFIG_*)
bash tests/w60-handoff-gen-gate.sh                    → PASS  (o gerador novo não afrouxa [1]-[4])
bash tests/w101-update-preserve-gate.sh               → PASS  (a string do WARN de drift não mudou)
bash tests/w144-gate-control-counter-gate.sh          → PASS  (os três estados de vacuidade)
gh issue view 120 --json state                        → CLOSED
node -e '…ledger…' | grep LDG-0175                    → resolved

# universo de template/ — DELTA medido, nunca total literal:
ANTES=$(git -C <repo> ls-files template/ | wc -l)     # medir ANTES de começar e guardar
DEPOIS=$(git -C <repo> ls-files template/ | wc -l)    # medir ao fim
[ "$((DEPOIS - ANTES))" -eq 1 ]                       # a onda acrescenta exatamente 1 rastreado
```

**A conferência da linha da sentinela é de propriedade, e a contagem que a revisão 4 escrevia não fecha — por duas razões lidas no fonte de `tests/run-all.sh`, e o revisor tem razão nas duas.** A primeira é que `run_one` (linhas 71-84) ecoa, sob `-v`, o **log inteiro** de cada item; o log dos dois gates desta onda contém linhas de universo próprias (`[1]`, `[17]` e `[18]` chamam a sentinela direto) e as das execuções aninhadas de `[6]`-`[9]`, `[14]` e `[19]`, de modo que um `grep -c` sobre a saída da suíte conta ecos, não invocações. A segunda é que `run_one` é o mesmo laço usado para as duas suítes `bats` (linhas 97-99), então uma chamada de sentinela colocada nele "fora do condicional", como D12 manda, roda também depois delas — o que já descasa a contagem em dois antes de qualquer eco. A propriedade a conferir é: **a sentinela é invocada exatamente uma vez por item executado pelo `run_one` — gates e suítes `bats` — e emite exatamente uma linha de universo por invocação; no verde a linha só aparece sob `-v`, e fora do verde aparece sempre.** Como conferi-la é de quem executa, e a leitura vale mais que a contagem: um `grep` sobre a saída agregada não distingue invocação de eco.

Dois denominadores literais sobrevivem nesta lista, e os dois são a única categoria que a invariante 3 permite: `13/13` e `19/19` são as listas de cenários que os próprios gates declaram, fechadas por construção em tempo de escrita, e a divergência entre executado e declarado **é** o achado que o contador existe para produzir. Tudo o mais é derivado. O `<N>` da linha da sentinela não é literal em lugar nenhum — nem no fonte, nem aqui: é o número que o baseline capturou no início daquela execução, e a asserção é que ele é maior que zero e igual ao do baseline.

O total de arquivos rastreados sob `template/` **saiu da definição de pronto como número**. A revisão 1 escrevia `434`, o B6 a reprovou porque a própria onda o levava a 435, e a revisão 2 trocou `434` por `435` — que é o mesmo defeito com o valor atualizado, porque qualquer outra onda que aterrisse antes desta o invalida de novo. O que se verifica é o **delta**: a onda acrescenta exatamente um arquivo rastreado (`check-tree-integrity.sh`), e o par `ANTES`/`DEPOIS` acima mede isso sem gravar total nenhum. A medição de hoje, `git ls-files template/ | wc -l` → 434, fica no corpo da spec como referência datada e não como expectativa.

E os cinco gates rastreados acrescentados à lista não são zelo: são o resultado da varredura de strings de §2.6, e cada um deles afirma alguma coisa que esta onda toca. Um gate desses vermelho no PR é achado da revisão adversarial, e a lista dos que a implementação precisou editar — se precisar — entra na descrição do PR.

E três verificações que não são de comando e são as que importam:

- Rodar o gerador contra uma **cópia** do `.forge/HANDOFF.md` do `axis-go-cloud` (8.090 bytes, zero marcadores), em fixture sob `$TMPDIR` com o `cwd` dentro dela, e observar que os 8.090 bytes continuam lá.
- Conferir, ao fim de tudo, que `.forge/HANDOFF.md` **deste** repositório continua com o mesmo sha256 de antes do trabalho — é o que o cenário `[13]` automatiza, e o motivo está em §1.3.
- Avisar o `axis-go-cloud` pelo canal de liaison, antes da release, que o `handoff-gen.sh` local com o bloco `forge:path-anchoring` será sobrescrito pelo overlay, com `WARN` nominal e backup em `.git/forge-backups/forge-N`.

---

## 5. Respostas ao veredito da revisão 1

Um item por bloqueador. Onde o revisor mediu, remedi antes de aceitar; onde ele errou, o comando que o refuta está aqui e a posição fica de pé.

**B1 — D9 comparava com o índice e aprovava árvore corrompida. PROCEDE, e o desenho mudou.** Reproduzi o falso-verde em fixture própria (`$TMPDIR/onda-a-b1.*`), com o roteiro integral publicado em §2.2: corrompi `template/.forge/f7.txt`, rodei `git add`, e `git diff-files --name-only -- template/` devolveu **vazio** enquanto `git diff --quiet -- <path>` devolveu **rc=0** e o disco tinha `exit 1`. O desenho de dois estágios **desapareceu**: o veredito passa a ser um estágio, `git diff --name-status -z HEAD -- <scope>`, que devolveu `template/.forge/f7.txt` no mesmo estado. Conferi também que ele não sofre do falso positivo de `mtime` que motivava o estágio 2 — depois de `touch` sem mudança de conteúdo devolve vazio —, então `[3]` segue verde. O cenário `[13]` (staged) e a mutação M11 entram para que a troca não possa ser desfeita em silêncio.

**B2 — a base de custo não reproduz. PROCEDE, e a decisão deixou de repousar em custo.** Remedi os seis primitivos, três execuções cada, sob `load averages` entre 19,4 e 31,1 (a suíte roda em outro processo e a invariante 9 me proíbe de pará-la). `git status --porcelain -u=all -- template/`: **0,28 / 0,04 / 0,05s**, não 0,79-1,61s. `git ls-files --others --exclude-standard`: **0,05 / 0,05 / 0,04s**, não 0,13-0,91s. `git diff-files --name-only`: **0,03 / 0,05 / 0,04s**. A tabela completa está em §2.2, com o comando de cada linha. A dispersão entre execuções do mesmo comando é maior que a diferença entre comandos, então **custo não discrimina** e a escolha passou a ser por correção. Duas decisões mudaram por causa dessa remedição: D9 (o primitivo) e **D10**, que deixou de adiar a varredura de não rastreados para o fim da suíte — a 0,05s ela roda por gate e passa a nomear o gate culpado. A remedição em bancada ociosa entra na definição de pronto, como passo 2.

**B3 — [9] e P3 eram vermelho fabricado. PROCEDE, e a propriedade foi trocada, não reescrita.** Medi eu mesmo, com o roteiro publicado em §1.7: 5 seções `## ` antes e 5 depois, `## 5.` presente, prefixo e sufixo do documento **byte-idênticos** (2.445 bytes fora do slot intactos), e só `LINHA-DEPOIS-DO-LITERAL` desaparecida. O documento não trunca; a perda é inteiramente dentro do corpo. A P3 antiga passava contra o código defeituoso e saiu do conjunto. Entrou P2 enunciada sobre o **slot** ("para todo corpo, inclusive os que contêm os literais, o miolo entre o primeiro `:START` e o último `:END` é o corpo verbatim"), **medida vermelha hoje**, e P3 nova sobre fechamento do ciclo. A mensagem de `[9]` foi reescrita para nomear a perda do corpo, com os números da medição. E entrou uma decisão de desenho que não existia — D16, `lastIndexOf(END)` — porque uma propriedade vermelha sem correção declarada não é especificação, é observação.

**B4 — a retrocompatibilidade repousava em `machinery.lock`. PROCEDE em parte, e refuto a parte medida com o comando que a refuta.** O lock **existe**: `find ~/Documents/projects -maxdepth 3 -name machinery.lock` devolve zero porque o caminho tem quatro níveis; `find ... -maxdepth 5` devolve dez, e os 8 consumidores com `.forge/` completo têm `.forge/cache/machinery.lock` com 285 a 404 entradas, todas incluindo os quatro arquivos do gerador. A referência ao lock em §1.9 fica, agora medida. O que **procede** é a acusação central: a frase "é código stock, sem patch local" era importada e é falsa — remedi por sha256 contra o template **e contra o lock de cada consumidor**, e `scripts/handoff-gen.sh` diverge dos dois em `axis-go-cloud` (bloco `forge:path-anchoring`, `mtime` local de hoje 11:08) e em `Axis.PadSimulator` (guarda `command -v node`, `mtime` local de hoje 11:17). Refuto, porém, a leitura de que `templates/handoff/HANDOFF.md` esteja "patcheado em 5 de 8": em 4 desses 5 o arquivo local **bate com o próprio lock** — é template velho, não customização —, e só `lionclaw` diverge do lock. E refuto a palavra "silêncio": `bin/forge.mjs:628-629` empilha esses caminhos em `driftWarned` e `:642-643` imprime `WARN: drift local em <path> sobrescrito pelo template`, com backup prévio em `.git/forge-backups/forge-N` (`:594-608`). §1.10 foi reescrita inteira sobre essas medições, e produz três providências concretas: absorver o patch do `Axis.PadSimulator` upstream como D18 com rc `3`; declarar que o do `axis-go-cloud` **não** é absorvido, por ser LDG-0171/Onda F, com a consequência escrita; e abrir item de ledger para absorvê-lo e avisar o consumidor pelo liaison antes da release.

**B5 — [5]/[6] podiam destruir o handoff real, e [5] passava verde sem execução. PROCEDE inteiramente, e virou correção de produto.** Confirmei os dois fatos com fixtures próprias, isoladas em `$TMPDIR`, com o `cwd` sempre dentro delas: com `FORGE_ROOT` apontando para `a` e `cwd` em `b`, quem foi reescrito foi `b` (73 → 2.650 bytes, `a` intacto, `rc=0`); e com o gerador ausente o hook sai `0` sem executar nada, deixando o arquivo intacto. Três mudanças: §1.1 abre com o aviso de que **toda** reprodução roda com `cwd` dentro da fixture, e o idioma antigo foi removido do texto; `[5]`, `[6]` e o novo `[12]` executam o hook com `cd` para dentro da fixture, em letra; e `[13]` novo compara o sha256 de `.forge/HANDOFF.md` do repositório real no início e no fim do gate, porque D15 impede a sentinela do item 2 de ver esse arquivo. O verde vácuo foi fechado por D19: recusa e inconclusivo passam a deixar recibo endereçado por conteúdo fora da árvore, e `[5]` exige o recibo com o sha do arquivo intacto — sinal positivo de execução que sobrevive ao `/dev/null`. E a causa raiz virou D17: o hook passa a honrar `FORGE_ROOT`, alinhado ao contrato que `handoff-gen.sh:7` já publica, com mutação M9 provando que só `[12]` cai quando se desfaz.

**B6 — a DoD exigia 434 depois de a onda acrescentar um arquivo. PROCEDE.** Medi: `git ls-files template/ | wc -l` → **434** hoje; D8 acrescenta `check-tree-integrity.sh`, rastreado sob `template/`, logo **435** no dia da entrega. O literal saiu da definição de pronto e da §2.6: o denominador da sentinela é capturado no baseline no início da suíte, a asserção é "maior que zero e igual ao do baseline", e a linha da DoD passou a ser uma conferência de delta. A revisão 3 foi além e tirou também o `435`, que era o mesmo defeito com o valor atualizado: a DoD mede `DEPOIS - ANTES = 1` e não grava total nenhum — ver §6, resposta a N4.

**B7 — a varredura de §2.1 não reproduz e sub-cobre. PROCEDE, e a decisão que ela sustentava foi revertida.** Refiz a varredura, mais ampla que a minha e que a do revisor, publicando o comando de cada número: invocação direta **10 sítios em 8 arquivos** (eu havia escrito 9 em 7); atribuição a variável **48 sítios cobrindo 33 scripts**; e o superconjunto de toda referência a script real do template, **119 sítios em 62 arquivos alcançando 53 scripts distintos**, entre eles `template/.forge/scripts/tests/run-all.sh` em `tests/w153-upgrade-safety-gate.sh:97`, que é o arquivo exato do LDG-0175. **Retiro a afirmação "zero sítios de escrita"** — ela não está estabelecida, e a lista de "quatro scripts alvo" era arbitrária. Auditei os 7 sítios de execução direta sem raiz fixada e nenhum escreve nesta árvore hoje (`w112:154` roda `validate-rules.sh` sobre a árvore real e é somente leitura; `w153:101` e `mermaid-drawio-gate.sh:75` estão fixados por `--path`/`--out`), mas isso é auditoria de 7, não prova sobre 119. Por isso **a metade (i) volta**, contra o que a revisão 1 decidiu: (i-a) é o nulo do `w146`/`w144` com comando publicado e registrado em teste pelo `[9]`; (i-b) é o varredor estático da forma literal, com cenário `[15]` próprio, corpus plantado para o vermelho e corpus real para a regressão, e mutação M13. Não há abandono a justificar, e portanto não há aval de orquestrador a pedir.

**B8 — [7] falharia contra um engine correto por estado de fixture indefinido. PROCEDE.** O estado ficou em letra na tabela de §1.5: o destino de `[7]` **tem** o par de marcadores e tem texto adicional depois do `:END`, para que o conteúdo mude e D2 dispare; sem marcadores, D1 recusaria antes de qualquer escrita e a asserção de backup seria falsa para sempre. A coluna "Estado exato da fixture" foi acrescentada à tabela inteira pelo mesmo motivo — `[1]`, `[3]`, `[5]`, `[6]`, `[11]` e `[12]` também tinham estado implícito.

**Ressalvas do veredito, todas tratadas.**

- *Controle da mutação vindo do HEAD.* Procede, e é grave pelo motivo que o revisor deu: como as mutações rodam depois da implementação, um `ORIG` do HEAD apagaria o trabalho não commitado e o `cmp -s` confirmaria a restauração. §1.6 agora manda `cp "$ALVO" "$ORIG"` da árvore de trabalho, com o parágrafo que explica por quê.
- *`--baseline` e `--snapshot` sem leitor.* `--snapshot` saiu da assinatura. `--baseline` ganhou semântica declarada (D9/D10), leitor em toda invocação, escrita por `--baseline-write` e cenário próprio (`[14]`), mais a mutação M12. Entrou `--label`, com leitor e com os cenários `[6]`/`[7]` exigindo o nome do gate na mensagem.
- *O gate do item 1 não tinha terceiro estado.* Procede. Entrou D18 (`node` ausente → `rc=3`, token `INCONCLUSIVO`, arquivo intacto), cenário `[11]`, mutação M10, e a tabela de rc de `[8]` passou a `0/1/2/3/4`.
- *`--gates-dir` exige reestruturar o parser.* Procede, e virou nota mecânica obrigatória em D14, com a grafia única (`--gates-dir <dir>`), a recusa explícita de `--gates-dir=<dir>` com `exit 2` fixada no cenário de contrato `[10]`, e o alerta de que a resolução para caminho absoluto precisa acontecer antes do `cd "$WS"` de `run-all.sh:14`.
- *§1.6 muta arquivo rastreado sob `template/` e não fazia a admissão de §2.4.* Procede. O parágrafo foi repetido em §1.6, com o mesmo fecho, para que o implementador trate os dois gates com a mesma disciplina.
- *O fallback de `TMPDIR` acumula backups.* Procede. D3 ganhou política de expurgo: o próprio gerador poda arquivos com mais de 14 dias **apenas** no diretório de fallback, nunca no de `<git-common-dir>`.
- *O crédito.* Registrado, e ele não é simetria de cortesia: a medição do falso-verde do índice, a do custo e a dos patches locais dos consumidores derrubaram três decisões desta spec, e as três estavam erradas.

---

## 6. Respostas ao veredito da revisão 2

Um item por bloqueador novo. Remedi cada afirmação do revisor com comando próprio antes de aceitá-la; onde ele errou o comando está aqui e a posição fica de pé. Os oito bloqueadores da revisão 1 seguem resolvidos e a §5 continua valendo palavra por palavra — nenhuma correção desta revisão os reabre.

Antes dos quatro itens, o resultado das quatro varreduras que a revisão 3 fez sobre a própria spec, porque três dos quatro bloqueadores novos e dois defeitos que o revisor não viu nasceram exatamente ali.

**Varredura 1 — todo número literal em asserção ou definição de pronto.** Sobreviveram **dois**, e os dois são a exceção legítima: `13/13` do gate 1 e `17/17` do gate 2, denominadores da lista de cenários que o próprio arquivo declara, fechados por construção, cuja divergência é o achado. Saíram: o `132` do varredor de `[15]`, que virou denominador derivado com asserção `> 0` (N4); o `435` da definição de pronto, que virou a conferência de delta `DEPOIS - ANTES = 1`; o `133 chamadas` / `131 gates` da extrapolação de custo de D9, que viraram `ls tests/*-gate.sh | wc -l` no momento da execução mais a propriedade "menos de 5% do tempo total"; o `1 gate de 132` de D13, que virou a propriedade "exatamente um arquivo de `tests/` traz sentinela própria"; e o `115 dos 132` de D7, marcado como medição datada da qual a decisão usa a proporção, não o par. Permaneceram como **medições datadas**, com o comando publicado e fora de qualquer asserção: `434` rastreados sob `template/`, `w207` de ordinal máximo, as contagens de `machinery.lock`, os `37` sítios de LDG-0171, os tamanhos das fixtures de §1.1 e §1.2 e os tempos de D9. E o `15 de 15` do gate 2 virou `17 de 17` na mesma passada — um denominador que não acompanha os cenários é o próprio defeito que o contador existe para pegar.

**Varredura 2 — toda string que a onda muda em saída de produção.** Nenhuma string existente muda; o que há são acréscimos. A tabela nominal com o `grep` de cada uma está em §2.6, e ela produziu um achado que não estava no veredito: a grafia de D11 (`— N arquivo(s) rastreado(s) comparado(s) (template/)`) **não é** a que a `lib/gate-universe.sh` emite (`— <count> <item> examinado(s) (<scope>)`), e um cenário de contrato escrito sobre a grafia inventada reprovaria a implementação canônica. D11 passou a usar a lib e a afirmar o que ela produz. Da mesma varredura saíram os cinco gates rastreados que a onda toca de raspão e que entram na definição de pronto — `w80`, `w146`, `w60`, `w101` e `w144` —, com a restrição nominal de que a reestruturação do parser de `run-all.sh` não pode mexer no bloco `GIT_CONFIG_*` que `w80[7]` conta nem mudar o formato do `--list` de que `w80[3]` e `w146[7]` dependem.

**Varredura 3 — toda linha da matriz de mutação, rodada em bancada.** Rodei em `$TMPDIR`, com a maquinaria real copiada, as quatro que o código de hoje permite rodar: M1, M8, M9 e M11. **Duas estavam erradas.** M9 era no-op com a fixture que a spec declarava (N1) e M11 declarava efeito errado (N2); as duas linhas foram corrigidas para o que eu medi, com a saída colada em §1.6 e §2.4. M8 e M1 reproduziram o efeito declarado, e M8 ganhou uma âncora precisa porque um `s/lastIndexOf/indexOf/g` global mutaria também a detecção do par que D1 usa. As nove restantes (M2-M7, M10, M12-M15) mutam código que ainda não existe e passaram a trazer a coluna `A MEDIR`, com a regra em letra: quando o efeito medido no passo 6 divergir da linha, quem se corrige é a linha. É a lição na forma mais crua — matriz de mutação escrita por dedução mente, e o `cmp` da restauração não vê.

**Varredura 4 — toda enumeração de desfechos, procurando o caso não coberto.** D11 enumerava cinco e faltavam **dois**: repositório git sem nenhum commit (N3) e o vazio com isenção declarada, que a lib já implementa e que a spec documentava sem cenário. D11 passou a sete desfechos, com ordem de avaliação fixada. A tabela de rc de `[8]` foi reexaminada e está fechada, com uma consequência declarada: a guarda de D18 verifica **presença** de `node`, não versão, e um `node` presente mas velho demais para o código do render sai `1` pelo galho de erro, não `3`. E a enumeração implícita de D3 ("há repositório git" contra "não há") escondia um terceiro caso que virou defeito: a resolução do `--git-common-dir` pelo `cwd` em vez de por `$ROOT`, medida e fechada.

### N1 — o cenário `[12]` era vermelho permanente e M9 era no-op. PROCEDE, e é a mais grave das quatro.

Remedi antes de aceitar, e a medição do revisor reproduz inteira. Montei duas fixtures git sob `$TMPDIR` com a maquinaria real copiada, apliquei D1 e D16 no `handoff-render.mjs` e D17 no `on-session-end.sh`, e rodei o hook com o `cwd` dentro de `b` e `FORGE_ROOT` apontando para `a`, nos dois estados de fixture. Sem o par de marcadores: `a mudou? NAO | b mudou? NAO` **com D17 e sob M9** — a mutação não altera nada observável. Com o par: `a mudou? SIM | b mudou? NAO` com D17 e `a mudou? NAO | b mudou? SIM` sob M9. Recontrole com D17 restaurado por `cp` e `cmp -s`: `a mudou? SIM | b mudou? NAO`.

A causa é a que o revisor nomeia: a coluna de estado de `[12]` dizia "duas fixtures git, cada uma com handoff próprio de 73 bytes", e um handoff de 73 bytes escrito à mão não tem os marcadores, logo D1 recusa com `exit 4` e o handoff de `a` nunca é regenerado. É a mesma classe do B8, que a revisão 2 declarou ter fechado para a tabela inteira, reaparecendo no cenário que a própria revisão 2 criou — e é o padrão de LDG-0164 e de `feedback-mutacao-fantasma-restore`, com o agravante de que aqui nem o `cmp` reclamaria, porque a mutação de fato muda o arquivo.

O que mudou: a coluna de estado de `[12]` passa a exigir em letra o **par de marcadores nas duas fixtures**, com corpo de delta próprio e distinto para que a regeneração de fato mude o conteúdo; a asserção foi reescrita como "`sha256` de `a/.forge/HANDOFF.md` **muda** e `b/.forge/HANDOFF.md` fica **byte-idêntico** (`cmp -s` contra a cópia de `t0`)"; a matriz de quatro células e o recontrole entraram em §1.5, abaixo da tabela; e a linha de M9 em §1.6 passou a `MEDIDO` com a ressalva "só morde com a fixture de `[12]` corrigida".

### N2 — M11 derruba `[3]` também. PROCEDE, e a correção fortalece a mutação.

Remedi, e a primeira medição me deu o contrário do que o revisor afirma — o que virou o achado mais útil desta rodada. Na fixture, depois de `touch template/.forge/f7.txt` sem mudança de conteúdo, `git diff-files --name-only -- template/` devolveu **vazio**, não o caminho. Investiguei em vez de refutar, e a explicação é de ordem: `git diff HEAD` **refresca o índice em disco** e limpa o estado *stat-dirty* do `touch`; eu havia rodado o primitivo de D9 antes do de M11, e o refresh apagou o sinal. Isolando, `git diff-files --name-only` executado como primeiro comando git depois do `touch` devolve `template/.forge/f7.txt` em todas as variações que testei — `touch` imediato, `touch -t` futuro, `touch -t` antigo, reescrita com mesmo conteúdo e `chmod`. O revisor está certo, e aceito.

O que mudou: a linha de M11 em §2.4 passou a "**`FAIL [3]` e `FAIL [13]`**; `[2]` e `[6]` continuam verdes", com estado `MEDIDO` e as três medições coladas. E entrou uma exigência que nem eu nem o revisor tínhamos: em `[3]`, a invocação da sentinela precisa ser o **primeiro comando git depois do `touch`**, sem nenhum outro comando git intercalado, inclusive nenhum `git status` de depuração — sem isso M11 é no-op em `[3]` e a linha volta a mentir por um caminho que nenhum `cmp` detecta. Como o revisor observa, a correção fortalece a mutação: M11 passa a provar que o primitivo é ao mesmo tempo content-based e ancorado no HEAD, e que nenhum dos dois sozinho basta.

### N3 — repositório git sem commit não casa com desfecho nenhum de D11. PROCEDE.

Remedi. Num `git init` sem commit, `git diff --name-status -z HEAD -- template/` sai `128` com `fatal: bad revision 'HEAD'`, enquanto `git status --porcelain -uno -- template/` responde `rc=0` com `A  template/.forge/x.txt` e `git ls-files -- template/` conta 1 — o galho `sem-git` não dispara porque o diretório **é** repositório git, e a guarda de universo vazio não dispara porque há um rastreado. Confirmo as duas implementações ruins que o revisor descreve, e acrescento o caso que ele não mediu: **sem** o `git add`, `git ls-files` devolve `0` e a guarda de universo vazio dispararia com o motivo **errado**, dizendo "não há arquivo rastreado no escopo" quando a causa é "não há HEAD contra o que comparar" — um `FAIL` com diagnóstico falso é quase tão caro quanto um falso-verde, porque manda o implementador procurar no lugar errado.

O que mudou: D11 foi reescrita e passou de cinco desfechos a **sete**, com a ordem de avaliação fixada em letra (`sem-git` → `sem-head` → universo com isenção → divergência → não rastreado, primeira condição que casa decide). O galho novo é `INCONCLUSIVO tree-integrity/sem-head`, com `rc 2` e token distinto do `sem-git`, e ganhou cenário dedicado `[16]`, como `[5]` tem para o `sem-git`, mais a mutação M14, que captura o `128` com `|| true` e tem de derrubar `[16]` sozinha. Na mesma passada entrou o sétimo desfecho, que era ressalva do revisor e não bloqueador: o `OK tree-integrity/universo-vazio … justificativa declarada`, com cenário `[17]` exercitando os dois lados do que a `forge_universe_waiver` decide. O gate 2 foi de 15 para 17 cenários e o contador de controle foi junto.

### N4 — o literal do varredor de `[15]` envelhece no dia da entrega. PROCEDE.

Remedi: `ls tests/*.sh | wc -l` → **132** hoje, esta onda acrescenta dois arquivos a `tests/`, logo o número correto na entrega é **134**, e 135 na primeira onda seguinte que criar um gate. É o mesmo mecanismo do `434 → 435` pelo qual o B6 reprovou a revisão 1, num cenário criado pela revisão 2 — e o revisor tem razão em dizer que §2.6 disciplinou o denominador da sentinela sem uma palavra sobre o do varredor.

O que mudou: o `132` saiu do corpo do cenário `[15]`; o denominador do varredor é derivado no momento da execução, com asserção `> 0` mais a propriedade "zero violação no corpus real e exatamente a violação plantada no corpus de fixture"; §2.6 ganhou um terceiro contador declarado, o do varredor, ao lado do do gate e do da sentinela; e §2.1 abre dizendo que todos os seus números são medições datadas, publicadas com o comando para serem refeitas.

### Ressalvas do veredito, todas tratadas

- *`--baseline-write` fora da assinatura publicada e do cenário de contrato.* Procede, e é a classe de `--snapshot` invertida — um leitor sem interruptor publicado. Entrou na assinatura de D8 com semântica declarada (escreve o baseline a partir do estado atual, exige `--baseline`, não emite veredito, é erro de uso invocá-lo sem `--baseline` ou junto de um veredito) e no cenário `[10]`.
- *O preâmbulo de §1.5 afirmava falsamente que todo cenário falha por ausência real, e faltava a coluna que a tabela do gate 2 tem.* Procede nos dois pontos. O preâmbulo passou a dizer que `[10]` e `[13]` nascem verdes por construção, contam no `DECLARADOS=13` e não têm vermelho a observar no passo 3; a tabela ganhou a coluna "Por que falha por ausência real", preenchida linha a linha com o sítio de código que falta; e entrou um parágrafo dizendo que os números da coluna de mensagens são valores medidos para o implementador reconhecer o vermelho, e nunca literais no fonte do gate.
- *`find ~/Documents/projects -maxdepth 5 -name machinery.lock | wc -l` devolve 20, não 10.* Procede — remedi e deu **20**. Corrigi o número e acrescentei de onde vêm os vinte: onze sob `.forge.bak-N`, dois de repositórios aninhados (`axis-go-cloud/axis-device-platform`, `secret-weapon/Axis.SecretWeapon`) e quatro de um diretório de backup avulso. Nenhum é consumidor ativo, e o número muda a cada `forge update` de qualquer um dos oito, porque cada update cria um `.forge.bak-N` novo — o que o torna, ele também, um número que não pode entrar em asserção. A propriedade que a spec afirma continua sendo "os 8 consumidores com `.forge/` completo têm lock", e as oito linhas de contagem por consumidor reproduzem exatamente, como o próprio revisor confirma.
- *O terceiro estado da allowlist não tinha cenário.* Procede, e virou `[17]` — ver N3.
- *Um gate que commitasse sob `template/` continua invisível a `git diff HEAD`.* Procede como fato e deixou de estar fora do desenho. Medi as três formas: adicionar e commitar é pego pelo contador de universo (1 → 2 rastreados); commitar por cima de uma divergência que já existia em `t0` é pego pela lista de divergentes (a divergência **some**); e alterar um rastreado limpo e commitar, sem adicionar nem remover, é invisível aos dois — rastreados e divergentes ficam byte a byte idênticos enquanto o disco fica com `corrompido`. O baseline passa a gravar uma quarta entrada, o **sha do HEAD**, com mensagem própria (`FAIL tree-integrity/head-mudou`), porque "o gate commitou" é diagnóstico diferente de "o gate sujou"; custa `git rev-parse HEAD`, medido em 0,04 / 0,02 / 0,03s; e a mutação M15 existe para provar que sem essa entrada o caso escapa.

### Um defeito que a revisão 3 achou por conta própria, e que nenhum dos dois vereditos viu

D3 mandava o backup para `<git-common-dir>/forge-backups/handoff/` sem dizer **como** o `git-common-dir` é resolvido, e a resolução ingênua é pelo `cwd`. Medi o custo: com o `cwd` na árvore do `forge-harness` e `$ROOT` num diretório avulso de `$TMPDIR`, `git rev-parse --path-format=absolute --git-common-dir` sem `-C` devolve `/Users/milton/Documents/projects/forge-harness/.git`, enquanto `git -C "$ROOT" rev-parse …` devolve `fatal: not a git repository`. E o arranjo não é hipotético: `tests/w60-handoff-gen-gate.sh:14,33` roda o gerador com `FORGE_ROOT` num `mktemp -d /tmp/forge-handoff.XXXXXX` e o `cwd` na árvore real, de modo que um backup resolvido pelo `cwd` escreveria dentro do `.git` **deste** repositório a cada execução da suíte. Seria a mesma classe do defeito que D17 conserta, entrando pela porta do remédio, e numa onda cujo nome é "perda de dado silenciosa" isso é o pior lugar possível para um descuido. D3 passou a exigir `git -C "$ROOT"` explícito, o galho de fallback passou a ser "`$ROOT` não é repositório git" e nunca "o `cwd` não é", e `[7]` ganhou a asserção sobre `<repo-real>/.git/forge-backups/` — escrita como delta vazio entre antes e depois, e não como ausência absoluta, correção que veio na mesma rodada e está registrada nas ressalvas de §7.

---

## 7. Respostas ao veredito da revisão 3

Um item por bloqueador. Remedi cada afirmação do revisor com comando próprio antes de aceitá-la; onde ele errou, o comando que o refuta está aqui e a posição fica de pé. Os bloqueadores das revisões 1 e 2 seguem resolvidos, e §5 e §6 continuam valendo palavra por palavra — nenhuma correção desta revisão os reabre.

Antes dos itens, a varredura que esta revisão fez sobre si mesma, porque ela é o assunto da rodada.

### A varredura de comandos prescritos — invariante 19

A regra nova separa duas coisas que esta spec vinha misturando: **medição**, que é comando que eu rodei e cuja saída está colada, e **prescrição**, que é comando que o implementador vai rodar. Medição envelhece e é datada; prescrição, se nunca foi executada, é palpite com aparência de rigor — e a revisão 3 mostrou três palpites meus e de specs vizinhas custando um bloqueador cada.

Inventariei o documento inteiro: **44 blocos cercados e 132 comandos em linha**, dos quais **31 são prescrições** — comando que a spec manda o implementador rodar, dentro de um cenário, de uma mutação ou de uma decisão de desenho. O resto é medição datada, com o comando publicado para ser refeito, e continua onde estava.

Das 31 prescrições:

- **19 reexecutei nesta revisão** e a saída está colada no corpo, ou já estava e reproduziu. São as de `git diff --name-status -z HEAD` contra `git diff-files` (§2.2 e a nota de `[3]`), as três grafias de `--gates-dir` (D14), a resolução do `--git-common-dir` com e sem `-C` (D3), os três galhos de `rc` do gerador (`[8]`), a guarda de `node` de D18, a indexação de `process.argv` do roteiro de §1.7, `forge_universe_check` conferida contra a assinatura real da lib, e as contagens da varredura de §2.1.
- **8 converti para propriedade mais contrafactual**, porque nunca as executei ou porque a execução mostrou que o primitivo não discrimina: o `touch` de `[3]`, o `mtime` de `[4]`, o primitivo de M11, o de M3, a derivação do `--path` da sentinela em D14, a comparação de caminho de fixture, o desfecho de `--baseline` ausente em D8, e a mecânica de restauração de §1.6, que passou a declarar as três propriedades antes de mostrar o idioma.
- **4 permanecem prescritas sem execução minha, e digo quais e por quê**: `cmp -s` para igualdade byte a byte, `shasum -a 256` para endereçamento por conteúdo, `bash -n` para sintaxe e `git ls-files -- <scope> | wc -l` para o contador de universo. São primitivos cujo contrato é o próprio nome, sem estado de fixture que os torne não discriminantes, e três deles já são idioma corrente da suíte. Registro-os aqui em vez de fingir que a varredura fechou em zero.

O saldo é que a spec **encurtou** nos lugares em que prescrevia e **cresceu** nos lugares em que precisava provar. Três medições novas entraram por causa da regra, e nenhuma delas era dedutível: o racy-clean de `[3]`, a intermitência de nove em doze do `%m` de `[4]`, e a divergência entre `/var` e `/private/var` que quebra comparação de caminho de fixture por string.

### Remanescente 1 — N2 fechado na direção errada. PROCEDE, com duas refutações dentro.

Remedi na sequência que o gate de fato constrói, três fixtures novas, git 2.50.1, e o revisor está certo: `git diff-files --name-only -- template/` devolveu **vazio em 3 de 3**, pela regra racy-clean. A medição está colada na nota de `[3]` em §2.3. Com o `touch` ingênuo, `[3]` passa com o primitivo certo e com o errado — é gate morto — e M11 é no-op nele, o que faz da linha de M11 uma dedução pela terceira rodada seguida. Aceito inteiro.

**Refuto duas das quatro saídas que o veredito propõe, e as duas com medição.** A reescrita com o mesmo conteúdo **não** produz o estado stat-dirty de forma confiável: devolveu vazio em 3 de 3 naquela bancada, pelo mesmo racy-clean que o `touch`. (Retificação da revisão 5, com a medição na nota de `[3]` em §2.3: o correto é dizer **intermitente** — em seis fixtures novas ela reportou em 2 —, e a conclusão não muda, porque um estado intermitente é pior que um estado nulo.) E o `chmod` produz divergência para o primitivo **certo** também — `git diff --name-only HEAD` reporta o caminho, porque o modo faz parte da entrada de árvore —, de modo que `[3]` com `chmod` ficaria vermelho contra a implementação correta, que é vermelho fabricado. Sobrevivem `touch -t` com data distante e `touch` com folga real de `mtime`, e é sobre esses dois que a nota de `[3]` fala.

O que mudou, e aqui a invariante 19 muda a forma da correção: a spec **não** fixa o comando da fixture. Ela declara a propriedade (o rastreado está stat-dirty com conteúdo intacto) e o contrafactual (`rc = 0` com D9, reprovação sob M11), e impõe ao implementador duas obrigações verificáveis — provar o estado stat-dirty com o primitivo stat-based antes de rodar a asserção, e provar que M11 morde. As duas medições vão para o PR. A regra de ordem da revisão 3 continua valendo e ganhou o par que faltava: estado **e** ordem, nenhum suficiente sozinho. A linha de M11 permanece `FAIL [3]` e `FAIL [13]`, agora com a ressalva de no-op escrita nela.

### Novo 1 — `FORGE_SUITE_ROOT` sem semântica, sem leitor e sem cenário. PROCEDE inteiramente.

O revisor está certo nos dois lados, e o segundo é o que importa. `tests/run-all.sh:13-14` resolve `WS` pelo próprio `BASH_SOURCE` e faz `cd "$WS"` sem override nenhum — conferi lendo o arquivo —, então sem uma resposta para "que repositório a sentinela julga", os cenários `[6]`, `[7]` e `[8]`, que são o centro da onda, ficam vermelhos contra a implementação correta ou fazem um gate julgar a árvore de trabalho de quem rodou a suíte. E publicar a variável em três lugares sem dizer o que ela faz é a classe de `--snapshot` que eu mesmo removi de D8 nesta mesma família de decisões, reintroduzida no runner.

A correção é a mais radical das quatro: **a variável sai da spec inteira**, e o problema que ela existia para resolver passa a ser resolvido por derivação. `--gates-dir` é o único botão, e a sentinela julga o repositório git que **contém o diretório de gates em execução** — `$WS` na invocação normal, a fixture quando a flag é passada, e `INCONCLUSIVO sem-git` quando esse diretório não está em repositório git. Um botão a menos, uma precedência a menos para documentar, e a semântica passa a ser derivável em vez de declarada. Montei a cabeça do runner em bancada e medi as três grafias, com a saída colada em D14, o que fechou de quebra duas ressalvas do veredito: qual das duas formas de resolver o caminho relativo (capturar o `PWD` antes do `cd`, e o motivo é não reordenar o cabeçalho que `w80[7]` conta) e o que `--gates-dir` faz com as suítes `bats` (suprime, e a supressão é condicionada à flag justamente para ficar invisível a `w80` e `w146`).

Essa bancada devolveu um achado que não estava em veredito nenhum e que vale para os dois gates: em `$TMPDIR` no macOS, `git rev-parse --show-toplevel` devolve `/private/var/…` enquanto `mktemp -d` devolveu `/var/…`, e a comparação por string entre os dois **falha** enquanto `-ef` acerta. Toda asserção que confronte o caminho de uma fixture com um caminho que o `git` devolveu passa a ser por identidade de arquivo, e a medição está em §1.5.

### Novo 2 — a tabela de rc de `[8]` contradiz o gerador de hoje. PROCEDE.

Remedi os três galhos contra `template/.forge/scripts/handoff-gen.sh`, em fixture git sob `$TMPDIR` com o `cwd` dentro dela:

```
--- (a) nenhum change ativo, sem id
rc=1 saida=FAIL (nenhum change ativo em …/.forge/specs/active)
--- (b) id inexistente
rc=1 saida=FAIL (change inexistente: nao-existe)
--- (c) dois changes ativos, sem id
rc=2 saida=FAIL (múltiplos changes ativos — informe <change-id>)
```

"Ausente" é `1` e só "ambíguo" é `2`. O cabeçalho do script (`handoff-gen.sh:9` — "Exit 1 on error, 2 on ambiguous/no id") já é impreciso e a spec o herdou sem medir, exatamente o defeito que esta rodada existe para eliminar. Como §0 declara que o contrato é apenas **ampliado**, um cenário de contrato escrito sobre a tabela errada nasceria vermelho contra a implementação correta e inalterada, ou empurraria o implementador a mudar um `rc` de maquinaria distribuída em silêncio.

O que mudou: a tabela de `[8]` passou a `0` sucesso; `1` erro, inclusive change ausente e change inexistente; `2` change ambíguo; `3` inconclusivo; `4` recusa. E sobre o cabeçalho do script: **ele é corrigido junto**, na mesma onda, porque é comentário no arquivo que esta onda já reescreve e porque deixá-lo mentindo ao lado de um cenário que afirma o contrário é convite a uma rodada futura "consertar" o cenário pelo comentário. Conferi que nenhum gate afirma a string — `grep -rn 'ambiguous/no id' tests/` não devolve nada —, então a correção não deixa gate vermelho e não entra na lista de §2.6.

### Novo 3 — `[4]` não pode falhar e M3 é no-op, pela mesma classe de `[3]`. PROCEDE, e é pior do que o veredito diz.

Remedi, e a medição vai além da do revisor. Rodei doze pares de escrita separados por 18 ms: `stat -f %m` colidiu em **9 de 12**, e `stat -f %Fm` distinguiu em **12 de 12**. A saída completa está na nota de `[4]` em §1.5. A leitura que o veredito não faz é a que mais assusta: `[4]` com o primitivo óbvio não seria um gate morto, seria um gate **intermitente** — verde em cerca de três quartos das execuções e vermelho no resto —, e quem rodar uma vez conclui que funciona. Um sinal que discrimina por sorte é pior que um que não discrimina nunca, porque produz evidência de cobertura que não existe.

O que mudou, em três frentes. A asserção de `[4]` deixou de nomear `mtime` e passou a declarar a propriedade ("a segunda execução não escreve o destino e não cria backup novo"), com três obrigações para o implementador: resolução abaixo de um segundo ou sinal não temporal; discriminação provada por **repetição**, N de N com N ≥ 10, porque uma execução única não distingue correto de sortudo; e portabilidade entre `stat` do BSD e do GNU, senão o gate passa aqui e morre no CI. A linha de M3 passou a exigir o mesmo N de N. E a regra de §1.6 — "quando o efeito medido divergir da linha, quem se corrige é a linha" — ganhou a exceção que o revisor pede, escrita de forma a não deixar margem: **quando a mutação sai no-op, quem se corrige é o cenário, não a linha**, porque um no-op nunca é evidência sobre a implementação, é evidência sobre o teste.

### Ressalvas do veredito, todas tratadas

- *Sexta coluna espúria na tabela de §2.3.* Procede — eram dez linhas com justificativas do gate 1 penduradas nos cenários do gate 2. Removidas.
- *A coluna "Estado exato da fixture" de §1.5 omite o change ativo em `[1]`, `[5]`, `[6]` e `[11]`.* Procede, e medi o custo: sem `manifest.yaml` o gerador sai `1` com "nenhum change ativo" antes de chegar à recusa, ao backup ou à guarda de `node` — é a mesma medição que fecha o Novo 2. As quatro células passaram a dizê-lo, mais `[7]`, que tinha a mesma omissão e que o veredito não listou.
- *D14 manda resolver `--gates-dir` "antes desse `cd`" e o parser está depois dele.* Procede. Escolhi capturar o `PWD` original numa variável antes da linha 14, e digo por quê: mover o bloco de parsing reordena o cabeçalho, que contém o `GIT_CONFIG_*` cuja contagem `w80[7]` afirma. Medido em bancada, com a saída em D14.
- *`--gates-dir` e as suítes `bats`.* Procede. Suprime, e a supressão é parte da semântica da flag e está no cenário `[10]`.
- *`--baseline` inexistente, e o consumidor sem baseline.* Procede, e virou desfecho em vez de frase: `INCONCLUSIVO tree-integrity/sem-baseline`, oitavo galho de D11, com `rc 2`, cenário `[18]` e mutação M16. Sem baseline a sentinela emite o contador de universo e não emite veredito de divergência — do contrário reprovaria todo trabalho legítimo não commitado, que é o que D10 existe para evitar. O gate 2 foi de 17 para 18 cenários e o contador de controle foi junto.
- *A colisão de `rc 1` com o idioma do harness para argumento inválido.* Procede, e ganhou a frase que faltava em D8: a colisão foi resolvida a favor do desfecho e não do idioma, porque quem lê o `rc` da sentinela é o `run-all.sh`, que precisa separar "não verifiquei" de "reprovei" e não precisa separar "você me chamou errado" de "achei divergência".
- *A asserção de `[7]` como ausência absoluta.* Procede. Conferi que `<repo-real>/.git/forge-backups/` não existe hoje, e que ele é propriedade de `forge update`, logo pode existir na bancada de quem rodar a suíte. Reescrita como delta: o conjunto de antes é igual ao de depois.
- *§2.3 sem o preâmbulo que §1.5 ganhou.* Procede. O preâmbulo entrou, nomeando `[11]` e `[12]` como verdes por construção e `[15]` como o caso de corpus plantado.
- *A linha da sentinela "no modo `-v`" sem nada na fiação que a condicione.* Procede. Virou regra de desenho em D12: o `run_one` captura a saída da sentinela e a ecoa sempre que ela não conclui limpo, e no verde só sob `-v`. A definição de pronto foi corrigida junto, com a conferência derivada em vez de literal.
- *O crédito.* O revisor da revisão 3 fechou um gate morto, um gate intermitente, um interruptor sem leitor e uma tabela de contrato herdada de um comentário errado. Os quatro eram meus, os quatro passaram por duas revisões anteriores sem serem vistos, e três deles são a mesma doença: escrever comando sem rodar.

### Varredura da invariante 14, última passada

Percorri de novo todo literal que conta alguma coisa da árvore. Sobrevivem **dois**, e os dois são a exceção que a própria invariante declara: `13/13` do gate 1 e `18/18` do gate 2 (na revisão 5 este virou `19/19` com a entrada de `[19]` — ver §8), denominadores da lista de cenários que cada gate declara, fechados por construção e cuja divergência é o achado. O `17/17` da revisão 3 virou `18/18` na mesma passada em que `[18]` entrou — um denominador que não acompanha os cenários é o próprio defeito que o contador existe para pegar.

Tudo o mais que conta árvore permanece como **medição datada**, com o comando publicado e fora de qualquer asserção, e remedi cada um hoje, em `c41eead`: `git ls-files template/ | wc -l` → 434; `ls tests/*.sh | wc -l` → 132; `ls tests/*-gate.sh | wc -l` → 131; `grep -rn 'SCRIPT_DIR/\.\./\.\.' template/.forge/scripts/ | wc -l` → 37; a varredura de §2.1 → 119 sítios em 62 arquivos; a propriedade de D13 → exatamente **um** arquivo de `tests/` com sentinela própria. Um número da revisão 3 **não** reproduziu, e a correção está em D10 e em §3: `git status --porcelain -- template/` devolve vazio hoje, porque a Fase 0 foi commitada em `c41eead`, enquanto a revisão 3 registrava dois arquivos modificados. É o argumento da invariante 14 acontecendo com a própria spec entre duas rodadas de revisão, e o que estava apoiado naquele número passou a ser apoiado na propriedade que não vence: a árvore **pode** estar legitimamente suja no instante em que alguém roda a suíte.


---

## 8. Respostas ao veredito da revisão 4

Um item por bloqueador. Remedi cada afirmação do revisor com comando próprio antes de aceitá-la, em bancada sob `$TMPDIR` e com o `cwd` sempre dentro da fixture; nenhum gate da suíte foi executado. Os bloqueadores das revisões 1, 2 e 3 seguem resolvidos — o veredito da revisão 4 os conferiu um a um com medição própria e nenhum reincidiu —, e §5, §6 e §7 continuam valendo palavra por palavra. **Os três bloqueadores desta rodada procedem inteiramente, e não há refutação a fazer:** os três são defeitos meus, e dois deles são a mesma doença que esta spec vem perseguindo desde a revisão 3 — uma peça declarada num lugar e não propagada para os outros.

### Novo 1 — a fixture do PATH de `[11]` produz vermelho fabricado e mutação no-op. PROCEDE.

Remedi as três montagens contra o gerador de hoje, e a saída está colada na nota de `[11]` em §1.5. Com um diretório que só tem `bash`, o gerador morre em `handoff-gen.sh:12` com `dirname: command not found` e sai `1` com `FAIL (template ausente: …)`, porque sem `dirname` o `SCRIPT_DIR` colapsa para o `cwd` e o `TPL` derivado não existe. A asserção `rc = 3` de `[11]` ficaria vermelha contra a implementação **correta**, e M10 seria no-op — com e sem a guarda o `rc` é `1`. Com `PATH=/usr/bin:/bin` o `rc` é `127` na invocação de `node`, que é a saída que eu mesmo colei em §1.6, prova de que a minha medição foi feita com um `PATH` diferente do que a spec mandava montar. A célula de estado virou propriedade — `node` ausente e presente todo utilitário externo invocado antes da guarda —, com o piso medido hoje (`bash`, `dirname`, `find`, `wc`, `tr`, `basename`; mais `awk` quando a fixture tem `.forge/FORGE.md`) declarado como piso e não como lista fechada, por duas razões que medi: a lista depende do estado da fixture e depende de onde a guarda for posta. E entrou a obrigação que faltava, na forma que `[3]` e `[4]` já usam: antes da asserção, o implementador prova que o vermelho de hoje é `rc=127` na invocação de `node`, e não `rc` de passo anterior. D18 e a linha de M10 foram corrigidas junto, e o bloco de bancada de §1.6 ganhou a retratação em letra.

### Novo 2 — `head-mudou` era o nono galho sem enumeração, sem contrato e sem cenário. PROCEDE.

O revisor está certo em cada uma das cinco constatações, e conferi todas por leitura da própria spec: o desfecho não estava na enumeração de D11, que se declarava exaustiva em oito; não estava na ordem de avaliação; não estava no vocabulário literal que `[10]` afirma; não tinha cenário entre `[1]`-`[18]`; e M15 mandava observar um `FAIL` num cenário inexistente. Pela regra que esta spec escreveu três vezes, um galho sem cenário é indistinguível de um galho que não existe.

Das duas saídas que o veredito oferece, escolhi a primeira — o cenário entra — e a escolha é medida, não de gosto. Remedi o galho em fixture nova, com um gate falso que altera um rastreado limpo e commita, e os três primeiros sinais do baseline ficam byte a byte idênticos aos de `t0` enquanto o disco está corrompido; só o sha do HEAD muda. A saída está em D11. Tirar a quarta entrada do baseline, que é a outra saída, devolveria esse caso ao invisível, e ele é o único que os outros três sinais não pegam.

O que mudou, e é a varredura inteira em vez de um remendo: D11 passou de oito para **nove** desfechos; a ordem de avaliação ganhou `head-mudou` entre `sem-baseline` e divergência, com o motivo medido (quando o HEAD se moveu, os outros dois sinais foram calculados contra outra base e descreveriam o defeito errado); o vocabulário literal ganhou a linha do `FAIL`; `[10]` passou de sete a oito tokens; entrou o cenário `[19]`, de canal real; o `rc` do galho ficou declarado como `1`, com os três galhos de `rc 2` inalterados; M15 passou a apontar para `[19]`; o denominador do gate 2 foi de `18/18` para `19/19` no contador de §2.6, na definição de pronto e no passo 4 de §4; §2.7 pôs `[19]` entre os de integração; e D10 passou a nomear o cenário.

### Novo 3 — a saída não temporal de `[4]` é no-op medida, e a outra alternativa não existe no caminho `rc=0`. PROCEDE.

Remedi as duas. `writeFileSync` com bytes idênticos preserva inode, tamanho e sha256 — só o `ctime` muda, e em granularidade de segundo, portanto na mesma loteria que derrubou o `%m` —, de modo que um `[4]` escrito sobre "inode mais tamanho mais checksum" é gate morto e M3 é mutação no-op. A saída está na nota de `[4]` em §1.5. E "o próprio recibo do gerador" não é opção porque D19 só escreve recibo em `rc 3` e `rc 4`, e `[4]` é o caminho `rc 0`, onde `handoff-gen.sh:63` imprime a mesma linha `OK <path>` escrevendo ou não — conferi lendo D19 e o script. Que a nota que existe para eliminar sinal não discriminante oferecesse dois sinais não discriminantes é o pior lugar possível para esse defeito, e o revisor tem razão em chamá-lo assim.

Das duas correções que o veredito oferece, escolhi a primeira — endurecer a obrigação — e declaro por que não escolhi a segunda: fixar em D4 um sinal positivo de "não escrevi" no caminho feliz acrescentaria superfície de saída a uma fronteira publicada, reabrindo a tabela de rc de `[8]` e a varredura de strings de §2.6 para comprar o que a obrigação compra de graça. A frase que dispensava obrigações saiu. No lugar dela: nenhum sinal dispensa nenhuma obrigação; qualquer candidato, temporal ou não, tem de ser provado discriminante sob M3 em N de N com N ≥ 10, com controle **e** recontrole — muda quando o gerador escreve, não muda quando ele não escreve, na mesma fixture; as obrigações 1 e 3 caem só para um sinal genuinamente não temporal, e um sinal que dependa de `ctime` não é. E, para que a exigência não feche um caminho vazio, medi uma prova de existência e a marquei como prova de existência, não como prescrição: o `mtime` em milissegundos lido pelo mesmo `node` que o gerador já exige distinguiu 12 de 12 pares escritos a 18 ms, enquanto a granularidade de segundo colidiu em 11 de 12.

### Ressalvas do veredito, todas tratadas

- *A conferência da linha da sentinela não fecha contra a implementação correta.* Procede, e conferi as duas razões no fonte: `run_one` (`tests/run-all.sh:71-84`) ecoa o log inteiro de cada item sob `-v`, e é o mesmo laço das duas suítes `bats` (`:97-99`), de modo que uma chamada "fora do condicional" roda também depois delas. O comando saiu da definição de pronto e virou propriedade: a sentinela é invocada uma vez por item executado pelo `run_one` e emite uma linha de universo por invocação. D12 ganhou a consequência em letra, que é deliberada — uma suíte `bats` não tem mais licença para sujar `template/` do que um gate.
- *As duas grafias da asserção de `[7]`.* Procede. A formulação de delta agora está nos três lugares; o parágrafo normativo de §1.5 e a resposta de §6 deixaram de dizer "nenhum arquivo apareça".
- *Contradição de letra entre a obrigação 1 de `[3]` e a regra de ordem 2 de §2.4.* Procede, e remedi a base antes de aceitar: `git diff-files` não refresca o índice — duas chamadas seguidas sobre um arquivo em `touch -t 209001010101` reportaram o caminho nas duas, em 3 de 3 fixtures, e o sinal só sumiu depois de um `git diff HEAD`. A regra 2 passou a proibir o que de fato mata o sinal (comando git que **refresque o índice**), com a prova de estado como exceção explícita e medida, e a nota de `[3]` aponta para ela.
- *`[7]` pode passar por contaminação entre execuções.* Procede, e é mais grave do que ressalva: com nome endereçado por conteúdo, expurgo de 14 dias e corpus fixo, um backup da execução de ontem satisfaz a asserção **mesmo sob M2**. `[7]` passou a exigir âncora que não sobreviva à execução anterior — o caminho impresso em stderr naquela invocação, ou `TMPDIR` dentro da fixture, ou nonce por execução —, e a linha de M2 foi corrigida junto: ela derruba `[2]`, `[3]`, `[6]` **e `[7]`**, que é o conjunto de cenários que afirmam backup e que a matriz declarava incompleto desde a revisão 2.
- *A reescrita de mesmo conteúdo é intermitente, não "nunca reporta".* Procede, e a medição do revisor está certa contra a minha: em seis fixtures novas o `diff-files` devolveu vazio em 4 e reportou o caminho em 2. Corrigi a nota de `[3]` e a resposta de §7. A conclusão não muda — ela não serve de estado de fixture —, mas o motivo correto é loteria de racy-clean, e loteria é pior que sinal nulo, porque produz o gate intermitente que a nota de `[4]` descreve. Na mesma passada remedi o `touch` ingênuo em 10 fixtures novas (vazio em 10 de 10 na minha bancada, contra 1 de 5 reportando na do revisor: as duas dizem que o estado não é determinístico) e o `touch -t 209001010101` (stat-dirty com `diff-HEAD` vazio em 10 de 10).

### A conferência final, linha a linha

A revisão 4 diagnosticou o padrão que derrubou três rodadas — a correção de um bloqueador cria o seguinte, porque muda uma peça sem varrer o resto do documento. Fiz a varredura antes de fechar, e registro o resultado de cada linha.

1. **Toda seção que menciona a peça mudada foi atualizada?** Grepei as quatro peças e li cada ocorrência. `head-mudou`: 2 linhas antes desta rodada (D10 e a resposta de §6), 10 fora desta seção agora, e as novas são D11 (enumeração, ordem de avaliação, vocabulário literal, `rc`), `[10]`, `[19]`, o contador de §2.6 e o parágrafo de `rc 2`; M15 passou a citar `[19]`. `[11]`/PATH: corrigi a célula da tabela, a nota nova, D18 e a linha de M10, mais a retratação no bloco de bancada de §1.6. `[4]`/sinal: a obrigação 3 e o parágrafo que a seguia. `[7]`: as três grafias mais a linha de M2. Duas peças foram atualizadas **por efeito colateral encontrado nesta varredura e não pedido pelo veredito**: a linha de M2, que não listava `[7]`, e o parágrafo de `rc 2` de D11, que enumerava o `rc 1` sem `head-mudou`.
2. **Todo contador declarado continua batendo?** Recomputei cada um. Gate 1: `DECLARADOS=13`, "onze dos treze falham por ausência real" (`[10]` e `[13]` verdes por construção) — intocado, nenhum cenário entrou nele. Gate 2: `DECLARADOS=19` no preâmbulo de §2.3, `19 de 19` no contador de §2.6, `19/19` na definição de pronto, `[1]`-`[19]` no passo 4, e "dos dezenove, dezessete falham por ausência real" — `[11]` e `[12]` são os dois verdes por construção, `[19]` falha por ausência real, e 19 − 2 = 17. Desfechos de D11: nove, e o vocabulário literal tem nove linhas. Tokens de `[10]`: oito. Entradas do baseline: quatro, e a medição de D11 mostra três idênticos e um mudado. Mutações: dezesseis, M1-M16, e o passo 6 continua dizendo dezesseis. Os denominadores históricos de §6 (`17/17`) e §7 (`18/18`) ficam como registro da rodada que os produziu, e o de §7 ganhou o ponteiro para cá.
3. **Toda enumeração exaustiva continua exaustiva?** As quatro que se declaram assim. D11 (desfechos) foi de oito para nove, com ordem de avaliação e vocabulário juntos. A tabela de `rc` da sentinela: `2` para os três inconclusivos, `1` para divergência, não rastreado, `head-mudou` e erro de uso, `0` para limpo — o parágrafo que enumerava o `1` foi corrigido. A tabela de rc de `[8]` (gate 1): intocada, `0/1/2/3/4`, porque nada nesta rodada mexeu no gerador. Os cenários de gate 2: `[1]`-`[19]`, contíguos, e o novo entrou na lista de níveis de §2.7.
4. **Toda matriz de mutação aponta para cenário que existe, com o efeito medido?** As dezesseis. M15 apontava para um cenário inexistente e passou a apontar para `[19]`. M2 apontava para três cenários e derrubava quatro. M10 continua em `[11]`, agora com a ressalva de que só morde com a fixture corrigida — mesma forma da ressalva que M9 e M11 já carregavam. As treze restantes não foram tocadas por esta rodada e seguem com o estado que tinham, `MEDIDO` ou `A MEDIR`.
5. **Todo literal que conta a árvore virou piso mais propriedade?** Sobrevivem os dois de sempre — `13/13` e `19/19` —, que são as listas de cenários que cada gate declara. O literal novo desta rodada é a lista de utilitários da fixture de `[11]`, e ele entrou **como piso mais propriedade** desde a primeira linha: a propriedade é "todo utilitário externo invocado antes da guarda", o piso medido é a lista de seis, e as duas razões de ele ser piso (estado da fixture e posição da guarda) estão medidas. Nada mais foi acrescentado; `434`, `132`, `131`, `37` e `w207` seguem como medição datada fora de asserção.

### O crédito

O revisor da revisão 4 fechou um desfecho que existia sem enumeração, sem contrato e sem cenário, uma fixture cuja montagem literal produzia vermelho contra a implementação correta, e uma nota que oferecia dois sinais no-op dentro do parágrafo que existe para eliminar sinal no-op. Os três são meus, e os três nasceram do mesmo gesto: declarar uma peça num lugar e não varrer o documento atrás do efeito. Ele também mediu por conta própria três coisas que ninguém tinha pedido — que o `touch` ingênuo é loteria e não morte certa, que `git diff-files` não refresca o índice, e que a contaminação do fallback de `TMPDIR` engana `[7]` sob M2 —, e as três viraram correção aqui.
