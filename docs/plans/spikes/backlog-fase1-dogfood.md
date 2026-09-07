# Fase 1 — completar o dogfood do harness neste repositório

Especificação da Fase 1 do plano `docs/plans/2026-09-07-backlog-zero.md`. Data: 2026-09-07, **revisão 4** (as revisões 1, 2 e 3 foram reprovadas; as respostas item a item estão nas seções 9, 10 e 11). Remedido na branch `fix/strix-achados-medios`, commit **`c41eead`** — a Fase 0 foi commitada entre a revisão 3 e esta, e HEAD saiu de `49bc97d`. `package.json` em `0.14.0`, suíte em 132 arquivos `tests/*.sh` (`ls tests/*.sh | wc -l` → `132`), `git ls-files` em **1168** (era 1167 na revisão 3) e `check-secrets` medindo **1163** arquivos versionados (era 1162). Os dois contadores subiram em vinte e quatro horas sem defeito nenhum, o que é a demonstração empírica da política de derivar todo contador no instante da execução.

Toda afirmação numérica abaixo vem de um comando executado durante a redação desta especificação, e o comando está citado ao lado do número. Nenhum gate da suíte foi executado: a suíte é serializada pelo orquestrador, e gate manual concorrente produz falha fantasma em gate alheio. Onde um número depende de tempo de execução, a carga sob a qual ele foi medido está registrada junto com ele (nesta rodada, `uptime` → `load averages: 24,91 24,32 24,50`, com nenhum `run-all.sh` em execução — conferido por `ps -Ao pid,etime,command | grep run-all.sh`, lista vazia).

### Método desta revisão — invariante 19, aplicada à especificação inteira

A revisão 3 foi reprovada por um padrão, não por dois acidentes: **a especificação prescrevia comando exato que ela nunca executou, e errava**. O plano-mestre transformou isso no invariante 19, e esta revisão o aplica a todo comando prescrito, não só aos dois bloqueadores.

A regra que passa a valer aqui: a especificação declara a **propriedade** que precisa valer e o **contrafactual** que a mutação tem de produzir; o implementador — que executa — escolhe o primitivo e **prova que ele discrimina**, com controle e recontrole. Prescrição de comando exato só permanece no documento quando veio de uma execução registrada, com a saída colada ao lado.

A varredura encontrou quatro prescrições mortas, todas no protocolo da §7, e **as quatro foram descobertas executando o comando prescrito numa bancada sob `$TMPDIR`, não relendo o texto**. Três delas eram falso-verde perfeito: o critério de aceite da fase inteira — a comparação gate a gate da suíte — aprovava uma suíte vermelha. Estão medidas na §7, cada uma com controle e contrafactual, e resumidas na §11.

## 1. O defeito, reproduzido

```
$ node bin/forge.mjs update --dry-run
FAIL (/Users/milton/Documents/projects/forge-harness/.forge existe mas forge.yaml não — instalação parcial, arquivo apagado, ou harness sem esse arquivo (ex.: dogfood). Não rode init (exigiria --force e sobrescreveria specs/baseline existentes) — restaure .forge/forge.yaml (do template ou do histórico do git) e rode update de novo)
RC=3
```

A recusa é literal e o código é 3. A causa está em `bin/forge.mjs:517` — `updateHarness()` recusa quando `.forge/` existe e `.forge/forge.yaml` não. O `.forge/` da raiz tem 344 arquivos (`find .forge -type f ! -name '.DS_Store' | wc -l` → `344`) e um symlink (`find .forge -type l | wc -l` → `1`), distribuídos assim: `liaison` 166, `specs` 160, `product` 7, `graph` 4, `ledger` 2, `cache` 1 (ignorado pelo git), mais os quatro arquivos soltos `FORGE.md`, `HANDOFF.md`, `empty-universe-allowlist.txt` e `secrets-allowlist.txt`. Não há `forge.yaml`, `rules/`, `scripts/`, `commands/`, `agents/`, `hooks/` nem `machinery.lock`.

O defeito é de ausência, não de lógica: a recusa está correta e é o comportamento desenhado. O que falta é a instalação.

### 1.1 A instalação, medida por execução real num CLONE INDEPENDENTE do repositório

A revisão 1 mediu num diretório copiado à mão, e isso foi suficiente para os sha256 mas não para os contadores de git — um diretório sem `.git` não tem `git ls-files`, e três dos números que esta fase precisa (`check-secrets`, corpus rastreado, o que o `.gitignore` engole) só existem dentro de um repositório. Esta revisão remede tudo num **clone independente**, que é também o veículo do passo 3 do protocolo (seção 7) e o único que passa o guard de worktree (seção 9, bloqueador 1).

```
$ SP=<scratchpad>
$ git clone --no-hardlinks "$WS" "$SP/clone" && git -C "$SP/clone" checkout fix/strix-achados-medios
$ git -C "$SP/clone" rev-parse --short HEAD                     # 49bc97d — mesmo commit da árvore real
$ cd "$SP/clone" && node ./bin/forge.mjs update --dry-run       # reproduz a recusa: rc 3, mensagem literal
$ rm -f .forge/contracts && cp -R template/.forge/contracts .forge/contracts
$ cp template/.forge/forge.yaml .forge/forge.yaml
$ node ./bin/forge.mjs update --no-plugin --no-backup           # RC=0, "✔ Forge atualizado ... (template v0.14.0)"
$ node ./bin/forge.mjs update --dry-run                         # RC=0, "0 mudança(s) de arquivo."
```

A instalação acrescenta **476 arquivos novos** na árvore, distribuídos assim (`git -C "$SP/clone" status --porcelain --untracked-files=all | grep '^??' | awk -F/ '{if(NF==1)print $1; else print $1"/"$2}' | sort | uniq -c | sort -rn`):

| destino | arquivos |
|---|---|
| `.forge/scripts` | 136 |
| `.forge/commands` | 57 |
| `.forge/rules` | 51 |
| `.forge/agents` | 48 |
| `.claude/agents` | 48 |
| `.forge/schemas` | 28 |
| `.forge/templates` | 21 |
| `.forge/skills` | 20 |
| `.claude/skills` | 20 |
| `.forge/hooks` | 13 |
| `.forge/capabilities` | 13 |
| `.forge/adapters` | 10 |
| `.forge/contracts` | 5 |
| `.forge/README.md`, `.forge/forge.yaml`, `.claude/settings.json`, `AGENTS.md`, `CLAUDE.md`, `.gitattributes` | 1 cada |

Mais um arquivo modificado (`.gitignore`, +30 linhas do bloco gerenciado) e um removido (`.forge/contracts`, o symlink que a decisão (e) substitui).

Desses 476, exatamente **1** é engolido pelo `.gitignore` — `.forge/cache/machinery.lock` (medido com `git check-ignore --stdin` sobre a lista completa, num repositório sintético cujo `.gitignore` é o da raiz concatenado com `installer/gitignore.patch`). Esse único arquivo ignorado é o assunto do bloqueador 4 e está tratado na decisão (g).

Os quatro arquivos de instrução ficaram byte a byte idênticos, com os sha256 registrados abaixo para uso como controle na implementação:

| arquivo | sha256 |
|---|---|
| `.forge/FORGE.md` | `b36a11d0ea144afb8300c95e67fbc04f2e0d3ef065ac6c93163e5f444998f11b` |
| `.forge/HANDOFF.md` | `d0e3b19cffca9756ca893979944d154b35ff98c6cc6005d5893993389043f118` |
| `.forge/empty-universe-allowlist.txt` | `6a8a99aaaf7bd00923820c37860c201c7701d8ce4bc1c0420dfa1d15bc5cf1c2` |
| `.forge/secrets-allowlist.txt` | `596c666ad3c4923312d35257a7e8c2d016ec919fdf5ae43bd32626c20be72c4d` |

### 1.2 A instalação é IDEMPOTENTE sobre a árvore rastreada — medido

Este é o fato que sustenta as decisões (g) e o critério de aceite, e ele não estava na revisão 1. Com os 476 arquivos commitados no clone, apaguei o lock e rodei o update de novo:

```
$ cd "$SP/clone" && rm -f .forge/cache/machinery.lock
$ node ./bin/forge.mjs update --no-plugin --no-backup   # RC=0
$ wc -l .forge/cache/machinery.lock                     # 403 (2 linhas de cabeçalho + 401 entradas)
$ git status --porcelain                                # VAZIO — a árvore não ficou suja
```

Um `forge update` sobre a instalação já rastreada é um no-op no que é versionado e escreve **só** o `machinery.lock`, que é o único arquivo ignorado. Na revisão 2 essa medição servia para tornar seguro um passo de CI que aplicava o update antes da suíte; a revisão 3 **removeu esse passo** (decisão (g), pelo bloqueador NOVO 2), e a medição passa a sustentar outra coisa: é a propriedade que a asserção [2] cobra sem escrever nada, por `update --dry-run`. Idempotência continua sendo o fato; deixou de ser a licença para um comando que muta a árvore antes de ela ser medida.

### 1.3 Um achado da medição: `<INSTALLED_AT>` fica órfão

Copiar `template/.forge/forge.yaml` para a raiz deixa o placeholder cru:

```
$ grep -n 'template_version\|installed_at' "$SP/clone/.forge/forge.yaml"
4:  installed_at: "<INSTALLED_AT>"
5:  template_version: "0.14.0"
```

Quem preenche esse token é o `init` (`bin/forge.mjs:809`, `[/<INSTALLED_AT>/g, 'installed']`) e o `installer/install.sh:69`; o `update` não o conhece e o próprio código diz por quê (`bin/forge.mjs:445`). A varredura de placeholders do doctor procura só `<PROJECT_[A-Z_]*>` (`doctor.sh:119`), então esse órfão passa despercebido, e o schema o aceita porque o campo é `string` livre. O protocolo da seção 7 passa a substituí-lo explicitamente, e a asserção [1] passa a cobrá-lo. É achado desta especificação e entra no ledger com esta medição.

### 1.4 O que o update cria FORA de `.forge/`

- `.claude/` com 69 arquivos — `settings.json`, 48 agents e 20 skills. Este repositório hoje tem um `.claude/` **vazio de arquivos**: `find .claude -mindepth 1` devolve só `.claude/worktrees`, um diretório sem conteúdo, criado pela ferramenta e invisível para o git (que não versiona diretório vazio). Nenhum arquivo do harness o menciona (`grep -rn '\.claude/worktrees' template bin tests installer` → nada).
- `AGENTS.md` (2.197 bytes) e `CLAUDE.md` como symlink para ele. Hoje nenhum dos dois existe.
- `.gitattributes` novo (1.495 bytes), que carrega o `merge=union` do store do liaison.
- Bloco gerenciado acrescentado ao `.gitignore` existente (32 linhas hoje, `grep -c . .gitignore` → 26 não vazias; o bloco acrescenta 30 linhas).

O `.claude/settings.json` gerado declara exatamente um hook:

```json
{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/enforce-worktree-location.sh"}]}]}}
```

Isso é aditivo em relação aos hooks globais do usuário (settings de projeto e de usuário se compõem no Claude Code), mas passa a interceptar todo `Bash` desta sessão e das próximas — e a rodada atual trabalha em worktrees. É risco operacional real, tratado na seção 6.

## 2. O risco central, medido: quais gates mudam de contador

A pergunta do plano é qual gate passa a ver duas cópias da maquinaria. São **três**, e a revisão 1 achou dois por um comando de censo que não reproduzia.

### 2.1 O censo, com um comando que reproduz

O grep da revisão 1 (`grep -ln -- '--path "\$WS"\|FORGE_ROOT="\$WS"\|--root "\$WS"' tests/*.sh`) devolve **2** arquivos, não os 7 que ela nomeou. O censo correto é feito em dois passos, e os dois reproduzem:

```
# 1. quais check-*.sh do produto têm a RAIZ como alvo default
$ for f in template/.forge/scripts/check-*.sh; do grep -qE 'TARGET="\$ROOT"|targets=\("\$ROOT"\)|ROOT="\$\{FORGE_ROOT' "$f" && echo "$f"; done
template/.forge/scripts/check-ai-attribution.sh
template/.forge/scripts/check-authz.sh
template/.forge/scripts/check-data-governance.sh
template/.forge/scripts/check-heavy-mutex.sh
template/.forge/scripts/check-heredoc-hash.sh
template/.forge/scripts/check-observability.sh
template/.forge/scripts/check-push-ahead.sh
template/.forge/scripts/check-red-first.sh
template/.forge/scripts/check-secrets.sh
template/.forge/scripts/check-shell-pipeline.sh
template/.forge/scripts/check-suite-wiring.sh

# 2. quais desses a suíte aponta para o REPOSITÓRIO INTEIRO
$ grep -nE 'check-[a-z-]+\.sh"? (--path|--root|path)? ?"\$WS"|--path "\$WS"|--root "\$WS"|run_gate path "\$WS"|run_check "\$WS"' tests/*.sh
tests/w139-secrets-gate.sh:359:run_gate path "$WS"
tests/w146-suite-invocation-gate.sh:118:run_check "$WS"
tests/w151-heavy-mutex-gate.sh:1338:out46b="$(FORGE_ROOT="$WS" bash "$WS/template/.forge/scripts/check-heavy-mutex.sh" --path "$WS" 2>&1)"; rc46b=$?
```

Três gates, três asserções. Os oito `check-*.sh` restantes da lista do passo 1 têm alvo default de raiz mas nenhum ponto de entrada da suíte os aponta para `$WS` — o `ci.yml` passa `--path template --path tests` no lint (linha 68) e os demais rodam sobre fixture.

### 2.2 Os três contadores, medidos antes e depois

Todos medidos com o mesmo script de produção que o CI roda, o "antes" na árvore real e o "depois" no clone com a instalação já commitada:

| gate | asserção | hoje | depois | comando |
|---|---|---|---|---|
| `w139-secrets-gate.sh` | `[15]` | `nenhum segredo em 1162 arquivo(s) versionado(s)` | `1637` | `FORGE_ROOT="$PWD" bash template/.forge/scripts/check-secrets.sh path "$PWD"` |
| `w146-suite-invocation-gate.sh` | `[6]` | `1 runner(s) fiado(s) em 3 ponto(s) de entrada` | `2 runner(s)` / `7 ponto(s)` | `FORGE_ROOT="$PWD" bash template/.forge/scripts/check-suite-wiring.sh --root "$PWD"` |
| `w151-heavy-mutex-gate.sh` | `[46b]` | `heavy-mutex/universo — 230 arquivo(s)` | `320` | `FORGE_ROOT="$PWD" bash template/.forge/scripts/check-heavy-mutex.sh --path "$PWD"` |

**`w139[15]`.** `check-secrets.sh` opera sobre `git ls-files` (cabeçalho do script, linha 11). O 1637 não é estimativa: é o número que o script imprimiu no clone depois de `git add -A` e commit dos 476 arquivos, e ele depende da decisão (a) — com só `.forge/` rastreado o número medido é `1565`, com `.claude/` + `AGENTS.md` + `CLAUDE.md` + `.gitattributes` também rastreados é `1637`. O veredito não muda — os arquivos instalados são cópia byte a byte de arquivos que já passam —, mas o número muda e o baseline gate a gate precisa registrar isso como divergência esperada e justificada. Um dos 476 fica de fora da varredura por conter byte nulo (`.forge/scripts/lib/secret-scan.mjs`, que carrega o próprio caractere que usa para detectar binário), e o `machinery.lock` fica de fora por ser ignorado — daí 1637 e não 1639.

Há um segundo efeito no mesmo gate, e este é de premissa: o comentário das linhas 361-363 afirma que *"este repositório não declara `secrets:` no .forge/forge.yaml, então herda o default `warn`"*. Depois da Fase 1 o `forge.yaml` existe e declara `enforce: block` (`template/.forge/forge.yaml:107`). A asserção continua correta, porque ela cobra zero achado e não o modo; o comentário passa a mentir. É a mesma classe do achado 1 da Fase 0 — documentação que o assert não cobre — e a fase corrige o comentário.

**`w146[6]`.** `check-suite-wiring.sh` declara `SUITE_DIRS="tests .forge/scripts/tests"` (linha 47) e conta pontos de entrada em `.github/workflows/*.yml`, `.forge/hooks/git/*`, `.forge/FORGE.md` e `package.json` (linhas 68-76). Hoje a raiz tem 1 workflow, nenhum hook em `.forge/hooks/git/` e os dois arquivos restantes. Depois da instalação são 7 pontos de entrada (entram os 4 hooks do template) e 2 runners, porque `.forge/scripts/tests/run-all.sh` passa a existir. O segundo runner precisa ser citado por algum ponto de entrada, senão o gate reprova: ele é citado em `template/.forge/hooks/git/pre-push:476` (`grep -rn 'scripts/tests/run-all.sh' template/.forge/hooks/`), e a citação chega junto com o hook instalado. Medido no clone instalado: `OK suite-wiring — .forge/scripts/tests/run-all.sh invocado em .forge/hooks/git/pre-push`.

**`w151[46b]`.** Este é o terceiro gate, que a revisão 1 declarou imune por engano. O cenário `[46b] o gate estático passa sobre o repositório INTEIRO` varre `--path "$WS"`, e o universo do `check-heavy-mutex.sh` são os `.sh` mais os quatro nomes de hook (`pre-push`, `pre-commit`, `post-merge`, `commit-msg`), excluindo `.git`, `node_modules` e `.forge/worktrees`. O `.forge` instalado acrescenta 88 desses (`machineryFiles(template/.forge)` filtrado por extensão e nome de hook) e o `.claude` instalado acrescenta 2 (`.claude/skills/dotnet-quality-scan/scripts/scan.sh` e `.claude/skills/node-quality-scan/scripts/scan.sh`), o que dá o 320 medido. **O veredito continua verde** porque as cópias `.forge/scripts/lib/heavy-mutex.sh`, `.forge/scripts/heavy-run.sh` e `.forge/scripts/check-heavy-mutex.sh` são isentas por caminho canônico (`check-heavy-mutex.sh:53-55`), e essa isenção foi escrita exatamente para a forma instalada — o gate já previa este dia.

### 2.3 O varredor mais exposto, e por que o CI o salva

`check-shell-pipeline.sh` é o único do harness cujo alvo default é o repositório inteiro sem contador de universo próprio: `ROOT="${FORGE_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"` na linha 25 e `[ "${#targets[@]}" -gt 0 ] || targets=("$ROOT")` na linha 40. Medido com o próprio coletor do lint, na árvore real e no clone instalado:

```
$ node <script que importa collectShellFiles de template/.forge/scripts/lib/shell-pipeline-lint.mjs>
raiz real          => 226
raiz + instalação  => 312     (medido no clone instalado, não somado à mão)
  .forge instalado =>  84
  .claude instalado =>  2
  template/        =>  84
  template/.forge/scripts => 73
  tests/           => 134
```

Uma varredura de raiz iria de 226 para **312** — e nem 299 (revisão 1) nem 310 (revisão da revisão): os dois erraram por somar à mão, e os 2 que faltam nos dois são os `scan.sh` das skills que o `.claude/` instala. **Não acontece**, e a razão está medida no `ci.yml`: o passo do lint invoca `check-shell-pipeline.sh --path template --path tests` (linha 68), com escopo explícito, e o passo do `check-secrets` usa `path "$PWD"` (coberto em 2.2). Nenhum ponto de entrada do repositório roda o lint sem `--path`.

Depois da instalação o `pre-push` passa a rodar os mesmos lints, mas **por diff** e não pela árvore — `template/.forge/hooks/git/pre-push:250-260` documenta que varrer o corpus inteiro bloquearia o push da própria entrega, porque `w145` e `w159` montam fixtures que contêm de propósito a forma proibida. O universo do lint no hook é o conjunto de `.sh` que aquele push publica, e não muda com a duplicação.

### 2.4 O resto da suíte

`grep -nE '(\$WS|\$ROOT|"\$PWD"|\$\(pwd\))/\.forge' tests/*.sh` devolve nove ocorrências, e todas apontam para **dado**, não para maquinaria: `.forge/ledger/ledger.json` (`w157:81`, `w157:163`, `w202:45`), `.forge/ledger/LEDGER.md` (`w202:46`), `.forge/specs/active` (`w20:105`, `w20:106`, `w20:127`), uma linha de fixture em `w151:1233` e um comentário em `w158:4`. Nenhuma varre `.forge/scripts`, `.forge/rules` ou `.forge/commands`.

Os quatro gates que a variante frouxa do grep encontra e que a revisão 1 não conferiu foram conferidos aqui, um a um: `w145:128,186` e `w159:147` passam `--path "$WS/template" --path "$WS/tests" --path "$WS/bin"`, `w193:81` passa `--path "$WS/tests"`, e `w20` toca só `.forge/specs`. Nenhum muda.

`w204-ordinal-root-resolution-gate.sh` foi medido em execução, não por leitura: `gate-ordinal.sh next` devolve `w208` na árvore real e `w208` no clone instalado, pelas duas cópias do script (`template/.forge/scripts/gate-ordinal.sh` e `.forge/scripts/gate-ordinal.sh`). O universo local é `TESTS_DIR` (`gate-ordinal.sh:72-87`), e `.forge/scripts/tests/` contém um único arquivo, `run-all.sh`, que não casa `w[0-9]*`.

`plugin-sync-gate.sh` não muda: todas as referências são a `template/.forge/commands` e `plugin/forge` (linhas 18-44). `npx-pack-gate.sh` não muda: o campo `files` do `package.json` é uma allowlist (`["bin/","template/","installer/gitignore.patch","installer/gitattributes.patch","installer/install.sh","installer/removed-files.txt","CHANGELOG.md"]`) e o `.forge/` da raiz não entra no pacote publicado.

**Conclusão medida:** três gates mudam de contador (`w139[15]`, `w146[6]` e `w151[46b]`), nenhum muda de veredito, e a suíte não tem varredura de raiz sem escopo. Isso não dispensa o passo 3 do protocolo — a suíte inteira roda no clone descartável e a comparação é gate a gate —, mas dá a previsão contra a qual comparar, e qualquer quarto gate que mude de número é achado.

## 3. Decisões fechadas

### (a) O que entra no git — `.forge/` instalado, `.claude/`, `AGENTS.md`, `CLAUDE.md` e `.gitattributes`, TODOS RASTREADOS

**Decisão: os 476 arquivos entram no git, exceto o único que o `.gitignore` engole (`machinery.lock`, decisão (g)).** A revisão 1 decidiu isso só para `.forge/` e deixou os adapters implícitos, o que tornava a previsão de `w139[15]` indeterminada — é o bloqueador 6, e ele estava certo.

A razão é normativa e está escrita no próprio produto. `template/.forge/rules/conventions/machinery-propagation.md` abre com: *"O harness vive dentro da árvore de trabalho: `.forge/scripts/`, `.forge/rules/`, `.forge/schemas/`, `.forge/templates/`, `.forge/hooks/`, `.forge/agents/` e o plugin são arquivos versionados como qualquer outro."* Toda a mecânica que depende disso é medível: o guard de worktree de `updateHarness()` (`bin/forge.mjs:531-537`) recusa aplicar maquinaria num worktree linkado justamente porque *"a maquinaria é versionada na árvore"*; o `doctor` reporta divergência de maquinaria por worktree; e o `machinery.lock` só é referência de drift se existir onde o gate roda.

A razão para estender a decisão aos adapters é **de campo, e foi medida nos três consumidores instalados**:

```
$ for r in axis-fare-validator axis-go-cloud/axis-device-platform azim-crm; do d="$HOME/Documents/projects/$r"; echo "$r: .claude=$(git -C "$d" ls-files .claude | wc -l) AGENTS.md=$(git -C "$d" ls-files AGENTS.md | wc -l) CLAUDE.md=$(git -C "$d" ls-files CLAUDE.md | wc -l) .gitattributes=$(git -C "$d" ls-files .gitattributes | wc -l)"; done
axis-fare-validator: .claude=292 AGENTS.md=1 CLAUDE.md=1 .gitattributes=1
axis-go-cloud/axis-device-platform: .claude=61 AGENTS.md=1 CLAUDE.md=1 .gitattributes=0
azim-crm: .claude=61 AGENTS.md=1 CLAUDE.md=1 .gitattributes=0
```

Os três rastreiam `.claude/`, `AGENTS.md` e `CLAUDE.md`. O `.gitattributes` só existe rastreado no consumidor que atualizou depois de o patch existir, e aqui ele **não é opcional**: ele carrega o `merge=union` do store do liaison, e o cabeçalho de `installer/gitattributes.patch` documenta que sem ele `--ours`/`--theirs` destroem mensagens publicadas em silêncio, com rc=0. Um `.gitattributes` não rastreado é um driver de merge que existe só na máquina de quem instalou — exatamente o modo de falha que a decisão inteira combate.

**Alternativa descartada: ignorar `.forge/` no git.** Ela é tentadora porque zera a duplicação no corpus rastreado. Foi descartada por três razões, e a segunda mudou desde a revisão 1 porque o revisor tinha razão sobre ela. Primeira: um clone novo em CI não teria `.forge/scripts/`, e `check-suite-wiring.sh --root "$PWD"`, que o `ci.yml` roda como passo próprio (linha 74), voltaria a ver 3 pontos de entrada em vez de 7 — a instalação existiria só na máquina de quem a fez, que é precisamente o modo de falha que `machinery-propagation.md` documenta como *"config de máquina: some num clone novo, some num runner de CI, some quando alguém troca de laptop"*. Segunda: o `machinery.lock` **não** distingue as duas alternativas, porque ele é ignorado nas duas (medido, decisão (g)) — o que distingue é a asserção [4], que compara `.forge/<rel>` com `template/.forge/<rel>` byte a byte e que **só existe se `.forge/` existir na árvore de quem roda o gate**. Terceira, e decisiva: o repositório que produz a norma seria o único lugar onde ela não vale.

O preço da decisão está medido, com um comando que não soma à mão — `git ls-tree -r -l <rev>` sobre os dois commits de instalação no clone:

```
$ for rev in HEAD~2 HEAD~1 HEAD; do printf '%s: ' "$rev"; git ls-tree -r -l "$rev" | awk '{n++; b+=$4} END {printf "%d arquivo(s), %d byte(s)\n", n, b}'; done
HEAD~2: 1167 arquivo(s), 10363316 byte(s)     # antes
HEAD~1: 1570 arquivo(s), 13224690 byte(s)     # só .forge/ (+403 arquivos, +2.861.374 bytes, +27,6%)
HEAD:   1642 arquivo(s), 14078628 byte(s)     # completo (+475 arquivos, +3.715.312 bytes, +35,9%)
```

Em linhas de diff, `git show --stat` dos dois commits: `406 files changed, 64338 insertions(+), 1 deletion(-)` e `72 files changed, 26372 insertions(+)` — 90.710 linhas ao todo. O +403 (e não +404) do primeiro commit é o symlink `contracts` removido em troca dos 5 arquivos reais da decisão (e).

O preço tem uma mitigação que a fase entrega junto, e ela não é opcional: com duas cópias no repositório, um agente que faça `grep` encontra dois sítios e pode editar o errado. A asserção [4] do gate novo exige identidade byte a byte entre `.forge/<rel>` e `template/.forge/<rel>` para todos os 401 paths de maquinaria, de modo que a cópia instalada nunca possa divergir do produto sem o gate morder.

### (b) `codegraph.include_paths`, `empty-universe-allowlist.txt` e `secrets-allowlist.txt` — NENHUM DOS TRÊS MUDA

**`codegraph.include_paths` fica `["template/.forge/**"]`, sem alteração.** Medido, compilando o glob com o próprio compilador do motor:

```
$ node --input-type=module -e 'import {compileLayerMap} from "./template/.forge/scripts/lib/graph-layers.mjs"; …'
globs: [ '/^template\/\.forge(?:\/.*)?$/' ]
template/.forge => true
.forge => false
.forge/scripts => false
```

`include_paths` é aditivo, não uma allowlist: `graph-build.mjs:119-125` usa `forcedInclude` só para vencer o default de pular nome com prefixo de ponto e `SKIP_DIRS`. O `.forge/` da raiz começa com ponto, não casa o glob declarado, e continua fora do walk.

E isso foi **verificado por execução, contra a árvore instalada**, não por leitura do artefato commitado:

```
$ node template/.forge/scripts/lib/graph-build.mjs "$SP/clone" --out "$SP/graph2"
OK .forge/graph/graph.json (310 nodes, 59 edges; 310 summaries stale)
   { bin: 1, installer: 1, template: 153, tests: 150, tools: 5 }   sob .forge/: 0
```

**Alternativa descartada: acrescentar `.forge/**` ao `include_paths`.** Duplicaria os nodes de `template/.forge/**` no grafo, tornaria toda consulta de `/forge:query` ambígua, e faria `/forge:impact` reportar impacto duplo em cada mudança de script. A prova de que essa é a consequência real, e não uma previsão, está na mutação de [9] (seção 5.1).

**`secrets-allowlist.txt` fica como está.** As duas entradas de hoje são `tests/w139-secrets-gate.sh` e `tests/w112-liaison-session-gate.sh`, e `tests/` não é maquinaria — não há cópia de nenhum dos dois sob `.forge/`. Os 476 arquivos instalados passam no gate sem allowlist nenhuma, e isso não é previsão: `check-secrets.sh path "$PWD"` no clone com tudo commitado devolve `OK secrets — nenhum segredo em 1637 arquivo(s) versionado(s)`. Acrescentar uma entrada "por precaução" seria abrir a porta exata que o cabeçalho do arquivo diz ser por onde um gate de segredo é esvaziado na prática.

**`empty-universe-allowlist.txt` fica como está, com uma entrada.** Hoje ela tem só `red-first-ci`. O leitor é `forge_universe_waiver()` em `lib/gate-universe.sh:31`, que resolve `${FORGE_EMPTY_UNIVERSE_ALLOWLIST:-$root/.forge/empty-universe-allowlist.txt}`. Antes da instalação, `$root` para um script executado de `template/.forge/scripts/` é `template/`, e o CI contorna isso passando `FORGE_ROOT="$PWD"` em cada invocação. Depois da instalação, um script executado de `.forge/scripts/` resolve `$root` para a raiz do repositório e lê a mesma allowlist que o CI já lê. A convergência é a favor, não contra.

### (c) O que impede o próximo `forge update` de sobrescrever `FORGE.md`, `HANDOFF.md` e as allowlists

**A resposta não é uma nova guarda: é a lista `MACHINERY_DIRS`, e ela já exclui os quatro arquivos.** `bin/forge.mjs:307` declara `MACHINERY_DIRS = ['agents','capabilities','commands','contracts','hooks','schemas','scripts','skills','templates','rules']`, e `machineryFiles()` (linhas 310-329) enumera exatamente esses dez diretórios, mais `adapters/*.yaml` que não sejam `*.lock.yaml`, mais `README.md`. `FORGE.md`, `HANDOFF.md`, `empty-universe-allowlist.txt` e `secrets-allowlist.txt` não estão em nenhum dos três conjuntos, e portanto o overlay nunca escreve neles.

A enumeração foi contada, não estimada:

```
$ node -e '<reimplementação literal de MACHINERY_DIRS + walk + adapters/*.yaml + README.md sobre template/.forge>'
total machineryFiles: 401
{ agents: 48, capabilities: 13, commands: 57, contracts: 5, hooks: 13, schemas: 28, scripts: 136, skills: 20, templates: 21, rules: 51, adapters: 8, 'README.md': 1 }
```

E confirmada pelo lado do produto, sem reimplementação nenhuma: o `machinery.lock` gerado pelo update real tem 403 linhas, das quais 2 são cabeçalho (`wc -l .forge/cache/machinery.lock` no clone instalado). **401 é o piso literal da asserção [4]** (decisão do bloqueador 7).

A distinção com a issue #101 precisa ser dita em letra. #101 mede que `scripts` está em `MACHINERY_DIRS` e fora de `ENRICHABLE_DIRS` (`bin/forge.mjs:352`), de modo que `forge update` **sobrescreve `.forge/scripts/` inteiro**. Isso continua verdadeiro depois da Fase 1, e é **desejável aqui**: a cópia instalada deve ser sempre a do template. O que #101 chama de perda silenciosa é a perda de um *fix local* em `scripts/` de um consumidor; neste repositório, um fix local em `.forge/scripts/` seria o defeito, não o trabalho.

**Consequência que o cabeçalho do gate novo precisa declarar, sob pena de o próximo leitor "consertar" o gate:** a asserção [4], por exigir identidade byte a byte em TODA a maquinaria, torna `ENRICHABLE_DIRS` (`agents`, `rules`, `skills`, `templates`) **inutilizável neste repositório**. Isso é deliberado e contradiz, só aqui, o contrato que o update publica para os consumidores — lá a customização local em `rules/` e `agents/` é legítima e o lock existe para preservá-la; aqui ela é drift, porque a fonte mora na mesma árvore. A frase tem de estar no cabeçalho do gate, com esta razão.

**O que a Fase 1 precisa mudar por causa disso: nada no código, e uma linha na documentação.** O `.forge/FORGE.md` da raiz declara hoje que *"este repositório não é (ainda) um consumidor completo de si mesmo"*, e essa frase deixa de ser verdade. Ela é substituída por uma que diga o contrato novo: `.forge/` é instalação, `template/.forge/` é fonte, edição de maquinaria acontece na fonte e chega aqui por `forge update`, e o gate `w<N>` reprova se as duas divergirem.

**Um segundo destruidor existe e NÃO é o update: `/forge:handoff`.** A issue #120 mede que `lib/handoff-render.mjs:70` reescreve `.forge/HANDOFF.md` incondicionalmente, com 290.761 bytes virando 2.764, sem backup e com `exit 0`. Depois da Fase 1 este repositório passa a ter `.forge/scripts/lib/handoff-render.mjs` instalado, e o `HANDOFF.md` da raiz — 8.320 bytes hoje (`ls -la .forge/`) — vira alvo. Isso é **Onda A**, não Fase 1. O que a Fase 1 faz é registrar a dependência: enquanto a Onda A não fecha, `/forge:handoff` não é executado neste repositório, e o `HANDOFF.md` entra no inventário sha256 do passo 1 para que a destruição, se ocorrer, seja detectável.

### (d) O gate novo: `w<N>-dogfood-install-integrity-gate.sh`

Especificado por inteiro na seção 5. O ordinal medido no momento da redação é **w208** (`FORGE_ROOT="$PWD" bash template/.forge/scripts/gate-ordinal.sh next` → `w208`, *"derivado do tronco remoto 'origin/develop' (máximo remoto w207) e da árvore local (máximo local w207)"*), mas por força do invariante 10 do plano **o ordinal é alocado pelo orquestrador no momento de escrever o arquivo**, conferido contra `origin/*` e contra as branches em voo desta rodada. `LDG-0173` mede que `gate-ordinal.sh next` só lê `origin/develop`, `origin/main` e `origin/master`.

### (e) O symlink `.forge/contracts` vira diretório real

Medido: `.forge/contracts -> ../template/.forge/contracts` (`ls -la .forge/`), e o alvo tem 5 arquivos. `contracts` está em `MACHINERY_DIRS`, então o overlay escreve `join(forge, 'contracts', …)` — que, através do symlink, resolve **dentro do produto**. Hoje o conteúdo é idêntico e a escrita é inócua; um `forge update --source` de outra versão mutaria `template/.forge/contracts/` como efeito colateral de uma instalação.

**Decisão: substituir o symlink por um diretório real com os 5 arquivos, antes de instalar.** É a única forma de a instalação não ter o produto como destino de escrita. A identidade dos 5 arquivos com a fonte fica coberta pela asserção [4].

**Alternativa descartada: manter o symlink e excluir `contracts` de `MACHINERY_DIRS`.** Mudaria o comportamento do `update` para todos os consumidores instalados, para acomodar uma conveniência de um único repositório. O símbolo é local; a lista é contrato.

### (f) `runtime.gates` no `FORGE.md` da raiz: declarado, com os quatro gates órfãos nomeados

O update aplicado fez o doctor imprimir, medido:

```
! harness: gates: 14 check-*.sh examinado(s), 4 gate(s) órfão(s) — nenhum hook os invoca e runtime.gates não os declara: check-authz check-data-governance check-observability check-suite-wiring
· harness: runtime.gates vazio em todas as fases — nenhum gate declarado (informativo; não reprova, LDG-0013)
```

O `FORGE.md` da raiz não tem bloco `runtime:` nenhum (o arquivo inteiro cabe em 17 linhas e só carrega `codegraph:`). Depois da instalação, o `pre-push` passa a executar o caminho de `runtime.gates` — e este repositório cai exatamente no cenário da issue #119.

**Decisão: o `FORGE.md` da raiz declara `runtime.gates` na forma CSV escalar, com `check-suite-wiring` e `check-secrets`, e NÃO declara `runtime.test` — e a onda entrega junto o alias `--path` em `check-suite-wiring.sh`, sem o qual metade da declaração bloqueia todo push.**

#### O bloqueador NOVO 1 da revisão 3, remedido e aceito, com a escolha em letra

A revisão 3 mediu o **leitor** (`forge_runtime_gates_phase source` devolve os dois gates) e nunca mediu a **invocação**. Remedi antes de aceitar, e o revisor está inteiramente certo. `template/.forge/hooks/git/pre-push:450` executa todo gate declarado como `run_check "$gate" "bash '$gate_script' --path '$ROOT'"`, e `check-suite-wiring.sh` só aceita `--root`:

```
$ FORGE_ROOT="$PWD" bash template/.forge/scripts/check-suite-wiring.sh --path "$PWD"
FAIL suite-wiring — argumento desconhecido '--path' (use --root <dir>)
RC=2
```

`run_check` (`pre-push:204-221`) converte qualquer rc não-zero em `pre-push BLOQUEADO: <label> falhou` seguido de `exit 1`, e `gate_deps_ready` (`pre-push:193-201`) não salva o caso, porque só pula comandos que casam `*pnpm*|*npm*|*npx*|*yarn*` — conferi as duas funções no fonte. Ou seja, aplicada a decisão (f) como a revisão 3 a escreveu, **o primeiro `git push` depois da Fase 1 é bloqueado com o produto correto e a fiação correta**: a suíte está fiada, e quem reprova é a incompatibilidade de flag.

**A escolha é (ii): `check-suite-wiring.sh` ganha `--path` como alias de `--root`.** A alternativa (i) — declarar só `check-secrets` e registrar `check-suite-wiring` como órfão por interface — foi descartada, e a razão é do produto, não deste repositório. Que `--path` é o contrato de quem entra em `runtime.gates` está escrito no próprio harness: `check-secrets.sh:18` documenta `--path <path>` como *"alias de `path`, para runtime.gates do pre-push"* e a linha 40 o implementa. Um gate que não honra esse contrato **não pode ser declarado em `runtime.gates` por consumidor nenhum** — e o gate em questão é justamente o que existe para detectar suíte entregue e nunca chamada. Deixá-lo assim seria o defeito que ele combate, aplicado a ele mesmo. Sob (i), o repositório que produz a norma declararia um único gate e registraria em ledger que o outro é inalcançável; sob (ii), o ecossistema inteiro ganha o gate declarável.

**A correção foi executada em bancada, com controle, aplicação e recontrole** (cópia do script sob `$TMPDIR`, `lib/gate-universe.sh` ao lado, arquivo rastreado nenhum tocado):

```
$ sed -i '' "s|    --root) shift;|    --path\|--root) shift;|" "$T/cw.sh"
$ grep -n -- '--path' "$T/cw.sh"
31:    --path|--root) shift; [ $# -gt 0 ] || { echo "FAIL suite-wiring — --root exige um argumento" >&2; exit 2; }

$ for a in --root --path --nope; do out=$(FORGE_ROOT="$WS" bash "$T/cw.sh" "$a" "$WS" 2>&1); printf '%s => rc=%s | %s\n' "$a" "$?" "$(printf '%s' "$out" | tail -1)"; done
--root => rc=0 | OK suite-wiring — 1 runner(s) fiado(s) em 3 ponto(s) de entrada examinado(s)
--path => rc=0 | OK suite-wiring — 1 runner(s) fiado(s) em 3 ponto(s) de entrada examinado(s)
--nope => rc=2 | FAIL suite-wiring — argumento desconhecido '--nope' (use --root <dir>)
```

O recontrole é a terceira linha: o alias **não** afrouxa o parser — argumento de fato desconhecido continua saindo 2 com a mesma mensagem. É essa linha que impede a correção de virar `*) shift ;;`, o descarte silencioso que `tests/w150-liaison-flag-and-trust-gate.sh:273` reprova nominalmente.

**A varredura da lição 2 (invariante 15) foi refeita para a interface nova, e nenhum gate cai.** Medido: `tests/w146-suite-invocation-gate.sh:27` define `run_check() { out="$(bash "$CHECK" --root "$1" 2>&1)"; ... }` e usa `--root` nas seis invocações (linhas 40, 51, 62, 71, 118); `.github/workflows/ci.yml:74` também passa `--root`. A string `argumento desconhecido` não é afirmada por gate nenhum sobre este script — a única ocorrência dela em `tests/` é `w150:273`, que conta ocorrências de `*) shift ;;` em **outro** arquivo e portanto é ajudada, não prejudicada, por um parser que continua recusando.

**O que isso custa à §6, dito em voz alta:** a onda deixa de mudar **uma** linha em `template/` e passa a mudar **duas** — a `USER_DATA` de `doctor.sh:114` e o `case` de `check-suite-wiring.sh:31`. A §6 registra as duas, e a segunda é aditiva por construção (uma flag nova aceita; nenhuma flag existente muda de significado), o que a torna retrocompatível para todo consumidor instalado.

Os dois gates escolhidos são os que já rodam no `ci.yml` como passos próprios contra a raiz, e o custo local deles foi medido, em três execuções cada, sob a carga registrada no cabeçalho desta spec (`load averages: 26,28 27,30 27,15` — ou seja, o **pior** caso, não o melhor):

```
check-secrets       5785ms   5208ms   6238ms
check-suite-wiring   349ms    357ms    316ms
```

Menos de sete segundos somados, com a máquina sob três suítes simultâneas. Um `pre-push` desse tamanho não vira `--no-verify`.

**O que a forma CSV faz com as FASES, medido antes de fiar (lição 5).** Montei uma fixture com exatamente este `FORGE.md` e chamei o leitor único do produto: `forge_get_runtime gates` devolve `check-suite-wiring,check-secrets`, `forge_runtime_gates_phase source` devolve os dois, e `forge_runtime_gates_phase pre-deploy` devolve **vazio**. Ou seja: a forma CSV põe tudo na fase `source`, que é a que o `pre-push` executa (`pre-push:443-445`) — o caminho que a fase quer —, e declara ZERO gate para qualquer outra fase. A consequência é para a Onda K e precisa estar escrita aqui, porque é esta fase que cria o bloco: `run-gates.sh --phase pre-deploy` neste repositório cai na guarda de vacuidade (`run-gates.sh:60-67`, que só dispara quando `--phase` é pedido explicitamente) e reprova por universo vazio. Não é defeito desta fase e não se corrige aqui — declarar gate de fase que não existe seria pior —, mas a Onda K precisa saber que o primeiro `--phase pre-deploy` deste repositório reprova por vacuidade, e não por gate quebrado. Entra como item de ledger com esta medição.

**`runtime.test` fica ausente, deliberadamente, e a base agora é medição e não o teto do CI.** A revisão 1 justificou a ausência com `timeout-minutes: 25` do `ci.yml`, que é um **teto**, não um custo — o próprio comentário do arquivo diz que ele existe porque o default do GitHub é 6 horas. O custo real, medido nas dez últimas execuções do workflow:

```
$ gh run list --workflow=ci.yml --limit 10 --json displayTitle,status,conclusion,createdAt,updatedAt
success 585s · success 702s · success 696s · success 639s · success 681s · failure 640s
success 655s · success 675s · failure 673s · success 681s
```

Entre 585 e 702 segundos num runner `ubuntu-latest` dedicado — dez a doze minutos por push, e mais numa máquina de desenvolvimento que já roda outras coisas. Declarar `runtime.test: npm test` poria isso no caminho de todo `git push`. A autoridade da suíte já é o CI, num runner que o autor não controla, e a ausência precisa estar **escrita** no `FORGE.md`, porque a issue #106 mede o dano de um `runtime.test` sem guarda de cobertura e um campo ausente sem razão registrada é indistinguível de um campo esquecido.

**`check-authz`, `check-data-governance` e `check-observability` não são declarados.** Eles pressupõem uma superfície de aplicação (rotas, PEPs, wrappers de telemetria) que este repositório não tem, e declará-los produziria universo vazio a cada push — o que ou reprova por vacuidade, ou exige três isenções na allowlist, e três isenções escritas para calar um gate que não se aplica é o esvaziamento que o próprio arquivo de allowlist adverte contra. A fase registra em letra, no `FORGE.md`, que são órfãos por desenho aqui.

### (g) `machinery.lock` é ignorado pelo git, e a saída é o CI aplicar o update — NÃO uma negação no `.gitignore`

Este é o bloqueador 4, e o revisor estava certo no diagnóstico e **errado na correção acionável**. Medido:

```
$ git check-ignore -v .forge/cache/machinery.lock
.gitignore:14:.forge/cache/	.forge/cache/machinery.lock
```

A linha é 14, não 18, e não vem do bloco gerenciado: o `.gitignore` da raiz **já** ignora `.forge/cache/` hoje, antes de qualquer instalação. O bloco gerenciado repete o padrão (`installer/gitignore.patch:18`), então o arquivo fica ignorado pelas duas vias.

A correção sugerida pelo revisor — *"negar `!.forge/cache/machinery.lock` FORA do bloco gerenciado"* — **não funciona**, e isso foi medido em repositório sintético, não deduzido da documentação:

```
# caso 1 — o padrão de DIRETÓRIO seguido da negação
$ printf '.forge/cache/\n!.forge/cache/machinery.lock\n' > .gitignore && git check-ignore -v .forge/cache/machinery.lock
.gitignore:1:.forge/cache/	.forge/cache/machinery.lock            # CONTINUA IGNORADO

# caso 3 — a negação num bloco posterior, exatamente como o revisor propôs
$ printf '# bloco a\n.forge/cache/\n# bloco b\n!.forge/cache/machinery.lock\n' > .gitignore && git check-ignore -v .forge/cache/machinery.lock
.gitignore:2:.forge/cache/	.forge/cache/machinery.lock            # CONTINUA IGNORADO

# caso 2 — o único que funciona exige trocar o padrão por um de ARQUIVOS
$ printf '.forge/cache/*\n!.forge/cache/machinery.lock\n' > .gitignore && git check-ignore -v .forge/cache/machinery.lock
.gitignore:2:!.forge/cache/machinery.lock	.forge/cache/machinery.lock   # não ignorado
```

O git não reabre diretório excluído, e o padrão do bloco gerenciado é de diretório. A única forma de rastrear o lock seria trocar `.forge/cache/` por `.forge/cache/*` **no `installer/gitignore.patch`**, ou seja mudar o contrato de todo consumidor instalado para acomodar este repositório — a mesma troca que a decisão (e) já recusou.

O campo, aliás, está dividido sobre isso, o que confirma que a ambiguidade é real e não invenção da fase:

```
$ git -C ~/Documents/projects/axis-fare-validator ls-files .forge/cache
.forge/cache/machinery.lock
.forge/cache/publish.lock
$ grep -n 'forge/cache' ~/Documents/projects/axis-fare-validator/.gitignore
134:.forge/cache/
```

O `axis-fare-validator` e o `azim-crm` **rastreiam** o lock (entrou por `git add -f`, ou antes do padrão existir — arquivo já rastreado não é afetado por `.gitignore`), e o `axis-device-platform` não. Registro isso como achado de campo para a Onda C, que é onde #101 e o contrato do lock vivem; a Fase 1 não unifica o ecossistema.

**Decisão em duas partes:**

1. **O lock NÃO é rastreado neste repositório.** Ele é estado de instalação, e o que ele serviria para provar aqui — que a cópia instalada é a do template — a asserção [4] prova diretamente e de forma mais forte, comparando com a fonte que mora na mesma árvore.

2. **O `ci.yml` NÃO ganha passo nenhum** — a revisão 2 acrescentava `node bin/forge.mjs update --no-plugin --no-backup` antes da suíte, e a revisão 3 o remove. A razão é o bloqueador NOVO 2, que remedi por leitura do código antes de aceitar: o overlay copia todo path não-enriquecível sem perguntar (`bin/forge.mjs:614-633`), `scripts` está em `MACHINERY_DIRS` e fora de `ENRICHABLE_DIRS`, e o `WARN: drift local` só é emitido quando existe lock anterior — que num clone limpo de CI **não existe**. Ou seja, no ambiente que o próprio `ci.yml` chama de autoridade, um `forge update` antes da suíte conserta o drift que [4] existe para detectar, e o conserta em silêncio absoluto. O passo era, contra [4] e [1], exatamente o "contorno para deixar verde" que a revisão 2 negava ser.

3. **O lock passa a ser materializado pelo gate, na bancada, e não pela árvore de quem roda.** É a primeira das três saídas que o revisor ofereceu, escolhida porque é a única que também resolve dois problemas que ele não estava olhando: um worktree linkado nunca pode ter lock (o update recusa com rc 4 ali, medido) e a rodada inteira trabalha em worktrees; e um clone limpo de CI tampouco tem lock, de modo que [3], em qualquer das outras saídas, seria NÃO-VERIFICADO em CI para sempre. O sujeito de [3] passou a ser o lock que o update REAL escreve no alvo de bancada de [5] — a mesma execução, sem comando extra —, e a §5.1 [3] diz em letra o que essa asserção prova (escopo e formato do lock) e o que não prova (integridade da instalação, que é [4]).

4. **As outras duas saídas do revisor foram medidas, e uma delas entrou junto por mérito próprio.** "Rodar o update num job separado" apenas move o mascaramento de lugar sem tornar [4] falsificável, e gasta um job; descartada. "Fazer [4] e [1] lerem a árvore commitada" foi **adotada**, e não como remendo do passo de CI (que deixou de existir) mas como a forma certa da asserção: [4a] compara OIDs de blob dentro de HEAD e [1b] valida `git show HEAD:.forge/forge.yaml`, de modo que nenhum passo anterior — hoje, ou no dia em que alguém reintroduzir um — consegue deixá-las verdes por construção. O custo é um `git ls-tree -r HEAD` de 0,27s, medido.

5. **O que a fase perde ao remover o passo, dito em voz alta:** o CI deixa de provar, por execução na própria árvore do runner, que este repositório consegue reinstalar o harness que publica. Não é perda real, é troca de veículo: [5] roda o update de verdade, com o binário de verdade, sobre uma cópia da árvore de verdade, dentro do gate que o CI executa — e ainda mede o efeito no disco, que o passo de CI não media. O que o passo tinha de único era aplicar sobre a árvore rastreada, e essa propriedade virou asserção não-destrutiva em [2]: o `update --dry-run` não pode listar mudança em path de maquinaria. Dry-run não escreve nada, e a idempotência medida em 1.2 continua sendo o que ele confirma.

6. **Ainda assim, `[3]` distingue três estados**, porque o invariante 2 do plano não admite exceção. Os estados estão na seção 5.1.

## 4. Dois defeitos que a fase expõe e precisa fechar

Estes não são risco previsto: são achados produzidos durante a medição, reproduzidos por execução real contra a árvore de verdade.

```
$ FORGE_ROOT="$PWD" bash template/.forge/scripts/doctor.sh --report
  ✗ harness: .forge/forge.yaml ausente
  ✗ harness: AGENTS.md ausente (rode .forge/scripts/sync-adapters.sh)
  ✗ harness: 14 arquivo(s) da fonte canônica com refs .claude/
  ✗ harness: 2 arquivo(s) com placeholders <PROJECT_*> não preenchidos
```

Os dois primeiros são o que a Fase 1 instala. Os dois últimos são **falso positivo do doctor**, e a causa está medida em `template/.forge/scripts/doctor.sh:114-121`:

```
USER_DATA='/(specs|worktrees|product|evals|custom)/'
leaks="$(grep -rl '\.claude/' "$ROOT/.forge" … | grep -vE "/(adapters|scripts|hooks)/|/commands/harness/|$USER_DATA" | wc -l)"
orphans="$(grep -rl '<PROJECT_[A-Z_]*>' "$ROOT/.forge" … | grep -vE "/templates/|$USER_DATA" | wc -l)"
```

`ledger` e `liaison` não estão em `USER_DATA`. Os arquivos foram enumerados, não contados de longe:

```
$ grep -rl '<PROJECT_[A-Z_]*>' .forge | grep -vE "/templates/|/(specs|worktrees|product|evals|custom)/"
.forge/ledger/LEDGER.md
.forge/ledger/ledger.json
$ grep -rl '\.claude/' .forge | grep -vE "/(adapters|scripts|hooks)/|/commands/harness/|/(specs|worktrees|product|evals|custom)/" | sed 's|/[^/]*$||' | sort | uniq -c
   1 .forge/liaison/forge-harness
  11 .forge/liaison/forge-harness/blobs
   2 .forge/liaison/forge-harness/log
```

Os 2 órfãos citam `<PROJECT_ID>` como **prosa descrevendo o mecanismo do guard** — a mesma situação que o `w158` já reconheceu como legítima para `specs/archived` e `product/current`. Os 14 vazamentos são todos `.forge/liaison/**`: `CHANNEL.md`, blobs de corpo de mensagem e dois `log/*.jsonl`, ou seja **conteúdo escrito por outro repositório**, que a rule `liaison-untrusted-input.md` manda tratar como dado.

O falso positivo **sobrevive à instalação**, e isso foi medido no clone instalado: os mesmos dois greps devolvem os mesmos 2 e os mesmos 14 arquivos, nas mesmas pastas. A maquinaria instalada não acrescenta um único vazamento, porque os diretórios que legitimamente citam `.claude/` (`adapters`, `scripts`, `hooks`, `commands/harness`) já são excluídos e os demais não o citam.

A correção é acrescentar `ledger` e `liaison` a `USER_DATA`, e ela é de uma linha. É mudança de comportamento que chega a todo consumidor instalado, e a seção 6 a trata como tal.

O terceiro achado é o `<INSTALLED_AT>` órfão da seção 1.3. Os três entram no ledger com a medição **antes** de serem corrigidos, para que a correção tenha um item que a explique.

## 5. O gate novo — vermelho antes do verde

Arquivo: `tests/w<N>-dogfood-install-integrity-gate.sh`, com N alocado pelo orquestrador (ver 3.d).

**Denominador fixo: 9 asserções.** O gate imprime `w<N>: 9 asserção(ões) declarada(s)` na primeira linha e `PASS w<N>-dogfood-install-integrity-gate (9/9)` na última. Um `[k]` que não roda faz o contador final divergir de 9 e o gate reprova nomeando qual faltou. As raias de [1] e [4] (`[1a]`/`[1b]`, `[4a]`/`[4b]`) **não** mexem no denominador: cada uma delas é um contador de controle dentro da sua asserção, e é a asserção que tem veredito — o denominador de cenários é o único número literal que o gate pode ter sem virar dívida, e multiplicá-lo por raia o quebraria na primeira raia nova.

**Vocabulário de três estados, obrigatório em todas as nove** (invariante 2 do plano). `OK [k]` — examinei e não há violação. `FAIL [k]` — examinei e há violação. `FAIL [k]/NÃO-VERIFICADO` — não consegui examinar; nunca imprime `OK`, nunca sai 0. As três formas mais comuns do terceiro estado neste gate são ferramenta ausente (`node`, `ajv`, `yaml`), comando que recusa antes de produzir efeito, e universo vazio. A lição está em LDG-0157: rc≠0 de uma ferramenta **não** é violação.

**A regra que delimita o terceiro estado, escrita uma vez e válida nas nove:** `NÃO-VERIFICADO` é sobre o INSTRUMENTO, nunca sobre o objeto. Ferramenta ausente, comando que recusa antes de produzir efeito, HEAD inexistente, universo vazio — instrumento. Arquivo presente e malformado, lock presente com linha ilegível, versão presente que não é semver, sha que diverge — objeto examinado e errado, portanto `FAIL` seco. Sem essa fronteira escrita, a segunda pessoa a mexer no gate converte todo caso difícil em NÃO-VERIFICADO e o gate vira ruído com aparência de rigor.

**Política de número literal dentro do gate, também escrita uma vez** (é a dívida que reprovou duas revisões seguidas desta spec). São legítimos **exatamente um literal EXATO e os pisos declarados**. O literal exato é o denominador de cenários (`9`), fixo por construção e cuja divergência É o achado — é a única exceção que o invariante 14 admite. Os pisos declarados são três, e piso não é literal exato porque só envelhece para baixo: o piso `401` da enumeração de maquinaria (em [3] e nas duas raias de [4]) e os pisos `310` nodes e `59` edges de [9]. A revisão 3 escrevia "são literais legítimos exatamente dois" e depois carregava mais dois pisos em [9], o que fazia a política se contradizer com quem a lesse pela primeira frase; a cláusula de escape "ou expresso como piso mais propriedade" resolvia para quem lesse até o fim, e agora a contagem e a cláusula concordam. Todo o resto — número de gates em `tests/`, de arquivos rastreados, de nodes do grafo, de entradas do lock, de arquivos sob `.forge/` — é derivado no momento da execução ou expresso como piso mais propriedade. A regra tem um teste barato: se a Onda seguinte do plano-mestre acrescentar um arquivo e o número mudar, ele não podia ser literal.

**Invariante 8 (bash 3.2).** O gate não usa `declare -A`, `${var,,}`, `${var^^}`, `mapfile` nem `readarray`, e o primeiro passo da sua verificação é `/bin/bash -n tests/w<N>-dogfood-install-integrity-gate.sh` com o bash do sistema (`/bin/bash --version` → `GNU bash, version 3.2.57(1)-release (arm64-apple-darwin25)`), não com o do Homebrew.

**Higiene de árvore.** Nenhuma asserção pode sujar a árvore de quem roda o gate. Onde o gate regenera artefato, ele passa `--out` para `$TMPDIR`; onde ele muta código, muta uma **cópia** em `$T`. A razão não é estética: `tests/w201-flag-como-valor-gate.sh:35,378` tira snapshot de `git -C "$WS" status --porcelain` antes e depois, e um gate que dirtifica a árvore vira falha fantasma em gate alheio.

### 5.1 As asserções, com o vermelho de cada uma

**[1] `.forge/forge.yaml` existe, valida contra o schema e não carrega placeholder órfão.**
Verde: o arquivo existe; `yaml` + `ajv/dist/2020.js` o validam contra `template/.forge/schemas/forge.schema.json` (o schema declara draft 2020-12 e o `Ajv` default é draft-07 — o idioma correto é o de `tests/w197:125`); `grep -q '<[A-Z_]\+>' .forge/forge.yaml` não casa nada; e `harness.template_version` é semver válido **não superior** a `package.json.version`.
**Vermelho hoje:** `FAIL [1]: .forge/forge.yaml não existe — este repositório não é consumidor de si mesmo`. Falha por ausência real do arquivo (`ls -la .forge/`). Não há fixture envolvida.
**Terceiro estado, e a regra que o delimita:** `NÃO-VERIFICADO` é sobre o INSTRUMENTO, nunca sobre o objeto. `FAIL [1]/NÃO-VERIFICADO: ajv ou yaml indisponíveis (rode npm ci)` quando o `require` falha, e o mesmo quando `package.json` não pode ser lido — porque nesses casos falta o outro lado da comparação. YAML malformado, `harness.template_version` ausente e versão que não é semver são o oposto: o objeto foi examinado e está errado, então o desfecho é `FAIL` seco, com o campo nomeado. Sem essa regra escrita, a segunda pessoa a mexer no gate converte todo caso difícil em NÃO-VERIFICADO e o gate vira ruído.
**Duas raias, pela mesma razão do bloqueador NOVO 2:** [1a] valida `.forge/forge.yaml` da árvore de trabalho e [1b] valida `git show HEAD:.forge/forge.yaml`. A raia de HEAD existe porque `bumpTemplateVersion` (`bin/forge.mjs:392`) reescreve o campo em todo `forge update`, então um update rodado antes do gate apaga da árvore de trabalho exatamente a edição à mão que [1] existe para pegar — e a deixa viva no commit. Nada consegue alterar o que já está em HEAD. Quando os paths não existem em HEAD (instalação aplicada e ainda não commitada — o estado entre o passo 5 e o commit do protocolo), [1b] é `FAIL/NÃO-VERIFICADO: a instalação ainda não está commitada`, nunca `OK`.
**Por que não igualdade de versão** (bloqueador 8): `template_version` só é reescrito quando `forge update` roda (`bumpTemplateVersion`, `bin/forge.mjs:392`, chamado em `:685`), e a Onda J bumpa `package.json` num PR de release contra `main`. Entre o bump e o update seguinte, uma asserção de igualdade reprovaria sem defeito nenhum, e o back-merge carregaria o vermelho. `template_version <= package.json.version` nunca fabrica vermelho no bump e continua mordendo o caso real — alguém editar `.forge/forge.yaml` à mão para uma versão futura, ou instalar de um `--source` mais novo que o produto. O drift de conteúdo, que é o risco de verdade, é [4] quem pega, e [4] não depende de versão.
**E a Fase 1 registra a dependência com a Onda J em vez de deixá-la na memória de quem fizer a release:** depois desta fase, um bump de `package.json` sem o `forge update` correspondente deixa `.forge/forge.yaml` uma versão atrás, o que [1] tolera de propósito (`<=`) mas [2] passa a NOMEAR na lista de mudanças do dry-run. A fase abre item de ledger dizendo que o PR de release da Onda J inclui `node bin/forge.mjs update --no-plugin --no-backup` e o commit do `.forge/forge.yaml` resultante, e o cabeçalho do gate cita esse item.

**[2] `node bin/forge.mjs update --dry-run` não recusa, e não lista mudança em path de MAQUINARIA.**
Verde: rc 0, a saída não contém `existe mas forge.yaml não`, e nenhuma das linhas de mudança (`+ `, `~ `, `= `, `- `, `! `, formadas em `bin/forge.mjs:545-562`) nomeia um path de maquinaria. Contador de controle: `[2] N linha(s) de mudança, M em path de maquinaria`, e reprova quando M é maior que zero, nomeando até dez.
**Por que não a forma óbvia "0 mudança(s) de arquivo"**, que é o que a instalação produz hoje (medido em 1.1): ela seria vermelho fabricado na primeira release, porque o dry-run emite `~ forge.yaml (template_version)` sempre que `package.json` está à frente de `.forge/forge.yaml`, e a Onda J bumpa `package.json` num PR próprio. É a mesma classe do bloqueador 8 da revisão 1, e a saída é a mesma: asserir sobre o que não pode divergir sem defeito — a maquinaria — e IMPRIMIR, sem engolir, as linhas de `forge.yaml`. A linha `! forge.yaml (<chave>: seção nova exige preenchimento manual — não mesclada)` é a exceção da exceção: ela reprova, porque significa que o template publicou uma seção que este consumidor precisa preencher, e este repositório é consumidor de si mesmo.
**Vermelho hoje:** `FAIL [2]: update recusou com rc=3 — ".forge existe mas forge.yaml não"`. É a reprodução literal da seção 1, com a mensagem exata do binário, e o comando é o mesmo que qualquer pessoa roda na raiz.
**Worktree linkado: o gate RETARGETA em vez de desistir, e a saída veio de execução.** A revisão 3 mandava [2] imprimir `NÃO-VERIFICADO` sempre que o checkout fosse um worktree linkado — e como a rodada inteira trabalha em worktrees e o próprio harness instala um hook de `PreToolUse` que os exige, isso deixava [2] em NÃO-VERIFICADO permanente, ou seja um gate honesto e inútil. O revisor apontou uma saída que o mecanismo já medido sustenta, e eu a remedi em repositório sintético antes de aceitar: `mainCheckoutOf(target)` (`bin/forge.mjs:531`, implementado em `:203-209`) julga o **alvo**, então apontar o alvo para o checkout principal passa o guard.

```
$ cd "$T/wt/linked"                                    # worktree linkado
$ node "$WS/bin/forge.mjs" update --dry-run            # alvo implícito = o próprio worktree
FAIL (update rodado de dentro de um worktree linkado (/private/var/.../wt/linked). …)
rc=4
$ node "$WS/bin/forge.mjs" update --dry-run --target "$T/wt/main"
402 mudança(s) de arquivo. Rode sem --dry-run para aplicar.
rc=0
$ git rev-parse --path-format=absolute --git-dir         # /private/var/.../wt/main/.git/worktrees/linked
$ git rev-parse --path-format=absolute --git-common-dir  # /private/var/.../wt/main/.git
```

A propriedade que [2] passa a cobrar: **o dry-run é observado contra o checkout principal, venha o gate de onde vier.** Quando `--git-dir` e `--git-common-dir` divergem, o alvo é o `dirname` do segundo; quando coincidem, o alvo é o próprio checkout. `--dry-run` não escreve nada — conferido no alvo depois da execução acima —, então retargetar não é escrever na árvore de outra frente.

**Terceiro estado, agora reduzido ao que é de fato instrumento.** `rc 4` persistente **depois** do retarget (o alvo derivado não é checkout principal — repositório corrompido, ou `git` velho demais para `--path-format=absolute`) e `rc 127` (node ausente) imprimem `FAIL [2]/NÃO-VERIFICADO` com a causa nomeada. `rc 3` continua sendo `FAIL` seco: o objeto foi examinado e o harness não está instalado.

**[3] O `machinery.lock` que um `forge update` REAL produz cobre a enumeração de maquinaria inteira, com piso e cobertura por conjunto.**
O sujeito desta asserção mudou na revisão 3, e a mudança resolve os dois bloqueadores novos de uma vez: o lock examinado é o que o update de bancada de [5] escreve em `$T/alvo/.forge/cache/machinery.lock`, **não** o lock do checkout de quem roda o gate. As três razões estão medidas. Primeira: o lock é ignorado pelo git por um padrão de DIRETÓRIO (`.gitignore:14`, `.forge/cache/`), então ele não existe num clone limpo nem no runner de CI, e era só para materializá-lo ali que a revisão 2 pôs um `forge update` antes da suíte no `ci.yml` — o passo que o bloqueador NOVO 2 mostrou destruir a falsificabilidade de [4] e [1]. Segunda: num worktree linkado o lock nunca pode existir, porque o update recusa com rc 4 ali (medido em [2]), e a rodada inteira trabalha em worktrees. Terceira: o que um lock do checkout provaria — que a cópia instalada é a do template — [4] prova diretamente, na mesma árvore, e mais forte.
Verde: o update de bancada de [5] (a MESMA execução, não uma segunda) termina com o lock escrito; toda linha não-comentário casa `^([0-9a-f]{64})  (.+)$`, que é o leitor literal de `readMachineryLock` (`bin/forge.mjs:360-368`); e a cobertura contra a enumeração de maquinaria é **bidirecional** — nenhuma entrada da enumeração falta no lock, nenhuma entrada do lock está fora da enumeração, e o sha de cada entrada é o de `template/.forge/<rel>`.
**Contador com PISO, nunca contagem exata** (bloqueador NOVO 1): o gate imprime `[3] N entrada(s) de lock conferida(s) (piso 401), A ausente(s), E excedente(s)` e reprova quando `N < 401`, quando `A > 0` ou quando `E > 0`. A forma que a revisão 2 escreveu — "reprova se o número for diferente de 401" — era vermelho fabricado com o produto certo e o gate certo: qualquer arquivo novo de maquinaria leva a enumeração a 402, e a Onda K do plano-mestre entrega pelo menos quatro (`template/.forge/scripts/lib/deploy-common.sh`, `template/.forge/scripts/deploy.sh`, `lib/ci/github-actions.sh` e um segundo adaptador de provedor — plano-mestre, linhas 191-193), todos sob `scripts`. O piso mede a data desta redação, só envelhece para baixo, e só uma REMOÇÃO deliberada de maquinaria o toca.
**Como a enumeração é derivada sem reimplementar a lista:** o gate lê a constante do próprio produto — `const MACHINERY_DIRS = [...]` de `bin/forge.mjs`, por regex sobre o fonte (medido: devolve os dez diretórios) — e aplica a mesma regra de `machineryFiles()`: os dez diretórios, mais `adapters/*.yaml` que não sejam `*.lock.yaml`, mais `README.md`, sem `.DS_Store`. Reimplementar a LISTA no gate é a dívida que a lição 1 descreve, e ela envelheceria no dia em que alguém acrescentasse um diretório de maquinaria; derivar a lista e travar só o PISO deixa a enumeração seguir o produto sem perder a contrapositiva.

**As duas regras que o gate reimplementa mesmo assim, e por que a divergência delas É o achado.** Além da lista, `machineryFiles()` carrega duas regras que o gate reproduz sem derivar: `adapters/*.yaml` que não sejam `*.lock.yaml`, e `README.md` na raiz. A ressalva do revisor procede — elas envelhecem pelo mesmo motivo que a lista envelheceria. A decisão é **declarar em letra que a divergência é o achado**, e não derivá-las: a cobertura de [3] é **bidirecional**, então uma mudança em `machineryFiles()` que altere qualquer das duas regras aparece imediatamente como entrada ausente ou excedente, com o path nomeado, e o gate reprova pedindo a decisão em vez de seguir em silêncio. Derivar as duas por regex exigiria parsear a lógica do walk, não uma constante — trocaria uma dívida rara e barulhenta por um parser frágil e mudo.

**Ordem obrigatória entre [3] e [6], e ela é assimétrica.** [3] examina o lock que o update de bancada de [5] escreve em `$T/alvo`, e o update **mutado** de [6] reescreve esse MESMO lock com 402 entradas (medido). Se a implementação rodar [3] depois de [6] e antes do recontrole, o contador de excedentes reprova com o produto certo e o gate certo — vermelho fabricado por ordenação. **A especificação fixa: [3] lê o lock do alvo antes de [6] mutar qualquer coisa**, e a alternativa igualmente válida é [5] copiar o lock para fora do alvo ao terminar, deixando [3] livre da ordem. Qualquer das duas serve; o que não serve é deixar a ordem implícita.
**O que [3] prova e o que NÃO prova, dito em letra para que ninguém a leia como prova de instalação:** o sha de cada entrada casar com `template/.forge/<rel>` é tautológico por construção, porque o lock foi gerado daquele mesmo template. O que [3] prova é ESCOPO e FORMATO — que `writeMachineryLock` cobre toda a enumeração e que `readMachineryLock` relê o que ele escreve. O comentário do produto (`bin/forge.mjs:370-372`) diz que estreitar esse escopo "para enxugar o lock" quebraria em silêncio o segundo uso do lock, o WARN de drift local; [3] é a asserção que morde essa mudança. A integridade da instalação é [4], e ela não depende do lock.
**Vermelho hoje:** `FAIL [3]/NÃO-VERIFICADO: o update de bancada recusou (rc=3) — nenhum lock foi produzido e a cobertura não pôde ser observada`. A bancada copia o `.forge/` da raiz, que hoje não tem `forge.yaml`, então o comando recusa antes de escrever: é falha por causa real, e a mensagem nomeia a mesma causa que [1] e [2] nomeiam.
**Terceiro estado, separado do vermelho:** `node` ausente, e rc 4 caso alguém torne a bancada um repositório git com worktree (é uma das razões de a bancada não ser repositório git, §5). Lock com linha ilegível **não** é terceiro estado: `readMachineryLock` conta `invalid` e emite WARN (`bin/forge.mjs:365-367`), o objeto foi examinado e está corrompido, e o desfecho é `FAIL` seco.
**Medido nesta revisão, na bancada:** `update --target $T/alvo --no-plugin --no-backup` devolve rc 0, o produto imprime `maquinaria: 401 arquivo(s) de template aplicados (overlay aditivo)`, e o lock sai com **2 linhas de cabeçalho e 401 entradas**. Com `--source`, o cabeçalho ganha uma TERCEIRA linha (`bin/forge.mjs:384`) — é por isso que o gate conta linhas não-comentário em vez de `wc -l` menos dois, que é como a revisão 2 chegou ao 403.

**[4] A maquinaria instalada é byte a byte igual ao produto — na árvore COMMITADA e na árvore de trabalho.**
São duas raias, e a primeira é a autoritativa. Ela existe por causa do bloqueador NOVO 2: enquanto [4] só olhasse a árvore de trabalho, qualquer passo anterior que rodasse `forge update` a deixaria verde por construção, porque `scripts` está em `MACHINERY_DIRS` e fora de `ENRICHABLE_DIRS` e o overlay copia os 401 arquivos sem perguntar (`bin/forge.mjs:614-633`, `cpSync` incondicional para todo path não-enriquecível). Confirmei o mecanismo no código e um agravante que o veredito não menciona: o `WARN: drift local em <rel> sobrescrito pelo template` só é emitido quando existe lock anterior (`oldLock && oldLock.has(rel)`), e num clone limpo de CI não existe lock nenhum — a sobrescrita é **totalmente silenciosa** lá.
**Raia (a), HEAD — autoritativa.** Um único `git ls-tree -r HEAD -- .forge template/.forge` (medido: 0,27s, 344 blobs sob `.forge` e 432 sob `template/.forge` hoje) devolve modo e OID de blob de cada path. Para cada `<rel>` da enumeração, a asserção é `OID(HEAD:.forge/<rel>) == OID(HEAD:template/.forge/<rel>)`. Comparar OID é comparar conteúdo sem passar por filtro de working tree nenhum, e nada — nem `forge update`, nem `sync-adapters`, nem um passo de CI — altera o que já está em HEAD. É a raia que continua falsificável ainda que alguém torne a pôr um update antes da suíte.

**De onde vem a enumeração de [4a], e por que isso resolve o rótulo duplo.** A ressalva do revisor procede e a resolução é escolher o lado: **a enumeração de [4a] sai do lado FONTE dentro de HEAD** — `template/.forge/` em `HEAD` —, nunca da árvore de trabalho. Duas consequências, e as duas são o que se quer. Primeira: um arquivo de maquinaria novo e ainda não commitado não existe em HEAD **dos dois lados**, então ele não joga [4a] em NÃO-VERIFICADO nem em vermelho — [4b], que lê a árvore, é quem o vê. Segunda: o universo de [4a] nunca é vazio num repositório que tem o produto commitado, o que elimina o rótulo `universo-vazio` desta raia. Medido hoje, em `HEAD=c41eead`:

```
$ git ls-tree -r HEAD -- template/.forge | awk '{print $4}' | sed 's|^template/\.forge/||' | wc -l
     432
$ ... | awk '<a regra de machineryFiles: os dez diretórios + adapters/*.yaml não-lock + README.md>' | wc -l
     401
$ comm -23 <(sort mach-head.txt) <(git ls-tree -r HEAD -- .forge | awk '{print $4}' | sed 's|^\.forge/||' | sort) | wc -l
     401
```

**O rótulo, decidido:** ausência de contraparte em `.forge/<rel>` é **`FAIL` seco, nunca NÃO-VERIFICADO**, porque o instrumento funcionou e o objeto foi examinado — o `ls-tree` rodou, enumerou 401 paths de maquinaria e observou que a árvore commitada não carrega a instalação. É exatamente o defeito que [4a] existe para pegar no dia em que alguém apagar `.forge/scripts/` e commitar, e é o vermelho de hoje. `NÃO-VERIFICADO` fica reservado ao que de fato é instrumento: `git` ausente, HEAD inexistente, e o lado **fonte** ausente de HEAD (que significa um HEAD anterior ao produto, e aí não há com o que comparar).
**Raia (b), árvore de trabalho.** `sha256(.forge/<rel>) == sha256(template/.forge/<rel>)`, que pega o drift local antes do commit. `.forge/contracts` tem de ser diretório real, não symlink (decisão 3.e), e a comparação usa `-h` para detectar isso; em HEAD o mesmo fato aparece como modo `120000` no `ls-tree` (medido hoje: `120000 blob 61da15b8… .forge/contracts`).
**Contadores de controle, com PISO LITERAL nos dois** (bloqueador 7 da revisão 1, mantido): `[4a] N path(s) comparado(s) em HEAD (piso 401), M divergente(s)` e `[4b] N path(s) comparado(s) na árvore (piso 401), M divergente(s)`. Qualquer `M > 0` reprova nomeando até dez paths; `N < 401` reprova por piso. O 401 é literal, não derivado da enumeração, porque `machineryFiles()` é a mesma função que alimenta `writeMachineryLock` (`bin/forge.mjs:378`) e um denominador derivado encolhe junto com ela: apagar metade de `template/.forge/scripts/` e rodar `forge update` deixaria os dois lados consistentes e o gate verde. Mexer no piso é edição deliberada, com a medição nova ao lado (`node -e '<enumeração>'` → 401 nesta redação).
**Terceiro estado da raia (a), e a lição 4 aplicada:** procurei o desfecho que a enumeração não cobria e ele existe — `git ls-tree -r HEAD` num repositório SEM COMMIT sai **128** com `fatal: Not a valid object name HEAD` (medido em repositório sintético), exatamente a classe do achado que derrubou uma enumeração "exaustiva" na rodada anterior. Os três desfechos de instrumento são `git` ausente, HEAD inexistente e **o lado fonte** ausente de HEAD. Nos três, `FAIL [4a]/NÃO-VERIFICADO` com a causa nomeada, jamais `OK`. O estado entre o passo 5 e o commit do protocolo — instalação no disco, ainda não no histórico — **não** é terceiro estado: é `FAIL` seco de [4a] com [4b] verde ao lado, e esse par é a leitura correta de "instalado e não commitado".
**Vermelho hoje, com os dois rótulos separados e nenhum deles `universo-vazio`:** `FAIL [4a]: 401 path(s) de maquinaria enumerado(s) em HEAD (piso 401), 401 sem contraparte em .forge/ — a instalação não está na árvore commitada` (medido acima, os três números), e `FAIL [4b]/universo-vazio: 0 path(s) comparado(s) na árvore (piso 401) — .forge/scripts, .forge/rules e .forge/commands não existem`. As duas raias falham hoje por razões diferentes e imprimem linhas diferentes: [4a] tinha o que examinar e reprovou pelo objeto; [4b] não tinha universo. A revisão 3 colapsava as duas em `universo-vazio` e, de quebra, violava o invariante 3 na raia autoritativa, que aprovaria por não ter olhado para nada se algum dia o rótulo virasse verde.
**Cabeçalho obrigatório:** a consequência declarada em 3.c — `ENRICHABLE_DIRS` é inutilizável neste repositório por desenho.

**[5] CANAL: um `forge update` REAL preserva os arquivos de instrução da raiz.**
Este é o assert que a rule `testing/gate-delivery-channel.md` exige, e ele não invoca função nenhuma: ele roda o comando. O cenário copia `.forge/` da árvore real para `$T/alvo/.forge`, grava os sha256 dos quatro arquivos de instrução, executa `node "$WS/bin/forge.mjs" update --target "$T/alvo" --no-plugin --no-backup`, e reconfere os quatro sha256 mais o inventário completo dos arquivos preexistentes.
Verde: rc 0, os quatro sha256 idênticos, zero divergências no inventário preexistente, e um **sinal positivo de execução** — a saída do update contém `Forge atualizado em` e o `machinery.lock` do alvo passou a existir. A ausência de erro não basta: um update que não rodou preservaria os quatro arquivos trivialmente.
**Vermelho hoje:** `FAIL [5]/NÃO-VERIFICADO: o update recusou (rc=3) — a preservação não pôde ser observada`. O gate não afirma que o update destrói os arquivos; afirma que **não conseguiu verificar** que não destrói, porque o comando recusa antes de chegar lá.
`--no-plugin` é obrigatório: sem ele o update escreve em `~/.claude/skills/forge`, e um gate que muta o `$HOME` de quem o roda é um gate que ninguém roda duas vezes. `--no-backup` também, e agora com a razão medida: quando o alvo **não** é repositório git, o produto avisa `(fora de um repositório git: o backup ficou DENTRO da árvore — remova-o antes de rodar gates com --path)` e escreve `.forge.bak-N` dentro do próprio alvo (`bin/forge.mjs:597-609`).
**Três condições da bancada, todas medidas nesta revisão, e nenhuma delas é estética.** (i) O alvo **não** é repositório git: `wireHooksPath()` roda ao fim de todo update e, num alvo que fosse repositório, apontaria `core.hooksPath` dele; no alvo não-git o produto imprime `git: não é um repositório — hooks não configurados` e não toca em config nenhuma. É também o que impede o rc 4 do guard de worktree dentro da própria bancada. (ii) A bancada copia `bin/`, `template/`, `installer/` **e `package.json`**: sem o `package.json`, `pkgVersion()` cai no default e o update imprime `forge.yaml: template_version -> 0.0.0` — medido, e uma asserção de versão sobre a bancada nasceria falsa por isso. (iii) O `.forge/` copiado para o alvo precisa do `forge.yaml`, senão o comando recusa com rc 3 antes de escrever — que é justamente o vermelho de hoje.
**Custo, medido sob a carga registrada no cabeçalho desta spec:** um update de bancada completo levou entre 60 e 130 segundos com três suítes rodando em paralelo, e o grosso é o `sync-adapters` mais o `doctor` que o próprio update chama no fim. O gate roda o comando **três** vezes ([5], [6] mutado, [6] restaurado) e [3] reaproveita o lock da execução de [5] em vez de rodar uma quarta. Isso põe o gate na classe dos caros, e a §7 mede o custo real numa máquina ociosa antes de a fase fechar.

**[6] MUTAÇÃO do canal, com recontrole por checksum.**
O que se muta é o **mecanismo que [5] guarda**: a fronteira entre maquinaria e arquivo de instrução. A mutação faz `machineryFiles()` passar a enumerar `FORGE.md` da raiz do template como se fosse maquinaria, o que faz o overlay sobrescrever `.forge/FORGE.md` do alvo.
A mutação **nunca toca arquivo rastreado**. LDG-0175 mede o custo de usar `template/.forge/scripts/tests/run-all.sh` — arquivo rastreado e distribuído no pacote — como fixture sem restaurar, e o encontrou reduzido a um stub de 3 linhas. Aqui o gate copia `bin/`, `template/` e `installer/` para `$T/pkg` e muta a **cópia**.

**O primitivo da edição é escolha do implementador, e a especificação não o prescreve — invariante 19.** A revisão 3 prescrevia `node -e '<código>' <caminho>` lendo `process.argv[2]`, e isso está errado: **com `node -e` não existe arquivo de script, então o primeiro argumento do usuário cai em `process.argv[1]`**. Medido nesta revisão, com o controle ao lado:

```
$ node -e 'console.log(JSON.stringify(process.argv))' /tmp/foo.txt bar
["/opt/homebrew/Cellar/node/26.0.0/bin/node","/tmp/foo.txt","bar"]

$ printf 'console.log(JSON.stringify(process.argv))\n' > "$T/argv/s.mjs" && node "$T/argv/s.mjs" /tmp/foo.txt bar
["/opt/homebrew/Cellar/node/26.0.0/bin/node","/var/.../T/f1-rev4/argv/s.mjs","/tmp/foo.txt","bar"]
```

A prescrição errada estava, agravantemente, no parágrafo que **ensinava** a evitar mutação-fantasma, que é a forma mais provável de ser copiada sem conferência. O que a especificação declara em lugar dela:

- **Propriedade:** a edição altera o fonte da cópia em `$T/pkg/bin/forge.mjs` de modo que `machineryFiles()` passe a enumerar `FORGE.md` da raiz do template.
- **Contrafactual obrigatório:** `cmp` (ou `shasum`) entre a cópia mutada e a pristina tem de acusar **diferença** ANTES de o update mutado rodar. Enquanto o controle imprimir "idênticos", não houve mutação e nenhuma conclusão pode ser tirada da execução seguinte.
- **Duas armadilhas nomeadas, com a evidência de cada uma:** `perl -0pi -e` com `$` sem escape do lado direito são variáveis do **perl**, vazias, e a mutação vira `cp "" ""` (LDG-0164); e o índice de `process.argv` depende de o mutador ser `-e` ou arquivo, medido acima.
- **A prova de que o primitivo escolhido discrimina é do implementador**, e ela é a matriz de [6] inteira rodando: controle idêntico, mutação acusada por `cmp`, os três efeitos da tabela abaixo observados, recontrole voltando ao sha pristino.
**A matriz desta mutação foi EXECUTADA nesta revisão, e o efeito medido não é o que a revisão 2 escreveu.** Rodei a mutação numa cópia sob `$TMPDIR` e observei três efeitos, não um:

| o que a mutação faz | efeito medido |
|---|---|
| `machineryFiles()` passa a enumerar `FORGE.md` | `.forge/FORGE.md` do alvo é sobrescrito pelo do template — sha `b36a11d0…` → `65e4447d…` |
| o overlay escreve 402 arquivos | o produto imprime `maquinaria: 402 arquivo(s) de template aplicados` e o lock do alvo sai com **402** entradas, ganhando a linha `65e4447d…  FORGE.md` |
| o orphan-check pós-overlay roda | o update **sai com rc 1** e `FAIL (1 arquivo(s) de maquinaria com placeholders <PROJECT_*> — template inválido?)`, porque `template/.forge/FORGE.md` carrega placeholders e agora está classificado como maquinaria (`bin/forge.mjs:645-651`) |

O terceiro efeito é o que obriga a escrever a asserção com cuidado: se [6] apenas exigisse "o update mutado falha", ele estaria medindo o orphan-check e não a sobrescrita, e continuaria verde se alguém removesse o orphan-check. A acusação que [6] cobra é a **mudança de sha do `.forge/FORGE.md` do alvo**, e o rc diferente de zero do binário mutado é registrado como parte do comportamento mutado — nunca como NÃO-VERIFICADO.
**Recontrole, também executado:** restaurei `$T/pkg/bin/forge.mjs` da cópia pristina, conferi o sha256 contra o gravado antes (`ecb7c166…`, idêntico), restaurei o `FORGE.md` do alvo e rodei [5] de novo — rc 0, `.forge/FORGE.md` de volta em `b36a11d0…`, lock de volta em 401 entradas. O primitivo de recontrole por checksum foi validado com controle, mutação e recontrole nesta revisão, e ele discrimina:

```
$ shasum -a 256 f.md > f.sha
$ shasum -a 256 -c f.sha            # intacto
f.md: OK                             rc=0
$ printf 'conteudo MUTADO\n' > f.md && shasum -a 256 -c f.sha
f.md: FAILED                         rc=1
shasum: WARNING: 1 computed checksum did NOT match
$ printf 'conteudo original\n' > f.md && shasum -a 256 -c f.sha
f.md: OK                             rc=0
```

`feedback-mutacao-fantasma-restore` registra o caso em que um `restore()` quebrado deixou a mutação eterna e ninguém viu, e na redação da revisão 3 a armadilha apareceu de verdade: a mutação passou o caminho onde o `readFileSync` recebia `undefined`, o arquivo não mudou, e o `cmp` de controle imprimiu "IDENTICOS". Foi o controle que pegou — as duas vezes, na redação do autor e na do revisor. **É por isso que o controle é obrigatório e o primitivo não é**: qualquer idioma serve desde que o `cmp` acuse diferença antes do update mutado rodar.
Controle final: ao fim de [6], `sha256(bin/forge.mjs)` da árvore real tem de ser idêntico ao do início do gate.
**Vermelho hoje:** [6] depende de [5] chegar a executar; hoje ele não chega, e a saída é `FAIL [6]/NÃO-VERIFICADO: mutação não executada porque [5] não pôde observar o canal` — que conta como asserção **executada e não-verificada**, e portanto reprova o gate sem deixar o denominador cair de 9. Um `SKIP` que não conta é a porta pela qual um gate perde metade das asserções em silêncio.

**[7] `.forge/contracts` é diretório real.**
Verde: `[ -d .forge/contracts ] && [ ! -L .forge/contracts ]`, e os 5 arquivos batem com `template/.forge/contracts/**` (já coberto por [4], repetido aqui porque a razão é outra: o alvo de escrita do update).
**Vermelho hoje:** `FAIL [7]: .forge/contracts é symlink para ../template/.forge/contracts — um update escreveria dentro do produto`. Falha por estado real, medido em `ls -la .forge/`, e o mesmo fato aparece em HEAD como modo `120000` (`git ls-tree -r HEAD -- .forge/contracts` → `120000 blob 61da15b8…`, medido) — o gate confere as duas formas, porque a raia de HEAD de [4] já tem o `ls-tree` na mão e o symlink commitado é o que chega a quem clona.
**Enumeração de desfechos, com o caso que faltava:** diretório real (verde), symlink (vermelho acima), **arquivo comum** (vermelho próprio: `FAIL [7]: .forge/contracts é um arquivo, não um diretório`), e ausência total (`FAIL [7]/NÃO-VERIFICADO: .forge/contracts não existe`). Os quatro imprimem linhas diferentes; a revisão 2 enumerava só três e o caso do arquivo comum caía na linha da ausência.

**[8] O doctor da raiz não produz falso positivo em dado de projeto.**
Verde: `FORGE_ROOT="$WS" bash "$WS/template/.forge/scripts/doctor.sh" --report` não imprime `placeholders <PROJECT_*> não preenchidos` nem `refs .claude/`. **Contador de controle próprio:** o gate confere que o doctor de fato examinou — a saída tem de conter as duas linhas positivas (`fonte canônica sem refs .claude/` e `sem placeholders <PROJECT_*> órfãos`), e não apenas a ausência da linha de falha.
Controle e recontrole desta asserção: o gate cria um placeholder `<PROJECT_ID>` real num `FORGE.md` de fixture sob `$T`, com `FORGE_ROOT` apontando para lá, e exige que o doctor **acuse exatamente 1 arquivo**; depois remove e exige que volte a zero. Esse `1` é o único literal exato da asserção e ele é legítimo pelo mesmo motivo que o denominador `9`: é o denominador do cenário que o próprio gate constrói, e não um contador da árvore — a fixture tem um arquivo porque o gate a criou com um. Sem isso, [8] passaria num doctor cuja varredura fosse desligada por completo.
**Vermelho hoje:** `FAIL [8]: doctor reporta N arquivo(s) com placeholders <PROJECT_*> e M arquivo(s) com refs .claude/ — todos sob .forge/ledger e .forge/liaison, que são dado de projeto`, com `N` e `M` lidos da saída do doctor no momento da execução e a lista de arquivos enumerada pelo próprio gate. **Os números não são literais na asserção, de propósito:** na medição da seção 4 eles eram 2 e 14, mas `.forge/liaison/**` cresce a cada `liaison sync` — hoje são 166 arquivos e o store é append-only — e um vermelho que cobrasse "exatamente 14" trocaria de valor sozinho, sem defeito nenhum, entre a redação desta spec e a execução dela. O que a asserção cobra é a PROPRIEDADE: zero arquivo acusado, e, enquanto houver algum, que todos estejam sob os dois diretórios de dado (se aparecer um fora deles, o achado é outro e o gate diz isso).
**Terceiro estado:** `FAIL [8]/NÃO-VERIFICADO` quando o doctor sai com rc que indica que ele não rodou.

**[9] O grafo não duplica.**
Esta asserção foi inteiramente reescrita — a forma da revisão 1 estava morta por construção e nascia vermelha por número copiado de artefato defasado (bloqueadores 2 e 3, e os dois procediam).

Verde, e a ordem dos três itens importa:

1. **Propriedade, não contagem:** o grafo **regenerado** não tem **nenhum** node cujo **`id`** comece com `.forge/`. O campo é `id`, não `path` — os nodes não têm `path`, e a asserção escrita com `path` filtraria por `undefined` em 100% deles e aprovaria um grafo inteiramente duplicado. Medido: `node -e 'const g=require("./.forge/graph/graph.json"); …'` agrupando por `n.path` devolve `{ '': 256 }` e agrupando por `n.id` devolve `{bin:1, installer:1, template:135, tests:114, tools:5}`; `Object.keys(g.nodes[0])` é `['id','lang','loc','fingerprint','layer','summary']`.
2. **Piso medido, nunca literal exato:** o grafo regenerado tem **≥ 310 nodes** e **≥ 59 edges**, com todos os prefixos de `id` dentro do conjunto `{bin, installer, template, tests, tools}`. A contagem exata é proibida como asserção porque ela sobe a cada gate novo — o próprio gate desta fase leva `tests` de 150 para 151 — e transformaria [9] num gerador de vermelho fabricado em toda onda seguinte do plano.
3. **Contador de controle com contrapositiva:** o gate imprime `[9] N node(s) examinado(s), M sob .forge/` e **reprova quando N é 0**, porque um grafo vazio satisfaz "nenhum node sob `.forge/`" trivialmente.

**Regeneração, e por que o número commitado não serve.** O `.forge/graph/graph.json` rastreado está defasado: `generated_at 2026-09-04T19:53:54.648Z`, 256 nodes e 51 edges. Regenerando hoje contra a árvore de verdade:

```
$ node template/.forge/scripts/lib/graph-build.mjs "$PWD" --out "$TMPDIR/g"
OK .forge/graph/graph.json (310 nodes, 59 edges; 310 summaries stale)
   { bin: 1, installer: 1, template: 153, tests: 150, tools: 5 }   sob .forge/: 0
$ git status --porcelain    # inalterado — o --out impede que o gate suje a árvore
```

O `--out` para `$TMPDIR` é obrigatório: sem ele `graph-build.mjs` escreve em `<root>/.forge/graph` (linha 18) e o gate dirtifica o checkout de quem o roda.

**Vermelho hoje:** [9] passa hoje, e passa de propósito — é a asserção de não-regressão que fixa a decisão (b). Como ela nasce verde, ela **não** conta como prova de red-first: a prova dela é a mutação.

**A mutação de [9], em fixture sintética, e ela foi executada.** A ressalva do revisor procede: `graph-build.mjs` lê `<root>/.forge/FORGE.md` (`const root = resolve(process.argv[2] || '.')` na linha 16, `readForgeFrontmatter(root)` na 90), então mutar o `include_paths` da árvore real significaria escrever no arquivo rastreado que [5] e [6] existem para proteger. A saída é uma fixture mínima que reproduz o mecanismo inteiro sem tocar em nada:

```
$T/root/.forge/FORGE.md                       (frontmatter com include_paths: ["template/.forge/**"])
$T/root/template/.forge/scripts/{a,b}.sh
$T/root/.forge/scripts/{a,b}.sh               (as mesmas duas cópias, sob o diretório de ponto)

$ node template/.forge/scripts/lib/graph-build.mjs "$T/root" --out "$T/out1"
OK .forge/graph/graph.json (2 nodes, 0 edges)   nodes: [template/.forge/scripts/a.sh, template/.forge/scripts/b.sh]

# MUTAÇÃO: acrescenta ".forge/**" ao include_paths do FORGE.md da FIXTURE
$ node template/.forge/scripts/lib/graph-build.mjs "$T/root" --out "$T/out2"
OK .forge/graph/graph.json (4 nodes, 0 edges)   nodes: [.forge/scripts/a.sh, .forge/scripts/b.sh, template/.forge/scripts/a.sh, template/.forge/scripts/b.sh]
```

A mutação sobe o node count de 2 para 4 e faz aparecerem nodes com `id` sob `.forge/` — que é exatamente o que o item 1 do verde proíbe. **Reexecutei a matriz inteira nesta revisão**, com controle, mutação e recontrole na mesma bancada: controle `nodes=2 sob .forge/:0`, mutação `nodes=4 sob .forge/:2` com os ids `.forge/scripts/a.sh` e `.forge/scripts/b.sh`, e recontrole `nodes=2 sob .forge/:0` com o `FORGE.md` da fixture conferido por `shasum -a 256 -c` contra o gravado antes. A árvore real ficou intacta (`git status --porcelain` com as mesmas 13 linhas antes e depois). Recontrole: o `FORGE.md` da fixture volta ao conteúdo original, o sha256 é reconferido contra o gravado antes, e a regeneração tem de voltar a 2 nodes com zero sob `.forge/`. Nenhum arquivo rastreado é lido para escrita em nenhum ponto.

### 5.2 Onde entram PBT, contrato, integração e E2E

**PBT — APLICA-SE, e entra.** O invariante 5 do plano lista "serializador de manifesto" entre as superfícies que pedem propriedade, e `machinery.lock` é exatamente isso: `writeMachineryLock` (`bin/forge.mjs:378`) emite `"<sha256>  <rel>"` por linha e `readMachineryLock` (`bin/forge.mjs:360`) lê com `/^([0-9a-f]{64})  (.+)$/`. A propriedade: para qualquer conjunto de pares `(sha, rel)` gerado, `read(write(pares))` devolve o mesmo mapa e o contador `invalid` é zero.

A propriedade **não é vacuosa**, e isso foi medido antes de escrevê-la — reimplementei o par e passei nove classes de `rel` por ele:

```
OK    invalid=0  rel="normal/a.sh"
OK    invalid=0  rel=" com espaco inicial.sh"
OK    invalid=0  rel="dois  espacos.sh"
OK    invalid=0  rel="#comeca-com-hash.md"
OK    invalid=0  rel="acentuação/ação.md"
OK    invalid=0  rel="com\ttab.sh"
FALHA invalid=1  rel="quebra\nde-linha.sh"
OK    invalid=0  rel=".oculto/x.sh"
OK    invalid=0  rel="so espaco no fim .sh"
```

Existe falsificador real: um nome de arquivo com `\n` — legal em POSIX — quebra o round-trip e cai no fallback conservador de "preservar", que é uma **atualização silenciosamente pulada**. O gerador do PBT tem de incluir a classe que falha, senão a propriedade vira decoração. O harness já tem bancada de PBT (`tests/w121-pbt-harness-gate.sh`), e a propriedade entra lá ou no gate novo, à escolha do implementador, desde que o denominador seja declarado.

**Teste de contrato — APLICA-SE, e é a asserção [1].** `forge.schema.json` é fronteira publicada com adotante instalado. Validar o `forge.yaml` do template já é feito em outro gate; o que [1] acrescenta é a instância **deste** repositório, que é a que pode divergir quando alguém editar o bloco `runtime` da raiz à mão. Que a instância instalada valida está medido: `ajv/dist/2020.js` + `yaml` sobre `.forge/forge.yaml` do clone → `valida: true`.

**Teste de integração — APLICA-SE, e é a asserção [5].** O defeito de #101 e de #120 não é de função, é de fiação: `machineryFiles()` está correta e um teste unitário sobre ela nasceria verde sem dizer nada. [5] roda o binário de verdade, sobre uma cópia da árvore de verdade, e mede o efeito no disco.

**E2E — APLICA-SE, e NÃO é o gate: é o passo 3 do protocolo.** O E2E desta fase é instalar no clone descartável e rodar os 132 gates lá, comparando gate a gate contra o baseline. Isso não cabe num gate — seria um gate que roda a suíte inteira — e é o procedimento de aceite da onda, descrito na seção 7.

## 6. Retrocompatibilidade

**O que muda em `template/` e portanto chega a todo consumidor instalado: DUAS linhas.** A revisão 3 dizia "uma" e o bloqueador NOVO 1 mostrou que a decisão (f), como estava, bloqueava todo push — a segunda linha é o preço de corrigir isso na interface em vez de contorná-lo na declaração.

**Segunda linha: `check-suite-wiring.sh:31` passa a aceitar `--path` como alias de `--root`.** É aditiva por construção — uma flag nova é aceita, nenhuma flag existente muda de significado, e argumento de fato desconhecido continua saindo 2 com a mesma mensagem (medido na decisão (f), com controle e recontrole). A varredura da lição 2 foi refeita para a interface nova e nenhum gate cai: `tests/w146-suite-invocation-gate.sh:27` e `.github/workflows/ci.yml:74` invocam com `--root`, e a string `argumento desconhecido` não é afirmada por gate nenhum sobre este script. O efeito no consumidor é que `check-suite-wiring` passa a ser **declarável em `runtime.gates`**, o que hoje é impossível para qualquer consumidor — o `pre-push` invoca todo gate declarado com `--path` (`pre-push:450`) e este recusa.

**Primeira linha: a correção de `doctor.sh:114` acrescentando `ledger` e `liaison` a `USER_DATA`.** O efeito no consumidor é que o doctor deixa de flagrar placeholders `<PROJECT_*>` e refs `.claude/` dentro de `.forge/ledger/**` e `.forge/liaison/**`. Isso é estritamente menos ruído, não menos cobertura: os dois diretórios são dado de projeto, e o segundo é conteúdo escrito por **outro** repositório. O único caso que deixa de ser reportado é um consumidor com placeholder genuinamente não preenchido dentro de um arquivo de ledger ou de liaison — e um placeholder num corpo de mensagem de outro repositório nunca foi configuração deste. Entra no `CHANGELOG.md` e numa mensagem de liaison de tipo `note`, porque quatro repositórios do ecossistema rodam o doctor e vão ver o número mudar. O alias de `check-suite-wiring.sh` entra na mesma mensagem, porque ele **habilita** algo que hoje não é possível e os consumidores precisam saber que podem declarar o gate.

**O que muda em `.github/workflows/ci.yml`: NADA.** A revisão 2 acrescentava um passo de `forge update` antes da suíte; a revisão 3 o removeu inteiro (decisão (g), bloqueador NOVO 2), e nenhum outro passo entra no lugar. O gate novo roda pelo passo de suíte que já existe.

**O que muda em `template/` e NÃO chega a ninguém: nada mais.** As demais entregas são arquivos da raiz deste repositório e o gate novo em `tests/`, que não é distribuído.

**O que quebra neste repositório, e precisa de decisão antes de aplicar:**

1. **Hooks de git passam a existir.** `wireHooksPath()` (`bin/forge.mjs:227`) aponta `core.hooksPath` para `<raiz>/.forge/hooks/git`, em caminho absoluto. Hoje `git config core.hooksPath` devolve rc 1 (não configurado) e `.git/hooks/` só tem samples: **nenhum hook roda neste repositório hoje**. Depois da fase, `pre-commit`, `commit-msg`, `pre-push` e `post-merge` passam a rodar em todo commit e push, e o `core.hooksPath` é config do `.git/config` **comum**, compartilhado pelas worktrees desta rodada. Isso não é reversível por branch: é uma mudança de máquina, imediata, para todas as frentes em voo. A aplicação na árvore real (passo 5) só acontece com as ondas em voo cientes, e o passo 3 mede o custo de tempo de um `git push` com os hooks ativos, no clone, antes de a árvore real recebê-los.

2. **O `pre-push` NÃO bloqueia por acks pendentes — medido.** `check-liaison-acks.sh` roda no `pre-push:117` e bloqueia quando reprova. Executando-o hoje contra a raiz: `WARN liaison-acks — 22 thread(s) examinada(s), 40 mensagem(ns) exigem ack deste repositório (enforce: warn, não bloqueia)`, com `RC=0`. O modo é `warn` porque o `forge.yaml` do template declara `liaison.enforce: warn` (`template/.forge/forge.yaml:93`). Se alguém subir para `block` antes da Onda I, **todo push deste repositório fica bloqueado por 40 mensagens**. O número medido hoje é 40 e o plano-mestre fala em 37: a divergência é de data, e o contador de pronto da Onda I é o comando, não o plano.

3. **`secrets.enforce` passa de `warn` (default por ausência do bloco) para `block`.** `template/.forge/forge.yaml:107` declara `enforce: block`. É seguro aqui, e a segurança está medida nos dois lados: `1162` arquivos hoje e `1637` depois, zero achado nas duas medições.

4. **`.claude/settings.json` de projeto passa a existir e passa a ser RASTREADO** (decisão a), declarando um `PreToolUse` em `Bash` que aponta para `.forge/hooks/pre-tool-use/enforce-worktree-location.sh`. Um detalhe medido nesta revisão, que muda o que o passo 5 vê: o `.claude/` da raiz é um alvo móvel — no início desta sessão o `git status` reportava `?? .claude/` e agora ele contém só o diretório vazio `worktrees`, porque uma sessão de agente escreve e apaga `.claude/settings.local.json` ali. Esse arquivo é ignorado pelo bloco gerenciado (`installer/gitignore.patch:23`) e **não** pelo `.gitignore` de hoje, então até a instalação ele aparece como não rastreado e depois dela some do `git status`. O passo 5 confere o conteúdo de `.claude/` no momento em que roda, e não confia no retrato desta spec. Ele compõe com os hooks globais do usuário, não os substitui. O passo 3 do protocolo tem uma verificação nomeada para ele: rodar, dentro do clone instalado e com o hook ativo, ao menos um comando composto de shell a partir de uma worktree, e registrar a saída. Se o hook recusar algo que a rodada precisa, a decisão volta à mesa antes do passo 5 — mas ela volta com a recusa medida, não com receio.

5. **O bloco gerenciado do `.gitignore` declara ignorados CINCO padrões do grafo**, dos quais **três** correspondem a arquivos que este repositório versiona hoje. Medido: `installer/gitignore.patch` ignora `.forge/graph/graph.json`, `.forge/graph/report.md`, `.forge/graph/cache/fingerprints.json`, `.forge/graph/symbols.json` e `.forge/graph/module-deps.json`; `git ls-files .forge/graph` devolve `cache/fingerprints.json`, `cache/summaries.json`, `graph.json` e `report.md` — quatro arquivos, três deles cobertos pelo bloco (o `summaries.json`, que custa tokens, o bloco deliberadamente não ignora). Arquivo já rastreado não é afetado por `.gitignore`, então nada se perde agora.

**Decisão fechada, em vez da alternativa em aberto da revisão 1:** a fase acrescenta as três negações **fora** do bloco gerenciado, e isso funciona — medido, e a diferença em relação ao `machinery.lock` é justamente o que torna a medição necessária:

```
$ printf '.forge/graph/graph.json\n.forge/graph/report.md\n.forge/graph/cache/fingerprints.json\n…\n\n!.forge/graph/graph.json\n!.forge/graph/report.md\n!.forge/graph/cache/fingerprints.json\n' > .gitignore
$ for f in graph.json report.md cache/fingerprints.json cache/summaries.json; do printf '%s -> ' "$f"; git check-ignore -v ".forge/graph/$f" || echo "NAO IGNORADO"; done
graph.json -> .gitignore:8:!.forge/graph/graph.json
report.md -> .gitignore:9:!.forge/graph/report.md
cache/fingerprints.json -> .gitignore:10:!.forge/graph/cache/fingerprints.json
cache/summaries.json -> NAO IGNORADO
```

Os padrões do grafo são de **arquivo**, e o git reabre arquivo excluído por padrão de arquivo; o do `machinery.lock` é de **diretório** (`.forge/cache/`), e o git não reabre arquivo dentro de diretório excluído. As duas medições estão nesta spec porque a intuição de "negar depois do bloco" acerta num caso e erra no outro, e quem ler só uma delas vai generalizar errado.

O motivo de manter o grafo versionado é que ele é evidência para humanos aqui, e nenhum gate depende dele: `grep -nE '(\$WS|\$ROOT|"\$PWD"|\$\(pwd\))/\.forge' tests/*.sh` não devolve uma única leitura de `.forge/graph`. Fica registrado, como achado da fase e item de ledger próprio, que o artefato versionado está 54 nodes atrás da árvore (256 contra 310) — a Fase 1 **não** o regenera, porque regenerá-lo no mesmo commit tornaria impossível atribuir uma divergência à instalação.

6. **Duas premissas escritas em gates e comentários deixam de valer**, e a fase as corrige junto porque deixá-las é criar a mesma dívida da Fase 0: o comentário de `w139[15]` sobre herdar `warn`, e o cabeçalho de `tests/w158-doctor-placeholder-scope-gate.sh`, que afirma que *"no próprio forge-harness, cuja raiz do dogfood é parcial (sem scripts/) … a ÚNICA cópia executável de doctor.sh vive em template/.forge/scripts/doctor.sh"*. Depois da fase existem duas cópias executáveis. As asserções de `w158` rodam sobre fixtures em `$T` e continuam válidas; o texto, não.

## 7. O protocolo, executável

Os passos abaixo são para serem executados na ordem, com `git -C` explícito, sem `sleep` em foreground, e com a suíte serializada pelo orquestrador.

**Leia isto antes dos comandos.** Onde um comando aparece com `$` e saída colada, ele foi executado na redação desta revisão e a saída é a prova. Onde aparece uma **propriedade** com **contrafactual**, o primitivo é escolha do implementador, e a definição de pronto do passo exige que ele **prove a discriminação** — rodar o critério contra um controle negativo e observar que ele acusa. Essa distinção é o invariante 19, e ela não é formalidade: a varredura desta revisão executou os comandos que a revisão 3 prescrevia para o passo 2 e para o passo 3 e **eles aprovavam uma suíte vermelha**. Quatro prescrições mortas, três delas falso-verde perfeito, todas abaixo com a medição.

**Pré-condição, verificável por comando:** a Fase 0 fechou e `git -C "$WS" status --porcelain` está **vazio**. O passo 3 usa um clone, e um clone só reproduz a árvore quando não há trabalho não commitado. A revisão 3 escreveu aqui um retrato da árvore ("7 modificados e 5 não rastreados, então o protocolo não pode rodar hoje") e ele **venceu durante a própria revisão**: a Fase 0 foi commitada, HEAD passou de `49bc97d` para `c41eead`, `git ls-files` foi de 1167 para 1168 e agora `git status --porcelain` devolve 5 linhas, todas das specs desta rodada. O retrato sai; fica a pré-condição, que é um comando e não uma data.

### Passo 1 — inventário sha256, antes de qualquer escrita

```
WS=/Users/milton/Documents/projects/forge-harness
OUT="$WS/docs/plans/spikes/fase1-inventario-antes.txt"
( cd "$WS/.forge" && find . -type f ! -name '.DS_Store' -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 ) > "$OUT"
( cd "$WS/.forge" && find . -type l -print0 | LC_ALL=C sort -z | xargs -0 -I{} sh -c 'printf "%s -> %s\n" "{}" "$(readlink "{}")"' ) >> "$OUT"
# denominador DERIVADO no momento da execução, nunca literal: `.forge/liaison/**` e `.forge/specs/**`
# crescem sozinhos entre a redação desta spec e a execução dela (hoje 166 e 160 arquivos, store de
# liaison append-only), e um "esperado: 344" trocaria de valor sem defeito nenhum.
N_ARQ=$( cd "$WS/.forge" && find . -type f ! -name '.DS_Store' | wc -l | tr -d ' ' )
N_LNK=$( cd "$WS/.forge" && find . -type l | wc -l | tr -d ' ' )
[ "$(grep -c '' "$OUT")" -eq "$((N_ARQ + N_LNK))" ] || echo "FAIL: inventário não cobre a árvore no mesmo instante"
echo "inventário: $N_ARQ arquivo(s) + $N_LNK symlink(s)"   # testemunha de 2026-09-07: 344 + 1
```

**Este passo foi EXECUTADO nesta revisão**, contra a árvore real e com `OUT` apontando para `$TMPDIR` (nenhuma escrita no repositório), e ele reproduz:

```
$ ( cd "$WS/.forge" && find . -type f ! -name '.DS_Store' -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 ) > "$OUT"
$ ( cd "$WS/.forge" && find . -type l -print0 | LC_ALL=C sort -z | xargs -0 -I{} sh -c 'printf "%s -> %s\n" "{}" "$(readlink "{}")"' ) >> "$OUT"
$ echo "linhas=$(grep -c '' "$OUT")  N_ARQ=$N_ARQ  N_LNK=$N_LNK  soma=$((N_ARQ+N_LNK))"
linhas=345  N_ARQ=344  N_LNK=1  soma=345
$ tail -2 "$OUT"
492341bbfc92fe08e4192065884240cf0a71d76ce8e5c5b7ac550dd7571541a9  ./specs/archived/index.yaml
./contracts -> ../template/.forge/contracts
```

Sem erro em `stderr`, o denominador fecha, e a última linha mostra o symlink `contracts` capturado com o alvo — que é o objeto da decisão (e). O único ponto frágil deste passo, declarado em vez de contornado: a substituição `{}` do `xargs -I` é textual e um nome de arquivo com aspas a quebraria; a árvore de hoje não tem nenhum, e a **propriedade** que o passo cobra — o denominador de linhas igual a `N_ARQ + N_LNK`, derivado no mesmo instante — é justamente o que acusa se isso mudar.

**A exclusão de `.DS_Store` é escolha declarada, não completude.** Existe um `.forge/.DS_Store` de 6.148 bytes (`find .forge -name '.DS_Store' -exec ls -la {} \;`), ele é ignorado pelo `.gitignore` da raiz (linha 2) e pelo bloco gerenciado, nenhum comando do harness o lê e ele muda sozinho quando alguém abre a pasta no Finder — incluí-lo no inventário produziria divergência espúria entre o passo 1 e o passo 5. O plano-mestre pede "inventário byte a byte de TODO arquivo hoje sob `.forge/`", e esta é a única exceção, com o motivo escrito aqui.

O artefato fica no repositório, commitado no primeiro commit da onda, porque um inventário que só existe no `$TMPDIR` de quem o rodou não é evidência para mais ninguém.

### Passo 2 — baseline da suíte, verde, com contador nominal por gate

**A prescrição da revisão 3 para este passo estava MORTA, e a morte é a pior possível: ela aprova uma suíte vermelha.** Ela dizia:

```
cd "$WS" && bash tests/run-all.sh 2>&1 | tee "$BASE"
[ "$(grep -cE '^(PASS|FAIL) ' "$BASE")" -eq "$N_GATES" ] || echo "FAIL: a suíte não reportou veredito para todos os $N_GATES gates"
grep -c '^FAIL ' "$BASE"                   # exigido: 0
```

Ninguém tinha rodado. `tests/run-all.sh` **não imprime `PASS <gate>` nem `FAIL <gate>`** — ele imprime `  ✓ <nome>` / `  ✗ <nome>` com códigos ANSI colados no marcador (`run-all.sh:76,80`), uma linha-resumo `PASS=<n>  FAIL=<n>  SKIP=<n>` (`:107`) e, quando reprova, um bloco `FALHARAM:` com os nomes (`:109`). Montei em `$TMPDIR` duas saídas fiéis ao formato — uma verde e uma com um gate reprovado — e passei o critério prescrito pelas duas:

```
=== idioma prescrito, sobre a saída VERDE ===
  grep -cE '^(PASS|FAIL) ' => 0   (esperava N_GATES=3)
  grep -c '^FAIL '        => 0   (exigido: 0)
=== o MESMO idioma sobre a saída VERMELHA (um gate reprovou) ===
  grep -cE '^(PASS|FAIL) ' => 0
  grep -c '^FAIL '        => 0   (exigido: 0 -> SATISFEITO)
```

O contrafactual não muda o veredito: **um gate reprovado satisfaz `exigido: 0`**. E a primeira linha, que existia como contador de controle, dispara sempre — em `|| echo`, sem `exit`, ou seja imprime ruído que ninguém lê e nunca reprova.

**Dois defeitos independentes no mesmo bloco, os dois medidos.** Primeiro, o `| tee` descarta o rc do `run-all.sh`, que é o sinal mais barato que existe (`run-all.sh:110` sai 1 quando `fail != 0`):

```
$ bash ./falso.sh 2>&1 | tee saida.txt >/dev/null; echo $?    # falso.sh sai 1
0
$ bash ./falso.sh >saida.txt 2>&1; echo $?
1
```

É literalmente a lição de `feedback-suite-sem-concorrencia` — *rc de gate nunca via pipe* — violada pela própria especificação que a cita. Segundo, os três contadores de gate **não existem** na saída padrão: `run_one` só ecoa o log do gate quando `VERBOSE=1` (`run-all.sh:77`), e o baseline é gerado sem `-v`. As variáveis saem vazias, e a aritmética que depende delas degrada em silêncio:

```
$ /bin/bash -c 'SEC_DEPOIS=""; SEC_ANTES=""; echo "$((SEC_DEPOIS - SEC_ANTES))"'
0
$ /bin/bash -c 'SEC_DEPOIS=""; SEC_ANTES=""; NOVOS=475; NULOS=1; [ "$((SEC_DEPOIS - SEC_ANTES))" -eq "$((NOVOS - NULOS))" ] && echo "sem achado" || echo "ACHADO: ..."'
ACHADO: ...
```

Ou seja: o passo 3 imprimiria "ACHADO" em toda execução, por variável vazia, e o achado de verdade se perderia no ruído — o mesmo desfecho prático do falso-verde, por outro caminho.

**O que a especificação declara em lugar do bloco morto.**

- **Propriedade P1 — veredito por gate, nominal.** O baseline registra, para cada gate da suíte, o nome e o veredito, e o número de vereditos registrados é igual ao número de gates que a suíte declara ter executado. Zero veredito registrado reprova o passo.
- **Propriedade P2 — a suíte é verde e isso é lido de forma que um vermelho reprove.** O critério tem de considerar reprovado qualquer baseline em que exista ao menos um gate com veredito de falha, e o passo só fecha se o instrumento escolhido também **enxergar o rc** do runner.
- **Propriedade P3 — os contadores dos três gates da §2.2 são capturados do baseline, nunca comparados com literal.** Os números da §2.2 são testemunhas de data, não critério: `check-secrets` mediu 1162 na revisão 3 e mede **1163** hoje, sem defeito nenhum, só porque a Fase 0 foi commitada.
- **Contrafactual obrigatório, e ele é a definição de pronto do passo:** antes de confiar no critério, rode-o contra um baseline sintético com **um gate reprovado** e observe que ele **acusa**. Um critério que não distingue verde de vermelho num arquivo montado à mão não vai distinguir na suíte de verdade.
- **Duas restrições medidas que o implementador não precisa redescobrir:** o baseline exige `-v` para carregar os contadores dos gates, e o rc do runner não sobrevive a um pipe. Ambas com a medição colada acima.

O que sobrevive da revisão 3 sem mudança, porque já estava certo: **o denominador é derivado no instante da execução**, nunca literal — a própria onda acrescenta um gate a `tests/`, então `132` estaria errado no dia da execução.

```
BASE="$WS/docs/plans/spikes/fase1-baseline-suite.txt"
N_GATES=$(ls "$WS"/tests/*.sh | wc -l | tr -d ' ')     # derivado; testemunha de hoje: 132
cd "$WS" && bash tests/run-all.sh -v > "$BASE" 2>&1; RC_BASE=$?   # sem pipe: o rc é sinal, não ruído
# vereditos e contadores: propriedades P1/P2/P3, com o contrafactual do baseline vermelho provado antes
```

Testemunhas de 2026-09-07 para leitura humana, sem valor de critério: `nenhum segredo em 1163 arquivo(s) versionado(s)`, `1 runner(s) fiado(s) em 3 ponto(s) de entrada`, `heavy-mutex/universo — 230 arquivo(s)` — os três remedidos hoje com os scripts de produção, fora da suíte. O primeiro subiu de 1162 para 1163 em vinte e quatro horas, sem defeito nenhum, o que é a razão de ele não poder ser critério.

### Passo 3 — instalação em CLONE descartável, e comparação gate a gate

O plano-mestre pede "worktree descartável". **A letra é inexecutável e a razão está medida:** `updateHarness()` chama `mainCheckoutOf(target)` (`bin/forge.mjs:531`), que resolve `git -C "$target" rev-parse --path-format=absolute --git-common-dir` (`bin/forge.mjs:203-209`) — o critério é o **alvo**, não o cwd, então `--target <worktree>` a partir do checkout principal recusa igual. Reproduzido em repositório sintético:

```
$ git init main && (cd main && git commit --allow-empty -qm init && git worktree add ../wt)
$ mkdir -p wt/.forge && cp "$WS/template/.forge/forge.yaml" wt/.forge/
$ (cd main && node "$WS/bin/forge.mjs" update --dry-run --target ../wt)
FAIL (update rodado de dentro de um worktree linkado (…/wt). …)
RC=4
```

O veículo é um **clone independente**, que é checkout principal de si mesmo e passa o guard. Ele preserva a intenção do plano — instalar num descartável, nunca na árvore de trabalho — e é mais fiel que o worktree em dois pontos: tem `.git` próprio, então `core.hooksPath` e `git ls-files` não contaminam o repositório real, e reproduz o que um clone de CI vê.

```
CLONE=/tmp/forge-fase1-clone
rm -rf "$CLONE"
git clone --no-hardlinks "$WS" "$CLONE"
git -C "$CLONE" checkout fix/strix-achados-medios
git -C "$CLONE" rev-parse --short HEAD                       # tem de bater com o do $WS
```

Baseline dentro do clone, ANTES de instalar, para separar "diferença de clone" de "diferença de instalação":

**Aqui mora a segunda prescrição morta, e ela é o critério de aceite da fase inteira.** A revisão 3 escrevia `diff <(grep -E '^(PASS|FAIL) ' antes) <(grep -E '^(PASS|FAIL) ' depois)   # exigido: vazio`. Como nenhum dos dois lados casa coisa alguma na saída real do `run-all.sh` (medido acima), **os dois lados são vazios e o `diff` sai vazio sempre**:

```
$ diff <(grep -E '^(PASS|FAIL) ' verde.txt) <(grep -E '^(PASS|FAIL) ' vermelho.txt); echo "rc_diff=$?"
rc_diff=0
```

O contrafactual é o arquivo `vermelho.txt`, que tem um gate reprovado: a comparação gate a gate — o E2E desta fase, o item 3 do protocolo do plano-mestre — **aprovava**. Um `diff` cujos dois operandos são sempre vazios é a forma mais silenciosa possível de gate morto, porque a saída vazia é exatamente o sinal de sucesso esperado.

**Propriedade P4, em lugar do comando:** a comparação é entre os **pares (nome de gate, veredito)** do baseline e os do clone, e ela reprova quando qualquer gate muda de veredito, quando um gate desaparece de um dos lados e quando **qualquer dos dois lados tem zero par** — a contrapositiva sem a qual o defeito acima se repete com outro idioma. **Contrafactual obrigatório:** o implementador prova que o critério acusa introduzindo uma discordância artificial num dos lados antes de confiar nele.

**Primitivos que discriminam, medidos aqui para provar que a propriedade é alcançável** — o implementador escolhe, e a escolha não precisa ser nenhuma destas:

```
$ for f in verde.txt vermelho.txt; do printf '%s -> ' "$f"; grep -o 'PASS=[0-9]*  FAIL=[0-9]*  SKIP=[0-9]*' "$f"; done
verde.txt -> PASS=3  FAIL=0  SKIP=0
vermelho.txt -> PASS=2  FAIL=1  SKIP=0

$ for f in verde.txt vermelho.txt; do printf '%s -> FALHARAM=%s nomes=[%s]\n' "$f" "$(grep -c '^FALHARAM:' $f)" "$(sed -n '/^FALHARAM:/,$p' $f | sed -n 's/^  - //p' | tr '\n' ' ')"; done
verde.txt -> FALHARAM=0 nomes=[]
vermelho.txt -> FALHARAM=1 nomes=[w146-suite-invocation-gate.sh ]
```

**E uma armadilha que eu mesmo caí ao procurar o primitivo, registrada porque ela vai reaparecer:** parsear a linha `  ✓ <nome>` parece o caminho óbvio e é o mais frágil. O marcador vem colado ao código ANSI, sem espaço, e o `\x1b` de um `sed` de BSD não é escape reconhecido — a primeira tentativa minha classificou o gate REPROVADO como `PASS` e o `diff` saiu vazio de novo:

```
$ sed -n '3p' vermelho.txt | od -c | head -1
0000000          033   [   3   2   m   ✓  **  ** 033   [   0   m       w
```

A linha-resumo e o bloco `FALHARAM:` não têm ANSI e não têm multibyte. Quem escolher parsear o marcador tem de provar a discriminação, como qualquer outro primitivo.

```
cd "$CLONE" && bash tests/run-all.sh -v > /tmp/fase1-suite-clone-antes.txt 2>&1; RC_ANTES=$?
# comparação gate a gate pela propriedade P4, com o contrafactual provado antes de confiar nela
```

Instalação, com os placeholders resolvidos (seção 1.3 — `cp` cru deixa `<INSTALLED_AT>` órfão). Hoje `grep -n '<[A-Z_]*>' template/.forge/forge.yaml` devolve **só** a linha 4 (`installed_at`), e as outras duas substituições são defensivas para o dia em que o template ganhar mais um token; quem decide se sobrou algum é o `grep -q` da linha seguinte, não a lista de `s///`:

```
cd "$CLONE"
rm -f .forge/contracts && cp -R template/.forge/contracts .forge/contracts
cp template/.forge/forge.yaml .forge/forge.yaml
perl -pi -e 's/<INSTALLED_AT>/installed/g; s/<PROJECT_SLUG>/forge-harness/g; s/<PROJECT_NAME>/forge-harness/g' .forge/forge.yaml
grep -q '<[A-Z_]\+>' .forge/forge.yaml && { echo "FAIL: placeholder órfão em .forge/forge.yaml"; exit 1; }
node ./bin/forge.mjs update --no-plugin --no-backup
node ./bin/forge.mjs update --dry-run                        # exigido: rc 0, "0 mudança(s) de arquivo"
```

Reconferência do inventário e comparação da suíte. **A terceira prescrição morta está aqui, e ela guarda o critério de aceite que o plano-mestre escreve em letra — "`sha256` idênticos para os arquivos preexistentes".** O idioma da revisão 3 era `join -j2 -o 1.1,2.1,0` sobre os dois inventários, com `# exigido: vazio`. Ele detecta sha diferente, e eu confirmei que detecta:

```
$ LC_ALL=C join -j2 -o 1.1,2.1,0 <(LC_ALL=C sort -k2 a.txt) <(LC_ALL=C sort -k2 b.txt) | awk '$1!=$2{print "DIVERGE: "$3}'
DIVERGE: ./y/dois.md
```

Mas `join` só emite linha para as chaves que existem **nos dois lados**: um arquivo que estava no "antes" e sumiu no "depois" não forma par, não é comparado, e não aparece. Contrafactual executado — inventário "antes" com quatro arquivos, "depois" com três porque `FORGE.md` foi destruído, e nenhum sha divergente entre os que sobraram:

```
$ LC_ALL=C join -j2 -o 1.1,2.1,0 <(LC_ALL=C sort -k2 a3.txt) <(LC_ALL=C sort -k2 b3.txt) | awk '$1!=$2{print "DIVERGE: "$3}'
                                        # saiu VAZIO = VERDE, com um arquivo de instrução destruído
$ pares=3  antes=4  -> ACUSA: cobertura incompleta
```

A última linha é o recontrole e mostra a saída: **contar os pares formados e exigir que o número seja igual ao denominador do "antes"**. Com isso o arquivo apagado reprova, e a asserção deixa de ser "os que sobreviveram estão iguais" para ser "todos sobreviveram e estão iguais" — que é o que o plano-mestre pede e o que [5] guarda dentro do gate.

**Propriedade P5, em lugar do comando:** a reconferência é **bidirecional e com contador**. Todo path do inventário "antes" tem contraparte no "depois" com o mesmo sha256; nenhum path do "antes" desaparece; o número de comparações efetivamente realizadas é impresso e tem de ser igual ao denominador registrado no passo 1. **Contrafactual obrigatório:** o critério é exercido contra um inventário "depois" com um arquivo removido e um com um sha alterado, e tem de acusar os dois — o `join` cru acusa o segundo e aprova o primeiro.

```
( cd "$CLONE/.forge" && find . -type f ! -name '.DS_Store' -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 ) > /tmp/inv-depois.txt
# reconferência pela propriedade P5, com o contrafactual dos dois tipos de dano provado antes
git -C "$CLONE" add -A && git -C "$CLONE" -c core.hooksPath=/dev/null commit -qm "dogfood: instala o harness"
cd "$CLONE" && bash tests/run-all.sh -v > /tmp/fase1-suite-depois.txt 2>&1; RC_DEPOIS=$?
# comparação gate a gate: propriedade P4, mesmo critério e mesmo contrafactual do baseline
```

O `commit` antes da suíte não é higiene: `check-secrets.sh` opera sobre `git ls-files`, e sem o commit o contador de `w139[15]` mediria a árvore antiga.

A comparação de vereditos pela propriedade P4 tem de sair sem discordância, com contador não-zero dos dois lados. Os contadores mudam nos **três** gates previstos e **só** neles — e os `grep` abaixo só encontram o que procuram porque a suíte rodou com `-v` (medido no passo 2: sem `-v`, `run_one` não ecoa o log de gate que passou, e as variáveis saem vazias, degradando a aritmética para "ACHADO" em toda execução):

```
SEC_DEPOIS=$(grep -oE 'nenhum segredo em [0-9]+' /tmp/fase1-suite-depois.txt | grep -oE '[0-9]+')
HVY_DEPOIS=$(grep -oE 'heavy-mutex/universo — [0-9]+' /tmp/fase1-suite-depois.txt | grep -oE '[0-9]+')
# guarda de vacuidade das duas capturas: variável vazia é instrumento que não mediu, não delta zero
[ -n "$SEC_DEPOIS" ] && [ -n "$SEC_ANTES" ] || echo "NÃO-VERIFICADO: o baseline não carrega o contador do check-secrets (rodou sem -v?)"

# o critério é o DELTA derivado da própria instalação, não um alvo literal:
NOVOS=$(git -C "$CLONE" diff --name-only --diff-filter=A HEAD~1 HEAD | wc -l | tr -d ' ')
# detecção de byte nulo por `tr`, e NÃO por `grep -qU $'\x00'`: testei os dois idiomas e o do grep
# está quebrado nos dois sentidos — o bash não guarda NUL em string, o padrão chega VAZIO, e na
# medição ele casou o arquivo SEM nulo e não casou o que TEM (`lib/secret-scan.mjs`).
NULOS=$(git -C "$CLONE" diff --name-only --diff-filter=A HEAD~1 HEAD | while read -r f; do a=$(LC_ALL=C tr -d '\000' < "$CLONE/$f" | wc -c | tr -d ' '); b=$(wc -c < "$CLONE/$f" | tr -d ' '); [ "$a" -ne "$b" ] && echo "$f"; done | wc -l | tr -d ' ')
[ "$((SEC_DEPOIS - SEC_ANTES))" -eq "$((NOVOS - NULOS))" ] || echo "ACHADO: o universo do check-secrets não cresceu pelos arquivos que a instalação acrescentou"

NOVOS_SH=$(git -C "$CLONE" diff --name-only --diff-filter=A HEAD~1 HEAD | grep -cE '\.sh$|/(pre-push|pre-commit|post-merge|commit-msg)$')
[ "$((HVY_DEPOIS - HVY_ANTES))" -eq "$NOVOS_SH" ] || echo "ACHADO: o universo do heavy-mutex não cresceu pelos .sh que a instalação acrescentou"

# suite-wiring é estrutural, e a asserção é de PROPRIEDADE: o segundo runner passa a existir e é
# citado, e os pontos de entrada crescem exatamente pelos hooks instalados.
grep -q '\.forge/scripts/tests/run-all.sh invocado em' /tmp/fase1-suite-depois.txt || echo "ACHADO: o segundo runner não foi citado por ponto de entrada nenhum"
```

As testemunhas de 2026-09-07, medidas no clone instalado e registradas para leitura humana, são `1637`, `2 runner(s) / 7 ponto(s)` e `320` — mas quem reprova é o delta acima, não elas.

**Toda divergência de contador fora desses três é achado**, e o achado tem **três** saídas legítimas, não duas: ou o gate estava certo e a instalação precisa de ajuste; ou o gate estava medindo o universo errado e vira item próprio de ledger, com a medição; **ou o contador não é determinístico**, e essa é a saída que a revisão 2 não enumerava. O terceiro caso se distingue por medição, não por opinião: rodar o gate divergente duas vezes no MESMO commit do clone, sem tocar em nada entre as execuções. Se os dois números diferirem, o achado é de não-determinismo do gate — item de ledger próprio, e a comparação daquele gate entre antes e depois não conclui nada.

**Três medições operacionais fecham o passo, e as três são pré-requisito do passo 5. A primeira mudou de natureza nesta revisão: ela deixou de medir CUSTO e passou a cobrar VEREDITO.**

A revisão 3 mandava cronometrar `git push --dry-run` com os hooks ativos e não dizia o que o resultado tinha de ser — mas o bloqueador NOVO 1 mostrou que o push podia estar **bloqueado**, e um cronômetro não vê isso. Remedi o instrumento antes de reescrever o critério, em repositório sintético com remoto próprio e hook de eco:

```
$ git push --dry-run origin HEAD   2>&1 | grep -c 'PRE-PUSH EXECUTOU'     # 1  — dry-run EXECUTA o hook
$ git push -q      origin HEAD     2>&1 | grep -c 'PRE-PUSH EXECUTOU'     # 1
# contrafactual: o mesmo hook saindo 1
$ git push --dry-run origin HEAD:refs/heads/outro
PRE-PUSH BLOQUEIA
error: failed to push some refs to '…/remote.git'
RC=1
```

O `--dry-run` é o instrumento certo — ele roda o `pre-push` e propaga a reprovação —, e o passo agora tem critério:

- **DoD-1, veredito:** o `git push --dry-run` do clone instalado tem de **passar**, com rc 0. Se bloquear, o passo registra **qual check** bloqueou, lido da linha `pre-push BLOQUEADO: <label> falhou`, e a fase não avança para o passo 5 até o bloqueio estar entendido e resolvido. A lista real que o `pre-push` passa a rodar na raiz é `docs-reviewed`, `red-first`, `ai-attribution`, `liaison-acks`, `liaison-log-integrity`, `worktree-prereqs`, `runtime.gates`, `harness-tests` e `push-ahead` — o candidato conhecido a bloquear é o `runtime.gates` da decisão (f), que é a razão de o alias `--path` entrar na mesma onda.
- **DoD-2, custo:** três execuções cronometradas, com a carga registrada ao lado. Custo continua interessando; ele só deixou de ser o único critério.
- **DoD-3, os dois hooks que o passo 3 nunca exercitava.** O `commit` do clone usa `-c core.hooksPath=/dev/null` — deliberadamente, para que o commit da instalação não dispare hook nenhum —, e a consequência é que `pre-commit` e `commit-msg` saem do passo sem serem exercidos uma única vez, embora passem a rodar em toda a árvore real depois do passo 5. O passo passa a exercitá-los **em separado**, num commit descartável dentro do clone e com os hooks ativos, exigindo veredito e não só tempo. Duas medições já feitas adiantam parte do trabalho: `commit-msg` aceita as cinco últimas mensagens deste repositório com rc 0, e `.forge/scripts/tests/run-all.sh` sem teste nenhum sai 0 dizendo `0 arquivo(s) de teste examinado(s)`, ou seja não há vacuidade ali.

```
cd "$CLONE"
for i in 1 2 3; do /usr/bin/time -p git push --dry-run origin HEAD; done      # rc EXIGIDO: 0 nas três
# o hook de PreToolUse do .claude/settings.json, exercido de dentro de uma worktree do clone
bash "$CLONE/.forge/hooks/pre-tool-use/enforce-worktree-location.sh" < <fixture de entrada representativa>
```

### Passo 4 — descarte do clone

```
rm -rf "$CLONE"
```

Sem `git worktree remove` e sem `git worktree prune`: o clone não é worktree do repositório real e não deixa registro nele. É uma das razões de o clone ser mais seguro que o worktree aqui.

### Passo 5 — aplicação na árvore real, com reconferência

Só depois de o passo 3 fechar, e só com as ondas em voo cientes do item 1 da seção 6.

```
cd "$WS"
rm -f .forge/contracts && cp -R template/.forge/contracts .forge/contracts
cp template/.forge/forge.yaml .forge/forge.yaml
perl -pi -e 's/<INSTALLED_AT>/installed/g; s/<PROJECT_SLUG>/forge-harness/g; s/<PROJECT_NAME>/forge-harness/g' .forge/forge.yaml
node bin/forge.mjs update --no-plugin
( cd "$WS/.forge" && find . -type f ! -name '.DS_Store' -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 ) > /tmp/inv-real.txt
# reconferência pela propriedade P5 (bidirecional, com contador de comparações contra o denominador
# do passo 1) — NUNCA o `join` cru, que fica verde quando um arquivo de instrução é APAGADO
git -C "$WS" config --get core.hooksPath   # esperado: /Users/milton/Documents/projects/forge-harness/.forge/hooks/git
node bin/forge.mjs update --dry-run        # exigido: rc 0, "0 mudança(s) de arquivo"
```

O passo 5 é o lugar onde a propriedade P5 mais importa: é aqui que o critério de aceite do plano-mestre — *"reconferir os `sha256` do inventário e provar que os arquivos de instrução estão idênticos"* — é medido contra a árvore real, e é aqui que um `HANDOFF.md` destruído pela issue #120 apareceria. Com o `join` cru ele não apareceria: apareceria como saída vazia.

O `--no-plugin` é intencional aqui também: o plugin global é gerido por `npm run build:plugin` e pelo `plugin-sync-gate`, e um update que o reinstale por efeito colateral é ruído no diff.

### Passo 6 — o gate novo, red-first de verdade

O gate é escrito e observado **vermelho** ANTES do passo 5, contra a árvore real sem instalação, com as mensagens de falha da seção 5.1 registradas na saída. O vermelho é o do estado atual, não um vermelho montado: `[1]` falha porque o arquivo não existe, `[2]` porque o binário recusa com rc 3, `[3]` porque nem o lock nem `.forge/scripts/` existem, `[4a]` porque os 401 paths enumerados em HEAD não têm contraparte em `.forge/` e `[4b]` porque o universo da árvore é vazio contra o piso de 401 — dois rótulos distintos, medidos, `[5]` e `[6]` porque o canal não pôde ser observado, `[7]` porque `contracts` é symlink, `[8]` pelos arquivos que o doctor acusa no momento da execução. `[9]` nasce verde por desenho e a prova dela é a mutação em fixture, executada no mesmo passo. Antes de tudo, `/bin/bash -n` sobre o arquivo do gate, com o bash 3.2 do sistema.

## 8. O que a Fase 1 explicitamente NÃO faz

**Não corrige a issue #120.** `lib/handoff-render.mjs:70` continua reescrevendo `.forge/HANDOFF.md` incondicionalmente depois desta fase, e o `HANDOFF.md` da raiz — hoje 8.320 bytes — passa a ser alvo alcançável porque a maquinaria fica instalada. Isso é Onda A, e antecipá-lo aqui faria a Onda A nascer sobre um verde que ela não produziu. O que a fase faz é registrar a exposição em letra e pôr o arquivo no inventário do passo 1.

**Não corrige a issue #119.** O `pre-push` deste repositório passa a exercitar o caminho de `runtime.gates`, e a decisão (f) evita o falso-verde declarando gates de verdade. Mas a guarda de `pre-push:418` continua condicionada à forma do frontmatter em vez da disponibilidade do leitor, e isso é Onda D.

**Não corrige a issue #101.** `scripts` continua em `MACHINERY_DIRS` e fora de `ENRICHABLE_DIRS`. Aqui isso é o comportamento desejado (decisão c). #101 é Onda C, e a divisão do campo sobre rastrear ou não o `machinery.lock` (decisão g) entra lá como insumo medido.

**Não regenera `.forge/graph/graph.json`.** O artefato versionado está defasado (256 nodes contra 310 regenerados) e isso é achado registrado, não trabalho desta fase: regenerá-lo no mesmo commit tornaria impossível atribuir uma divergência de contador à instalação.

**Não declara `runtime.test`.** A razão está na decisão (f) e agora é medição, não teto: o CI leva entre 585 e 702 segundos nas dez últimas execuções.

**Não declara `check-authz`, `check-data-governance` nem `check-observability`.** Os três produziriam universo vazio a cada push neste repositório.

**Não acrescenta passo ao `ci.yml`.** A revisão 2 acrescentava um `forge update` antes da suíte, e a revisão 3 o removeu por tornar [4] e [1] infalsificáveis exatamente onde o repositório declara a autoridade (decisão (g)). O `ci.yml` sai desta fase como entrou.

**Não muda `installer/gitignore.patch`.** Rastrear o `machinery.lock` exigiria trocar `.forge/cache/` por `.forge/cache/*` no patch distribuído, o que muda o contrato de todo consumidor para acomodar este repositório (decisão g).

**Não roda o piloto do Strix, não toca o liaison e não responde ack nenhum.** São Onda I e decisão de produto do dono, e a Fase 1 muda o universo dos gates para todas as ondas seguintes: fazer qualquer outra coisa no mesmo commit tornaria impossível atribuir uma divergência de contador à instalação.

**Não altera o `template/.forge/FORGE.md` nem o `template/.forge/templates/FORGE.md`.** LDG-0161 mede que os dois divergem e que nenhum caminho gera um do outro; a fase escreve o `FORGE.md` da **raiz**, que é um terceiro arquivo.

## 9. Respostas ao veredito da revisão 1

Todo bloqueador foi remedido por comando próprio antes de aceito. Sete procedem e estão corrigidos por mudança de decisão, não de redação; nenhum foi adiado; e num deles a correção acionável proposta pelo revisor foi **refutada por medição** e substituída por outra.

### Bloqueador 1 — passo 3 inexecutável — PROCEDE, decisão trocada

Remedi em repositório sintético e o revisor está certo: `mainCheckoutOf(target)` (`bin/forge.mjs:531`, implementado em `:203-209`) resolve `git -C "$target" rev-parse --git-common-dir`, então o critério é o alvo e `--target <worktree>` recusa com `RC=4` mesmo rodando do checkout principal. A frase falsa da §7 foi removida e substituída pela descrição correta do guard, com o comando que a reproduz. O veículo passou a ser um **clone independente**, e eu o validei de ponta a ponta antes de escrevê-lo: o clone reproduz a recusa rc 3, aceita a instalação, e o `--dry-run` seguinte devolve `0 mudança(s) de arquivo` (seção 1.1). A §7 registra em letra que a palavra "worktree" do plano-mestre é inexecutável e por quê.

### Bloqueador 2 — [9] nasce vermelha por número de artefato defasado — PROCEDE, asserção trocada

Remedi: `.forge/graph/graph.json` commitado tem `generated_at 2026-09-04T19:53:54.648Z`, 256 nodes e 51 edges; regenerado hoje com `--out` para `$TMPDIR` dá **310 nodes e 59 edges**, `{template 153, tests 150, tools 5, bin 1, installer 1}`. O revisor reproduz exatamente. A asserção deixou de ser contagem exata e passou a ser **propriedade + piso**: zero nodes com `id` sob `.forge/`, `≥ 310` nodes e `≥ 59` edges, prefixos dentro do conjunto conhecido. Registrei também, na §8, que o artefato versionado está 54 nodes atrás e que a fase deliberadamente não o regenera.

### Bloqueador 3 — [9] consulta campo inexistente — PROCEDE, corrigido

Remedi: `Object.keys(g.nodes[0])` é `['id','lang','loc','fingerprint','layer','summary']`; agrupar por `n.path` devolve `{ '': 256 }` e por `n.id` devolve `{bin:1, installer:1, template:135, tests:114, tools:5}`. A asserção usa `id`. Acrescentei a contrapositiva que o revisor pediu: o gate imprime `N node(s) examinado(s)` e **reprova quando N é 0**, porque um grafo vazio satisfaz a propriedade trivialmente.

### Bloqueador 4 — `machinery.lock` é ignorado — PROCEDE no diagnóstico, CORREÇÃO ACIONÁVEL REFUTADA

Remedi o diagnóstico e ele procede, com uma correção de detalhe: `git check-ignore -v .forge/cache/machinery.lock` aponta `.gitignore:14`, não `:18`, e o padrão **já existe hoje** no `.gitignore` da raiz, antes de qualquer instalação — o bloco gerenciado apenas o repete.

**Mas a correção acionável do revisor não funciona, e isso não é opinião.** Ele propôs *"negar `!.forge/cache/machinery.lock` FORA do bloco gerenciado"*. Testei em repositório sintético os três arranjos e registrei a saída na decisão (g): com o padrão de **diretório** `.forge/cache/`, a negação posterior — dentro ou fora de bloco — é **ignorada pelo git**, que continua reportando `.gitignore:N:.forge/cache/` como a regra vencedora. Só funciona trocando o padrão por `.forge/cache/*`, o que significa editar `installer/gitignore.patch` e mudar o contrato de todo consumidor. Escolhi a segunda saída que o revisor ofereceu, e reforcei: `[3]` ganhou o terceiro estado explícito com código próprio e mensagem que nomeia o `.gitignore:14`, **e** o `ci.yml` ganhou um passo que aplica o update antes da suíte — passo cuja segurança foi medida (seção 1.2: sobre a árvore rastreada o update deixa `git status --porcelain` vazio e escreve só o arquivo ignorado). **[Correção da revisão 3: esse passo foi REMOVIDO. Ele era seguro para a árvore e destrutivo para as asserções — mascarava em silêncio o drift que [4] e [1] existem para detectar, no ambiente que o repositório chama de autoridade. Ver bloqueador NOVO 2, §10, e a decisão (g) reescrita. O que o passo materializava, o lock, passou a ser produzido pela bancada de [5].]** O argumento errado de 3(a) que o revisor apontou foi reescrito: o que distingue as duas alternativas não é o lock, é a asserção [4], que só existe se `.forge/` existir na árvore.

Acrescentei ainda um achado de campo que o revisor não tinha: dois dos três consumidores (`axis-fare-validator`, `azim-crm`) **rastreiam** o lock apesar do padrão, e o terceiro não — o ecossistema está dividido, e isso é insumo medido para a Onda C.

### Bloqueador 5 — censo não reproduz e omite `w151` — PROCEDE, censo e tabela refeitos

Remedi e confirmo: o grep citado devolve **2** arquivos (`w151`, `w204`), não 7. Substituí por um censo de dois passos que reproduz (§2.1) — primeiro os `check-*.sh` cujo alvo default é a raiz (11 arquivos), depois quais deles a suíte aponta para `$WS` (3 asserções, com número de linha). Confirmo também a segunda metade: `tests/w151-heavy-mutex-gate.sh:1338` varre `--path "$WS"`.

O número dele, porém, eu não aceitei sem medir, e ele está **incompleto**: o revisor previu ~318 somando 88 arquivos do `.forge` instalado; medido no clone com a instalação aplicada, o contador vai de **230 para 320**, porque o `.claude/` instalado também traz dois `.sh` (`.claude/skills/dotnet-quality-scan/scripts/scan.sh` e `.claude/skills/node-quality-scan/scripts/scan.sh`). `w151[46b]: 230 → 320` entrou na tabela de contadores previstos, no protocolo e no critério de aceite. Reconferi os demais gates que a spec declarava imunes, um a um e com linha citada: `w145:128,186`, `w159:147`, `w193:81`, `w20`, `plugin-sync`, `npx-pack` e `w204` — este último por execução (`gate-ordinal.sh next` devolve `w208` antes e depois, pelas duas cópias do script).

### Bloqueador 6 — destino de `.claude/` não decidido — PROCEDE, decidido em letra

Remedi o efeito numérico com `git check-ignore --stdin` sobre a lista completa dos 476 novos: apenas **1** é ignorado (`machinery.lock`), e não 5 como o revisor estimou — os outros 4 que ele contou (`publish.lock`, `graph.json`, `report.md`, `fingerprints.json`) são preexistentes, não novos. A decisão (a) agora cobre `.claude/`, `AGENTS.md`, `CLAUDE.md` e `.gitattributes`, todos **rastreados**, com censo dos três consumidores como base (os três rastreiam `.claude/`, `AGENTS.md` e `CLAUDE.md`) e com o argumento independente do `.gitattributes`, que carrega o `merge=union` do liaison e sem o qual `--ours`/`--theirs` destroem mensagens publicadas em silêncio.

A previsão de `w139[15]` deixou de ser previsão: medi os dois cenários por execução no clone, com `git add` e commit antes de cada um. Só `.forge/`: **1565**. Completo: **1637**. Nem os `~1563` da revisão 1 nem os `~1635` do revisor. O trabalho aberto da §6.4 (ler o `.claude/settings.json` antes de aplicar) virou passo nomeado do protocolo, com saída registrada e com a regra de que a decisão volta à mesa se o hook recusar algo que a rodada precisa.

### Bloqueador 7 — denominador de [4] é derivado — PROCEDE, piso literal fixado

Remedi por dois caminhos independentes: reimplementando `MACHINERY_DIRS` + `walk` + `adapters/*.yaml` + `README.md` sobre `template/.forge` (**401** pares, `{agents 48, capabilities 13, commands 57, contracts 5, hooks 13, schemas 28, scripts 136, skills 20, templates 21, rules 51, adapters 8, README.md 1}`), e contando o lock que o update real gerou no clone (`wc -l` → 403 linhas, das quais 2 de cabeçalho). Os dois batem em 401. O piso é literal no gate, com a justificativa do revisor escrita ao lado: `writeMachineryLock` é alimentado pela mesma enumeração, então um denominador derivado encolhe junto com o numerador e apagar metade de `scripts/` deixaria o gate verde.

### Bloqueador 8 — [1] transforma o bump em vermelho fabricado — PROCEDE, asserção trocada e dependência registrada

Remedi: `template_version` só é reescrito por `bumpTemplateVersion` (`bin/forge.mjs:392`, chamado em `:685`), que só roda dentro de `forge update` — confirmado no clone, onde o `.forge/forge.yaml` copiado do template saiu com `template_version: "0.14.0"`. Escolhi a segunda saída, com uma correção sobre a forma que o revisor propôs: "mesma major/minor" **também** fabrica vermelho, porque o bump de `0.14.0` para `0.15.0` muda a minor. A asserção é `template_version <= package.json.version` por comparação semver, com terceiro estado quando a versão não parseia. Registrei a dependência com a Onda J em item de ledger e no cabeçalho do gate, em vez de deixá-la na memória de quem fizer a release, porque o passo de CI da decisão (g) reescrevia `.forge/forge.yaml` quando as versões divergem e isso deixaria a árvore suja no runner de um push de release. **[Correção da revisão 3: o passo foi removido (§10, NOVO 2). A dependência com a Onda J continua, por outro caminho: [2] passa a NOMEAR a linha `~ forge.yaml (template_version)` do dry-run, sem reprovar por ela.]**

### Medições que não reproduziram — todas remedidas

- **§2.1, grep de censo:** confirmo, 2 arquivos. Substituído (bloqueador 5).
- **§2.1, `w151` "NÃO MUDA":** confirmo que muda. Número corrigido para 320, medido, não somado (bloqueador 5).
- **§2.2, universo do lint 226 → 299:** o revisor está certo de que 299 é falso e **errado no substituto**. Medido diretamente com `collectShellFiles` contra o clone instalado: **312**, não 310. Os 2 que faltam na conta dele são os `scan.sh` das skills do `.claude/`. Os quatro números de base (226 / 84 / 73 / 134) reproduzem, e a conclusão não muda: nenhum ponto de entrada roda o lint sem `--path`.
- **§3(b) e §5.1 [9], 256/51:** confirmo, artefato defasado. Corrigido para 310/59 regenerados, e a estabilidade foi verificada **também no clone instalado** (310/59, zero nodes sob `.forge/`), o que é a prova de que a decisão (b) se sustenta depois da instalação e não só antes dela.
- **§3(a), crescimento do corpus:** troquei os números somados à mão por medição de árvore inteira, com `git ls-tree -r -l` nos três commits: 1167 arquivos / 10.363.316 bytes antes, 1570 / 13.224.690 só com `.forge/`, 1642 / 14.078.628 completo. Em linhas de diff, 90.710 inserções e 1 deleção. Isso substitui tanto os `2.831.035 / 63.798 / 392` da revisão 1 quanto os `2.838.773 / 63.964 / 401` do revisor, porque os dois mediam só um subconjunto.
- **§6, item 5, "quatro arquivos":** confirmo o revisor. São **cinco** padrões no bloco e **três** dos quatro arquivos rastreados de `.forge/graph` cobertos por eles; `cache/summaries.json` não é ignorado, deliberadamente, porque custa tokens. Corrigido, e a decisão fechada com a medição de que a negação **funciona** aqui (padrão de arquivo) ao contrário do `machinery.lock` (padrão de diretório).
- **§7, passo 3, rc 4:** confirmo, reproduzido em repositório sintético próprio. Corrigido (bloqueador 1).

### Ressalvas — todas tratadas

- **Mutação de [9] não executável contra fixture:** procede, e a saída está na §5.1 [9]. Montei uma fixture mínima em `$T` com `.forge/FORGE.md` próprio e duas cópias dos mesmos dois `.sh`, **executei** a mutação, e ela sobe o node count de 2 para 4 fazendo aparecerem `id` sob `.forge/`. Nenhum arquivo rastreado é lido para escrita. A spec agora diz qual das duas saídas foi escolhida, que era o ponto da ressalva.
- **`--out` obrigatório:** acolhido e escrito como regra de higiene do gate inteiro (§5), com a citação de `w201:35,378`. Verifiquei na prática: regenerei o grafo duas vezes durante esta redação e `git status --porcelain` não mudou.
- **[4] torna `ENRICHABLE_DIRS` inutilizável:** acolhido, e virou cabeçalho obrigatório do gate na decisão (c), com a razão escrita — aqui a customização local em `rules/` e `agents/` é drift, porque a fonte mora na mesma árvore.
- **§6 item 5 em aberto:** fechado, com as duas medições de `git check-ignore` que mostram por que a negação funciona no grafo e não no lock.
- **Invariante 8 não citada:** acolhido. A §5 cobra `/bin/bash -n` com o bash do sistema (medido: `GNU bash, version 3.2.57(1)-release`) e proíbe nominalmente `declare -A`, `${var,,}`, `${var^^}`, `mapfile` e `readarray`.
- **`.DS_Store` excluído sem declarar:** acolhido. A exclusão está declarada como escolha na §7, com o arquivo medido (`.forge/.DS_Store`, 6.148 bytes) e o motivo: ignorado pelo git, não lido por nenhum comando do harness, e muda sozinho — incluí-lo produziria divergência espúria entre o passo 1 e o passo 5.
- **[1], [2], [3], [7] e [8] binárias:** acolhido. A §5 declara o vocabulário de três estados como obrigatório nas nove asserções, com a citação de LDG-0157, e cada uma das cinco ganhou o seu terceiro estado nomeado na §5.1 — em [3] ele é o centro da asserção, não um adorno.

### Um achado que a revisão 1 não tinha e a revisão não pediu

Copiar `template/.forge/forge.yaml` para a raiz — o comando que o próprio protocolo da revisão 1 mandava rodar — deixa `installed_at: "<INSTALLED_AT>"` órfão, porque quem substitui esse token é o `init` (`bin/forge.mjs:809`) e o `installer/install.sh:69`, não o `update`. O doctor não pega, porque procura só `<PROJECT_[A-Z_]*>` (`doctor.sh:119`), e o schema aceita porque o campo é string livre. Está na §1.3, o protocolo passou a substituí-lo, a asserção [1] passou a cobrá-lo, e entra no ledger com a medição.

## 10. Respostas ao veredito da revisão 2

Os dois bloqueadores novos procedem, e os dois foram remedidos por comando próprio antes de aceitos — nenhum foi refutado. Em NOVO 2, porém, a correção acionável do revisor entrou só em parte: ela resolve o mascaramento e não resolve os dois estados em que a asserção [3] simplesmente não pode ser observada, e por isso a saída escolhida é outra, com a dele adotada junto por mérito próprio.

### NOVO 1 — contador exato de 401 em [3] — PROCEDE, asserção trocada por piso mais cobertura

Remedi por dois caminhos antes de aceitar. Reimplementei `machineryFiles()` sobre `template/.forge` e contei **401** com a mesma distribuição que o revisor mediu (`agents 48, capabilities 13, commands 57, contracts 5, hooks 13, schemas 28, scripts 136, skills 20, templates 21, rules 51, adapters 8, README.md 1`); e rodei o update real numa bancada sob `$TMPDIR`, onde o **produto** imprime `maquinaria: 401 arquivo(s) de template aplicados` e o lock sai com 2 linhas de cabeçalho e 401 entradas. Conferi também a Onda K no plano-mestre (linhas 191-193): ela entrega `lib/deploy-common.sh`, `deploy.sh`, `lib/ci/github-actions.sh` e ao menos um segundo adaptador de provedor, todos sob `scripts` — a enumeração vai a 405 e a forma exata reprovaria com o gate certo e o produto certo.

A [3] foi reescrita: piso (`N >= 401`) mais **cobertura bidirecional por conjunto** (nenhuma entrada da enumeração ausente do lock, nenhuma entrada do lock fora da enumeração, sha de cada entrada igual ao de `template/.forge/<rel>`), com a enumeração derivada do produto — o gate lê `const MACHINERY_DIRS = [...]` de `bin/forge.mjs` por regex (medido: devolve os dez diretórios) em vez de reimplementar a lista. Corrigi de passagem um detalhe que a revisão 2 acertou por sorte: o cabeçalho do lock tem duas linhas, mas ganha uma **terceira** quando o update roda com `--source` (`bin/forge.mjs:384`), então contar `wc -l` menos dois é frágil e o gate conta linhas não-comentário.

### NOVO 2 — o passo de CI torna [4] e [1] infalsificáveis — PROCEDE, passo removido

Remedi no código antes de aceitar, e o achado é **mais forte** do que o veredito diz. O overlay copia todo path não-enriquecível sem perguntar (`bin/forge.mjs:614-633`, `cpSync` incondicional), `scripts` está em `MACHINERY_DIRS` e fora de `ENRICHABLE_DIRS` — até aí o veredito. O agravante que ele não menciona: o `WARN: drift local em <rel> sobrescrito pelo template` só é emitido quando existe lock anterior (`oldLock && oldLock.has(rel)`), e num clone limpo de CI **não existe lock nenhum** — a sobrescrita lá não deixa nem o aviso. O passo era, contra [4] e [1], exatamente o contorno que a revisão 2 negava ser.

A correção tem três partes e nenhuma delas é a de manter o passo. Primeira: **o passo saiu do `ci.yml`**, que volta a não mudar nesta fase. Segunda: **[4] e [1] ganharam raia sobre a árvore commitada** — [4a] compara OIDs de blob dentro de HEAD com um único `git ls-tree -r HEAD -- .forge template/.forge` (medido: 0,27s) e [1b] valida `git show HEAD:.forge/forge.yaml`; nada que rode antes do gate altera o que já está em HEAD, hoje ou no dia em que alguém reintroduzir um passo. É a saída (ii) do revisor, adotada não como remendo mas como a forma certa da asserção. Terceira, e é aqui que a correção dele não bastava: **[3] mudou de sujeito** e passou a examinar o lock que o update REAL escreve no alvo de bancada de [5], porque as duas outras saídas dele deixariam [3] em NÃO-VERIFICADO permanente nos dois ambientes que a rodada usa de fato — um clone limpo de CI, onde o lock é gitignorado por padrão de diretório, e um worktree linkado, onde o lock **nunca** pode existir porque o update recusa com rc 4 ali (medido em repositório sintético). A saída (iii), job separado, foi descartada por medição de efeito: ela move o mascaramento de lugar sem tornar [4] falsificável.

O que a fase perde está escrito na decisão (g), item 5, em vez de ficar implícito: o CI deixa de aplicar o update na árvore do runner, e o dogfood em CI passa a ser [5] (update real, binário real, cópia real da árvore, efeito medido no disco) mais [2] (`--dry-run`, que não escreve nada e não pode listar mudança em path de maquinaria).

### As quatro varreduras exigidas pela rodada, com o que cada uma achou

**1. Todo número literal em asserção ou definição de pronto.** Sete eram dívida e foram convertidos; dois são legítimos e ficaram. Legítimos: o denominador de cenários (`9`), fixo por construção; e o piso `401`, que só envelhece para baixo. Convertidos: o `exatamente 401` de [3] (piso mais cobertura); o `esperado: 344 linhas` do passo 1 (derivado por `find` no mesmo instante — `.forge/liaison/**` é append-only e cresce a cada sync, hoje 166 arquivos); o `denominador: 132` do passo 2 (derivado por `ls tests/*.sh`, e a própria onda acrescenta um gate); os contadores `1162`, `1 runner / 3 pontos` e `230` do passo 2, mais `1637`, `2 runners / 7 pontos` e `320` do passo 3 (capturados em variável, com o critério passando a ser o **delta** derivado dos arquivos que a instalação acrescenta — e a dívida já era real: `git ls-files` devolve **1167** hoje contra os 1162 que o `check-secrets` viu, porque cinco specs desta rodada ainda não estão rastreadas); e os `2 arquivo(s)` e `14 arquivo(s)` do vermelho de [8] (lidos da saída do doctor na execução, com a asserção cobrando a propriedade). O piso `≥ 310 nodes / ≥ 59 edges` de [9] ficou como está, com a razão dita: piso não fabrica vermelho quando a árvore cresce, e crescer é o que ela faz a cada onda.

**2. Toda string que esta onda muda em saída de produção.** **[Atualizado na revisão 4: a onda passou a mudar DUAS linhas de `template/`, e a varredura foi refeita para a segunda — ver §11, NOVO 1. A segunda linha não muda string nenhuma: ela acrescenta uma flag aceita. Medido que `w146:27` e `ci.yml:74` invocam com `--root` e que gate nenhum afirma a mensagem `argumento desconhecido` deste script.]** A onda muda **uma** string: a linha `USER_DATA` de `doctor.sh:114`, que ganha `ledger` e `liaison`. Ela não altera o texto impresso, e sim os contadores das duas linhas de veredito. Varri `tests/`, `.github/` e `template/.forge/hooks/` pelas quatro strings envolvidas (`placeholders <PROJECT`, `refs .claude/`, `fonte canônica sem refs`, `sem placeholders`) e achei quatro gates que as afirmam: `tests/w158-doctor-placeholder-scope-gate.sh`, `tests/w63-forge-update-gate.sh`, `tests/w106-red-first-gate.sh` e `tests/npx-pack-gate.sh`. Conferi um a um: os quatro afirmam a forma **positiva** (`sem placeholders`, `sem refs .claude`) ou injetam o placeholder num `FORGE.md` de fixture sob `$T` — nenhum monta fixture sob `.forge/ledger/**` ou `.forge/liaison/**` esperando acusação, que é o único caso em que a linha mais permissiva os derrubaria. Nenhum gate precisa ser editado junto, e nenhuma outra string de produção muda nesta onda (o texto do `FORGE.md` da raiz e os comentários de `w139` e `w158` não são saída de produção). O único gate que afirma o vocabulário de gate órfão, `w191-doctor-orphan-gate-gate.sh`, roda inteiramente sobre fixtures com `FORGE_ROOT="$T"` e não vê o `runtime.gates` que a decisão (f) acrescenta à raiz.

**3. Toda linha da matriz de mutação, executada numa cópia sob `$TMPDIR`.** A matriz de [6] estava **errada** e foi corrigida pelo que medi: a mutação não produz um efeito, produz três — a sobrescrita do `.forge/FORGE.md` do alvo (`b36a11d0…` → `65e4447d…`), o lock indo a 402 entradas com uma linha `FORGE.md`, e o update saindo com **rc 1** e `FAIL (1 arquivo(s) de maquinaria com placeholders <PROJECT_*> — template inválido?)`, porque o orphan-check pós-overlay (`bin/forge.mjs:645-651`) passa a ver o `FORGE.md` do template como maquinaria. Isso mudou a asserção: [6] cobra a mudança de sha, não o rc, senão estaria medindo o orphan-check. O recontrole também foi executado — binário restaurado com sha idêntico ao pristino (`ecb7c166…`), rc 0, `FORGE.md` de volta em `b36a11d0…`, lock de volta em 401. A mutação de [9] foi reexecutada com controle e recontrole (2 nodes / 0 sob `.forge/` → 4 / 2 → 2 / 0). E a armadilha de `feedback-mutacao-fantasma-restore` apareceu de verdade nesta redação: a primeira tentativa de mutar passou a variável de ambiente à direita do `node -e`, o `readFileSync` recebeu `undefined`, o arquivo não mudou e o `cmp` de controle imprimiu `IDENTICOS` — mutação fantasma detectada pelo controle. **[Correção da revisão 4: a conclusão que esta linha tirava — "e a razão de o gate passar caminho por `process.argv[2]`" — estava errada, e o bloqueador NOVO 2 da revisão 3 a derrubou por medição. Com `node -e` o caminho cai em `process.argv[1]`. A especificação parou de prescrever o primitivo e passou a cobrar o controle, que é o que pegou o defeito nas duas vezes. Ver §5.1 [6] e §11.]**

**4. Toda enumeração de desfechos, com o caso não coberto procurado ativamente.** Cinco enumerações tinham buraco. [2] não cobria **rc 4**, o guard de worktree — e é o desfecho mais provável desta rodada, porque toda a rodada trabalha em worktrees e o próprio harness instala um hook que os exige; medido em repositório sintético, com a detecção por `git rev-parse --git-dir` diferente de `--git-common-dir`. [4a] não cobria **HEAD inexistente**: `git ls-tree -r HEAD` num repositório sem commit sai **128** (medido), a mesma classe do achado que derrubou a enumeração "exaustiva" da rodada anterior. [7] não cobria `.forge/contracts` ser **arquivo comum**, que caía na linha da ausência. O passo 3 dizia "duas saídas legítimas e nenhuma terceira" para uma divergência de contador, e a terceira existe: **não-determinismo do gate**, distinguível por rodar o gate duas vezes no mesmo commit do clone. E [3] tinha três estados que pressupunham um lock no checkout — pressuposto falso em worktree linkado e em clone limpo, o que motivou a troca de sujeito da asserção.

### Achados novos desta revisão, que entram no ledger com a medição

- **`runtime.gates` em forma CSV declara zero gate para toda fase que não seja `source`** (medido com o leitor único do produto sobre fixture: `forge_runtime_gates_phase source` devolve os dois gates, `pre-deploy` devolve vazio). Como `run-gates.sh` só aplica a guarda de vacuidade quando `--phase` é pedido explicitamente, o primeiro `--phase pre-deploy` deste repositório vai reprovar por universo vazio — insumo medido para a Onda K, não defeito desta fase.
- **A bancada de `[5]`/`[6]` precisa do `package.json` copiado**: sem ele `pkgVersion()` cai no default e o update imprime `forge.yaml: template_version -> 0.0.0` (medido). Uma asserção de versão sobre a bancada nasceria falsa por isso.
- **O `.claude/` da raiz é alvo móvel**: uma sessão de agente escreve e apaga `.claude/settings.local.json`, que o bloco gerenciado ignora (`installer/gitignore.patch:23`) e o `.gitignore` de hoje não. O passo 5 confere o conteúdo no momento em que roda.
- **`grep -qU $'\x00'` não detecta byte nulo em bash**: o shell não guarda NUL em string, o padrão chega vazio, e na medição o idioma casou o arquivo SEM nulo e **não** casou o que tem (`template/.forge/scripts/lib/secret-scan.mjs`). O defeito era meu, apareceu na primeira escrita do passo 3 desta revisão e foi pego por teste antes de virar linha da spec; o protocolo usa comparação de tamanho por `tr -d '\000'`. Vale para qualquer gate futuro que precise separar binário de texto em shell.
- **Custo do gate novo**: três execuções de `forge update` de bancada, entre 60 e 130 segundos cada sob a carga registrada no cabeçalho desta spec. O gate entra na classe dos caros, e a §7 mede o custo numa máquina ociosa antes de a fase fechar.

## 11. Respostas ao veredito da revisão 3

Os dois bloqueadores novos **procedem**, os dois foram remedidos por comando próprio antes de aceitos, e nenhum foi refutado. Em NOVO 1, a correção acionável do revisor vinha em duas opções e a especificação escolheu a segunda, com a razão em letra. Em NOVO 2, a correção acionável do revisor — trocar `process.argv[2]` por `process.argv[1]` — foi **acolhida no diagnóstico e recusada como remédio**: pelo invariante 19 a especificação parou de prescrever o primitivo e passou a cobrar o controle, que é o que pegou o defeito nas duas vezes.

A revisão 3 acertou também no que o revisor confirmou por execução, e o crédito é dele: ele reproduziu a matriz de mutação de [6] inteira, o grafo em 310/59 com zero nodes sob `.forge/`, os 401 do lock com a distribuição exata, o `.gitignore:14`, a forma CSV de `runtime.gates`, o ordinal `w208` e o `check-liaison-acks` em WARN. Nenhum dos 31 + 15 bloqueadores das três primeiras rodadas reincidiu.

### NOVO 1 — a decisão (f) bloqueia todo `git push` deste repositório — PROCEDE, corrigido na interface

Remedi antes de aceitar e o revisor está inteiramente certo, inclusive no diagnóstico de que o defeito é a **chamada** e não o gate. Reproduzi a recusa literal (`FAIL suite-wiring — argumento desconhecido '--path' (use --root <dir>)`, rc 2), conferi no fonte que `pre-push:450` invoca todo gate declarado com `--path`, que `run_check` (`:204-221`) converte rc não-zero em `exit 1`, e que `gate_deps_ready` (`:193-201`) só pula comandos JS. A decisão (f) como estava punha o repositório num estado em que o primeiro push depois da Fase 1 falharia com o produto certo e a fiação certa.

**Escolhi a opção (ii) — o alias `--path` em `check-suite-wiring.sh` — e a razão não é conveniência local.** `check-secrets.sh:18` documenta `--path` como *"alias de `path`, para runtime.gates do pre-push"*: esse é o contrato de quem entra em `runtime.gates`, e um gate que não o honra **não é declarável por consumidor nenhum**. O gate em questão existe para detectar suíte entregue e nunca chamada; deixá-lo inalcançável seria o defeito que ele combate aplicado a ele mesmo. A opção (i) resolveria este repositório e deixaria o produto quebrado para os outros treze.

A correção foi **executada em bancada** com controle, aplicação e recontrole — `--root` rc 0, `--path` rc 0 com a mesma saída, `--nope` continuando rc 2 com a mensagem de argumento desconhecido —, e a saída está colada na decisão (f). Isso importa porque o recontrole é o que separa um alias de um `*) shift ;;`, o descarte silencioso que `w150:273` reprova nominalmente.

**As três consequências que o revisor pediu que ficassem em letra estão escritas.** A §6 deixou de dizer "uma linha em `template/`" e passou a dizer duas, com a segunda declarada aditiva e a varredura da lição 2 refeita (medido: `w146:27` e `ci.yml:74` usam `--root`; nenhum gate afirma a mensagem de argumento desconhecido deste script — exatamente o que o revisor adiantou, e eu confirmei por conta própria). A definição de pronto do passo 3 mudou junto: ela cobrava **custo** do `git push --dry-run` e agora cobra **veredito**, com rc 0 exigido e o check bloqueador nomeado quando houver. E remedi o instrumento antes de reescrever o critério — em repositório sintético, `git push --dry-run` executa o `pre-push` (o hook imprime nas duas execuções) e propaga a reprovação (`RC=1` com o hook saindo 1), então o passo já era o instrumento certo.

### NOVO 2 — a prescrição de mutação de [6] produz a mutação-fantasma que ela ensina a evitar — PROCEDE, e a correção é de método

Remedi e reproduzi exatamente: `node -e '<código>' <caminho>` põe o caminho em `process.argv[1]`, porque não existe arquivo de script para ocupar esse índice; com o mutador escrito como arquivo, o caminho volta para `process.argv[2]`. As duas saídas estão coladas na §5.1 [6]. O agravante que o revisor nomeia é o que mais pesou na correção: a prescrição errada estava no parágrafo que **ensinava** a evitar mutação-fantasma, que é a forma mais provável de ser copiada sem conferência.

**A correção acionável dele resolveria este caso e não a classe.** Trocar um token por outro deixaria a especificação prescrevendo um primitivo que ela continua sem executar no contexto real do gate. O que entrou foi o invariante 19: [6] passou a declarar a **propriedade** (a edição faz `machineryFiles()` enumerar `FORGE.md`) e o **contrafactual obrigatório** (o `cmp` acusa diferença ANTES de o update mutado rodar; enquanto ele imprimir "idênticos", nenhuma conclusão pode ser tirada), com as duas armadilhas nomeadas e medidas — o índice de `process.argv` e o `$` sem escape do `perl -0pi` de LDG-0164 — e com a prova de discriminação transferida para quem executa. A obrigação de controle e recontrole que o revisor manda preservar está preservada e agora é o **único** elemento não-negociável da passagem, que é o que ele mesmo observa: foi o controle que pegou o defeito nas duas vezes.

### As ressalvas de redação — cinco tratadas, uma adotada com medição, nenhuma ignorada

**"Exatamente dois" contradiz os pisos de [9] — corrigido.** A política agora diz "exatamente um literal EXATO (o denominador `9`) e os pisos declarados (`401`, `310`, `59`)", e a contagem concorda com a cláusula de escape que já existia.

**[4a] descrevia o mesmo estado por duas linhas — resolvido escolhendo o lado da enumeração.** A enumeração de [4a] passa a sair do lado **fonte dentro de HEAD** (`template/.forge/` em `HEAD`), o que responde a pergunta que o revisor fez e elimina o efeito colateral que ele previu: arquivo de maquinaria novo e não commitado não joga [4a] em NÃO-VERIFICADO, porque não existe em HEAD dos dois lados. Medido hoje em `c41eead`: 432 blobs sob `template/.forge`, **401** deles maquinaria, e **401** sem contraparte em `.forge/`. Com isso o universo de [4a] nunca é vazio num repositório que tem o produto commitado, o rótulo `universo-vazio` some desta raia, e ausência de contraparte vira `FAIL` seco — o instrumento funcionou, o objeto foi examinado e está errado. O revisor notou corretamente que nenhum dos dois desfechos saía 0 e portanto não havia falso-verde; o que havia era uma raia autoritativa que aprovaria por não ter olhado para nada se algum dia o rótulo mudasse, e agora ela tem contador não-zero por construção.

**[2] em NÃO-VERIFICADO permanente em worktree — ADOTADA, e a saída dele foi medida antes de entrar.** Reproduzi em repositório sintético: de dentro de um worktree linkado, `update --dry-run` sai **rc 4**, e `update --dry-run --target <checkout principal>` sai **rc 0**, porque `mainCheckoutOf(target)` julga o alvo. [2] passa a retargetar em vez de desistir, o terceiro estado encolhe para o que é de fato instrumento, e a asserção deixa de ser honesta-e-inútil. A saída está colada na §5.1 [2], com os `git rev-parse` que detectam o caso.

**A ordem entre [3] e [6] — fixada em letra.** [3] lê o lock do alvo **antes** de [6] mutar qualquer coisa, e a alternativa igualmente válida ([5] copiar o lock para fora do alvo ao terminar) está registrada. O revisor está certo de que a ordem importa: o update mutado reescreve o mesmo lock com 402 entradas, e [3] rodando depois reprovaria por excedente com o produto certo.

**As duas regras extras da enumeração derivada — declarado que a divergência É o achado.** `adapters/*.yaml` não-lock e `README.md` continuam reimplementadas, e a §5.1 [3] agora escreve por quê: a cobertura de [3] é bidirecional, então uma mudança em `machineryFiles()` que altere qualquer das duas aparece como entrada ausente ou excedente com o path nomeado. Derivá-las exigiria parsear a lógica do walk e não uma constante — trocaria uma dívida rara e barulhenta por um parser frágil e mudo.

**O passo 3 nunca exercitava `pre-commit` nem `commit-msg` — corrigido, com as duas medições dele acolhidas.** Virou DoD-3 do passo, com commit descartável dentro do clone e hooks ativos, exigindo veredito. As medições que ele adiantou (`commit-msg` aceita as cinco últimas mensagens com rc 0; `.forge/scripts/tests/run-all.sh` sem teste sai 0 dizendo `0 arquivo(s) de teste examinado(s)`, sem vacuidade) entraram no texto com crédito.

**A pré-condição da §7 já tinha vencido — o retrato saiu.** O revisor observou a Fase 0 sendo commitada durante a própria revisão. Reproduzi: HEAD é `c41eead`, `git ls-files` devolve **1168**, `git status --porcelain` devolve 5 linhas, todas de specs desta rodada. Ficou a pré-condição, que é um comando; saiu o retrato, que era uma data. E o mesmo fenômeno deu a testemunha mais econômica da política de derivar contadores: `check-secrets` mediu 1162 na revisão 3 e mede **1163** hoje.

### O que a MINHA varredura achou, e que nenhuma das três revisões tinha achado

Aplicar o invariante 19 à especificação inteira — executar todo comando prescrito em vez de reler — produziu **quatro prescrições mortas, todas no protocolo da §7, três delas falso-verde perfeito**. Elas não estavam no veredito de nenhuma rodada, e a mais grave guardava o critério de aceite da fase inteira.

1. **`grep -c '^FAIL ' "$BASE"  # exigido: 0` no passo 2 é sempre satisfeito.** `run-all.sh` não imprime `FAIL <gate>`; imprime `  ✗ <nome>` com ANSI. Medido com controle (baseline verde) e contrafactual (baseline com um gate reprovado): **os dois devolvem 0**. O contador de controle da linha anterior devolve 0 nos dois casos e, em `|| echo` sem `exit`, nunca reprova.

2. **O `diff` de vereditos do passo 3 compara dois conjuntos vazios.** É a comparação gate a gate — o E2E desta fase e o item 3 do protocolo do plano-mestre. Medido: `rc_diff=0` entre um baseline verde e um baseline com gate reprovado. Um `diff` cujos operandos são sempre vazios é a forma mais silenciosa de gate morto, porque saída vazia é o sinal de sucesso esperado.

3. **O `join -j2` dos passos 3 e 5 fica verde quando um arquivo é APAGADO.** `join` só emite linha para chave presente nos dois lados. Medido com controle (detecta sha alterado: `DIVERGE: ./y/dois.md`), contrafactual (`FORGE.md` removido do "depois", nenhum sha divergente entre os restantes → **saída vazia = verde**) e recontrole (contador de pares 3 contra denominador 4 → acusa). É o critério que guarda a frase do plano-mestre *"provar que os arquivos de instrução estão idênticos"* — e um `HANDOFF.md` destruído pela issue #120 passaria por ele.

4. **Os contadores dos três gates da §2.2 não existem na saída padrão da suíte.** `run_one` só ecoa o log de gate que passou quando `VERBOSE=1`. Sem `-v`, as variáveis saem vazias e `$((SEC_DEPOIS - SEC_ANTES))` degrada para 0 em bash — medido no `/bin/bash` 3.2 do sistema —, fazendo o passo 3 imprimir "ACHADO" em toda execução. Falso-verde não é, mas o efeito prático é o mesmo: ruído constante em que o achado de verdade se perde.

Dois defeitos menores saíram na mesma varredura: o `| tee` do passo 2 descarta o rc do `run-all.sh` (medido: 0 com pipe, 1 sem), que é a lição de `feedback-suite-sem-concorrencia` violada pela própria especificação que a cita; e parsear a linha `  ✓ <nome>` é a rota frágil — o marcador vem colado ao ANSI, o `\x1b` de um `sed` de BSD não é escape reconhecido, e **a minha primeira tentativa de primitivo classificou o gate reprovado como `PASS`**, com o `diff` saindo vazio de novo. Registro o erro em letra porque ele é a melhor demonstração da regra: quem escolher esse primitivo tem de provar a discriminação, e eu só descobri o defeito porque rodei o contrafactual.

**Resultado da varredura de comandos prescritos.** A especificação carregava **41 linhas de evidência com saída colada** (revisões 1 a 3, a maioria reproduzida pelo revisor), **60 linhas de comando prescritas no protocolo da §7** e **4 linhas de comando prescritas nas asserções da §5**, mais cerca de 26 primitivos citados inline em §5.1. Nesta rodada eu **executei 14 comandos novos** — o parser de `check-suite-wiring` com alias e três flags, `git push --dry-run` com hook de eco e hook que reprova, `process.argv` em `-e` e em arquivo, o inventário do passo 1 inteiro, o `join` em três cenários, o critério de suíte em dois baselines, a aritmética com variável vazia, o `| tee`, `shasum -c` em três estados, `--target` de worktree em dois modos, a enumeração de maquinaria em HEAD, `check-secrets` e `check-heavy-mutex` na árvore de hoje — e **converti 4 prescrições mortas em propriedade mais contrafactual** (P1/P2/P3 do passo 2, P4 da comparação de suíte, P5 da reconferência de inventário, e o veredito do push no DoD-1), mais **1 prescrição de primitivo em [6]** (a mutação) e **1 em [2]** (o retarget, que passou de desistência a propriedade). Nenhuma prescrição sobreviveu sem ter sido executada ou convertida.

### Achados novos desta revisão, que entram no ledger com a medição

- **`check-suite-wiring.sh` não é declarável em `runtime.gates` por nenhum consumidor**: o `pre-push` invoca com `--path` (`:450`) e o script só aceita `--root` (`:29-33`), devolvendo rc 2 e bloqueando o push. Medido, com o alias validado em bancada. É defeito de produto, não deste repositório, e a Fase 1 o corrige porque é a primeira a fiá-lo.
- **O critério de aceite da Fase 1, como escrito até a revisão 3, aprovava uma suíte vermelha.** Três idiomas independentes (`grep '^FAIL '`, `diff` de vereditos, `join` de inventário), todos medidos com controle e contrafactual. Entra no ledger como lição de método, não como defeito de código: nenhum dos três é bug de produto, os três são especificação prescrevendo comando que não rodou.
- **`run-all.sh` não expõe veredito por gate em formato estável**: o consumidor de saída é obrigado a parsear ANSI, ou a linha-resumo, ou o bloco `FALHARAM:`. É insumo para a Onda F (consolidação e varreduras): um `--porcelain` no runner tornaria toda comparação gate a gate trivial e falsificável, e três especificações desta rodada já pagaram por não ter um.
