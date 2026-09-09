# Onda L5 — red-first e a evidência que não acumula (especificação implementável)

Autor: especificador do subgrupo L5 da Onda L. Data da revisão 3: 2026-09-08. Base medida: branch `feat/fase1-dogfood-completo` do `forge-harness`, `package.json` em `0.14.0`, árvore `template/.forge/` do produtor.

Escopo: issue **#138** (o protocolo Red-first é escopado por `type: bugfix` no manifesto enquanto a norma que ele implementa é escopada por defeito corrigido) e issue **#139** (`/forge:red record` sobrescreve a evidência anterior em vez de acumular, de modo que um change com N defeitos só prova o Red de um). As duas fecham juntas porque a correção de uma sem a outra é inútil: destravar o autor de uma `feature` que corrige três defeitos sem lhe dar onde gravar três evidências entrega um instrumento que registra um terço do trabalho e chama isso de conformidade.

Esta especificação é para ser executada, não lida. **Toda afirmação numérica abaixo traz, ao lado dela, o comando que a produziu nesta revisão**, e as saídas coladas vieram de execução minha em 2026-09-08. Nenhum gate da suíte foi executado na elaboração — `feedback-suite-sem-concorrencia` registra que gate manual concorrente produz falha fantasma em gate alheio.

**Regra de método, e ela é a invariante 19 do plano-mestre.** A especificação declara a **propriedade** que precisa valer e o **contrafactual** que a mutação tem de produzir; quem escolhe o primitivo é o implementador, que executa, e ele prova que o primitivo discrimina, com controle e recontrole. Comando exato só permanece aqui quando veio de uma execução minha, com a saída colada. Onde eu montei bancada com a implementação futura aplicada, o §A no fim do documento traz o script da bancada inteiro, para que qualquer revisor possa refazê-la.

## 0. Resumo do que muda

| Peça | O que muda |
|---|---|
| `manifest.yaml` do change | ganha `fixes_defects`, uma **lista** de identificadores de defeito; declarar a lista liga o protocolo Red-first no change, qualquer que seja o `type` |
| `schemas/spec-manifest.schema.json` | ganha a propriedade `fixes_defects` (o schema é `additionalProperties: false` e é validado por ajv contra changes ativos reais) |
| `evidence/red/red-evidence.json` | ganha `entries`, uma lista com um registro por defeito; os escalares do topo passam a ser projeção da primeira entrada e o `status` do topo passa a ser **derivado** |
| `schemas/red-evidence.schema.json` | ganha `entries` (medido: hoje o schema estrito **reprova** um artefato que a carregue) |
| `lib/red-evidence.mjs` | ganha a normalização na leitura, a derivação do status, a redução de resolução sobre a lista e a **projeção do topo** (D19) |
| `lib/defect-scope.mjs` (**arquivo novo**) | o único ponto que responde "este manifesto declara defeitos corrigidos, e quais" — `fixesDefects`/`isDefectFixing` mais a CLI que os cinco leitores em shell consomem (D3) |
| `lib/red-evidence-ops.mjs` | `record` ganha `--id` e passa a ser **fail-closed** sobre entrada já declarada; `replay` ganha `--id`; `ensure` itera todas; `--id` recusa valor com forma de flag |
| `lib/check-red-first.mjs` | o predicado de aplicabilidade deixa de ser `type === 'bugfix'` e passa a ser `isDefectFixing(manifest)`, importado de `lib/defect-scope.mjs`; os itens 1 a 8 da rule passam a ser avaliados **por entrada** (D20); `waive` passa a ser por entrada; nasce a asserção de cobertura por defeito declarado, com contador no próprio texto |
| `red-evidence.sh` (duas guardas), `hooks/git/lib/check-red-first.sh`, `doctor.sh`, `spec-verify.sh`, `lib/validate-spec.mjs` | passam a consultar o mesmo predicado, pelo **leitor canônico** do manifesto, nunca por um `awk` novo |
| `rules/testing/regression-red-first.md`, `rules/testing/change-test-contract.md`, `commands/testing/red.md` | passam a dizer o que o instrumento faz; o comando é espelhado em `plugin/forge` por `npm run build:plugin` |
| Gate novo `tests/w<NNN>-red-defect-scope-gate.sh` | o vermelho desta onda, com contador de controle de denominador fixo e prova de mutação |
| `tests/w106-red-first-gate.sh`, `tests/w107-red-replay-gate.sh`, `tests/w144-gate-control-counter-gate.sh` | editados em três dimensões — strings de produção (§6.1), sequência de chamada de `record` (§6.2, **nove** sítios) e fixtures que escrevem o artefato à mão (§6.4, **três** dos dez sítios) —, todas com a lista nominal |

O que a onda **não** faz está em §8, e a lista é grande de propósito.

---

## 1. A régua desta onda — o que reproduzi e o que NÃO reproduziu

Os dois itens são medições de terceiro, feitas na árvore instalada de um consumidor. A primeira obrigação era reproduzir cada defeito aqui, no `template/`. O resultado tem quatro partes, e a primeira delas é sobre a própria ferramenta de medição.

### 1.0 A varredura de texto lê o universo? — o controle que precede toda afirmação de ausência

LDG-0177, medido pelo orquestrador em 2026-09-08, registra que `template/.forge/scripts/lib/secret-scan.mjs` é **invisível** a `grep` sem `-a`, porque carrega bytes de controle literais dentro de um literal de regex; o `file` o classifica como `data`. A consequência é que **varredura de texto que devolve vazio não prova ausência** — é a invariante 2 do plano-mestre (três estados, nunca dois) aplicada à ferramenta de medição. Reproduzi o achado:

```
$ cd /Users/milton/Documents/projects/forge-harness
$ grep -rn 'AKIA' template/.forge/scripts/lib/secret-scan.mjs ; echo "sem -a rc=$?"
sem -a rc=1
$ grep -arn 'AKIA' template/.forge/scripts/lib/secret-scan.mjs | cut -c1-60 ; echo "com -a rc=$?"
template/.forge/scripts/lib/secret-scan.mjs:13:  { name: 'AW
template/.forge/scripts/lib/secret-scan.mjs:118:// que menci
template/.forge/scripts/lib/secret-scan.mjs:123:  { name: 'A
com -a rc=0
```

Então **antes** de usar qualquer varredura como prova de ausência, medi quais arquivos do universo cada varredura consegue ler, comparando a lista com `-a` contra a lista sem `-a`:

```
$ for d in tests template; do
    echo "== $d/ — arquivos que SÓ o -a lê =="
    comm -13 <(grep -rl '' "$d" 2>/dev/null | sort) <(grep -arl '' "$d" | sort)
  done
== tests/ — arquivos que SÓ o -a lê ==
tests/.DS_Store
== template/ — arquivos que SÓ o -a lê ==
template/.DS_Store
template/.forge/scripts/lib/secret-scan.mjs
```

**Leitura desta medição, e ela vale para todo o documento.** Em `tests/` o único arquivo opaco sem `-a` é o `.DS_Store` do Finder, que não é gate — então as varreduras de §6 sobre `tests/` seriam sólidas mesmo sem `-a`, e ainda assim todas foram refeitas com `-a`. Em `template/` o `secret-scan.mjs` é opaco, e ele é maquinaria executável — qualquer afirmação de ausência sobre `template/` feita sem `-a` está errada por construção. **Todas as varreduras desta especificação usam `-a`**, e as que sustentam uma afirmação de ausência trazem, além disso, um **controle positivo plantado** que a varredura precisa achar. O §1.3 e a nota de D17 trazem os dois controles plantados desta onda.

Registro o que isso me obrigou a corrigir na revisão 1: a §3.2 afirmava que `grep -rln "red-evidence.schema.json"` devolvia "só `lib/red-evidence.mjs`". Sem escopo, ele devolve onze arquivos; a afirmação substantiva (nenhum **gate** valida o artefato contra o schema) é verdadeira, mas precisava do escopo e do controle, e agora tem os dois.

### 1.1 O que reproduz integralmente

Tudo que as duas issues descrevem sobre `record`, `init`, `replay`, `waive`, `check` e `status` reproduz no `template/` byte a byte, com as mesmas mensagens. As saídas estão em §2.1 e §3.1.

### 1.2 O que NÃO reproduz — o `pre-push`, e o que isso significa

O passo 7 da reprodução de #138 afirma que o hook de `pre-push`, alimentado com a faixa que contém os commits `fix(...)`, sai `rc=0` **sem nenhuma saída**. No `template/` isso é falso: o hook **bloqueia**.

Fixture: repositório git em `$TMPDIR` com `template/.forge/hooks/` e `template/.forge/scripts/` copiados, um único change ativo `type: feature`, e dois commits `fix(...)` na faixa empurrada. O script inteiro da bancada está em §A.1.

```
== hook pre-push ==
FAIL red-first/universo-vazio — 0 change(s) type:bugfix examinado(s) (changes ativos em .forge/specs/active, push com commit fix(...)): o gate não examinou nada.
      Universo vazio não é ausência de violação, é ausência de verificação — os dois não
      podem colapsar no mesmo verde. Confira o alvo, o glob e o range.
      Se o vazio for legítimo, declare em …/.forge/empty-universe-allowlist.txt: 'red-first  # motivo: <justificativa>'.
pre-push BLOQUEADO: red-first — há commit fix(...) sendo publicado e NENHUM change
  ativo type:bugfix foi examinado. Abra o change (/forge:spec new --type bugfix) e
  registre o Red com /forge:red record + replay, ou dispense com /forge:red waive.
rc=1
```

**A primeira causa da divergência está medida, e é defasagem da cópia instalada.** O consumidor onde a issue foi escrita roda `template_version: "0.1.0-rc24"` no worktree em que a reprodução aconteceu, e a cópia rc24 do hook não tem o contador de controle de universo:

```
$ A=~/Documents/projects/azim-crm/.forge/worktrees/platform-config-ux/.forge/hooks/git/lib/check-red-first.sh
$ T=~/Documents/projects/forge-harness/template/.forge/hooks/git/lib/check-red-first.sh
$ for pat in 'local examined=0 skipped=0 engaged=0' 'gate-universe.sh' 'forge_universe_check'; do
    printf '  %-42s rc24=%s template=%s\n' "$pat" "$(grep -ac -- "$pat" "$A" || true)" "$(grep -ac -- "$pat" "$T" || true)"
  done
  local examined=0 skipped=0 engaged=0       rc24=0 template=1
  gate-universe.sh                           rc24=0 template=2
  forge_universe_check                       rc24=0 template=1
$ ls -l "$A" "$T" | awk '{print $5, $9}'
5727 …/worktrees/platform-config-ux/.forge/hooks/git/lib/check-red-first.sh
8616 …/forge-harness/template/.forge/hooks/git/lib/check-red-first.sh
```

O `empty-universe-allowlist.txt` do consumidor está ausente na raiz e no worktree (`ls` sobre os dois caminhos devolve `AUSENTE` nos dois), então a diferença não vem de isenção declarada.

**E há um segundo motivo, que sobrevive à atualização e é o achado que importa.** Mesmo no template de hoje, o hook fica verde quando existe **qualquer** change ativo `type: bugfix` no repositório, ainda que ele não tenha relação nenhuma com os commits `fix(...)` empurrados. Medido de novo nesta revisão, com o mesmo fixture mais um `outro-bugfix` cuja evidência está `waived` e cujos `fix_files` não intersectam a faixa (script em §A.1):

```
== hook do TEMPLATE, feature com 2 commits fix(...) + 1 bugfix alheio com waiver ==
OK red-first/universo — 1 change(s) type:bugfix examinado(s) (changes ativos em .forge/specs/active, push com commit fix(...); 1 sem interseção com os fix_files declarados)
rc=0
```

Isso é pior que o silêncio que a issue relata, e a diferença é de qualidade e não de grau: o hook **imprime um contador que parece cobertura** — `1 change(s) type:bugfix examinado(s)` — enquanto os dois commits `fix(...)` publicados pertencem a um change que ninguém olhou. É a invariante 2 do plano-mestre pelo avesso: o gate não colapsou "não examinei" em verde, ele colapsou "examinei outra coisa" em verde, e o contador de controle assina embaixo.

O consumidor onde a issue nasceu tem **seis** changes ativos, **três** deles `type: bugfix`, então na árvore dele o desfecho seria este e não o `universo-vazio`, mesmo depois de atualizar:

```
$ cd ~/Documents/projects
$ ls -d azim-crm/.forge/specs/active/*/ | wc -l
       6
$ grep -al '^type: bugfix' azim-crm/.forge/specs/active/*/manifest.yaml | xargs -n1 dirname | xargs -n1 basename
account-enrichment-event-mapping
fix-grpc-baseline-drift
pipeline-stage-invariants
```

*(A revisão 1 dizia "sete changes ativos, dois deles type: bugfix". A contagem correta, medida acima, é seis e três.)*

**O que isso muda na correção.** O `pre-push` do template já detecta o sinal certo (`fix(...)` na faixa) e já cobra — o que falta não é detecção, é **como satisfazer a cobrança de dentro de um change que não é `bugfix`**. Isso derruba a Opção C da issue (derivar do commit `fix(...)`) como novidade: ela já está implementada. E redefine o alvo do denominador do hook, que é a decisão D5 abaixo.

### 1.3 O que NÃO reproduz — a norma que as duas issues citam como autoridade

As duas issues fundamentam a obrigação em `rules/testing/change-test-contract.md:19`:

> **3. Teste de regressão.** Todo defeito corrigido deixa para trás um teste que falha se ele voltar, exercitando o **fluxo real** em que apareceu — não uma unidade adjacente que ficou verde o tempo todo enquanto o sistema estava quebrado.

Essa frase **não existe no `template/`**, e a varredura que sustenta essa afirmação foi conferida contra um controle positivo plantado, porque varredura vazia não prova ausência (§1.0):

```
$ grep -arn "Todo defeito corrigido" template/ ; echo "rc=$?"
rc=1
$ P="${TMPDIR%/}/l5r2/ctrl2"; rm -rf "$P"; mkdir -p "$P"; cp -R template "$P/template"
$ printf 'Todo defeito corrigido deixa teste.\n' > "$P/template/CONTROLE.md"
$ grep -arln "Todo defeito corrigido" "$P/template"
/…/l5r2/ctrl2/template/CONTROLE.md
```

O controle acha o plantado no mesmo universo copiado; a varredura sobre a árvore real devolve vazio porque a frase de fato não está lá. O que o template diz na última linha do arquivo é o oposto do que a issue lhe atribui:

> Em change de tipo `bugfix`, este contrato é complementado por [`regression-red-first.md`](./regression-red-first.md): o teste de reprodução precisa ter sido observado falhando na árvore pré-correção, com evidência replicável.

O template é escopado por `type`, exatamente como o instrumento. Medi de onde vem a versão longa: `rules/` está em `ENRICHABLE_DIRS` (`bin/forge.mjs:352` — `const ENRICHABLE_DIRS = ['agents', 'rules', 'skills', 'templates'];`), e o consumidor `azim-crm` enriqueceu o arquivo localmente.

```
$ for r in forge-harness/template azim-crm axis-go-cloud axis-fare-validator lionclaw; do
    f=~/Documents/projects/$r/.forge/rules/testing/change-test-contract.md
    printf '  %-22s %s linhas | frase presente: %s\n' "$r" "$(wc -l < "$f" | tr -d ' ')" "$(grep -ac 'Todo defeito corrigido' "$f" || echo 0)"
  done
  forge-harness/template 21 linhas | frase presente: 0
  azim-crm               37 linhas | frase presente: 1
  axis-go-cloud          21 linhas | frase presente: 0
  axis-fare-validator    21 linhas | frase presente: 0
  lionclaw               19 linhas | frase presente: 0
```

Só o `azim-crm` enriqueceu; o `axis-go-cloud` e o `axis-fare-validator` continuam com as 21 linhas do template, e o `lionclaw` tem 19, que é uma versão anterior à do template atual. *(A revisão 1 dizia, em prosa, que "os outros três consumidores continuam com as 21 do template" enquanto a própria tabela mostrava 19 no lionclaw; a prosa estava errada e a tabela, certa.)*

**Consequência, e ela é a mais importante desta onda.** A contradição que #138 denuncia — norma escopada por defeito contra instrumento escopado por tipo — **não é um defeito do produto hoje**; é uma incoerência entre a norma local de um consumidor e o instrumento que ele recebeu. Isso não absolve o harness: o consumidor enriqueceu a rule porque a versão do template é fraca demais para o trabalho real dele, e a lacuna que ele nomeia é verdadeira em qualquer leitura. Mas muda três coisas na entrega:

1. A correção **não é só de código**. Enquanto `template/.forge/rules/testing/change-test-contract.md` não disser que a obrigação é por defeito corrigido, o produto continua entregando um instrumento coerente com uma norma fraca, e o consumidor continua tendo razão em enriquecer o arquivo por conta própria. A rule do template entra no escopo desta onda.
2. A citação de linha das duas issues **não deve ser copiada para a implementação**. `change-test-contract.md:19` no template é outra linha, sobre outro assunto. Implementador que ancorar mensagem de erro naquela referência publica um ponteiro falso para todo adotante.
3. O caminho de enriquecimento **funcionou como projetado** e isso é informação positiva: o consumidor conseguiu apertar a norma sem fork, e o update preservou o arquivo. O que não funcionou foi o instrumento acompanhar.

### 1.4 O censo — quantos changes o furo realmente alcança

O plano-mestre pede a medição: quantos changes arquivados são `type: feature` e corrigiram defeito, e quantos `type: bugfix` têm mais de um defeito. Medi neste repositório e nos consumidores cujas árvores de spec estão acessíveis, com dois critérios explícitos, cada um com o seu limite declarado e com o comando que o aplica.

**Critério A — `type: bugfix` com mais de um defeito:** o `bugfix.md` ou o `proposal.md` do change tem duas ou mais subseções `### 1.N`, que é o idioma que os repositórios usam para enumerar defeitos dentro de "§1 Comportamento atual (incorreto)". O critério subestima: um change que descreva dois defeitos em prosa corrida não é contado.

```
$ grep -ah '^### 1\.[0-9]' <dir-do-change>/bugfix.md <dir-do-change>/proposal.md 2>/dev/null | wc -l
```

**Critério B — change não-`bugfix` que corrige defeito:** o diretório do change tem, em algum `.md`, uma afirmação explícita de correção de defeito. A regex é a abaixo, e ela é declarada aqui porque a da revisão 1 era estreita demais e deixava passar `tinha três defeitos medidos`:

```
$ grep -arnoiE 'defeit[oa]s?[[:space:]]+(verificáve|medid|real|conhecid)|corrige o defeito' <dir-do-change>
```

O critério subestima muito mais que o A, porque a maior parte dos changes não declara isso em letra.

Resultado, com o repositório do produtor incluído. As oito linhas foram remedidas uma a uma nesta revisão:

| Achado | Change | Defeitos declarados | O que a evidência guarda |
|---|---|---|---|
| MULTI | `azim-crm/active/pipeline-stage-invariants` | 5 subseções `### 1.N`, quatro delas defeitos independentes | uma entrada, `status: pending`, e o `reproduces` descreve em prosa o defeito do §1.1 (`AddStage aceita um segundo estágio de categoria terminal…`) |
| MULTI | `axis-go-cloud/archived/2026-09-01-akua-hierarchy-wire-contract` | 4 (`### 1.1` a `### 1.4`) | uma entrada, `status: observed`, um único `test_id`, `reproduces: "bugfix.md#11-o-contrato-de-wire-esta-incompleto-em-quatro-campos"` — o change foi arquivado com 1 de 4 provado |
| MULTI | `axis-fare-validator/archived/2026-08-04-lists-parameters-refresh-integrity` | 2 (LDG-0206 e LDG-0205) | uma entrada, `status: waived`, e o `reproduces` do próprio waiver diz `bugfix.md §1.1` |
| FEATURE | `azim-crm/worktrees/platform-config-ux` | `proposal.md:13` diz `defeitos verificáveis`, `tasks.md:97` diz `os três defeitos` e `tasks.md:126` diz `os quatro defeitos` | nenhuma — não há `evidence/red/`, e o instrumento recusa o change |
| FEATURE | `axis-go-cloud/active/public-contract-code-conformance` | `proposal.md:7` e `:19` dizem `os dois defeitos` | nenhuma |
| FEATURE | `axis-go-cloud/archived/2026-08-05-pto-registration-party-role` | `tasks.md:37` diz `defeito real` | nenhuma |
| FEATURE | `axis-go-cloud/archived/2026-08-31-registry-navigation-consolidation` | `proposal.md:8` diz `tinha três defeitos medidos` | nenhuma |
| FEATURE | `axis-go-cloud/archived/2026-09-01-device-facing-mtls-hardening` | `stories/STORY-07.md:128` diz `defeito real` | nenhuma |

Os `type:` e a ausência de `evidence/red/` das cinco linhas FEATURE foram conferidos assim:

```
$ for d in <os cinco diretórios>; do echo "== $d"; grep -h '^type:' "$d/manifest.yaml"; ls "$d/evidence/red/" 2>/dev/null || echo "   (sem evidence/red)"; done
```

O caso do `axis-fare-validator` é o mais instrutivo dos três MULTI, e por isso está em letra: o waiver é `no-test-infra` com uma nota longa e honesta explicando que o Red **foi** observado antes do squash e que a infra de replay não sobrevive ao squash — e o campo `reproduces` do artefato diz `bugfix.md §1.1`. Quem escreveu sabia que estava falando de um defeito só. O artefato não tinha onde dizer o que aconteceu com o §1.2, e o gate aprovou o change inteiro.

**Neste repositório o furo de #139 não tem instância, e agora o critério A foi aplicado a cada um dos cinco:**

```
$ cd /Users/milton/Documents/projects/forge-harness
$ for m in .forge/specs/archived/*/manifest.yaml; do
    grep -q '^type: bugfix' "$m" || continue; d=$(dirname "$m")
    echo "$(basename "$d") -> subseções '### 1.N' = $(grep -h '^### 1\.[0-9]' "$d"/bugfix.md "$d"/proposal.md 2>/dev/null | wc -l | tr -d ' ')"
  done
2026-08-03-graph-bin-source -> subseções '### 1.N' = 0
2026-08-03-hookspath-respect-custom -> subseções '### 1.N' = 0
2026-08-03-red-replay-graft-base -> subseções '### 1.N' = 0
2026-08-03-tasks-meta-required -> subseções '### 1.N' = 0
2026-09-04-gate-assert-visibility -> subseções '### 1.N' = 0
```

Isso é registro honesto, não absolvição: significa que o gate desta onda não pode usar um change real deste repositório como fixture positivo, e por isso todos os cenários de §3.5 são herméticos, montados em `$TMPDIR`.

**A magnitude do lado de #138, medida por um proxy diferente e mais grosseiro.**

```
$ git log --format='%s' | grep -cE '^fix(\(|!|:)'          # 63
$ git log --oneline | wc -l                                 # 337
$ grep -al '^type: bugfix' .forge/specs/archived/*/manifest.yaml | wc -l   # 5
```

Os dois primeiros números não são comparáveis um a um com o terceiro — um change de bugfix carrega vários commits `fix(...)`, e `fix(build)`/`fix(lint)` inflam o numerador — e por isso não escrevo aqui nenhuma taxa derivada deles. O que o par sustenta é a direção: correção de defeito neste repositório acontece, em volume, fora de um change `type: bugfix`, e nada nesse volume passa pelo protocolo.

---

## 2. ITEM 1 — issue #138

### 2.1 O defeito, reproduzido no template

Bancada: `$TMPDIR/l5-bench/feat-root`, com `.forge/specs/active/platform-config-ux/manifest.yaml` contendo `type: feature`, e os scripts invocados diretamente de `template/.forge/scripts/` com `FORGE_ROOT` apontando para a bancada. Nenhum arquivo do repositório foi tocado. Script em §A.2.

```
== 1. tipo ==
type: feature
== 2. init ==
FAIL (init só se aplica a change type:bugfix, got: feature)
rc=1
--- red-evidence.sh record … ---
FAIL (red-evidence só se aplica a change type:bugfix, got: feature)
rc=1
--- red-evidence.sh replay … ---
FAIL (red-evidence só se aplica a change type:bugfix, got: feature)
rc=1
--- red-evidence.sh waive … --reason non-behavioral ---
FAIL (waive só se aplica a change type:bugfix, got: feature)
rc=1
--- check-red-first.sh check … ---
OK check-red-first (n/a — type: feature)
rc=0
--- check-red-first.sh status … ---
OK (n/a — type: feature)
rc=0
```

Os quatro subcomandos que **escrevem** recusam; os dois que **leem** declaram não-aplicabilidade e saem `0`. Reprodução idêntica à da issue, com uma diferença de endereço que o implementador precisa saber: as linhas citadas na issue são as da cópia rc24.

**Os sítios de aplicabilidade são ONZE, não nove.** A revisão 1 enumerou nove e a enumeração era falsamente exaustiva. A varredura corrigida, com `-a`, e a conferência de cada âncora por `sed -n <linha>p`:

```
$ grep -arnE '"bugfix"|= .bugfix.' template/.forge/scripts template/.forge/hooks
```

| # | Sítio | Linha medida | Papel |
|---|---|---|---|
| 1 | `template/.forge/scripts/red-evidence.sh:122` | `[ "$MTYPE" = "bugfix" ] \|\| { echo "FAIL (init só se aplica…` | guarda do `init` |
| 2 | `template/.forge/scripts/lib/red-evidence-ops.mjs:69` | `if (man.type !== 'bugfix') { … red-evidence só se aplica…` | `requireBugfix`, usado por `record`/`replay` |
| 3 | `template/.forge/scripts/lib/red-evidence-ops.mjs:219` | `if (man.type !== 'bugfix') { console.log('OK ensure (n/a…` | `cmdEnsure` |
| 4 | `template/.forge/scripts/lib/check-red-first.mjs:166` | `if (man.type !== 'bugfix') {` | `evaluateRedFirst` |
| 5 | `template/.forge/scripts/lib/check-red-first.mjs:350` | `if (man.type !== 'bugfix') { … OK (n/a — type: …` | `cmdStatus` |
| 6 | `template/.forge/scripts/lib/check-red-first.mjs:539` | `if (man.type !== 'bugfix') { … waive só se aplica…` | `cmdWaive` |
| 7 | `template/.forge/hooks/git/lib/check-red-first.sh:123` | `[ "$type" = "bugfix" ] \|\| continue` | laço do `pre-push` |
| 8 | `template/.forge/scripts/spec-verify.sh:118` | `if [ "$TYPE" = "bugfix" ]; then` | bloco red-first do `/forge:verify` |
| 9 | `template/.forge/scripts/lib/validate-spec.mjs:155` | `if (reached('verified') && man.type === 'bugfix') {` | transição para `verified` |
| **10** | `template/.forge/scripts/red-evidence.sh:66` | `[ "$type" = "bugfix" ] \|\| continue` | **laço do subcomando `ci`** — o braço que o `red-first.yml` do GitHub Actions executa |
| **11** | `template/.forge/scripts/doctor.sh:294` | `[ "$chtype" = "bugfix" ] \|\| continue` | **laço do `doctor`**, que relata evidência pendente |

Os dois últimos são os que faltavam, e a omissão era consequente: sem eles, a onda poderia fechar com todos os cenários verdes enquanto o `ci` — cuja autoridade a §8.5 declara ser "ser externo ao autor" — e o `doctor` continuassem escopados por `type`. Os dois entram em D1, na ordem de execução §9(7), e cada um ganha cenário próprio na matriz (`[21]` e `[22]`).

### 2.2 O artefato escrito à mão, e o WARN que descreve outro problema

Reproduzi o experimento da issue: mesmo diretório de change, mesmo `evidence/red/red-evidence.json` forjado, variando **apenas** o `type` do manifesto. A revisão 1 colou esta saída sem o script; ele está agora em §A.3, e o ponto que ele exige cuidado é que o galho do item 3d (`check-red-first.mjs:174-177`) só dispara quando `!errors.length`, então o `excerpt_sha256` do artefato forjado precisa ser o hash **real** do `excerpt` — foi por não fazer isso que o revisor não repetiu a medição.

```
$ bash bench-A3.sh          # o script inteiro está em §A.3
== type: feature ==
rc=0
WARN (change tem evidência de Red gravada (status: observed) mas type mudou para 'feature' — a política red-first foi desligada por essa mudança; confirme que a recategorização é legítima (item 3d, rule testing/regression-red-first.md))
== type: bugfix ==
rc=1
fatal: not a git repository (or any of the parent directories): .git
CONFLICT (excerpt classifica como 'unknown' via red-classify — não é comportamental, independente do campo 'classification' declarado ('behavioral') (item 3, rule testing/regression-red-first.md); excerpt não casa com o failure_pattern declarado ('AssertionError') (item 4, rule testing/regression-red-first.md))
```

*(A linha `fatal: not a git repository` é ruído da bancada — `red-classify` consulta o git e a bancada de §A.3 não tem repositório —, e não muda o veredito. Ela está colada porque a saída é a que a execução produziu, e omitir uma linha porque ela é inconveniente é o hábito que esta rodada está tentando desfazer.)*

A evidência forjada que o gate reprova num `bugfix` passa num `feature` sem avaliação alguma, e o `WARN` afirma um fato falso — o change sempre foi `feature`, nada "mudou para". A frase existe porque o galho de `lib/check-red-first.mjs:166` foi escrito pensando só na recategorização `bugfix → refactor`, e ele é o único galho que sobra quando o `type` não é `bugfix`.

### 2.3 Decisões de desenho — FECHADAS

**D1. O predicado de aplicabilidade passa a ser `isDefectFixing(manifest)`, num único lugar, e ele é `type === 'bugfix' || o manifesto declara defeitos corrigidos`.**

A raiz é o predicado errado, não o fato de ele estar em onze lugares — a issue está certa nisso. O conserto é um predicado exportado e compartilhado, consumido pelos **onze** sítios da tabela de §2.1, `ci` e `doctor` incluídos.

*Alternativa descartada — a Opção A da issue sozinha (relaxar só os escritores, manter a cobrança em `bugfix`).* Medi por que ela não serve: com o predicado de `evaluateRedFirst` intocado, o artefato que o autor diligente gravasse continuaria com `applicable: false`, ou seja, gravado e nunca lido, e o `WARN` de item 3d passaria a disparar num change que nunca mudou de tipo. Destrava metade do problema e, na metade destravada, entrega um artefato que nenhum gate avalia — que é o mesmo estado de hoje com mais passos.

*Alternativa descartada — a Opção C da issue (derivar do commit `fix(...)`).* Medida em §1.2: o `pre-push` do template **já** deriva desse sinal e **já** bloqueia. A opção não é uma proposta nova, é a descrição do comportamento atual; e o sinal é da faixa de push, portanto inútil para `/forge:verify` e para a transição a `verified`, que não têm faixa.

**D2. A declaração é `fixes_defects`, e ela é uma LISTA de identificadores, nunca um booleano.**

Um booleano responde "este change corrige defeito?" e é tudo que #138 sozinha pediria. Uma lista responde "**quais** defeitos", e é o que torna a cobertura de #139 verificável: o instrumento passa a poder dizer `1/2 defeito(s) declarado(s) com Red resolvido — sem prova: branding-save`. Os identificadores da lista são os mesmos `entries[].id` da evidência (§3), e é essa igualdade que faz as duas issues fecharem com um contrato só em vez de dois.

Medi que o leitor canônico do manifesto já lê a forma, nas duas sintaxes YAML e na forma inválida:

```
$ node --input-type=module -e "
import { parseYamlSubset } from '…/template/.forge/scripts/lib/yaml-lite.mjs';
import { readFileSync } from 'node:fs';
const m = parseYamlSubset(readFileSync('<arquivo>','utf8'));
console.log(JSON.stringify(m.fixes_defects) + '  (' + (Array.isArray(m.fixes_defects) ? 'array' : typeof m.fixes_defects) + ')');"

  block-sequence -> ["branding-preview-vars","branding-save-silent"]  (array)
  flow-sequence  -> ["branding-preview-vars","branding-save-silent"]  (array)
  fixes_defects: true -> true  (boolean)
```

`parseYamlSubset` devolve array para a block-sequence e para a flow-sequence, e devolve `true` booleano quando a chave recebe `true`. A forma booleana **não** é aceita: o schema declara `type: array` e o leitor trata qualquer coisa que não seja lista de strings não vazias como **erro de declaração**, terceiro estado, nunca como ausência. Aceitar as duas formas criaria dois vocabulários para o mesmo fato — o defeito que `check-push-ahead.sh:166` já registra ter recusado a cometer.

*Alternativa descartada — reusar `ledger_origin` transformado em lista.* O campo existe, é `^LDG-[0-9]{4}$` e só é preenchido por `/forge:spec new --from-ledger`. Amarrá-lo obrigaria todo defeito a ter entrada no ledger antes de existir teste, o que é uma exigência de processo que esta onda não tem mandato para criar, e quebraria os consumidores que usam o campo como está. `fixes_defects` pode **referenciar** um `LDG-NNNN` como identificador quando o autor quiser — a lista é de strings, não de ids do ledger.

**D3. Os sítios em shell consultam o leitor canônico do manifesto; nenhum deles inventa uma segunda regra de extração. São CINCO leitores em shell, não dois.**

A revisão 1 dizia que o idioma `awk` do `type` existia em dois sítios em shell. Medi e são seis leitores, dos quais cinco são red-first:

```
$ grep -arn 'awk -F.: . .\$1=="type"' template/.forge/scripts template/.forge/hooks | sed 's/^\(.*:[0-9]*\):.*/\1/'
template/.forge/scripts/spec-verify.sh:33
template/.forge/scripts/red-evidence.sh:65
template/.forge/scripts/red-evidence.sh:121
template/.forge/scripts/doctor.sh:293
template/.forge/scripts/spec-transition.sh:44
template/.forge/hooks/git/lib/check-red-first.sh:122
```

`spec-transition.sh:44` não é red-first; os outros cinco são. E há **dois idiomas distintos**, o que agrava o ponto: `red-evidence.sh` usa `awk -F': ' '$1=="type"{gsub(/[" ]/,"",$2); print $2; exit}'` (com `gsub`) e os demais usam a forma sem `gsub`. Medi o que o idioma devolve para a chave nova:

```
$ awk -F': ' '$1=="fixes_defects"{print $2; exit}' manifesto-block.yaml
                                                       # (vazio)
$ awk -F': ' '$1=="fixes_defects"{print $2; exit}' manifesto-flow.yaml
[branding-preview-vars, branding-save-silent]
```

Duas respostas diferentes para o mesmo conteúdo semântico, e a primeira delas é indistinguível de "a chave não existe" — que é exatamente o modo de falha que a lição de `project-strix-pentest-profile` registra: leitor novo de um arquivo que já tem leitor canônico **herda** a regra de extração, não a reinventa. A propriedade é: existe **um** ponto no repositório que responde "este manifesto declara defeitos corrigidos, e quais", e todo consumidor — shell ou JS — passa por ele. Na bancada esse ponto é um arquivo novo, `lib/defect-scope.mjs`, cujo fonte inteiro está em §A.4; ele exporta `fixesDefects(man)` (três estados: declara / não declara / **declaração inválida**) e `isDefectFixing(man)`, e traz uma CLI (`node lib/defect-scope.mjs <change-dir>` → `yes`/`no` mais os ids, `rc=2` para declaração inválida) que é o que os cinco leitores em shell consomem. O arquivo separado, e não uma exportação a mais em `check-red-first.mjs`, é o que evita o ciclo de import com `red-evidence-ops.mjs`, que também precisa do predicado — medido na bancada, onde `node --check` reprova o ciclo. O primitivo continua sendo escolha do implementador; o que a onda exige é o ponto único.

**D4. Change que não declara nada continua `n/a`, sem `WARN`, e isso preserva `w106[9]`.**

A cobrança é por auto-declaração, e a rule já assume isso: a seção "O limite desta norma" diz em letra que a calibragem é contra **descuido**, não contra autor adversarial. Um campo que o autor esquece de marcar é o mesmo descuido que hoje já passa; um campo que ele marca é ganho líquido. Medido na bancada com o predicado aplicado (§A.4), com controle, mutação e recontrole:

```
=== CONTROLE — A: feature COM fixes_defects, SEM evidencia | B: feature SEM o campo (fixture de w106[9]) ===
  A: applicable=true rc=1 | evidence/red/red-evidence.json ausente — change type:bugfix sem evidên…
  B: applicable=false rc=0 | OK check-red-first (n/a — type: feature)
```

O controle B é a fixture literal de `tests/w106-red-first-gate.sh:507-514`, que cria `feat-a --type feature` e exige `rc=0` mais a substring `n/a` (`tests/w106-red-first-gate.sh:513`, conferida por `sed -n 513p`). Ela sobrevive sem edição.

O controle A expõe, de quebra, uma mensagem que a onda **tem** de corrigir: ela diz `change type:bugfix sem evidência de Red` sobre um change que é `feature`. É a asserção do cenário `[4]`.

**D5. O denominador do contador de controle do `pre-push` passa a ser "change ativo que o predicado alcança", a mensagem de bloqueio deixa de mandar o autor abrir um change `bugfix`, e o contador passa a NOMEAR os changes examinados.**

É a correção do achado de §1.2, e a terceira metade dela — nomear — é a correção do bloqueador 4 da revisão 1. Medi que a saída de hoje **não** nomeia change nenhum no caminho positivo, lendo o código e depois a saída:

```
$ sed -n 156p template/.forge/hooks/git/lib/check-red-first.sh
    if ! forge_universe_check "red-first" "$examined" "change(s) type:bugfix" "$scope" "$REPO"; then
```

`forge_universe_check` só recebe contagem e string de escopo (`template/.forge/scripts/lib/gate-universe.sh:54-65`), e quem nomeia o change é a linha de BLOQUEIO (`:138`), que por construção não é impressa quando `rc=0`. A bancada de §A.1 confirma:

```
OK red-first/universo — 1 change(s) type:bugfix examinado(s) (changes ativos em .forge/specs/active, push com commit fix(...); 1 sem interseção com os fix_files declarados)
rc=0
```

Sem uma decisão, `[7]` — o par positivo — seria vermelho contra a implementação correta. Então D5 decide **três** coisas: o `scope` ganha a lista dos ids examinados; o rótulo do item deixa de citar `type:bugfix`; e o sub-relato `N sem interseção com os fix_files declarados` passa a falar da **união** dos `fix_files` de **todas** as entradas do change, e a dizer isso em letra. A terceira parte fecha uma ressalva da revisão 2: com a projeção de D19, o `fix_files` do topo é o da PRIMEIRA entrada, então o sub-relato de hoje falaria de um subconjunto sem avisar — um change com dois defeitos cujo segundo toca o arquivo empurrado seria contado como "sem interseção". Medido na bancada com D5 aplicado (script inteiro em §A.5):

```
=== CONTROLE — [7] (uma entrada observed, internamente consistente) ===
OK red-first/universo — 1 change(s) que corrigem defeito examinado(s) (changes ativos em .forge/specs/active, push com commit fix(...); examinados: pcx)
  rc=0
=== CONTROLE — [6] (declara defeito, SEM evidência) ===
pre-push BLOQUEADO: red-first pendente em 'pcx' (commit fix(...) detectado em 'refs/heads/develop').
  CONFLICT (evidence/red/red-evidence.json ausente — change que corrige defeito sem evidência de Red (item 1, rule testing/regression-red-first.md) — escaffolde com 'red-evidence.sh init pcx' e grave com /forge:red record + replay, ou dispense com /forge:red waive --reason <motivo>; 0/1 defeito(s) declarado(s) com Red resolvido — sem prova: branding-preview-vars (item 1, rule testing/regression-red-first.md))
  grave a observação com /forge:red record + /forge:red replay, ou dispense com /forge:red waive --reason <motivo>.
  rc=1
```

*(Um erro de bancada meu, registrado porque quase virou uma medição falsa: a primeira montagem escreveu `change_id:` no `manifest.yaml`, e a chave real é `id:` — `head -5 .forge/specs/archived/2026-09-04-gate-assert-visibility/manifest.yaml` devolve `id: gate-assert-visibility`. O sintoma foi a mensagem `escaffolde com 'red-evidence.sh init undefined'`, que eu quase colei como se fosse defeito do produto. Refeito com a chave certa, a mensagem nomeia `pcx`.)*

**Este é o ponto da onda que muda uma string afirmada por gate existente, e a varredura está em §6.1.** O texto `change(s) type:bugfix examinado(s)` é afirmado literalmente por `tests/w107-red-replay-gate.sh:273` e por `tests/w144-gate-control-counter-gate.sh:76`. Os dois entram na definição de pronto.

*O que D5 explicitamente NÃO resolve:* o `pre-push` continua sem saber, quando existe um `bugfix` alheio ativo, que os commits `fix(...)` da faixa pertencem a outro change. Corrigir isso exigiria casar commit com change, que não é um problema desta onda e não tem sinal disponível hoje. O que D5 entrega é que o change `feature` que declara defeitos **entra no denominador** e é **nomeado**, então o caso medido em §1.2 deixa de existir para quem declara. Para quem não declara, o furo permanece, e ele está nomeado em §8.

**D6. O `WARN` de item 3d muda de texto sem perder a substring que `w106[17]` afirma.**

Hoje a mensagem afirma que o `type` mudou, e §2.2 mede que isso é falso quando o change sempre foi `feature`. O texto novo precisa oferecer as duas leituras sem afirmar nenhuma — "há evidência gravada e a política não se aplica a este change; confirme se o `type` mudou depois do `record` ou se falta declarar `fixes_defects`" — e a propriedade é que ele continue contendo a substring `type mudou`, porque `tests/w106-red-first-gate.sh:974` faz `grep -qi "type mudou"` (conferido por `sed -n 974p`). Escrito assim, `w106[17]` fica verde sem edição e a mensagem para de mentir. Se o implementador preferir um texto que não contenha a substring, a edição do `w106[17]` entra na mesma entrega e na definição de pronto — as duas saídas são aceitáveis, a omissão não é.

**D7. `init` é a porta para o change que adquire a declaração depois, e `spec-new.sh` não ganha flag nova.**

O caso realista é o do `platform-config-ux`: os defeitos foram descobertos **durante** o redesenho, não na criação do change. `red-evidence.sh init` já existe exatamente para isso — o cabeçalho do arquivo o descreve como a saída de brownfield para um change existente que nunca teve o scaffold — e com D1 ele passa a aceitar o change que declara defeitos. `spec-new.sh` fica intocado: acrescentar `--fixes` ali resolveria só o caso em que o autor já sabe de tudo na criação, que é o caso raro, ao custo de mais uma superfície de flag na classe de #103.

**D8. `verification.schema.json` deixa de dizer que `red_first` só é populado para `type: bugfix`.**

Mudança de `description` apenas. Varri `tests/` pela frase `só populado para change` e por `red_first`, com `-a`:

```
$ grep -arn -F 'só populado para change' tests/   # nenhum resultado
$ grep -arn -F 'red_first' tests/
tests/w192-declared-switch-has-reader-gate.sh:176
```

A única ocorrência é uma regex de recorte que casa o nome da chave, não a descrição. Nenhuma edição de gate decorre desta.

**D9. As rules do template passam a enunciar a obrigação por defeito corrigido.**

É a consequência de §1.3. `template/.forge/rules/testing/change-test-contract.md` ganha, no lugar onde hoje diz "Em change de tipo `bugfix`, este contrato é complementado por…", a formulação por defeito: todo defeito corrigido deixa teste de regressão, e o protocolo Red-first se aplica ao change que os corrige, qualquer que seja o `type`, quando ele os declara. `template/.forge/rules/testing/regression-red-first.md` ganha o parágrafo correspondente na seção "Verificação" e a menção a `fixes_defects` na seção "Quando o Red não é possível". `template/.forge/commands/testing/red.md:10` deixa de dizer "Vale só para changes `type: bugfix`", e as linhas `:21` e `:25` do mesmo arquivo, que repetem o escopo por tipo, acompanham.

**Consequência obrigatória de propagação:** `template/.forge/commands/testing/red.md` tem espelho em `plugin/forge/commands/red.md`, e medi que hoje eles são byte a byte idênticos (`cmp -s plugin/forge/commands/red.md template/.forge/commands/testing/red.md` sai `0`). A regeneração é por `npm run build:plugin`, **nunca** por `build-plugin.sh`, que instala em `$HOME`. Sem isso o `plugin-sync-gate` reprova.

### 2.4 O VERMELHO de #138, antes do verde

O gate novo é `tests/w<NNN>-red-defect-scope-gate.sh`. O ordinal é alocado pelo orquestrador no momento de escrever o arquivo, conferido contra `origin/*` **e** contra as branches em voo desta rodada — é a invariante 10, e LDG-0167/LDG-0173 registram o pedágio já pago duas vezes.

Todas as fixtures são herméticas, em `$TMPDIR`, com `cwd` **dentro** da fixture. Nenhum cenário escreve em `.forge/` do repositório real: `on-session-end.sh` resolve a raiz pelo `cwd` e ignora `FORGE_ROOT`, e §1.4 mede que este repositório não tem change real que sirva de fixture positiva.

| # | Cenário | Estado da fixture | Asserção | Vermelho de hoje | Por que falha por ausência real |
|---|---|---|---|---|---|
| [1] | `init` num change que declara defeitos | change `type: feature` com `fixes_defects` de dois ids (`branding-preview-vars`, `branding-save-silent`), sem `evidence/red/` | `rc = 0`; `evidence/red/red-evidence.json` criado com `status: pending`; e — asserção que fecha o §8 item 10 — o artefato nasce com **duas** entradas, cujos ids são, **na ordem**, os dois de `fixes_defects`, e **nenhuma** delas se chama `default` | `FAIL (init só se aplica a change type:bugfix, got: feature)`, rc=1 | a guarda de `red-evidence.sh:122` compara `type` com a string `bugfix` |
| [2] | `record` sem `--id` no mesmo change, no scaffold recém-escaffoldado | idem, com o scaffold de `[1]` já criado (duas entradas, nenhuma declarada) | `rc = 0`; a declaração é gravada na **primeira entrada escaffoldada**, cujo id é o **primeiro** de `fixes_defects` (`branding-preview-vars`); nenhuma terceira entrada é criada; e a linha `OK record` **nomeia o id em que gravou** | `FAIL (red-evidence só se aplica a change type:bugfix, got: feature)`, rc=1 | `requireBugfix` em `lib/red-evidence-ops.mjs:69` |
| [2b] | `record` sem `--id` num change que declara defeito e cujo scaffold é **legado** | change `type: bugfix` **sem** `fixes_defects`, com o scaffold do template (`templates/bugfix/red-evidence.json`, que não tem `entries`) | `rc = 0` e a declaração gravada na entrada sintetizada `default` | — | **não falha por ausência** — é o caminho de hoje, e existe para provar que `default` continua sendo o id quando não há id declarado. É o cenário que sustenta o `--id default` dos nove sítios de §6.2 |
| [3] | `waive` no mesmo change, **com `--id`** | idem, depois de `[2]` (duas entradas, uma declarada) | `rc = 0`; o waiver é gravado **na entrada nomeada** com a política do motivo reaplicada; a outra entrada não é tocada; e o `deriveStatus` do topo passa a refletir o pior status presente | `FAIL (waive só se aplica a change type:bugfix, got: feature)`, rc=1 | `lib/check-red-first.mjs:539` |
| [3b] | `waive` **sem** `--id` com duas entradas | idem | `rc ≠ 0`, mensagem que nomeia as duas entradas e pede o `--id`, e o artefato **byte-idêntico** ao anterior | — | nasce com D14; sem a exigência, o comando escolheria uma das duas sem critério, e o waiver de um defeito acabaria no outro |
| [4] | `check` num change que declara defeitos e não tem evidência | `type: feature`, `fixes_defects` com dois ids, sem `evidence/red/` | `rc = 1`, saída com `CONFLICT`, e a mensagem **não** afirma `type:bugfix` sobre um change que é `feature` | `OK check-red-first (n/a — type: feature)`, rc=0 | `evaluateRedFirst` devolve `applicable: false` em `lib/check-red-first.mjs:166` |
| [5] | CONTROLE NEGATIVO — `check` num change `feature` **sem** a declaração | `type: feature`, sem `fixes_defects` | `rc = 0` e a saída contém `n/a` | — | **não falha por ausência** — é o comportamento de hoje, e a asserção existe para provar que a mudança é cirúrgica (é a fixture de `w106[9]`) |
| [6] | CANAL — `pre-push` real, faixa com `fix(...)`, change `feature` que declara defeitos e não tem evidência | repositório git com `.forge/` copiado do template, dois commits `fix(...)`, `cwd` dentro | o hook **bloqueia** (`rc≠0`), a linha de bloqueio nomeia o change, e o contador de controle lista o id examinado | rc=0 quando existe um `bugfix` alheio ativo (medido em §1.2), ou `universo-vazio` quando não existe | `hooks/git/lib/check-red-first.sh:123` filtra por `type` |
| [7] | CANAL — `pre-push`, mesmo repositório, change `feature` que declara defeitos e **tem** todas as entradas resolvidas | idem, com evidência resolvida | `rc = 0`, e o contador de controle **lista o id do change examinado** | hoje o contador não nomeia change nenhum — medido em D5 | nasce com D5; sem a decisão de nomear, a asserção seria vermelha contra a implementação correta |
| [8] | CONTRATO — `fixes_defects` malformado é terceiro estado | `fixes_defects: true` (booleano), e variantes com `"abc"`, com mapa, com lista contendo string vazia | `rc ≠ 0` com mensagem que nomeia a **declaração inválida**, nunca `n/a` e nunca um `CONFLICT` de evidência ausente | — | **não falha por ausência** hoje porque a chave não existe; nasce junto com D2 |
| [9] | CONTRATO — as duas formas YAML devolvem a mesma lista | mesmo change em block-sequence e em flow-sequence | a lista lida é idêntica nas duas formas | — | nasce com D3; a asserção é o que impede a regressão para o `awk` medido em §2.3 |
| [21] | CANAL — `red-evidence.sh ci` alcança o change que declara defeitos | um change `feature` com `fixes_defects` e evidência pendente, e um `feat-ci` sem a declaração | o relato do `ci` nomeia o primeiro e **não** nomeia o segundo, e o `rc` reflete a pendência | `[ "$type" = "bugfix" ] \|\| continue` em `red-evidence.sh:66` faz o `ci` pular o change inteiro | é o sítio 10 de §2.1, e ele é o braço executado pelo `red-first.yml` |
| [22] | CANAL — `doctor.sh` relata evidência pendente do change que declara defeitos | idem | o `info` do doctor cita o change | `[ "$chtype" = "bugfix" ] \|\| continue` em `doctor.sh:294` | é o sítio 11 de §2.1 |

**Sobre a coluna do vermelho.** Os números e mensagens são os medidos na minha bancada e servem para o implementador **reconhecer** o vermelho quando o vir. Nenhum deles é literal no fonte do gate: a mensagem de falha do gate imprime o `rc` e a saída que ele mesmo mediu naquela execução, e a asserção é sobre a propriedade (recusou, aceitou, nomeou o change, contém `n/a`), nunca sobre o texto integral.

**Obrigação do implementador antes de escrever `[6]` e `[7]`.** Os cenários dependem de o `_redfirst_has_fix_commit` engajar de fato, e engajar depende da faixa resolvida por `_redfirst_resolve_base`. Medi que a forma com `remote_sha` zerado e a forma com base explícita produzem o mesmo desfecho neste fixture, mas as duas passam por galhos diferentes de `_redfirst_resolve_base` — e o galho do zero depende de `origin/develop`/`origin/HEAD`/`origin/main` existirem. O implementador prova que o hook **engajou** antes de assertar o veredito, e o sinal positivo de execução é o próprio contador de controle, que só é impresso quando `engaged=1`. Sem essa prova, `[6]` mede "o hook não rodou" e chama isso de "o hook aprovou", que é a invariante 2 dentro do gate que existe para defendê-la.

**Segunda obrigação, e ela me custou uma medição errada.** A fixture de `[7]` precisa de uma entrada **genuinamente resolvida**, e a forma barata é enganosa. Montei `[7]` com uma entrada `waived` de `reason: non-behavioral` e `fix_files: ["src/app.mjs"]`, e o hook bloqueou — não por tipo, mas porque a política do waiver é reaplicada a cada `check` e `non-behavioral` nunca é permitido quando o diff toca código no grafo:

```
pre-push BLOQUEADO: red-first pendente em 'pcx' (commit fix(...) detectado em 'refs/heads/develop').
  CONFLICT (waiver non-behavioral inválido — o diff real toca arquivo de código presente no grafo (src/app.mjs); a política nunca permite non-behavioral quando o diff toca código, independente do que o waiver declare (item 1, rule testing/regression-red-first.md))
```

A fixture correta é uma entrada `observed` **internamente consistente** (todos os campos de replay preenchidos, `excerpt_sha256` igual ao hash real do `excerpt`, `replay_head` igual ao HEAD) — o hook roda o check ESTÁTICO, e o limite documentado em `w106[3-FORJA/check]` é justamente que o estático aceita uma forja consistente. Com essa fixture, `[7]` sai `rc=0` e o contador nomeia `pcx`, como a caixa de D5 mostra. Quem montar `[7]` com um waiver produz vermelho contra a implementação correta e vai procurar o defeito no lugar errado.

### 2.5 Prova de mutação de #138

Bancada: cópia inteira de `template/.forge` em `$TMPDIR/l5r2/impl`, com o predicado de D1 e a cobrança de D16 aplicados em `lib/check-red-first.mjs` (patch em §A.4). Controle, mutação e recontrole medidos; restauração por cópia do arquivo **já patchado** e conferência de `sha256`.

**M5 — o predicado volta a ser `type === 'bugfix'`.** Comando exato:

```
$ perl -0pi -e "s/\Qreturn !!man && (man.type === 'bugfix' || fixesDefects(man).declared);\E/return !!man \&\& man.type === 'bugfix';/" "$C"
$ cmp -s "$C" "$B/C.impl" && echo "MUTACAO FANTASMA" || echo "arquivo mudou (cmp contra C.impl)"
```

```
=== CONTROLE — A: feature COM fixes_defects, SEM evidencia | B: feature SEM o campo ===
  A: applicable=true rc=1 | evidence/red/red-evidence.json ausente — change type:bugfix sem evidên…
  B: applicable=false rc=0 | OK check-red-first (n/a — type: feature)
=== M5 ===
arquivo mudou (cmp contra C.impl)
  A: applicable=false rc=0 | OK check-red-first (n/a — type: feature)
  B: applicable=false rc=0 | OK check-red-first (n/a — type: feature)
=== RESTAURACAO + sha256 ===
restauracao OK
=== RECONTROLE ===
  A: applicable=true rc=1 | evidence/red/red-evidence.json ausente — change type:bugfix sem evidên…
  B: applicable=false rc=0 | OK check-red-first (n/a — type: feature)
```

A mutação derruba `[4]` e mantém `[5]` verde nas duas metades — ela é específica do predicado, e não um interruptor geral que apaga o gate inteiro. O recontrole devolve exatamente o controle.

**M7 — a mutação do CANAL, que a revisão 1 declarou não ter medido. Agora está medida, e o resultado corrige a matriz.** Bancada em §A.5: repositório git com o hook e o predicado corrigidos, `pcx` do tipo `feature` declarando um defeito, dois commits `fix(...)` na faixa. A mutação desfaz D5 no laço do hook, reintroduzindo o filtro por `type`:

```
$ python3 -c "…insere as duas linhas do filtro por type antes da consulta ao predicado…" "$H"
$ cmp -s "$H" "$B/H.impl" && echo "MUTACAO FANTASMA" || echo "arquivo mudou (cmp contra H.impl)"
$ bash -n "$H" && echo "bash -n OK"
```

```
=== CONTROLE — [6] (sem evidencia) ===
  CONFLICT (evidence/red/red-evidence.json ausente — … ; 0/1 defeito(s) declarado(s) com Red resolvido — sem prova: branding-preview …)
OK red-first/universo — 1 change(s) que corrigem defeito examinado(s) (…; examinados: pcx)
=== CONTROLE — [7] (entrada resolvida) ===
OK red-first/universo — 1 change(s) que corrigem defeito examinado(s) (…; examinados: pcx)
--- [6] sob a mutacao ---
pre-push BLOQUEADO: red-first — há commit fix(...) sendo publicado e NENHUM change
  ativo type:bugfix foi examinado. …
--- [7] sob a mutacao ---
pre-push BLOQUEADO: red-first — há commit fix(...) sendo publicado e NENHUM change
  ativo type:bugfix foi examinado. …
=== RESTAURACAO + sha256 ===
restauracao OK
=== RECONTROLE [6] ===  (idêntico ao controle)
=== RECONTROLE [7] ===  (idêntico ao controle)
```

**O que a medição corrige na matriz.** A revisão 1 declarava `[7]` "verde por construção" e "não falha por ausência". Isso é falso: sob M7 o `[7]` **também** vira vermelho, porque o universo esvazia e o hook bloqueia por vacuidade. `[7]` discrimina, e a linha da matriz foi reescrita. O que M7 **não** faz é isolar — ela derruba os dois cenários do canal ao mesmo tempo, então o par `[6]`/`[7]` não separa "bloqueou pelo estado" de "bloqueou pelo tipo" sozinho; quem faz essa separação é o `[5]`, o controle negativo, que fica verde sob M5 e sob M7. Isso está escrito aqui porque a revisão 1 atribuía a `[7]` um poder discriminante que a medição não sustenta.

**Todas as mutações desta seção usaram `perl -0pi -e` entre aspas duplas, com o padrão `\Q…\E` e sem nenhum `$` não escapado do lado direito.** É a armadilha de LDG-0164: `$` não escapado do lado direito é variável do **perl**, vazia, e a substituição vira no-op enquanto o `cmp` confirma que o arquivo mudou. Cada mutação teve `cmp -s` contra a cópia de controle **mais** a observação do efeito comportamental — as duas coisas, nunca uma.

**E um erro de bancada meu, que o recontrole pegou e que fica registrado porque é a lição inteira de `feedback-mutacao-fantasma-restore`.** Na primeira execução de M6 eu usei como baseline de `cmp` e de restauração a cópia do arquivo **anterior ao patch** da implementação, e não a cópia do arquivo patchado. O `cmp` acusou "arquivo mudou" (verdade, mas pelo motivo errado) e a restauração devolveu o produto sem a implementação — o recontrole teria medido o produto de hoje e chamado isso de "a implementação correta". Refiz com o baseline certo (`C.impl`, o arquivo já patchado), e é essa segunda execução que está colada em §3.4. A regra que sai daqui: **o baseline de uma prova de mutação é a implementação sob teste, não o estado de onde ela partiu**, e a conferência de `sha256` só vale contra esse baseline.

### 2.6 Retrocompatibilidade de #138

`fixes_defects` é **opt-in e ausente por default**, então nenhum change instalado muda de comportamento. A superfície de risco tem três pontos, e os três estão medidos.

1. **O schema é `additionalProperties: false` e é validado por ajv contra changes ativos reais.** `grep -n 'additionalProperties' template/.forge/schemas/spec-manifest.schema.json` devolve `7`, `32` e `44`; `tools/validate-forge.mjs:63-80` compila `spec-manifest.schema.json` e valida o manifesto de todo change ativo do repositório; `tests/w20-spec-gate.sh:90` roda esse validador (`sed -n 90p` devolve `node "$WS/tools/validate-forge.mjs" >/dev/null`). Um change que carregue `fixes_defects` sem o schema ter a propriedade reprova o `w20`. **A propriedade e o schema entram no mesmo commit**, sem exceção.
2. **Consumidor que atualizar o schema sem atualizar o código, ou o contrário, não quebra.** Schema novo com código velho: o campo é aceito pelo schema e ignorado pelo código — o change fica sem cobrança, que é o estado de hoje. Código novo com schema velho: o campo é lido e cobrado, e a validação por ajv reprova — que é ruidoso, mas é a direção correta de falha. `forge update` propaga `schemas/` e `scripts/` juntos (os dois estão em `MACHINERY_DIRS`, `bin/forge.mjs:307`), então a metade solta só aparece em instalação manual.
3. **Os consumidores já aplicaram a 0.14.0 e nenhum deles tem `fixes_defects` em manifesto nenhum** — a chave não existia. Nenhum change ativo passa a ser cobrado por esta onda sem que alguém escreva a declaração.

---

## 3. ITEM 2 — issue #139

### 3.1 O defeito, reproduzido no template

Bancada: change sintético `type: bugfix` em `$TMPDIR/l5-bench/multi-defeito`, com o scaffold copiado de `template/.forge/templates/bugfix/red-evidence.json`, e `lib/red-evidence-ops.mjs` do template invocado diretamente. Script em §A.6.

```
== record #1 (defeito A) ==
OK record — tests/DefeitoA.Tests.cs declarado (status: pending — rode /forge:red replay para observar)
{ "test_path": "tests/DefeitoA.Tests.cs", "test_id": "DefeitoA_NaoDuplicaCobranca",
  "command": "dotnet test tests/DefeitoA.Tests.cs", "failure_pattern": "Expected 1 but was 2",
  "fix_files": ["src/Billing/Charge.cs"] }
== record #2 (defeito B) ==
OK record — tests/DefeitoB.Tests.cs declarado (status: pending — rode /forge:red replay para observar)
{ "test_path": "tests/DefeitoB.Tests.cs", "test_id": "DefeitoB_RespeitaTenant",
  "command": "dotnet test tests/DefeitoB.Tests.cs", "failure_pattern": "RLS policy violation",
  "fix_files": ["src/Tenancy/Filter.cs"] }
== sobrou algo do defeito A no change? ==
>>> NENHUMA ocorrencia de DefeitoA no change
```

O segundo `record` apagou o primeiro integralmente, sem aviso, com a mesma linha `OK record` do primeiro.

**A quimera do `record` parcial também reproduz.** As atribuições de `cmdRecord` são condicionais à presença da flag (`lib/red-evidence-ops.mjs:95-101`) e a checagem de obrigatoriedade olha o objeto resultante, não as flags — `sed -n 114p` devolve `if (!data.test_path || !data.test_id || !data.command || !data.failure_pattern) {`, e `sed -n 127p` devolve `writeJsonAtomic(ev.path, data);`.

```
== record parcial (só --failure-pattern) ==
OK record — tests/DefeitoB.Tests.cs declarado (status: pending — rode /forge:red replay para observar)
{ "test_path": "tests/DefeitoB.Tests.cs", "test_id": "DefeitoB_RespeitaTenant",
  "command": "dotnet test tests/DefeitoB.Tests.cs", "failure_pattern": "NullReferenceException em Notification" }
```

**E o contorno por arquivo extra é invisível para os gates, como a issue afirma.**

```
$ ls evidence/red/
red-evidence-defeito-a.json      <- escrito à mão, status "observed"
red-evidence.json                <- escrito pelo record, status "pending"
$ check-red-first.mjs status  -> PENDING (status: pending)          rc=0
$ check-red-first.mjs check   -> CONFLICT (… status 'pending' …)     rc=1
```

`lib/red-evidence.mjs:9` fixa `REL_PATH = 'evidence/red/red-evidence.json'` e `loadRedEvidence` só olha esse caminho. O plural `evidence/red/*.json` aparece em **seis** sítios do template, não cinco como dizia a revisão 1:

```
$ grep -arn 'evidence/red/\*' template/ | sed 's/:.*//' | sort | uniq -c
   1 template/.forge/contracts/stages/verify.yaml
   1 template/.forge/hooks/git/lib/check-red-first.sh
   1 template/.forge/rules/testing/regression-red-first.md
   1 template/.forge/schemas/README.md
   1 template/.forge/scripts/lib/red-classify.mjs
   1 template/.forge/scripts/lib/red-level.mjs
$ grep -arn 'evidence/red/\*' tests/ ; echo "rc=$?"
rc=1
```

Cinco deles descrevem um instrumento que não existe; o sexto, `contracts/stages/verify.yaml:9`, é um comentário que registra a **remoção** da entrada, então ele não engana da mesma forma — mas entra na lista, porque a enumeração precisa ser exaustiva e não conveniente. Nenhum gate afirma a string (a varredura sobre `tests/` é sólida sem `-a` pela medição de §1.0, e foi feita com `-a` de qualquer forma), então não há consequência de gate.

### 3.2 Decisões de desenho — FECHADAS

**D10. `entries` é uma lista embutida no mesmo arquivo, com `id` estável por entrada.**

*Alternativa descartada — honrar literalmente o `evidence/red/*.json` da documentação, um arquivo por defeito.* É mais fiel ao texto e não mexe no schema, mas espalha o status do change por N arquivos sem um lugar único que responda "este change está resolvido?", transforma o nome do arquivo em identidade (frágil a renomeação) e obriga a mudar todos os pontos que hoje resolvem `REL_PATH`. A lista embutida concentra a decisão num arquivo e sobrevive melhor a `git merge`. A documentação é que passa a dizer `evidence/red/red-evidence.json` no singular, corrigindo os **seis** sítios enumerados acima.

**D11. O `status` do topo é DERIVADO, e é o PIOR status presente entre as entradas — só isso, e nada mais.**

A ordem é `pending` < `not-possible` < `waived` < `observed`, e a derivação devolve o mínimo. **A revisão 1 acrescentava uma segunda frase — "`observed` no topo só quando toda entrada está `observed` ou `waived`" — e ela contradizia a primeira.** Para `{observed, waived}` as duas davam respostas opostas, e a segunda quebrava a retrocompatibilidade do artefato legado `status: waived`, que normaliza para uma única entrada `waived` e passaria a derivar `observed`. A frase saiu. O que ela tentava dizer pertence a **outro predicado**, e os dois são distintos por construção:

- `deriveStatus(entries)` responde "qual é o pior estado presente" e é o que o topo carrega;
- `isResolvedMulti(entries)` responde "toda entrada está resolvida", isto é, `entries.length > 0 && toda entrada ∈ {observed, waived}`, e é o que decide se o change passa.

Medido na bancada (§A.7), com controle, mutação e recontrole:

```
=== CONTROLE ===
  misto(observed,pending)    deriveStatus=pending       isResolvedMulti=false
  todas-observed             deriveStatus=observed      isResolvedMulti=true
  observed+waived            deriveStatus=waived        isResolvedMulti=true
  legado-waived(1 entrada)   deriveStatus=waived        isResolvedMulti=true
  vazia                      deriveStatus=pending       isResolvedMulti=false
  normalizeEntries(legado status:waived) -> [["default","waived"]]
```

O caso `observed+waived` derivando `waived` e resolvendo `true` é a resposta certa, e é o que preserva os leitores instalados: `spec-verify.sh` compara `d.status` com `observed` **ou** `waived`, então um topo `waived` continua passando. Confirmado lendo o leitor:

```
$ sed -n 118p template/.forge/scripts/spec-verify.sh
if [ "$TYPE" = "bugfix" ]; then
$ sed -n 121p template/.forge/scripts/spec-verify.sh
    _redfirst_status() { node -e "try{const d=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));process.stdout.write(d.status||'')}catch{process.stdout.write('')}" "$RED_JSON"; }
```

*(A revisão 1 citava `spec-verify.sh:120` três vezes como o sítio do leitor; a guarda está em `:118` e o `node -e` em `:121`. Corrigido.)*

E medi os leitores de três versões instaladas contra um artefato que carrega `entries`:

```
$ node --input-type=module -e "
import { validateRedEvidence, isResolved } from '<caminho do red-evidence.mjs instalado>';
import fs from 'node:fs';
const d = JSON.parse(fs.readFileSync('$B/artefato-com-entries.json','utf8'));
console.log('<rótulo> -> errors=' + JSON.stringify(validateRedEvidence(d)) + ' isResolved=' + isResolved(d));"

0.14.0(template)         -> errors=[] isResolved=false
rc24(azim-crm-worktree)  -> errors=[] isResolved=false
0.11.0(PadSimulator)     -> errors=[] isResolved=false
```

Os três caminhos são, na ordem: `forge-harness/template/.forge/scripts/lib/red-evidence.mjs`, `azim-crm/.forge/worktrees/platform-config-ux/.forge/scripts/lib/red-evidence.mjs` (o `forge.yaml` do worktree diz `template_version: "0.1.0-rc24"`) e `Axis.PadSimulator/.forge/scripts/lib/red-evidence.mjs` (`template_version: "0.11.0"`). Zero erros de validação em todas, e `isResolved` degradando para a leitura do status do topo. A degradação é para "a leitura conservadora", nunca para erro de parse.

*Alternativa descartada — espelhar o status da PRIMEIRA entrada.* Tem o mesmo modo de falha da derivação pelo melhor status sempre que a primeira entrada é a provada, e é justamente a ordem em que um autor tende a gravar (o defeito que ele já resolveu primeiro).

**D19. A PRESENÇA da chave `entries` decide quem é a fonte. Presente, `entries` vence sempre e o topo em disco é descartado; ausente, o topo é a fonte e a normalização sintetiza uma entrada `default`. O conjunto projetado no topo são os VINTE campos por defeito que o schema enumera, e só o `status` é derivado em vez de projetado.**

A revisão 2 reprovou porque D10 e D11 diziam "o topo é projeção" sem decidir o que vale quando o topo e `entries` **divergem** — e a §7 enumerava `entries` ausente, vazia, uma e N sem esse caso, embora ele seja exatamente o estado que três fixtures de gate criam (§6.4). A regra é uma frase e não tem exceção:

- `entries` **ausente** ⇒ artefato legado. O topo é a fonte, `normalizeEntries` sintetiza uma entrada `id: default` a partir dos vinte campos, e o `status` da entrada é o do topo. É o cenário `[17]` e a propriedade P3.
- `entries` **presente**, inclusive vazia ⇒ `entries` é a fonte. Todo leitor que vá decidir reprojeta o topo antes de olhar; o valor que estava em disco é descartado, sem fusão e **sem virar erro**. Reprojetar é barato e não-ambíguo, e transformar em erro algo que se recalcula com certeza trava um change sem lhe dar remédio.

Os vinte campos projetados são os do schema menos `schema`, `change_id`, `status` e `entries`: `test_path`, `test_id`, `command`, `base_commit`, `failure_pattern`, `excerpt`, `excerpt_sha256`, `classification`, `base_result`, `base_strategy`, `graft_from`, `revert_patch`, `replay_head`, `setup_command`, `reproduces`, `fix_files`, `waiver`, `recorded_at`, `replayed_at`, `waived_at`. **A enumeração não é conveniente: ela é o `properties` do schema menos três chaves**, e é por isso que ela consegue ser exaustiva. Conferida por comando, não por contagem à mão:

```
$ node -e 'const s=require("./template/.forge/schemas/red-evidence.schema.json");
  const k=Object.keys(s.properties); console.log("props="+k.length);
  console.log("projetados="+k.filter(x=>!["schema","change_id","status"].includes(x)).length)'
props=23
projetados=20
$ node --input-type=module -e "import {ENTRY_FIELDS} from '<B>/.forge/scripts/lib/red-evidence.mjs'; console.log('ENTRY_FIELDS='+ENTRY_FIELDS.length)"
ENTRY_FIELDS=20
```

`entries` não entra na conta porque ainda não está no schema — D17 a acrescenta no mesmo commit, e a partir daí a subtração passa a ser de quatro chaves. **Quem implementar deriva `ENTRY_FIELDS` do schema em vez de reescrever a lista à mão**, ou a próxima propriedade que entrar no schema fica fora da projeção sem que nada acuse. O `status` do topo é `deriveStatus(entries)` (D11), que coincide com a projeção quando há uma entrada e a supera quando há N.

Medido na bancada, com o artefato exatamente na forma que a forja de `w106` produz — `entries` com a declaração real e o topo forjado à mão (script em §A.7):

```
$ node probe-D19.mjs
  fonte lida        -> [["default","pending","tests/bug-a.test.mjs"]]
  topo em disco     -> status=observed test_path=tests/bug-a-forja.test.mjs
  topo reprojetado  -> status=pending test_path=tests/bug-a.test.mjs classification=null
  legado (sem entries) -> [["default","observed","tests/x.mjs","test-graft","abc1234"]]
  legado reprojetado   -> status=observed base_strategy=test-graft graft_from=abc1234
  entries:[] + topo cheio -> entradas=0 deriveStatus=pending topo.test_path=null
```

As três linhas dizem, na ordem, as três consequências que importam:

1. **A forja de topo vira no-op para o leitor novo.** É a raiz do bloqueador 1 da revisão 2, e a saída está em §6.4: três das dez fixtures que escrevem o artefato à mão precisam passar a escrever na entrada.
2. **`w108` fica verde sem edição.** `bug-8` recebe `record` uma única vez (`grep -an 'record bug' tests/w108-red-graft-gate.sh` devolve uma linha, `record bug-8`), então tem uma entrada só, e `base_strategy`, `classification`, `base_commit` e `graft_from` — que `tests/w108-red-graft-gate.sh:75,76,80,81` leem do topo por `json_field` — são quatro dos vinte campos projetados. A linha "legado reprojetado" acima é a prova mecânica: os dois campos que o `w108` lê sobrevivem à ida e volta. O mesmo vale para `tests/w106-red-first-gate.sh:487` (`grep -q '\"waived_at\": \"20'`), porque `waived_at` está na lista dos vinte e `bug-a` tem uma entrada só.
3. **`entries: []` zera o topo**, o que fecha `[24]` do lado do artefato e não só do lado do predicado.

*Alternativa descartada — divergência é erro de artefato (terceiro estado).* É o instinto certo em quase todo lugar deste documento, e aqui ele é o errado: o valor divergente é **derivável com certeza** da fonte, e a única origem possível dele é edição à mão. Transformar em erro custa um change travado sem remédio (um `git merge` que resolveu o topo pela versão errada, por exemplo) e, medido, nem salvaria a fixture do `w106`: com o erro, o `ensure` sairia pelo galho `evidência inválida — check-red-first cobre` sem reescrever o artefato, e o `grep` de `tests/w106-red-first-gate.sh:176` continuaria achando `"status": "observed"` no topo. As duas saídas exigem a mesma edição de fixture; a projeção silenciosa é a que não cria um modo de falha novo.

**D20. Os itens 1 a 8 da rule são avaliados POR ENTRADA, e cada achado nomeia a entrada. Isto era ressalva na revisão 2 e virou decisão porque a medição mostra que ele deixa um change PASSAR.**

O revisor levantou que `evaluateRedFirst` lê a projeção do topo e que, com N entradas, as entradas 2..N ficariam com status próprio mas sem os itens 3 (classificação), 4 (casamento com o `failure_pattern`) e 5 (alcançabilidade). Medi, e o efeito é pior que "cobertura verde com entradas não avaliadas": o change sai `rc=0`. Fixture `C4` — dois ids declarados, duas entradas `observed`, e a **segunda** com `excerpt` de erro de build (`npm ERR! missing script: test`) declarado como `classification: behavioral` e que não casa com o `failure_pattern`, que é exatamente a evidência que §2.2 mede sair `CONFLICT` rc=1 quando é a única:

```
=== D20 — a entrada 2 é avaliada? (entrada 2 com excerpt que não casa e classificação divergente) ===
  rc=0 | cobertura=0
    - nome de teste sem referência aparente ao defeito (item 7, rule testing/regression-red-first.md)…
```

Zero achados bloqueantes. A cobertura fecha 2/2 porque as duas entradas estão `observed`, e a evidência da segunda nunca é olhada — a onda teria entregue um instrumento que aprova, com contador verde, o artefato que ele reprovaria se o defeito fosse um só. Decisão: `evaluateRedFirst` itera as entradas, aplica os itens 1 a 8 a cada uma e prefixa cada achado com `[<id>]`. O cenário `[25]` cobre, e o contrafactual é a própria fixture `C4`: sem a decisão, `rc=0`.

**D21. Dois `entries` com o mesmo `id` são declaração inválida do artefato — terceiro estado, nunca "duas provas do mesmo defeito".**

A necessidade saiu de uma medição de mutação, não de leitura. Sob M1 (§3.4), o `record` sem `--id` acrescenta uma **segunda** entrada também chamada `default` — e não sobrescreve a primeira, como a revisão 2 escrevia:

```
=== M1 ===
  entradas=[{"id":"default","tp":"tests/A.cs","fp":"PA"},{"id":"default","tp":"tests/B.cs","fp":"PB"}]
```

A implementação correta nunca produz isso (`--id` de id existente atualiza, e sem `--id` só se escreve em entrada não declarada). Mas um artefato escrito à mão pode, e aí a cobertura de D16 mente: `resolvidas` é um `Set` de ids, então duas entradas com o mesmo id — uma `observed`, uma `pending` — contam como um id resolvido, e o defeito sem prova desaparece do relato. Decisão: id repetido em `entries` é erro de artefato, com mensagem que nomeia o id, e `validateRedEvidence` passa a conferir. `[26]` cobre.

**D12. `record` sem `--id` só escreve numa entrada AINDA NÃO DECLARADA. Esta decisão corrige a proposta da própria issue.**

A issue propõe: "Sem `--id`, mantém o comportamento atual somente quando `entries` tem no máximo uma entrada; com duas ou mais, falha pedindo o `--id`". Implementei essa regra literal na bancada e medi que **ela preserva o defeito na reprodução da própria issue**: com uma entrada declarada, o segundo `record` sem `--id` continua sobrescrevendo. É a mutação M1, com controle e recontrole, em §3.4.

O critério correto não é a **contagem** de entradas, é o **estado** da entrada alvo: um `record` sem `--id` pode preencher o scaffold cru que `spec-new` criou, e não pode tocar numa entrada que já declara um teste. "Já declara" significa: a entrada tem `test_path`, `test_id`, `command` ou `failure_pattern` não vazio. Medido com a regra corrigida (§A.6, com a implementação aplicada):

```
== [CONTROLE D12] record #1 sem --id (scaffold cru) ==
OK record — [default] tests/A.cs declarado (status: pending, 1 entrada(s))
rc=0
== [CONTROLE D12] record #2 sem --id -> RECUSA (cenario exato de #139) ==
FAIL (--id obrigatório: a evidência já declara 1 defeito(s) (default) — record sem --id sobrescreveria a declaração existente; use --id <um deles> para atualizar, ou --id <novo> para acrescentar)
rc=1
== record #2 com --id ==
OK record — [defeito-b] tests/B.cs declarado (status: pending, 2 entrada(s))
status_topo=pending | topo.test_path=tests/A.cs | entradas=default:tests/A.cs:pending, defeito-b:tests/B.cs:pending
== atualizar a entrada default por --id (nao cria terceira) ==
OK record — [default] tests/A.cs declarado (status: pending, 2 entrada(s))
entradas=2 -> default:dotnet test A --filter x | defeito-b:dotnet test B
```

Fail-closed, que é a política que o resto do módulo já adota, e `--id` de uma entrada existente **atualiza** em vez de duplicar. A mensagem de recusa carrega acentuação correta e nomeia o remédio.

**D12b. As fixtures de `w106` e `w107` que re-gravam a MESMA evidência ganham `--id default`, e são NOVE sítios. Esta decisão fechou o bloqueador 1 da revisão 1; a revisão 3 corrige a contagem de oito para nove.**

D12 quebra toda fixture existente que chama `record` uma segunda vez sobre a mesma evidência já declarada. A revisão 1 varreu `tests/` por **strings de saída** e nunca pela **sequência de chamadas**, e por isso afirmou que `w106` ficaria verde sem edição. Medi a sequência:

```
$ grep -n 'record ' tests/w106-red-first-gate.sh tests/w107-red-replay-gate.sh \
    | grep -oE '(w10[67][^:]*):[0-9]+.*record bug[a-z0-9-]*'
w106-red-first-gate.sh:99:…  record bug-a
w106-red-first-gate.sh:242:… record bug-a
w106-red-first-gate.sh:631:… record bug-x
w106-red-first-gate.sh:689:… record bug-d
w106-red-first-gate.sh:713:… record bug-d
w106-red-first-gate.sh:739:… record bug-d
w106-red-first-gate.sh:769:… record bug-d
w106-red-first-gate.sh:796:… record bug-d
w106-red-first-gate.sh:969:… record bug-typechange
w107-red-replay-gate.sh:60:…  record bug-1
…
w107-red-replay-gate.sh:365:… record bug-9
w107-red-replay-gate.sh:443:… record bug-12
w107-red-replay-gate.sh:457:… record bug-12
w107-red-replay-gate.sh:720:… record bug-20
w107-red-replay-gate.sh:730:… record bug-20
```

São doze chamadas sobre cinco changes que recebem `record` mais de uma vez, e oito delas são a segunda-ou-posterior sobre entrada já declarada. **Mas o critério "duas chamadas de `record` no mesmo change" é o critério errado, e ele esconde um nono sítio.** O que D12 recusa é `record` sem `--id` sobre um artefato **já declarado**, e a declaração pode ter vindo de uma escrita à mão. Refiz a varredura pela linha do tempo — chamadas de `record` e escritas à mão do artefato, na ordem em que o gate as executa:

```
$ for f in tests/w106-red-first-gate.sh tests/w107-red-replay-gate.sh; do echo "===== $f"; \
    grep -an 'record \(bug\|feat\)[a-z0-9-]*\|cat > "\$EV\|d\.status = \|d\.waiver = \|d\.excerpt = ' "$f"; done
```

Ela expõe `tests/w106-red-first-gate.sh:631` (`record bug-x`), que é a **primeira** chamada de `record` sobre `bug-x` e por isso não aparecia na varredura por sequência — mas o artefato de `bug-x` foi declarado à mão pelo heredoc de `tests/w106-red-first-gate.sh:593`, cujo conteúdo traz `"test_path": "tests/bug-x.spec.ts"`. `isDeclared` é verdadeiro, e D12 recusa. Os nove sítios:

| Gate | Linha | Change | Por que a evidência já está declarada |
|---|---|---|---|
| `w106` | 242 | `bug-a` | o próprio comentário de `w106:239-241` diz que o re-record é necessário porque a forja sobrescreveu a declaração |
| `w106` | 713, 739, 769, 796 | `bug-d` | `bug-d` é criado uma vez (`w106:647`) e reusado como bancada de cinco fixtures de replay; o `record` de `:689` já declara |
| `w107` | 365 | `bug-9` | a forja do `[9]` (`w107:331-344`) escreve `test_path`/`test_id`/`command` à mão antes |
| `w107` | 457 | `bug-12` | o `record` de `:443` já declara |
| `w107` | 730 | `bug-20` | o `record` de `:720` já declara |
| **`w106`** | **631** | **`bug-x`** | **o heredoc de `:593` declara à mão (`test_path` não nulo) — sítio que a varredura por sequência de chamada não vê** |

Os dois gates rodam sob `set -euo pipefail` (`w106:24`, `w107:16`), e a maioria dessas chamadas está redirecionada para `/dev/null` sem `set +e`, então o `rc=1` de D12 mata o gate na linha.

**A saída é `--id default`, e não afrouxar D12.** A entrada sintetizada pela normalização de um artefato legado tem `id` igual a `default` (medido em D11: `normalizeEntries(legado) -> [["default","waived"]]`), e D12 já decide que `--id` de uma entrada existente **atualiza**. Medi que a atualização por `--id default` funciona e preserva o prefixo `OK record` que quatro gates afirmam (a saída da caixa de D12 acima, linha "atualizar a entrada default por --id"). Então a edição é uniforme e mecânica: as oito chamadas ganham `--id default` logo depois do id do change.

*Alternativa descartada — uma flag nova `--replace`/`--force` para sobrescrita deliberada.* Ela seria mais expressiva, mas acrescenta superfície de flag na classe de #103 para resolver um caso que `--id` já resolve, e criaria dois vocabulários para "quero escrever nesta entrada". A recusa de D12 já nomeia o remédio (`use --id <um deles> para atualizar`), então o autor humano descobre a saída pela própria mensagem.

**As nove edições entram na definição de pronto, nominalmente**, e a DoD da revisão 1 — que mandava `w106` ficar "verde sem edição" — estava errada e foi reescrita. O `--id default` é correto nos nove porque, em todos, o artefato no momento da chamada está na forma **legada** (sem a chave `entries`) ou tem uma única entrada `default`: o heredoc de `:593` e as forjas escrevem só escalares do topo, e D19 manda `normalizeEntries` sintetizar `default` a partir deles. O cenário `[2b]` é o que fixa essa leitura.

**D13. Entrada nova nasce vazia e nunca herda campos da anterior.**

É o que fecha a quimera de §3.1. Medido no controle: `--id` novo com campos incompletos **recusa** por obrigatoriedade em vez de completar com o que sobrou da entrada anterior.

```
== [D13] --id novo com campos incompletos -> RECUSA, sem herdar ==
FAIL (--test-path, --test-id, --command e --failure-pattern são obrigatórios para record)
rc=1
entradas=[{"id":"default","tp":"tests/A.cs","fp":"PA"},{"id":"defeito-b","tp":"tests/B.cs","fp":"PB"}]
```

**D14. `waive` passa a ser por entrada.** `--id` obrigatório quando há mais de uma **entrada**, declarada ou não, e o waiver mora na entrada, não no topo.

*(A revisão 2 escrevia "mais de uma entrada **declarada**", e essa redação tem um buraco que o cenário `[3]` expõe. Com o `init` de §8 item 10, um change que declara dois ids nasce com duas entradas **não declaradas** — e um waiver é exatamente o que se concede ao defeito que não tem teste, isto é, à entrada não declarada. Pelo critério antigo, `waive` sem `--id` seria aceito ali e teria de escolher uma das duas sem critério. O critério é a **contagem de entradas**, não o estado delas, e isso é uma diferença deliberada em relação a D12: `record` escreve uma declaração, e "a primeira ainda não declarada" é um alvo natural; `waive` dispensa um defeito nomeado, e não existe alvo natural quando há mais de um.)* O caso real que sustenta a decisão está em §1.4: o waiver de `axis-fare-validator/2026-08-04-lists-parameters-refresh-integrity` tem `reason: no-test-infra`, uma nota longa e honesta que descreve o Red do §1.1, e o campo `reproduces` do próprio artefato diz `bugfix.md §1.1` — enquanto o efeito dele foi dispensar o change inteiro, §1.2 incluído. O autor sabia de qual defeito falava; o artefato não tinha onde registrar isso.

**D15. `replay` ganha `--id` (uma entrada; todas por omissão) e `ensure` roda sempre todas, sem atalho.**

`ensure` é chamado incondicionalmente por `spec-verify.sh` (dentro do bloco de `:118`), pelo pré-flight de `archive-spec.sh` e por `lib/validate-spec.mjs:155-166`, e a decisão da Onda E é que ele não tem atalho. Com N entradas o custo é N execuções do motor de replay a cada `/forge:verify` e a cada transição para `verified`. **Isso é caro e é aceito em letra**, com dois argumentos medidos: hoje o mesmo autor pagaria N vezes de qualquer forma, porque a única saída disponível é fatiar o trabalho em N changes (N worktrees, N `bugfix.md`, N `verify`, N `archive`), e a alternativa de cachear já foi tentada duas vezes e removida (ADR-0003, adendas 1 e 2). O único atalho que permanece é `status: waived` **na entrada**, que é política própria e não observação pendente de prova.

**Consequência de D19 sobre este comando, e ela precisa estar escrita porque é o ponto de escrita que o `ensure` compartilha com o `replay`.** `persistReplayResult` é hoje o único tradutor de veredito em escrita, e ele grava um `status` global e os campos de replay no topo (`lib/red-evidence-ops.mjs:136-176`). Com `entries` como fonte, ele passa a escrever **na entrada replayada** e a reprojetar o topo — se continuasse escrevendo só no topo, o resultado de um replay real teria exatamente o mesmo destino da forja de §6.4: descartado na próxima leitura. É a mesma decisão de D19 aplicada ao escritor, e ela vale para os cinco escritores mais o sexto (a fixture de gate), sem exceção.

**D16. A cobrança por defeito declarado é uma asserção com contador no próprio texto.**

Quando o manifesto declara `fixes_defects`, cada id precisa de uma entrada de evidência **resolvida** (`observed` ou `waived`). O achado nomeia quantos foram provados de quantos e **quais faltam**. Medido na bancada com a asserção aplicada (§A.4):

```
=== C1: 2 declarados, 1 entrada observed (artefato com o topo projetado) ===
  rc=1 | cobertura=1
    - 1/2 defeito(s) declarado(s) com Red resolvido — sem prova: branding-save-silent (item 1, rule testing/re…
    - nome de teste sem referência aparente ao defeito (item 7, rule testing/regression-red-first.md)…
=== C2: 2 declarados, 2 entradas resolvidas ===
  rc=0 | cobertura=0
=== C3 (contrapositiva): 2 entradas resolvidas, um id ERRADO ===
  rc=1 | cobertura=1
    - 1/2 defeito(s) declarado(s) com Red resolvido — sem prova: branding-save-silent (item 1, rule testing/re…
```

O achado de cobertura está presente em C1 e C3 e **ausente** em C2. A contrapositiva C3 prova que o casamento é por `id` e não por contagem: duas entradas resolvidas com um id errado não satisfazem dois ids declarados.

*(A revisão 2 colava estas mesmas três caixas com `rc=1` nos três casos e um `CONFLICT` de "evidência de replay incompleta" em C2. Aquilo era artefato da minha fixture, não do desenho: os `entries` de C1/C2/C3 não tinham os campos de replay, então o topo projetado saía vazio e os itens 2/3 disparavam por conta própria. Remontei as três fixtures com entradas completas — `test_path`, `test_id`, `command`, `failure_pattern`, `excerpt` com `excerpt_sha256` real, `classification`, `base_commit`, `base_result`, `fix_files`, `recorded_at`, `replayed_at` — e C2 sai `rc=0`, como tem de sair. A frase "os três casos saem rc=1" era falsa e foi removida.)*

**A asserção de `[15]` continua sendo sobre a presença do achado, nunca sobre o código de saída**, e agora por um motivo medido em vez de assumido: M6 (§3.4) mantém `rc=1` nas duas metades, então uma asserção escrita só sobre o `rc` seria no-op contra ela.

**D17. O schema `red-evidence.schema.json` ganha `entries` no mesmo commit do escritor.**

Medido com ajv 2020 estrito, carregado do mesmo jeito que `tools/validate-forge.mjs:21` o carrega:

```
$ node --input-type=module -e '
import fs from "node:fs";
import Ajv2020 from "ajv/dist/2020.js";
const ajv = new Ajv2020.default({ allErrors: true, strict: true, allowUnionTypes: true });
const v = ajv.compile(JSON.parse(fs.readFileSync("template/.forge/schemas/red-evidence.schema.json","utf8")));
for (const f of process.argv.slice(1)) {
  const d = JSON.parse(fs.readFileSync(f,"utf8"));
  console.log(f.replace(/.*\//,"") + " -> " + (v(d) ? "VALIDA" : "REPROVA: " + JSON.stringify((v.errors||[]).map(e=>e.instancePath+" "+e.message))));
}' "$B/artefato-com-entries.json" "$B/scaffold.json"

artefato-com-entries.json -> REPROVA: [" must NOT have additional properties"]
scaffold.json -> VALIDA
```

*(Nota de método: `new Ajv(...)` do pacote raiz falha com `no schema with key or ref "https://json-schema.org/draft/2020-12/schema"` neste schema. O import correto é `ajv/dist/2020.js`, e foi por não usá-lo que a medição pareceu irreprodutível.)*

**Nenhum gate valida `red-evidence.json` contra o schema hoje**, e a afirmação de ausência vem com escopo, com `-a` e com controle positivo plantado:

```
$ grep -arln 'red-evidence.schema' tests/ tools/ ; echo "rc=$?"
rc=1
$ mkdir -p "$P/ctrl" && printf 'red-evidence.schema.json\n' > "$P/ctrl/plant.txt"
$ grep -arln 'red-evidence.schema' "$P/ctrl"
/…/ctrl/plant.txt
```

Sem escopo, a mesma varredura devolve onze arquivos (`CHANGELOG.md`, `schemas/README.md`, o ADR-0003, dois artefatos de spec arquivados, `docs/refer`, `.forge/product/current/...`, esta própria especificação, o schema e o `lib/red-evidence.mjs`) — a revisão 1 dizia "só `lib/red-evidence.mjs`" e estava errada na forma, certa no conteúdo. O comentário de `lib/red-evidence.mjs:20` diz em letra que `additionalProperties` não é reforçado no runtime. Ou seja: publicar o escritor sem o schema **não deixa nada vermelho hoje**, e é exatamente por isso que a decisão precisa estar escrita — a lacuna seria um contrato publicado que o próprio produto reprova, esperando a primeira validação estrita para aparecer. O `schema` permanece `red-evidence/v1`: a mudança é aditiva e os leitores instalados a aceitam (D11).

**D18. `--id` recusa valor com forma de flag. Esta decisão nasce de uma medição nova e fecha o buraco em que D12 se apoia.**

`parseFlags` (`lib/red-evidence-ops.mjs:80-87`) faz `out[a.slice(2)] = argv[i + 1]` sem perguntar o que `argv[i+1]` é. Medi a consequência na bancada, com a implementação de D12 aplicada:

```
$ node lib/red-evidence-ops.mjs record <dir> --test-path tests/A.cs --test-id A --command "t A" --failure-pattern PA --id --setup-command "echo x"
OK record — [--setup-command] tests/A.cs declarado (status: pending, 2 entrada(s))
rc=0
$ node -e '…lê o artefato…'
entradas=["default","--setup-command"]
```

O autor que digita `--id` e esquece o valor cria uma entrada chamada `--setup-command`, e essa entrada nunca casará com nenhum id de `fixes_defects` — o modo de falha é uma cobertura permanentemente incompleta com um id impossível de adivinhar. `tests/w201-flag-como-valor-gate.sh` cobre `ledger-ops`, `deferral-ops` e `liaison-ops` (`grep -aoE '(ledger|deferral|liaison|red-evidence|check-red-first)-ops' tests/w201-flag-como-valor-gate.sh | sort -u` devolve exatamente esses três), e não cobre `red-evidence-ops`, então nada reprova hoje.

A decisão: **`--id` recusa, com `rc≠0` e mensagem própria, um valor que comece com `--`.** A onda não reconcilia `parseFlags` com `lib/arg-guards.sh` nem com a issue #103 — isso continua fora do escopo (§8.6) —, ela endurece a única flag em que o fail-closed de D12 se apoia. O cenário `[23]` cobre. Vale notar que a ordem importa: quando `--id` vem **antes** das flags obrigatórias, o engano já falha fechado por obrigatoriedade (medido: `FAIL (--test-path, --test-id, --command e --failure-pattern são obrigatórios…)`), e é só na ordem inversa que ele passa — que é precisamente o tipo de dependência de ordem que uma guarda explícita elimina.

### 3.3 O VERMELHO de #139, antes do verde

Cenários do mesmo gate `tests/w<NNN>-red-defect-scope-gate.sh`, herméticos, em `$TMPDIR`.

| # | Cenário | Estado da fixture | Asserção | Vermelho de hoje | Por que falha por ausência real |
|---|---|---|---|---|---|
| [10] | dois `record` no mesmo change, com `--id` distintos | change `bugfix`, scaffold do template | as duas declarações coexistem e a primeira é recuperável do artefato | `>>> NENHUMA ocorrencia de DefeitoA no change` — o primeiro `record` foi apagado | `cmdRecord` copia `ev.data` e sobrescreve campo a campo em `lib/red-evidence-ops.mjs:93-105`; não há array em lugar nenhum |
| [11] | segundo `record` **sem** `--id` sobre entrada já declarada | idem, uma entrada declarada | `rc ≠ 0`, mensagem que nomeia a entrada existente, e o artefato **byte-idêntico** ao anterior — em particular, **nenhuma segunda entrada com o mesmo id**, que é o dano que M1 produz | `OK record`, rc=0, artefato sobrescrito | não existe guarda; a escrita de `lib/red-evidence-ops.mjs:127` é incondicional |
| [12] | `record` com `--id` novo e campos incompletos | uma entrada `default` completa | `rc ≠ 0` por obrigatoriedade, e **nenhuma** entrada nova criada | `OK record` com o `test_path` do defeito anterior e o `failure_pattern` do novo | a obrigatoriedade de `lib/red-evidence-ops.mjs:114` olha o objeto resultante, não as flags |
| [13] | status derivado | evidência com uma entrada `observed` e uma `pending` | `deriveStatus` do topo é `pending`, e o leitor de `spec-verify.sh:121` lê `pending` | não há campo derivado; o topo é o que o último `record` escreveu | `persistReplayResult` grava um `status` global para o change inteiro (`lib/red-evidence-ops.mjs:136-176`) |
| [13b] | status derivado no caso `{observed, waived}` | uma entrada `observed`, uma `waived` | `deriveStatus` é `waived` (o pior presente) e `isResolvedMulti` é `true` | — | nasce com D11; é o caso em que as duas frases da revisão 1 se contradiziam, e o cenário existe para fixar a leitura única |
| [14] | `isResolvedMulti` sobre a lista | uma entrada `observed`, uma `pending` | o change **não** é resolvido | `isResolved` lê `data.status` e devolve o que estiver lá | `lib/red-evidence.mjs:87-89` reduz um campo, não uma lista |
| [15] | cobertura por defeito declarado | manifesto com dois ids, evidência com uma entrada resolvida | a saída contém o achado de cobertura com o contador `N/M` e o id sem prova; a asserção é sobre a **presença do achado**, nunca sobre o `rc` | o `CONFLICT` de hoje não diz qual defeito ficou sem prova, porque só existe um | nasce com D16 |
| [16] | CONTRAPOSITIVA de [15] | dois ids declarados, duas entradas resolvidas com **um id errado** | o achado nomeia o id declarado que não tem entrada | — | nasce com D16; sem ela [15] passaria por contagem em vez de casamento |
| [17] | RETROCOMPATIBILIDADE — artefato legado sem `entries` | evidência no formato de hoje, `status: observed`, campos completos; e a variante `status: waived` | `check` e `status` se comportam exatamente como hoje, o change é resolvido, e o topo **não muda de valor** | — | **não falha por ausência** — é a guarda de não-regressão, verde antes e depois; a variante `waived` é a que a segunda frase de D11, agora removida, teria quebrado |
| [18] | `waive` por entrada, **com `--id`** (obrigatório: há duas entradas, D14) | duas entradas, uma `observed` e uma que precisa de dispensa | o waiver mora na entrada nomeada, `deriveStatus` do topo passa a `waived`, `isResolvedMulti` é `true`, e a entrada `observed` permanece `observed` | `waive` grava no topo e dispensa o change inteiro | `cmdWaive` em `lib/check-red-first.mjs:539` opera sobre o objeto raiz |
| [19] | CONTADOR DE CONTROLE do gate | — | ver §5 | — | **não falha por ausência** — verde por construção |
| [20] | SENTINELA do próprio gate | — | `git -C <repo> status --porcelain` sobre `template/`, `tests/` e `.forge/` é idêntico no início e no fim do gate | — | **não falha por ausência** — o vermelho dela é defeito do gate, não do produto |
| [23] | `--id` com valor de forma de flag | entrada `default` declarada, `--id --setup-command "echo x"` no fim da linha | `rc ≠ 0`, mensagem própria, e **nenhuma** entrada nova criada | `OK record — [--setup-command] …`, rc=0, entrada `--setup-command` criada (medido em D18) | nasce com D18 |
| [24] | `entries: []` presente e vazia | evidência com `entries: []` **e o topo cheio de escalares** | `isResolvedMulti` é `false`, `deriveStatus` é `pending` e o topo reprojetado zera — `entries` presente vence o topo mesmo quando está vazia | — | nasce com D11 e D19; sem a cláusula de tamanho, `[].every(…)` aprovaria por vacuidade, e sem D19 o topo cheio seria lido como a fonte |
| [25] | itens 1 a 8 da rule POR ENTRADA | dois ids declarados, duas entradas `observed`, e a **segunda** com `excerpt` de erro de build declarado `classification: behavioral` que não casa com o `failure_pattern` | `rc ≠ 0`, com achado que **nomeia a segunda entrada** (prefixo `[<id>]`) | `rc=0`, cobertura 2/2 verde, nenhum achado bloqueante — medido em D20 | nasce com D20; sem ela `evaluateRedFirst` lê só a projeção do topo, que é a primeira entrada |
| [26] | id repetido em `entries` | artefato escrito à mão com duas entradas `id: default`, uma `observed` e uma `pending` | `rc ≠ 0` com erro de artefato que **nomeia o id repetido**, e a cobertura **não** conta o id como resolvido | — | nasce com D21; o achado saiu de M1, que produz exatamente esse artefato |
| [27] | topo divergente de `entries` | artefato com `entries` carregando a declaração real e o topo forjado à mão (`status: observed`, `test_path` de outro teste) | o leitor decide pela entrada: `deriveStatus` é o da entrada, o topo reprojetado descarta a forja, e **nenhum** erro é levantado | — | nasce com D19; é a forma exata que as três fixtures de §6.4 produzem, e sem o cenário a decisão fica sem contrafactual |

**A sentinela `[20]` não é zelo.** LDG-0175 registra um gate desta suíte que usou arquivo rastreado de `template/` como fixture e não restaurou, deixando `run-all.sh` reduzido a um stub de três linhas. Esta onda toca `template/.forge/scripts/lib/`, que é o mesmo bairro.

### 3.4 Prova de mutação de #139

Bancada `$TMPDIR/l5r2/impl`, com D10–D13 e D16 aplicados (patches em §A.4 e §A.7). **Controle, mutação, restauração por cópia do arquivo já patchado com conferência de `sha256`, e recontrole em todas as linhas.**

**M1 — a guarda de `record` vira a regra literal proposta pela issue (`entries.length > 1`).** Comando:

```
$ perl -0pi -e 's/\Qconst declared = entries.filter(isDeclared);\E/const declared = entries.length > 1 ? entries.filter(isDeclared) : [];/' "$R"
$ cmp -s "$R" "$B/R.orig" && echo "MUTACAO FANTASMA" || echo "arquivo mudou (cmp)"
```

```
--- CONTROLE (implementação correta) ---
FAIL (--id obrigatório: a evidência já declara 1 defeito(s) (default) — 
  arquivo mudou (cmp contra R.impl)
--- M1 ---
OK record — [default] tests/B.cs declarado (status: pending, 2 entrada(s
  entradas=[{"id":"default","tp":"tests/A.cs","fp":"PA"},{"id":"default","tp":"tests/B.cs","fp":"PB"}]
  restauracao: a9654c0fda0067752a100a8aa70a053f vs a9654c0fda0067752a100a8aa70a053f
  restauracao OK
--- RECONTROLE ---
FAIL (--id obrigatório: a evidência já declara 1 defeito(s) (default) — 
  entradas=[{"id":"default","tp":"tests/A.cs","fp":"PA"}]
```

Derruba `[11]`. É a linha mais importante da matriz porque a mutação é **a proposta da issue**, e sem ela o gate ficaria verde sobre o defeito que ele existe para fechar. *(A revisão 2 descrevia o efeito de M1 como "continua sobrescrevendo"; a medição desta revisão mostra outra coisa e é ela que vale — sob M1 nasce uma SEGUNDA entrada com o id `default`, id duplicado que nunca casa de forma única com `fixes_defects`. É desse achado que sai D21, e a asserção de `[11]` passa a incluir que o artefato fica byte-idêntico, o que a mutação viola nas duas leituras.)*

**M2 — `deriveStatus` devolve o MELHOR status em vez do pior.** Comandos (as duas substituições são necessárias — só inverter a comparação sem inverter o valor inicial deixa a mutação incompleta):

```
$ perl -0pi -e 's/\Qif (STATUS_RANK[s] < STATUS_RANK[worst]) worst = s;\E/if (STATUS_RANK[s] > STATUS_RANK[worst]) worst = s;/' "$E"
$ perl -0pi -e "s/\Qlet worst = 'observed';\E/let worst = 'pending';/" "$E"
```

```
=== CONTROLE ===
  misto(observed,pending)    deriveStatus=pending       isResolvedMulti=false
  observed+waived            deriveStatus=waived        isResolvedMulti=true
=== M2 ===
arquivo mudou (cmp)
  misto(observed,pending)    deriveStatus=observed      isResolvedMulti=false
  observed+waived            deriveStatus=observed      isResolvedMulti=true
=== RESTAURACAO ===  restauracao OK
=== RECONTROLE ===
  misto(observed,pending)    deriveStatus=pending       isResolvedMulti=false
  observed+waived            deriveStatus=waived        isResolvedMulti=true
```

Derruba `[13]` e `[13b]`, e **não** derruba `[14]` — as asserções medem coisas diferentes e a mutação prova isso. Um gate que tivesse só `[14]` ficaria verde sobre M2, e o `spec-verify.sh` aprovaria um change com um defeito sem prova.

**M4 — `isResolvedMulti` sobre a lista usa `some` em vez de `every`.**

```
$ perl -0pi -e "s/\Qreturn es.every((e) => e && (e.status === 'observed' || e.status === 'waived'));\E/return es.some((e) => e \&\& (e.status === 'observed' || e.status === 'waived'));/" "$E"
```

```
=== CONTROLE ===   misto(observed,pending)  deriveStatus=pending  isResolvedMulti=false
=== M4 ===         misto(observed,pending)  deriveStatus=pending  isResolvedMulti=true
=== RECONTROLE === misto(observed,pending)  deriveStatus=pending  isResolvedMulti=false
```

Derruba `[14]` e não derruba `[13]`. Espelha M2 na direção oposta, e o par é o que prova que as duas asserções são necessárias.

**M3 — entrada nova HERDA os campos da anterior.**

```
$ perl -0pi -e 's/\Qtarget = { id: f['"'"'id'"'"'], status: '"'"'pending'"'"' }; entries.push(target);\E/target = { ...entries[entries.length - 1], id: f["id"], status: "pending" }; entries.push(target);/' "$R"
```

```
=== CONTROLE (entrada nova nasce vazia) ===
rc=1 out=FAIL (--test-path, --test-id, --command e --failure-pattern são obriga
  entradas=[{"id":"default","tp":"tests/A.cs","fp":"PA"}]
=== M3 ===
arquivo mudou (cmp)
rc=0 out=OK record — [defeito-b] tests/A.cs declarado (status: pending, 2 entra
  entradas=[{"id":"default","tp":"tests/A.cs","fp":"PA"},{"id":"defeito-b","tp":"tests/A.cs","fp":"NullReferenceException"}]
=== RESTAURACAO === restauracao OK
=== RECONTROLE ===
rc=1 …  entradas=[{"id":"default","tp":"tests/A.cs","fp":"PA"}]
```

Derruba `[12]`. Sob a mutação, o artefato passa a declarar o teste de um defeito com o padrão de falha de outro — que é literalmente a quimera descrita na issue, agora reproduzida como contrafactual.

**M6 — a guarda de cobertura passa a exigir só a EXISTÊNCIA da entrada, não a resolução.**

```
$ perl -0pi -e "s/\Qconst resolvidas = new Set(entries.filter((e) => e.status === 'observed' || e.status === 'waived').map((e) => e.id));\E/const resolvidas = new Set(entries.map((e) => e.id));/" "$C"
$ cmp -s "$C" "$B/C.impl" && echo "MUTACAO FANTASMA" || echo "arquivo mudou (cmp contra C.impl)"
```

Cenário: 2 declarados, entrada `branding-save` **presente mas pending**.

```
--- CONTROLE (baseline = C.impl) ---
  rc=1 | cobertura=1
  arquivo mudou (cmp contra C.impl)
--- M6 ---
  rc=1 | cobertura=0
  restauracao OK (261b9106e39b0ee8937b3d92caeeef08)
--- RECONTROLE ---
  rc=1 | cobertura=1
```

**O `rc` é 1 nas duas metades**, e essa é a observação que a linha da matriz existe para registrar: uma asserção escrita só sobre o `rc` seria **no-op** aqui, porque o `CONFLICT` do status pendente do topo mantém o vermelho sozinho. A asserção de `[15]` precisa ser sobre a **presença do achado de cobertura** na saída, com o contador `N/M`, nunca sobre o código de saída. É a mesma classe de LDG-0164 chegando pelo lado do observável em vez do lado da mutação.

**M8 — `evaluateRedFirst` avalia só a projeção do topo, em vez de iterar as entradas (o contrafactual de D20).**

Esta é a única mutação cujo lado **positivo** a bancada não implementa, e isso está dito em §A.9: a iteração dos itens 1 a 8 por entrada é um refactor de `evaluateRedFirst` que a bancada não fez. O que ela mediu foi o contrafactual — que é o que prova a necessidade da decisão —, com a fixture `C4` de §3.2: dois ids declarados, duas entradas `observed`, e a segunda com `excerpt` de erro de build declarado `behavioral` e que não casa com o `failure_pattern`.

```
=== M8 (= a versão que lê só o topo) ===
  rc=0 | cobertura=0
    - nome de teste sem referência aparente ao defeito (item 7, rule testing/regression-red-first.md)…
```

Derruba `[25]`. **A leitura honesta desta linha:** ela demonstra o dano, não a correção. Uma asserção de `[25]` escrita contra ela precisa afirmar a **presença de um achado bloqueante que nomeie a segunda entrada**, e o implementador confirma a outra metade quando implementar D20 — o `rc=1` com `[branding-save-silent]` no achado.

**M9 — a precedência inverte: o topo vence `entries` quando o topo traz `status`.** Comando:

```
$ perl -0pi -e 's/\Qconst raw = Array.isArray(data.entries) ? data.entries\E/const raw = data.status ? null : Array.isArray(data.entries) ? data.entries/' "$E"
$ cmp -s "$E" "$B/E.impl" && echo "MUTACAO FANTASMA" || echo "arquivo mudou (cmp contra E.impl)"
$ node --check "$E"
```

```
--- CONTROLE ---
  fonte lida        -> [["default","pending","tests/bug-a.test.mjs"]]
  topo em disco     -> status=observed test_path=tests/bug-a-forja.test.mjs
  topo reprojetado  -> status=pending test_path=tests/bug-a.test.mjs classification=null
  arquivo mudou (cmp contra E.impl)
--- M9 ---
  fonte lida        -> [["default","observed","tests/bug-a-forja.test.mjs"]]
  topo em disco     -> status=observed test_path=tests/bug-a-forja.test.mjs
  topo reprojetado  -> status=observed test_path=tests/bug-a-forja.test.mjs classification=behavioral
  restauracao OK (ae5f283706f05204b35ab1d66a4ebe44)
--- RECONTROLE ---
  fonte lida        -> [["default","pending","tests/bug-a.test.mjs"]]
  topo em disco     -> status=observed test_path=tests/bug-a-forja.test.mjs
  topo reprojetado  -> status=pending test_path=tests/bug-a.test.mjs classification=null
```

Derruba `[27]`, e a fixture da mutação é literalmente a forja do `w106`: sob M9 a forja de topo **volta a funcionar**, a declaração real desaparece da leitura e o artefato passa a dizer `observed` com o teste forjado. É a prova de que D19 não é preferência de estilo — a direção da precedência é o que separa "o `ensure` reexecuta o teste verdadeiro" de "o `ensure` reexecuta o teste que o forjador escolheu".

**M10 — a guarda de id repetido é removida (o contrafactual de D21).** Comando:

```
$ perl -0pi -e 's/\Qif (rep.size) errors.push\E/if (false \&\& rep.size) errors.push/' "$E"
```

```
--- CONTROLE ---
  errors=["entries: id repetido (default) — cada defeito declarado precisa de exatamente uma entrada"]
  ids tidos por resolvidos=["default"]  (entradas=2)
  arquivo mudou (cmp contra E.impl)
--- M10 ---
  errors=[]
  ids tidos por resolvidos=["default"]  (entradas=2)
  restauracao OK (ae5f283706f05204b35ab1d66a4ebe44)
--- RECONTROLE ---
  errors=["entries: id repetido (default) — cada defeito declarado precisa de exatamente uma entrada"]
  ids tidos por resolvidos=["default"]  (entradas=2)
```

Derruba `[26]`. A segunda linha é a que importa e ela **não muda** com a mutação: com dois `default`, um `observed` e um `pending`, o `Set` de resolvidas contém `default` nas duas metades. Ou seja, a cobertura de D16 conta o defeito como provado tanto com a guarda quanto sem ela — quem discrimina é **só** o erro de artefato, e é por isso que a asserção de `[26]` precisa ser sobre a mensagem de id repetido e não sobre o resultado da cobertura. É a mesma classe de M6, chegando pelo lado do observável.

**M7 — a mutação do canal do `pre-push`** está em §2.5, com o mesmo protocolo, e ela é a que a revisão 1 declarava não ter medido.

**Todas as mutações usaram `perl -0pi -e` com `\Q…\E` e sem nenhum `$` não escapado do lado direito**, e cada uma teve o `cmp -s` contra a cópia de controle **mais** a observação do efeito comportamental. As duas coisas, sempre — o `cmp` sozinho é o que produziu as mutações fantasmas de LDG-0164 e de `feedback-mutacao-fantasma-restore`. O erro de baseline que eu mesmo cometi na primeira execução de M6 está relatado em §2.5.

### 3.5 Retrocompatibilidade de #139

Esta é a onda que mais precisa desta seção, porque os consumidores já carregam artefatos no formato de hoje. Medi cada classe, e os comandos estão colados.

```
$ cd ~/Documents/projects
$ for r in axis-go-cloud axis-fare-validator azim-crm forge-harness Axis.PadSimulator lionclaw; do
    v=$(grep -h 'template_version' "$r/.forge/forge.yaml" 2>/dev/null | head -1 | tr -d ' ')
    arch=$(grep -al '^type: bugfix' "$r/.forge/specs/archived"/*/manifest.yaml 2>/dev/null | wc -l | tr -d ' ')
    act=$(grep -al '^type: bugfix' "$r/.forge/specs/active"/*/manifest.yaml 2>/dev/null | wc -l | tr -d ' ')
    echo "$r | $v | bugfix arquivados=$arch | bugfix ativos=$act"
  done
axis-go-cloud       | template_version:"0.14.0"     | bugfix arquivados=27 | bugfix ativos=3
axis-fare-validator | template_version:"0.14.0"     | bugfix arquivados=19 | bugfix ativos=1
azim-crm            | template_version:"0.1.0-rc24" | bugfix arquivados=0  | bugfix ativos=3
forge-harness       | (dogfood, sem forge.yaml)     | bugfix arquivados=5  | bugfix ativos=0
Axis.PadSimulator   | template_version:"0.11.0"     | bugfix arquivados=0  | bugfix ativos=2
lionclaw            | template_version:"0.14.0"     | (sem specs)          | (sem specs)
```

E, contando só os `bugfix` arquivados que de fato têm artefato:

```
$ for r in axis-go-cloud axis-fare-validator forge-harness; do
    n=0
    for m in "$r"/.forge/specs/archived/*/manifest.yaml; do
      [ -f "$m" ] || continue; grep -q '^type: bugfix' "$m" || continue
      [ -f "$(dirname "$m")/evidence/red/red-evidence.json" ] && n=$((n+1))
    done
    echo "$r: bugfix arquivados COM artefato = $n"
  done
axis-go-cloud: 27
axis-fare-validator: 6
forge-harness: 5
```

| Classe | Quantos, medidos pelos comandos acima | O que acontece |
|---|---|---|
| Changes `bugfix` arquivados com evidência no formato de hoje | 27 em `axis-go-cloud`, 6 em `axis-fare-validator` (de 19 arquivados), 5 aqui | `normalizeEntries` sintetiza uma entrada `default` a partir dos escalares do topo; `check`, `status` e a resolução respondem exatamente como hoje. Cenário `[17]` fixa isso |
| Changes `bugfix` ativos com evidência pendente | 3 em `azim-crm`, 3 em `axis-go-cloud`, 1 em `axis-fare-validator`, 2 em `Axis.PadSimulator` | idem — sem `fixes_defects` no manifesto, a cobrança de D16 não se aplica e a única regra é "toda entrada resolvida", que para uma entrada é a regra de hoje |
| Harness instalado mais antigo lendo artefato novo | rc24 e 0.11.0 medidos em D11 | `validateRedEvidence` devolve `errors=[]` e a resolução lê o status derivado do topo — degradação conservadora, nunca erro de parse |
| `spec-verify.sh` de qualquer versão instalada | leitor medido em D11 | extrai `d.status` e aceita `observed` **ou** `waived`; com o status derivado ele continua correto sem mudança |
| Artefato novo validado estritamente contra o schema de hoje | medido com ajv 2020 em D17 | **reprova**; por isso D17 põe o schema no mesmo commit |
| Artefato novo cujo topo alguém editou à mão (ou um `git merge` resolveu pelo lado errado) | D19, sonda colada | o topo é reprojetado a partir de `entries` e o valor divergente é descartado — sem erro, sem fusão e sem travar o change. É a decisão que D19 toma em letra, e a alternativa (erro) está descartada com o motivo medido |

**O que quebra, dito em letra.** Um autor que hoje roda `record` duas vezes de propósito, para **substituir** a declaração anterior, passa a receber `rc≠0` e precisa de `--id`. É uma quebra de fluxo deliberada e é o ponto da onda; ela aparece no `CHANGELOG.md` como mudança de comportamento, e a mensagem de recusa diz qual `--id` usar para atualizar a entrada existente. **As oito fixtures de `w106`/`w107` listadas em D12b são a primeira consumidora dessa quebra**, e é por isso que elas foram medidas antes e não depois.

---

## 4. Onde entram PBT, contrato, integração e E2E

**PBT — aplica-se, e as propriedades estão medidas.** `template/.forge/scripts/lib/pbt.mjs` é o harness zero-dep do repositório, exercitado por `tests/w121-pbt-harness-gate.sh`, com `forAll`, geradores, shrinking e seed reprodutível. A derivação de status e a redução de resolução sobre uma lista são exatamente o espaço de entrada que a invariante 5 descreve. **São quatro propriedades, não três** — a revisão 1 tinha três porque `deriveStatus` e a resolução estavam confundidas em D11. O script está em §A.8.

```
=== CONTROLE ===
P1 deriveStatus-iff-todas-observed: OK (500 execuções, seed 20260908)
P2 derivacao-invariante-sob-permutacao: OK (500 execuções, seed 20260908)
P3 retrocompat-normalizacao: OK (500 execuções, seed 20260908)
P4 isResolvedMulti-iff-todas-resolvidas: OK (500 execuções, seed 20260908)
```

P1 é `deriveStatus(entries) === 'observed'` se e somente se toda entrada é `observed`. P2 é a invariância de `deriveStatus` **e** de `isResolvedMulti` sob permutação das entradas. P3 é a normalização de um artefato legado: exatamente uma entrada, com `id: 'default'`, preservando o status do topo. P4 é `isResolvedMulti(entries)` se e somente se toda entrada é `observed` ou `waived` — a propriedade que a segunda frase de D11 tentava enunciar e enunciava errado.

E medi que P1 **discrimina**: sob M2, ela reprova com contraexemplo minimizado, e as outras três continuam verdes.

```
=== M2 aplicada ===
P1 deriveStatus-iff-todas-observed: FALHOU [["pending","observed"]]
P2 …: OK
P3 …: OK
P4 …: OK
=== RECONTROLE ===
P1 deriveStatus-iff-todas-observed: OK (500 execuções, seed 20260908)
```

O contraexemplo é `[["pending","observed"]]` — duas entradas, uma pendente e uma observada, que é o menor caso em que o pior e o melhor divergem. *(A revisão 1 dizia `[[0]]`; esse valor não sai deste gerador e a afirmação estava errada.)* As quatro propriedades entram no gate como cenário próprio, com seed fixa para serem depuráveis.

**Contrato — aplica-se, em três fronteiras publicadas.** `spec-manifest.schema.json` e `red-evidence.schema.json` têm adotante instalado, e as duas mudam. `verification.schema.json` muda de descrição. Os cenários `[8]`, `[9]`, `[17]`, `[24]`, `[26]` e `[27]` são os testes de contrato — os dois últimos porque D19 e D21 são regras sobre a FORMA do artefato, e não sobre o comportamento de um comando; `tools/validate-forge.mjs`, que já roda por `tests/w20-spec-gate.sh:90`, é o backstop de ajv para o manifesto.

**Integração e canal — aplica-se, e é onde o defeito de #138 é de fiação e não de função.** Os cenários `[6]`, `[7]`, `[21]` e `[22]` exercem os quatro canais reais — `pre-push`, `red-evidence.sh ci`, `doctor.sh` e o `check` —, porque `rules/testing/gate-delivery-channel.md` exige que a prova aconteça pelo canal real e que ela distinga "não encontrei violação" de "não rodei". O sinal positivo de execução do `pre-push` é o contador de controle do próprio hook, que só é impresso quando `engaged=1`.

**E2E — não se aplica, e a justificativa é medida.** O caminho fim a fim do protocolo é `record → replay → verify → archive`, e o `replay` roda o motor real em worktree git efêmero. Esse caminho já tem cobertura E2E em `tests/w107-red-replay-gate.sh`, `tests/w108-red-graft-gate.sh` e `tests/w163-red-replay-shallow-clone-gate.sh`, e o que esta onda muda no `replay` é a **iteração** sobre entradas, não o motor. O que entra no gate desta onda é a asserção de que `ensure` **itera** — observável sem rodar o motor, pelo número de vereditos persistidos — e a asserção de que o motor foi chamado uma vez por entrada. **Aviso ao implementador:** `tests/w107-red-replay-gate.sh` no cenário `[19]` é sensível a temporização de sinal e reprova sob carga alta; se ele for executado durante esta onda, falha por carga não é defeito, e a suíte não tolera concorrência.

---

## 5. Contador de controle, com denominador fixo

O gate publica, na última linha, quantos cenários declarou e quantos executou, e reprova quando os dois divergem ou quando o executado é zero.

```
w<NNN>: DECLARADOS=<N>  EXECUTADOS=<N>
```

O denominador é o número de cenários do próprio gate — a única exceção legítima da invariante 14, porque é fixo por construção e a divergência é justamente o achado. **Nenhum outro número do gate é literal no fonte.** Em particular:

- `[15]` e `[16]` imprimem o contador `N/M` que o **achado** produziu naquela execução, e a asserção é sobre a presença do achado e sobre a nomeação do id faltante, nunca sobre o valor de `N/M`;
- `[6]`, `[7]` e `[21]` afirmam que a saída **nomeia** o change examinado, nunca que ela diz um número específico — o número muda com a fixture;
- `[25]` afirma que o achado **nomeia a entrada** pelo prefixo `[<id>]`, nunca quantos achados saíram;
- nenhum cenário conta arquivos de `tests/`, entradas de `machinery.lock` ou nodes do grafo.

Além do contador do gate, dois contadores de fora entram na definição de pronto porque envelhecem com esta entrega — o gate novo acrescenta um arquivo a `tests/`, então o badge muda no dia da entrega:

- o badge `gates-N` do `README.md:12`, conferido por `tests/w200-readme-inventory-gate.sh:253-272` contra `find tests -maxdepth 1 -name '*-gate.sh' | wc -l`;
- a linha `scripts/ (N)` da seção `## 📁 Estrutura` do `README.md:235`, conferida pelo mesmo gate com o critério `find "<root>/<dir>" -type f ! -name 'README.md'`.

Medi hoje:

```
$ grep -n 'gates-' README.md | head -1
12:[![Gates](https://img.shields.io/badge/gates-131%20passing-brightgreen.svg)](./tests)
$ find tests -maxdepth 1 -name '*-gate.sh' | wc -l
     131
$ grep -n 'scripts/ (' README.md | head -1
235:└── scripts/ (136)      # engine determinista …
$ find template/.forge/scripts -type f ! -name 'README.md' | wc -l
     136
```

**Os números não são alvo desta especificação** — o gate os deriva da árvore, e o implementador escreve o que a árvore disser depois da entrega. O que a definição de pronto exige é `w200` verde. A razão de estar escrito aqui é que duas especificações desta rodada esqueceram exatamente estas duas linhas, e esta onda **acrescenta** um gate, então o badge muda com certeza.

---

## 6. Invariante 15 — varredura das quatro dimensões: strings, sequências de chamada, escritas à mão e leituras diretas

A revisão 1 varreu strings e não varreu sequências de chamada; a revisão 2 varreu as duas e não varreu a terceira dimensão — as fixtures que **escrevem o artefato à mão**. Os bloqueadores 1 das duas rodadas nasceram exatamente daí, e o padrão é o mesmo: a varredura cobre a dimensão que a rodada anterior aprendeu e para nela. A seção agora tem **quatro** partes, e a quarta é a que faltava.

**A regra que sai disso, e ela é mais importante que a lista.** Uma mudança de contrato de artefato alcança uma fixture por quatro caminhos, não por um: (a) a **string** que ela afirma; (b) a **sequência de chamadas** que ela faz; (c) a **escrita direta** do artefato; (d) a **leitura direta** de um campo do artefato. As quatro precisam de varredura própria, com comando próprio, e nenhuma delas é derivável das outras — `w106:631` está em (b) e é invisível a uma varredura por sequência, e `w107:472` está em (c) e é invisível às três outras.

### 6.1 Strings de produção afirmadas por gate

Varri `tests/` por cada string que esta onda propõe mudar ou pode mudar, com `grep -arn -F`, e a medição de §1.0 mostra que a varredura lê todo o universo de `tests/` que não seja `.DS_Store`.

| String de produção | Quem afirma em `tests/` | Decisão |
|---|---|---|
| `change(s) type:bugfix examinado(s)` (contador do `pre-push`) | `tests/w107-red-replay-gate.sh:273`, `tests/w144-gate-control-counter-gate.sh:76` | **muda com D5.** Os dois gates são editados na mesma entrega e entram na definição de pronto |
| `type mudou` (WARN de item 3d) | `tests/w106-red-first-gate.sh:974` | **preservada por D6** — o texto novo continua contendo a substring. Se o implementador optar por texto sem ela, edita o `w106[17]` na mesma entrega |
| `n/a` (saída de não-aplicabilidade) | `tests/w106-red-first-gate.sh:513` (e `:972`, numa mensagem de FAIL do próprio gate) | **preservada** — o galho de `n/a` continua existindo para o change que não declara nada (D4, controle B medido) |
| `OK record` | `tests/w107-red-replay-gate.sh:61`, `tests/w107-red-replay-gate.sh:366`, `tests/w106-red-first-gate.sh:100`, `tests/w106-red-first-gate.sh:632` | **prefixo preservado.** A linha ganha o `[id]` e a contagem de entradas depois do prefixo; os quatro `grep -q "OK record"` continuam casando (medido: `OK record — [default] tests/A.cs declarado (status: pending, 1 entrada(s))`) |
| `feat-ci` ausente do relato de `red-evidence.sh ci` | `tests/w109-red-ci-gate.sh:99` (cria a fixture), `tests/w109-red-ci-gate.sh:102` (afirma a ausência) | **preservada** — a fixture cria `feat-ci --type feature` sem `fixes_defects`, e D4 garante que ela continua fora do universo mesmo depois de D1 alcançar o `ci` |
| `0 change(s) ativo(s)` | `tests/w144-gate-control-counter-gate.sh:97`, `tests/w109-red-ci-gate.sh:7` (comentário) | **preservada** — o vocabulário de vacuidade não muda |
| `universo-vazio` | `tests/w109-red-ci-gate.sh:53` e mais cinco gates alheios | **preservado** |
| `justificativa declarada` | `tests/w109-red-ci-gate.sh:32,58,59` e mais três gates alheios | **preservada** |
| `só se aplica a change type:bugfix`, `red-evidence só se aplica`, `OK ensure`, `PENDING (status` | nenhum gate afirma (`grep -arn -F` vazio, universo lido conforme §1.0) | livres para mudar |
| `só populado para change` (descrição de `red_first` em `verification.schema.json`) | nenhum gate afirma | livre (D8) |
| `red_first` (nome da chave) | `tests/w192-declared-switch-has-reader-gate.sh:176` | intocado — é regex de recorte sobre o nome, não sobre a descrição |
| `0 type:bugfix`, `$checked type:bugfix verificado(s)` e `$checked type:bugfix com Red observado ou dispensado` (as **três** strings do `ci`, `red-evidence.sh:99,100,101`) | nenhum gate afirma. `tests/w144-gate-control-counter-gate.sh:122` afirma só `2 change(s) ativo(s) examinado(s)`, que é o **prefixo** e não muda | **mudam com D1**, para o vocabulário `que corrigem defeito`. Sem consequência de gate, e estão listadas porque a revisão 2 as omitiu — é a mesma classe de enumeração conveniente que a onda vem corrigindo, agora sem dano |

O comando, e o controle positivo que o valida:

```
$ grep -arn -F 'type:bugfix' tests/ | grep -av '^tests/[^:]*:[0-9]*:#'
tests/w107-red-replay-gate.sh:273:grep -q "change(s) type:bugfix examinado(s)" <<<"$out" || …
tests/w144-gate-control-counter-gate.sh:76:  *"1 change(s) type:bugfix examinado(s)"*) : ;;
$ P="${TMPDIR%/}/l5r3/ctrl"; mkdir -p "$P"; printf 'change(s) type:bugfix examinado(s)\n0 type:bugfix\n' > "$P/plant.txt"
$ grep -arln -F 'type:bugfix' "$P"
/…/l5r3/ctrl/plant.txt
```

As demais ocorrências de `type:bugfix` em `tests/` são comentário ou `echo` de rótulo de passo (`w173:6,17,72,73`, `w107:267,277`, `w109:3`, `w144:16,20,58,77,113`), conferidas uma a uma; só as duas acima são asserção.

**Leituras diretas de campo do topo (dimensão (d)).** Varri quem lê um campo do artefato por `json_field`/`grep` em vez de pela saída de um comando, porque D19 muda quem escreve o topo:

```
$ grep -arn 'json_field "$EV8"\|grep -q ."waived_at\|grep -q ."base_strategy\|grep -q ."classification\|grep -q ."base_commit\|grep -q ."revert_patch\|grep -q ."replayed_at' tests/w10[6789]*.sh
tests/w107-red-replay-gate.sh:68:  '"classification": "behavioral"'   (bug-1)
tests/w107-red-replay-gate.sh:69:  '"base_commit": "'                  (bug-1)
tests/w107-red-replay-gate.sh:72:  '"base_strategy": "ancestry"'       (bug-1)
tests/w107-red-replay-gate.sh:73:  '"revert_patch": null'              (bug-1)
tests/w107-red-replay-gate.sh:75:  '"replayed_at": "'                  (bug-1)
tests/w107-red-replay-gate.sh:177: '"base_strategy": "revert-synthesis"' (bug-4)
tests/w107-red-replay-gate.sh:178: '"revert_patch": "'                 (bug-4)
tests/w108-red-graft-gate.sh:74:   json_field status                   (bug-8)
tests/w108-red-graft-gate.sh:75:   json_field base_strategy            (bug-8)
tests/w108-red-graft-gate.sh:76:   json_field classification           (bug-8)
tests/w108-red-graft-gate.sh:80:   json_field base_commit              (bug-8)
tests/w108-red-graft-gate.sh:81:   json_field graft_from               (bug-8)
tests/w106-red-first-gate.sh:487:  '"waived_at": "20'                  (bug-a)
```

Treze leituras diretas, sobre quatro changes — `bug-1`, `bug-4`, `bug-8` e `bug-a` —, e os quatro recebem `record` uma única vez (a linha do tempo de §6.2 confirma: `bug-1` em `w107:60`, `bug-4` em `w107:170`, `bug-8` em `w108:68`, `bug-a` em `w106:99` mais o re-`record` de `:242` sobre a mesma entrada). Uma entrada só ⇒ a projeção do topo é essa entrada, e os sete campos lidos (`status`, `classification`, `base_commit`, `base_strategy`, `revert_patch`, `replayed_at`, `graft_from`, `waived_at`) estão todos entre os **vinte** projetados por D19 — exceto `status`, que é derivado e, com uma entrada, coincide. **Nenhuma edição decorre desta dimensão**, e a afirmação vem com o comando porque a revisão 2 a levantou como risco em aberto sobre `w108`.

### 6.2 Sequências de chamada quebradas por D12 — a varredura que faltava

Está em D12b: **nove** sítios, nominais, em `tests/w106-red-first-gate.sh` (linhas 242, **631**, 713, 739, 769, 796) e `tests/w107-red-replay-gate.sh` (linhas 365, 457, 730). Cada um ganha `--id default`. **Esta é a lista que entra na definição de pronto.**

O comando que a produz, para o implementador refazer depois de qualquer rebase, é a **linha do tempo** e não a contagem — a contagem por change perde `w106:631`, cuja declaração veio de um heredoc:

```
$ for f in tests/w106-red-first-gate.sh tests/w107-red-replay-gate.sh; do
    echo "===== $f"
    grep -an 'record \(bug\|feat\)[a-z0-9-]*\|cat > "\$EV\|cat > "\$T2/.forge/specs/active/\$id/evidence\|d\.status = \|d\.waiver = \|d\.excerpt = \|d\.waiver\.deferral_id' "$f"
  done
```

A saída, condensada nos eventos que importam (`R` = chamada de `record`, `H` = escrita à mão):

```
w106  99 R bug-a | 135,140 H (forja 1) | 191,196 H (forja 2) | 242 R bug-a | 343 H | 386 H nogit
      533 H | 547 H | 562 H | 576 H | 593 H | 631 R bug-x | 689 R bug-d | 713,739,769,796 R bug-d
      862 H | 894 H | 913 H | 969 R bug-typechange
w107  60 R bug-1 | 106 R bug-2 | 138 R bug-3 | 170 R bug-4 | 185 R bug-5 | 196 R bug-6
      332,340 H (forja bug-9) | 365 R bug-9 | 406 R bug-11 | 443 R bug-12 | 457 R bug-12
      466 R bug-14 | 472 H (adultera excerpt) | 486 R bug-15 | 503 R bug-16 | 563 R bug-17
      598 R bug-18 | 649 R bug-19 | 720 R bug-20 | 730 R bug-20
```

Ela é a mesma varredura que produz §6.4, e é por isso que as duas dimensões saem de um comando só. **Se o implementador achar um décimo sítio ao rodar, ele entra na lista e o achado é registrado no PR.**

### 6.3 O espelho do plugin

`template/.forge/commands/testing/red.md` muda (D9), e o espelho `plugin/forge/commands/red.md` é hoje byte-idêntico (`cmp -s` sai `0`). A regeneração é `npm run build:plugin`, **nunca** `build-plugin.sh` — que instala em `$HOME` — sob pena de o `plugin-sync-gate` reprovar.

### 6.4 Fixtures que ESCREVEM o artefato à mão — a dimensão que faltava

D19 muda quem é a fonte, então toda fixture que escreve `red-evidence.json` sem passar por `record`/`replay`/`waive`/`init` precisa ser classificada. São **dez** sítios, produzidos pela varredura de §6.2, e o critério de classificação é único: **o artefato, no momento da escrita, já carrega a chave `entries`?** Se sim, a escrita no topo vira no-op para o leitor novo e a fixture quebra; se não, `normalizeEntries` sintetiza `default` a partir do que ela escreveu e a fixture sobrevive intacta.

| # | Sítio | O que escreve | Estado do artefato ali | Efeito de D19 |
|---|---|---|---|---|
| 1 | `w106:135-150` (forja 1 de `bug-a`) | dez escalares do topo, entre eles `status`, `test_path`, `command` | **tem `entries`** — vem do `record` de `:99` e do `replay` de `:101` | **QUEBRA** |
| 2 | `w106:191-206` (forja 2, `[3-FORJA/sem-FORGE_ROOT]`) | os mesmos dez escalares | **tem `entries`** | **QUEBRA** |
| 3 | `w106:343-344` (waiver colado à mão) | `status`, `waiver`, `waived_at` no topo | scaffold do `spec-new`, forma legada | ileso |
| 4 | `w106:386` (`mk_nogit_change`) | o artefato inteiro, por heredoc | criado do zero, forma legada | ileso |
| 5 | `w106:533,547,562,576,593` (cinco heredocs sobre `$EV_X`) | o artefato inteiro, por heredoc | substituem o scaffold, forma legada | ilesos — mas o de `:593` é o que declara `bug-x` e faz de `w106:631` o nono sítio de §6.2 |
| 6 | `w106:862-865` (waiver colado, dois motivos) | `status`, `waiver`, `waived_at` | scaffold do `spec-new`, forma legada | ileso |
| 7 | `w106:894-897` (waiver `hotfix-under-incident`) | idem | idem | ileso |
| 8 | `w106:913-914` (troca o `deferral_id`) | `waiver.deferral_id` | escrito por `:897`, forma legada | ileso |
| 9 | `w107:332-343` (forja de `bug-9`) | onze escalares do topo | scaffold do `spec-new` — o `record` de `bug-9` só vem em `:365` | ileso |
| 10 | `w107:469-475` (adultera o `excerpt` de `bug-14`) | `excerpt` no topo, **sem** recalcular `excerpt_sha256` | **tem `entries`** — `record` em `:466`, `replay` em `:467` | **QUEBRA** |

**As três que quebram, e por quê.** Nas três, a escrita cai num artefato cuja fonte já é `entries`, e o leitor novo simplesmente não a vê. O efeito é diferente em cada uma e nos três casos produz vermelho **contra a implementação correta**:

- Sítios 1 e 2 — o `ensure` de `validate-spec` passa a replayar o teste da **entrada**, que é o teste verdadeiro de `bug-a` e reproduz de fato; o veredito volta `observed`, o `rc` de `validate-spec` vira 0 e `tests/w106-red-first-gate.sh:174` (`[ "$rc_vs" -ne 0 ]`) e `:176` (`grep -q '"status": "observed"' "$EV_A" && FAIL`) disparam os dois.
- Sítio 10 — a adulteração do `excerpt` no topo é descartada na reprojeção, o `excerpt_sha256` volta a casar, e `tests/w107-red-replay-gate.sh:479` (`[ "$rc" -ne 0 ]`) e `:480` (`grep -qi "excerpt_sha256"`) disparam. **Este sítio a revisão 2 não achou**, porque ele não é uma "forja" no vocabulário do gate e não escreve `status`.

**A edição, e ela é a mesma nos três: a fixture escreve nos DOIS lugares.** Onde hoje há `d.status = …`, passa a haver o alvo resolvido antes:

```js
const t = (Array.isArray(d.entries) && d.entries.length) ? d.entries[0] : d;
t.status = "observed"; t.test_path = "…";   // e assim por diante, nos dez/onze campos
if (t !== d) Object.assign(d, { status: t.status, test_path: t.test_path, /* … */ });
```

Três propriedades dessa edição, e as três importam:

1. **Ela é retrocompatível.** Antes da implementação, `d.entries` não existe, `t` é `d`, e a fixture faz exatamente o que faz hoje. Ela pode entrar no repositório **antes** do código, o que é o que a ordem de §9 pede.
2. **Ela mantém a fixture honesta.** Um forjador humano competente forjaria os dois lugares, porque é o que o artefato mostra. Uma fixture que só forja o topo estaria testando o descuido do forjador, não o gate.
3. **Ela preserva o que os sítios 1, 2 e 10 existem para provar** — que o `ensure` reexecuta de verdade e reprova, e que a adulteração de `excerpt` é pega pelo `excerpt_sha256`. Com a forja na entrada, o `ensure` replaya o teste forjado (trivialmente verde na base), o veredito volta "não reproduz", `deriveStatus` do topo deixa de ser `observed` e o `grep` de `:176` volta a não achar nada — que é a asserção original, intacta.

**As três edições entram na definição de pronto, nominalmente**, ao lado das nove de §6.2. Os sete sítios ilesos entram também — como **asserção de que continuam ilesos**, porque "não precisa editar" é uma afirmação que envelhece: basta alguém acrescentar um `record` antes de um deles para virar o oitavo caso.

---

## 7. Invariante 17 — a enumeração e o caso que faltava

`isDefectFixing` e o vocabulário de status precisam de enumeração exaustiva, e procurei ativamente o caso não coberto em cada uma.

**Enumeração de `fixes_defects`.** Ausente; lista de strings não vazia; lista vazia; lista com string vazia ou só espaços; valor booleano; valor string; valor mapa; chave duplicada no YAML. Os oito estão cobertos e cada um tem desfecho escrito: ausente e lista vazia são "não declara" (`n/a`); lista não vazia declara; **string vazia dentro da lista é erro de declaração**, não elemento válido, porque um id vazio nunca casaria com entrada nenhuma e produziria um `CONFLICT` permanente sem remédio; booleano, string e mapa são erro de declaração (`[8]`, e o booleano e a string foram medidos — `declaração inválida em manifest.yaml: fixes_defects deve ser uma lista de identificadores, got: boolean (true)` e `got: string ("abc")`); chave duplicada é resolvida pelo leitor canônico e o gate afirma qual das duas vence, para que a resposta não dependa do leitor.

**Enumeração de status de entrada.** `pending`, `observed`, `waived`, `not-possible`, e o **quinto caso que a lista de quatro esconde**: entrada **sem** campo `status`. Ele existe porque `normalizeEntries` sintetiza uma entrada a partir de um artefato legado, e um artefato legado escrito à mão pode não ter `status`. Desfecho escrito e implementado na bancada: ausência de `status` na entrada — e valor fora do vocabulário — é tratada como `pending`, nunca como resolvida, e a normalização o materializa para que nenhum leitor posterior precise repetir a decisão.

**Enumeração de `entries`.** Ausente (legado, `[17]`); presente e vazia (`[24]`); presente com uma entrada; presente com N; **presente e DIVERGENTE do topo** (`[27]`, D19); **presente com dois ids iguais** (`[26]`, D21). Os dois últimos são os casos que a lista de quatro escondia, e os dois têm dono agora: divergência é resolvida pela entrada, sem erro; id repetido é erro de artefato. O caso `entries: []` é o que a redução por `every` aprovaria por vacuidade, porque `[].every(…)` é `true`. Medido na bancada: `vazia -> deriveStatus=pending isResolvedMulti=false`, porque `isResolvedMulti` exige `es.length > 0` antes da redução. Sem essa cláusula, um artefato com `entries: []` seria "resolvido" sem uma única prova, que é a invariante 3 aplicada dentro do próprio artefato.

**Enumeração de quem ESCREVE o artefato.** `record`, `replay`, `ensure`, `waive`, `init` — e o sexto escritor, que é a **fixture de gate** escrevendo à mão (dez sítios, §6.4). O sexto é o que a revisão 2 não enumerou, e ele existe porque a suíte precisa forjar estados que os cinco primeiros se recusam a produzir. Todo escritor, inclusive o sexto, escreve na entrada e reprojeta o topo.

**Enumeração do `status` da ENTRADA em `evaluateRedFirst`.** Com D20 os itens 1 a 8 rodam por entrada, e a pergunta "que entradas são avaliadas?" precisa de resposta exaustiva: **todas**, inclusive as `waived` (a política do waiver é reaplicada, como já é hoje no topo) e as `not-possible` (que produzem o achado de item 1). Entrada `pending` produz o achado de item 1 e nada mais — não faz sentido cobrar `excerpt` de quem ainda não replayou. A única exceção é a `waived`, para a qual o `ensure` não replaya (D15).

**Enumeração de `--id`.** Ausente (D12 decide pelo estado da entrada); id existente (atualiza); id novo (cria, sem herança); id com forma de flag (`[23]`, D18); id vazio. O último é o que a lista de quatro esconde: `--id ""` produziria uma entrada com id vazio, que nunca casa com `fixes_defects`. Desfecho escrito: id vazio ou só espaços é recusado pela mesma guarda de D18.

---

## 8. O que esta onda explicitamente NÃO faz

1. **Não fecha os três vetores adversariais da rule.** O `command` continua vindo do artefato que o autor escreve, o defeito artificial continua indistinguível do genuíno para o motor, e o waiver continua dependendo da palavra de quem o grava. A rule declara os três em letra e esta onda não muda isso — ela multiplica por N a superfície de declaração, e a revisão humana que os três exigem passa a ter N objetos em vez de um.
2. **Não faz o `pre-push` casar commit com change.** O furo medido em §1.2 — um `bugfix` alheio ativo satisfaz o denominador enquanto os commits `fix(...)` pertencem a outro change — só é fechado, por esta onda, para quem declara `fixes_defects`. Para quem não declara, ele permanece, e permanece nomeado.
3. **Não torna `fixes_defects` obrigatório para `type: bugfix`.** Seria a forma de exigir N provas de todo bugfix multi-defeito, e quebraria os 58 changes `bugfix` medidos (27+19+5 arquivados mais 3+3+1 ativos nos consumidores e aqui), todos sem o campo. Fica como candidato a onda futura, com migração.
4. **Não muda o formato de `evidence/red/` para múltiplos arquivos.** D10 registra a alternativa e o porquê.
5. **Não remove nem enfraquece o `red-first.yml` do GitHub Actions.** A autoridade dele é ser externo ao autor, e isso é propriedade do ambiente, não do script. `red-evidence.sh ci` passa a varrer o universo do predicado novo — é o sítio 10 de §2.1 e o cenário `[21]` —, e o workflow não muda.
6. **Não reconcilia com a Onda E nem com a issue #133.** Esta onda não toca `lib/arg-guards.sh` nem `lib/argparse.sh`. A flag `--id` que ela introduz passa pelo `parseFlags` local de `lib/red-evidence-ops.mjs:80-87`, que é código próprio do módulo, e D18 endurece **essa** flag sem migrar o parser. Registro isso porque o plano-mestre nomeia a reconciliação E×L4 como a única interação entre lotes, e esta onda não a amplia.
7. **Não migra artefato nenhum.** Não há script de migração e não é preciso: `normalizeEntries` faz a conversão na leitura, e o artefato só ganha `entries` no primeiro `record` posterior à atualização.
8. **Não decide o ordinal do gate.** É do orquestrador, uma vez, no momento de escrever o arquivo, conferido contra `origin/*` e contra as branches em voo (invariante 10).
9. **Não atualiza as cópias instaladas dos consumidores.** A entrega é do produtor; a propagação é `forge update` no consumidor, e a issue #101 e a Onda C tratam do que esse update faz com maquinaria local.
10. **Não decide o que `init` escreve quando o manifesto declara dois ids** — decide, sim, e a decisão é esta: `init` escaffolda **uma entrada por id declarado**, com todos os campos nulos, para que o fluxo natural (`init` → `record --id <um deles>`) já nomeie os alvos e o achado de cobertura fale de ids que existem no artefato. O `record` sem `--id` sobre esse scaffold recai no caso "nenhuma entrada declarada" de D12 e escreve na **primeira**, cujo id é o primeiro de `fixes_defects`. *(A revisão 1 deixava isso indecidido numa seção rotulada "FECHADAS"; o revisor tinha razão e o item saiu de ressalva para decisão. A revisão 2 justificava a regra dizendo que ela "mantém o cenário `[2]` determinístico"; determinismo não era o ponto, e o `[2]` daquela versão afirmava o nome errado da entrada — corrigido na §2.4 desta revisão.)*

**O risco que esta decisão cria, dito em letra.** Se o autor gravar primeiro o defeito que corresponde ao **segundo** id de `fixes_defects`, a cobertura sai 2/2 verde com os dois rótulos trocados: as duas entradas existem, as duas resolvem, e cada uma carrega o teste do outro defeito. É falha de **rotulagem**, não de contagem, e nenhum instrumento desta onda a detecta — o casamento é por id, e os dois ids existem. O que a onda entrega contra isso é a mensagem do `record`, que **nomeia a entrada em que gravou** (`OK record — [branding-preview-vars] tests/A.cs declarado …`, medido em D12): o autor vê o id no momento da gravação e percebe a troca. Não é uma garantia, é um aviso, e ele está aqui para que ninguém leia a cobertura verde como prova de que cada teste prova o defeito certo.

---

## 9. Ordem de execução e definição de pronto

**Ordem.** O predicado antes da lista, e a lista antes da cobrança — porque a cobrança de D16 lê os dois. Concretamente: (0) as **três** edições de fixture de §6.4, que são retrocompatíveis e por isso entram **antes** do código, para que o vermelho de cada etapa seguinte seja legível; (1) `fixes_defects` no schema do manifesto e o leitor canônico único, em `lib/defect-scope.mjs` (D1, D2, D3); (2) `entries` no schema da evidência, a normalização, a precedência e a projeção, a derivação de status e a redução de resolução (D10, D11, D17, D19, D21); (3) `record` com `--id` fail-closed, sem herança, e com a guarda de valor-com-forma-de-flag (D12, D13, D18) — e, no mesmo passo, as **nove** edições de `--id default` de §6.2; (4) `replay --id` e `ensure` iterando (D15); (5) `waive` por entrada (D14); (6) a asserção de cobertura e a avaliação por entrada (D16, D20); (7) os **onze** sítios de aplicabilidade passando a consultar o predicado — hook, `ci` e `doctor` incluídos (D5); (8) rules, comando e espelho do plugin (D6, D8, D9).

O vermelho é observado e registrado **antes** de cada uma dessas etapas, na etapa a que ela pertence, e não de uma vez no fim — a invariante 1 exige que o teste falhe pela ausência real da funcionalidade, e um gate escrito depois de tudo implementado não tem como provar isso.

**Definição de pronto.**

- Os **trinta** cenários do gate novo, com o contador de controle na última linha e o denominador batendo. A lista, para o denominador não envelhecer em silêncio: `[1] [2] [2b] [3] [3b] [4] [5] [6] [7] [8] [9] [10] [11] [12] [13] [13b] [14] [15] [16] [17] [18] [19] [20] [21] [22] [23] [24] [25] [26] [27]`. Conferida por `grep -ocE '^\| \[[0-9]+b?\] \|' <este arquivo> | wc -l`, que devolve `30`.
- As quatro propriedades PBT no gate, com seed fixa, e a demonstração de que P1 reprova sob M2 com o contraexemplo minimizado.
- A matriz de mutação com M1 a M10, cada uma com controle, contrafactual observado, restauração conferida por `sha256` **contra o arquivo já patchado** e recontrole — as saídas coladas no PR. As dez cobrem os dez cenários que podem ficar verdes por engano: M1→`[11]`, M2→`[13]`/`[13b]`, M3→`[12]`, M4→`[14]`, M5→`[4]`/`[5]`, M6→`[15]`, M7→`[6]`/`[7]`, M8→`[25]`, M9→`[27]`, M10→`[26]`. **M8 é a única cuja metade positiva a bancada não implementa** (§A.9): ela está medida pelo contrafactual, e o implementador fecha a outra metade quando implementar D20.
- `tests/w107-red-replay-gate.sh` e `tests/w144-gate-control-counter-gate.sh` editados para o vocabulário novo do contador do hook, e verdes.
- `tests/w106-red-first-gate.sh` e `tests/w107-red-replay-gate.sh` editados nos **nove sítios de re-`record`** listados em §6.2 — `w106:242, 631, 713, 739, 769, 796` e `w107:365, 457, 730` —, cada um ganhando `--id default`, e verdes. Se o implementador achar um décimo sítio ao rodar, ele entra na mesma lista e o achado é registrado no PR.
- `tests/w106-red-first-gate.sh` e `tests/w107-red-replay-gate.sh` editados nos **três sítios de escrita à mão** listados em §6.4 — `w106:135-150`, `w106:191-206` e `w107:469-475` —, cada um passando a escrever na primeira entrada e a reprojetar o topo, e verdes. Os **sete** sítios restantes de §6.4 continuam sem edição, e o PR registra que foram conferidos um a um.
- `tests/w108-red-graft-gate.sh` verde **sem edição**, e o PR cola a varredura de leituras diretas de §6.1 que sustenta essa previsão — se ele ficar vermelho, o conjunto projetado de D19 está errado e é ele que muda, não o gate.
- `tests/w106-red-first-gate.sh` verde no `[17]` sem edição, ou com a edição declarada, conforme D6.
- `tests/w109-red-ci-gate.sh` e `tests/w20-spec-gate.sh` verdes sem edição — o `w109` é o gate do canal `ci`, e ele é a prova externa de que `[21]` não quebrou o vocabulário de vacuidade.
- `tests/w200-readme-inventory-gate.sh` verde, com o badge e a linha `scripts/ (N)` atualizados para o que a árvore disser depois da entrega (o gate novo muda o badge com certeza).
- `npm run build:plugin` executado e `plugin/forge/commands/red.md` em paridade.
- `bash -n` limpo em todo shell tocado, e nenhum uso de `declare -A`, `${var,,}`, `${var^^}`, `mapfile` ou `readarray` — bash 3.2.
- `CHANGELOG.md` registrando a mudança de comportamento de `record` sem `--id`.
- Suíte inteira verde, rodada pelo orquestrador, serializada.
- Issues #138 e #139 fechadas com a prova de que o defeito descrito não reproduz mais, e com o registro de que o passo 7 de #138 não reproduzia no template pelos dois motivos de §1.2 — a defasagem da cópia rc24 e o `bugfix` alheio que satisfaz o denominador.

**Um registro que não é item de ledger e precisa sobreviver a esta onda.** A norma que as duas issues citam como autoridade vive na cópia enriquecida de um consumidor e não no template (§1.3). D9 traz a formulação por defeito para o template, mas a lição é mais larga que este arquivo: quando o campo enriquece uma rule, ele está dizendo que a norma do produto é fraca demais para o trabalho real dele, e hoje ninguém no produtor fica sabendo. `machinery.lock` grava o `sha256` do template por path e `check-machinery-drift.sh` o honra, então o sinal existe e não é lido nesta direção. Isso é matéria de outra onda, e fica escrito aqui para não sumir.

**Um segundo registro, do mesmo tipo, e ele é de método.** `template/.forge/scripts/lib/secret-scan.mjs` é invisível a `grep` sem `-a` (§1.0, LDG-0177). Enquanto o arquivo estiver assim, toda auditoria por texto sobre `template/` que não use `-a` produz falso-negativo silencioso — e o produto tem gates que auditam por texto. Escapar os bytes de controle no literal de regex é uma correção de uma linha que não pertence a esta onda, e fica aqui nomeada para não se perder.

---

## 10. Respostas ao veredito da revisão 1

### 10.1 Bloqueadores

**Bloqueador 1 — D12 derruba fixtures de `w106`/`w107` e a DoD afirmava o contrário. ACEITO, com a contagem corrigida.** Remedi a sequência de chamadas com `grep -n 'record ' tests/w10*.sh` e li cada sítio. O revisor descreveu doze chamadas sobre cinco changes; das doze, **oito** são a segunda-ou-posterior sobre entrada já declarada, e são essas oito que D12 recusa. *(A revisão 3 corrigiu esta contagem para **nove**: o critério "duas chamadas no mesmo change" perde `w106:631`, cuja declaração veio de um heredoc e não de um `record` anterior. Ver §6.2 e §11.3.)* A correção não é afrouxar D12: é D12b, que dá `--id default` às oito chamadas, apoiada na medição de que `--id` de entrada existente **atualiza** e que o prefixo `OK record` sobrevive. A DoD foi reescrita e a lista nominal está em §6.2. A seção §6 ganhou a parte que faltava — varredura de **sequência de chamada**, não só de string.

**Bloqueador 2 — contradição de três vias sobre o status derivado. ACEITO integralmente.** A segunda frase de D11 estava errada e saiu. O topo é o **pior status presente**, e ponto; "toda entrada resolvida" é outro predicado, `isResolvedMulti`, e agora tem propriedade própria (P4) e cenário próprio (`[13b]`, `[24]`). O caso `{observed, waived}` deriva `waived` e resolve `true` — medido, com controle e recontrole, em D11 e §A.7. O cenário `[18]` foi reescrito para dizer isso, e a regressão que o revisor nomeou (artefato legado `status: waived` normalizando para `observed`) não acontece: `normalizeEntries(legado status:waived) -> [["default","waived"]]` e `deriveStatus` devolve `waived`.

**Bloqueador 3 — a enumeração dos "nove sítios" é falsamente exaustiva. ACEITO integralmente, e a varredura foi refeita com `-a`.** São onze, e a tabela de §2.1 os lista com a linha conferida por `sed -n <linha>p`. `red-evidence.sh:66` (o laço do `ci`, braço do `red-first.yml`) e `doctor.sh:294` entraram em D1, na ordem de execução §9(7) e ganharam os cenários `[21]` e `[22]`. De quebra, corrigi D3: o idioma `awk` do `type` não está em dois sítios em shell, está em seis leitores (cinco deles red-first) e em dois idiomas diferentes.

**Bloqueador 4 — `[6]` e `[7]` asseram uma propriedade que a saída do hook não tem. ACEITO, e a decisão que faltava foi tomada.** Reproduzi o caminho positivo na minha própria bancada git e confirmei que o contador não nomeia change nenhum. D5 passou a decidir também o texto: o `scope` ganha `examinados: <ids>`. Medido com a decisão aplicada: `OK red-first/universo — 1 change(s) que corrigem defeito examinado(s) (…; examinados: pcx)` com `rc=0`. E, ao medir a mutação do canal (M7), descobri que a revisão 1 errava também na outra direção: `[7]` **não** é "verde por construção" — sob M7 ele fica vermelho por vacuidade. A matriz e a §2.5 registram que M7 derruba os dois cenários do canal juntos e que quem isola o efeito é o controle negativo `[5]`.

### 10.2 Medições sem lastro — o que foi remedido e o que saiu

Nove itens na lista do revisor. **Oito foram remedidos com o comando colado; um foi removido.**

1. **Tudo que exigia a implementação futura (controles de D4, regra de D12, C1/C2/C3 de D16, M1–M6, P1–P3).** REMEDIDO. Reconstruí a bancada inteira em `$TMPDIR/l5r2/impl`, aplicando os patches de D1/D10/D11/D12/D13/D16 sobre uma cópia de `template/.forge`. Todos os controles, mutações, restaurações e recontroles foram reexecutados em 2026-09-08, e os comandos de mutação estão colados linha a linha em §2.5 e §3.4. A mutação do canal (M7), que a revisão 1 declarava não ter medido, agora está medida. Um erro de baseline meu na primeira execução de M6 está relatado em §2.5, com a regra que sai dele.
2. **Os vereditos de ajv.** REMEDIDO, com o comando completo em D17, e com a nota de que o import precisa ser `ajv/dist/2020.js` — motivo pelo qual o revisor não repetiu. A frase imprecisa sobre `grep -rln "red-evidence.schema.json"` devolver "só `lib/red-evidence.mjs`" foi corrigida: sem escopo devolve onze arquivos, e a afirmação substantiva agora vem com escopo, `-a` e controle positivo plantado.
3. **A leitura do artefato novo pelos três harnesses instalados.** REMEDIDO. Montei as três bancadas, os três caminhos estão nominais em D11 e as três saídas foram reproduzidas.
4. **Os números da tabela de retrocompatibilidade da §3.5.** REMEDIDOS, com os dois laços de `for` colados. Um número mudou: `axis-fare-validator` tem 19 `bugfix` arquivados, dos quais **6** com artefato — a revisão 1 escrevia "19 (6 com artefato)" de modo que se lia como se os 19 tivessem artefato. A tabela agora separa as duas contagens. Acrescentei `Axis.PadSimulator` (2 ativos), que faltava.
5. **Cinco das oito linhas do censo da §1.4, mais a linha MULTI do `azim-crm`.** REMEDIDAS, uma a uma, com o `type:` e a ausência de `evidence/red/` conferidos e com a citação do arquivo e da linha em que o critério B casa. Duas correções saíram daí: o `reproduces` do `pipeline-stage-invariants` não é a string `§1.1`, é uma descrição em prosa do defeito do §1.1; e a regex do critério B da revisão 1 era estreita demais (não achava `tinha três defeitos medidos`), então a regex correta está declarada em §1.4.
6. **O diff da cópia rc24 do hook no consumidor e a ausência do `empty-universe-allowlist.txt`.** REMEDIDOS, com o laço de `grep -ac` sobre os três marcadores e o `ls -l` dos dois arquivos. De quebra corrigi um número: o consumidor tem **seis** changes ativos e **três** `bugfix`, não sete e dois.
7. **O texto exato do `WARN` da §2.2.** REMEDIDO. A saída reproduz quando o `excerpt_sha256` é o hash real do `excerpt`, e o script está em §A.3 com essa exigência em letra — que é exatamente o que faltava ao revisor.
8. **A afirmação de que este repositório não tem `bugfix` arquivado multi-defeito.** REMEDIDA. O critério A foi aplicado a cada um dos cinco, com o laço colado em §1.4; os cinco devolvem zero subseções `### 1.N`.
9. **A frase de §1.4 sobre "os cinco sítios" do plural `evidence/red/*.json`.** Não estava na lista do revisor como medição, e sim como ressalva, mas o método é o mesmo: REMEDIDA, e são **seis**, com `grep -arn` colado em §3.1.

**O que saiu por não ser remedível:** a afirmação da revisão 1 de que o contraexemplo minimizado de P1 sob M2 é `[[0]]`. Esse valor não sai do gerador que a bancada usa; o valor medido é `[["pending","observed"]]`, e é ele que está no documento. Nenhuma outra afirmação numérica foi mantida sem comando.

### 10.3 As demais ressalvas

- **Ponteiros de linha com desvio de ±1.** Conferi todos os âncoras do documento com `sed -n <linha>p`. O revisor está certo sobre `spec-verify.sh`: a guarda é `:118` e o `node -e` é `:121`, e as três citações de `:120` foram corrigidas. **Refuto a segunda parte com medição:** `lib/red-evidence-ops.mjs:114` está certo, não é `:115` — `grep -an 'if (!data.test_path' template/.forge/scripts/lib/red-evidence-ops.mjs` devolve `114`, e `sed -n 114p` devolve a linha da obrigatoriedade.
- **A prosa da §1.3 contra a própria tabela (lionclaw com 19 linhas).** Aceito e corrigido; a prosa estava errada, a tabela certa, e a medição está colada.
- **A enumeração dos sítios do plural.** Aceita e corrigida para seis, com a observação de que o sexto é um comentário sobre a remoção da entrada.
- **O mapeamento entre `fixes_defects` e os `entries[].id` iniciais.** Aceito: era um buraco numa seção rotulada "FECHADAS". A decisão está agora em §8, item 10 — `init` escaffolda uma entrada por id declarado.
- **`--id` passando pelo `parseFlags` sem guarda de valor-com-forma-de-flag.** Aceito, e promovido de ressalva a decisão: D18, com a medição que mostra a entrada `--setup-command` sendo criada, mais o cenário `[23]`. Medi também que `tests/w201-flag-como-valor-gate.sh` cobre apenas `ledger-ops`, `deferral-ops` e `liaison-ops`.
- **Saídas de bancada sem acentuação em §3.2 e §3.4.** Corrigido na fonte, não só na nota: a implementação da bancada agora emite `--id obrigatório: a evidência já declara …` com acentuação correta, e é essa a saída colada.

---

## 11. Respostas ao veredito da revisão 2

### 11.1 Bloqueadores

**NOVO 1 — a forja de artefato do `w106` morre com `entries`, e a definição de pronto afirma o contrário. ACEITO, e a varredura foi refeita na dimensão inteira, não no achado.**

O revisor está certo no diagnóstico e certo na causa: a §6 varreu strings e sequências de chamada e não varreu as fixtures que **escrevem** o artefato. Remedi antes de aceitar. A sonda de D19 reproduz o mecanismo com o artefato exatamente na forma que a forja produz — `entries` com a declaração real, topo forjado — e mostra o leitor decidindo pela entrada e o topo reprojetado voltando a `pending` e ao `test_path` verdadeiro; com isso o `ensure` replaya o teste real, o veredito volta `observed` e `tests/w106-red-first-gate.sh:174` e `:176` disparam os dois, como o revisor previu.

**A varredura completa achou dez sítios, não dois, e um deles o revisor não tinha.** `tests/w107-red-replay-gate.sh:469-475` adultera o `excerpt` de `bug-14` no topo, **depois** de `record` (`:466`) e `replay` (`:467`), para provar que o `excerpt_sha256` deixa de casar; com D19 a adulteração é descartada na reprojeção, o hash volta a casar, e `w107:479` e `:480` ficam vermelhos contra a implementação correta. Ele não aparece numa busca por "forja" porque não escreve `status` e o gate não o chama assim. A tabela dos dez está em §6.4, com o critério de classificação em letra (o artefato já carrega `entries` naquele ponto?), as três que quebram nomeadas, e as sete ilesas nomeadas também — como asserção de que continuam ilesas, porque "não precisa editar" é uma afirmação que envelhece.

**A decisão em aberto que o revisor identificou por baixo do achado virou D19**, e ela é a peça que faltava: a **presença** da chave `entries` decide a fonte; presente, `entries` vence e o topo em disco é descartado sem virar erro; ausente, o topo é a fonte e a normalização sintetiza `default`. O conjunto projetado são os **vinte** campos por defeito, e a enumeração não é conveniente — é o `properties` do schema menos `schema`, `change_id`, `status` e `entries`. Com isso as duas consequências que o revisor levantou ficam decididas e medidas: `tests/w106-red-first-gate.sh:487` (`waived_at`) e `tests/w108-red-graft-gate.sh:75,76,80,81` (`base_strategy`, `classification`, `base_commit`, `graft_from`) leem campos que estão entre os vinte, sobre changes de **uma entrada** — a varredura de leituras diretas está em §6.1 e devolve treze sítios sobre quatro changes, todos de um `record` só. Nenhuma edição decorre daí, e a previsão está na definição de pronto como asserção (`w108` verde sem edição), não como afirmação.

**A edição das três fixtures é retrocompatível e entra ANTES do código**, no passo (0) da ordem de §9: a fixture resolve o alvo (`d.entries[0]` quando existe, `d` quando não) e escreve nos dois lugares, que é o que um forjador humano competente faria e o que preserva a asserção original.

**NOVO 2 — o cenário `[2]` assere a entrada `default` num fixture em que ela não nasce. ACEITO integralmente.**

O revisor está certo: o `[1]` cria um change com `fixes_defects` de dois ids, e o §8 item 10 — que a revisão 2 promoveu de ressalva a decisão — manda `init` escaffoldar uma entrada por id declarado, então o artefato nasce com `branding-preview-vars` e `branding-save-silent` e nenhuma `default`. Ele está certo também sobre o remédio de menor esforço e por que ele é ruim: fazer `init` sempre criar `default` desfaz o item 10 e devolve o achado de cobertura falando de ids que não existem no artefato. Adotei a correção que ele indicou — `[2]` passa a afirmar que a declaração é gravada na **primeira entrada escaffoldada**, cujo id é o primeiro de `fixes_defects`, e que a linha `OK record` **nomeia** esse id.

Três coisas saíram de brinde, e as três fecham buracos que o `[2]` errado escondia:

- **`[1]` ficou sem asserção nenhuma sobre o item 10.** A decisão existia desde a revisão 2 e nenhum cenário a exercitava. `[1]` passa a afirmar que o artefato nasce com **duas** entradas, com os ids na ordem de `fixes_defects`, e que **nenhuma** se chama `default`.
- **Nasceu `[2b]`**, o caso do scaffold **legado** (`type: bugfix` sem `fixes_defects`, artefato do `templates/bugfix/red-evidence.json`, que não tem `entries`), em que `default` continua sendo o id certo. Ele é o cenário que sustenta o `--id default` dos nove sítios de §6.2 — sem ele, aquela edição fica apoiada numa afirmação sem contrafactual.
- **A frase "mantém o cenário `[2]` determinístico" saiu do item 10.** Determinismo não era o ponto, como o revisor escreveu, e a frase existia para justificar uma asserção errada.

### 11.2 As ressalvas — todas fechadas, e uma delas era pior que ressalva

**A avaliação dos itens 1 a 8 POR ENTRADA. ACEITA e promovida a decisão (D20), porque a medição é pior que o enunciado.** O revisor descreveu o risco como "cobertura N/N verde com N-1 entradas nunca avaliadas". Montei a fixture `C4` — dois ids declarados, duas entradas `observed`, a segunda com `excerpt` de erro de build declarado `behavioral` e que não casa com o `failure_pattern` — e o resultado é `rc=0`, **zero achados bloqueantes**: não é só cobertura enganosa, é um change que **passa** carregando a evidência que o mesmo instrumento reprova quando o defeito é um só. D20 decide a iteração e o prefixo `[<id>]` em cada achado; `[25]` cobre; e a §7 ganhou a enumeração de quais entradas são avaliadas (todas, e o que cada status produz).

**O sub-relato do contador do hook calculado sobre `fix_files` da primeira entrada. ACEITA**, e virou a terceira parte de D5: o sub-relato passa a falar da **união** dos `fix_files` de todas as entradas e a dizer isso em letra (`N sem interseção com a união dos fix_files declarados`). Está no patch do hook em §A.5, colado.

**As duas strings de produção do `ci` que a §6.1 não listava. ACEITA, e são três, não duas.** `red-evidence.sh:99,100,101` — `0 type:bugfix`, `$checked type:bugfix verificado(s)` e `$checked type:bugfix com Red observado ou dispensado`. As três entraram na tabela. Confirmei a ausência de consequência com a varredura completa de `type:bugfix` em `tests/`, com controle positivo plantado: só `w107:273` e `w144:76` são asserção; as demais treze ocorrências são comentário ou `echo` de rótulo, conferidas uma a uma. `w144:122` afirma `2 change(s) ativo(s) examinado(s)`, que é o prefixo e não muda.

**O risco de rotulagem do §8 item 10. ACEITA e nomeada em letra**, no próprio item: se o autor gravar primeiro o defeito do segundo id, a cobertura sai 2/2 verde com os rótulos trocados, e nenhum instrumento desta onda detecta — o casamento é por id e os dois ids existem. O que a onda oferece contra isso é a mensagem do `record`, que nomeia a entrada em que gravou; está escrito que é aviso e não garantia.

**O título do §A prometendo scripts e entregando prosa. ACEITA, e a saída foi colar os patches, não mudar o título.** O §A traz agora, na íntegra: o script do `pre-push` (A.1), o dos quatro escritores (A.2), o do `WARN` (A.3), o fonte inteiro de `lib/defect-scope.mjs` mais o patch de `check-red-first.mjs` (A.4), o patch do hook e o da mutação M7 (A.5), o corpo novo de `cmdRecord` (A.6), o bloco aditivo de `red-evidence.mjs` e as duas sondas (A.7) e o script das quatro propriedades (A.8). Acrescentei um **A.9** dizendo o que continua fora do alcance: a bancada não implementa D14, D15, D20 nem D21 — essas quatro estão medidas pelo contrafactual — e nenhum gate da suíte foi executado.

### 11.3 O que a remedição corrigiu no próprio documento

Cinco afirmações da revisão 2 caíram quando refiz a medição, e elas estão corrigidas na fonte, não só anotadas:

1. **"Os oito sítios de re-`record` são exatamente os que reincidem sobre entrada já declarada."** São **nove**. O critério "duas chamadas de `record` no mesmo change" perde `tests/w106-red-first-gate.sh:631`, que é a **primeira** chamada sobre `bug-x` — mas o artefato foi declarado à mão pelo heredoc de `:593`, cujo conteúdo traz `"test_path": "tests/bug-x.spec.ts"`. O revisor confirmou os oito com o mesmo critério errado que eu usei, e o achado é meu. A varredura correta é a **linha do tempo** de chamadas e escritas, e está colada em §6.2.
2. **"Os três casos C1/C2/C3 saem `rc=1`."** Falso, e era artefato da minha fixture: os `entries` de C1/C2/C3 não tinham os campos de replay, então o topo projetado saía vazio e os itens 2/3 disparavam sozinhos. Remontadas com entradas completas, **C2 sai `rc=0`**, que é o que tem de sair. A frase saiu e as três caixas foram recoladas.
3. **"Sob M1, o segundo `record` sem `--id` continua sobrescrevendo."** A medição desta revisão mostra outra coisa: sob M1 nasce uma **segunda entrada com o id `default`**. É desse achado que sai D21 (id repetido é erro de artefato), porque `resolvidas` é um `Set` e dois ids iguais — um `observed`, um `pending` — fazem o defeito sem prova sumir do relato.
4. **"O contador do hook, no caminho positivo, é o único ponto."** A fixture de `[7]` que eu tinha em mente não serve: com uma entrada `waived` de `reason: non-behavioral` e `fix_files` tocando o arquivo empurrado, o hook bloqueia pela política do waiver, não pelo tipo. A obrigação está agora escrita em §2.4, com a saída colada — `[7]` precisa de uma entrada `observed` internamente consistente, e é essa que produz `rc=0` com o contador nomeando `pcx`.
5. **`change_id:` no `manifest.yaml` das minhas bancadas.** A chave real é `id:`, e o sintoma foi a mensagem `escaffolde com 'red-evidence.sh init undefined'`, que eu quase colei como defeito do produto. Corrigido nas bancadas e nomeado em §A.2, porque é o tipo de erro que produz um "achado" convincente e falso.

Um sexto item é de método e não de conteúdo: li o `rc` do hook através de um pipe (`printf | hook | head`) e o `PIPESTATUS[0]` me devolveu o `rc` do `printf`, fazendo a medição do universo vazio parecer `rc=0` quando o hook havia saído `rc=1`. `feedback-suite-sem-concorrencia` já registra que `rc` de gate nunca se lê por pipe; refiz por redirecionamento de arquivo, e a invocação correta está colada em §A.5.

### 11.4 O que o revisor mediu e eu conferi antes de aceitar

Remedi, com comando meu, tudo que o veredito afirma ter reproduzido, e as afirmações batem: os **onze** âncoras de aplicabilidade (`grep -arnE '"bugfix"|= .bugfix.'` sobre `template/.forge/{scripts,hooks}` devolve dezesseis linhas, das quais onze são red-first — `spec-new.sh:81`, `spec-transition.sh:82` e `validate-spec.mjs:133,255,264` são sobre `scale`/`design.md`/`requirements`, não sobre red-first); o badge `gates-131` contra `find tests -maxdepth 1 -name '*-gate.sh' | wc -l` = 131 e `scripts/ (136)` contra 136 arquivos; a cobertura do `w201` (`ledger-ops`, `deferral-ops`, `liaison-ops`, e nada mais); `record` uma vez por change em `w108` (`:68`) e `w109`; e as duas asserções do contador do hook em `w107:273` e `w144:76`. A única correção de endereço é interna a esta revisão e já está no texto: `tests/w106-red-first-gate.sh:174`, não `:173`, é a linha do `[ "$rc_vs" -ne 0 ]`.

---

## A. Bancadas — os scripts e os patches, na íntegra

Todas as bancadas rodam sob `$TMPDIR`, com `cwd` dentro da fixture, e nenhuma escreve em arquivo rastreado do repositório. `TPL` é `/Users/milton/Documents/projects/forge-harness/template`, e a raiz da bancada desta revisão é `$TMPDIR/l5r3`.

**O que mudou nesta revisão, e por quê.** A revisão 2 prometia "os scripts" e entregava receita em prosa — "um patch em `lib/check-red-first.mjs` que (a) exporta … (b) troca …" —, e o revisor registrou, com razão, que essa era a única classe de medição do documento fora do alcance de um terceiro. Os patches estão colados abaixo, na íntegra, e é sobre eles que rodam os controles de D4, D11, D12, D13, D16, D18, D19, D20 e D21, as mutações M1 a M7 e as propriedades P1 a P4. A montagem inteira, na ordem:

```
$ B="${TMPDIR%/}/l5r3"; rm -rf "$B"; mkdir -p "$B"
$ TPL=/Users/milton/Documents/projects/forge-harness/template
$ cp -R "$TPL/.forge" "$B/.forge"
$ cat patch-A7.mjs >> "$B/.forge/scripts/lib/red-evidence.mjs"      # A.7
$ cp defect-scope.mjs "$B/.forge/scripts/lib/"                      # A.4
$ python3 aplica-A6.py "$B"                                         # A.6 — troca o corpo de cmdRecord
$ python3 aplica-A4.py "$B"                                         # A.4 — predicado + cobrança
$ cp "$B/.forge/scripts/lib/red-evidence.mjs"     "$B/E.impl"       # baselines de mutação:
$ cp "$B/.forge/scripts/lib/red-evidence-ops.mjs" "$B/R.impl"       #   sempre o arquivo JÁ
$ cp "$B/.forge/scripts/lib/check-red-first.mjs"  "$B/C.impl"       #   PATCHADO, nunca o de partida
```

A última linha é a lição de `feedback-mutacao-fantasma-restore` transformada em passo: **o baseline de uma prova de mutação é a implementação sob teste, não o estado de onde ela partiu**, e o `cmp`/`sha256` da restauração só vale contra esse baseline.

### A.1 — o `pre-push` do template (§1.2)

```bash
#!/usr/bin/env bash
# A.1 — o pre-push do TEMPLATE (§1.2). Mede o desfecho de hoje: feature com 2 commits fix(...)
# mais um bugfix ALHEIO com waiver, cujos fix_files não intersectam a faixa.
set -euo pipefail
TPL="${TPL:-/Users/milton/Documents/projects/forge-harness/template}"
B="${TMPDIR%/}/l5r3/push"; rm -rf "$B"; mkdir -p "$B/.forge" "$B/src"
cp -R "$TPL/.forge/scripts" "$TPL/.forge/hooks" "$TPL/.forge/rules" "$B/.forge/"
mkdir -p "$B/.forge/specs/active/pcx" "$B/.forge/specs/active/outro-bugfix/evidence/red"
printf 'change_id: pcx\ntype: feature\nscale: 2\nstatus: implementing\nfixes_defects: [branding-preview-vars]\n' > "$B/.forge/specs/active/pcx/manifest.yaml"
printf 'change_id: outro-bugfix\ntype: bugfix\nscale: 1\nstatus: implementing\n' > "$B/.forge/specs/active/outro-bugfix/manifest.yaml"
cat > "$B/.forge/specs/active/outro-bugfix/evidence/red/red-evidence.json" <<'JSON'
{ "schema": "red-evidence/v1", "change_id": "outro-bugfix", "status": "waived",
  "test_path": null, "test_id": null, "command": null, "failure_pattern": null,
  "fix_files": ["src/nada-a-ver.mjs"], "waiver": { "reason": "non-behavioral", "note": "sem relação com a faixa" },
  "recorded_at": "2026-09-01T00:00:00.000Z", "waived_at": "2026-09-01T00:00:00.000Z" }
JSON
cd "$B"
git init -q . && git config user.email t@t && git config user.name t
printf 'export const a = 1;\n' > src/app.mjs
git add -A && git commit -qm "chore: base"
git update-ref refs/remotes/origin/develop HEAD
printf 'export const a = 2;\n' > src/app.mjs; git add -A; git commit -qm "fix(app): corrige a"
printf 'export const b = 3;\n' >> src/app.mjs; git add -A; git commit -qm "fix(app): corrige b"
LOCAL="$(git rev-parse HEAD)"; REMOTE="$(git rev-parse refs/remotes/origin/develop)"
echo "== hook do TEMPLATE, feature com 2 commits fix(...) + 1 bugfix alheio com waiver =="
set +e
printf 'refs/heads/develop %s refs/heads/develop %s\n' "$LOCAL" "$REMOTE" \
  | FORGE_ROOT="$B" bash .forge/hooks/git/lib/check-red-first.sh origin "$B" 2>&1
echo "rc=$?"
set -e
echo "== o mesmo push SEM o bugfix alheio (universo vazio) =="
rm -rf "$B/.forge/specs/active/outro-bugfix"
set +e
printf 'refs/heads/develop %s refs/heads/develop %s\n' "$LOCAL" "$REMOTE" \
  | FORGE_ROOT="$B" bash .forge/hooks/git/lib/check-red-first.sh origin "$B" 2>&1 | head -4
echo "rc=${PIPESTATUS[0]}"
set -e
```

### A.2 — a recusa dos quatro escritores (§2.1)

```bash
#!/usr/bin/env bash
set -euo pipefail
TPL="${TPL:-/Users/milton/Documents/projects/forge-harness/template}"
B="${TMPDIR%/}/l5r3/feat-root"; rm -rf "$B"; mkdir -p "$B/.forge"
cp -R "$TPL/.forge/scripts" "$TPL/.forge/rules" "$TPL/.forge/templates" "$B/.forge/"
D="$B/.forge/specs/active/platform-config-ux"; mkdir -p "$D"
printf 'id: platform-config-ux\ntype: feature\nscale: 2\nstatus: implementing\n' > "$D/manifest.yaml"
cd "$B"
echo "== 1. tipo =="; grep '^type:' "$D/manifest.yaml"
for cmd in \
  "red-evidence.sh init platform-config-ux" \
  "red-evidence.sh record platform-config-ux --test-path t --test-id i --command c --failure-pattern p" \
  "red-evidence.sh replay platform-config-ux" \
  "check-red-first.sh waive platform-config-ux --reason non-behavioral --note n" \
  "check-red-first.sh check platform-config-ux" \
  "check-red-first.sh status platform-config-ux"; do
  echo "--- $cmd ---"
  set +e; FORGE_ROOT="$B" bash ".forge/scripts/$cmd" 2>&1; echo "rc=$?"; set -e
done
```

**Atenção à chave do manifesto:** é `id:`, não `change_id:`. Escrevi `change_id:` na primeira montagem desta revisão e a mensagem de erro saiu `escaffolde com 'red-evidence.sh init undefined'` — que eu quase colei como se fosse defeito do produto. `head -5 .forge/specs/archived/2026-09-04-gate-assert-visibility/manifest.yaml` devolve `id: gate-assert-visibility`, e é isso que as fixtures precisam escrever.

### A.3 — o `WARN` do item 3d (§2.2)

A condição necessária, que é o que faltava ao revisor, está comentada no próprio script: `excerpt_sha256` tem de ser o sha256 **real** do `excerpt`, porque o galho de `check-red-first.mjs:174-177` só dispara quando `!errors.length`.

**Duas armadilhas desta bancada, as duas caídas por mim antes de corrigir.** A primeira é `process.argv` sob `node -e`: com `-e`, `argv[1]` já é o **primeiro argumento**, e não o caminho do script — a desestruturação correta é `const [,p,exc,hsh] = process.argv`, e a errada (`[,,p,exc,hsh]`) não falha, ela escreve num arquivo cujo nome é o próprio `excerpt`, no `cwd` do shell. A segunda decorre da primeira: como o `cd "$B"` do script vem **depois** da escrita, esse arquivo espúrio nasce no diretório de onde a bancada foi invocada — no meu caso, a raiz do repositório, que é exatamente o que a regra "bancada em `$TMPDIR`, `cwd` dentro da fixture" existe para impedir. Removido; e é por isso que o `cd "$B"` correto vem **antes** de qualquer escrita, não depois.

```bash
#!/usr/bin/env bash
# A.3 — o WARN do item 3d (§2.2). O mesmo diretório de change, o mesmo artefato forjado,
# variando APENAS o `type` do manifesto. Roda contra o template PRISTINO.
set -euo pipefail
TPL="${TPL:-/Users/milton/Documents/projects/forge-harness/template}"
B="${TMPDIR%/}/l5r3/warn"; rm -rf "$B"; mkdir -p "$B/.forge"
cp -R "$TPL/.forge/scripts" "$TPL/.forge/rules" "$B/.forge/"
D="$B/.forge/specs/active/pcx"; mkdir -p "$D/evidence/red"
printf 'id: pcx\ntype: feature\nscale: 2\nstatus: implementing\n' > "$D/manifest.yaml"
# CONDIÇÃO NECESSÁRIA: excerpt_sha256 tem de ser o sha256 REAL do excerpt — o galho do item 3d
# (lib/check-red-first.mjs:174-177) só dispara quando !errors.length, e foi por não fazer isso
# que a medição pareceu irreprodutível.
EXC='npm ERR! missing script: test'
HSH="$(node -e "process.stdout.write(require('crypto').createHash('sha256').update(process.argv[1]).digest('hex'))" "$EXC")"
node -e '
const fs=require("fs"); const [,p,exc,hsh]=process.argv;
fs.writeFileSync(p, JSON.stringify({
  schema:"red-evidence/v1", change_id:"pcx", status:"observed",
  test_path:"tests/pcx.test.mjs", test_id:"pcx-regression", command:"node --test tests/pcx.test.mjs",
  base_commit:"0123456", failure_pattern:"AssertionError", excerpt:exc, excerpt_sha256:hsh,
  classification:"behavioral", base_result:"failed", base_strategy:"ancestry", revert_patch:null,
  graft_from:null, replay_head:null, setup_command:null, reproduces:"bugfix.md §1",
  fix_files:["src/pcx.mjs"], waiver:null,
  recorded_at:"2026-09-01T00:00:00.000Z", replayed_at:"2026-09-01T00:00:01.000Z", waived_at:null
}, null, 2)+"\n");' "$D/evidence/red/red-evidence.json" "$EXC" "$HSH"
cd "$B"
for t in feature bugfix; do
  perl -pi -e "s/^type: .*/type: $t/" "$D/manifest.yaml"
  echo "== type: $t =="
  set +e
  FORGE_ROOT="$B" bash .forge/scripts/check-red-first.sh check pcx > "$B/o.txt" 2>&1
  echo "rc=$?"
  set -e
  cat "$B/o.txt"
done
```

### A.4 — o predicado, a declaração inválida e a cobrança (D1, D2, D3, D16, D20, M5, M6)

O arquivo novo, na íntegra. É o "único ponto" que D3 exige, e é separado de `check-red-first.mjs` porque `red-evidence-ops.mjs` também precisa do predicado e o import cruzado fecharia um ciclo.

`lib/defect-scope.mjs`:

```js
// lib/defect-scope.mjs — L5 / D1, D2, D3. O ÚNICO ponto do repositório que responde
// "este manifesto declara defeitos corrigidos, e quais". Todo consumidor — JS ou shell —
// passa por aqui; nenhum inventa uma segunda regra de extração (lição de
// project-strix-pentest-profile: leitor novo de um arquivo com leitor canônico HERDA a
// regra de extração).
import { readFileSync, existsSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { parseYamlSubset } from './yaml-lite.mjs';

// fixesDefects(man) -> { declared: bool, ids: string[], error: string|null }
// Três estados, nunca dois: declara / não declara / declaração inválida.
export function fixesDefects(man) {
  const none = { declared: false, ids: [], error: null };
  if (!man || typeof man !== 'object') return none;
  const v = man.fixes_defects;
  if (v === undefined || v === null) return none;
  if (!Array.isArray(v)) {
    const got = typeof v === 'object' ? 'map' : typeof v;
    return { declared: false, ids: [], error: `declaração inválida em manifest.yaml: fixes_defects deve ser uma lista de identificadores, got: ${got} (${JSON.stringify(v)})` };
  }
  if (!v.length) return none; // lista vazia = não declara (§7)
  const bad = v.filter((x) => typeof x !== 'string' || !x.trim().length);
  if (bad.length) return { declared: false, ids: [], error: `declaração inválida em manifest.yaml: fixes_defects contém ${bad.length} identificador(es) vazio(s) ou não-string — um id vazio nunca casaria com entrada nenhuma` };
  return { declared: true, ids: v.map((s) => s.trim()), error: null };
}

// isDefectFixing(man): o predicado de aplicabilidade dos ONZE sítios (D1).
// Declaração inválida NÃO é "não se aplica": é erro, e quem chama precisa distinguir —
// por isso o erro sai por fixesDefects() e este predicado é só o galho feliz.
export function isDefectFixing(man) {
  return !!man && (man.type === 'bugfix' || fixesDefects(man).declared);
}

export function readManifestAt(changeDir) {
  const p = join(resolve(changeDir), 'manifest.yaml');
  if (!existsSync(p)) return null;
  try { return parseYamlSubset(readFileSync(p, 'utf8')); } catch { return null; }
}

// CLI para os cinco leitores em shell (D3): imprime "yes"/"no"/"err: …" e os ids.
if (import.meta.url === `file://${process.argv[1]}`) {
  const man = readManifestAt(process.argv[2] || '.');
  const fd = fixesDefects(man);
  if (fd.error) { console.log(`err: ${fd.error}`); process.exit(2); }
  console.log(`${isDefectFixing(man) ? 'yes' : 'no'}\t${fd.ids.join(',')}`);
}
```

O patch em `lib/check-red-first.mjs` (`aplica-A4.py`) é o que a bancada aplicou, e ele faz quatro coisas: acrescenta os dois imports; insere o galho de declaração inválida e troca `if (man.type !== 'bugfix')` por `if (!isDefectFixing(man))` no topo de `evaluateRedFirst`; troca a mensagem do item 1 que afirma `type:bugfix`; e insere o bloco de cobertura logo depois de `const data = …`:

```python
import sys, pathlib
p = pathlib.Path(sys.argv[1], '.forge/scripts/lib/check-red-first.mjs'); s = p.read_text()
s = s.replace("import { loadRedEvidence",
              "import { fixesDefects, isDefectFixing } from './defect-scope.mjs';\n"
              "import { normalizeEntries, loadRedEvidence", 1)
s = s.replace("""export function evaluateRedFirst(changeDir) {
  const man = readManifest(changeDir);
  if (!man) return { manifestError: true };
  if (man.type !== 'bugfix') {""",
"""export function evaluateRedFirst(changeDir) {
  const man = readManifest(changeDir);
  if (!man) return { manifestError: true };
  // D2 — declaração inválida é TERCEIRO ESTADO: nunca 'n/a', nunca CONFLICT de evidência.
  const fd = fixesDefects(man);
  if (fd.error) {
    return { applicable: true, type: man.type, findings: [{ enforceable: true, msg: fd.error }], status: null, changeId: man.id };
  }
  if (!isDefectFixing(man)) {""", 1)
s = s.replace("change type:bugfix sem evidência de Red (item 1,",
              "change que corrige defeito sem evidência de Red (item 1,", 1)
s = s.replace("  const data = ev.exists && !ev.errors.length ? ev.data : null;",
"""  const data = ev.exists && !ev.errors.length ? ev.data : null;

  // D16 — cobrança por defeito declarado. O achado NOMEIA quantos de quantos e QUAIS faltam.
  if (fd.declared) {
    const entries = data ? normalizeEntries(data) : [];
    const resolvidas = new Set(entries.filter((e) => e.status === 'observed' || e.status === 'waived').map((e) => e.id));
    const sem = fd.ids.filter((id) => !resolvidas.has(id));
    if (sem.length) {
      findings.push({ enforceable: true, msg: `${fd.ids.length - sem.length}/${fd.ids.length} defeito(s) declarado(s) com Red resolvido — sem prova: ${sem.join(', ')} (item 1, ${RULE_REF})` });
    }
  }""", 1)
p.write_text(s)
```

**O que este patch NÃO faz, e é a lacuna que D20 fecha.** Ele deixa os itens 2 a 8 lendo `data`, que é a projeção do topo — foi assim que a fixture `C4` saiu `rc=0` com uma entrada nunca avaliada. A implementação de verdade itera `normalizeEntries(data)` e prefixa cada achado com `[<id>]`; a bancada mediu o **contrafactual** (a versão que não itera) porque é ele que prova que a decisão é necessária.

A sonda dos controles (`C1`, `C2`, `C3`, `C4`, `[8]` e o par A/B de D4) monta cada fixture com `projectTop` — para que o artefato seja o que os escritores produziriam, e não um objeto meio-formado que dispara achados por conta própria, que foi o erro da revisão 2:

```js
// probe-cobertura.mjs (trecho)
import { evaluateRedFirst } from '<B>/.forge/scripts/lib/check-red-first.mjs';
const r = evaluateRedFirst('<B>/ch/<caso>');
const cov = (r.findings||[]).filter(f => /defeito\(s\) declarado/.test(f.msg));
console.log('  rc=' + ((r.findings||[]).some(f => f.enforceable) ? 1 : 0) + ' | cobertura=' + cov.length);
for (const f of (r.findings||[])) console.log('    - ' + f.msg.slice(0,104) + '…');
```

### A.5 — o canal do `pre-push` corrigido (D5, `[6]`, `[7]`, M7)

Sobre a bancada de A.1, com os quatro arquivos patchados copiados para `$B/push/.forge/scripts/lib/`. O patch do hook, na íntegra:

```python
import sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()   # .forge/hooks/git/lib/check-red-first.sh
old = '''      type="$(awk -F': ' '$1=="type"{print $2; exit}' "$manifest")"
      [ "$type" = "bugfix" ] || continue'''
new = '''      # D3 — leitor canônico único; nenhum awk novo. rc=2 é declaração inválida (terceiro
      # estado): o change ENTRA no universo, para que o check estático produza o achado.
      node "$REPO/.forge/scripts/lib/defect-scope.mjs" "$chdir" >/dev/null 2>&1; rc=$?
      [ "$rc" -eq 2 ] || node "$REPO/.forge/scripts/lib/defect-scope.mjs" "$chdir" 2>/dev/null | grep -q '^yes' || continue'''
assert old in s; s = s.replace(old, new, 1)
s = s.replace('      examined=$((examined + 1))',
              '      examined=$((examined + 1))\n      examined_ids="${examined_ids:+$examined_ids, }$chid"', 1)
s = s.replace('local examined=0 skipped=0 engaged=0',
              'local examined=0 skipped=0 engaged=0\n  local examined_ids=""', 1)
old3 = '''    local scope="changes ativos em .forge/specs/active, push com commit fix(...)"
    [ "$skipped" -gt 0 ] && scope="$scope; $skipped sem interseção com os fix_files declarados"
    if ! forge_universe_check "red-first" "$examined" "change(s) type:bugfix" "$scope" "$REPO"; then'''
new3 = '''    local scope="changes ativos em .forge/specs/active, push com commit fix(...)"
    # D5 — o sub-relato fala da UNIÃO dos fix_files de TODAS as entradas do change, e diz isso.
    [ "$skipped" -gt 0 ] && scope="$scope; $skipped sem interseção com a união dos fix_files declarados"
    [ -n "$examined_ids" ] && scope="$scope; examinados: $examined_ids"
    if ! forge_universe_check "red-first" "$examined" "change(s) que corrigem defeito" "$scope" "$REPO"; then'''
assert old3 in s; s = s.replace(old3, new3, 1)
p.write_text(s)
```

`bash -n` limpo depois do patch, conferido antes de qualquer medição. **A mutação M7 reinsere as duas linhas do filtro por `type` imediatamente antes da consulta ao predicado**, com `python3` e não com `perl`, para não depender de escaping de `$`:

```python
anchor = '      node "$REPO/.forge/scripts/lib/defect-scope.mjs" "$chdir" >/dev/null 2>&1; rc=$?'
s = s.replace(anchor, '''      type="$(awk -F': ' '$1=="type"{print $2; exit}' "$manifest")"
      [ "$type" = "bugfix" ] || continue
''' + anchor, 1)
```

A invocação do hook é sempre por **redirecionamento de arquivo, nunca por pipe** — `feedback-suite-sem-concorrencia` registra que `rc` de gate lido através de pipe mede o processo errado, e eu reproduzi o engano nesta bancada antes de corrigir (o `PIPESTATUS[0]` de `printf | hook | head` é o do `printf`, e a medição do universo vazio saiu `rc=0` quando o hook havia saído `rc=1`):

```bash
printf 'refs/heads/develop %s refs/heads/develop %s\n' "$LOCAL" "$REMOTE" > "$PB/stdin.txt"
FORGE_ROOT="$PB" bash .forge/hooks/git/lib/check-red-first.sh origin "$PB" < "$PB/stdin.txt" > "$PB/o.txt" 2>&1; echo "rc=$?"
```

### A.6 — `record` com `entries` (D12, D13, D18, M1, M3)

O corpo novo de `cmdRecord`, na íntegra. O `aplica-A6.py` troca o bloco entre `function cmdRecord(changeDir, argv) {` e o comentário `// persistReplayResult:`, acrescenta o import de `normalizeEntries`, `deriveStatus`, `isDeclared` e `projectTop` mais o de `isDefectFixing`, e renomeia `requireBugfix` para `requireDefectFixing` com o predicado de D1.

```js
// ---------------------------------------------------------------------------
// L5 / D12, D13, D18 — record orientado a entradas. Substitui o corpo de cmdRecord.
// ---------------------------------------------------------------------------
function cmdRecord(changeDir, argv) {
  requireDefectFixing(changeDir);
  const ev = requireEvidence(changeDir);
  const f = parseFlags(argv);
  const entries = normalizeEntries(ev.data);

  // D18 — --id recusa valor com forma de flag, vazio ou só espaços. É a única flag em que
  // o fail-closed de D12 se apoia, e parseFlags não pergunta o que argv[i+1] é.
  if ('id' in f) {
    const v = f['id'];
    if (v === undefined || String(v).startsWith('--') || !String(v).trim().length) {
      console.log(`FAIL (--id exige um identificador de defeito como valor, got: ${v === undefined ? '<ausente>' : JSON.stringify(v)})`);
      process.exit(1);
    }
  }
  const wantId = 'id' in f ? String(f['id']).trim() : null;

  // D12 — sem --id só se escreve em entrada AINDA NÃO DECLARADA. O critério é o ESTADO da
  // entrada alvo, não a contagem de entradas: com a regra da issue (entries.length > 1) o
  // segundo record sem --id continuaria sobrescrevendo a única declaração existente.
  let target;
  if (wantId === null) {
    const declared = entries.filter(isDeclared);
    if (declared.length) {
      console.log(`FAIL (--id obrigatório: a evidência já declara ${declared.length} defeito(s) (${declared.map((e) => e.id).join(', ')}) — record sem --id sobrescreveria a declaração existente; use --id <um deles> para atualizar, ou --id <novo> para acrescentar)`);
      process.exit(1);
    }
    target = entries.find((e) => !isDeclared(e));
    if (!target) { target = { id: 'default', status: 'pending' }; entries.push(target); }
  } else {
    target = entries.find((e) => e.id === wantId);
    // D13 — entrada nova nasce VAZIA e nunca herda campos da anterior.
    if (!target) { target = { id: wantId, status: 'pending' }; entries.push(target); }
  }

  if (f['test-path']) target.test_path = f['test-path'];
  if (f['test-id']) target.test_id = f['test-id'];
  if (f['command']) target.command = f['command'];
  if (f['fix-files']) target.fix_files = f['fix-files'].split(',').map((s) => s.trim()).filter(Boolean);
  if (f['failure-pattern']) target.failure_pattern = f['failure-pattern'];
  if (f['setup-command']) target.setup_command = f['setup-command'];
  if (f['reproduces']) target.reproduces = f['reproduces'];
  if (f['excerpt']) { target.excerpt = f['excerpt']; target.excerpt_sha256 = sha256(f['excerpt']); }

  // Obrigatoriedade sobre o ALVO — nunca sobre o objeto resultante da fusão com o topo.
  if (!target.test_path || !target.test_id || !target.command || !target.failure_pattern) {
    console.log('FAIL (--test-path, --test-id, --command e --failure-pattern são obrigatórios para record)');
    process.exit(1);
  }
  if (!Array.isArray(target.fix_files)) target.fix_files = [];

  target.status = 'pending';
  target.replayed_at = null;
  target.replay_head = null;
  target.recorded_at = nowIso();

  // D19 — o topo é reescrito como projeção da primeira entrada; o status é derivado.
  writeJsonAtomic(ev.path, projectTop(ev.data, entries));
  console.log(`OK record — [${target.id}] ${target.test_path} declarado (status: ${deriveStatus(entries)}, ${entries.length} entrada(s))`);
}
```

### A.7 — normalização, precedência, derivação e projeção (D10, D11, D19, M2, M4)

Bloco **aditivo** ao fim de `lib/red-evidence.mjs`. A única alteração acima dele é a guarda de id repetido (D21), que entra em `validateRedEvidence` logo antes do `return errors;` e é a que M10 derruba:

```js
  // D21 — id repetido em entries é declaração inválida do artefato: `resolvidas` é um Set de
  // ids, então duas entradas com o mesmo id fazem o defeito sem prova sumir do relato.
  if (Array.isArray(data.entries)) {
    const vistos = new Set(); const rep = new Set();
    for (const e of data.entries) { const id = e && e.id; if (vistos.has(id)) rep.add(id); vistos.add(id); }
    if (rep.size) errors.push(`entries: id repetido (${[...rep].join(', ')}) — cada defeito declarado precisa de exatamente uma entrada`);
  }
```

O resto é aditivo, e é isso que preserva `isResolved` para os leitores instalados medidos em D11.

```js
// ---------------------------------------------------------------------------
// L5 / D10-D11 — entries como fonte, topo como projeção derivada.
// Bloco ADITIVO ao fim de lib/red-evidence.mjs. Nada acima é alterado.
// ---------------------------------------------------------------------------

// Pior-primeiro: deriveStatus devolve o MÍNIMO desta ordem entre as entradas.
export const STATUS_RANK = { pending: 0, 'not-possible': 1, waived: 2, observed: 3 };

// Campos por defeito — a projeção do topo é exatamente esta lista, e ela é a mesma
// enumeração do schema menos `schema`, `change_id`, `status` e `entries`. `status` do
// topo NÃO é projetado: é derivado (deriveStatus), o que coincide com a projeção quando
// há uma entrada só e a supera quando há N.
export const ENTRY_FIELDS = [
  'test_path', 'test_id', 'command', 'base_commit', 'failure_pattern', 'excerpt',
  'excerpt_sha256', 'classification', 'base_result', 'base_strategy', 'graft_from',
  'revert_patch', 'replay_head', 'setup_command', 'reproduces', 'fix_files', 'waiver',
  'recorded_at', 'replayed_at', 'waived_at',
];

// isDeclared: a entrada já carrega uma declaração de teste? É o predicado de D12.
// `reproduces` NÃO entra: o scaffold do template já o traz preenchido ("bugfix.md §1"),
// e incluí-lo faria todo scaffold cru parecer declarado, fechando o caminho de [2].
export function isDeclared(e) {
  return !!e && ['test_path', 'test_id', 'command', 'failure_pattern']
    .some((k) => typeof e[k] === 'string' && e[k].trim().length > 0);
}

// normalizeEntries: a PRESENÇA da chave `entries` decide quem é a fonte.
//  - ausente  -> artefato legado: o topo é a fonte, e sintetizamos UMA entrada `default`.
//  - presente -> `entries` é a fonte, inclusive quando vazia; o topo em disco é descartado.
// Status ausente ou fora do vocabulário na entrada vira 'pending' e é materializado, para
// que nenhum leitor posterior precise repetir a decisão (§7, quinto caso).
export function normalizeEntries(data) {
  if (!data || typeof data !== 'object') return [];
  const raw = Array.isArray(data.entries) ? data.entries
    : (data.entries === undefined ? null : []);
  if (raw === null) {
    const e = { id: 'default' };
    for (const k of ENTRY_FIELDS) if (data[k] !== undefined) e[k] = data[k];
    e.status = STATUS_RANK[data.status] === undefined ? 'pending' : data.status;
    return [e];
  }
  return raw.filter((e) => e && typeof e === 'object' && !Array.isArray(e)).map((e) => {
    const out = { ...e };
    out.id = typeof e.id === 'string' ? e.id : '';
    out.status = STATUS_RANK[e.status] === undefined ? 'pending' : e.status;
    return out;
  });
}

// deriveStatus: o PIOR status presente. Lista vazia é 'pending' — nunca 'observed' por
// vacuidade. Uma frase, sem exceção; "toda entrada resolvida" é isResolvedMulti.
export function deriveStatus(entries) {
  const es = Array.isArray(entries) ? entries : [];
  if (!es.length) return 'pending';
  let worst = 'observed';
  for (const e of es) {
    const s = STATUS_RANK[e && e.status] === undefined ? 'pending' : e.status;
    if (STATUS_RANK[s] < STATUS_RANK[worst]) worst = s;
  }
  return worst;
}

// isResolvedMulti: TODA entrada resolvida, e pelo menos uma entrada.
export function isResolvedMulti(entries) {
  const es = Array.isArray(entries) ? entries : [];
  if (!es.length) return false;
  return es.every((e) => e && (e.status === 'observed' || e.status === 'waived'));
}

// projectTop: reescreve o topo a partir da PRIMEIRA entrada (D19). Chamado por todo
// escritor e por todo leitor que vá decidir — o topo em disco nunca é consultado quando
// `entries` está presente.
export function projectTop(data, entries) {
  const out = { ...data };
  const first = entries[0] || {};
  for (const k of ENTRY_FIELDS) out[k] = first[k] === undefined ? null : first[k];
  if (!Array.isArray(out.fix_files)) out.fix_files = [];
  out.entries = entries;
  out.status = deriveStatus(entries);
  return out;
}
```

A sonda de D11 (`probe-D11.mjs`), que produz as sete linhas da caixa de D11:

```js
import { normalizeEntries, deriveStatus, isResolvedMulti } from './.forge/scripts/lib/red-evidence.mjs';
const E = (id, status) => ({ id, status });
const casos = [
  ['misto(observed,pending)   ', { entries: [E('a','observed'), E('b','pending')] }],
  ['todas-observed            ', { entries: [E('a','observed'), E('b','observed')] }],
  ['observed+waived           ', { entries: [E('a','observed'), E('b','waived')] }],
  ['legado-waived(1 entrada)  ', { status: 'waived', test_path: 'tests/A.cs' }],
  ['vazia                     ', { entries: [] }],
  ['entrada sem status        ', { entries: [E('a','observed'), { id: 'b' }] }],
];
for (const [rot, d] of casos) {
  const es = normalizeEntries(d);
  console.log(`  ${rot} deriveStatus=${String(deriveStatus(es)).padEnd(13)} isResolvedMulti=${isResolvedMulti(es)}`);
}
console.log('  normalizeEntries(legado status:waived) -> ' + JSON.stringify(normalizeEntries({status:'waived'}).map(e=>[e.id,e.status])));
```

A sonda de D19 (`probe-D19.mjs`), que produz as seis linhas da caixa de D19 — inclusive a que reproduz a forja do `w106`:

```js
import { normalizeEntries, deriveStatus, projectTop } from './.forge/scripts/lib/red-evidence.mjs';
// Artefato como a forja do w106 o deixaria: entries com a declaração REAL, topo forjado à mão.
const disco = {
  schema: 'red-evidence/v1', change_id: 'bug-a',
  status: 'observed', test_path: 'tests/bug-a-forja.test.mjs', classification: 'behavioral',
  entries: [{ id: 'default', status: 'pending', test_path: 'tests/bug-a.test.mjs', classification: null }],
};
const es = normalizeEntries(disco);
console.log('  fonte lida        -> ' + JSON.stringify(es.map(e => [e.id, e.status, e.test_path])));
console.log('  topo em disco     -> status=' + disco.status + ' test_path=' + disco.test_path);
const rep = projectTop(disco, es);
console.log('  topo reprojetado  -> status=' + rep.status + ' test_path=' + rep.test_path + ' classification=' + rep.classification);
// legado: entries AUSENTE -> o topo é a fonte
const legado = { schema: 'red-evidence/v1', change_id: 'bug-a', status: 'observed', test_path: 'tests/x.mjs', base_strategy: 'test-graft', graft_from: 'abc1234' };
const el = normalizeEntries(legado);
console.log('  legado (sem entries) -> ' + JSON.stringify(el.map(e => [e.id, e.status, e.test_path, e.base_strategy, e.graft_from])));
console.log('  legado reprojetado   -> status=' + projectTop(legado, el).status + ' base_strategy=' + projectTop(legado, el).base_strategy + ' graft_from=' + projectTop(legado, el).graft_from);
// entries: [] presente + topo cheio -> entries vence, e o topo zera
const vazia = { schema: 'red-evidence/v1', change_id: 'c', status: 'observed', test_path: 'tests/x.mjs', entries: [] };
const ev = normalizeEntries(vazia);
console.log('  entries:[] + topo cheio -> entradas=' + ev.length + ' deriveStatus=' + deriveStatus(ev) + ' topo.test_path=' + projectTop(vazia, ev).test_path);
```

### A.8 — as propriedades (P1–P4)

```js
// A.8 — as quatro propriedades (P1-P4). Roda com o pbt.mjs do próprio repositório.
import { gen, forAll } from './.forge/scripts/lib/pbt.mjs';
import { normalizeEntries, deriveStatus, isResolvedMulti } from './.forge/scripts/lib/red-evidence.mjs';

const STATUS = gen.oneOf(['pending', 'observed', 'waived', 'not-possible']);
const LISTA = gen.array(STATUS, 1, 6);
const OPTS = { runs: 500, seed: 20260908 };
const asEntries = (ss) => ss.map((s, i) => ({ id: `d${i}`, status: s }));

const props = [
  ['P1 deriveStatus-iff-todas-observed', [LISTA],
    (ss) => (deriveStatus(asEntries(ss)) === 'observed') === ss.every((s) => s === 'observed')],
  ['P2 derivacao-invariante-sob-permutacao', [LISTA],
    (ss) => {
      const rev = [...ss].reverse();
      return deriveStatus(asEntries(ss)) === deriveStatus(asEntries(rev))
        && isResolvedMulti(asEntries(ss)) === isResolvedMulti(asEntries(rev));
    }],
  ['P3 retrocompat-normalizacao', [STATUS],
    (s) => {
      const es = normalizeEntries({ schema: 'red-evidence/v1', change_id: 'c', status: s, test_path: 'tests/x' });
      return es.length === 1 && es[0].id === 'default' && es[0].status === s && deriveStatus(es) === s;
    }],
  ['P4 isResolvedMulti-iff-todas-resolvidas', [LISTA],
    (ss) => isResolvedMulti(asEntries(ss)) === ss.every((s) => s === 'observed' || s === 'waived')],
];

for (const [nome, gens, prop] of props) {
  const r = forAll(gens, prop, OPTS);
  console.log(r.ok ? `${nome}: OK (${r.runs} execuções, seed ${r.seed})`
                   : `${nome}: FALHOU ${JSON.stringify(r.counterexample)}`);
}
```

Ela roda contra o `pbt.mjs` do próprio repositório (`gen`, `forAll`, shrinking, seed reprodutível), com `runs: 500` e `seed: 20260908`, e a demonstração de que P1 discrimina é a mesma M2 de §3.4 aplicada a `red-evidence.mjs` antes da execução, com restauração por `cp` do `E.impl` e recontrole.

### A.9 — o que continua fora do alcance desta bancada

Duas coisas, ditas em letra para não virarem promessa implícita:

1. **A bancada não é a implementação.** Os patches acima são existências de prova — eles fazem as propriedades valerem e as mutações discriminarem, e é isso que uma especificação precisa demonstrar. Eles não têm o `replay --id` de D15, o `waive` por entrada de D14 nem a iteração dos itens 1 a 8 por entrada de D20; essas três decisões estão medidas pelo **contrafactual** (a versão sem elas, e o dano que ela produz), não pelo positivo — D20 pela mutação M8, e D14/D15 pela leitura do código que hoje opera sobre o objeto raiz. D19 e D21, que também nasceram nesta revisão, estão implementadas na bancada e medidas dos dois lados (M9 e M10).
2. **Nenhum gate da suíte foi executado**, nesta revisão nem nas anteriores — `feedback-suite-sem-concorrencia` registra que gate manual concorrente produz falha fantasma em gate alheio, e a rodada proíbe. Todas as consequências que este documento atribui a `w106`, `w107`, `w108`, `w109` e `w144` vêm de leitura de fixture com âncora conferida por `sed -n <linha>p`, somada às decisões escritas — nunca de execução. Onde a previsão é falsificável, ela está na definição de pronto como asserção, e não como afirmação.
