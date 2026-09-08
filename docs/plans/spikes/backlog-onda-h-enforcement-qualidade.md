# Onda H — enforcement de qualidade

Especificação implementável. Insumo: `docs/plans/2026-09-07-backlog-zero.md`, seções "Invariantes" (as dezenove, normativas) e "Onda H". Fecha LDG-0008, LDG-0065 e LDG-0021, e abre um item novo cujo defeito foi encontrado pela própria técnica que LDG-0021 pede.

**Correção da revisão 1, e ela é sobre o plano-mestre, não sobre esta onda.** A revisão 0 desta especificação declarava ter lido também a seção "Método de prova" do plano. Essa seção não existe: `grep -nE '^#{1,3} ' docs/plans/2026-09-07-backlog-zero.md` devolve as nove seções reais (Definição de pronto, Estado medido, Invariantes, Fase 0, Fase 1, Ondas do backlog, Fora do backlog formal, Cadeia de execução, Ordem de execução) e nenhuma delas tem esse nome, enquanto `grep -n 'Método de prova'` casa uma única linha, a 5, que manda todas as ondas lerem uma seção inexistente. O insumo desta onda passa a ser o que existe, e o defeito fica registrado aqui para o dono do plano resolver antes que as ondas seguintes o citem de novo.

Data das medições: 2026-09-07. Árvore: `/Users/milton/Documents/projects/forge-harness`, HEAD `3bb67f5`, worktree em `feat/fase1-dogfood-completo`. Todo número deste documento veio de um comando citado no parágrafo em que aparece, executado nesta rodada. Nenhum número é herdado de relatório de terceiro, e nenhum é herdado do registro do ledger sem reconferência — os três registros foram reconferidos contra o código de hoje e as divergências estão nomeadas.

Nenhum gate da suíte foi executado na produção desta especificação: a suíte não tolera concorrência (`feedback-suite-sem-concorrencia`) e nenhum cenário aqui exigia rodar um gate inteiro. As reproduções usam bancadas em `$TMPDIR` que copiam `template/.forge` para uma fixture e operam lá; nenhum arquivo rastreado do repositório foi escrito.

**A bancada é publicada, e essa é a diferença mais importante entre esta revisão e a anterior.** A revisão 1 reprovou nove afirmações numéricas por não trazerem o comando que as produz — sem gerador, alfabeto e semente, o revisor não tinha o que repetir, e a definição de pronto exigia "reconferir as medições" a partir de um documento que não permitia reconstruí-las. Nesta revisão **toda** afirmação numérica traz ao lado o comando exato que a devolve, e os dois programas de bancada que os comandos invocam estão colados na íntegra no **Apêndice A**. Quem revisar copia o apêndice para um diretório qualquer, roda as linhas citadas e obtém os mesmos números — ou mostra que não obtém, que é o ponto.

---

## 1. Sumário executivo

Os três itens têm o mesmo eixo, e nomeá-lo evita três remendos desconexos: **o harness publica normas de qualidade que nenhum código lê**. A norma de TDD manda escrever o teste antes e nada verifica isso para `type: feature`. A norma de PBT manda cobrir propriedade e a própria rule declara, em letra, que o check determinista não existe. Os packs Java e Python prometem qualidade de stack em prosa e não trazem um único arquivo que converta a prosa em erro de build.

O quarto achado é o que dá a esta onda o seu valor mais alto, e ele não estava no plano: aplicar a técnica que LDG-0021 pede — fuzzing guiado por gramática sobre a superfície de entrada que as regras deixam passar — ao par emissor/parser de YAML do harness encontrou, em minutos, **corrupção exponencial e silenciosa do baseline**, já materializada neste repositório e em dois repositórios adotantes. O arquivo `.forge/product/current/capabilities/forge-harness-template/spec.yaml` tem 272.103 bytes, dos quais **84,2% são barras invertidas** acumuladas ao longo de treze gerações de archive. O item de fuzzing deixa de ser dívida teórica e passa a ser o item que pagou o próprio custo antes de ser implementado.

| Item | Fatia que fecha | Ancoragem do enforcement |
|---|---|---|
| LDG-0008 | TDD-em-feature | chave nova lida no pré-flight §13.1 de `lib/validate-archive.mjs`, o mesmo ponto da primeira fatia |
| LDG-0008 | cobertura por propriedades | segunda chave nova no mesmo ponto, sobre o `traceability.yaml` que já existe |
| LDG-0065 | packs Java e Python | `java-baseline.sh` e `python-baseline.sh` com `--check`/`--apply`, assets nos packs, fiação em doctor/verify-build/reviewer |
| LDG-0021 | eixo de fuzzing decidido e executado sobre uma superfície | propriedade de round-trip do par emissor/parser, com denominador derivado e piso |
| item novo | corrupção do baseline por escape não desfeito | correção do par, detector de corrupção e migração explícita |

---

## 2. LDG-0008 — o que a primeira fatia deixou, e o que ainda não existe

### 2.1 O estado herdado, reconferido

A fatia de 2026-09-05 tornou reais duas chaves e removeu uma terceira. Conferido contra o código de hoje, e não contra o registro: `grep -n 'require_' template/.forge/forge.yaml` devolve `require_tests_before_archive` na linha 50 e `require_traceability_before_archive` na linha 57, ambas com valor `false`.

A terceira chave sumiu, e o comando que prova isso precisa de âncora — a revisão 1 pegou aqui um erro meu que vale a régua inteira. `grep -c 'require_human_approval_before_archive' template/.forge/forge.yaml` devolve **1**, não zero, porque o comentário da linha 58 contém a substring ao explicar que a chave não existe. A forma correta é a que `w192[3]` já usa, ancorada em começo de linha e dois-pontos: `grep -cE '^[[:space:]]*require_human_approval_before_archive:' template/.forge/forge.yaml` devolve **0**. A conclusão sempre esteve certa; o comando citado é que media outra coisa, e é exatamente a classe de defeito que esta onda existe para combater — um predicado que aprova por olhar para o lugar errado. O leitor é `template/.forge/scripts/lib/validate-archive.mjs`, linhas 108 a 151, e a semântica de ausência está escrita ali em letra na linha 95: *"Ausência da chave NÃO liga o enforcement"*.

**Uma correção ao registro do ledger, medida.** O detalhe de LDG-0008 afirma que `require_tests_before_archive` foi tornada real "default true". O arquivo entrega `false`, e o comentário de `forge.yaml:35-49` explica por quê — ligada por default ela reprovaria o primeiro `archive` de todo projeto greenfield, e o `w31` seria o gate decisivo por ser o único montado a partir dos templates de fábrica. O registro está desatualizado num ponto que importa para esta onda, porque as duas chaves novas herdam essa mesma decisão de default.

### 2.2 O defeito da fatia TDD-em-feature, reproduzido

`require_tests_before_archive` pergunta *"a suíte tem um check `test` com status `passed`?"*. Ela não pergunta *"este change escreveu um teste?"*, e a diferença é o item inteiro.

**Bancada montada e executada nesta rodada, com os comandos na ordem em que rodaram.** `template/.forge` copiado para `$d`, `git init`, e um change `type: feature` conduzido até `verified` pelo caminho real dos scripts. A "feature" implementada foi um arquivo de produção e **zero arquivos de teste**:

```
d=$TMPDIR/bancada-h/fix-feat; S="$d/.forge/scripts"
mkdir -p "$d"; cp -R template/.forge "$d/.forge"
git init -q "$d"; git -C "$d" config user.email t@t; git -C "$d" config user.name t
git -C "$d" add -A && git -C "$d" commit -q --no-verify -m init
cd "$d" && FORGE_ROOT="$d" bash "$S/spec-new.sh" ch-feat --type feature --scale 0
  → OK .forge/specs/active/ch-feat
mkdir -p "$d/src"; printf 'export function taxa(v){ return v*0.0299; }\n' > "$d/src/taxa.js"
find "$d" -path "$d/.forge" -prune -o -name '*test*' -print | wc -l
  → 0
FORGE_ROOT="$d" bash "$S/spec-transition.sh" ch-feat tasks-ready    → OK ch-feat: proposed -> tasks-ready
FORGE_ROOT="$d" bash "$S/spec-transition.sh" ch-feat implementing   → OK ch-feat: tasks-ready -> implementing
perl -pi -e 's/^(\s*)- \[ \] /$1- [X] /' "$d/.forge/specs/active/ch-feat/tasks.md"
printf 'archive:\n  baseline_delta: none\n' >> "$d/.forge/specs/active/ch-feat/manifest.yaml"
FORGE_ROOT="$d" bash "$S/spec-transition.sh" ch-feat implemented    → OK ch-feat: implementing -> implemented
FORGE_ROOT="$d" bash "$S/spec-verify.sh" ch-feat                    → OK ch-feat (verification.yaml written)
FORGE_ROOT="$d" bash "$S/approval-log.sh" ch-feat --gate implementation_verified --decision approve --reason bancada
FORGE_ROOT="$d" bash "$S/spec-transition.sh" ch-feat verified       → OK ch-feat: implemented -> verified
FORGE_ROOT="$d" bash "$S/approval-log.sh" ch-feat --gate human_archive_approval --decision approve --reason bancada
```

Com a chave ligada e um check `test: passed` no `verification.yaml` — o estado exato de um repositório que declara `test:` no bloco `runtime` do `FORGE.md` e cuja suíte passa —, o pré-flight §13.1 aprova:

```
sed -i '' 's/require_tests_before_archive: false/require_tests_before_archive: true/' "$d/.forge/forge.yaml"
# no verification.yaml, o único check registrado (name: none, status: skipped) vira name: test, status: passed
cd "$d" && FORGE_ROOT="$d" node "$S/lib/validate-archive.mjs" "$d/.forge/specs/active/ch-feat" "$d"; echo "rc=$?"
  · quality.require_tests_before_archive: true — check 'test' passou
  · quality.require_traceability_before_archive: false — dispensa declarada em .forge/forge.yaml; a rastreabilidade não foi exigida
OK ch-feat
rc=0
```

O `rc` é lido de `$?` **sem pipe**: `bash script | tail -3` devolve o `rc` do `tail`, e essa armadilha custou uma medição errada na produção desta própria revisão — o contrafactual `(e)` de §7 mediu `rc=0` nos dois lados antes de eu tirar o `| tail` e ver `rc=1` no lado mutado.

O change entra no baseline com código novo e nenhuma linha de teste, sob uma chave cujo nome afirma o contrário. Esse é o defeito, e ele não é de leitura: é de **sinal escolhido**. O sinal disponível prova que a suíte está verde, não que o change foi dirigido por teste.

### 2.3 Decisão fechada — o sinal é o Red observado, e o motor já existe

**Decisão:** a fatia TDD-em-feature é enforçada por uma chave nova, `quality.require_red_before_archive`, default `false`, lida no mesmo pré-flight §13.1. Ligada, ela exige que um change `type: feature` carregue `evidence/red/red-evidence.json` com `status` em `observed` ou `waived` — a mesma evidência que hoje só é exigida de `type: bugfix`, produzida pelo mesmo motor de replay.

**A enumeração dos status é exaustiva sobre o enum publicado, e o quarto valor tem tratamento escrito (invariante 17).** `sed -n '13p' template/.forge/schemas/red-evidence.schema.json` devolve `"enum": ["pending", "observed", "waived", "not-possible"]` — são quatro, não dois. `observed` e `waived` aprovam; `pending` reprova, porque é a declaração sem a observação; e **`not-possible` reprova sob esta chave**, com mensagem própria que o distingue de `pending`. A escolha é deliberada e contrária ao instinto: `not-possible` é um desfecho legítimo do protocolo red-first para um bugfix cujo Red é genuinamente inviável, mas uma *feature* cujo Red é impossível é uma feature que ninguém sabe testar, e aprovar o archive nesse estado seria a chave dizendo "verifiquei" sobre o caso que ela menos consegue verificar. Quem tiver esse caso desliga a chave no `forge.yaml` e a dispensa fica registrada na saída do pré-flight, que é o desfecho auditável.

**Por que esse sinal, e não uma heurística de diff.** Contar arquivos de teste tocados pelo change seria enforcement de aparência: um arquivo de teste tocado não é um teste que falhava antes. O motor de replay decide por execução real — reconstrói a árvore pré-mudança, roda o teste declarado, exige falha comportamental lá e passagem no HEAD. É literalmente Vermelho antes do Verde, e é o único sinal do harness que não é auto-declarado. A invariante 1 do plano-mestre pede exatamente isso, e a lição de `project-red-first-limite-verificacao` — evidência produzida por quem é verificado, no ambiente que ele controla, não prova nada — reprova as alternativas.

**A medição que torna a decisão barata, e que eu não presumi.** O motor é agnóstico de tipo. `grep -c bugfix` sobre os arquivos da maquinaria red devolve **0** em `lib/red-replay.mjs` (695 linhas), **0** em `lib/red-classify.mjs`, **0** em `lib/red-level.mjs` e **0** em `lib/red-evidence.mjs`. O acoplamento a `bugfix` vive inteiro na camada de política e de CLI: **12** ocorrências em `red-evidence.sh`, **9** em `lib/check-red-first.mjs`, **11** em `lib/validate-spec.mjs`, **5** em `spec-new.sh`, **4** em `lib/red-evidence-ops.mjs`, **2** em `spec-verify.sh` e **1** em `archive-spec.sh`. `deriveBase` (`red-replay.mjs:186`) recebe `{ root, testPath, fixFiles, testId }` e nada mais — nenhuma das três estratégias (`ancestry`, `revert-synthesis`, `test-graft`) consulta o tipo do change. Para uma feature, os `fix_files` são os arquivos que a implementam, e a árvore pré-mudança é a árvore em que a feature não existe: o teste falha lá por comportamento ausente, que é a definição de Red.

**Alternativa descartada, com a medição que a descarta: ampliar o escopo default de `red-evidence.sh ci` e de `check-red-first.sh check` para `feature`.** Seria a mudança mais direta e é a errada, porque **três gates rastreados afirmam literalmente o contrário**, e mudá-los junto significaria apagar a asserção que eles existem para fazer:

| Gate | Linha | O que afirma hoje |
|---|---|---|
| `tests/w106-red-first-gate.sh` `[9]` | 507-513 | `change type:feature é no-op — nenhum finding`; roda `check-red-first check feat-a` e exige `rc 0` **e** a substring `n/a` na saída |
| `tests/w109-red-ci-gate.sh` `[4]` | 99-102 | `change de outro tipo é ignorado`; cria `feat-ci` e exige que `grep -q 'feat-ci'` **não** case na saída de `ci` |
| `tests/w144-gate-control-counter-gate.sh` `[4]` | 113-124 | `2 changes ativos e 0 type:bugfix é OK`; cria um change `feature` e um `refactor` e exige `rc 0` de `ci` |

A decisão preserva os três verdes sem editar uma linha deles: o default de fábrica da chave nova é `false`, as fixtures dos três gates não a declaram, e `wants()` trata ausência como desligado (`validate-archive.mjs:97`). O enforcement novo mora **apenas** no pré-flight de archive, que nenhum dos três exercita. Isso é a invariante 15 aplicada antes de escrever código, e não depois de deixar quatro gates vermelhos.

**O que a decisão exige mexer, e é pouco:** `red-evidence.sh init` recusa hoje qualquer tipo diferente de `bugfix` (`red-evidence.sh:122`) e `check-red-first.mjs waive` faz o mesmo (`check-red-first.mjs:539`). As duas guardas passam a aceitar `feature`. Varrido nesta rodada: `grep -rn 'init só se aplica\|waive só se aplica' tests/` devolve **zero linhas** — nenhum gate rastreado afirma essas duas recusas, então relaxá-las não quebra nada.

**A varredura da string do scaffold, remedida — a revisão 1 achou aqui um número meu errado num parágrafo cuja função era justamente afastar a armadilha B.** O template `templates/bugfix/red-evidence.json` continua sendo a fonte do scaffold, e o campo `reproduces` nasce hoje com o literal `bugfix.md §1`. A revisão 0 dizia que `grep -rn 'bugfix.md §1' tests/` devolvia zero. **Devolve 6**, medido de novo agora: `grep -rn 'bugfix.md §1' tests/ | wc -l` → `6`, todas em `tests/w106-red-first-gate.sh` (linhas 391, 539, 554, 569, 583, 600).

**A conclusão sobrevive, e a razão é medida, não retórica.** As seis linhas são literais de heredoc que o próprio `w106` escreve dentro de um `red-evidence.json` de fixture — o gate constrói o dado que vai examinar, e não afirma nada sobre o que o template de fábrica produz. O elo que faria a mudança do template alcançar o gate seria uma invocação do `init`, e ela não existe: `grep -rn 'red-evidence.sh\" init\|red-evidence.sh init' tests/ | wc -l` → `0`. **Por isso a decisão é não mexer no literal.** Trocar `bugfix.md §1` por um valor dependente de tipo obrigaria a editar as seis linhas de `w106` para nada — o campo `reproduces` é texto livre de auditoria e a chave nova não o lê. É uma mudança de string de produção que a varredura da invariante 15 recomenda **não** fazer, e o registro dela aqui vale mais que a mudança valeria.

**Terceiro estado, e a revisão 1 derrubou a justificativa que eu tinha dado para ele.** A chave ligada num change `feature` cujo repositório não tem `node` no PATH não pode virar "aprovado" nem "reprovado por falta de evidência": o pré-flight não conseguiu examinar. A revisão 0 afirmava que esta onda herdaria da Onda D "o vocabulário `INCONCLUSIVO` e os códigos 4 e 5". **Remedido, e a afirmação era falsa nos dois membros.** A seção "Onda D" do plano (`awk 'NR>=119 && NR<=125' docs/plans/2026-09-07-backlog-zero.md`) fecha #119, #106 e LDG-0157, e a terceira classe que ela nomeia em letra é `"NÃO VERIFICADO — node ausente"`, não `INCONCLUSIVO`; nenhum código numérico aparece ali. No repositório, `grep -rn 'INCONCLUSIVO' template/ tests/` casa `pentest-ops.sh:1026` e `:1043`, que retornam **4**, e `grep -rn 'exit 5$' template/.forge/scripts/` devolve **zero linhas** — o código 5 que eu citei não existe em lugar nenhum.

**A decisão corrigida, e ela fica mais barata do que era.** Esta onda **não** depende da Onda D e **não** inventa vocabulário: o pré-flight, ao não conseguir examinar, emite `NÃO VERIFICADO — node ausente` no formato que `hooks/git/pre-push:143` e `:181` já usam e que `w160[4]` e `w168[5]` já assertam, e reprova. Reprovar, e não aprovar, é a leitura fail-closed que a natureza do ponto exige: o pré-flight de archive é o último portão antes do baseline, e um portão que aprova quando não conseguiu olhar é literalmente a invariante 3 violada. A dependência de ordenação some da §13 junto com esta correção.

### 2.4 O defeito da fatia PBT, reproduzido — a rule confessa a lacuna e a confissão é exata

`template/.forge/rules/testing/property-based-testing.md:56` diz, em letra:

> O que **não** existe ainda: um check determinista que reprove um change com propriedade declarada e sem teste correspondente. Enquanto não existir, esta parte é honor system — e está nomeada como tal aqui em vez de escondida.

Conferido, e é pior que a confissão em dois pontos.

**Primeiro: não há leitor.** `grep -rn "PBT" template/.forge/scripts/ template/.forge/hooks/ bin/ lib/` devolve **5 linhas**, todas comentários — quatro no cabeçalho de `lib/pbt.mjs` e uma em `lib/yaml-lite.mjs:17`. Zero código executável lê o token.

**Segundo: no pipeline de change, não há onde declarar.** O token `PBT-NN` tem vocabulário estabelecido nos agentes — `requirements-writer.md:186` e `requirements-validator.md:271` definem a seção `### PBT-NN — <Nome da Propriedade>`, e `tasks-validator.md:380` exige que *"Todo `PBT-NN` possui TASK correspondente"*. Mas `template/.forge/templates/spec/requirements.md` — o artefato que `/forge:spec new` materializa — **não tem nenhuma seção PBT**: `grep -rn -i "pbt" template/.forge/templates/spec/*.md` devolve zero. As duas metades da norma vivem em pipelines diferentes e nunca se encontram.

**Terceiro, e é o que fecha o argumento sobre por que a norma precisa de máquina: a própria suíte deste repositório tem um gerador de PBT que exclui deliberadamente os caracteres que quebram a propriedade que ele afirma medir.** `tests/w162-yaml-lite-flow-array-gate.sh`, no cenário `[4]`, escreve:

```
// charset deliberadamente sem aspas/backslash: o unescape de aspas embutidas é lacuna
// pré-existente do parser (fora do escopo de LDG-0033, que é sobre flow-style de ARRAY).
```

O cenário anuncia "PROPRIEDADE round-trip: parse(render(x)) === x, 200 listas geradas (seed fixa)" e o gerador não gera os dois caracteres sob os quais a propriedade é falsa. A ressalva está honesta, dentro do teste — e invisível para quem lê a rule, para quem lê o nome do cenário e para quem confia no verde. §5 mostra o que a exclusão escondia.

### 2.5 Decisão fechada — a declaração de propriedade lida no `traceability.yaml`, sem artefato novo

**Decisão:** a fatia de cobertura por propriedades é enforçada por `quality.require_property_coverage_before_archive`, default `false`, no mesmo pré-flight. Ligada, ela exige, para **toda** entrada do `traceability.yaml` cujo `requirement_id` casa `^PBT-`, que a entrada tenha ao menos uma `task` e ao menos um item em `evidence`.

**Por que o `traceability.yaml`, e por que isso não é artefato novo.** O schema aceita a forma hoje, sem alteração: `traceability.schema.json` declara `requirement_id` como `{ "type": "string", "minLength": 3 }`, sem `pattern`, então `PBT-01` já é um valor válido. A coerência já é cobrada: `validate-spec.mjs:379-381` reprova quando o `requirement_id` da matriz não aparece no artefato de requisitos, e `:382` reprova quando não há task. O campo `evidence` já existe no schema e o cabeçalho do template já diz que ele é preenchido pelo `/forge:verify`. A onda acrescenta **uma seção opcional** ao `templates/spec/requirements.md`, no vocabulário que os agentes já usam, e **um leitor** — nada mais.

**Alternativa descartada:** inventar `properties.yaml` no change. Descartada porque o harness já pagou o preço de duas fontes para o mesmo fato — é a razão registrada da remoção de `require_human_approval_before_archive` na fatia anterior, e é LDG-0152 vista de outro ângulo.

**Alternativa descartada:** derivar as propriedades por varredura do `design.md`. Descartada porque `design.md` é opcional (`validate-spec.mjs:133` só o exige em `scale >= 2` e não em `bugfix`), então a varredura teria universo vazio na maioria dos changes e aprovaria por não ter olhado — a falha clássica que a invariante 3 nomeia.

**A seção nova do template não pode tropeçar em duas guardas existentes, e as duas foram reconferidas com as linhas certas.** A cópia bash de `SCAFFOLD_MARKERS_RE` está em `spec-verify.sh:103` — `sed -n '102,104p' template/.forge/scripts/spec-verify.sh` mostra o comentário na 102 e o `grep -qE '<scaffold:|<capability-kebab>|REQ-XXX-'` na 103 — e `PBT-NN` não casa nenhum dos três padrões. **E o argumento é mais forte do que a revisão 0 dava:** a guarda é aplicada a `"$DIR/spec-delta.yaml"` e a nada mais, então ela nunca chega perto do `requirements.md`. A segunda guarda chama-se `hasFilledTableRow`, não `tableHasDataRow`, e está em `validate-spec.mjs:238-242` (`grep -n 'hasFilledTableRow' template/.forge/scripts/lib/validate-spec.mjs` → `238`, `269`, `271`); ela rejeita linha de tabela que contenha `<...>`, o que torna tabela um formato ruim para a seção nova — por isso a seção é de **cabeçalhos**, `### PBT-NN — <Nome da Propriedade>`, exatamente a forma que `requirements-writer.md:186` já prescreve (`awk 'NR==186' template/.forge/agents/specifications/requirements-writer.md` devolve a linha verbatim), e não uma tabela.

**O caso não coberto, procurado ativamente (invariante 17).** Um change que **tem** propriedade verificável e **não declara** nenhum `PBT-NN` passa por esta chave sem reprovação, porque não há como uma máquina saber que a propriedade existia. Isso é limite declarado, não lacuna esquecida: a chave transforma "declarei propriedade e não testei" em erro determinista, e deixa "não declarei" como honor system — que é estritamente melhor que o estado de hoje, onde as duas metades são honor system.

**O segundo caso não coberto, e este eu não previ: encontrei-o executando o meu próprio protótipo.** Com a chave ligada e um `traceability.yaml` sem nenhuma entrada `PBT-`, o protótipo imprimiu `quality.require_property_coverage_before_archive: true — 0 propriedade(s) declarada(s), todas com TASK e evidence` e aprovou com `rc 0`. É vacuidade pura: o universo era vazio e a nota afirmava conformidade sobre ele. O conserto é normativo aqui e assertado em §6.1 e §8 — com a chave ligada e zero entradas `PBT-`, o pré-flight emite `NÃO VERIFICADO — 0 propriedade declarada` em vez de uma nota de aprovação, e a distinção entre "examinei e estava conforme" e "não havia o que examinar" fica visível para quem audita o archive depois. Registro em voz alta que este defeito nasceu dentro da minha própria prova de existência, e que ele só apareceu porque o protótipo foi **executado**.

**A rule passa a dizer isso em letra, e são duas linhas a reescrever, não uma.** `awk 'NR>=54 && NR<=55' template/.forge/rules/testing/property-based-testing.md` devolve, na 54, *"A cobertura de propriedades por change é declarada no `design.md` e conferida no `/forge:verify`"* — que esta onda contradiz, porque move a declaração para `requirements.md`/`traceability.yaml` — e, na 55, o parágrafo que declara a lacuna. A revisão 0 nomeava só a 55 e chamava-a de 56. As duas entram na definição de pronto de §13, nominalmente.

---

## 3. LDG-0065 — packs Java e Python sem enforcement mecânico

### 3.1 O registro, reconferido contra o código de hoje

`find template/.forge/capabilities/backend-java-relational -type f` devolve **um** arquivo: `PROFILE.md`, com **14 linhas**. O mesmo para `backend-python-relational`: `PROFILE.md`, **14 linhas**. `grep -rn -iE 'ruff|mypy|error prone|spotbugs|checkstyle' template/.forge/capabilities/backend-java-relational/ template/.forge/capabilities/backend-python-relational/` devolve **zero linhas**. O registro do ledger descreve o defeito corretamente e permanece exato.

Os dois packs com enforcement material continuam sendo os mesmos dois: `backend-dotnet-relational` (três assets, `dotnet-baseline.sh`, gate `w155`) e `backend-node-postgres` (`node-baseline.sh`, gate `w180`). A contagem de assets do pack Node estava errada na revisão 0 e a revisão 1 pegou: `find template/.forge/capabilities/backend-node-postgres/assets -type f` devolve **cinco** arquivos — `eslint.config.mjs` mais `eslint-rules/{utils.cjs,verify.mjs,index.cjs,core-rules.cjs}` — e não "dois assets mais quatro arquivos de regra", que contava seis e classificava o `PROFILE.md` como asset contra o critério que o próprio parágrafo anterior usa. `wc -l` sobre os quatro `PROFILE.md` devolve 45 (dotnet), 34 (node), 14 (java) e 14 (python) — a assimetria é visível até no tamanho.

**O que os reviewers dizem hoje.** `grep -n -iE 'error prone|spotbugs|checkstyle|enforcer' template/.forge/agents/code-review/java-reviewer.md` devolve **zero**; `grep -n -iE 'ruff|mypy|flake8|black' template/.forge/agents/code-review/python-reviewer.md` devolve **zero**. Os dois reviewers gastam julgamento de LLM em coisas que uma ferramenta decide de graça.

**O que o doctor faz hoje.** `check_dotnet` (`doctor.sh:579-586`) e `check_node` (`doctor.sh:614-621`) invocam o baseline da stack e reportam. `check_python` (`doctor.sh:625-641`) e `check_java` **não têm bloco equivalente** — terminam no LSP. `grep -n 'check_java()' template/.forge/scripts/doctor.sh` devolve **645**, não 644 como a revisão 0 dizia. Os pontos de inserção são simétricos e óbvios.

**O que o `verify-build` faz hoje, e onde ele já está adiante.** `template/.forge/skills/verify-build/SKILL.md:145` já executa `ruff check .` no pipeline Python, e `:148` já manda reportar typecheck como não configurado em vez de aprovado quando mypy/pyright não estão declarados. O pipeline Java (`:126-134`) usa o wrapper existente e não menciona analisador nenhum. Ou seja: o lado Python tem meia fiação e o lado Java não tem nenhuma — a onda completa as duas, e não parte do zero no Python.

### 3.2 Decisões fechadas

**Decisão que a revisão 1 exigiu, e ela vem primeiro porque decide o tamanho da onda: os scanners deterministas por stack NÃO entram.** `ls template/.forge/skills/ | grep -i quality` devolve `dotnet-quality-scan` e `node-quality-scan` e nada de Java ou Python, e a revisão mostrou que a fórmula "espelha `w155` e `w180`, cenário a cenário" da revisão 0 deixava o implementador sem saber se precisava escrever mais dois scanners — o que muda o gate β de 8 para 16 cenários e a onda de barata para cara. **Decidido: esta onda entrega os dois `*-baseline.sh`, os assets e a fiação; `java-quality-scan` e `python-quality-scan` ficam de fora e viram item de ledger próprio, aberto por esta onda com o escopo escrito.** A consequência está paga em três lugares: §6.2 troca "cenário a cenário" pela lista nominal dos cenários que gate β de fato espelha, §8 não ganha contador de regras por scanner, e §12 ganha a exclusão em letra. A alternativa — os scanners entrarem — foi descartada pelo custo medido: `w155` e `w180` dedicam quatro e cinco cenários exclusivamente ao scanner (`w155` [8] uma linha por regra, [9] achado no sujo e ausência no limpo, [10] portabilidade sem `ripgrep`, [12] frontmatter; `w180` os mesmos mais [12] com `verify.mjs` sob `RuleTester` real), e cada regra de scanner é uma decisão de produto sobre o que é defeito naquela linguagem, que é trabalho de curadoria e não de fiação.

**Decisão: `java-baseline.sh` e `python-baseline.sh`, espelhando `node-baseline.sh` linha a linha de contrato.** Mesma dupla `--check` (default, não escreve) e `--apply` (materializa o que falta), mesma recusa de sobrescrever configuração existente sem `--force`, mesma saída de uma linha por check no padrão do gate-runner (`OK`/`MISS`/`FAIL`/`WARN`/`INFO`), mesmo `exit 0` quando o que é load-bearing está no lugar e `1` quando falta ou diverge. Mesma detecção de stack ausente como no-op silencioso — `awk 'NR>=57 && NR<=64' template/.forge/scripts/node-baseline.sh` mostra o bloco que sai `0` com `INFO node:none` quando não há `package.json`/`tsconfig.json` (a revisão 0 citava 60-66 e a revisão 1 citava 59-65; o bloco começa no comentário da 57 e termina no `fi` da 64), e o equivalente é ausência de `pom.xml`/`build.gradle*` no Java e de `pyproject.toml`/`setup.cfg`/`requirements*.txt` no Python.

**Decisão: a severidade default é derivada do estado do repositório, greenfield contra brownfield, pelo mesmo eixo dos dois packs existentes.** `node-baseline.sh:66-79` decide por **presença de código-fonte**, não por contagem de violação, e o comentário das linhas 67-69 registra o porquê: `error` direto numa base com centenas de violações preexistentes reprova o primeiro lint e mata a adoção. No Python isso significa `ruff` com `select` amplo e severidade de erro em greenfield, e um conjunto reduzido de regras bloqueantes em brownfield; no Java, `Error Prone` em `-Werror` no greenfield e `WARN` no brownfield. O ledger já registra que esta é a decisão mais cara do padrão e que ela vale igual para ruff e para Error Prone — a onda replica, não redecide.

**Decisão: os assets do pack Python são `pyproject.toml` de referência (blocos `[tool.ruff]` e `[tool.mypy]` com `strict`) e o do Java é `pom-quality.xml` de referência (plugin `maven-compiler-plugin` com Error Prone, `spotbugs-maven-plugin` e `maven-checkstyle-plugin`, todos com falha em violação, mais `maven-enforcer-plugin` para o piso de versão), acompanhado de `checkstyle.xml`.** O asset Java é de referência e **não** é materializado por cima de um `pom.xml` existente: o `--apply` só escreve quando não há `pom.xml` na raiz, e quando há, o `--check` cobra que o `pom.xml` existente declare os plugins com falha em violação — exatamente a assimetria que `node-baseline.sh:87-97` já implementa para o caso de um `eslint.config.*` de outra extensão já existir (`awk 'NR>=86 && NR<=97'` mostra o comentário na 87-90 e o ramo `INFO keep:` na 95).

**Decisão que fecha a diferença mais importante entre Java e as três stacks anteriores: Gradle.** Um projeto Java com `build.gradle`/`build.gradle.kts` e sem `pom.xml` não recebe asset nenhum — o `--check` reporta `INFO java:gradle` e cobra, por leitura do arquivo de build, que os três analisadores estejam declarados; o `--apply` **nunca** escreve em `build.gradle*`. O motivo é medido: o mesmo raciocínio de `node-baseline.sh` sobre não coexistir dois configs se aplica com força maior aqui, porque um `build.gradle` é código executável e um patch cego nele quebra o build. Um projeto com **os dois** arquivos (Maven e Gradle na mesma raiz) é o caso não coberto que procurei ativamente: o `--check` reporta `WARN java:ambiguo` nomeando os dois arquivos e **não** decide sozinho qual é a fonte, porque escolher errado silenciosamente é a classe de defeito que esta onda inteira combate.

**Decisão de portabilidade, e ela é medida, não estimada: nem os scripts nem o gate invocam a ferramenta da stack.** A revisão 1 marcou esta como não checada; remedida agora, com o laço colado:

```
for c in dotnet node java gradle python3 ruff mypy mvn pip; do
  if command -v "$c" >/dev/null 2>&1; then echo "$c: sim"; else echo "$c: nao"; fi
done
  dotnet: sim | node: sim | java: sim | gradle: sim | python3: sim
  ruff: nao   | mypy: nao | mvn: nao  | pip: nao
```
 O gate desta onda tem de rodar aqui e no CI, e um gate que exigisse `ruff` seria vermelho por ambiente na máquina do dono do repositório. O precedente é o `w155`, que audita XML e INI e nunca executa `dotnet`. A auditoria do `pyproject.toml` usa `tomllib` e a do `pom.xml` usa `xml.etree`, os dois pela stdlib:

```
python3 --version                          → Python 3.13.14
python3 -c 'import tomllib; print("ok")'   → ok
grep -n 'python3' tests/w155-dotnet-enforcement-gate.sh | head -1
  → 123:python3 - "$PACK/assets/Directory.Build.props" ... <<'PY' || fail "[1]: asset XML inválido"
```

A revisão 1 anotou que `w155:123` seria 122; **refutado por medição** — o `grep -n` acima devolve 123 para a invocação do `python3`, e `sed -n '123,127p'` mostra o heredoc com `import xml.etree.ElementTree as ET` na 124. O número da revisão 0 estava certo neste ponto.

**E aqui a onda corrige um defeito que encontrou no precedente, em vez de copiá-lo.** `w155:123` escreve `python3 - ... <<'PY' || fail "[1]: asset XML inválido"`: numa máquina sem `python3`, o comando falha por ausência da ferramenta e o gate acusa **XML inválido** sobre um XML perfeitamente válido. É a mesma classe de LDG-0157, que a Onda D fecha no seu próprio universo. **Pela mesma correção de §2.3**, o gate desta onda não herda vocabulário da Onda D: ele declara o terceiro estado como `NÃO VERIFICADO — python3 ausente`, na forma que `hooks/git/pre-push:143,181` já usa e que `w160[4]` e `w168[5]` já assertam, e reprova em vez de imputar violação de XML. A correção do `w155` **não** entra nesta onda — vira item de ledger próprio, porque tocar um gate alheio para consertar um defeito de outra classe é o alargamento que a invariante 15 manda evitar.

**Decisão: a fiação é a mesma lista de cinco pontos que `w155[11]` e `w180[13]` já assertam, e a revisão 1 provou que a revisão 0 tinha nomeado a lista errada.** Os cinco pontos são os que os moldes efetivamente grepam, medidos linha a linha:

| # | Ponto | Onde `w155[11]` cobra | Onde `w180[13]` cobra |
|---|---|---|---|
| 1 | reviewer da stack | 255-256 (`dotnet-quality-scan` em `dotnet-reviewer.md`) | 294-299 (`node-quality-scan`, `node-baseline`, `Bash` nas tools) |
| 2 | `skills/verify-build/SKILL.md` | 260-263 (`dotnet format` e `--verify-no-changes`) | 300-307 (`node-baseline`, `$PM exec eslint .` sem `--max-warnings`, finding `NODE-BASELINE`) |
| 3 | `scripts/doctor.sh` | 264-265 (`dotnet-baseline`) | 308-309 (`node-baseline`) |
| 4 | **`installer/forge-init.md`** | 266-267 (`grep -q 'dotnet-baseline' "$WS/installer/forge-init.md"`) | 310-311 (`grep -q 'node-baseline' ...`) |
| 5 | **`PROFILE.md` do pack, com conteúdo nomeado** | 268-271 (`IDE1006` e `ManagePackageVersionsCentrally`) | 312-315 (`forge-quality` e `LDG-0061\|LDG-0130`) |

A revisão 0 omitia os pontos 4 e 5 e punha no lugar deles `capabilities/README.md` e `commands/harness/capabilities.md`, que nenhum dos dois moldes grepa — uma implementação fiel a ela entregaria três de cinco e gate β nasceria vermelho por omissão da própria especificação. **`installer/forge-init.md` não aparecia uma única vez na revisão 0** (`grep -c 'forge-init' <spec>` → 0).

**Concretamente, o que cada ponto exige:**

1. `java-reviewer.md` e `python-reviewer.md` passam a mandar rodar `java-baseline.sh --check` / `python-baseline.sh --check` **antes** de gastar julgamento de LLM, no molde do `dotnet-reviewer.md`.
2. `verify-build/SKILL.md` ganha a chamada ao baseline nos pipelines Java e Python, e o finding correspondente na tabela — o lado Python já executa `ruff check .` na linha 145 e já reporta typecheck como não configurado na 148, então ali é completar, não iniciar.
3. `doctor.sh` ganha `check_python` e `check_java` com o bloco de baseline colado no molde de `check_dotnet`/`check_node`, **informativo**, nunca escrevendo.
4. `installer/forge-init.md` passa a citar `java-baseline` e `python-baseline` na materialização por stack, ao lado das duas linhas que já existem.
5. Os dois `PROFILE.md` de 14 linhas são **reescritos**, e cada um precisa documentar nominalmente a armadilha da sua stack — no molde do `IDE1006` do dotnet (uma severidade que o analisador trata como sugestão e que o build ignora em silêncio se não for elevada) e da decisão de `max-lines` do node (uma regra cuja severidade default reprovaria toda base brownfield, registrada em LDG-0061/LDG-0130). No Java, a armadilha equivalente é o **Error Prone só valer sob `-Werror`**: sem ele o analisador reporta e o build passa, que é o falso-verde clássico. No Python, é o **`ruff` sem `select` explícito** rodar só o subconjunto default e dar verde sobre um `pyproject.toml` que parece configurado. Cada `PROFILE.md` cita a decisão de severidade greenfield contra brownfield e o item de ledger que a registra, para que o gate tenha uma âncora estável a grepar.

**Fiação secundária, fora da contagem de cinco, e com uma armadilha que a revisão 0 não viu.** `capabilities/README.md` e `template/.forge/commands/harness/capabilities.md` passam a citar os assets dos quatro packs, e não só os do dotnet como hoje — mas **`commands/harness/capabilities.md` tem espelho no plugin**: `ls plugin/forge/commands/ | grep -i capab` devolve `capabilities.md`, e `tests/plugin-sync-gate.sh:22` reprova com `plugin/forge dessincronizado — rode: npm run build:plugin` quando a fonte e o espelho divergem. **Editar esse arquivo sem rodar `npm run build:plugin` deixa `plugin-sync-gate` vermelho no dia da entrega**, e isso entra na definição de pronto de §13. Os dois arquivos ficam fora da contagem de cinco porque nenhum molde os grepa, e misturá-los inflaria o denominador de gate β sem que o gate os examine.

---

## 4. LDG-0021 — a decisão de produto, tomada com medição

### 4.1 O que o item pede, e por que ele não cabe inteiro

O registro pede *"decidir o eixo de fuzzing guiado por gramática e a estratégia de corpus real dos repositórios adotantes, com `design.md`"*. São duas decisões e uma delas tem custo de campo: corpus real de adotante significa coletar entradas de quatro repositórios, decidir o que pode ser versionado, e tratar o que é dado de negócio. Isso não cabe numa onda que já entrega dois enforcements novos e dois scripts de baseline.

**A decisão de produto, e é a que o mandato pede em letra:**

| Fica nesta onda | Vira trabalho próprio |
|---|---|
| O **eixo** decidido e executado: os pares emissor/parser do harness, começando pelo par de YAML | Corpus extraído de repositórios adotantes |
| O **motor**: geração guiada por gramática sobre `lib/pbt.mjs`, que já tem PRNG por seed e shrinking | Fuzzing das superfícies que não são pares emissor/parser (frontmatter do `FORGE.md`, mensagem de liaison, `graph.json`, varredura de rotas) |
| A **propriedade** aplicada ao par de YAML, com denominador derivado e piso | Fuzzing diferencial contra um parser YAML completo |
| A **correção** do defeito que o eixo encontrou, e a migração do dado corrompido | — |

**E a residual não vira item de ledger — vira invariante mantida pelo gate, e essa é a parte da decisão que eu defendo mais.** O gate desta onda deriva, na execução, o conjunto de módulos que emitem YAML e exige que **cada um** esteja coberto pela propriedade de round-trip. Um par emissor/parser novo, criado daqui a três meses, reprova o gate no dia em que nascer sem propriedade. Isso é estritamente melhor que um item de ledger "estender o fuzzing às demais superfícies", que envelheceria como envelheceram os literais que a invariante 14 nomeia, e que ninguém leria.

**A revisão 1 mostrou que o denominador da revisão 0 tornava essa promessa falsa, e eu remedi o denominador executando a varredura larga — que encontrou dois emissores que ele não via.** A revisão 0 derivava o universo de `grep -l "yamlQuote\|yamlFlowList" lib/*.mjs`, o que só enxerga `template/.forge/scripts/lib/`. Medido agora:

```
grep -rln 'yamlQuote\|yamlFlowList' template/.forge bin --include='*.mjs' | sort
  template/.forge/scripts/lib/delta-apply.mjs
  template/.forge/scripts/lib/liaison-config.mjs
  template/.forge/scripts/lib/spec-delta-scaffold.mjs
  template/.forge/scripts/lib/yaml-lite.mjs        ← o próprio par, excluído do denominador

grep -rn 's/"/\\\\"/g' template/.forge bin
  template/.forge/scripts/spec-close.sh:65
  template/.forge/scripts/approval-log.sh:83
  template/.forge/scripts/approval-log.sh:88
  template/.forge/scripts/approval-log.sh:89
```

**Os quatro `.mjs` de hoje estão todos em `lib/`, de modo que a varredura larga não muda o número — e é justamente isso que provava o denominador estreito, e por que ele estava errado.** Os dois emissores que ele nunca veria não são `.mjs`: são `approval-log.sh` e `spec-close.sh`, escritos em bash, que emitem `chave: "valor"` em `approvals.yaml` e no registro de fechamento **escapando apenas a aspas dupla e não a barra invertida**. Eles produzem YAML de produção, rastreado, hoje, e o denominador da revisão 0 dava verde sobre eles por não ter olhado — que é literalmente o defeito da invariante 3 que esta onda existe para combater.

**E o achado tem consequência direta e medida sobre a correção do parser.** Um arquivo escrito por esses dois emissores com uma barra invertida no texto é lido corretamente **hoje** e passaria a ser lido **errado** depois da correção do leitor, porque a barra que ninguém escapou vira escape na volta. Medido: `.forge/specs/archived/2026-09-04-gate-assert-visibility/approvals.yaml` contém, no campo `reason`, a prosa `sem o \n na classe negada`, e é o único dos 92 arquivos YAML da árvore em que o candidato completo diverge do candidato com escape no emissor. Dos 16 `approvals.yaml` rastreados (`git ls-files '*approvals.yaml' | wc -l` → 16), **1** carrega uma barra invertida. **Portanto os dois emissores em bash entram no escopo desta onda**: eles passam a escapar a barra invertida junto com a aspas, e o gate γ os inclui no denominador. Sem isso, a correção do par **introduziria** corrupção nova num arquivo que hoje está íntegro, que seria a onda repetindo o defeito que ela veio consertar.

**Como o denominador fica.** Derivado na execução sobre **todos** os `.mjs` de `template/.forge/**` mais `bin/` que citem `yamlQuote`/`yamlFlowList`, **mais** todos os `.sh` de `template/.forge/**` que emitam `chave: "..."` com escape manual, menos o próprio `yaml-lite.mjs`. Piso **5** — os três `.mjs` de hoje mais os dois `.sh` — e um cenário de contrapositiva plantando um emissor sintético **fora** de `lib/` que o gate precisa acusar nomeando o caminho, especificado em §6.3. A dívida deixa de existir por construção, não por promessa — e desta vez a construção olha para o lugar todo.

**Desfecho proposto para LDG-0021: `resolved`.** A justificativa é que o item pede uma **decisão** e a decisão foi tomada, executada sobre uma superfície real, e o resíduo foi fechado por construção em vez de reagendado. Reconheço a tensão com a régua do plano-mestre, que reprova o fechamento por reclassificação silenciosa — a diferença é que não há reclassificação nem silêncio: o escopo que sai está escrito na tabela acima, e o mecanismo que o cobre está no gate. Se o dono do repositório preferir o desfecho conservador, a alternativa honesta é `open` com o detalhe reescrito para conter apenas a coluna da direita — e nesse caso a definição de pronto do plano fecha com **um** item aberto, o que precisa ser decidido por quem é dono do contador, não pelo especificador da onda.

### 4.2 O eixo, e a medição que o escolhe

Fuzzing sem gramática é desperdício mensurável nesta superfície. A revisão 1 reprovou esta medição por não trazer gerador, alfabeto nem semente; **remedida agora com a bancada publicada no Apêndice A**, e o número mudou porque a bancada anterior não era reproduzível nem por mim:

```
node prop.mjs unguided template/.forge/scripts/lib/yaml-lite.mjs 20000 20260907
  alfabeto=30 simbolos  casos=20000  seed=20260907  comprimento=1..40
  rejeicoes por 'unparseable line' = 18987 de 20000 = 94.9%
```

**94,9%** do orçamento gasto em entradas que o parser recusa na primeira linha, sem nunca alcançar a lógica de escalar, de comentário final ou de lista em flow style. É o argumento empírico para a palavra "guiado" no registro do item. O alfabeto de 30 símbolos e o PRNG estão em `ALF_BRUTO` e em `rnd()` no apêndice, e a semente é o argumento final da linha de comando.

O eixo escolhido é **o par emissor/parser**, e a propriedade é o round-trip: `parse(render(x)) === x`, com `render(x)` sendo a linha `chave: ${yamlQuote(x)}`.

**O domínio é decidido em letra aqui, porque a revisão 1 mostrou que deixá-lo vago era o defeito mais caro do documento.** A revisão 0 dizia "para todo `x` do domínio que o emissor aceita" e listava o alfabeto obrigatório como "aspas, barra e tabulação", sem dizer nada sobre quebra de linha — e "o domínio que o emissor aceita" é uma tautologia, porque o emissor de hoje aceita qualquer string e devolve texto que o parser recusa. Medido nesta rodada contra o código de hoje e contra o candidato que só conserta o leitor:

```
para x = "a\nb":  yamlQuote → "a\nb" (com quebra literal)  →  parseYamlSubset → EXCECAO: unparseable line: "b"
para x = "a\rb":  yamlQuote → "a\rb" (com CR literal)      →  parseYamlSubset → EXCECAO: unparseable line
para x = "a\tb":  yamlQuote → "a\tb" (com TAB literal)     →  parseYamlSubset → "a  b"   ROUND-TRIP QUEBRADO
```

**Decisão: o domínio é o conjunto de TODAS as strings, sem exclusão, e o conserto se estende ao emissor.** `yamlQuote` passa a escapar `\\`, `"`, `\n`, `\r` e `\t` como as sequências de dois caracteres correspondentes, e o leitor desfaz exatamente essas cinco, devolvendo o caractere cru para qualquer outro `\X` — que preserva a tolerância de hoje. A alternativa era excluir os caracteres de controle do domínio e **assertar a exclusão em letra no gate**, e ela foi descartada por medição, não por gosto: com o alfabeto estendido a 20 símbolos incluindo `\n` e `\r`, o candidato que conserta só o leitor deixa **951 de 2.000** casos falhando, enquanto o candidato que também conserta o emissor fecha em **0 de 2.000** (os dois comandos estão em §5.3). Excluir seria escrever, num gate desta onda, a mesma exclusão que §2.4 acusa em `w162[4]` — com a agravante de que a alcançabilidade estava provada e eu escolheria não alcançá-la. §10 reavalia a retrocompatibilidade da mudança de forma emitida, que é o preço desta decisão.

A escolha do eixo tem três razões medidas. Primeira: é o lugar onde o harness escreve dado durável e o lê de volta, então uma quebra ali é perda de dado, não mensagem feia. Segunda: o oráculo é gratuito — não é preciso um parser de referência para saber que a resposta está errada. Terceira: o denominador é derivável do código, e portanto não envelhece.

Denominador medido hoje, pela varredura **larga** que §4.1 fixou: `grep -rln 'yamlQuote\|yamlFlowList' template/.forge bin --include='*.mjs'` devolve **quatro** arquivos, dos quais um é o próprio `yaml-lite.mjs`, restando **três emissores** em JavaScript — `delta-apply.mjs`, `spec-delta-scaffold.mjs` e `liaison-config.mjs` —, e `grep -rn 's/"/\\\\"/g' template/.forge bin` devolve mais **dois** em bash, `approval-log.sh` e `spec-close.sh`. Total de **cinco** emissores, que é o piso de §8.

Do outro lado, a revisão 0 afirmava "quinze módulos importam de `yaml-lite.mjs`", e a revisão 1 mostrou que nenhuma contagem plausível dá quinze. **Remedido com o comando ao lado:** `grep -rl "from '.*yaml-lite.mjs'" template/.forge bin --include='*.mjs' | wc -l` devolve **14**. O número é testemunha de data e não entra em asserção nenhuma — quem consome o parser não é o universo que o gate γ examina, que é o de quem **emite**; está aqui só para dizer o tamanho do raio de alcance da correção. O gate deriva o denominador de emissores na execução e usa piso, nunca literal.

---

## 5. O defeito que o eixo encontrou — corrupção exponencial e silenciosa do baseline

### 5.1 Reprodução

`yamlQuote` (`yaml-lite.mjs:9-11`) escapa barra invertida e aspas duplas. `coerceScalar` (`yaml-lite.mjs:89`) desfaz **as aspas** e não desfaz **o escape**:

```
"a\"b"        -> yamlQuote -> "a\"b"        -> parseScalar -> a\"b       ROUND-TRIP QUEBRADO
"a\\b"        -> yamlQuote -> "a\\b"        -> parseScalar -> a\\b       ROUND-TRIP QUEBRADO
"plain"       -> yamlQuote -> "plain"       -> parseScalar -> plain      OK
"a # b"       -> yamlQuote -> "a # b"       -> parseScalar -> a # b      OK
"a: b"        -> yamlQuote -> "a: b"        -> parseScalar -> a: b       OK
```

O emissor é usado onde o dado é prosa humana. `delta-apply.mjs` emite `title` (:164), `normative` (:165) e `given`/`when`/`then` (:170-172) — os campos do baseline de capability. Cada `/forge:archive` lê o baseline, aplica o delta e reescreve. Executado nesta rodada, com um requisito cujo texto contém aspas:

```
geração 0: o sistema deve gravar o campo "status"
geração 1: o sistema deve gravar o campo \"status\"
geração 2: o sistema deve gravar o campo \\\"status\\\"
geração 3: o sistema deve gravar o campo \\\\\\\"status\\\\\\\"
geração 4: (15 barras antes de cada aspas)
```

A contagem de barras é **2^n − 1**: dobra a cada archive. Não é degradação lenta, é explosão.

### 5.2 O dano já materializado, medido

**A enumeração é um censo derivado, e não uma lista escrita à mão — a revisão 1 derrubou a lista da revisão 0 mostrando que ela sub-relatava o dano nos dois lados.** A revisão 0 abria com "neste repositório, em arquivo rastreado e commitado:" e nomeava **um** arquivo; havia **três**. Tabulava **cinco** arquivos de adotante; há **dezesseis**. O detector desta onda é a mesma varredura, e o censo abaixo é a saída dele, não uma transcrição:

```bash
#!/usr/bin/env bash
# censo.sh <raiz> — varre YAML RASTREADO atrás de run de 2+ barras invertidas antes de aspas.
set -u
raiz="${1:?uso: censo.sh <raiz>}"; total=0; atingidos=0
while IFS= read -r f; do
  case "$f" in *.yaml|*.yml) ;; *) continue ;; esac
  total=$((total + 1))
  run="$(grep -oE '\\\\+"' "$raiz/$f" 2>/dev/null | awk '{ n = length($0) - 1; if (n > m) m = n } END { print m + 0 }')"
  [ "${run:-0}" -ge 2 ] || continue
  atingidos=$((atingidos + 1))
  printf '%s\tbytes=%s\tocorrencias=%s\trun_max=%s\n' "$f" \
    "$(wc -c < "$raiz/$f" | tr -d ' ')" "$(grep -oE '\\\\+"' "$raiz/$f" | wc -l | tr -d ' ')" "$run"
done < <(git -C "$raiz" ls-files)
printf 'CENSO %s: yaml_rastreados=%s atingidos=%s\n' "$raiz" "$total" "$atingidos"
```

Saída neste repositório:

```
bash censo.sh /Users/milton/Documents/projects/forge-harness
.forge/product/current/capabilities/forge-harness-template/spec.yaml   bytes=272103  ocorrencias=48  run_max=8191
.forge/specs/archived/2026-08-03-forge-update-command/verification.yaml bytes=1604    ocorrencias=1   run_max=3
docs/product/capabilities/forge-harness-template/spec.yaml              bytes=13528   ocorrencias=26  run_max=3
CENSO: yaml_rastreados=93 atingidos=3
```

O arquivo mais atingido, medido separadamente:

```
F=.forge/product/current/capabilities/forge-harness-template/spec.yaml
wc -l < "$F"                              → 633
wc -c < "$F"                              → 272103
tr -cd '\\' < "$F" | wc -c                → 229216       (84,2% do arquivo)
grep -cE '\\{2,}' "$F"                     → 17           (linhas com run de 2+ barras)
awk 'NR==40 { print length($0) }' "$F"    → 16657         (bytes, no locale do awk)
python3 -c "print(len(open('$F').read().split(chr(10))[39]))"  → 16651   (caracteres)
```

Os dois números da linha 40 são o mesmo fato em unidades diferentes — a linha tem seis caracteres acentuados de dois bytes —, e a revisão 0 citava só um deles sem dizer qual, o que deixou a revisão 1 com uma divergência aparente de seis. O run máximo é **8191 = 2^13 − 1**, treze gerações de archive.

Nos adotantes, o mesmo censo, lido sem escrita:

```
bash censo.sh ~/Documents/projects/axis-fare-validator     → yaml_rastreados=233 atingidos=7
bash censo.sh ~/Documents/projects/axis-go-cloud           → yaml_rastreados=752 atingidos=9
bash censo.sh ~/Documents/projects/azim-crm                → yaml_rastreados=273 atingidos=0
```

| Repositório | Arquivo | Bytes | Ocorrências | Run máximo |
|---|---|---|---|---|
| `axis-fare-validator` | `.forge/…/resultado-tap-passageiro/spec.yaml` | 34.318 | 12 | 63 |
| `axis-fare-validator` | `.forge/…/transporte-device-backend/spec.yaml` | 22.501 | 4 | 7 |
| `axis-fare-validator` | `.forge/…/diagnostico-e-status-perifericos/spec.yaml` | 19.549 | 4 | 7 |
| `axis-fare-validator` | `.forge/…/dinheiro-multimoeda/spec.yaml` | 5.366 | 6 | 3 |
| `axis-fare-validator` | `.forge/…/parametros-listas-versionados/spec.yaml` | 8.955 | 2 | 3 |
| `axis-fare-validator` | `docs/…/dinheiro-multimoeda/spec.yaml` | 5.366 | 6 | 3 |
| `axis-fare-validator` | `docs/…/transporte-device-backend/spec.yaml` | 16.301 | 4 | 3 |
| `axis-go-cloud` | `.forge/…/acquirer-processing/spec.yaml` | 39.971 | 20 | 15 |
| `axis-go-cloud` | `.forge/…/admin-portal/spec.yaml` | 15.362 | 14 | 15 |
| `axis-go-cloud` | `.forge/…/parameters/spec.yaml` | 2.706 | 6 | 3 |
| `axis-go-cloud` | `docs/…/acquirer-processing/spec.yaml` | 29.564 | 16 | 7 |
| `axis-go-cloud` | `docs/…/admin-portal/spec.yaml` | 15.362 | 14 | 15 |
| `axis-go-cloud` | `docs/…/parameters/spec.yaml` | 2.706 | 6 | 3 |
| `axis-go-cloud` | `.forge.bak-1/…/acquirer-processing/spec.yaml` | 39.971 | 20 | 15 |
| `axis-go-cloud` | `.forge.bak-1/…/admin-portal/spec.yaml` | 15.362 | 14 | 15 |
| `axis-go-cloud` | `.forge.bak-1/…/parameters/spec.yaml` | 2.706 | 6 | 3 |

`azim-crm` está limpo, e `pitflow` fica fora do censo por não ser repositório git (`[ -d ~/Documents/projects/pitflow/.git ]` falha). **Todos os runs são 2^n − 1**, em três árvores que não se conhecem, o que confirma a causa no código distribuído e não numa edição manual. Nem o número 3, nem o 16, nem os nomes desta tabela entram em asserção: são **testemunhas de data**, e a asserção correspondente é a propriedade "nenhum YAML rastreado tem run de 2 ou mais barras antes de aspas" mais o piso de que o censo examinou ao menos um arquivo, que é o que §13 cobra.

O texto é recuperável, e recuperei — a revisão 1 marcou esta como não checada, e o inverso vai colado agora:

```
node inverso.mjs .forge/product/current/capabilities/forge-harness-template/spec.yaml 40
  entrada: 16651 caracteres
  saida:   269 caracteres
```

O programa `inverso.mjs` está no Apêndice A e cabe em duas linhas de lógica — `linha.replace(/\\+"/g, '"').replace(/\\{2,}/g, '\\')`, que colapsa run de barras antes de aspas para uma aspas e run de duas ou mais barras para uma barra. O resultado é prosa íntegra: *"rules/architecture/observability.md estendida com a seção "Golden Signals e Alerts-as-Code" (alertas como código versionado, schema alerts-as-code) e a stack OSS OTel Collector→Tempo/Loki/Prometheus/Grafana (Jaeger como alternativa compatível via OTLP)"*. O valor original tinha um par de aspas internas, e é ele que a corrupção vinha dobrando desde a primeira gravação.

### 5.3 A correção não é uma linha — o fuzzer provou isso, e é o argumento de existência dele

**Todas as medições desta seção foram refeitas com a bancada do Apêndice A, e os números mudaram em relação à revisão 1 porque a bancada anterior não era reproduzível.** Três versões do par foram construídas na bancada, por patch com âncora literal e `assert` de que a âncora foi encontrada:

| Versão | O que muda |
|---|---|
| **hoje** | `template/.forge/scripts/lib/yaml-lite.mjs` sem alteração |
| **A** — conserto óbvio | só o leitor: `coerceScalar` desfaz o escape ao ler escalar entre aspas duplas |
| **B** — conserto completo do leitor | A, mais `stripTrailingComment` ciente de escape, mais tabulação normalizada **apenas na indentação** |
| **C** — par completo | B, mais `yamlQuote` escapando `\n`/`\r`/`\t` e o leitor desfazendo as cinco sequências |

Os quatro comandos e as quatro saídas, na íntegra:

```
node prop.mjs classify $B/forge/scripts/lib/yaml-lite.mjs 500  20260907
  alfabeto=18 simbolos  casos=500  seed=20260907  comprimento=1..12
  falhas=309 de 500     aspas 75 | barra 53 | aspas+barra 30 | tabulacao 151
  contraexemplo mais curto: "\""

node prop.mjs classify $B/yaml-A.mjs 500 20260907   → falhas=153 de 500   (tabulacao 151 | aspas 1 | aspas+barra 1)
node prop.mjs classify $B/yaml-B.mjs 500 20260907   → falhas=0 de 500
node prop.mjs classify $B/yaml-C.mjs 500 20260907   → falhas=0 de 500
```

O conserto óbvio corta de 309 para 153 e deixa a outra metade de pé. Classificando sobre 2.000 casos, com o mesmo alfabeto de 18 símbolos e a mesma semente:

```
node prop.mjs classify $B/forge/scripts/lib/yaml-lite.mjs 2000 20260907
  falhas=1265 de 2000   aspas 297 | barra 251 | aspas+barra 115 | tabulacao 602
node prop.mjs classify $B/yaml-A.mjs 2000 20260907
  falhas=607 de 2000    tabulacao 602 | aspas 3 | aspas+barra 2
node prop.mjs classify $B/yaml-B.mjs 2000 20260907   → falhas=0 de 2000
node prop.mjs classify $B/yaml-C.mjs 2000 20260907   → falhas=0 de 2000
```

As 607 residuais do candidato A são três defeitos independentes, e a classificação os separa:

| Falhas em 2.000 | Classe | Causa |
|---|---|---|
| 602 | **tabulação no valor** | `parseYamlSubset:100` faz `l.replace(/\t/g,'  ')` na **linha inteira**, então uma tabulação dentro de um escalar aspeado vira dois espaços e o valor não volta |
| 3 | **aspas duplas seguidas de espaço-cerquilha** | `stripTrailingComment` alterna `inDouble` na aspas **escapada**, conclui que está fora de aspas e trunca o valor no ` #` |
| 2 | **barra invertida junto com os dois casos acima** | mesma causa da linha anterior |

São três defeitos independentes numa função de doze linhas, e dois deles nenhum autor imaginaria. É exatamente o argumento da rule de PBT, agora com número: o autor escreveu o código pensando nos exemplos que imaginou.

**A medição que decide o bloqueador 4, com o alfabeto estendido a 20 símbolos incluindo `\n` e `\r`:**

```
node prop.mjs classify-ctrl $B/forge/scripts/lib/yaml-lite.mjs 2000 20260907  → falhas=1537 de 2000
node prop.mjs classify-ctrl $B/yaml-B.mjs 2000 20260907                       → falhas=951 de 2000
node prop.mjs classify-ctrl $B/yaml-C.mjs 2000 20260907                       → falhas=0 de 2000
```

O candidato B — que conserta só o leitor, e é o que a revisão 0 descrevia — deixa **951 de 2.000** falhando sobre o domínio completo. Só o par corrigido dos dois lados fecha em zero. É o número que manda o conserto ao emissor em vez de mandar a exclusão ao gerador.

**Controle e recontrole sobre o repositório inteiro, contra o candidato C.** Parseei os arquivos `.yaml`/`.yml` de `template/`, `.forge/`, `docs/` e `tests/` com as duas versões e comparei o JSON serializado:

```
node diff-arvore.mjs . $B/forge/scripts/lib/yaml-lite.mjs $B/yaml-C.mjs
  arquivos=92  identicos=75  divergentes=15  erro_nos_dois=2  erro_so_em_A=0  erro_so_em_B=0
  DIF .forge/product/current/capabilities/forge-harness-template/spec.yaml  json_A=498429 json_B=269165
  … (mais 14 linhas DIF, todas de spec-delta.yaml, verification.yaml, approvals.yaml e adapters)
  ERRO_AMBOS template/github/workflows/staging.yml
  ERRO_AMBOS tests/fixtures/w132/contracts/widgets-api.v1.yaml
```

**75 idênticos, 15 divergentes, e os mesmos 2 erros de parse dos dois lados** — a revisão 0 dizia 76/14, e o erro era meu. As 15 divergências são todas na direção de recuperar conteúdo, e o `spec.yaml` corrompido cai de **498.429 para 269.165** caracteres de JSON serializado. Os 2 erros comuns são `template/github/workflows/staging.yml` e `tests/fixtures/w132/contracts/widgets-api.v1.yaml`, dois arquivos que nenhum consumidor de produção entrega ao `yaml-lite` e que estão fora do subset por desenho — nomeados aqui porque uma afirmação de "nenhuma regressão" sem esses dois seria incompleta.

**A décima-sexta divergência, e ela é a que quase virou defeito novo.** `node diff-arvore.mjs . $B/yaml-B.mjs $B/yaml-C.mjs` devolve `identicos=89 divergentes=1`, e o único arquivo é `.forge/specs/archived/2026-09-04-gate-assert-visibility/approvals.yaml` — o campo `reason` contém a prosa `sem o \n na classe negada`, escrita por `approval-log.sh:83`, que escapa aspas e não escapa barra. É o achado de §4.1 chegando por outro caminho, e a razão de os dois emissores em bash entrarem no escopo.

**Não prescrevo o patch, e o Apêndice A é evidência, não prescrição.** Os quatro consertos acima foram executados por mim numa cópia em `$TMPDIR` e servem como prova de que a propriedade é **alcançável**, o que uma especificação precisa provar antes de exigir um verde. O apêndice publica o patch que eu apliquei para que os números sejam reproduzíveis, e não para que o implementador o copie: a escolha do primitivo é dele, sob a obrigação da invariante 19 de demonstrar que a propriedade discrimina, por controle e recontrole. O que é **normativo** é o resultado — zero falha sobre o domínio completo de 20 símbolos, e os dois emissores em bash escapando a barra invertida.

### 5.4 Decisão fechada sobre a migração — detectar sempre, reescrever nunca sem ordem

**Decisão:** a correção do par emissor/parser entra nesta onda. A **migração** do dado já corrompido é operação separada, `--check` por default e `--apply` explícito, e nunca roda como efeito colateral de um archive, de um update ou de um doctor.

O motivo é a Onda A, que existe porque `handoff-render.mjs` reescrevia um arquivo de 290.761 bytes sem backup e saía com código zero. Uma migração automática de baseline seria a mesma classe de operação, com a agravante de que o baseline é a memória do projeto. O `doctor` **relata** a corrupção e aponta o comando; quem decide escrever é o humano.

**Como a migração recupera o valor, e por que não basta desfazer barras.** O texto recuperado da linha 40 contém aspas internas **sem escape**, e nessa forma ele não é um escalar válido do subset. A migração portanto não é uma substituição de texto: ela **lê o valor lógico** pelo inverso medido em §5.2, e o **reemite** pelo emissor corrigido. É o par completo, não meia operação.

**Efeito sobre o adotante que não migrar.** A correção do parser desfaz **uma** geração de dobra a cada leitura, então um arquivo com run 15 passa a ser lido com run 7 — melhor que hoje e ainda errado. A migração é o único caminho para o valor original, e o detector existe para que a escolha de não migrar seja consciente em vez de invisível.

**Escopo do dano fora deste repositório.** Os dezesseis arquivos dos dois adotantes atingidos ficam **fora** desta onda: escrever em repositório de terceiro não é ato do harness. O que a onda produz é a ferramenta e a mensagem, e a Onda I carrega o aviso pelo canal de liaison — **e a mensagem carrega a saída do censo rodado no dia do envio, não a tabela de §5.2**, que é testemunha de 2026-09-07 e terá envelhecido. A revisão 1 mostrou que a lista escrita à mão sub-relatava o dano em mais de três vezes; mandar o comando junto com o resultado é o que impede a Onda I de repetir o erro.

**Itens novos de ledger — são dois, e a citação normativa da revisão 0 estava errada.** O defeito da corrupção recebe registro próprio, referido aqui como **LDG-NOVO-1**; ele nasce e fecha nesta onda, e o registro cita o percentual medido, a linha do código, a saída do censo e o gate que passa a guardar a propriedade. O segundo, **LDG-NOVO-2**, nasce **aberto**: são os scanners `java-quality-scan` e `python-quality-scan` que §3.2 decidiu deixar de fora, com o escopo escrito e o molde nomeado (`w155` [8]-[10] e [12], `w180` [8]-[12]).

Os dois ids são alocados pelo **orquestrador** no momento da escrita, e não por esta especificação. A revisão 0 atribuía essa prática à "invariante 10", e a revisão 1 mostrou que a invariante 10 trata de **ordinal de gate**, não de id de ledger — a prática é a certa e a citação era falsa. A âncora correta é operacional: `python3 -c "import json;d=json.load(open('.forge/ledger/ledger.json'));print(max(i['id'] for i in d['entries']))"` devolve **LDG-0176** hoje, e há **22** itens `open`, de 107 entradas. Os dois números são testemunhas de data e servem só para o orquestrador saber de onde continuar.

**Por que aqui e não na Onda A.** A Onda A tem o mesmo tema — perda de dado com código zero — e seria o lar temático. Duas razões medidas mandam o item para cá: a especificação da Onda A já passou por cinco rodadas de revisão e reabri-la custaria essas rodadas de novo; e a propriedade que guarda a correção **é** o produto da fatia de fuzzing, de modo que separá-los deixaria a Onda H com um fuzzer que não encontrou nada, que é a definição de fuzzer que ninguém mantém.

---

## 6. O Vermelho, antes do Verde

Três gates, um por item. Cada um nasce vermelho por ausência real da funcionalidade, e o parágrafo abaixo diz qual asserção falha, com que mensagem, e por quê.

### 6.1 Gate α — enforcement de TDD-em-feature e de cobertura por propriedades

| Asserção | Falha hoje porque | Mensagem esperada no vermelho |
|---|---|---|
| `quality.require_red_before_archive` consta de `forge.yaml` e do `forge.schema.json` | nenhuma das duas a declara — `grep -c` devolve zero nos dois arquivos | `chave ausente em forge.yaml` |
| a chave tem leitor que **decide** — ocorrência fora de linha de comentário, em `scripts/`, `hooks/` ou `bin/` | não há leitor: `grep` devolve zero ocorrências em qualquer arquivo executável | o mesmo predicado de `w192[1]`, com a chave nova na lista |
| change `type: feature` sem `red-evidence.json`, com a chave em `true`, **reprova** o pré-flight e **nomeia a chave** | o pré-flight aprova com `rc 0`, medido em §2.2 | `pré-flight aprovou um change feature sem Red observado com a chave em true` |
| o mesmo change com a chave em `false` **aprova** e o pré-flight **declara a dispensa** | a chave não existe, então não há dispensa a declarar | `passou em silêncio sobre a dispensa` |
| `red-evidence.sh init` aceita `type: feature` | recusa hoje, `red-evidence.sh:122` | `init só se aplica a change type:bugfix, got: feature` |
| `status: not-possible` num change `feature`, com a chave em `true`, **reprova** com mensagem distinta de `pending` | não há leitor | `not-possible aprovou o archive de uma feature` |
| a chave em `true` com **zero** entradas `PBT-` no `traceability.yaml` emite `NÃO VERIFICADO` e **não** uma nota de conformidade | o protótipo de §2.5 aprovou com `0 propriedade(s) declarada(s), todas com TASK e evidence` | `nota de conformidade sobre universo vazio` |
| `quality.require_property_coverage_before_archive` consta e tem leitor | nenhuma das duas coisas existe | idem primeira e segunda linhas |
| entrada `PBT-01` no `traceability.yaml` com `evidence: []`, com a chave em `true`, **reprova** nomeando `PBT-01` | não há leitor de `PBT-` em código executável — as 5 ocorrências no repositório são comentários | `pré-flight aprovou propriedade declarada sem evidência` |
| a mesma entrada com um item em `evidence` **aprova** e o pré-flight **declara** que a exigência foi satisfeita | idem | `aprovou sem declarar que a exigência foi satisfeita` |
| `templates/spec/requirements.md` tem a seção `PBT-NN` | `grep -i pbt` devolve zero no template | `template sem lugar para declarar propriedade` |
| `rules/testing/property-based-testing.md` não contém mais a frase que declara a lacuna | a frase está lá, linha 56 | `a rule ainda declara que o check não existe` |

A última asserção é a que mais me importa e é a mais fácil de escrever mal: ela **não** pode ser um `grep -v` da frase antiga e nada mais, porque apagar a frase satisfaz o predicado sem entregar nada. Ela é pareada com um sinal positivo — a rule precisa citar nominalmente a chave nova e o artefato onde a propriedade é declarada.

### 6.2 Gate β — enforcement de Java e Python

**Espelha uma lista NOMINAL de cenários dos dois moldes, e não "cenário a cenário".** A revisão 1 mostrou que a fórmula anterior deixava em aberto se a onda entregava scanners por stack; §3.2 decidiu que não, e a consequência é esta lista fechada, que o implementador pode contar antes de escrever:

| # | Cenário de gate β | Espelha |
|---|---|---|
| [0] | fixtures greenfield e brownfield montadas em `$TMPDIR` | `w155[0]`, `w180[0]` |
| [1] | os assets do pack existem e são sintaticamente válidos (TOML por `tomllib`, XML por `xml.etree`) | `w155[1]`, `w180[1]` |
| [2] | `--check` reprova numa fixture sem configuração, nomeando o que falta | `w155[2]`, `w180[2]` |
| [3] | `--apply` materializa e o `--check` seguinte aprova | `w155[3]`, `w180[3]` |
| [4] | `--apply` **não** sobrescreve configuração existente sem `--force` | `w155[4]`, `w180[4]` |
| [5] | severidade default varia por greenfield contra brownfield | `w155[5]`, `w180[5]` |
| [6] | a armadilha da stack está documentada no `PROFILE.md` e cobrada pelo `--check` | `w155[6]`, `w180[6]` |
| [7] | **Gradle**: `--check` reporta `INFO java:gradle` e nunca escreve em `build.gradle*` | sem molde — específico desta onda |
| [8] | **Maven e Gradle na mesma raiz**: `WARN java:ambiguo` nomeando os dois, sem decidir | sem molde — o caso não coberto de §3.2 |
| [9] | portabilidade: sem a ferramenta da stack no `PATH`, o script **não** vira `FAIL` por ausência de motor | `w155[10]`, `w180[10]` |
| [10] | fiação nos cinco pontos, com contador próprio | `w155[11]`, `w180[13]` |
| [11] | frontmatter válido nos artefatos tocados | `w155[12]`, `w180[14]` |
| [12] | canal de entrega: harness instalado de verdade, `doctor` de verdade | `w155[13]`, `w180[15]` |
| [13] | mutação com controle e recontrole por `cmp` sobre a íntegra | `w180[11]` |
| [14] | universo vazio: zero pack no diretório reprova com `universo-vazio` | `lib/gate-universe.sh` |

**Os cenários que gate β NÃO espelha, e por quê:** `w155` [8] (uma linha por regra), [9] (achado no sujo e ausência no limpo) e [12] no sentido de frontmatter de skill, e `w180` [8], [9] e [12] (`verify.mjs` sob `RuleTester` real) existem **por causa da skill determinista de scan**, que esta onda não entrega. Contar 8 ou 16 cenários era a ambiguidade que a revisão 1 apontou; a resposta é 15, listados acima.

Vermelho hoje na primeira asserção: `[ -f "$PACK/assets/pyproject.toml" ]` falha porque `find template/.forge/capabilities/backend-python-relational -type f` devolve exatamente um arquivo, e `PROFILE.md` não é asset. As demais caem em cascata pela mesma ausência: não há script para `--check` reprovar, não há `--apply` para materializar, não há linha no `doctor` para casar.

**O cenário [10] é o que precisa ser específico em vez de um `grep` frouxo**, e a revisão 1 mostrou por quê: ele exige que **cada um** dos cinco pontos da tabela de §3.2 — reviewer, `verify-build`, `doctor`, `installer/forge-init.md` e `PROFILE.md` com conteúdo nomeado — cite a maquinaria nova, com contador próprio e piso 5 por stack, porque quatro de cinco passando é o falso-verde clássico. A revisão 0 nomeava dois pontos que os moldes não grepam e omitia os dois que eles grepam, o que faria este cenário nascer vermelho por omissão da especificação.

### 6.3 Gate γ — round-trip do par emissor/parser e detector de corrupção

| Asserção | Falha hoje porque | Mensagem esperada |
|---|---|---|
| a propriedade `parse(render(x)) === x` vale para todo `x` gerado, incluindo aspas, barra, tabulação, `\n` e `\r` | 1.265 de 2.000 casos falham no alfabeto de 18 e 1.537 de 2.000 no de 20, medido em §5.3 | `round-trip quebrado em N de M casos`, com contraexemplo minimizado |
| o alfabeto do gerador **contém** aspas, barra, tabulação e os dois caracteres de controle, e a asserção é sobre o alfabeto, não sobre a taxa | é a ausência dos três primeiros que faz `w162[4]` passar hoje sobre a mesma lacuna | `gerador não cobre os caracteres que quebram a propriedade: <lista>` |
| **o domínio é declarado em letra e o gate o assere** — nenhum caractere é excluído em silêncio | não há propriedade e não há declaração | `domínio da propriedade não declarado` |
| todo emissor de YAML do harness está coberto pela propriedade, com o denominador derivado de §4.1 | a cobertura não existe | `emissor sem propriedade de round-trip: <caminho>` |
| **contrapositiva do denominador**: um emissor sintético plantado **fora** de `scripts/lib/` — em `template/.forge/hooks/` ou num `.sh` que emita `chave: "..."` — faz o gate **reprovar nomeando o caminho** | o denominador da revisão 0 só olhava `lib/*.mjs` e aprovaria por não ter olhado | `emissor sem propriedade de round-trip: template/.forge/hooks/<sintetico>` |
| `approval-log.sh` e `spec-close.sh` escapam a barra invertida junto com a aspas | escapam só a aspas: `grep -rn 's/"/\\\\"/g' template/.forge` devolve as quatro linhas | `emissor em bash escapa aspas e não escapa barra: <arquivo>:<linha>` |
| o detector de corrupção acha o padrão no arquivo corrompido e **não** acha no arquivo íntegro | o detector não existe | `detector aprovou arquivo com run 8191` |
| a migração em `--check` **não escreve** — conferido por `cmp` contra a cópia íntegra — e a migração em `--apply` recupera o valor original | não existe migração | `--check escreveu no arquivo` |
| universo vazio: zero emissor encontrado reprova com `universo-vazio` | não existe gate | `universo-vazio` de `lib/gate-universe.sh` |

Dois cenários carregam a lição da onda inteira. O **do alfabeto** é o que fecha o argumento de §2.4: o gate que prova a propriedade precisa provar também que o gerador dela gera o caso difícil, senão esta onda reproduziria em outro arquivo o defeito que encontrou no `w162`. E o **da contrapositiva do denominador** é o que a revisão 1 exigiu, porque sem ele a promessa de §4.1 — "um par novo reprova no dia em que nascer" — vale só para pares novos que nasçam no diretório onde os antigos já moram, que é uma promessa sobre o passado.

---

## 7. Prova de mutação — o que mutar, o que o gate acusa, restauração e recontrole

Todas as linhas abaixo têm **contrafactual medido nesta rodada** ou estão marcadas como contrafactual a medir pelo implementador, conforme a invariante 16. Nenhuma linha declara efeito que eu não observei.

A restauração é sempre por **cópia da íntegra**, nunca por reversão de `sed`, e é conferida com `cmp` contra a cópia guardada antes da mutação — o `feedback-mutacao-fantasma-restore` registra o caso em que um `restore()` quebrado deixou a mutação eterna. E nenhuma mutação usa `perl -0pi -e` com `$` do lado direito: LDG-0164 registra que essas são variáveis do **perl**, vazias, e a mutação vira no-op enquanto o `cmp` confirma que o arquivo mudou. As mutações desta onda usam `python3` sobre a cópia, com âncora literal e `assert` de que a âncora foi encontrada — que foi o mecanismo que usei em §5.3 e que abortou corretamente quando errei a âncora na primeira tentativa.

**Nenhuma linha desta tabela está marcada "a medir na implementação".** A revisão 0 tinha seis assim, e a invariante 16 diz em letra que o contrafactual vem **antes** de a linha ser escrita. Onde o alvo da mutação ainda não existe, o contrafactual foi medido sobre um **protótipo** do leitor instalado na bancada (linhas a, b, c) ou sobre o **molde já em produção** cuja mecânica a onda replica (linhas d, e, f). O protótipo está no Apêndice A e não é o patch prescrito — ele existe só para que a mutação tivesse o que mutar.

| # | O que mutar | O que o gate deve acusar | Contrafactual medido |
|---|---|---|---|
| (a) | remover a consulta a `require_red_before_archive` no pré-flight | o change `feature` sem Red passa a aprovar | **MEDIDO** sobre o protótipo: controle `rc=1` com `require_red_before_archive: true e o change type:feature nao carrega evidence/red/red-evidence.json`; mutado `rc=0` com `OK ch-feat`; restaurado por cópia da íntegra e conferido por `cmp`; recontrole `rc=1` |
| (b) | remover a consulta a `require_property_coverage_before_archive` | `PBT-01` sem `evidence` passa a aprovar | **MEDIDO**: controle `rc=1` com `1 propriedade(s) sem TASK ou sem evidence: PBT-01`; mutado `rc=0`; `cmp` limpo; recontrole `rc=1` |
| (c) | trocar o predicado `^PBT-` por `^PBT` sem âncora de hífen | um requisito `PBTX-01` passa a ser cobrado como propriedade | **MEDIDO, e a primeira tentativa foi no-op**: com a fixture em que `PBTX-01` tinha `evidence` preenchida, controle e mutado deram o **mesmo** `rc=1` e a mesma mensagem — a mutação não discriminava. Com a fixture pareada corrigida (`PBT-01` completo, `PBTX-01` **sem** `evidence`): controle `rc=0`; mutado `rc=1` com `1 propriedade(s) sem TASK ou sem evidence: PBTX-01`; recontrole `rc=0`. **A fixture pareada é normativa**, e sem ela esta linha seria mutação-fantasma |
| (d) | remover uma chave load-bearing do asset do pack Python | `--check` reprova nomeando a chave do `pyproject.toml` | **MEDIDO por análogo no molde**, porque o asset Python ainda não existe: sobre `dotnet-baseline.sh --check` numa fixture materializada por `--apply`, controle `rc=0` com 13 linhas de regra; removida `<TreatWarningsAsErrors>` do `Directory.Build.props`, `rc=1` com `FAIL Directory.Build.props:TreatWarningsAsErrors (propriedade ausente)`; restaurado por cópia e `cmp`; recontrole `rc=0` |
| (e) | remover `failOnViolation` do plugin de análise do asset Java | `--check` reprova nomeando o plugin | **MEDIDO pelo mesmo análogo de (d)** — é a mesma mecânica de "a configuração existe e está incompleta". Registro o erro de medição que cometi aqui: a primeira leitura deu `rc=0` nos dois lados porque eu li `$?` depois de `bash script \| tail -3`, e o `rc` do pipeline é o do `tail`. Sem pipe, `rc=1` |
| (f) | remover a linha do baseline Java do `doctor.sh` | o cenário de fiação reprova nomeando `doctor` | **MEDIDO por análogo no molde**: sobre uma cópia de `doctor.sh`, `grep -q 'dotnet-baseline'` casa (controle); trocado o token, não casa e o predicado de `w155[11]` produz `doctor não confere o baseline de build .NET` (mutado); restaurado por cópia e `cmp`; recontrole casa |
| (g) | **desfazer o unescape na leitura de escalar aspeado** | a propriedade reprova com contraexemplo contendo aspas | **MEDIDO**: 1.265 falhas em 2.000 no estado de hoje, que é exatamente esta mutação, contra 0 no candidato completo. Contraexemplo mais curto observado: `"\""` |
| (h) | **restaurar a normalização de tabulação para a linha inteira** | a propriedade reprova com contraexemplo contendo tabulação | **MEDIDO**: 607 falhas em 2.000 com o unescape presente e a tabulação normalizada na linha inteira, das quais **602** são da classe `tabulacao`. Contraexemplo mais curto: `"\t"` |
| (i) | **tornar `stripTrailingComment` cego a escape** | a propriedade reprova com aspas seguidas de espaço e cerquilha | **MEDIDO**: 3 falhas da classe `aspas` mais 2 da classe `aspas+barra` em 2.000, isoladas pela classificação do mesmo comando de (h) |
| (k) | **desfazer o escape de `\n`/`\r`/`\t` no emissor**, mantendo o leitor corrigido | a propriedade reprova sobre o alfabeto de 20 símbolos | **MEDIDO**: 951 falhas em 2.000 com `classify-ctrl` sobre o candidato B, contra 0 sobre o candidato C |
| (l) | **remover o escape de barra invertida de `approval-log.sh`**, deixando só o de aspas | o cenário dos emissores em bash reprova nomeando arquivo e linha | **MEDIDO como estado de hoje**: é a linha 83 do arquivo em produção, e o efeito observado é a divergência de leitura em `.forge/specs/archived/2026-09-04-gate-assert-visibility/approvals.yaml`, único dos 92 YAML da árvore em que os candidatos B e C discordam |
| (j) | **remover aspas, barra e tabulação do alfabeto do gerador** | o cenário de cobertura do alfabeto reprova nomeando os caracteres ausentes | **MEDIDO por controle e recontrole**: com o alfabeto de `w162[4]`, que exclui os três, a propriedade passa sobre o código defeituoso; com os três presentes, falha em 1.265 de 2.000 sobre o mesmo código |

A linha (j) continua sendo a mais importante da tabela: ela é a única cujo contrafactual mede o **gate**, e não o alvo. As demais provam que a propriedade morde o código; a (j) prova que o gerador da propriedade não foi calibrado para o verde. E a linha (c) ganhou o segundo lugar por acidente instrutivo — ela é a única cuja **primeira** medição foi no-op, e o que a salvou foi rodar a mutação em vez de declará-la.

---

## 8. Contador de controle — denominadores, e qual é fixo por construção

A invariante 3 exige que todo gate publique quantas condições examinou e reprove quando esse número é zero ou menor que o esperado. A invariante 14 exige que nenhum número que conta arquivos, gates ou entradas seja literal. As duas convivem assim:

| Gate | Contador | Origem | Piso |
|---|---|---|---|
| α | cenários do próprio gate | fixo por construção — é a exceção legítima da invariante 14, e a divergência é o achado | igual ao total |
| α | interruptores de `quality:` examinados | derivado de `forge.yaml` e do schema **na execução** | 4 — as duas herdadas mais as duas que a onda entrega |
| α | entradas `PBT-` examinadas no `traceability.yaml` | derivado do artefato na execução | 0 é **universo vazio**, não conformidade — ver §2.5 |
| β | packs de capability examinados | `ls -d template/.forge/capabilities/*/` na execução | 4 |
| β | pontos de fiação examinados por stack | fixo por construção — são os cinco da tabela de §3.2 | 5 por stack, 10 no total |
| γ | emissores de YAML examinados | derivado na execução sobre **todos** os `.mjs` de `template/.forge/**` e `bin/` que citem `yamlQuote`/`yamlFlowList`, **mais** os `.sh` que emitam `chave: "..."` com escape manual, menos o próprio `yaml-lite.mjs` | 5 |
| γ | casos de propriedade executados | fixo por construção, com seed fixa | igual ao total |
| γ | símbolos do alfabeto do gerador | derivado do gerador na execução | 20 — os 18 de §5.3 mais `\n` e `\r` |
| γ | arquivos YAML rastreados varridos pelo censo | derivado de `git ls-files` na execução | 1 |
| w200 | linhas de inventário do README e o badge `gates-N` | derivado da árvore pelo gate que já existe | ver §11 |

**Uma correção de justificativa que a revisão 1 pegou, e ela importa porque um implementador copiaria o molde errado.** A revisão 0 escrevia que o contador de interruptores é "derivado de `forge.yaml` e do schema na execução, **como `w192` já faz**". `w192` **não** faz: `sed -n '43,46p' tests/w192-declared-switch-has-reader-gate.sh` mostra `SWITCHES=(...)` como array bash com duas entradas fixas, e nada ali é derivado. O mecanismo prescrito — derivar, com piso — continua sendo o certo; a justificativa por precedente é que era falsa, e quem copiasse `w192` entregaria o literal que a invariante 14 proíbe. **`w192` é o molde do predicado de leitor, não do denominador.**

**Por que piso e não igualdade nos denominadores derivados.** Porque a própria onda muda três deles: ela acrescenta assets a dois packs, acrescenta chaves a `quality:` e pode acrescentar emissores. Três especificações desta rodada nasceram com esse defeito, cada uma com o seu número, e em dois casos o revisor mostrou que o literal quebraria no dia da entrega. O piso é o contrato: menos que isso é gate que aprovou por não ter olhado; mais que isso é a onda seguinte fazendo o seu trabalho.

**A anti-vacuidade, e ela não é opcional.** Cada gate tem um cenário que zera o seu universo — lista de interruptores vazia, nenhum pack no diretório, nenhum emissor encontrado, alfabeto sem os caracteres difíceis — e exige reprovação com o token `universo-vazio` de `template/.forge/scripts/lib/gate-universe.sh`. Sem ele, apagar os dados "conserta" o drift e o gate aprova por não ter examinado nada, que é o defeito que `w192[6]` e `w200[2]` já guardam nos seus domínios.

**E a vacuidade não é só do gate: ela é do próprio enforcement, e eu a encontrei dentro da minha prova de existência.** O protótipo do leitor de `require_property_coverage_before_archive`, rodado com zero entradas `PBT-`, imprimiu `0 propriedade(s) declarada(s), todas com TASK e evidence` e aprovou. Uma nota de conformidade sobre universo vazio é indistinguível, para quem audita o archive seis meses depois, de uma nota sobre um universo examinado — e é o mesmo defeito que a chave existe para consertar, um nível acima. Por isso a linha de piso de α diz que zero é universo vazio e não conformidade, e por isso §6.1 tem um cenário só para isso.

---

## 9. Onde entram PBT, contrato, integração e E2E

**PBT — aplica-se, e é o coração de um terço da onda.** A propriedade de round-trip do par emissor/parser é PBT no sentido estrito da rule: entrada gerada de um domínio válido, seed fixa, shrinking, e verificação do gerador. O quarto item da rule (exigir shrinking) e o quinto (verificar o embaralhador) têm tradução direta aqui: o contraexemplo precisa ser minimizado, e o alfabeto do gerador precisa ser assertado, que é a asserção `(j)` da matriz de mutação. `lib/pbt.mjs` já oferece PRNG por seed e shrinking, então a onda usa o que existe e não escreve motor novo.

**PBT — segundo sítio, menor.** O predicado `^PBT-` que o pré-flight aplica é um reconhecedor sobre um espaço de identificadores, e um teste de propriedade sobre identificadores gerados (`REQ-01`, `PBT-01`, `PBTX-01`, `pbt-01`, `PBT-`, string vazia) custa poucas linhas e cobre a mutação (c). Aplica-se.

**Teste de contrato — aplica-se, em três fronteiras publicadas.** Primeira: `forge.schema.json` ganha duas propriedades, e o `additionalProperties: false` do bloco `quality` significa que um `forge.yaml` com a chave nova **reprova** contra um schema antigo; o teste é a validação de um `forge.yaml` que declara as duas chaves contra o schema entregue. Segunda: `traceability.schema.json` **não** muda — e o teste de contrato é justamente a prova disso, um `traceability.yaml` com `requirement_id: PBT-01` validado contra o schema de hoje, que é o que sustenta a decisão de §2.5. Terceira: a assinatura de `java-baseline.sh` e `python-baseline.sh` é contrato com adotante — `--check`/`--apply`/`--force`/`--root` e os códigos de saída 0, 1 e 2 —, e o teste exige a mesma superfície dos dois scripts irmãos.

**Teste de integração — aplica-se, e é onde o gate α precisa viver.** O defeito de §2.2 não é de função, é de política: a função de leitura de chave está correta, e ninguém a chama para `feature`. Um teste unitário sobre o leitor nasceria verde e não diria nada — é a invariante 7 do plano-mestre, e LDG-0160 é o caso puro dela. O cenário exercita o caminho real, do `spec-new.sh` ao `validate-archive.mjs`, no molde de `mkfix`/`mk_verified` que `w192:119-141` já estabelece.

**E2E — aplica-se em um ponto e é caro em outro.** O caminho `spec new → transition → verify → approval → validate-archive` numa fixture com `git init` é E2E o bastante para esta onda, e é o que a bancada de §2.2 já percorreu. O que **não** cabe é E2E do replay real para uma feature: o motor cria worktrees efêmeros e roda um teste de verdade, com teto de tempo de 600 segundos em `spec-verify.sh:122`, e um cenário desses dentro da suíte a torna refém do relógio. A onda cobre o replay de feature por **teste de integração** sobre `deriveBase`, com um repositório de fixture de três commits, e declara que a cobertura E2E do replay continua sendo a que `w107` e `w108` já dão para `bugfix` — cujo motor, medido em §2.3, é o mesmo arquivo sem uma linha de acoplamento a tipo.

**O que não se aplica, com justificativa medida.** Fuzzing diferencial contra um parser YAML completo não se aplica: o harness é zero-dependência por contrato em `template/.forge/**`, e `lib/pbt.mjs:3-7` registra que é essa restrição que faz o motor existir. Sem oráculo externo, a propriedade de round-trip é o oráculo — e ela é suficiente, provado pelas **1.537 falhas em 2.000 casos** que encontrou, distribuídas em quatro classes distintas (aspas, barra, tabulação e caracteres de controle) e reduzidas a zero pelo candidato completo.

---

## 10. Retrocompatibilidade — o que já está instalado e o que quebra

**As duas chaves novas: nada quebra, e a razão é medida.** `validate-archive.mjs:97` define `wants` como igualdade estrita com `true`, e o comentário de `:95` declara que ausência não liga o enforcement. Um adotante com `forge.yaml` da 0.14.0 não tem as chaves, e o pré-flight se comporta exatamente como hoje. O sentido do risco é o seguro: quem não sabe da chave não é bloqueado por ela.

**O schema é a única fronteira onde a ordem importa.** O bloco `quality` do `forge.schema.json` tem `additionalProperties: false`, medido. Um adotante que escreva a chave nova no `forge.yaml` **antes** de atualizar o harness reprova a validação. A mitigação é a ordem natural — a chave chega com o update que traz o schema —, e a mensagem de recusa do validador já nomeia a propriedade desconhecida.

**Os packs Java e Python: nada quebra, e há uma armadilha nomeada.** Os dois scripts novos são no-op silencioso onde a stack não existe, no molde medido de `node-baseline.sh:60-66`. A armadilha é o `--apply` num repositório Java com `pom.xml` preexistente: a decisão de §3.2 é que ele **não** escreve por cima, e o `--check` cobra o conteúdo. Um `--apply` que escrevesse seria a repetição do defeito que a Onda A fecha, num arquivo que é o build inteiro do projeto.

**A correção do `yaml-lite`: aqui há mudança de comportamento observável, e ela é a razão da migração.** Os 15 arquivos que mudam de valor lido, medidos em §5.3, são todos arquivos onde o valor lido hoje está errado. O adotante que atualizar sem migrar lê uma geração a menos de corrupção. Nenhum gate rastreado afirma a forma corrompida: `grep -rn 'yaml-lite\|coerceScalar\|yamlQuote' tests/` devolve **doze linhas em sete arquivos**, e nenhuma delas afirma o valor de um escalar com escape — `w162` afirma o round-trip **num alfabeto que exclui os caracteres afetados**, `yaml-lite-gate.sh` afirma o strip de comentário final, e as demais apenas copiam o arquivo para uma fixture. Varredura executada nesta rodada.

**A mudança do EMISSOR é fronteira nova, e a revisão 1 mandou reavaliá-la — reavaliada, e o sentido do risco é favorável.** `yamlQuote` passa a escapar `\n`/`\r`/`\t`, o que muda o **texto emitido** e não só o lido. Três medições sustentam que isso não quebra nada instalado. Primeira: hoje um valor com `\n` produz arquivo **ilegível** — `parseYamlSubset` estoura com `unparseable line` —, então não existe baseline em produção que contenha um `\n` emitido e que hoje volte certo; a mudança só cria valor onde antes havia exceção. Segunda: um valor com `\t` hoje volta com a tabulação substituída por dois espaços, silenciosamente, então a forma antiga já era perda de dado. Terceira, e é a que exigiu trabalho: um arquivo que contenha a **sequência de dois caracteres** `\` seguido de `n` — texto legítimo, escrito por gente — continua voltando correto, porque o emissor escapa a barra **antes** de tudo; medido na bancada, `x = "a\\nb"` emite `"a\\\\nb"` e volta `"a\\nb"`, idêntico.

**A exceção real, e ela é o motivo de os dois emissores em bash entrarem no escopo.** `approval-log.sh` e `spec-close.sh` escrevem YAML sem escapar a barra invertida, e um arquivo que eles produziram com uma barra no texto é lido corretamente **hoje** e passaria a ser lido errado com o leitor corrigido. Há **1** arquivo assim entre os 16 `approvals.yaml` rastreados. Corrigir os dois emissores junto com o par é obrigatório, e não opcional: sem isso a onda troca uma corrupção por outra.

**Retrocompatibilidade do `w162[4]` em particular, porque ele é o gate mais próximo.** Ele continua verde depois da correção, e não por acaso: o alfabeto dele é subconjunto do alfabeto novo de 20 símbolos, e a propriedade passa a valer para um domínio estritamente maior — o candidato completo dá **0 falhas em 2.000** sobre o alfabeto largo, então dá zero sobre qualquer subconjunto dele. O comentário que declara a exclusão deliberada **é editado no mesmo PR**, porque deixá-lo apontando para uma lacuna já fechada faria do próprio comentário a próxima mentira em prosa — a mesma classe do R8 de quatro raízes que a Fase 0 corrige.

---

## 11. Ordinal, fiação e efeitos colaterais na suíte

**Ordinal.** Os três gates recebem ordinais alocados pelo **orquestrador**, uma vez, no momento de escrever o arquivo, e conferidos contra `origin/*` **e** contra as branches em voo desta rodada. Nenhum ordinal é escrito nesta especificação. A razão é medida e recente: `ls tests/ | grep -oE '^w[0-9]+' | sort -n | tail -3` devolve **w205, w206, w207** nesta árvore, enquanto o plano-mestre, escrito no commit `49bc97d`, cita a suíte "em 132 arquivos" e o tronco em `w205` — o teto já andou duas casas entre o plano e esta especificação, e LDG-0167/LDG-0173 registram o pedágio de duas colisões numa noite.

**Contagem de gates, e a revisão 1 derrubou a frase que eu tinha escrito aqui.** A revisão 0 dizia que este número "não entra em asserção nenhuma". **Entra.** `tests/w200-readme-inventory-gate.sh`, cenário `[6]` (linhas 258-272), compara o badge do topo do README com a árvore:

```
grep -oE 'gates-[0-9]+' README.md | head -1 | cut -d- -f2   → 131
find tests -maxdepth 1 -name '*-gate.sh' | wc -l            → 131
ls tests/*.sh | wc -l                                       → 132   (o extra é tests/run-all.sh)
```

Badge e árvore concordam **hoje**. A onda acrescenta **três** arquivos `*-gate.sh` e o badge fica em `131` contra `134`, e `w200[6]` reprova no dia da entrega com `o badge do README diz 131 gate(s) e a árvore tem 134 — a mesma contagem à mão que este gate existe para impedir`. A varredura da revisão 0 examinou só as linhas `<dir>/ (N)` da seção `## 📁 Estrutura` e concluiu "conferido linha a linha na seção", sem ver que o mesmo gate mantém uma segunda contagem **fora** dessa seção, no badge da linha 12. É a armadilha A na sua forma mais literal, e ela pegou esta especificação.

**O badge `gates-N` do `README.md` entra na definição de pronto de §13, nominalmente**, ao lado das linhas de inventário. Os números 131, 132 e 134 desta subseção são testemunhas de data e não entram em asserção nenhuma — a asserção é a do próprio `w200[6]`, que deriva os dois lados na execução.

**O inventário do README envelhece com esta onda, e isso é obrigação de entrega, não observação.** `tests/w200-readme-inventory-gate.sh` confere as linhas `<dir>/ (N)` da seção `## 📁 Estrutura` do `README.md` contra a árvore real, por `find ... -type f ! -name 'README.md'`, recursivo. Medidas hoje, com os dois lados:

```
grep -nE '\([0-9]+\)' README.md
  228: agents/  (47)   229: commands/ (56)   230: contracts/ (5)   232: skills/   (20)
  233: rules/   (50)   234: schemas/  (27)   235: scripts/  (136)
for d in agents commands contracts skills rules schemas scripts; do
  find template/.forge/$d -type f ! -name 'README.md' | wc -l; done
  47  56  5  20  50  27  136
```

Os sete pares concordam hoje. A onda acrescenta ao menos dois arquivos em `scripts/` (`java-baseline.sh` e `python-baseline.sh`) e edita `rules/testing/property-based-testing.md` sem acrescentar arquivo. **`scripts/ (136)` e qualquer outra linha afetada são atualizadas no mesmo PR**, e isso entra na definição de pronto. `capabilities/` aparece na seção **sem contagem declarada** (`sed -n '231p' README.md` devolve `├── capabilities/       # packs opt-in por stack ...`), e o critério do gate é a linha na forma `<dir>/ (N)` — os assets novos dos packs, portanto, não afetam este gate. As sete contagens acima são testemunhas de data; a asserção é a do `w200`, derivada dos dois lados na execução.

**Os gates que esta onda toca ou que afirmam o que ela muda — lista nominal, exigida pela invariante 15.**

| Gate | Relação | Ação |
|---|---|---|
| `w192-declared-switch-has-reader-gate.sh` | o array `SWITCHES` é literal e lista as duas chaves de hoje | **editar**: as duas chaves novas entram na lista, e o piso do contador sobe junto |
| `w106-red-first-gate.sh` `[9]` | afirma que `type: feature` é no-op no `check` | **não editar**: a fixture não declara a chave nova, e o default é `false` |
| `w109-red-ci-gate.sh` `[4]` | afirma que `feature` não aparece no relato do `ci` | **não editar**: o escopo do `ci` não muda |
| `w144-gate-control-counter-gate.sh` `[4]` | cria um change `feature` e exige `rc 0` do `ci` | **não editar**: mesma razão |
| `w162-yaml-lite-flow-array-gate.sh` `[4]` | round-trip com alfabeto que exclui aspas e barra | **editar o comentário**, não o cenário: a exclusão deixa de ser lacuna e passa a ser subconjunto |
| `w200-readme-inventory-gate.sh` `[1]`-`[5]` | confere as contagens `<dir>/ (N)` do README | **não editar o gate**; editar `scripts/ (136)` no README |
| `w200-readme-inventory-gate.sh` `[6]` | confere o badge `gates-131` contra `find tests -maxdepth 1 -name '*-gate.sh'` | **não editar o gate**; editar o badge da linha 12 do README para `gates-134` |
| `plugin-sync-gate.sh` | reprova quando `plugin/forge/commands/` diverge de `template/.forge/commands/**` | **não editar o gate**; rodar `npm run build:plugin` no mesmo PR, porque a onda edita `commands/harness/capabilities.md` |
| `w155-dotnet-enforcement-gate.sh` | é o molde do gate β e tem o defeito de `python3` ausente descrito em §3.2 | **não editar**: o defeito vira item de ledger próprio |
| `w180-node-enforcement-gate.sh` | segundo molde do gate β | **não editar** |

As três primeiras linhas da tabela são o resultado da varredura que a invariante 15 exige, e elas são a razão de a decisão de §2.3 ter escolhido o pré-flight em vez do escopo do `ci`. Sem a varredura, a onda teria deixado três gates rastreados vermelhos e a correção óbvia — afrouxar as três asserções — teria apagado exatamente o que elas guardam.

---

## 12. O que esta onda explicitamente NÃO faz

**Não muda o default de nenhuma chave de `quality:` para `true`.** As quatro nascem e permanecem `false`, pelo motivo medido e escrito em `forge.yaml:35-49`: ligada por default, uma chave dessas reprova o primeiro `archive` de todo adotante greenfield. Virar default é fatia própria, com censo de adotante, e não cabe aqui.

**Não estende o escopo default de `red-evidence.sh ci` nem de `check-red-first.sh check` para `feature`.** Três gates rastreados afirmam o contrário e o novo enforcement mora só no pré-flight, sob chave desligada de fábrica.

**Não escreve nos arquivos de baseline corrompidos dos repositórios adotantes.** O censo de §5.2 mediu 7 em `axis-fare-validator` e 9 em `axis-go-cloud` no dia 2026-09-07, e o número que a Onda I carrega é o do censo rodado no dia do envio, não este. A onda entrega o detector e a migração; a operação é do dono de cada repositório.

**Não entrega `java-quality-scan` nem `python-quality-scan`.** Os dois scanners deterministas por stack, análogos a `dotnet-quality-scan` e `node-quality-scan`, ficam fora por decisão explícita de §3.2 e viram LDG-NOVO-2, aberto por esta onda. A consequência é que gate β espelha os 15 cenários nominais de §6.2 e não os 14 e 16 dos dois moldes.

**Não corrige o `w155:123`**, onde `python3` ausente vira acusação de XML inválido. É a classe de LDG-0157, que a Onda D fecha no seu próprio universo, e ampliar uma onda para consertar o gate que ela usou como molde é alargamento — vira item de ledger.

**Não implementa fuzzing sobre as superfícies que não são pares emissor/parser** — frontmatter do `FORGE.md`, mensagem de liaison, `graph.json`, varredura de rotas. O eixo escolhido é o par emissor/parser, e a cobertura das demais fica garantida por construção apenas na medida em que elas venham a ter emissor: o gate γ cobra propriedade de todo emissor que exista, e não de toda entrada que o harness leia.

**Não introduz dependência nova.** Nem `ruff`, nem `mypy`, nem `mvn`, nem biblioteca de PBT. Os scripts auditam configuração e o gate roda com `bash`, `node` e `python3`, que são o que os moldes já usam.

**Não altera `traceability.schema.json`.** A forma `PBT-01` já é válida, medido, e alterar o schema por simetria criaria fronteira publicada nova sem necessidade.

---

## 13. Ordem de implementação e definição de pronto

**Ordem, e o motivo de cada posição.**

1. **Gate γ e a correção do `yaml-lite`, primeiro.** É a correção de perda de dado, e ela muda o resultado de leitura de 14 arquivos do repositório — qualquer coisa construída antes teria de ser remedida depois.
2. **A migração e o detector**, imediatamente atrás, porque o baseline deste repositório é insumo dos gates de archive.
3. **Gate α**, que depende só do pré-flight estável — a dependência da Onda D some com a correção de §2.3, porque o terceiro estado passa a usar o vocabulário `NÃO VERIFICADO` que `hooks/git/pre-push` já usa e que `w160[4]`/`w168[5]` já assertam.
4. **Gate β**, por último, porque é o mais isolado — dois scripts novos, assets novos e fiação em arquivos que nenhum dos outros dois toca.

**Definição de pronto.**

- Os três gates verdes, cada um com o seu contador publicado e acima do piso de §8, e cada um com o cenário de universo vazio reprovando com `universo-vazio`.
- As **doze** mutações da tabela de §7 executadas contra o gate, cada uma com a acusação observada e a restauração conferida por `cmp` contra a cópia íntegra — inclusive as que esta especificação já mediu em bancada, porque contrafactual medido sobre protótipo não substitui contrafactual medido contra o gate. A linha (c) exige a **fixture pareada** de §7, sem a qual ela é no-op provado.
- `w192` verde com as duas chaves novas na lista de interruptores e o piso do contador atualizado.
- `w162` verde, com o comentário do cenário `[4]` reescrito.
- **`w200` verde nos dois contadores**: as linhas `<dir>/ (N)` afetadas atualizadas (ao menos `scripts/`) **e o badge `gates-N` da linha 12 do `README.md`** batendo com `find tests -maxdepth 1 -name '*-gate.sh' | wc -l`.
- **`plugin-sync-gate` verde**: `npm run build:plugin` rodado no mesmo PR, porque a onda edita `template/.forge/commands/harness/capabilities.md`, que tem espelho em `plugin/forge/commands/`.
- `bash -n` limpo em tudo que for tocado, e nenhum uso de `declare -A`, `${var,,}`, `${var^^}`, `mapfile` ou `readarray` — a régua é bash 3.2.
- **O censo de §5.2 devolve `atingidos=0` neste repositório**, e não a queda de um percentual num arquivo nomeado — a asserção é a propriedade "nenhum YAML rastreado tem run de 2 ou mais barras antes de aspas" mais o piso de que o censo examinou ao menos um arquivo. Os três arquivos de hoje são testemunhas de data. A conferência qualitativa que fecha é o texto da linha 40 do `spec.yaml` de volta à prosa legível de §5.2.
- **`approval-log.sh` e `spec-close.sh` escapando a barra invertida**, e os arquivos que eles já escreveram conferidos pelo mesmo censo.
- A rule `property-based-testing.md` com as **duas** linhas reescritas — a 54, que manda declarar a cobertura no `design.md`, e a 55, que declara a lacuna — e com a chave nova e o artefato de declaração citados nominalmente. A asserção da 55 é pareada com um sinal positivo, nunca um `grep -v` da frase antiga.
- Os dois `PROFILE.md` de 14 linhas reescritos, cada um com a armadilha da sua stack documentada e uma âncora estável para o gate grepar.
- Suíte inteira verde, rodada pelo orquestrador, serializada.

**Desfecho de cada item no ledger.**

| Item | Desfecho | Prova |
|---|---|---|
| LDG-0008 | `resolved` | as duas fatias restantes têm chave, leitor e gate; o cenário de §2.2 passa a reprovar |
| LDG-0065 | `resolved` | dois packs com assets, dois scripts com `--check`/`--apply`, fiação nos cinco pontos, gate com controle e recontrole |
| LDG-0021 | `resolved` — **com a ressalva de produto de §4.1** | eixo decidido, motor entregue, uma superfície coberta, resíduo fechado por denominador derivado no gate |
| LDG-NOVO-1 | aberto e `resolved` na mesma onda | corrupção reproduzida, corrigida, migrada e guardada por propriedade; os dois emissores em bash corrigidos junto |
| LDG-NOVO-2 | aberto, e fica aberto | `java-quality-scan` e `python-quality-scan`, com escopo escrito e molde nomeado — é o custo declarado da decisão de §3.2 |

---

## 14. Varredura de comandos prescritos — a invariante 19 aplicada a este documento

Varri este documento atrás de todo comando ou mecanismo que ele prescreve ao implementador ou ao gate — prescrição, não medição já citada com a saída ao lado.

**Executados nesta rodada, com a saída colada no ponto de uso:** a bancada completa de `spec-new`/`transition`/`verify`/`approval`/`validate-archive` de §2.2, com o `rc=0` lido sem pipe; o `grep -cE` ancorado de §2.1; as contagens de `grep -c bugfix` por arquivo e o `grep -rn 'bugfix.md §1' tests/` de §2.3; o `awk NR==13` do enum de `red-evidence.schema.json`; as contagens de `grep` sobre `PBT` e sobre os templates de §2.4; o `grep -n hasFilledTableRow` e o `sed -n '102,104p'` de §2.5; o `awk 'NR>=54 && NR<=55'` da rule de PBT; o `find` sobre os dois packs, o `wc -l` dos quatro `PROFILE.md` e o `find .../assets` do pack Node de §3.1; o `command -v` das nove ferramentas, o `python3 --version`, o `python3 -c 'import tomllib'` e os `awk` de faixa sobre `node-baseline.sh` de §3.2; os `grep -n` sobre os blocos de fiação de `w155` e `w180`; o fuzz não guiado de 20.000 casos e as duas varreduras de denominador de §4.1 e §4.2; o round-trip de controle e a acumulação de gerações de §5.1; o `censo.sh` nas quatro árvores de §5.2; o `inverso.mjs` sobre a linha 40; as **dez** execuções de `prop.mjs` de §5.3, nas três larguras de alfabeto e nas quatro versões do par; os dois `diff-arvore.mjs` de §5.3; as **doze** mutações de §7, cada uma com controle, mutação, restauração por cópia da íntegra conferida por `cmp`, e recontrole; o `grep -rn` de `tests/` sobre `yaml-lite` de §10; o `ls tests/` com `sort -n`, o `grep -oE 'gates-[0-9]+'`, o `find tests -maxdepth 1` e os sete pares de contagem do README de §11; e o `ls plugin/forge/commands` mais o `grep -n` de `plugin-sync-gate.sh`.

**A régua desta revisão: nenhuma afirmação numérica sem o comando ao lado.** A revisão 1 listou nove medições irreprodutíveis, e todas as nove foram fechadas — sete remedidas com o comando colado (§4.2 fuzz não guiado, §5.3 propriedade nas quatro versões, §5.3 diff da árvore, §5.2 inverso da linha 40, §2.2 bancada, §3.2 `command -v`, §2.3 vocabulário da Onda D) e duas removidas por não sustentarem asserção (§4.2 "quinze módulos", substituída pela contagem por import com o comando e rebaixada a testemunha de data; §14 corretude semântica dos assets, que continua declarada como não medida porque **é** não medida). O único número deste documento que ninguém mediu é o que o parágrafo abaixo nomeia.

**Declarados como propriedade mais contrafactual, com a escolha do primitivo devolvida a quem executa:** a forma exata do predicado de leitor do gate α, que herda o predicado já provado de `w192[1]` em vez de reinventá-lo — mas **não** o denominador de `w192`, que é literal e que §8 corrige; a estratégia de derivação da árvore base para uma feature, que §9 manda cobrir por teste de integração sobre `deriveBase` e não por E2E; e a forma do inverso da migração, que §5.4 descreve como "ler o valor lógico e reemitir pelo emissor corrigido" e não como uma substituição de texto. As doze linhas da matriz de §7 saíram desta lista: todas têm contrafactual medido, sobre o gate, sobre o protótipo ou sobre o molde em produção, e a coluna diz qual dos três em cada caso.

**Três erros que a própria varredura cometeu e corrigiu, registrados porque são o exemplo canônico da invariante.** Primeiro: a versão inicial do arquivo de propriedade foi invocada como `node prop.mjs x <caminho>` e lia `process.argv[2]`, que recebeu o `x` e não o caminho, produzindo `ERR_MODULE_NOT_FOUND: Cannot find package 'x'` — literalmente o exemplo que a invariante 19 cita. Segundo: o protótipo do leitor de §7 lia `join(DIR, 'evidence/red/red-evidence.json')`, e a variável do diretório do change em `validate-archive.mjs` chama-se `root`, não `DIR`; o `catch` engolia o `ReferenceError` e o pré-flight reprovava por "evidência ausente" sobre uma evidência que estava no disco — um falso-vermelho que teria virado prescrição se eu não tivesse rodado. Terceiro: a medição de (e) leu `$?` depois de um pipe para `tail` e obteve `rc=0` nos dois lados da mutação, o que teria escrito na matriz uma linha declarando que a mutação não discrimina. **Os três apareceram porque os comandos foram executados**, e os três teriam sobrevivido a uma leitura atenta do documento.

**O que continua sem prova, dito em voz alta — e é o único item da lista.** Não medi o comportamento dos assets Java e Python contra uma build real: `mvn`, `ruff` e `mypy` não existem nesta máquina (medido no laço de `command -v` de §3.2), e o gate é desenhado para não precisar deles. Isso significa que a **corretude semântica** dos assets — que a configuração proposta de fato reprova o que promete reprovar quando executada por Maven ou por ruff — não é assertada por gate nenhum desta onda, apenas a presença e a forma das chaves load-bearing. É o mesmo limite que `w155` e `w180` já têm, e a saída honesta é a que o ledger de LDG-0065 já registra: a prioridade sobe no dia em que houver adotante Java ou Python exercitando o pack, e é nesse dia que a semântica é medida em campo.

---

## 15. Respostas ao veredito da revisão 1

Cada item abaixo foi remedido com comando próprio antes de ser aceito. Onde a medição contradiz o revisor, a refutação vem com o comando, e onde ela me contradiz, o número do documento mudou.

### Os seis bloqueadores

**Bloqueador 1 — badge `gates-N` do README.** **Aceito, e o revisor está certo em cheio.** Reproduzido: `grep -oE 'gates-[0-9]+' README.md | head -1` devolve `gates-131` e `find tests -maxdepth 1 -name '*-gate.sh' | wc -l` devolve `131`, e `w200[6]` (linhas 258-272) compara os dois. A frase da revisão 0 dizendo que a contagem de gates "não entra em asserção nenhuma" era falsa e saiu. §11 nomeia o badge e explica que a varredura anterior olhou só a seção `## 📁 Estrutura`, e §13 exige o badge em `gates-134` na definição de pronto. É a armadilha A pegando a onda que a documentava.

**Bloqueador 2 — escopo do gate β.** **Aceito, e decidido pela via barata.** Reproduzido: `ls template/.forge/skills/ | grep -i quality` devolve só `dotnet-quality-scan` e `node-quality-scan`, e os cenários `w155` [8]-[10]/[12] e `w180` [8]-[12] existem por causa dessas skills. §3.2 decide em letra que **os scanners não entram**, §6.2 substitui "cenário a cenário" por uma lista nominal de **15** cenários, §8 não ganha contador de regras por scanner, §12 exclui os dois scanners e §13 abre LDG-NOVO-2 com o escopo escrito. O implementador agora conta os cenários antes de escrever.

**Bloqueador 3 — os cinco pontos de fiação.** **Aceito, e a lista da revisão 0 estava errada nos dois sentidos.** Reproduzido linha a linha: `w155[11]` grepa `installer/forge-init.md` na 266 e o `PROFILE.md` nas 268-271; `w180[13]` faz o mesmo nas 310 e 312-315. `grep -c 'forge-init' <spec da revisão 0>` devolvia **0**. §3.2 ganhou a tabela dos cinco pontos com as linhas dos dois moldes, a instrução de reescrita dos dois `PROFILE.md` com a armadilha de cada stack, e moveu `capabilities/README.md`/`commands/harness/capabilities.md` para fora da contagem — **com a armadilha que o revisor não mencionou e eu achei varrendo**: o segundo tem espelho em `plugin/forge/commands/` e exige `npm run build:plugin`.

**Bloqueador 4 — domínio da propriedade de round-trip.** **Aceito, e resolvido pela via forte, não pela exclusão.** Reproduzido: `yamlQuote` não escapa `\n`/`\r`/`\t`, e o candidato que conserta só o leitor deixa **951 de 2.000** falhando quando o alfabeto inclui os caracteres de controle. §4.2 decide que **o domínio é todas as strings, sem exclusão**, e o conserto se estende ao emissor; §5.3 traz `classify-ctrl` nas três versões (1.537 / 951 / 0 em 2.000) e §10 reavalia a retrocompatibilidade da forma emitida com três medições, incluindo a que prova que a sequência literal `\` + `n` continua voltando correta.

**Bloqueador 5 — as duas enumerações que se diziam exaustivas.** **Aceito, e o dano é maior do que o revisor mediu.** Substituí as duas listas por um **censo derivado**, publicado na íntegra em §5.2: 3 arquivos neste repositório (o revisor achou 3), **7** em `axis-fare-validator` e **9** em `axis-go-cloud` (o revisor achou "ao menos três além dos cinco"; são onze além dos cinco, contando as cópias publicadas e o `.forge.bak-1`), e 0 em `azim-crm`. §12 e §13 passam a falar do censo e não de arquivos nomeados, e §13 exige `atingidos=0` como propriedade em vez da queda de 84,2% num arquivo.

**Bloqueador 6 — denominador estreito do gate γ.** **Aceito, e a varredura larga encontrou dois emissores que nem o revisor nomeou.** Reproduzido: `grep -rln 'yamlQuote\|yamlFlowList' template/.forge bin --include='*.mjs'` devolve os mesmos quatro de `lib/` — o que parecia inocentar o denominador estreito. Mas `grep -rn 's/"/\\"/g' template/.forge bin` devolve `approval-log.sh:83,88,89` e `spec-close.sh:65`, quatro sítios em **bash** que emitem `chave: "valor"` escapando aspas e não escapando barra, e que o denominador da revisão 0 nunca veria. Consequência medida: `.forge/specs/archived/2026-09-04-gate-assert-visibility/approvals.yaml` é o único dos 92 YAML em que os candidatos B e C divergem, porque contém a prosa `sem o \n na classe negada` — ou seja, a correção do leitor, sozinha, **introduziria** corrupção nova nesse arquivo. §4.1 refaz o denominador (piso **5**), §6.3 acrescenta a contrapositiva do emissor sintético plantado fora de `lib/` e o cenário dos dois emissores em bash, e §7 ganha a linha (l).

### As nove medições que não reproduziram

| # | Afirmação da revisão 0 | Desfecho |
|---|---|---|
| 1 | §4.2 — 20.000 casos, 18.912 rejeições, 94,6% | **REMEDIDA.** Bancada publicada no Apêndice A. `node prop.mjs unguided <yaml-lite> 20000 20260907` → **18.987 de 20.000 = 94,9%**. O número mudou; a conclusão não |
| 2 | §5.3 e §7 — 326/500, 166/500, 666/2000, 5/2000, 2/2000, 0/2000 | **REMEDIDAS, todas.** Alfabeto, PRNG e semente no apêndice. Hoje **309/500** e **1.265/2000**; candidato A **153/500** e **607/2000** (602 de tabulação, 3 de aspas, 2 de aspas+barra); candidatos B e C **0/2000**. O fuzz próprio do revisor deu 314/500 com alfabeto e PRNG diferentes, na mesma ordem de grandeza |
| 3 | §5.3 — 92 arquivos, 76 idênticos, 14 divergentes, 498.429→269.165 | **REMEDIDA, e o número estava errado.** `node diff-arvore.mjs . <hoje> <candidato C>` → `arquivos=92 identicos=75 divergentes=15 erro_nos_dois=2`, e o `spec.yaml` cai de **498.429 para 269.165** exatamente. Eram 75/15, não 76/14 |
| 4 | §5.2 — linha 40 de 16.651 para 269 | **REMEDIDA.** `node inverso.mjs <spec.yaml> 40` → `entrada: 16651 caracteres / saida: 269 caracteres`. A divergência que o revisor viu (16.657) é de **unidade**: `awk` conta 16.657 bytes e o Python conta 16.651 caracteres, porque a linha tem seis acentuados de dois bytes. §5.2 traz os dois comandos |
| 5 | §2.2 — a bancada até `verified` com `rc 0` | **REMEDIDA.** A sequência inteira de onze comandos está colada em §2.2, com a saída de cada um e o `rc=0` final lido de `$?` sem pipe |
| 6 | §3.2 — `command -v` das nove ferramentas, `python3 3.13.14` | **REMEDIDA.** Laço colado em §3.2: `dotnet/node/java/gradle/python3` sim, `ruff/mypy/mvn/pip` não, `Python 3.13.14`, `import tomllib` ok |
| 7 | §14 — corretude semântica dos assets Java e Python | **MANTIDA COMO NÃO MEDIDA.** É o único número que ninguém tem, e §14 diz isso em voz alta com o motivo (as ferramentas não existem nesta máquina) e o desfecho (medição em campo, no primeiro adotante) |
| 8 | §2.3 — `INCONCLUSIVO` e os códigos 4 e 5 herdados da Onda D | **REMOVIDA, e a afirmação era falsa.** `awk 'NR>=119 && NR<=125'` no plano mostra que a Onda D nomeia `"NÃO VERIFICADO — node ausente"` e nenhum código; `grep -rn 'exit 5$' template/.forge/scripts/` devolve zero. §2.3 passa a usar o vocabulário `NÃO VERIFICADO` que `pre-push:143,181` já usa, e §13 perde a dependência de ordenação com a Onda D |
| 9 | §4.2 — "quinze módulos importam de `yaml-lite.mjs`" | **REMOVIDA como afirmação e substituída por medição.** `grep -rl "from '.*yaml-lite.mjs'" template/.forge bin --include='*.mjs' \| wc -l` → **14**, com o comando ao lado e a marcação explícita de que é testemunha de data e não entra em asserção. O revisor mediu 14 e 16 pelos dois critérios; 14 é o de import |

### As ressalvas de redação

Todas aceitas e corrigidas, exceto uma refutada por medição.

- §2.1 — `grep -c 'require_human_approval_before_archive'` devolve **1**, não zero. Corrigido em §2.1 para a forma ancorada de `w192[3]`, que devolve **0**, com o motivo escrito.
- §2.3 — `grep -rn 'bugfix.md §1' tests/ | wc -l` devolve **6**, não zero. Corrigido, e a decisão mudou junto: **não mexer no literal**, porque as seis linhas são heredoc do próprio `w106` e `grep -rn 'red-evidence.sh init' tests/` devolve **0**, então mudar o template seria editar seis linhas de gate para nada.
- §8 — a justificativa "como `w192` já faz" era falsa: `sed -n '43,46p' tests/w192-...` mostra `SWITCHES=(...)` literal. Corrigido em §8, com o aviso de que `w192` é o molde do **predicado**, nunca do denominador.
- §2.5 — `hasFilledTableRow` (não `tableHasDataRow`), `238-242` (não 239-241). Corrigido.
- §2.5 — `SCAFFOLD_MARKERS_RE` na **103** e aplicada ao `spec-delta.yaml`, nunca ao `requirements.md`. Corrigido, e o argumento ficou mais forte do que era.
- §3.1 — `find .../backend-node-postgres/assets -type f` devolve **cinco** arquivos. Corrigido.
- §2.3 — o enum de `red-evidence.schema.json:13` tem **quatro** valores. §2.3 e §6.1 passam a dizer em letra o que acontece com `pending` e com `not-possible`, e a decisão sobre `not-possible` é reprovar, com a justificativa escrita (invariante 17).
- §2.5 e §13 — `property-based-testing.md` tem **duas** linhas a reescrever, a 54 e a 55, e a da lacuna é a **55**. Corrigido nos dois lugares, nominalmente.
- §5.4 — a alocação de id de ledger não é a invariante 10 (que trata de ordinal de gate). Corrigido, com a âncora operacional medida: maior id **LDG-0176**, **22** abertos de 107 entradas.
- Linha 3 — a seção "Método de prova" não existe no plano-mestre. Corrigido no cabeçalho, com o defeito devolvido ao dono do plano.
- `check_java` começa em **645**, e o bloco no-op de `node-baseline.sh` é **57-64**, a severidade **66-79** e a não-sobrescrita **87-97**. Corrigidos com os `awk` de faixa ao lado.
- **Refutado:** `w155:123`. `grep -n 'python3' tests/w155-dotnet-enforcement-gate.sh | head -1` devolve **123**, e `sed -n '123,127p'` mostra o heredoc com `xml.etree` logo abaixo. O número da revisão 0 estava certo; o do revisor, não.

### As cinco armadilhas, varridas na spec inteira

- **A — literal que envelhece em asserção.** Encontrada uma, e era grave: o badge `gates-N` (bloqueador 1). Varridos também os sete pares de contagem do README (`agents/ 47`, `commands/ 56`, `contracts/ 5`, `skills/ 20`, `rules/ 50`, `schemas/ 27`, `scripts/ 136`), todos batendo hoje e todos com o comando dos dois lados em §11. Todo número que conta arquivo, gate ou entrada neste documento passou a vir com a etiqueta de **testemunha de data**, e a asserção correspondente é propriedade mais piso — §8 tem a tabela.
- **B — string de produção mudada sem varrer `tests/`.** Encontradas duas. A primeira é `bugfix.md §1`, e a varredura mudou a decisão de "trocar" para "não trocar". A segunda é o espelho do plugin: a onda edita `commands/harness/capabilities.md`, `ls plugin/forge/commands/ | grep -i capab` devolve `capabilities.md`, e `plugin-sync-gate.sh:22` reprova sem `npm run build:plugin` — está em §3.2, na tabela de §11 e na definição de pronto de §13.
- **C — linha de matriz sem contrafactual medido.** Eram seis. Agora são zero: (a), (b) e (c) medidas sobre protótipo instalado na bancada, com controle, mutação, `cmp` e recontrole; (d), (e) e (f) medidas por análogo sobre o molde em produção, pela mesma mecânica; (g) a (l) medidas diretamente. A linha (c) foi **no-op na primeira tentativa** e só discrimina com a fixture pareada, que virou requisito normativo em §7 e §13.
- **D — enumeração que se diz exaustiva.** Encontradas três. As duas do bloqueador 5, substituídas por censo derivado. E uma terceira que o revisor não pegou: a enumeração de status de `red-evidence.json` em §2.3, que nomeava dois de quatro valores do enum — agora os quatro têm desfecho escrito.
- **E — prescrição de comando nunca executado.** Encontrados três erros, todos meus e todos apanhados por execução: o `process.argv[2]` do `prop.mjs`, o `join(DIR, ...)` do protótipo — que reprovava por "evidência ausente" sobre uma evidência presente, um falso-vermelho que teria virado prescrição — e o `rc` lido através de um pipe para `tail`, que mediu `rc=0` nos dois lados de uma mutação. Os três estão registrados em §14.

---

## Apêndice A — a bancada, na íntegra

**Isto é evidência de reprodutibilidade, não prescrição.** Os programas abaixo produziram todo número de §4.2, §5.2 e §5.3 e todo contrafactual de §7. O implementador não é obrigado a usá-los — a invariante 19 devolve a ele a escolha do primitivo, sob a obrigação de provar que a propriedade discrimina. Eles estão aqui para que o próximo revisor repita as medições sem adivinhar gerador, alfabeto ou semente.

### A.1 — `prop.mjs`, o motor de propriedade

```js
// Uso: node prop.mjs <modo> <caminho-do-yaml-lite.mjs> <casos> <seed>
//   modos: unguided | roundtrip | classify | classify-ctrl
import { pathToFileURL } from 'node:url';

const [, , modo, alvo, nCasosArg, seedArg] = process.argv;
if (!modo || !alvo) { console.error('uso: node prop.mjs <modo> <yaml-lite.mjs> [casos] [seed]'); process.exit(2); }
const N = Number(nCasosArg || 500);
const SEED = Number(seedArg || 20260907);
const Y = await import(pathToFileURL(alvo).href);

// PRNG: LCG de Numerical Recipes (a=1664525, c=1013904223, m=2^32). Seed explicita na linha de comando.
let _s = SEED >>> 0;
const rnd = () => { _s = (Math.imul(1664525, _s) + 1013904223) >>> 0; return _s / 4294967296; };
const pick = (a) => a[Math.floor(rnd() * a.length)];
const intBetween = (lo, hi) => lo + Math.floor(rnd() * (hi - lo + 1));

// Alfabeto BRUTO do fuzz nao guiado: 30 simbolos.
const ALF_BRUTO = ['a','b','c','0','1','2',' ',':','-','#','[',']','{','}',',','"',"'",'\\','\t','~','|','>','&','*','!','?','%','@','/','.'];
// Alfabeto GUIADO do round-trip: 18 simbolos, com aspas, barra invertida e tabulacao presentes.
const ALF_GUIADO = ['a','b','0',' ',':','-','#','[',']','{','}',',','"',"'",'\\','\t','~','.'];
// Alfabeto GUIADO+CTRL: os 18 acima mais quebra de linha e retorno de carro = 20 simbolos.
const ALF_CTRL = ALF_GUIADO.concat(['\n', '\r']);

const cadeia = (alf, lo, hi) => { let s = ''; const n = intBetween(lo, hi); for (let i = 0; i < n; i++) s += pick(alf); return s; };

if (modo === 'unguided') {
  console.log(`alfabeto=${ALF_BRUTO.length} simbolos  casos=${N}  seed=${SEED}  comprimento=1..40`);
  let rejeicoes = 0;
  for (let i = 0; i < N; i++) {
    const texto = cadeia(ALF_BRUTO, 1, 40);
    try { Y.parseYamlSubset(texto); } catch (e) { if (/unparseable line/i.test(String(e.message))) rejeicoes++; }
  }
  console.log(`rejeicoes por 'unparseable line' = ${rejeicoes} de ${N} = ${(100 * rejeicoes / N).toFixed(1)}%`);
  process.exit(0);
}

// Propriedade: para todo x do dominio, parse(render(x)) === x, com render = `chave: ${yamlQuote(x)}`.
function roundTrip(x) {
  const doc = `chave: ${Y.yamlQuote(x)}\n`;
  let lido;
  try { lido = Y.parseYamlSubset(doc).chave; } catch (e) { return { ok: false, classe: 'excecao' }; }
  return lido === x ? { ok: true } : { ok: false, classe: 'valor' };
}
function classifica(x) {
  if (/[\n\r]/.test(x)) return 'controle';
  if (/\t/.test(x)) return 'tabulacao';
  if (/\\/.test(x) && /"/.test(x)) return 'aspas+barra';
  if (/"/.test(x)) return 'aspas';
  if (/\\/.test(x)) return 'barra';
  return 'outra';
}

const ALF = modo.endsWith('-ctrl') ? ALF_CTRL : ALF_GUIADO;
console.log(`alfabeto=${ALF.length} simbolos  casos=${N}  seed=${SEED}  comprimento=1..12`);
let falhas = 0; const porClasse = {}; let menor = null;
for (let i = 0; i < N; i++) {
  const x = cadeia(ALF, 1, 12);
  if (!roundTrip(x).ok) {
    falhas++;
    const c = classifica(x); porClasse[c] = (porClasse[c] || 0) + 1;
    if (menor === null || x.length < menor.length) menor = x;   // shrinking simples: o mais curto observado
  }
}
console.log(`falhas=${falhas} de ${N}`);
if (modo.startsWith('classify')) {
  for (const c of Object.keys(porClasse).sort()) console.log(`  classe ${c}: ${porClasse[c]}`);
  if (menor !== null) console.log(`  contraexemplo mais curto: ${JSON.stringify(menor)}`);
}
```

### A.2 — `diff-arvore.mjs`, o controle e recontrole sobre a árvore

```js
// Uso: node diff-arvore.mjs <raiz> <yaml-lite-a.mjs> <yaml-lite-b.mjs>
import { pathToFileURL } from 'node:url';
import { readFileSync } from 'node:fs';
import { execSync } from 'node:child_process';
const [, , raiz, pa, pb] = process.argv;
const A = await import(pathToFileURL(pa).href);
const Bm = await import(pathToFileURL(pb).href);
const lista = execSync(`find ${JSON.stringify(raiz)}/template ${JSON.stringify(raiz)}/.forge ${JSON.stringify(raiz)}/docs ${JSON.stringify(raiz)}/tests -type f \\( -name '*.yaml' -o -name '*.yml' \\) 2>/dev/null || true`,
  { encoding: 'utf8', maxBuffer: 1 << 28 }).split('\n').filter(Boolean).sort();
let iguais = 0; const difs = [], errAmbos = [];
for (const f of lista) {
  const t = readFileSync(f, 'utf8');
  let ra = null, rb = null, ea = null, eb = null;
  try { ra = JSON.stringify(A.parseYamlSubset(t)); } catch (e) { ea = e.message; }
  try { rb = JSON.stringify(Bm.parseYamlSubset(t)); } catch (e) { eb = e.message; }
  if (ea && eb) { errAmbos.push(f); continue; }
  if (ea || eb) { difs.push([f, ea ? 'ERRO_SO_A' : 'ERRO_SO_B', '']); continue; }
  if (ra === rb) iguais++; else difs.push([f, ra.length, rb.length]);
}
console.log(`arquivos=${lista.length}  identicos=${iguais}  divergentes=${difs.length}  erro_nos_dois=${errAmbos.length}`);
for (const [f, la, lb] of difs) console.log(`  DIF ${f.replace(raiz + '/', '')}  json_A=${la} json_B=${lb}`);
for (const f of errAmbos) console.log(`  ERRO_AMBOS ${f.replace(raiz + '/', '')}`);
```

### A.3 — `inverso.mjs`, a recuperação da linha corrompida

```js
// Uso: node inverso.mjs <arquivo> <numero-da-linha>
import { readFileSync } from 'node:fs';
const [, , f, nl] = process.argv;
const linha = readFileSync(f, 'utf8').split('\n')[Number(nl) - 1];
const recuperado = linha.replace(/\\+"/g, '"').replace(/\\{2,}/g, '\\');
console.log(`entrada: ${linha.length} caracteres`);
console.log(`saida:   ${recuperado.length} caracteres`);
console.log(recuperado);
```

### A.4 — os quatro candidatos do par, e como foram construídos

Cada candidato é o arquivo de produção com um patch aplicado por `python3` sobre uma **cópia**, com âncora literal e `assert` de que a âncora foi encontrada — o mecanismo que abortou corretamente quando errei a âncora na primeira tentativa, e que evita a mutação-fantasma de LDG-0164.

| Candidato | Patch |
|---|---|
| **A** | em `coerceScalar`, o ramo de aspas duplas passa por `unescapeDouble(s.slice(1,-1))`, com `unescapeDouble(b)` consumindo `\` e devolvendo o próximo caractere |
| **B** | A, mais `if (c === '\\' && inDouble) { i++; continue; }` no topo do laço de `stripTrailingComment`, mais `l.replace(/^\t+/g, m => '  '.repeat(m.length))` no lugar de `l.replace(/\t/g,'  ')` em `parseYamlSubset` |
| **C** | B, mais `yamlQuote` encadeando `.replace(/\n/g,'\\n').replace(/\r/g,'\\r').replace(/\t/g,'\\t')` depois dos dois escapes que já existem, e `unescapeDouble` traduzindo `n`, `r` e `t` de volta e devolvendo o caractere cru para qualquer outro |

### A.5 — o protótipo do leitor, usado só para medir (a), (b) e (c)

O protótipo insere, imediatamente antes do bloco `// human archive approval gate` de `validate-archive.mjs`, os dois leitores das chaves novas — um consultando `join(root, 'evidence/red/red-evidence.json')` e comparando `status` com `observed`/`waived`, outro filtrando `traceability` por `/^PBT-/` e exigindo `tasks` e `evidence` não vazios —, cada um com o ramo `declaredOff` que registra a dispensa. Ele **não** é o patch prescrito: falta-lhe o tratamento de `not-possible`, o `NÃO VERIFICADO` de universo vazio e o de `node` ausente, que §2.3, §2.5 e §6.1 exigem da implementação. Ele existe porque a invariante 16 pede contrafactual medido, e uma mutação precisa de algo que exista para ser mutada.
