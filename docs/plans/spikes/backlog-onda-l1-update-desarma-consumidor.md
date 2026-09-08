# Onda L1 — o `forge update` desarma a configuração do consumidor (especificação implementável)

Autor: especificador do subgrupo L1 da Onda L. Data: 2026-09-07. Base medida: branch `feat/fase1-dogfood-completo`, árvore de trabalho limpa (`git status --porcelain` vazio), `v0.14.0` publicada no npm, `origin/develop` e `origin/main` com máximo de ordinal `w207`.

Escopo: issues **#125** (`hooks/` fora de qualquer galho de preservação e gerador com gancho literal), **#131** (o updater ignora `machinery-exceptions.txt`), **#130** (`sync-adapters.mjs` executa no `import`) e **#142** (o update particiona o mutex compartilhado). O mecanismo comum, do plano-mestre: o update tem autoridade sobre arquivos que o consumidor tem razão legítima para ter mudado e não distingue conserto local de defasagem. A diferença desta onda para a Onda C é que aqui a consequência é desarme de guarda de segurança.

Nenhum gate da suíte foi executado na elaboração desta especificação — `feedback-suite-sem-concorrencia` registra que gate manual concorrente produz falha fantasma em gate alheio. Toda medição abaixo é de bancada própria sob `$TMPDIR`, com `cwd` dentro da fixture, ou de leitura pura das árvores dos consumidores.

**Regra de método, e ela é a invariante 19 do plano-mestre.** A especificação declara a **propriedade** e o **contrafactual**; quem escolhe o primitivo é o implementador, que executa, e ele prova que o primitivo discrimina. Comando exato só permanece aqui quando veio de execução minha, com a saída colada. A varredura dos comandos prescritos está em §16.

**Retratação minha, em primeira pessoa, e ela vira evidência de §4.** Durante a §4 desta especificação eu corrompi um arquivo **rastreado** deste repositório — `template/.forge/scripts/lib/mermaid-to-drawio.mjs` — apenas por importá-lo. O dano foi `1 file changed, 11 insertions(+), 243 deletions(-)`, restaurado por `git checkout HEAD --` com `git status --porcelain` conferido vazio depois. Eu não editei o arquivo: eu o passei como argumento para um leitor, e o módulo se leu, se converteu e se sobrescreveu. É a mesma classe de LDG-0175 e é o achado mais grave desta onda; a mecânica está em §4.3.

---

## 0. Resumo do que muda

| Peça | Arquivo | Natureza |
|---|---|---|
| Ponte `stdin` → `argv` para os ganchos de conteúdo | `template/.forge/hooks/pre-tool-use/lib/<ponte>.sh` (novo) — em `lib/`, pelo precedente de `hooks/git/lib/`, para ficar FORA do universo de ganchos (D4.2) | maquinaria nova, distribuída |
| Manifesto de matcher, contrato e ativação | `template/.forge/hooks/pre-tool-use/hooks.manifest.default` (novo, do template — matcher e contrato) e `hooks.manifest` (do consumidor, nunca distribuído — sobreposição e ativação). **O esquema de coluna da camada do consumidor NÃO é escolhido aqui:** dois consumidores já a escreveram, em esquemas incompatíveis entre si, e a escolha é LDG-0178 (D4.3). Esta onda reconhece apenas o seu próprio esquema e **recusa** o que não reconhece (D4.5) | contrato novo, com dependência declarada |
| `PreToolUse` derivado do diretório, com quatro guardas que reprovam | `template/.forge/scripts/lib/sync-adapters.mjs` | comportamento novo; quebra dois gates existentes (§13) |
| Guarda de principal e exportações nomeadas | `template/.forge/scripts/lib/sync-adapters.mjs` | correção de defeito medido |
| Guarda de principal | `template/.forge/scripts/lib/mermaid-to-drawio.mjs` | correção de defeito medido por mim, na árvore real |
| `exit 2` no lugar de `exit 1` nos ganchos de bloqueio | `template/.forge/hooks/pre-tool-use/*.sh` | correção de contrato de saída |
| Leitura de `.forge/machinery-exceptions.txt` com três desfechos | `bin/forge.mjs` | contrato novo, com rc novo |
| Relatório nominal por arquivo de `hooks/` sobrescrito | `bin/forge.mjs` | mensagem nova |
| Esqueleto documentado do arquivo de exceções | `template/.forge/templates/machinery-exceptions.txt` (novo) | documentação distribuída |
| Paridade schema↔leitor de `heavy_mutex.root` | `template/.forge/schemas/forge.schema.json` | correção de contrato |
| Registro de famílias de lock em caminho fixo | `template/.forge/scripts/lib/heavy-mutex.sh` e `doctor.sh` | maquinaria nova |
| Gate do desarme do gancho | `tests/w<NNN>-hook-wiring-derived-gate.sh` (novo) | ordinal alocado pelo orquestrador |
| Gate do update sobre `hooks/` e exceções | `tests/w<NNN>-update-hooks-exceptions-gate.sh` (novo) | ordinal alocado pelo orquestrador |
| Gate do efeito colateral de import | `tests/w<NNN>-module-import-side-effect-gate.sh` (novo) | ordinal alocado pelo orquestrador |
| Gate da partição do mutex | `tests/w<NNN>-heavy-mutex-partition-gate.sh` (novo) | ordinal alocado pelo orquestrador |

Ordinais: o máximo publicado é **w207** em `origin/develop`, `origin/main` e no `HEAD` desta branch, medido com `for b in origin/develop origin/main HEAD; do git ls-tree -r --name-only "$b" tests/ | grep -oE '/w[0-9]+' | sed 's|/w||' | sort -n | tail -1; done` → `207, 207, 207`. As duas branches remotas restantes (`origin/wip/deepspec-run-manifest-ldg-0165` e `origin/wip/upgrade-safety-ldg-0131`) têm máximo `80` e `154`, portanto já absorvidas. Os quatro ordinais desta onda **não são alocados aqui**: a invariante 10 atribui a alocação ao orquestrador, no momento de escrever o arquivo, contra `origin/*` e contra as branches em voo desta rodada.

---

## 1. A régua da onda — o que reproduziu e o que não

O plano-mestre exige que cada item seja reproduzido na árvore do produtor antes de qualquer correção, porque várias issues descrevem a cópia instalada no consumidor, que pode divergir do template. O resultado desta varredura é o seguinte, e duas das quatro issues **não reproduzem como escritas**.

| Issue | Reproduz no template? | O que isso significa |
|---|---|---|
| #125 | **Sim, e com dois defeitos a mais do que a issue nomeia** | §2 |
| #130 | **Sim, e é uma classe de 31 módulos, não um arquivo** | §4 |
| #131 | **NÃO — o contrato que a issue diz que o updater ignora nunca foi publicado pelo produtor** | §3 |
| #142 | **NÃO como escrita — o updater não reescreve `resource`; o que reproduz é outra coisa, e é pior** | §5 |

Os dois "não" mudam onde a correção mora, e por isso vêm antes das decisões.

**E há um quinto insumo, que não é issue e não é meu: LDG-0178.** O produtor não distribui `hooks.manifest`, e **dois** consumidores o criaram por conta própria — dois de seis no meu censo, dois de cinco no do LDG-0178, e a diferença é só de denominador: o `collatra`, que eu incluo, também não tem o arquivo —, em esquemas de coluna incompatíveis entre si — achado do orquestrador, medido em 2026-09-08 e remedido por mim em §D4.3.1. Ele não muda onde a correção mora, mas muda **até onde ela vai**: a onda entrega a derivação e as guardas sem ler manifesto de esquema alheio, e a convergência de esquema fica declarada como dependência nominal, fora desta onda. §D4.5 é o mecanismo, §12 é a consequência para a base instalada e §14 item 9 é a fronteira.

### 1.2 A auditoria das minhas próprias varreduras de ausência — LDG-0177 aplicado

Esta subseção entrou na revisão 2 e ela é pré-requisito de leitura para o resto do documento. **Varredura de texto que devolve vazio não prova ausência: prova que a varredura não achou.** §2.4 mede o caso concreto — um arquivo-fonte rastreado, UTF-8 válido, que o `node` executa certo e que o `grep` sem `-a` pula em silêncio, porque carrega bytes de controle literais dentro de um literal de regex. É a invariante 2 do plano-mestre (três estados, nunca dois) aplicada ao próprio instrumento de medição: "não encontrei", "encontrei" e "não consegui ler" são desfechos diferentes, e o `grep` de texto colapsa o primeiro com o terceiro.

Toda afirmação de ausência desta especificação foi refeita com `-a` **e** com controle positivo plantado dentro do universo varrido, que a varredura precisava achar antes de o vazio dela valer. O controle é removido no fim e a remoção é conferida. O resultado, item a item:

| Afirmação de ausência | Onde | Refeita com | Sobrevive? |
|---|---|---|---|
| `check-secrets.sh` não cobre a classe AWS | §2.4 | `grep -an` no leitor canônico | **NÃO — derrubada.** §2.4 é a retratação |
| nenhum invocador do contrato posicional dos três ganchos de conteúdo | §2.3 | `grep -arln` em `template/ bin/ installer/ tests/ plugin/ .github/` | **sim, com um achado a mais**: a varredura cega não via `secret-scan.mjs`, que menciona `prevent-secrets-leak.sh` em comentário. A menção é de linhagem, não de invocação — o inventário de invocadores não muda, e a linhagem entra em §2.4 |
| `machinery-exceptions` não aparece em `bin/ installer/ tools/` | §3 | `grep -arl`, com o controle plantado em `template/` e achado | sim |
| `check-machinery-drift.sh` não existe no template | §3 | `find`, que não é cego a byte | sim |
| `stale_after_s` não tem leitor no template | §5.4, D9, §14 | `grep -arn template/` com controle plantado e achado no mesmo comando | sim — zero ocorrências reais |
| nenhum gate afirma `machinery-exceptions`, `hooks.manifest`, `preToolUseWiring` | §13 | `grep -arlF` sobre `tests/`, com controle plantado em `tests/` e achado nas três | sim — zero reais nas três |
| ninguém importa `sync-adapters.mjs` | §12 | `grep -arn` com controle plantado e achado | sim |

O comando do controle positivo, colado porque ele é o instrumento e não o resultado:

```
$ CTL=template/.forge/.l1-ctl.tmp
$ printf 'stale_after_s\nmachinery-exceptions\nimport sync-adapters\n' > "$CTL"
$ grep -arn "stale_after_s" template/ | sed "s|$CTL|<CONTROLE>|"
<CONTROLE>:1:stale_after_s
$ grep -arl 'stale_after_s' template/ | grep -vc 'l1-ctl'
0
$ rm -f "$CTL"
```

O `<CONTROLE>` aparecendo é o que autoriza o `0` da linha seguinte a significar ausência. Sem ele, o `0` significa apenas silêncio.


---

## 2. ITEM #125 — o gancho de segredos, reproduzido

### 2.1 Causa 1 — `hooks/` é sobrescrito, e sem lock o relatório não o cita

Fixture em `$TMPDIR`, `git init`, `forge init -y --no-plugin`, um conserto local plantado no gancho de segredos e um conserto local plantado numa `rule` como **controle positivo** (`rules/` já é enriquecível hoje, então o predicado não está cego):

```
=== o gancho ainda bloqueia ANTES do update? ===
rc_com_conserto=2
=== update ===
rc_update=0
HOOK SOBRESCRITO
RULE PRESERVADA
=== o gancho ainda bloqueia DEPOIS do update? ===
rc_pos_update=0
=== linhas do log que citam o gancho ===
0
```

O relatório inteiro do `update`, com o conserto de segurança destruído no meio dele:

```
backup: .forge copiado para .git/forge-backups/forge-1
maquinaria: 400 arquivo(s) de template aplicados (overlay aditivo)
preservados: 1 arquivo(s) com customização local NÃO sobrescritos:
  = rules/conventions/naming.md
  (se o template também mudou nesses paths, reconcilie à mão — diff contra .forge.bak-N)
…
✔ Forge atualizado em <fixture> (template v0.14.0)
  sem trabalho de produto a preservar
```

**Zero linhas citam o gancho, e a última linha diz que não havia trabalho a preservar.** O controle positivo é a `rule`, preservada e nomeada na mesma execução: o predicado enxerga preservação quando ela acontece.

Uma correção ao inventário da issue, e ela é do lado bom: **com `machinery.lock` presente, o silêncio não é total.** Repeti o cenário com o lock já escrito pelo primeiro `update` e o gancho voltou a ser sobrescrito, agora com aviso nominal:

```
SOBRESCRITO (com lock)
6:WARN: drift local em hooks/pre-tool-use/prevent-secrets-leak.sh sobrescrito pelo template (fix local em maquinaria? faça upstream; backup em .forge.bak-N)
```

O aviso existe, nomeia o arquivo e manda o operador para `.forge.bak-N`, que não existe — o backup foi para `.git/forge-backups/forge-2`. Esse literal errado é a mesma dívida que a Onda C fecha na issue #101, e esta onda **não** a duplica.

E o `--dry-run` não dá ao operador como distinguir defasagem de destruição:

```
= rules/conventions/naming.md (preservado — customização local)
~ hooks/pre-tool-use/prevent-secrets-leak.sh
```

O til é o mesmo símbolo de qualquer atualização de rotina.

### 2.2 Causa 2 — o gerador tem um gancho literal, e a fiação manual não sobrevive

`template/.forge/scripts/lib/sync-adapters.mjs:233` monta o bloco `PreToolUse` com um gancho, literal, com `matcher: 'Bash'`. O `.claude/settings.json` gerado por um `init` limpo tem exatamente uma entrada, e é a do guarda de worktree.

O que a issue não mede, e eu medi: **armar o detector à mão não adianta.** Plantei em `.claude/settings.json` um bloco `PreToolUse` com matcher de escrita apontando para o detector de segredos, e apenas **importei** o gerador:

```
sha da edição pendente: 6d07429859246a4c2ddfcc0c45b110e27694ed8c85011cd24f561d4b3a0c698d
sha depois do import:   c9d15dd1bce8f1fb33fe6f5205df39c4233f20cde8b1f9ac917e5a8bb4032177
EDIÇÃO APAGADA PELO IMPORT
```

O arquivo voltou a ser o literal de uma entrada. E o `CLAUDE.md` do próprio harness manda rodar `sync-adapters` depois de editar `.forge/`, então o desarme é rotina, não evento de upgrade — e não deixa rastro em `git status`, porque restaura o estado versionado.

### 2.3 O terceiro defeito, que nenhuma issue nomeia: o gancho é inerte no canal real

Este é o achado que muda o desenho. O gancho do template lê **argumentos posicionais**, e o protocolo `PreToolUse` do Claude Code entrega **JSON no stdin, sem argumentos**. Medi as três montagens contra o gancho stock do template, com a carga da issue (uma chave de acesso da AWS no corpo):

```
--- A: stdin JSON, sem argumentos (o que o Claude Code faz) ---
rc=0
--- B: argumentos posicionais (o contrato que o cabeçalho declara) ---
[HOOK] POSSÍVEL VAZAMENTO DE SECRET em: /tmp/x.env
[HOOK]   - AWS Access Key ID detectada (padrão AKIA...)
rc=1
--- C: argumentos posicionais, conteúdo limpo ---
rc=0
```

Três leituras, e as três entram no desenho.

A primeira: pelo canal real o gancho sai `0` sem ter examinado nada, porque `FILE="${1:-}"` fica vazio e a linha seguinte é `if [[ -z "$FILE" ]]; then exit 0; fi`. Não é um detector fraco — é um detector que **não roda**.

A segunda: mesmo quando roda, ele sai `1`, e `1` no protocolo `PreToolUse` é erro não bloqueante. O código de bloqueio é `2`. O conserto que os quatro consumidores aplicaram muda as duas coisas, e é por isso que a medição de campo fala em `rc=2`.

A terceira: dos quatro ganchos de `pre-tool-use` do template, **só um fala o protocolo real**, e é exatamente o único fiado. Medido pelo cabeçalho de cada arquivo:

```
check-language-policy.sh          FILE="${1:-}"
enforce-worktree-location.sh      # Recebe o tool input como JSON no stdin
prevent-secrets-leak.sh           FILE="${1:-}" / CONTENT="${2:-}"
validate-naming-conventions.sh    FILE="${1:-}"
```

E nenhum invocador existe para o contrato posicional: `grep -rn` por cada nome em `template/`, `bin/`, `installer/`, `tests/`, `plugin/` e `.github/` devolve apenas menções em `rules/` e a asserção de existência de arquivo em `tests/snapshot/claude-contract.bats`. Os três ganchos de conteúdo do template nunca foram invocados por ninguém, em canal nenhum.

### 2.4 O que a classe perde — RETRATAÇÃO, e a varredura que me enganou

**Esta seção concluía o oposto do que a árvore faz, e a revisão 1 me derrubou com medição. A conclusão errada era: "desarmar o gancho deixa a classe sem detector".** Ela vinha de eu ter grepado o INVÓLUCRO `check-secrets.sh` — que de fato não cita `AKIA`, porque delega — em vez do leitor canônico. É literalmente o erro que `project-strix-pentest-profile` registra na memória do projeto, cometido de novo por mim, na seção que sustentava o piso de severidade da onda inteira.

O que a árvore faz, medido agora:

```
$ sed -n '162p' template/.forge/scripts/check-secrets.sh
  const S = await import(pathToFileURL(join(lib, 'secret-scan.mjs')).href);

$ grep -an "AKIA" template/.forge/scripts/lib/secret-scan.mjs
13:  { name: 'AWS Access Key ID', re: /AKIA[0-9A-Z]{16}/ },
118:// que menciona `ghp_` ou `AKIA` ao documentar a política não casa, porque não carrega os 36 ou 16
123:  { name: 'AWS Access Key ID', re: /AKIA[0-9A-Z]{16}/ },

$ grep -an "provider-token" template/.forge/scripts/lib/secret-scan.mjs
121:const PROVIDER_TOKEN_RULES = [
181:    for (const rule of PROVIDER_TOKEN_RULES) {
184:        out.push({ cls: 'provider-token', lineNo, reason: `${rule.name} literal (${maskSecret(m[0])})` });
```

A regra está dentro de `PROVIDER_TOKEN_RULES`, que produz achados da classe `provider-token`, que é uma das quatro que `check-secrets.sh:224` conta. **O canal de commit TEM detector para a classe.** E o gate acusa de verdade — fixture git sob `$TMPDIR`, carga montada por concatenação em tempo de execução (nunca literal), `bash .forge/scripts/check-secrets.sh path .`:

```
OK secrets/scan-set — 2 arquivo(s) versionado(s) varrido(s) em path .
WARN secrets/provider-token — 1 ocorrência(s):
      x/conf.yaml:1: AWS Access Key ID literal (valor mascarado, 20 car.)
WARN secrets — 1 ocorrência(s) (enforce: warn, não bloqueia; rule rules/conventions/no-hardcoded-secrets.md)
rc=0
```

**Por que a varredura original devolveu vazio nos DOIS caminhos, e por que isso é um achado próprio.** `grep -n "AKIA"` sobre o leitor canônico também devolve vazio — não porque a regra não esteja lá, mas porque o arquivo é invisível ao `grep` sem `-a`. Ele contém, na implementação do próprio detector de conteúdo binário, bytes de controle LITERAIS dentro de um literal de regex; o `file` o classifica como `data` e o `grep` de texto o pula **sem uma linha de aviso**. É LDG-0177, e o efeito prático é que a minha conclusão errada teria sido confirmada por um segundo caminho independente. Varri o universo inteiro atrás de outros casos:

```
$ for d in tests template bin plugin installer snapshot; do
    for f in $(find $d -type f); do [ -s "$f" ] || continue
      grep -q . "$f" 2>/dev/null || printf '  %-70s %s bytes\n' "$f" "$(wc -c < "$f")"; done; done
  tests/.DS_Store                                              6148 bytes
  template/.DS_Store                                           6148 bytes
  template/.forge/scripts/lib/secret-scan.mjs                 12587 bytes
  snapshot/.DS_Store                                           6148 bytes
```

Exatamente **um** arquivo-fonte rastreado é invisível ao `grep` de texto neste repositório, e é o leitor canônico de segredos. Os `.DS_Store` não são rastreados (`git ls-files | grep -c DS_Store` → `0`). A disciplina que sai daí está em §1.2 e vale para toda varredura de ausência desta spec.

**O que a classe realmente perde, e é o piso de severidade corrigido — mais estreito, e ainda assim suficiente.** Não é a existência do detector; são três propriedades distintas:

1. **O momento.** O detector do canal de commit roda quando o byte já está no disco e no índice. O gancho de `pre-tool-use` existe para rodar **antes** do byte tocar o disco. Um segredo escrito e depois removido do índice permanece no reflog e no diretório de trabalho; um segredo nunca escrito não permanece em lugar nenhum.
2. **A postura, medida no parque.** O default na ausência do bloco `secrets` é `warn`, e ele não bloqueia. Medido nas seis árvores, com `awk` lendo o `enforce` do `forge.yaml` de cada uma:

```
axis-fare-validator     secrets.enforce=block
axis-go-cloud           secrets.enforce=warn
Axis.PadSimulator       secrets.enforce=warn
azim-crm                secrets.enforce=<bloco ausente → warn>
collatra                secrets.enforce=<bloco ausente → warn>
axis-device-platform    secrets.enforce=<bloco ausente → warn>
```

**Um de seis bloqueia; cinco de seis avisam e deixam passar.** Para esses cinco, desarmar o gancho de escrita não move a detecção para mais tarde no fluxo — move para um aviso que não impede nada.

3. **A linhagem, e ela fecha o argumento.** `secret-scan.mjs:3` diz, em letra: *"Extraído dos padrões de `hooks/pre-tool-use/prevent-secrets-leak.sh` para poder ser reusado fora de um hook de ferramenta"*, e `:96` confirma que o piso de quatro caracteres *"vem do `prevent-secrets-leak.sh` e é o mesmo em todo o harness"*. O detector de commit é **descendente** do gancho. O harness extraiu a inteligência do gancho para reusá-la em outro canal e deixou o canal original inerte — que é a forma mais exata de descrever o defeito desta onda.

Essa é a razão pela qual D5 continua fechada e a onda não encolhe: o conserto não é "acrescentar um detector", é **fazer o gancho que já existe rodar pelo canal por onde a escrita passa**. O que cai é a frase "sem detector nenhum", e ela cai inteira.
---

## 3. ITEM #131 — NÃO REPRODUZ, e é isso que decide onde a correção mora

O predicado da issue, reproduzido aqui, com o controle que ela mesma propõe:

```
$ grep -rl "machinery-exceptions" bin/ installer/ tools/
(vazio)

$ grep -rl "machinery-exceptions" . --exclude-dir=.git
.forge/liaison/forge-harness/blobs/067c53ff…-r0069.md
docs/plans/2026-09-07-backlog-zero.md
.forge/liaison/forge-harness/blobs/12b06b02…-r0086.md
```

O controle confirma que o `grep` não está cego. Mas a medição que decide é outra, e a issue não a faz:

```
$ find template -name "*machinery*"
template/.forge/rules/conventions/machinery-propagation.md

$ find . -name "check-machinery-drift.sh" -not -path "./.git/*"
(vazio)
```

**`check-machinery-drift.sh` não existe no template.** Ele existe em exatamente um consumidor:

```
axis-fare-validator                    script exceptions(34)
axis-go-cloud                           
Axis.PadSimulator                       
azim-crm                                
collatra                                
axis-go-cloud/axis-device-platform      
```

Um de seis tem o script e o arquivo; os dois são rastreados lá (`git ls-files` devolve os dois caminhos). Ou seja: o `machinery-exceptions.txt` é maquinaria **local do consumidor**, inventada por ele, e o "contrato" que a issue diz que o updater ignora nunca foi publicado pelo produtor.

**O que isso significa, e é a frase que a régua da onda pede em letra.** #131 não é um defeito do updater: é uma **lacuna de produto**. O updater não ignora um contrato — não há contrato. A correção muda de lugar: em vez de "ensinar o updater a ler um arquivo", a onda **adota o contrato para dentro do template** (formato, semântica de expiração, leitor) e só então o updater passa a honrá-lo. E o custo de não adotar está medido do outro lado — **com uma ressalva que a revisão 1 me obrigou a escrever, e que eu tinha repetido sem conferir.** A issue #131 afirma "30 divergências deliberadas", das quais "24 continuavam vivas" e "9 expiraram". **Os três números não fecham entre si: 24 + 9 = 33, não 30.** Eu repeti a aritmética da issue como se fechasse. Não reproduzi nenhum dos três — eles descrevem um upgrade que aconteceu naquela árvore em outra data, e não há como remedi-los daqui.

O que eu consigo medir hoje, e é o que entra no lugar:

```
$ F=~/Documents/projects/axis-fare-validator/.forge/machinery-exceptions.txt
$ wc -l < "$F"                    → 101
$ grep -c '^[^#]' "$F"            → 34    (linhas úteis: nem vazias, nem comentário)
$ grep '^[^#]' "$F" | awk '{print $2}' | cut -d/ -f1 | sort | uniq -c
   8 hooks
  26 scripts
```

E a classificação de cada uma contra o template DESTA árvore, com o predicado de D3 (`sha declarado == sha do template novo` → viva):

```
$ bash exc.sh                     # o script está colado em §16
declaradas=34  vivas=34  expiradas=0  ociosas_por_caminho_fora_do_template=0
```

**Trinta e quatro declaradas, trinta e quatro vivas, zero expiradas, na data de hoje.** Duas consequências, e as duas corrigem afirmações minhas:

Primeira, e ela é do lado bom: as **oito** exceções sob `hooks/` são exatamente os oito arquivos que a tabela de exposição de D1 conta como `preservaria=8` para essa árvore. Os dois instrumentos, medidos por caminhos independentes, batem — e isso é o que faz o formato ser adotável, não a aritmética da issue.

Segunda, e ela derruba uma frase de §12: eu escrevi que "o próximo `forge update` naquela árvore vai parar pelo menos uma vez" por causa de exceção expirada. **Medido: não vai.** Contra o template de hoje não há nenhuma expirada. O desfecho 2 de D3 continua obrigatório — ele é a razão de o contrato existir —, mas ele **não tem testemunha de campo hoje**, e o cenário `[4]` do Gate 2 tem de montar a expiração sinteticamente, como já monta. §12 foi corrigida.

O desenho do consumidor está inteiro no cabeçalho do arquivo dele e eu o li antes de decidir. Ele fecha o triângulo que o `machinery.lock` sozinho não fecha, e a razão está escrita lá: gravar no lock o sha do **template** deixa o detector acusando divergência permanente; gravar o sha **local** cala o detector e faz o `forge.mjs` classificar o próximo upgrade como limpo, suprimindo até o `WARN`. Declarar é a terceira saída. O crédito é do `axis-fare-validator` e entra no cabeçalho do arquivo que o template passar a distribuir.

---

## 4. ITEM #130 — reproduz, e é uma classe

### 4.1 O predicado, com controle

```
$ grep -nE "import\.meta\.url|realpathSync|process\.argv\[1\]" template/.forge/scripts/lib/sync-adapters.mjs
(vazio)

$ grep -rlE "import\.meta\.url" template/.forge/scripts/ | head
template/.forge/scripts/lib/plugin-build.mjs
template/.forge/scripts/lib/check-observability.mjs
template/.forge/scripts/lib/discover-lite.mjs
…
```

Oito de sessenta e três `.mjs` de `lib/` já usam o idioma de guarda; `sync-adapters.mjs` não usa nenhum.

### 4.2 O efeito, medido

Um leitor mínimo que só faz `await import(...)` e imprime o número de exportações, com `cwd` dentro da fixture:

```
ANTES do import
OK claude adapter synced (70 targets)
OK reconcile complete: 1 active [claude]
DEPOIS do import — exports: 0
rc_leitor=0
```

As duas linhas do meio são exatamente as que a issue cola. E `exports: 0` é um achado próprio: o gate que a #125 pede (comparar `preToolUseWiring()` com o `settings.json`) pressupõe uma exportação que hoje **não existe** — o módulo não exporta nada.

Terceiro efeito, que a issue não mede: importar o módulo a partir de um diretório sem `.forge` **mata o processo importador**.

```
ANTES do import
FAIL (no .forge/FORGE.md under <dir> — run /forge:init first)
rc_leitor=1
```

É `process.exit(1)` em nível de módulo, e não há `try/catch` em volta do `import` que o intercepte.

E o efeito destrutivo, medido com uma edição pendente plantada num alvo gerado, pela mesma bancada e com manifesto de `sha256` da árvore inteira antes e depois:

```
modulo|rc|arquivos_alterados|detalhe
sync-adapters.mjs|0|2|/.claude/settings.json
mermaid-to-drawio.mjs|0|2|/.forge/scripts/lib/mermaid-to-drawio.mjs
orphan-changes.mjs|0|0|
validate-rules.mjs|0|0|
```

Nota de método, e ela corrige uma medição minha anterior: numa árvore **já reconciliada**, importar `sync-adapters.mjs` é neutro em conteúdo, porque o `lock.emit` só escreve quando o conteúdo muda. Uma varredura que não plantasse a edição pendente concluiria que o módulo é inofensivo. O que ele destrói é trabalho **não aplicado**, e é por isso que a fixture precisa da edição pendente.

### 4.3 O achado grave, e ele é meu

Varri os 63 `.mjs` de `template/.forge/scripts/lib/` importando cada um de dentro de uma caixa vazia e contando saída, `rc` e arquivos criados. **A revisão 1 mediu 24 onde eu media 31, com um predicado descrito de outro jeito e sem o meu escrito em lugar nenhum.** Remedi na revisão 2 com o predicado colado, e o número reproduz — mas o que entra na spec agora não é o número: é a classificação, que é o que decide o desenho.

Predicado, ambiente e leitor, para que a divergência seja de critério e não de mistério: cópia dos 63 para `$TMPDIR`, `cwd` numa caixa vazia **criada de novo para cada módulo** (a revisão 3 mediu que reusar a caixa contamina a classificação — ver abaixo), `await import()` dentro de `try/catch`, **o caminho do módulo entregue por variável de ambiente e nunca por `argv`** (passá-lo em `argv[2]` é o que destruiu o `mermaid-to-drawio.mjs`, §4.3 — o leitor da própria varredura era a arma). Executa no import quem sai com `rc≠0` **ou** imprime alguma linha além das duas do leitor. `node v26.0.0`, macOS.

```
=== total .mjs ===        63
=== EXECUTAM no import === 31
=== INERTES ===            32
```

Repeti a varredura de dentro de uma caixa **com** `.forge/FORGE.md`, para descartar sensibilidade ao `cwd`: `31 de 63` de novo. O `31` é o número robusto desta onda: ele reproduziu em seis execuções minhas e na bancada do revisor, com dois predicados diferentes.

**A partição em três classes NÃO é robusta, e a revisão 3 mediu por quê — o achado é meu e derruba a linha que eu tinha escrito.** A revisão 2 publicou `18 mata / 10 imprime / 3 lança`; o revisor mediu `20 / 8 / 3` e atribuiu a divergência a critério. Não é critério: é **resíduo da caixa**. A varredura das duas rodadas importava os 63 módulos com o `cwd` na **mesma** caixa, e pelo menos um dos módulos **cria `.forge/` dentro dela**, o que muda o desfecho dos módulos importados depois. Medido nesta bancada, com o mesmo leitor e a mesma cópia dos 63:

```
caixa COMPARTILHADA, passe 1 (caixa limpa):   executam=31  mata/imprime/lança = 21/7/3   resíduo deixado: .forge
caixa COMPARTILHADA, passe 2 (mesma caixa):   executam=31  mata/imprime/lança = 20/8/3
caixa NOVA por módulo, passe 1:               executam=31  mata/imprime/lança = 23/3/5
caixa NOVA por módulo, passe 2:               executam=31  mata/imprime/lança = 23/3/5
```

O `20/8/3` do revisor é o passe 2 da caixa compartilhada, e o `18/10/3` meu é o mesmo instrumento num terceiro estado de resíduo. Com **uma caixa nova por módulo** a partição para de se mexer: `23` matam o importador, `3` imprimem e `5` lançam, idêntico em dois passes consecutivos. Trocando o critério de morte — `rc≠0` do leitor em vez de ausência do marcador de fim — a mesma bancada isolada dá `22/4/5`, e os três módulos que migram entre os dois critérios estão nomeados (`baseline-extract.mjs`, `changelog-from-merge.mjs`, `validate-rules.mjs`: saem `rc=0` sem o leitor chegar ao fim).

**Nenhum dos números entra em asserção desta onda**, e a lição de método é a que importa: uma varredura de efeito colateral que reusa a caixa mede o resíduo tanto quanto o módulo. O item de ledger de §15 passa a carregar o predicado, o isolamento e os dois critérios, em vez de um triplo que quem ler não sabe remedir.

A classe grave — a que mata o importador — é a de `sync-adapters.mjs` e `mermaid-to-drawio.mjs`, e os dois estão nela sob os dois critérios e sob os dois isolamentos. Nessa varredura eu passei o caminho do módulo como argumento do leitor, e `mermaid-to-drawio.mjs:16` é `const inFile = process.argv[2]` — que naquela invocação era o caminho do próprio módulo. A linha 19 é `const outFile = outArg >= 0 ? … : inFile.replace(/\.(md|mmd)$/, '.drawio')`; o caminho termina em `.mjs`, a substituição não casa, e `outFile === inFile`. O módulo leu a si mesmo, interpretou o próprio código-fonte como um diagrama Mermaid — os nós resultantes chamam-se `com`, `ut`, `if`, `const`, `try` — e escreveu o XML **por cima do próprio fonte**, com `rc=0` e uma linha `OK`.

```
$ git diff --stat HEAD -- template/.forge/scripts/lib/mermaid-to-drawio.mjs
 template/.forge/scripts/lib/mermaid-to-drawio.mjs | 254 +---------------------
 1 file changed, 11 insertions(+), 243 deletions(-)
```

Restaurado com `git checkout HEAD -- <path>`, e `git status --porcelain` conferido vazio depois. É a mesma classe de LDG-0175 — arquivo rastreado, distribuído no pacote npm, destruído por maquinaria — com o agravante de que aqui a operação parecia de leitura. Um `git commit -a` por cima desse estado publicaria o módulo destruído para os consumidores.

E a exposição não é hipotética: `template/.forge/scripts/check-secrets.sh:162` faz `await import(pathToFileURL(join(lib, 'secret-scan.mjs')).href)` em **produção**. O harness já importa `.mjs` de `lib/` no caminho quente; o que o protege hoje é a sorte de `secret-scan.mjs` não estar entre os 31.

### 4.4 A armadilha do conserto, medida contra o idioma que o próprio repositório já usa

`plugin-build.mjs:117` usa `if (import.meta.url === \`file://${process.argv[1]}\`)`. Instrumentei o `sync-adapters.mjs` de uma fixture para imprimir os dois lados nas três invocações:

```
=== A: via sync-adapters.sh (o invocador legítimo) ===
PROBE argv1=/var/folders/…/c125/.forge/scripts/lib/sync-adapters.mjs
PROBE meta =file:///private/var/folders/…/c125/.forge/scripts/lib/sync-adapters.mjs
PROBE strEq=false
=== B: node <caminho absoluto do .mjs>, como o w112 faz ===
PROBE strEq=false
=== C: import (o caso de #130) ===
PROBE strEq=false
```

**A igualdade de string crua é falsa nas três, inclusive nas duas legítimas.** No macOS `$TMPDIR` mora sob `/var/folders`, que é link simbólico para `/private/var`; `process.argv[1]` preserva o caminho pelo link e `import.meta.url` traz o caminho real. Copiar o idioma de `plugin-build.mjs` para cá desarmaria o gerador exatamente no ambiente em que as fixtures da suíte rodam — que é a retratação que a própria issue #130 registra, aqui reproduzida contra o idioma já publicado no repositório.

Prova de existência de um primitivo que discrimina, medida na mesma bancada e nas mesmas três invocações — é existência, não prescrição, porque a escolha continua sendo do implementador:

```
=== A: via sync-adapters.sh ===  PROBE realpathEq=true
=== B: node direto ===           PROBE realpathEq=true
=== C: import ===                PROBE realpathEq=false
```

Restauração conferida byte a byte por `cmp -s` contra a cópia original nas duas instrumentações.

---

## 5. ITEM #142 — NÃO REPRODUZ como escrita, e o que reproduz é pior

### 5.1 A premissa da issue, medida e refutada

A issue afirma que "o update do template altera esse nome". Fixture com o bloco local decidido pelo consumidor (`enabled: true`, `resource: axis-heavy-suite`, `root: "${TMPDIR:-/tmp}"`), seguida de `forge update`:

```
=== bloco depois do update ===
heavy_mutex:
  enabled: true
  resource: axis-heavy-suite
  root: "${TMPDIR:-/tmp}"
  timeout_s: 1800
forge.yaml MUDOU
3:forge.yaml: template_version -> 0.14.0
```

O `forge.yaml` mudou apenas em `template_version`. **O updater não reescreve `resource`, não reescreve `root` e não reescreve `enabled`.** A razão está no código e é estrutural: `mergeNewForgeKeys` (`bin/forge.mjs:483`) só acrescenta **chaves de topo ausentes**, e `newForgeKeys` (`bin/forge.mjs:447`) pula toda chave que o projeto já tem. A sugestão (1) da issue — "nunca reescrever `resource` num update" — já é o comportamento de hoje.

### 5.2 O que de fato acontece, medido

Fixture de consumidor de versão anterior, com o bloco `heavy_mutex:` inteiro removido, seguida de `forge update`:

```
=== bloco depois do update ===
heavy_mutex:
  enabled: false
  resource: forge-heavy-suite
  timeout_s: 1800
=== o que o relatório diz sobre isso ===
4:forge.yaml: 1 chave(s) de topo nova(s) do template mescladas: heavy_mutex
```

O bloco chega inteiro, com o default do template, e o relatório **nomeia a chave**. Não é silencioso sobre o merge; é silencioso sobre a **consequência**. E a consequência é de segunda ordem, o que a issue descreve com precisão: o sintoma não aparece na árvore que aplicou, aparece na relação entre ela e as irmãs.

Há um segundo efeito, e o `Axis.PadSimulator` já o escreveu no próprio `forge.yaml`: `root` **ficou de fora do mesmo update**. Isso não é omissão do template — é consequência do desenho aditivo. O merge é por chave de topo, então **nenhuma sub-chave nova jamais chega a um consumidor que já tem o bloco**. Um consumidor com `heavy_mutex:` de 2026-08 nunca receberá `root:`, `stale_after_s:` ou qualquer chave futura por update, para sempre, sem uma linha de aviso.

### 5.3 O estado medido nas árvores desta máquina, e ele corrige o diagnóstico da issue

```
axis-fare-validator     enabled: true   resource: axis-heavy-suite   root: "${TMPDIR:-/tmp}"   timeout_s: 1800
Axis.PadSimulator       enabled: true   resource: axis-heavy-suite   root: '${TMPDIR:-/tmp}'   timeout_s: 1800   stale_after_s: 3600
axis-go-cloud           enabled: false  resource: forge-heavy-suite  (sem root)                timeout_s: 1800
azim-crm                forge.yaml sem bloco heavy_mutex
collatra                forge.yaml sem bloco heavy_mutex
axis-device-platform    forge.yaml sem bloco heavy_mutex
```

**Correção da revisão 3, e ela derruba dois números meus.** A linha do `azim-crm` que eu tinha aqui (`enabled: false  resource: forge-heavy-suite  (sem root)`) **não reproduz**: aquele `forge.yaml` tem 67 linhas e as chaves de topo `version, harness, specs, graph, quality, handoff, ledger, autonomy, capabilities` — não há bloco `heavy_mutex` nem bloco `secrets`, e o arquivo não muda desde 2026-07-29, então não é defasagem entre bancadas. Logo **três de seis** têm o bloco, não quatro, e **um só** declara `enabled: false`, não dois. O revisor mediu isso antes de mim e a remedição é dele.

A issue descreve "duas famílias de lock, cada uma se achando protegida". O que está instalado é diferente e a diferença importa: dois repositórios participam de `$TMPDIR/axis-heavy-suite.lock`, **um** declara `enabled: false` e **três não têm o bloco** — e para o `pre-push` os quatro últimos são o mesmo estado, porque `_heavy_enabled` (`template/.forge/hooks/git/pre-push:237-241`) devolve falso tanto para `enabled: false` quanto para `forge.yaml` sem o bloco, e o engate em `:242` depende dele. Quatro de seis **não participam de lock nenhum**. A saturação que a issue documenta é compatível com isso — e a leitura honesta é que o `axis-go-cloud` rodou **fora de qualquer lock**, não dentro de outro. A partição de D8 e D10 continua real, e agora com o denominador certo: dois de um lado, quatro do outro.

Ressalva obrigatória, porque ela limita a minha própria conclusão: o `axis-go-cloud` tem um `heavy-mutex-preflight.sh` **local**, que não existe no template (`find . -name "*heavy-mutex-preflight*"` devolve vazio aqui), e o `pre-push` dele está entre os arquivos derivados. O que eu meço é o que o **código do template** faz com o `forge.yaml` medido; o que a árvore deles executa é maquinaria própria, e eu não a auditei.

### 5.4 O defeito de produto que reproduz aqui: o contrato proíbe o que o leitor suporta

`template/.forge/scripts/lib/heavy-mutex.sh` aceita, documenta e trata em galho próprio a **expressão literal** `${TMPDIR:-/tmp}` como valor de `heavy_mutex.root`, com um comentário de nove linhas explicando que é "o único valor que um repositório PODE versionar para convergir com o protocolo legado". O schema declara `"root": { "type": "string", "pattern": "^/" }`. A expressão não casa `^/`.

Medido, validando contra `$defs/forgeManifest` por um wrapper com `$ref` (o schema raiz não tem `$ref` para o manifesto, e por isso valida qualquer coisa — ver §5.5):

```
--- template/.forge/forge.yaml                → OK
--- Axis.PadSimulator/.forge/forge.yaml       → FAIL
    /heavy_mutex  additionalProperty: stale_after_s
    /heavy_mutex/root  must match pattern "^/"
    /quality  additionalProperty: require_human_approval_before_archive
--- axis-fare-validator/.forge/forge.yaml     → FAIL
    /heavy_mutex/root  must match pattern "^/"
    /quality  additionalProperty: require_human_approval_before_archive
```

**Os dois consumidores que resistiram ao default estão em violação de contrato hoje, em silêncio, pelo valor exato que o leitor do harness pede que eles escrevam.** É a classe de LDG-0159, que o `w199` fecha para `runtime.gates` e ninguém fechou para `heavy_mutex`.

Sobre `stale_after_s`: `grep -rn "stale_after_s" template/` devolve **vazio**. A chave não tem leitor no template — foi inventada pelo `Axis.PadSimulator`. Declará-la no schema aqui criaria uma chave publicada sem leitor, que é exatamente LDG-0151. Ela pertence a **L2/#137**, e a fronteira está declarada em §14.

### 5.5 Um achado colateral que esta onda registra e não conserta

O schema raiz de `forge.schema.json` tem apenas `$schema`, `$id`, `title` e `$defs` — **nenhum `$ref`, nenhuma `properties`, nenhum `additionalProperties`**. Validar um `forge.yaml` contra ele é vácuo: aceita qualquer documento. E `tests/w112-liaison-session-gate.sh:53` valida um `forge.yaml` exatamente assim. Isso é falso-verde e pertence à Onda D; aqui ele entra por uma razão operacional: **a asserção de paridade do gate desta onda tem de apontar para `$defs/forgeManifest` explicitamente**, sob pena de nascer vácua pelo mesmo motivo. Abre item de ledger novo (§15).

---

## 6. Decisões de desenho — FECHADAS

### D1. `hooks/` NÃO entra em `ENRICHABLE_DIRS`, e a razão é medida

A issue #125 pede, no item 1, que `hooks` entre em `ENRICHABLE_DIRS` "como `templates` entrou pela #71". Executei a proposta literal numa **cópia do produtor** sob `$TMPDIR` — a árvore rastreada nunca foi tocada — e medi os dois lados, com controle de mutação e recontrole.

Do lado bom, ela funciona: com o conserto local plantado e sem lock, `PRESERVADO`, `= hooks/pre-tool-use/prevent-secrets-leak.sh` no relatório, e o detector voltando a sair `rc=2`.

Do lado ruim, ela congela. **Esta é a medição M4, e a revisão 1 registrou que só eu a tinha. Reproduzi-a de novo, agora com o par completo control/recontrole, e ela é o que fecha a decisão central da onda.** Fixture de consumidor **apenas defasado** — o gancho é uma versão anterior do template, que ele nunca tocou, montada removendo a regra de JWT do arquivo do template —, sem lock:

```
=== controle da mutação ===
controle: bin/forge.mjs MUDOU (mutação aplicada)      # cmp -s contra a cópia original
$ grep -n "^const ENRICHABLE_DIRS" bin/forge.mjs
352:const ENRICHABLE_DIRS = ['agents', 'rules', 'skills', 'templates', 'hooks'];

=== com 'hooks' em ENRICHABLE_DIRS, consumidor apenas DEFASADO, sem lock ===
rc=0
3:preservados: 1 arquivo(s) com customização local NÃO sobrescritos:
4:  = hooks/pre-tool-use/prevent-secrets-leak.sh
linhas com JWT depois do update = 0        ← a correção do template NUNCA chegou

=== RECONTROLE: restaura bin/forge.mjs e repete a MESMA fixture ===
restauração byte a byte: OK                # cmp -s contra a cópia original
352:const ENRICHABLE_DIRS = ['agents', 'rules', 'skills', 'templates'];
rc=0
(nenhuma linha de preservação)
linhas com JWT depois do update = 2        ← a correção do template chegou
```

Sem lock o fallback de `ENRICHABLE_DIRS` é conservador — "divergiu do template novo → preserva" — e a população sem lock é justamente a que só está atrasada. A correção de segurança do template **nunca chega**, e o relatório chama o congelamento de "customização local". Trocar um desarme silencioso por um congelamento silencioso não é fechar a issue. O recontrole é o que impede esta linha de ser mutação-fantasma: a mesma fixture, o mesmo comando, o arquivo restaurado byte a byte, e o desfecho **inverte**.

*Alternativa descartada — `ENRICHABLE_DIRS`, a proposta literal da issue.* Pela medição acima. O precedente da #71 não transfere: `templates/` é fonte de um artefato de governança e não é canal de entrega de gate.

*Alternativa descartada — `PRESERVED_ON_DRIFT_DIRS` (o conjunto decidido por lock que a Onda C cria para `scripts/`).* Ele discrimina corretamente — medi os dois galhos: com lock, arquivo **defasado** recebe upgrade limpo (`A: ATUALIZADO`, com o detector de JWT de volta) e arquivo **consertado** é preservado. O problema é de classe, e a Onda C já o nomeou em P5: `hooks/` é o **canal de entrega** dos gates.

**A medição de exposição, refeita na revisão 2 porque a da revisão 1 não tinha comando colado e dois dos seis números estavam errados.** O revisor não reproduziu as colunas `preservaria` e `upgrade_limpo` e mediu um deslocamento constante nas linhas de lock que eu apresentava. Investigando: o `machinery.lock` **não fica em `.forge/machinery.lock`** — fica em `.forge/cache/machinery.lock`, o que sozinho já explica por que uma varredura de um lado e uma de outro não convergiam. A coluna de linhas do lock **saiu**: ela não sustentava argumento nenhum e era decoração que envelhece. O que ficou é o que decide, e o script está colado em §16:

```
$ bash expo.sh <as seis árvores>
axis-fare-validator     no_lock=13  preservaria=8  upgrade_limpo=0  ausente=0  fora_do_lock=5
axis-go-cloud           no_lock=13  preservaria=4  upgrade_limpo=0  ausente=2  fora_do_lock=1
Axis.PadSimulator       no_lock=13  preservaria=3  upgrade_limpo=0  ausente=0  fora_do_lock=4
azim-crm                no_lock=13  preservaria=3  upgrade_limpo=3  ausente=0  fora_do_lock=1
collatra                no_lock=13  preservaria=0  upgrade_limpo=6  ausente=0  fora_do_lock=0
axis-device-platform    no_lock=13  preservaria=7  upgrade_limpo=3  ausente=0  fora_do_lock=2
```

Predicado, escrito porque sem ele o número não vale: para cada entrada `hooks/*` do `machinery.lock` da árvore, `preservaria` conta os arquivos cujo sha em disco **difere** do sha gravado no lock (a regra por lock os leria como conserto local); `upgrade_limpo` conta os que **batem** com o lock e cujo sha no template desta árvore **difere** dele (defasagem pura, que a regra por lock deixaria passar). `fora_do_lock` conta arquivos sob `.forge/hooks/` que não têm entrada nenhuma no lock — maquinaria local do consumidor.

Duas correções a mim, e as duas importam: `azim-crm` não é `0/0` como eu escrevi, é `3/3`; e `axis-device-platform` é `7`, não `6`. As outras quatro linhas reproduziram idênticas.

E a linha nominal, que eu tinha errada: **`hooks/git/pre-push` diverge do lock em CINCO dos seis, não em quatro** — só o `collatra` o tem idêntico:

```
$ bash prepush.sh <as seis árvores>
axis-fare-validator     pre-push DIVERGE do lock (seria preservado)
axis-go-cloud           pre-push DIVERGE do lock (seria preservado)
Axis.PadSimulator       pre-push DIVERGE do lock (seria preservado)
azim-crm                pre-push DIVERGE do lock (seria preservado)
collatra                pre-push idêntico ao lock
axis-device-platform    pre-push DIVERGE do lock (seria preservado)
→ 5 de 6 com lock
```

Preservá-lo significa que uma correção na fiação dos gates nunca chega a cinco das seis árvores, e o operador lê "customização local" sobre isso. Os números são testemunha de data; a propriedade que o gate afirma é *"existe pelo menos um consumidor cujos ganchos a regra preservaria e pelo menos um cujos ganchos ela não preservaria"* — piso um de cada lado, e hoje o parque real tem cinco de um lado e três do outro, sobre denominador seis.

### D2. Divergência **não declarada** em `hooks/` continua sendo sobrescrita — e passa a ser nominal

O que muda não é o destino do arquivo; é o que o operador fica sabendo. Uma linha **por arquivo**, com token próprio e o caminho **real** do backup daquela execução, tanto com lock quanto sem:

```
SOBRESCRITO (não declarado): hooks/pre-tool-use/<arquivo> diverge do template e não há exceção
  declarada em .forge/machinery-exceptions.txt. O conteúdo anterior está em <backup real>.
  Para preservá-lo no próximo update, declare a exceção com o sha do template.
```

O invariante que o gate afirma: **zero linhas do relatório citando um arquivo de `hooks/` que a execução acabou de sobrescrever é o estado que a asserção derruba**, com o denominador de arquivos derivado da própria fixture, nunca literal.

*Alternativa descartada — recusar o update quando há deriva em `hooks/`.* Hostil pela mesma medição de exposição: **cinco** dos seis consumidores parariam no primeiro update, com de três a oito arquivos cada (`preservaria` é `8/4/3/3/0/7`; só o `collatra` é zero), para uma condição que na maioria das vezes é defasagem.

Consequência que precisa ser dita, porque decide um cenário alheio: com `hooks/` fora de qualquer galho de preservação implícita, o cenário `[4b]` que a Onda C cria — "um arquivo de `hooks/` sobrescrito com o `WARN` corrigido" — **continua tendo universo**, e a mensagem `WARN: drift local` não fica órfã. §7 fecha essa reconciliação.

### D3. `.forge/machinery-exceptions.txt` vira contrato do template, com três desfechos e um rc novo

O formato é o que o `axis-fare-validator` já opera, adotado com crédito nominal no cabeçalho do arquivo distribuído: uma linha por arquivo, `<sha256 do TEMPLATE no momento da declaração>  <caminho relativo a .forge/>  # razão`, com `#` e linha vazia ignorados.

Os três desfechos, e eles são exaustivos sobre o par (exceção declarada, sha do template):

1. **Exceção viva** — o sha declarado é igual ao sha do template **novo**: o arquivo é **preservado** e **nomeado**, com a razão declarada ecoada no relatório.
2. **Exceção expirada** — o sha declarado difere do sha do template novo: o update **para antes de escrever qualquer arquivo**, com rc próprio, e pede reexame **nominal** — nunca sobrescreve nem preserva em silêncio. O template mudou o arquivo desde a declaração, então a dispensa cobria uma divergência que ninguém mais examinou.
3. **Sem exceção** — D2.

E os desfechos que a enumeração precisa cobrir e que a issue não enumera, procurados ativamente por exigência da invariante 17:

4. **Exceção para um caminho que não existe no template** (o consumidor declarou um arquivo local). Não é erro: é exceção **ociosa**, reportada como tal e sem efeito sobre a escrita.
5. **Exceção para um caminho que existe no template mas cujo arquivo local é byte-idêntico ao template novo**. Também ociosa — não há divergência a dispensar —, reportada e sem efeito. Deixar isso passar em silêncio é o que faz uma exceção sobreviver à correção e absolver sozinha, meses depois, uma divergência que ninguém leu.
6. **Arquivo de exceções ausente** (a esmagadora maioria hoje: cinco dos seis consumidores). Comportamento idêntico ao de hoje mais D2, sem uma linha de ruído — a ausência do arquivo não é anomalia.
7. **Arquivo de exceções ilegível ou com linha malformada.** Terceiro estado, não verde e não vermelho: o update **para** com o token de não verificado, nomeando a linha, porque prosseguir seria decidir sobre preservação com uma lista que ninguém sabe se está completa. Uma linha malformada num arquivo de dispensa é indistinguível de uma dispensa que se pretendia declarar.

8. **Duas declarações para o MESMO caminho, com shas diferentes.** Achado da revisão 2, procurado ativamente por exigência da invariante 17 — a enumeração de sete estava incompleta e eu a apresentei como exaustiva. O caso não é hipotético: o formato é uma linha por arquivo, escrita à mão, e a operação natural de "atualizar uma exceção" é acrescentar a linha nova sem apagar a velha. Nenhuma das duas é obviamente a corrente: a mais recente no arquivo pode ser a que alguém colou por engano, e resolver por "a última vence" transforma ordem de linha em semântica que ninguém declarou. **É terceiro estado, como o 7**: o update para, nomeia o caminho e as duas linhas, e pede que uma seja removida. O parser o detecta, e a propriedade P1 do PBT (§11) já cobre o espaço — a duplicata é uma das entradas geradas.

Sobre o **nono** candidato que eu procurei e descartei: exceção declarando caminho sob um diretório que o update não gerencia (`specs/`, `product/`, `graph/`). Ele não é estado novo — cai no desfecho 4, exceção ociosa por caminho fora do template, e o relatório o nomeia como tal. Registro a busca porque uma enumeração que só cresce quando alguém a derruba não é exaustiva; é sortuda.

*Alternativa descartada — gravar o sha local no `machinery.lock` para calar o detector.* É a saída que o cabeçalho do consumidor já refuta com medição: cala o detector **e** faz o `forge.mjs` classificar o próximo upgrade como limpo, suprimindo até o `WARN` — a perda volta a ser total.

*Alternativa descartada — preservar por deriva sem exigir declaração.* É D1, medida como congelamento.

### D4. O bloco `PreToolUse` deriva do DIRETÓRIO; matcher, contrato e ATIVAÇÃO vêm de um manifesto de duas camadas

O universo dos ganchos é o **conteúdo** de `.forge/hooks/pre-tool-use/`: gancho novo entra na fiação sozinho. O que não se deriva do diretório é o **matcher**, o **contrato de entrada** e — decisão nova da revisão 2, §D4.3 — o **estado de ativação**.

#### D4.1 As duas camadas, e por que duas

- `hooks.manifest.default` — **distribuído pelo template**, declara matcher e contrato dos ganchos do próprio template, e é atualizado por update como qualquer maquinaria. **Não carrega ativação.**
- `hooks.manifest` — **nunca distribuído**, do consumidor, sobrepõe entradas por nome de arquivo e é a única camada que carrega ativação.

*Alternativa descartada — um único manifesto distribuído.* Medido: os **treze** arquivos de `template/.forge/hooks/` estão no `machinery.lock` (`grep -c '  hooks/' .forge/cache/machinery.lock` → `13` num consumidor real, contra `find template/.forge/hooks -type f | wc -l` → `13`). Um manifesto único, distribuído, estaria no lock e seria sobrescrito — as declarações do consumidor sumiriam no próximo overlay, levando os ganchos dele junto. Seria o defeito desta onda reentrando pela porta do remédio.

*Alternativa descartada — um cabeçalho `# forge-matcher:` dentro de cada gancho.* Pela mesma medição: treze de treze estão no lock, então o cabeçalho some no overlay, o gerador deixa de saber o matcher, e o gancho cai da fiação. **O campo chegou à mesma conclusão de forma independente e a escreveu no cabeçalho do arquivo dele**, com a medição própria: *"QUATRO dos cinco hooks estão no `.forge/cache/machinery.lock` (…) Um `# forge-matcher:` escrito dentro deles sumiria no próximo overlay (…) `hooks.manifest` NÃO está no lock"*.

*Alternativa descartada — declarar a lista no `forge.yaml`, que é o item 2 da issue #125.* Medida e refutada em §5.2: o merge do `forge.yaml` é por **chave de topo ausente**, então uma sub-chave nova nunca chega a um consumidor que já tem a chave. A fiação ficaria congelada exatamente para a população que já instalou o harness — que é toda ela.

#### D4.2 A ponte NÃO é um gancho, e a regra de exclusão é estrutural — bloqueador 3 da revisão 1

A revisão 1 mostrou uma contradição real entre §0, que punha a ponte em `hooks/pre-tool-use/<ponte>.sh`, e a guarda 2, que reprova todo `.sh` do diretório sem entrada no manifesto: ou a ponte é fiada como gancho (despachando para si mesma), ou a igualdade de conjunto de `[3]` reprova contra o código certo. A regra de exclusão não estava escrita em lugar nenhum. Está agora, e ela tem duas metades porque as duas populações são diferentes.

**A metade estrutural, para o que o produtor distribui.** A ponte mora em `template/.forge/hooks/pre-tool-use/lib/`, e o universo é `*.sh` na **profundidade 1** do diretório. O precedente é do próprio repositório e eu não o tinha invocado: `template/.forge/hooks/git/lib/` já é onde a maquinaria auxiliar de gancho mora, com `check-docs-reviewed.sh` e `check-red-first.sh` chamados pelo `pre-push:37` via `HOOK_LIB_DIR="$ROOT/.forge/hooks/git/lib"`. A vantagem sobre uma exceção declarada é que a guarda 2 continua **incondicional**: todo `.sh` de profundidade 1 precisa de entrada, sem caso especial que um manifesto malformado possa explorar.

**A metade declarativa, para a base instalada — e ela existe porque o campo já resolveu o problema do outro jeito.** Medido no `axis-fare-validator`, que opera a ponte em produção:

```
$ ls -1 .forge/hooks/pre-tool-use/*.sh | wc -l        → 7
$ python3 -c "… json … settings.json"
'^(Write|Edit|MultiEdit|NotebookEdit)$' -> $CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/dispatch-file-hook.sh $CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/check-language-policy.sh
'^(Write|Edit|MultiEdit|NotebookEdit)$' -> $CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/dispatch-file-hook.sh $CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/prevent-secrets-leak.sh
'^(Write|Edit|MultiEdit|NotebookEdit)$' -> $CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/dispatch-file-hook.sh $CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/validate-naming-conventions.sh
'^Bash$' -> $CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/enforce-docs-on-publish.sh
'^Bash$' -> $CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/enforce-worktree-location.sh
'^Bash$' -> $CLAUDE_PROJECT_DIR/.forge/hooks/pre-tool-use/guard-machinery-drift.sh
```

**Sete `.sh` no diretório, seis entradas fiadas.** A ponte está no diretório, em profundidade 1, e **nunca é uma entrada própria** — ela aparece como o primeiro token do comando de cada gancho `argv`. Sob a regra estrutural sozinha, essa árvore reprovaria na guarda 2 no primeiro `sync` depois da onda, nomeando `dispatch-file-hook.sh`: seria a onda quebrando exatamente o consumidor que resolveu o problema antes do produtor.

Por isso a regra é a união: **todo `.sh` de profundidade 1 precisa de declaração; uma declaração do tipo `dispatcher` satisfaz a guarda 2 e exclui o arquivo do conjunto fiado.** O produtor não precisa dela — a ponte dele está em `lib/` —, e a base instalada declara a sua com uma linha. A guarda 2 não enfraquece: nada no diretório fica sem declaração; o que muda é que uma das declarações possíveis diz "isto não é um gancho".

**Duas correções da revisão 3, e as duas são de alcance.** A primeira: a obrigação de declarar a ponte **vale para uma árvore só**. Medido em §D4.3.1 — o `axis-fare-validator` tem 7 `.sh` em profundidade 1 e 6 declarações, com `dispatch-file-hook.sh` mencionado apenas em comentário; o `Axis.PadSimulator` tem 4 `.sh` e 4 declarações, com o auxiliar dele já em `pre-tool-use/lib/pw-detector.sh`, ou seja, **já no layout que esta decisão escolhe**. O precedente estrutural de `hooks/git/lib/` não é só do produtor: uma das duas árvores de campo já o adotou por conta própria, e o crédito de §D4.2 passa a ser das duas. A segunda: a obrigação da declaração `dispatcher` **não estava registrada em nenhuma seção que fale com o consumidor**, e agora está — §12 e §14 item 8. Enquanto ela não for cumprida, quem protege aquela árvore não é esta decisão: é a guarda 4 (§D4.5), que para antes de a guarda 2 chegar a julgá-la.

#### D4.3 A ativação — bloqueador 4 da revisão 1

A revisão 1 derrubou o amaciamento de §12 com um argumento que eu não tinha resposta: o **mesmo** arquivo distribuído não pode produzir ganchos ativos no `init` e inativos no `update`, e um gancho presente no diretório e não fiado violaria a igualdade de conjunto de `[3]`. As duas metades caem, e o conserto muda as duas.

**A ativação não mora na camada distribuída.** `hooks.manifest.default` declara matcher e contrato e nada mais — é o mesmo arquivo em toda árvore, e continua sendo. A ativação mora no `hooks.manifest` do consumidor, que **nunca é distribuído** e por isso pode legitimamente diferir entre uma árvore nova e uma árvore que já existia.

**Quem escreve o `hooks.manifest`, e é aqui que a diferença é honesta: não é o arquivo, é o SEMEADOR.** Ele é semeado uma vez, por quem instala, e nunca mais tocado por maquinaria:

- **`forge init`** semeia com **todo gancho do template ativo.** Repositório novo, sem legado, sem fiação anterior a preservar.
- **`forge update`**, quando o arquivo está **ausente**, semeia derivando a ativação do que a árvore **já tem fiado** no `.claude/settings.json`: gancho hoje fiado nasce ativo, gancho hoje não fiado nasce **inativo e nomeado no relatório**. Nada que funcionava para de funcionar, e nada é ativado sem alguém saber.
- **Se o arquivo já existe**, nem `init` nem `update` o tocam. É a camada do consumidor — e §D4.3.1 mede que essa cláusula tem dois adotantes reais e o que ela custa neles.

Isso não é só o mecanismo que faltava ao amaciamento — é **conserto de um dano medido**. §2.2 mede que qualquer execução do gerador hoje apaga a fiação armada à mão, e §12 mede que três das seis árvores armaram a sua contra o gerador. O semeador alcança **uma** dessas três, e as outras duas são conservadas por outro mecanismo — a guarda 4 de §D4.5. §D4.3.1 é a medição que separa os dois casos, e ela derruba a frase que eu tinha escrito aqui.

#### D4.3.1 A base instalada JÁ escreveu o `hooks.manifest`, em DOIS esquemas incompatíveis — medição, e o limite que ela impõe a esta onda

Achado do orquestrador, registrado como **LDG-0178**, remedido por mim por leitura pura das seis árvores. A revisão 2 desenhou D4.3 tratando o `hooks.manifest` do consumidor como arquivo que ainda não existe em lugar nenhum. Existe, em dois, e os dois têm colunas diferentes:

```
$ for d in <as seis árvores>; do wc -l .../hooks.manifest; grep -c '^[^#]' ...; done
axis-fare-validator      linhas=63  declarações=6
axis-go-cloud            AUSENTE
Axis.PadSimulator        linhas=38  declarações=4
azim-crm                 AUSENTE
collatra                 AUSENTE
axis-device-platform     AUSENTE

$ grep '^[^#]' <cada um> | awk -F'\t' '{print NF}' | sort -u
axis-fare-validator      5     hook · matcher · contrato · UNIVERSO · razão
Axis.PadSimulator        4     hook · matcher · contrato · ESTADO
```

Os valores da **quarta coluna**, que é onde os dois esquemas colidem, lidos um a um:

```
axis-fare-validator      .cs,.java   |  comando  |  comando  |  comando  |  *  |  *
Axis.PadSimulator        armado      |  armado   |  retido:portao-invertido-le-o-disco-alcance-de-conteudo-zero-LDG-0387
                                     |  retido:28-falsos-positivos-estruturais-em-engine-e-sai-por-exit-1-LDG-0387
```

Quatro leituras, e as quatro mudam o desenho.

**Primeira: o `Axis.PadSimulator` já implementa a ativação que D4.3 apresentava como invenção da revisão 2**, com razão medida escrita por gancho retido — inclusive um retido por *"portão invertido que lê o disco"* e outro por 28 falsos positivos estruturais, os dois com o item de ledger deles na linha. O cabeçalho do arquivo diz em letra que a coluna `estado` *"É UMA ADIÇÃO NOSSA AO DESENHO ORIGINAL"* e credita o desenho ao `axis-fare-validator`. **Nenhuma das duas árvores é derivada do produtor: o produtor chega por último, a um contrato que o campo escreveu duas vezes.** O crédito de §D4.2, §D4.3 e §12 vai para as duas, e a linhagem entre elas é do campo, não minha.

**Segunda: um leitor do produtor que ponha ativação na quarta coluna lê as DUAS árvores errado.** No `axis-fare-validator` ele leria `*` e `comando` como estado; no `Axis.PadSimulator`, `retido:<razão>` como token que ele não conhece. E se token desconhecido cair para **ativo**, os dois ganchos que o `Axis.PadSimulator` reteve deliberadamente voltam a ser fiados — que é exatamente o dano que a guarda 3 existe para evitar, reentrando pela porta do remédio. **Esta onda não escreve esse leitor**, e §D4.5 é o mecanismo que garante que ele não exista por omissão.

**Terceira: nem a terceira coluna é comparável entre as duas árvores, e a razão é boa.** As duas declaram `prevent-secrets-leak.sh`, e o `axis-fare-validator` diz `argv` enquanto o `Axis.PadSimulator` diz `stdin-json`. Não é discordância: os arquivos são diferentes. O `axis-fare-validator` manteve o gancho em `argv` e pôs uma ponte externa (`dispatch-file-hook.sh`); o `Axis.PadSimulator` reescreveu o próprio gancho para ler o stdin quando `argv` não vem, com fail-closed medido em stdin vazio (`prevent-secrets-leak.sh:37`, *"BLOQUEADO: o payload do PreToolUse não chegou (stdin vazio) — fail-closed"*). **O campo resolveu o defeito de §2.3 pelos dois caminhos, e um deles é a alternativa que D5 descarta.** O descarte de D5 continua de pé como decisão de produto — uma ponte é um lugar só, três reescritas são três — mas ele deixa de ser apresentado como caminho único, e a existência de duas soluções de campo é a prova mais forte de que o defeito é real.

**Quarta: a guarda 2 estruturalmente reprovaria uma das duas árvores, e passaria a outra.** Medido: o `axis-fare-validator` tem **7 `.sh` em profundidade 1 e 6 declarações**, e a ponte só aparece no cabeçalho, em comentário (`grep -n dispatch-file-hook` → linha 21, `#`) — sem declaração própria, ela é o arquivo que a guarda 2 nomearia. O `Axis.PadSimulator` tem **4 `.sh` em profundidade 1 e 4 declarações**, com o auxiliar dele em `pre-tool-use/lib/pw-detector.sh`, profundidade 2 — ou seja, ele **já satisfaz as duas metades de §D4.2**, a estrutural e a declarativa, sem nenhuma mudança. A obrigação de declarar a ponte com uma linha existe para uma árvore só, e agora ela está escrita em §12 e em §14, e não apenas em §D4.2.

**O que esta onda faz com isso, e é a fronteira em letra.** Escolher o esquema de coluna da camada do consumidor é decisão de produto que exige conversa com os dois adotantes pelo canal de liaison, e está registrada **fora desta onda**, como LDG-0178. Esta especificação **não inventa um terceiro esquema** e **não finge que o campo não escreveu nada**: ela entrega a derivação, o `hooks.manifest.default` do produtor e as guardas **sem ler a quarta coluna de manifesto nenhum que não seja o seu**, e trata manifesto de esquema desconhecido como **terceiro estado** — §D4.5. A ativação por sobreposição do consumidor só passa a ser lida quando LDG-0178 fechar o esquema; até lá, quem já tem o arquivo conserva a fiação que tem, byte a byte, e é nomeado em toda execução.

#### D4.4 As quatro guardas, e as quatro reprovam ou param em vez de emitir array vazio, parcial ou inferido

A ordem é normativa e a guarda 4 vem primeiro, pela razão medida em §D4.5.

0. **(Guarda 4, avaliada antes das demais.) Manifesto do consumidor em esquema não reconhecido.** Terceiro estado: para, nomeia o arquivo e o LDG-0178, e deixa o `settings.json` anterior byte-idêntico. Detalhada em §D4.5.
1. **Universo vazio.** Diretório ausente, ou sem nenhum `.sh` em profundidade 1, reprova — universo vazio não é ausência de gancho.
2. **Não declarado.** `.sh` de profundidade 1 sem entrada em nenhuma das duas camadas reprova **nomeando o arquivo**. Uma entrada `dispatcher` satisfaz esta guarda e exclui o arquivo do conjunto fiado (D4.2).
3. **Declarado e inativo.** Gancho com entrada e ativação desligada **não é erro** — é o estado que o amaciamento produz — mas é **reportado nominalmente**, em toda execução, com a linha que diz como ativá-lo. Um gancho que ninguém vê inativo é indistinguível de um gancho desarmado, que é o defeito desta onda inteira.

O resultado vazio reprova. A recusa acontece **antes** de escrever o `settings.json`, para que o arquivo anterior sobreviva, e o `update` que a provocar reporta a recusa nominalmente. O crédito do desenho é do `axis-fare-validator` e do `Axis.PadSimulator`, no fio `upgrade-desarma-o-proprio-ponto-de-entrada` do canal — e §D4.3.1 mede o que cada um dos dois contribuiu, porque a revisão 2 dava o crédito de ativação ao primeiro quando quem a implementou foi o segundo.

**O que desta decisão eu NÃO executei, e por isso é propriedade e não prescrição:** o semeador de `update` derivando ativação do `settings.json` existente, a declaração `dispatcher` da guarda 2, a guarda 3 e a guarda 4 com o marcador de formato. Nenhum dos quatro existe em código hoje, meu ou de ninguém; o que eu medi é o estado de partida de cada um (a fiação de campo, o layout da ponte de campo, o dano do gerador, os dois manifestos instalados e a ausência de marcador de formato nos dois) e é isso que autoriza a decisão. A prova de que cada mecanismo discrimina é do implementador, e os quatro entram na lista de §16.

#### D4.5 Guarda 4 — manifesto do consumidor em esquema NÃO reconhecido é terceiro estado, nunca "ativo por omissão"

A regra, e ela é a única forma de D4.3 conviver com LDG-0178 sem escolher por cima dos dois adotantes: **o gerador reconhece exclusivamente o esquema que ele mesmo semeia**, marcado por uma linha de versão de formato que o semeador escreve e que nenhum dos dois arquivos de campo tem (conferido: nem o cabeçalho de 63 linhas do `axis-fare-validator` nem o de 38 do `Axis.PadSimulator` carrega marcador de formato do produtor). Diante de um `hooks.manifest` sem esse marcador, o gerador:

1. **recusa derivar** — sai com o rc de não verificado, **antes** de escrever o `settings.json`, de modo que a fiação anterior da árvore fica **byte-idêntica**;
2. **nomeia o arquivo e o item** — a linha diz qual manifesto ele não reconhece e aponta LDG-0178, em vez de dizer "erro de formato", que convidaria alguém a "consertar" o arquivo do consumidor;
3. **nunca infere** — token desconhecido não vira ativo, não vira inativo e não vira ausente. A quarta coluna alheia não é lida.

A ordem importa e é normativa: **a guarda 4 corre antes das guardas 2 e 3.** Sem essa ordem, o `axis-fare-validator` seria reprovado pela guarda 2 por causa da ponte não declarada — a onda quebrando o consumidor que resolveu o problema antes do produtor, que é o dano que §D4.2 existe para fechar, reentrando por outra porta.

O que a guarda 4 custa: nas duas árvores que já têm o arquivo, a onda **não** entrega a derivação — elas continuam com a fiação que armaram à mão, que é exatamente o que elas querem, e passam a ser nomeadas em toda execução até LDG-0178. O que ela impede: que a onda desarme dois ganchos deliberadamente retidos por leitura errada de uma coluna alheia. **Trocar entrega por não-dano nas duas árvores que resolveram o problema primeiro é a única troca honesta disponível antes de LDG-0178.**

*Alternativa descartada — inferir o esquema pelo número de colunas.* `5` e `4` de fato discriminam as duas árvores de hoje, mas o esquema do produtor também terá um número de colunas, e ele colidiria com um dos dois; pior, a inferência funcionaria em silêncio até o dia em que uma das árvores acrescentasse uma coluna — e nesse dia o desfecho seria ativação errada, não erro. Contagem de coluna é heurística; marcador é declaração.

*Alternativa descartada — ler os dois esquemas conhecidos, um galho para cada.* É inventar o terceiro esquema com outro nome: o produtor passaria a manter, sem acordo, um leitor de dois formatos de campo que os donos podem mudar amanhã. E fixaria por código uma decisão que LDG-0178 existe para tomar por conversa.

**A consequência sobre `[3]`, e ela corrige a asserção.** A igualdade de conjunto não é entre os `.sh` do diretório e os comandos emitidos — é entre o conjunto **ativo** e os comandos emitidos. O diretório continua sendo o universo; a ativação é o recorte; e o que impede o recorte de virar desarme silencioso é a guarda 3.

### D5. O gancho de bloqueio sai `2`, e o gancho de conteúdo recebe o que julgar por uma ponte

A propriedade, e o implementador escolhe o primitivo: um gancho declarado `stdin-json` é fiado direto e recebe o JSON do protocolo; um gancho declarado `argv` recebe o **caminho do arquivo** e o **conteúdo que está entrando**, e nunca o disco. E um gancho que decide bloquear sai `2`, não `1`.

*Alternativa descartada — reescrever cada um dos três ganchos de conteúdo para ler o stdin.* Triplica a superfície e obriga cada gancho a reimplementar a extração do JSON, que é onde as decisões de falha-aberta e falha-fechada divergem entre si. Uma ponte é um lugar só. O `axis-fare-validator` já opera uma (`dispatch-file-hook.sh`), e a existência dela é prova de que o caminho não é vazio — mas eu **não a executei**, então o que esta especificação fixa é a propriedade, e a prova de que a ponte discrimina é do implementador.

*Alternativa descartada — fiar os ganchos `argv` como comando nu, sem ponte.* Medido em §2.3: `rc=0` pelo stdin, com o gancho aprovando a carga. É armar um gate cego, que é pior do que não armá-lo, porque passa a contar como cobertura.

**O matcher é ancorado.** `TodoWrite` contém `Write`; sem âncora, um matcher de substring casa uma ferramenta cujo `tool_input` não tem caminho de arquivo, e a postura de falha-fechada da ponte transforma isso em bloqueio de uma ferramenta legítima. A asserção que fixa isso é **negativa** — a positiva sozinha aprova um matcher que casa tudo. Este achado é do campo e chegou pelo canal (`axis-pad-simulator-0014`); eu o registro sem tê-lo reproduzido, e a reprodução é obrigação do implementador antes de escrever a asserção.

### D6. `sync-adapters.mjs` ganha guarda de principal por **identidade de arquivo** e exportações nomeadas

A propriedade: importado como biblioteca, o módulo **não executa nada**; invocado como principal — pelo wrapper `sync-adapters.sh` ou por `node <caminho>` —, executa exatamente como hoje. O contrafactual que a guarda tem de produzir está medido em §4.4: `true`, `true`, `false` nas três invocações. E a prova é obrigatoriamente **dos dois lados** — um fail-closed que desarme o caminho legítimo é pior que o efeito colateral que ele fechava.

*Alternativa descartada — o idioma de `plugin-build.mjs` (`import.meta.url === \`file://${process.argv[1]}\``).* Medido falso nas três invocações sob `$TMPDIR` no macOS. Fica registrado como item de ledger que `plugin-build.mjs` tem a mesma fragilidade, medida e não corrigida por esta onda (§15).

O `process.exit(1)` de nível de módulo (`sync-adapters.mjs:41`) passa a viver dentro do galho de principal: importado, o módulo não pode matar o importador.

E o módulo passa a **exportar** a função que monta a fiação, porque o gate que a #125 pede precisa lê-la — hoje `exports: 0`.

### D7. `mermaid-to-drawio.mjs` ganha a mesma guarda, e por medição própria

Entra nesta onda porque o dano é da classe de LDG-0175, foi medido nesta bancada contra a árvore **real** (§4.3) e custa uma guarda. Os outros vinte e nove módulos que executam no import viram item de ledger com o predicado, o isolamento e a data (§15) — generalizar sem classificar cada sítio é o erro de LDG-0171, e esta onda não o repete.

### D8. O update **nunca** reescreve `heavy_mutex.resource`, `root` ou `enabled` — e um gate trava isso

Hoje já é verdade (§5.1). O que esta onda entrega é a **prova durável**: um cenário que planta um bloco local divergente, roda o update e exige que as três chaves fiquem byte-idênticas, com prova de mutação que faz o updater reescrevê-las e observa o gate acusar. Fechar por "já funciona" sem gate seria fechar por reclassificação silenciosa, que o plano-mestre proíbe.

### D9. Paridade schema↔leitor de `heavy_mutex.root`, e nada além disso no schema

O schema passa a aceitar o que o leitor canônico aceita: caminho absoluto **ou** a expressão literal `${TMPDIR:-/tmp}`. A asserção de paridade valida contra `$defs/forgeManifest` explicitamente, nunca contra a raiz — §5.5 mede que a raiz é vácua.

*Alternativa descartada — declarar `stale_after_s` junto.* `grep -rn "stale_after_s" template/` devolve vazio: a chave não tem leitor. Declará-la seria publicar uma chave sem leitor, que é LDG-0151. Ela pertence a #137, em L2, e a fronteira está em §14 com a consequência escrita.

### D10. Registro de famílias de lock em caminho FIXO, informativo, nunca bloqueante — com alavanca de isolamento

O problema real de #142 é que ninguém consegue ver a partição de dentro de uma árvore. A propriedade: toda árvore que executa o caminho do mutex — adquirindo **ou** decidindo não participar — deixa um registro num diretório de caminho **fixo**, independente de `resource` e de `root`, com o caminho da árvore, `enabled`, `resource`, `root` resolvido e o instante. O `doctor` lê o diretório e informa quantas famílias distintas de `(root, resource)` existem naquela máquina e quais árvores declaram não participar.

O caminho é fixo por decisão já registrada em `rules/conventions/heavy-resource-serialization.md`: um registro ancorado em `$TMPDIR` se particiona junto com o que ele existe para denunciar. Medi a superfície dessa partição nesta máquina: `ls -d /var/folders/*/*/T | wc -l` → **37** diretórios distintos, remedido na revisão 2. O número é testemunha de data; a propriedade é que ele é maior que um.

#### D10.1 A alavanca de isolamento — bloqueador 5 da revisão 1

A revisão 1 mostrou o buraco: caminho fixo, independente de `resource` e de `root`, sem nenhuma alavanca declarada, significa que o **gate escreve no registro real da máquina** e que a sentinela `[7]` — limitada ao conjunto de arquivos sob a raiz de lock — não alcança o vazamento. Pior: o denominador de `[5]` leria entradas de outras árvores e de execuções anteriores da própria suíte, e o "derivado em execução" que §10 promete não seria separável do parque. Confirmei o pressuposto: `heavy-mutex.sh:130-131` prende `FORGE_HEAVY_MUTEX_TESTING=1` a `FORGE_HEAVY_MUTEX_ROOT`, e essa trava governa a raiz do **lock**, não de um registro que ainda não existe.

A alavanca é uma variável de ambiente própria para a raiz do registro, com o **mesmo idioma de asserção positiva** que a biblioteca já usa e pela mesma razão escrita lá: um cenário que esqueça de montar a caixa falha alto em vez de tocar a máquina. O escritor do registro recusa, com o `rc 69` do idioma existente, quando `FORGE_HEAVY_MUTEX_TESTING=1` e a raiz do registro está vazia. Produção nunca define nenhuma das duas, então o caminho fixo continua fixo onde importa.

Isso **não** reintroduz a partição que D10 denuncia, e a diferença é de natureza: a partição que D10 combate é **acidental e silenciosa** — uma árvore se separa das irmãs sem saber, porque `$TMPDIR` difere. A alavanca é **explícita, exclusiva de bancada e ruidosa na ausência**: quem não a define não se isola, é recusado.

#### D10.2 Onde o escritor do registro NÃO pode morar, e é achado da invariante 15

O registro **não** entra em `heavy_mutex_acquire`. Ele mora no caminho do `doctor` e do pré-voo do `pre-push`, e a razão é medida: `tests/w151-heavy-mutex-gate.sh:66-67` exporta `FORGE_HEAVY_MUTEX_TESTING=1` para o gate inteiro e passa `FORGE_HEAVY_MUTEX_ROOT` **por invocação**; `tests/w154-heavy-mutex-yaml-root-gate.sh:52` faz `env -u FORGE_HEAVY_MUTEX_ROOT -u FORGE_HEAVY_MUTEX_TESTING` de propósito, para exercitar a própria trava. Se a escrita do registro entrasse em `acquire` com a trava estendida, **os dois gates ficariam vermelhos por construção** — o w151 porque define `TESTING=1` sem a variável nova, o w154 porque o caminho que ele desnuda mudaria de contrato. Nenhum dos dois é uma edição barata: o w151 tem **1348** linhas (`wc -l tests/w151-heavy-mutex-gate.sh` → `1348`; o `1277` que eu tinha escrito não reproduz, e o revisor mediu antes de mim — o argumento sobrevive, o número não).

Manter o escritor fora de `acquire` custa exatamente aquilo que D10 **já declarava como limite** — "uma árvore que nunca rodou o `doctor` nem o `pre-push` não aparece no registro" —, então a fronteira não encolheu: ela ficou explícita e ganhou a razão mecânica.

#### D10.3 Os limites, ditos em voz alta

Uma árvore que nunca rodou o `doctor` nem o `pre-push` não aparece no registro — a cobertura é da população que executou pelo menos uma vez, e §D10.2 é o porquê. Uma entrada envelhece: ela carrega o instante e o relatório diz a idade, em vez de fingir que o inventário é do agora. O registro **nunca** bloqueia; a rule já decidiu que travar aqui é como um gate vira `--no-verify` de hábito.

*Alternativa descartada — o preflight ler os `forge.yaml` das árvores irmãs, que é a sugestão (2) da issue.* Exige descobrir as árvores irmãs, e não há descoberta possível sem varrer o disco do usuário a cada push. O registro inverte a direção: cada árvore se anuncia onde as outras sabem olhar.

*Alternativa descartada — entregar o bloco `heavy_mutex` sem `resource`, deixando o default no leitor.* Não muda o recurso resolvido (o default do leitor é o mesmo nome) e tira do consumidor a única linha que ele pode ler para saber com quem pretende se serializar.

**Não executado por mim:** o mecanismo do registro, a alavanca e a recusa por `rc 69`. O que medi é o pressuposto de cada um — a trava existente, o alcance dela, os 37 diretórios e o arranjo de `TESTING` nos dois gates. Entra em §16.

## 7. Reconciliação obrigatória com a Onda C

A Onda C, já aprovada, mexe no mesmo updater. As duas especificações precisam ser compatíveis linha a linha, e são — mas por decisão, não por sorte.

| Ponto | Onda C | Onda L1 | Compatível? |
|---|---|---|---|
| `scripts/` | entra em `PRESERVED_ON_DRIFT_DIRS`, decidido por lock | intocado | sim — conjuntos disjuntos |
| `hooks/` | **explicitamente fora de escopo** (P5), com item de ledger a abrir | D1: continua fora de qualquer preservação implícita; ganha declaração explícita (D3) e relatório nominal (D2) | sim — **esta onda É o item de ledger que a Onda C prometeu abrir**, e a decisão dela é a mesma de P5, com o número que faltava |
| `WARN: drift local` | `[4b]` usa um arquivo de `hooks/` como universo sobrevivente da mensagem | D2 mantém `hooks/` sendo sobrescrito | sim — e é **por isso** que D2 não move `hooks/` para preservação: mover esvaziaria o universo de `[4b]` e a mensagem ficaria órfã |
| Rótulo do backup (`.forge.bak-N`) | P4 corrige as quatro strings | não toca nenhuma delas; consome o rótulo já corrigido nas mensagens novas de D2 | sim — **dependência de ordem**: as mensagens de D2 usam o rótulo de três valores de P4 |
| Recusa `rc 5` sem lock e sem backup | P3 | D3 acrescenta um rc para exceção expirada e outro para arquivo de exceções ilegível; D4.5 acrescenta o terceiro, para manifesto de consumidor em esquema não reconhecido | **exige coordenação**: os **três** códigos precisam ser alocados uma vez, no mesmo lugar, e a tabela de rc do `update` é fronteira publicada |
| `--dry-run` | `[9]` prevê preservação em `scripts/` | prevê preservação por exceção viva e parada por exceção expirada | sim, aditivo |

**A ordem de entrega é: Onda C primeiro, ou as duas no mesmo PR.** Se L1 saísse antes, as mensagens novas de D2 nasceriam com o literal `.forge.bak-N` errado que P4 existe para corrigir, e a tabela de rc seria reaberta duas vezes.

---

## 8. O VERMELHO, antes do verde

Ordem de trabalho obrigatória: **escrever cada gate inteiro primeiro, executá-lo, colar a saída vermelha no PR, e só então tocar a produção.** A invariante 1 trata vermelho não observado como achado da revisão adversarial. Todo número que aparece na coluna "vermelho de hoje" é o valor medido nesta bancada e serve para o implementador reconhecer o vermelho quando o vir; **nenhum deles é literal no fonte do gate** — a mensagem imprime o que aquela execução mediu, e a asserção é sobre a propriedade.

### 8.1 Gate 1 — `tests/w<NNN>-hook-wiring-derived-gate.sh`

`DECLARADOS=19`, cenários `[0]` a `[11]` mais `[6b]`, `[6c]`, `[7b]`, `[7c]` e `[7d]`, acrescentados na revisão 2 por D4.2 e D4.3, mais `[6d]` e `[7e]`, acrescentados na revisão 3 por §D4.3.1 e §D4.5. Dois nascem verdes por construção: `[0]`, contador do próprio gate, e `[11]`, sentinela. **Dezessete** falham hoje por ausência real.

| # | Cenário | Asserção | Vermelho de hoje | Por que falha por ausência real |
|---|---|---|---|---|
| [0] | CONTADOR DE CONTROLE | §10 | — | nasce verde; é o denominador de cenários do próprio gate |
| [1] | CONTRATO DE ENTRADA — cada gancho declarado `argv` recebe caminho e conteúdo pelo canal real | para cada gancho, uma carga que ele deve reprovar produz recusa quando entregue pelo protocolo do runtime | `FAIL [1]: pelo protocolo real (JSON no stdin, sem argumentos) o gancho sai rc=0 sem examinar nada` | os três ganchos de conteúdo leem `${1:-}` e saem `0` com `FILE` vazio (§2.3) |
| [2] | CÓDIGO DE BLOQUEIO — gancho que decide bloquear sai `2` | `rc = 2` | `FAIL [2]: o gancho sai rc=1, que no protocolo PreToolUse é erro não bloqueante` | `prevent-secrets-leak.sh` termina em `exit 1` |
| [3] | DERIVAÇÃO — o `settings.json` gerado fia todo gancho **ativo**, e o conjunto de comandos é exatamente o conjunto ativo | igualdade de **conjunto** entre os ganchos ativos (D4.3) e os comandos emitidos, comparada como conjunto e **nunca por contagem**; a ponte em `lib/` e toda entrada `dispatcher` estão fora dos dois lados por construção (D4.2); o cenário roda numa árvore cujo manifesto tem o marcador de formato do produtor, senão a guarda 4 para antes (D4.5) | `FAIL [3]: 4 gancho(s) no diretório, 1 fiado — o gerador emite um literal` | `sync-adapters.mjs:233` é um literal de um gancho |
| [4] | GANCHO NOVO ENTRA SOZINHO — um `.sh` novo no diretório, com entrada no `hooks.manifest` local | aparece na fiação sem que ninguém edite o gerador | `FAIL [4]: gancho novo não aparece no settings.json` | idem [3] |
| [5] | GUARDA 1 — diretório de ganchos vazio ou ausente | o gerador **reprova**, e o `settings.json` anterior fica byte-idêntico | `FAIL [5]: universo vazio produziu settings.json com o literal, indistinguível de árvore sem gancho` | não há guarda; o literal sai sempre |
| [6] | GUARDA 2 — `.sh` de profundidade 1 sem entrada em nenhuma camada do manifesto | reprova **nomeando o arquivo**, e o `settings.json` anterior fica byte-idêntico | `FAIL [6]: gancho sem declaração foi ignorado em silêncio` | o manifesto não existe |
| [6b] | GUARDA 2, O OUTRO LADO — um `.sh` de profundidade 1 declarado como `dispatcher` (o layout que o campo opera, §D4.2) | **não** reprova, e **não** aparece no conjunto fiado | `FAIL [6b]: o layout de ponte plana do axis-fare-validator é reprovado pela guarda 2` | a declaração `dispatcher` não existe |
| [6c] | GUARDA 3 — gancho declarado e **inativo** | não é erro, e é **reportado nominalmente** com a linha que diz como ativá-lo; o conjunto fiado o exclui | `FAIL [6c]: gancho inativo é indistinguível de gancho desarmado` | a ativação não existe |
| [6d] | GUARDA 4 — `hooks.manifest` do consumidor **sem o marcador de formato do produtor** (§D4.5). A fixture escreve o arquivo nas **duas** formas de campo, uma por sub-caso: cinco colunas com universo na quarta, e quatro colunas com estado na quarta | o gerador **para antes** das guardas 2 e 3, o `settings.json` anterior fica **byte-idêntico**, a linha nomeia o arquivo e o LDG-0178, e **nenhum** gancho é ativado por inferência — em particular, o gancho cuja quarta coluna é `retido:<razão>` **não** aparece na fiação | `FAIL [6d]: o gerador leu a quarta coluna alheia e fiou um gancho que o consumidor havia retido` | nada disso existe; §D4.3.1 mede os dois esquemas instalados |
| [7] | DUAS CAMADAS — entrada local sobrepõe a do `hooks.manifest.default` para o mesmo arquivo, e uma entrada só local sobrevive a um `update` | a fiação usa o matcher local, e o arquivo local é byte-idêntico depois do update | `FAIL [7]: hooks.manifest.default e hooks.manifest não existem` | o contrato não existe |
| [7b] | SEMEADURA POR `update` — árvore com `hooks.manifest` ausente e fiação armada à mão no `settings.json` | o `hooks.manifest` semeado deixa **ativo** exatamente o que já estava fiado e **inativo e nomeado** o que não estava; nenhum gancho antes fiado sai da fiação | `FAIL [7b]: o update reduziu a fiação de N ganchos a 1` | o semeador não existe; §2.2 mede o gerador apagando a fiação armada à mão |
| [7c] | SEMEADURA POR `init` — árvore nova | todo gancho do template nasce **ativo** | `FAIL [7c]: init não semeia manifesto` | idem |
| [7d] | SEMEADURA NÃO REESCREVE — `hooks.manifest` já presente **no formato do produtor**, seguido de `update` e de `init` sobre a mesma árvore | o arquivo fica **byte-idêntico** nas duas | `FAIL [7d]: a semeadura sobrescreveu a camada do consumidor` | idem — e é o contrafactual que impede a onda de reintroduzir o próprio defeito |
| [7e] | SEMEADURA NÃO ALCANÇA A BASE INSTALADA — `hooks.manifest` já presente **em esquema de campo**, nas duas formas de `[6d]`, com fiação armada à mão no `settings.json` | nem `update` nem `init` tocam o manifesto **e** a fiação anterior sobrevive **byte a byte**; o relatório nomeia a árvore como pendente de LDG-0178 | `FAIL [7e]: a árvore de esquema de campo perdeu a fiação armada à mão` | idem — e é o cenário que a revisão 2 não tinha, porque ela supunha que o semeador alcançava as três árvores que armaram à mão; §D4.3.1 mede que alcança **uma** |
| [8] | MATCHER ANCORADO — asserção **negativa** | uma ferramenta cujo nome **contém** o nome de uma ferramenta de escrita, sem casar por igualdade, **não** dispara o gancho | `FAIL [8]: o matcher casa por substring e uma ferramenta não pretendida é interceptada` | o matcher literal de hoje é `Bash`, sem âncora |
| [9] | CANAL DE ENTREGA — `sync-adapters.sh` de verdade, numa fixture, com edição pendente no `settings.json` | o gerador roda pelo wrapper e o resultado é a derivação, com **sinal positivo de execução** escolhido e provado discriminante pelo implementador | `FAIL [9]: o wrapper produziu o literal de um gancho` | idem [3] |
| [10] | PARIDADE — a função exportada que monta a fiação e o `settings.json` emitido descrevem o mesmo conjunto | conjuntos idênticos, lidos por importação da função | `FAIL [10]: o módulo não exporta nada (exports: 0) e importá-lo reconcilia a fixture` | medido em §4.2 |
| [11] | SENTINELA DO PRÓPRIO GATE | `git -C <repo> status --porcelain` e o conjunto de `sha256` de `template/` idênticos no início e no fim | `FAIL [11]: o gate mexeu na árvore real` | nasce verde; o vermelho dela é defeito do gate (LDG-0175) |

Nota obrigatória sobre `[1]` e `[2]`, e ela existe porque a carga é sensível: a fixture **constrói** a carga por concatenação em tempo de execução, nunca como literal no fonte do gate. `tests/w139-secrets-gate.sh` cenário `[15]` varre **este repositório inteiro** contra o próprio detector; um literal com forma de credencial dentro de um gate novo reprovaria o `w139` — e o programa já pagou esse pedágio com uma chave de exemplo dentro de uma especificação.

### 8.2 Gate 2 — `tests/w<NNN>-update-hooks-exceptions-gate.sh`

`DECLARADOS=14`, cenários `[0]` a `[12]` mais `[8b]`, acrescentado na revisão 2 pelo desfecho 8 de D3. **Quatro** nascem verdes: `[0]` (contador), `[2]` (a guarda contra congelar maquinaria, e M4 prova que ela mede — §6 D1, com controle e recontrole), `[10]` (guarda de regressão da issue #16, e M5 prova que morde) e `[12]` (sentinela). A frase anterior dizia três e omitia `[10]`, contra a própria tabela e contra §17 — o passo 1 de §17 manda registrar quem nasce verde, então a prosa errada mandava procurar vermelho onde não há.

| # | Cenário | Asserção | Vermelho de hoje | Por que falha por ausência real |
|---|---|---|---|---|
| [0] | CONTADOR DE CONTROLE | §10 | — | nasce verde |
| [1] | SEM exceção, com conserto local em `hooks/` | sobrescreve **e** nomeia o arquivo, com o caminho real do backup; zero linhas citando o arquivo é o estado que a asserção derruba | `FAIL [1]: <N> linha(s) de relatório e 0 citando o gancho destruído` — com `<N>` interpolado do próprio log | medido em §2.1: relatório sem lock não cita o arquivo |
| [2] | CONTROLE — consumidor apenas defasado em `hooks/`, sem exceção | **sobrescrito**, e o conteúdo passa a ser o do template novo | — | nasce verde; é a guarda contra congelar o canal de entrega, e M4 prova que ela mede |
| [3] | EXCEÇÃO VIVA | arquivo **preservado** byte a byte, nomeado no relatório com a razão declarada | `FAIL [3]: exceção viva foi sobrescrita — o arquivo .forge/machinery-exceptions.txt não é lido por ninguém` | `grep -rl "machinery-exceptions" bin/ installer/ tools/` → vazio (§3) |
| [4] | EXCEÇÃO EXPIRADA | o update **para** com rc próprio, pede reexame nominal, e a árvore **inteira** de `.forge/` fica byte-idêntica ao estado anterior | `FAIL [4]: exceção expirada foi sobrescrita com rc=0` | idem [3] |
| [5] | EXCEÇÃO OCIOSA por caminho fora do template | reportada como ociosa, sem efeito sobre a escrita, rc 0 | `FAIL [5]: exceção ociosa não é reportada` | idem [3] |
| [6] | EXCEÇÃO OCIOSA por arquivo idêntico ao template novo | reportada como ociosa, sem efeito, rc 0 | `FAIL [6]: exceção que não cobre nada sobrevive sem ser reportada` | idem [3] |
| [7] | ARQUIVO DE EXCEÇÕES AUSENTE | comportamento de [1], **sem** nenhuma linha de ruído sobre a ausência | `FAIL [7]: a ausência do arquivo é reportada como anomalia` | idem [3] |
| [8] | ARQUIVO DE EXCEÇÕES COM LINHA MALFORMADA | terceiro estado: o update **para**, com token de não verificado, nomeando a linha; árvore intacta | `FAIL [8]: linha malformada foi ignorada e o update prosseguiu decidindo com uma lista incompleta` | idem [3] |
| [8b] | DUAS DECLARAÇÕES PARA O MESMO CAMINHO, shas diferentes (desfecho 8 de D3, achado da revisão 2) | terceiro estado: o update **para**, nomeando o caminho e as duas linhas; árvore intacta. **Nunca** "a última vence" | `FAIL [8b]: a duplicata foi resolvida por ordem de linha, em silêncio` | idem [3] |
| [9] | `--dry-run` | prevê exatamente o que [1], [3] e [4] fazem, com os mesmos caminhos, e **não escreve** | `FAIL [9]: o dry-run marca o gancho com `~`, indistinguível de atualização de rotina` | medido em §2.1 |
| [10] | RETROCOMPATIBILIDADE DE `rules/` | um arquivo de `rules/` com customização continua preservado pela regra de hoje, sem exceção declarada | — se falhar, a onda regrediu a issue #16 | nasce verde; é guarda de regressão, e M5 prova que morde |
| [11] | EXPOSIÇÃO NO PARQUE | existe pelo menos um consumidor conhecido cujos ganchos a regra **preservaria** e pelo menos um cujos ganchos ela **não preservaria** — piso um de cada lado, derivado em execução, nunca literal | `FAIL [11]: a regra preserva tudo ou não preserva nada` | ver §6 D1 |
| [12] | SENTINELA DO PRÓPRIO GATE | como `[11]` do Gate 1 | `FAIL [12]: o gate mexeu na árvore real` | nasce verde |

Nota sobre `[4]` e `[8]`: a asserção é *árvore intacta*, e ela só é verdadeira se a decisão de parar for tomada num pré-voo sobre a lista inteira, **antes** do laço que escreve. Parar no meio do laço deixa a árvore pela metade, que é pior que o defeito. O implementador prova a propriedade comparando o conjunto de `sha256` de `.forge/` antes e depois, nunca a existência de um arquivo específico.

Nota sobre `[11]`, e ela é obrigatória: a fixture **não** pode ler `~/Documents/projects`. O gate roda em máquinas que não têm os consumidores, e ler árvore de terceiro de dentro da suíte é dependência de ambiente que a suíte não controla. O cenário monta dois consumidores sintéticos em `$TMPDIR` — um com conserto declarado, outro apenas defasado — e afirma o piso sobre eles. A tabela de §6 D1 é testemunha de data e **não entra em asserção**.

### 8.3 Gate 3 — `tests/w<NNN>-module-import-side-effect-gate.sh`

`DECLARADOS=7`, cenários `[0]` a `[6]`. **Quatro** nascem verdes: `[0]` (contador), `[2]` e `[3]` (os dois caminhos legítimos de invocação, que hoje passam e só ficam vermelhos sob M6) e `[6]` (sentinela). A frase anterior dizia dois, contra a própria tabela e contra §17.

| # | Cenário | Asserção | Vermelho de hoje | Por que falha por ausência real |
|---|---|---|---|---|
| [0] | CONTADOR DE CONTROLE | §10 | — | nasce verde |
| [1] | IMPORTAR NÃO EXECUTA — `sync-adapters.mjs` importado com edição pendente no `settings.json` | o `settings.json` fica **byte-idêntico** e o import não imprime nenhuma linha do gerador | `FAIL [1]: o import reconciliou 70 alvos e apagou a edição pendente` (medido: sha `6d074298…` → `c9d15dd1…`) | não há guarda de principal (§4.1) |
| [2] | INVOCAR EXECUTA — pelo wrapper `sync-adapters.sh` | reconcilia normalmente, com a saída de hoje | — se falhar, a guarda desarmou o caminho legítimo, que é a retratação de #130 | nasce **vermelho** só sob M6; hoje passa. É a metade que impede o fail-closed |
| [3] | INVOCAR EXECUTA — por `node <caminho absoluto do .mjs>`, o arranjo de `tests/w112-liaison-session-gate.sh:62,69` | idem [2] | idem | idem — e é o arranjo em que o idioma de string crua falha (§4.4) |
| [4] | IMPORTAR NÃO MATA O IMPORTADOR — import a partir de um diretório sem `.forge` | o importador continua vivo e o `import` devolve o módulo | `FAIL [4]: o import terminou o processo com rc=1 e a mensagem citava o cwd do importador` | `process.exit(1)` em nível de módulo |
| [5] | AUTODESTRUIÇÃO — `mermaid-to-drawio.mjs` importado com o próprio caminho em `process.argv[2]` | o arquivo do módulo fica **byte-idêntico** | `FAIL [5]: o módulo sobrescreveu o próprio fonte (243 linhas removidas, 11 acrescentadas) com rc=0 e uma linha OK` | medido em §4.3, na árvore real |
| [6] | SENTINELA DO PRÓPRIO GATE | como as demais — e aqui ela **não é decoração**: este gate é o que mais chegou perto de destruir a árvore | `FAIL [6]: o gate mexeu na árvore real` | nasce verde |

Nota obrigatória, e ela é a lição de §4.3 aplicada ao próprio gate: **nenhum cenário importa um módulo pelo caminho de `template/`**. Todos operam sobre cópias em `$TMPDIR`. O gate que mede a autodestruição não pode ser o caminho pelo qual ela acontece.

### 8.4 Gate 4 — `tests/w<NNN>-heavy-mutex-partition-gate.sh`

`DECLARADOS=9`, cenários `[0]` a `[7]` mais `[7b]`, acrescentado na revisão 2 por D10.1. Dois nascem verdes: `[0]` e `[1]`. `[7]` nasce **meio verde** e é o único cenário desta onda nesse estado — verde no eixo do lock, vermelho no do registro —, o que é exatamente o que se espera de uma sentinela cuja caixa ainda não existe.

| # | Cenário | Asserção | Vermelho de hoje | Por que falha por ausência real |
|---|---|---|---|---|
| [0] | CONTADOR DE CONTROLE | §10 | — | nasce verde |
| [1] | CONTROLE POSITIVO — bloco local com `enabled: true`, `resource` e `root` próprios, seguido de `update` | as três chaves ficam **byte-idênticas** | — | nasce verde: é o comportamento de hoje (§5.1), e M7 prova que a asserção mede |
| [2] | PARIDADE SCHEMA↔LEITOR — `root` com a expressão literal que o leitor aceita | valida contra **`$defs/forgeManifest`**, nunca contra a raiz | `FAIL [2]: /heavy_mutex/root must match pattern "^/"` sobre o valor que `heavy-mutex.sh` documenta como o único convergente | o `pattern` do schema é `^/` (§5.4) |
| [3] | ANTI-VACUIDADE DA PRÓPRIA VALIDAÇÃO | um documento com uma chave inventada sob `heavy_mutex` é **reprovado** | `FAIL [3]: a validação aprovou um documento inválido` | mede que `[2]` não caiu na armadilha de §5.5 |
| [4] | SUB-CHAVE NOVA NÃO CHEGA | consumidor com o bloco e sem `root`, template com `root`: o update **reporta** que a sub-chave nova não foi mesclada | `FAIL [4]: a sub-chave nova não chega e nada é dito` | o merge é por chave de topo (§5.2) e não há relato de sub-chave |
| [5] | REGISTRO — duas árvores com `(root, resource)` diferentes, e uma terceira com `enabled: false` | o `doctor` de qualquer uma das três informa o número de árvores e de famílias **que a própria fixture montou**, com a idade de cada entrada, e sai 0. O denominador é derivado em execução da lista de árvores que o cenário criou, nunca digitado na asserção — e ele **só é separável do parque da máquina** porque a raiz do registro está isolada pela alavanca de D10.1 | `FAIL [5]: nenhuma das três consegue ver as outras duas` | o registro não existe |
| [6] | O REGISTRO NÃO SE PARTICIONA | com `TMPDIR` diferente por árvore, `[5]` continua valendo | `FAIL [6]: o registro seguiu o TMPDIR e cada árvore viu só a si mesma` | idem [5] |
| [7] | SENTINELA — o gate não toca lock real **nem registro real** da máquina | o conjunto de arquivos sob a raiz de lock real **e** sob a raiz do registro real é idêntico antes e depois, delta vazio nos dois | `FAIL [7]: o gate criou lock ou entrada de registro fora da caixa` | nasce verde para o lock (`FORGE_HEAVY_MUTEX_TESTING=1` mais `FORGE_HEAVY_MUTEX_ROOT` já impõem a caixa) e **vermelho para o registro** enquanto a alavanca de D10.1 não existir — é o buraco que a revisão 1 apontou, e ele vira cenário em vez de ressalva |
| [7b] | A RECUSA DA ALAVANCA | com `FORGE_HEAVY_MUTEX_TESTING=1` e a raiz do registro vazia, o escritor **recusa** com o `rc 69` do idioma existente, em vez de escrever no registro real | `FAIL [7b]: a bancada sem caixa escreveu no registro da máquina` | a alavanca não existe |

---

## 9. Prova de mutação, com controle e recontrole

A coluna **Estado** distingue o que eu executei do que é hipótese. `MEDIDO` significa que rodei a mutação nesta bancada e colei a saída; `A MEDIR` significa que o alvo ainda não existe e a linha é hipótese, a confirmar no passo de mutação. A regra é explícita: quando o efeito medido divergir da linha, **quem está errada é a linha**. E a exceção é obrigatória: quando a mutação sair **no-op**, quem se corrige é o **cenário**, cujo sinal não discrimina — enfraquecer a linha nesse caso é registrar cobertura que não existe.

| # | O que mutar | Gate | O gate deve ACUSAR | Estado |
|---|---|---|---|---|
| M1 | devolver o bloco `PreToolUse` ao literal de um gancho | 1 | `[3]`, `[4]`, `[9]`, `[10]`; **não** pode derrubar `[1]` nem `[2]` | A MEDIR — se `[1]` cair junto, `[1]` está medindo a fiação e não o contrato de entrada |
| M2 | remover a guarda 2 (gancho sem entrada no manifesto passa a ser ignorado) | 1 | `[6]` e **só** `[6]` | A MEDIR |
| M3 | tirar as âncoras do matcher | 1 | `[8]` e **só** `[8]` | A MEDIR — e `[8]` é negativa de propósito: a positiva sozinha aprova um matcher que casa tudo |
| M4 | fazer a preservação valer para **todo** arquivo de `hooks/` que difira do template | 2 | `[2]` | **MEDIDO, com controle E recontrole** (§6 D1, revisão 2). Com `'hooks'` em `ENRICHABLE_DIRS`: `preservados: 1 arquivo(s) … = hooks/pre-tool-use/prevent-secrets-leak.sh`, `rc=0`, e `linhas com JWT depois do update = 0`. Restaurado byte a byte (`cmp -s` OK), a MESMA fixture: nenhuma linha de preservação e `linhas com JWT = 2`. O desfecho inverte, então a asserção mede |
| M5 | fazer a exceção governar também `rules/` | 2 | `[10]` | A MEDIR — mede que a onda não regrediu a issue #16 |
| M6 | trocar a guarda de principal pela igualdade de string crua (o idioma de `plugin-build.mjs`) | 3 | `[2]` e `[3]`; **não** pode derrubar `[1]` | **MEDIDO** contra o código de hoje: `strEq=false` nas três invocações, incluindo as duas legítimas (§4.4). É a mutação que prova que o fail-closed foi evitado |
| M7 | fazer o updater reescrever `heavy_mutex.resource` com o default do template | 4 | `[1]` e **só** `[1]` | A MEDIR — se `[2]` cair junto, `[2]` está lendo o `forge.yaml` da fixture em vez do schema |
| M8 | devolver o `pattern` do schema a `^/` | 4 | `[2]`; **não** pode derrubar `[3]` | **MEDIDO** contra o código de hoje: `/heavy_mutex/root must match pattern "^/"` nos dois consumidores que declaram a expressão |
| M9 | ancorar o registro de famílias em `$TMPDIR` | 4 | `[6]` e **só** `[6]` | A MEDIR — é a mutação que prova que `[6]` mede a âncora e não o conteúdo |
| M10 | remover a guarda de principal de `mermaid-to-drawio.mjs` | 3 | `[5]` e **só** `[5]` | **MEDIDO** contra o código de hoje: `1 file changed, 11 insertions(+), 243 deletions(-)` no próprio fonte, com `rc=0` |
| M11 | fazer o token desconhecido da quarta coluna do `hooks.manifest` do consumidor **cair para ativo** em vez de disparar a guarda 4 | 1 | `[6d]` e `[7e]`; **não** pode derrubar `[3]` nem `[6c]` | A MEDIR — é a mutação que prova que a guarda 4 mede o **desconhecimento** e não a ausência do arquivo. Se `[3]` cair junto, `[3]` está lendo o manifesto do consumidor em vez do conjunto ativo. É o dano exato de §D4.3.1: sob esta mutação, os dois ganchos que o `Axis.PadSimulator` retém com razão escrita voltam a ser fiados |

**Mecânica obrigatória, e é onde este programa já se enganou quatro vezes.** O controle vem da **árvore de trabalho**, nunca do `HEAD` — as mutações rodam **depois** da implementação, e um controle vindo do `HEAD` apagaria trabalho não commitado enquanto o `cmp -s` confirmaria alegremente a restauração. Se a mutação for por `perl -0pi`, use **aspas simples** e escape todo `$` do lado direito: com aspas duplas o `$` é variável do **perl**, vazia, e a mutação vira no-op enquanto o `cmp` confirma que o arquivo mudou (LDG-0164). Eu apliquei as minhas com `python3` lendo e reescrevendo o arquivo, com asserção de âncora (`assert old in t`) e `cmp -s` contra a cópia original — e **a asserção de âncora salvou uma delas**: a minha primeira tentativa com `perl -0pi` morreu com `syntax error at -e line 1, near "1:"` e o `cmp` de controle acusou `MUTACAO FANTASMA: arquivo nao mudou`, exatamente o padrão de LDG-0164 pego pela guarda em vez de pelo revisor.

As três propriedades que o implementador prova, uma a uma: a mutação **muda o comportamento** e não apenas os bytes; a restauração devolve o arquivo **byte a byte**; e a asserção derrubada **volta a passar** depois dela. Sem o recontrole a prova não vale — `feedback-mutacao-fantasma-restore` registra o caso em que um `restore()` quebrado deixou a mutação eterna e ninguém viu.

Os alvos de M1 a M3, M6 e M10 são arquivos **rastreados sob `template/`**, que é o que a sentinela de LDG-0175 existe para proibir. Não há contradição: a sentinela compara depois de o gate terminar, e o gate restaura antes de terminar. Se a restauração falhar, quem pega é a própria sentinela, no gate seguinte da suíte — e §4.3 é a prova viva de que o risco é real e de que a restauração precisa ser conferida, não presumida.

---

## 10. Contadores de controle, denominador fixo

Cada gate publica, e reprova em zero ou em divergência:

```
OK hook-wiring-derived/universo — 19 cenário(s) executado(s) de 19 declarado(s)
OK update-hooks-exceptions/universo — 14 de 14
OK module-import-side-effect/universo — 7 de 7
OK heavy-mutex-partition/universo — 9 de 9
```

Denominador **fixo e literal** no fonte (`DECLARADOS=N`), conferido contra o contador incrementado por cenário. Um cenário que deixe de rodar por `case` que não casa, por `continue` ou por variável vazia derruba o gate em vez de sumir do log. Denominador literal aqui é correto e não colide com a invariante 14, porque o universo é a lista de cenários que o próprio arquivo declara — fechado e conhecido em tempo de escrita, e é a única exceção que o plano-mestre admite.

**Os contadores que NÃO podem ser literais**, e cada um tem uma armadilha própria:

- `[3]` do Gate 1 compara **conjuntos** de nomes de gancho, nunca contagens, e o conjunto que ele compara é o dos ganchos **ativos** (D4.3), não o do diretório inteiro. O número de `.sh` em profundidade 1 de `pre-tool-use/` é quatro hoje (`ls -1 template/.forge/hooks/pre-tool-use/*.sh | wc -l` → `4`) e a ponte **não** o desloca, porque mora em `lib/` — mas o conjunto ativo varia por árvore por construção, já que a semeadura de `update` o deriva da fiação de cada consumidor. Qualquer literal aqui envelhece **dentro da própria onda**, e por dois motivos independentes.
- `[1]` do Gate 2 interpola do log daquela execução o número de linhas do relatório, e **quatro medições independentes deram quatro números**: `30` na minha primeira bancada (fixture git, `--no-plugin`), `29` na bancada da revisão 2 (fixture git, sem `--no-plugin` — o que trouxe a linha do plugin e tirou outras), `33` na Onda C (alvo não-git, dois `update`) e `34` na bancada do revisor. O número depende de flags, de o alvo ser repositório git, de o plugin ser instalado e do desfecho do `doctor` de pós-check. É o exemplo mais limpo desta rodada de por que a invariante 14 existe: qualquer um dos quatro, literalizado, estaria errado nos outros três ambientes.
- `[11]` do Gate 2 afirma **piso um de cada lado**, com o denominador derivado dos consumidores sintéticos da fixture.
- `[5]` do Gate 4 conta famílias e árvores da própria fixture, derivadas em execução da lista de árvores que o cenário montou. **A revisão 1 achou uma contradição real entre esta linha e a prosa de `[5]`, que fixava "três árvores e duas famílias" em literal; a prosa foi corrigida.** E a separabilidade desse denominador não é retórica: ela depende inteiramente da alavanca de D10.1 — sem caixa, o cenário lê entradas de outras árvores e de execuções anteriores da própria suíte, e o número deixa de ser da fixture.

**Chave de allowlist:** nenhuma. Os quatro universos são literais por construção e nunca são legitimamente vazios, então não há entrada a declarar em `empty-universe-allowlist.txt`.

---

## 11. Onde entra cada nível de teste

**Unitário.** `[5]` e `[6]` do Gate 1 (as guardas do gerador, sobre fixture de diretório), `[3]` a `[8]` do Gate 2 (a máquina de estados das exceções, sobre `bin/forge.mjs`), `[2]` e `[3]` do Gate 4 (a validação de schema).

**PBT — aplica-se, em um ponto, e só nele.** O espaço de entrada de verdade desta onda é o **parser do arquivo de exceções**: texto livre escrito por humano, com comentário, linha vazia, espaço à esquerda, caminho com espaço, `#` dentro da razão, acentuação, CRLF, sha em maiúsculas e minúsculas, e linha duplicada para o mesmo caminho. As propriedades, sobre entrada gerada por `template/.forge/scripts/lib/pbt.mjs` (harness zero-dep já entregue e coberto pelo `w121` — não se importa fast-check aqui, o contrato do template é zero dependência):

- **P1 — nenhuma entrada faz o parser aprovar em silêncio.** Toda linha não vazia e não comentada ou vira uma exceção bem formada, ou vira um erro **nomeado**. O terceiro desfecho — ser descartada sem menção — é o que `[8]` do Gate 2 proíbe, e o PBT é quem cobre o espaço que três exemplos escolhidos a dedo não cobrem.
- **P2 — idempotência de leitura.** Parsear duas vezes o mesmo texto produz o mesmo conjunto.
- **P3 — o comentário nunca vira dado.** Para todo texto de razão gerado, inclusive com `#` e com dois espaços consecutivos, o caminho e o sha extraídos são os mesmos que seriam extraídos com a razão vazia.

O universo do PBT tem contador próprio (`runs` do `forAll`, com `seed` impressa), porque um PBT que rodou zero casos aprova por não ter olhado.

**PBT — onde NÃO se aplica, com o motivo medido.** O bloco `PreToolUse` não tem espaço de entrada gerável: o universo é o conteúdo de um diretório, e o que varia é um conjunto finito e pequeno de nomes de arquivo. Gerar nomes aleatórios mediria o sistema de arquivos, não o gerador.

**Contrato.** `[2]` e `[3]` do Gate 4 (`forge.schema.json` é fronteira publicada e os seis consumidores validam contra ela), `[6d]`, `[7]`, `[7b]`, `[7c]`, `[7d]` e `[7e]` do Gate 1 (`hooks.manifest` é formato novo com **dois** adotantes instalados e **dois esquemas incompatíveis** — o `axis-fare-validator` opera 63 linhas e 6 declarações úteis em cinco colunas, o `Axis.PadSimulator` 38 linhas e 4 declarações em quatro colunas, medidos por `wc -l`, `grep -c '^[^#]'` e `awk -F'\t' '{print NF}'`; as 34 linhas que a revisão 1 atribuía a este arquivo são do `machinery-exceptions.txt`, e a troca foi minha), e a tabela de `rc` do `update`, que ganha códigos novos por D3 e D4.5 e cuja alocação é coordenada com a Onda C (§7).

**Integração.** `[9]` do Gate 1 é o `sync-adapters.sh` real, executado numa fixture, não o `.mjs` invocado direto — é a exigência de `rules/testing/gate-delivery-channel.md`. `[1]` a `[9]` do Gate 2 são o `bin/forge.mjs` real, rodando `update` contra fixture instalada por `init`, não a função de decisão isolada: o defeito de #125 é de **fiação de política**, e um teste unitário sobre a função de decisão nasceria verde.

**E2E — aplica-se em um ponto, e é `[1]` do Gate 1.** A prova de que o detector volta a bloquear tem de acontecer pelo protocolo do runtime, com a carga entrando pelo canal por onde ela entra em produção. É o único cenário desta onda em que o alvo é o comportamento observável de um agente, e é justamente onde a medição de campo dos quatro consumidores foi feita.

**E2E — onde NÃO se aplica, com o motivo.** Não há E2E roteirizável sobre o efeito de `[5]` do Gate 4 num parque real: exigiria três árvores vivas de consumidor numa máquina que a suíte não controla. A fronteira scriptável termina nas três fixtures sintéticas, e ela cobre a propriedade que importa — uma árvore consegue ver a família da outra.

---

## 12. Retrocompatibilidade — as seis árvores instaladas, medidas uma a uma

Esta é a seção que a onda mais precisa, e ela é sobre árvores que já estão instaladas.

**O que está fiado hoje, medido árvore por árvore — refeito na revisão 2, porque o censo da revisão 1 tinha cinco árvores em vez de seis e dois números errados.** O script está colado em §16.

```
$ bash fiacao.sh <as seis árvores>
axis-fare-validator   settings_rastreado=sim  comandos_fiados=7  ganchos_ptu_fiados=6  ganchos_ptu_no_disco=7
axis-go-cloud         settings_rastreado=sim  comandos_fiados=2  ganchos_ptu_fiados=1  ganchos_ptu_no_disco=3
Axis.PadSimulator     settings_rastreado=sim  comandos_fiados=3  ganchos_ptu_fiados=2  ganchos_ptu_no_disco=4
azim-crm              settings_rastreado=sim  comandos_fiados=1  ganchos_ptu_fiados=1  ganchos_ptu_no_disco=4
collatra              settings_rastreado=nao  comandos_fiados=1  ganchos_ptu_fiados=1  ganchos_ptu_no_disco=4
axis-device-platform  settings_rastreado=sim  comandos_fiados=5  ganchos_ptu_fiados=4  ganchos_ptu_no_disco=4
```

Três correções a mim na revisão 2, e nenhuma é cosmética. A primeira: eu tinha escrito `axis-fare-validator … ganchos fiados=7 ganchos no diretório=8`. São **7 `.sh` no diretório e 6 ganchos julgados** — o oitavo arquivo é o `hooks.manifest`, que não é `.sh`, e o sétimo `.sh` é a ponte, que nunca é entrada própria (§D4.2). A segunda: eu tinha omitido o `axis-device-platform` do censo inteiro. A terceira, e é a que muda a frase: eu escrevi "cinco de cinco têm mais ganchos no disco do que fiados", e o correto é **quatro de seis** — o `axis-fare-validator` e o `axis-device-platform` julgam tudo que têm (no primeiro, os 7 `.sh` do disco menos a ponte dão os 6 julgados).

**Quarta correção, da revisão 3, e ela é do instrumento e não do número.** O revisor rodou o `fiacao.sh` que eu tinha colado em §16 e obteve `7`, não `6`, na coluna `ganchos_ptu_fiados` do `axis-fare-validator` — e ele está certo: a linha `grep -o 'pre-tool-use/[A-Za-z0-9._-]*\.sh' | sort -u | grep -c .` conta **tokens únicos** do arquivo, e a ponte é o primeiro token de cada comando `argv`, então ela entra na conta. O `6` pretendido é o número de ganchos **julgados**, e para obtê-lo é preciso tomar o **último** token `pre-tool-use/` de cada comando, que é o gancho, e nunca o primeiro, que é a ponte. O script de §16 foi trocado pelo que produz o censo, e ele reproduz as seis linhas:

```
$ bash fiacao.sh <as seis árvores>
axis-fare-validator      rastreado=sim comandos=7 julgados=6 tokens_unicos=7 disco=7
axis-go-cloud            rastreado=sim comandos=2 julgados=1 tokens_unicos=1 disco=3
Axis.PadSimulator        rastreado=sim comandos=3 julgados=2 tokens_unicos=2 disco=4
azim-crm                 rastreado=sim comandos=1 julgados=1 tokens_unicos=1 disco=4
collatra                 rastreado=nao comandos=1 julgados=1 tokens_unicos=1 disco=4
axis-device-platform     rastreado=sim comandos=5 julgados=4 tokens_unicos=4 disco=4
```

A coluna `comandos` conta **todo** `"command":` do `settings.json`, inclusive os de `SessionStart` e `SessionEnd`, e é por isso que o `axis-fare-validator` mostra 7 comandos para 6 ganchos de `pre-tool-use`: o sétimo é o `on-session-start.sh`. Deixar as duas colunas juntas é de propósito — separá-las é o que evita a confusão que produziu o `7` no lugar do `6`.

E a afirmação "quatro de cinco armaram a fiação à mão" está errada. O gerador de hoje emite **um** comando de `pre-tool-use` (§2.2), então armou à mão quem tem mais de um: `axis-fare-validator` (6), `axis-device-platform` (4) e `Axis.PadSimulator` (2). **Três de seis.**

**Quem já armou à mão ganha o que já tinha, e para de perdê-lo — mas por DOIS mecanismos diferentes, e a revisão 2 só conhecia um.** §2.2 mede que qualquer execução do gerador apaga a fiação armada à mão; §12 mede que três árvores têm exatamente essa fiação — `axis-fare-validator` (6), `axis-device-platform` (4) e `Axis.PadSimulator` (2). A frase que estava aqui dizia que a semeadura de D4.3 conservava as três. **Não conserva: ela alcança uma.** Medido em §D4.3.1: o `hooks.manifest` já existe no `axis-fare-validator` e no `Axis.PadSimulator`, e D4.3 diz em letra que arquivo já presente não é tocado — nessas duas o semeador **nunca roda**. A partição é esta, e cada metade tem o cenário dela:

- **`axis-device-platform` (4 ganchos fiados, sem `hooks.manifest`)** — alcançado pelo semeador: o `update` deriva a ativação do que já está fiado, ele conserva os quatro, e `[7b]` do Gate 1 é a asserção.
- **`axis-fare-validator` (6) e `Axis.PadSimulator` (2), que já têm o arquivo, em esquemas que o produtor não reconhece** — conservados pela **guarda 4** (§D4.5): o gerador para antes de escrever, o `settings.json` deles fica byte-idêntico, e a onda não entrega a derivação a eles até LDG-0178. `[6d]` e `[7e]` do Gate 1 são as asserções, e `[7e]` é o que impede a onda de trocar a fiação de campo por uma derivação lida errado.

Os dois mecanismos existem por razões diferentes e não são intercambiáveis: o semeador **entrega**; a guarda 4 **não danifica**. Onde os dois se aplicariam, vale a guarda 4, porque ela corre primeiro.

**Quem nunca armou nada não ganha três ganchos ativos no dia do upgrade.** `azim-crm` e `collatra` estão em um gancho fiado, com quatro no disco. Ativar os três restantes numa árvore existente é mudança de política, e o precedente do próprio repositório manda amaciar: o bloco `secrets` entra em `warn` e não em `block` num repositório que já existia, com a razão escrita em `bin/forge.mjs:467` — "chegar travando o time no primeiro dia é como um gate vira `--no-verify` de hábito".

**A revisão 1 derrubou a versão anterior deste parágrafo com razão: eu decidia o amaciamento e não entregava mecanismo, e o mesmo arquivo distribuído não pode produzir estados diferentes.** O mecanismo está em D4.3 e ele não vive na camada distribuída: o `hooks.manifest.default` é idêntico em toda árvore e não carrega ativação; quem difere é o **semeador**. `init` semeia tudo ativo, porque não há legado; `update` semeia derivando da fiação existente, e o que não estava fiado nasce **inativo e nomeado** pela guarda 3. Para o `azim-crm` e o `collatra` isso significa um ativo e três declarados-inativos, com uma linha por arquivo dizendo como ativá-los — que é o amaciamento com o silêncio removido.

**O `Axis.PadSimulator` é o caso que mostra por que a guarda 3 não é enfeite — e o campo chegou nela antes de mim.** Ele fia dois de quatro, e os outros dois estão **declarados como retidos no `hooks.manifest` dele**, com a razão medida escrita na linha: um portão invertido que lê o disco, e 28 falsos positivos estruturais, os dois com item de ledger nomeado (§D4.3.1). Sem ativação declarada, a derivação passaria a invocar os dois que faltam e o autor descobriria no dia do upgrade; com ela, os dois nascem inativos e nomeados. A diferença que a revisão 3 acrescenta é de crédito e de risco: a guarda 3 **não é invenção desta onda**, é o `estado` que o `Axis.PadSimulator` já opera; e o risco concreto não é o gancho nascer ativo por descuido do produtor, é o produtor **ler a coluna `retido:<razão>` como token desconhecido e resolvê-la para ativo**, que é o dano que M11 muta e que `[6d]` derruba. A mensagem de canal (Onda I) precisa carregar a lista de §12 por repositório de qualquer forma, porque a semeadura é irreversível na prática: uma vez escrito, o `hooks.manifest` não é mais tocado por maquinaria (`[7d]`), e onde ele já existe nem sequer é lido (`[7e]`).

**Quem tem conserto local em `hooks/`.** **Cinco dos seis** (medição de §6 D1: `preservaria > 0` em `axis-fare-validator`, `axis-go-cloud`, `Axis.PadSimulator`, `azim-crm` e `axis-device-platform`; só o `collatra` é zero). O `quatro` anterior contradizia a tabela do próprio documento. Depois da onda, o comportamento do arquivo **não muda** — continua sobrescrito —, mas o relatório passa a nomeá-lo e a oferecer a saída. E para três deles a razão do conserto some: o `prevent-secrets-leak.sh` local existe porque o do template é inerte, e §2.3 mede isso. Consertar o produto é o que transforma o conserto local em defasagem.

**Quem tem `machinery-exceptions.txt`.** Um de seis, com 34 linhas úteis — 8 sob `hooks/` e 26 sob `scripts/`. Depois da onda, as declarações vivas passam a ser honradas e as expiradas passam a **parar** o update. **Correção da revisão 2, e ela derruba uma frase minha:** eu escrevi que "o próximo `forge update` naquela árvore vai parar pelo menos uma vez". Medido contra o template de hoje, `declaradas=34 vivas=34 expiradas=0` (§3) — **não vai parar nenhuma vez.** O desfecho de expiração continua obrigatório, porque é a razão de o contrato existir e porque o template vai mudar esses arquivos algum dia, mas ele não tem testemunha de campo hoje e o cenário `[4]` do Gate 2 monta a expiração sinteticamente. Os outros cinco não têm o arquivo e caem em `[7]` do Gate 2: nada muda e nada é dito.

**Quem tem `heavy_mutex`.** **Três de seis** — corrigido na revisão 3: o `azim-crm` não tem o bloco (§5.3). Nenhum dos três tem a chave reescrita (§5.1) e isso não muda. O que muda: os **dois** que declaram `root: "${TMPDIR:-/tmp}"` deixam de estar em violação de contrato, e passam a poder validar o próprio `forge.yaml` contra `$defs/forgeManifest`. O `Axis.PadSimulator` continua reprovando por `stale_after_s`, que esta onda deliberadamente não declara — a fronteira está em §14 e a chave é de #137. O **único** com `enabled: false` e os **três** sem bloco nenhum não mudam de comportamento; os quatro passam a **aparecer no registro como não participantes**, que é a informação que faltava, e o registro é o único lugar em que "desligado por declaração" e "desligado por bloco ausente" deixam de ser indistinguíveis.

**Quem importa `sync-adapters.mjs`.** Ninguém, hoje: `grep -rn "import.*sync-adapters"` sobre `tests/`, `template/`, `bin/` e `installer/` devolve apenas menções em blobs do liaison. Dois gates o **invocam** por `node <caminho>` (`w112:62,69`) e vários pelo wrapper — os dois caminhos continuam funcionando, e `[2]` e `[3]` do Gate 3 existem exatamente para provar isso. **A resposta à pergunta que o mandato faz é negativa**: nenhum gate da suíte atual importa o módulo, então não há um segundo defeito por esse caminho. O que existe é a exposição futura, e ela é real — `check-secrets.sh:162` já importa `secret-scan.mjs` em produção.

---

## 13. Varredura da invariante 15 — gates existentes que esta onda toca, nominalmente

**Esta seção foi refeita na revisão 2. A da revisão 1 errava em três gates, deixava passar um segundo literal no mesmo arquivo e não via que o contrato bats roda em DOIS modos.** O que segue é a varredura corrigida, com o comando de cada linha.

### 13.1 O contrato bats roda em dois modos, e a asserção prescrita reprovava o código CERTO

**Terceira leitura deste arquivo, e a terceira achou coisa nova — o registro fica porque ele é o padrão que derrubou as três rodadas.** A revisão 1 nomeou um literal; a revisão 2 achou o segundo e os dois modos; a revisão 3 acha a **terceira asserção do mesmo teste**, que o revisor apontou e eu remedi. A lição de método está em §16: varrer o arquivo inteiro, asserção por asserção, em vez de varrer atrás do que a rodada anterior nomeou.

**A enumeração exaustiva do teste C5 de 172-179, asserção por asserção**, porque afirmar sobre "o literal de contagem" enquanto o teste tem quatro asserções é como este arquivo me enganou duas vezes:

```
$ awk 'NR>=172 && NR<=179' tests/snapshot/claude-contract.bats
@test "C5: settings.json is valid JSON and wires ONLY the worktree-guard (PreToolUse/Bash)" {
  python3 -m json.tool "$CLAUDE_DIR/settings.json" >/dev/null          ← [a] sobrevive
  grep -q "$HOOK_PATH_FRAGMENT" "$CLAUDE_DIR/settings.json"            ← [b] sobrevive
  grep -q '"PreToolUse"' "$CLAUDE_DIR/settings.json"                   ← [c] sobrevive
  grep -q '"matcher": "Bash"' "$CLAUDE_DIR/settings.json"              ← [d] MORRE sob D5
  wired=$(grep -c '"command":' "$CLAUDE_DIR/settings.json")
  [ "$wired" -eq 1 ]                                                   ← [e] MORRE sob D4
}
```

`[a]` afirma JSON válido, e a derivação continua emitindo JSON válido. `[b]` procura o fragmento de caminho do guarda de worktree (`HOOK_PATH_FRAGMENT`, definido em `:22` para `generated` e `:30` para `source`), e o guarda de worktree é `stdin-json`, fiado direto e ativo nos dois modos — sobrevive, e é a asserção que impede a derivação de simplesmente esvaziar o array. `[c]` procura a chave `"PreToolUse"`, que continua existindo.

**`[d]` é o bloqueador remanescente da revisão 3, e ele é meu.** `grep -q '"matcher": "Bash"'` casa o literal que `sync-adapters.mjs:233` emite hoje, e D5 fixa que **o matcher passa a ser ancorado** — §8.1 `[8]` justifica o vermelho de hoje exatamente por *"o matcher literal de hoje é `Bash`, sem âncora"*. Numa implementação fiel, o gerador passa a emitir `"matcher": "^Bash$"`, que **não contém** a string `"matcher": "Bash"`, e `[d]` fica vermelha em `generated` mode contra o código certo. Medido:

```
$ grep -rn matcher tests/                       # e também com -a, LDG-0177
tests/snapshot/claude-contract.bats:176:  grep -q '"matcher": "Bash"' "$CLAUDE_DIR/settings.json"
                                                # UMA linha em toda a suíte

$ awk 'NR>=170 && NR<=181' tests/snapshot/claude-contract.bats | grep -c 'skip\|MODE'
0                                               # o teste não tem guarda de modo, como 178

$ python3 -c "…json.dumps(indent=2)…"           # o formato que sync-adapters.mjs:246 emite
  "matcher": "Bash",                            # exatamente o literal que 176 procura
```

E a varredura da direção oposta, para saber se o literal vive em outro lugar: `grep -arn '"matcher": "Bash"' template/ plugin/ bin/ installer/ snapshot/` devolve **uma** linha, `snapshot/project-bootstrap/.claude/settings.json:5` — o snapshot congelado. É o que faz o conserto de `[d]` ser **por modo**, igual ao de `[e]`: em `source` o literal continua correto, porque o snapshot não muda; em `generated` ele tem de virar a afirmação de que o matcher do guarda de worktree **casa a ferramenta `Bash` por igualdade** e não por substring — que é a propriedade de D5 e não um literal.

Sem esse conserto, `[d]` derruba junto os três gates que invocam a suíte bats em `generated` mode (§13.2), exatamente como `[e]`. A definição de pronto de §17 dizia que `w12`, `w13` e `w14` dependiam **inteiramente** do conserto de 178 e 207; dependem também de 176, e a frase foi corrigida.

`tests/snapshot/claude-contract.bats` tem dois literais de contagem, não um:

```
$ grep -n 'wired.*-eq' tests/snapshot/claude-contract.bats
178:  [ "$wired" -eq 1 ]      ← C5 "settings.json … wires ONLY the worktree-guard"
207:  [ "$wired" -eq 3 ]      ← C5 "handoff.auto: true wires +2 Session hooks"
```

E o de 178 **não tem guarda de modo**. Medido:

```
$ awk 'NR>=170 && NR<=181' tests/snapshot/claude-contract.bats | grep -c 'skip\|MODE'
0
$ sed -n '14p' tests/snapshot/claude-contract.bats
  MODE="${CLAUDE_CONTRACT_MODE:-source}"
```

O default é `source`, e em `source` o alvo é o snapshot congelado:

```
$ ls snapshot/project-bootstrap/.claude/hooks/pre-tool-use/ | wc -l        → 4
$ grep -c '"command":' snapshot/project-bootstrap/.claude/settings.json    → 1
$ grep -n "settings.json" snapshot/MANIFEST.sha256
82:e878c807…  project-bootstrap/.claude/settings.json
```

O snapshot está sob `MANIFEST.sha256` como referência histórica congelada, e esta onda **não** o regenera. A asserção que a revisão 1 prescrevia — igualdade de conjunto entre os `.sh` do diretório e os comandos emitidos — **reprovaria em `source` mode contra a implementação correta**, porque o snapshot congelado tem 4 ganchos e 1 comando por decisão de contrato. Vermelho fabricado, e é o modo que `tests/run-all.sh:54` executa por padrão.

**O conserto tem de ser por modo, e é assim que ele entra na definição de pronto:**

- Em `source`: a asserção continua sendo o literal de hoje. O snapshot é estado congelado; afirmar sobre ele é afirmar sobre o passado, e ele não muda. O que muda é ganhar a guarda de modo explícita que ele nunca teve, para que a intenção pare de depender de o `-eq 1` coincidir com o snapshot.
- Em `generated`: as duas asserções viram derivadas — a de 178 pela igualdade de conjunto com os ganchos **ativos** (D4.3), a de 207 pelo **delta** de dois, que é o que aquele cenário protege e o que sobrevive a qualquer número de ganchos de conteúdo.

### 13.2 Três gates executam o contrato em `generated` mode, e a revisão 1 os liberou

```
$ grep -rn CLAUDE_CONTRACT_MODE tests/
tests/w14-adapters-gate.sh:87:CLAUDE_CONTRACT_MODE=generated CLAUDE_CONTRACT_TARGET="$T" \
tests/w13-init-gate.sh:72:CLAUDE_CONTRACT_MODE=generated CLAUDE_CONTRACT_TARGET="$T1" \
tests/w12-sync-gate.sh:32:CLAUDE_CONTRACT_MODE=generated CLAUDE_CONTRACT_TARGET="$TMP" \
```

Os três rodam a **suíte bats inteira**, e portanto **as três** asserções de C5 que esta onda toca — 176, 178 e 207 —, contra uma árvore gerada. (A revisão 2 escrevia "as duas"; 176 entrou na revisão 3.) Eu os classifiquei como "intocado", "intocado" e "tocado só no eixo de idempotência" olhando para outra linha de cada um. Os três ficam vermelhos por construção no instante em que a derivação de D4 emitir mais de um comando, e a definição de pronto de §17 exigia `w13` e `w14` "verdes sem edição" sem dizer que isso depende inteiramente de o conserto de §13.1 funcionar nos **dois** modos. **A dependência agora está escrita, e a ordem do passo 8 de §17 mudou: o bats é consertado ANTES da derivação, não depois.**

### 13.3 A tabela corrigida

| Gate | Linha / cenário | O que afirma | O que esta onda faz com ele |
|---|---|---|---|
| `tests/snapshot/claude-contract.bats` | **176** (`grep -q '"matcher": "Bash"'`), **sem guarda de modo** | matcher literal, sem âncora | **EXIGE AÇÃO, e é o bloqueador remanescente da revisão 3.** D5 ancora o matcher (`"^Bash$"`), que não contém a string procurada. Conserto **por modo**, como o de 178: em `source` o literal fica; em `generated` vira a afirmação de que o matcher casa `Bash` por igualdade e não por substring. Único `matcher` de toda a suíte (`grep -rn matcher tests/` → 1 linha). |
| `tests/snapshot/claude-contract.bats` | 178 (`-eq 1`), **sem guarda de modo** | contagem literal de `"command":` | **EXIGE AÇÃO, e o conserto é POR MODO** — §13.1. Em `source` o literal fica e ganha a guarda que nunca teve; em `generated` vira igualdade de conjunto com os ativos. |
| `tests/snapshot/claude-contract.bats` | 173, 174, 175 (as outras três asserções do mesmo teste C5) | JSON válido, fragmento de caminho do guarda de worktree, chave `"PreToolUse"` | **intocadas, e nomeadas de propósito** — §13.1 enumera as cinco asserções do teste uma a uma, porque duas rodadas seguidas eu afirmei sobre "o literal" de um teste que tem cinco. `174` é a que impede a derivação de esvaziar o array. |
| `tests/snapshot/claude-contract.bats` | 207 (`-eq 3`), guardado em `generated` | contagem literal com `handoff.auto: true` | **EXIGE AÇÃO — a revisão 1 nunca o nomeou.** Vira o **delta** de dois entre os dois estados. |
| `tests/w12-sync-gate.sh` | 32 | roda o contrato bats em `generated` mode | **EXIGE AÇÃO INDIRETA** — herda as **três** asserções de C5 que esta onda toca (176, 178 e 207). |
| `tests/w12-sync-gate.sh` | 21-27 | idempotência: dois `sync-adapters --adapter claude` produzem hash idêntico | **intocado por desenho, e é uma linha vermelha.** A derivação tem de ser determinística: ordem estável dos ganchos, agrupamento estável por matcher. Se este eixo ficar vermelho, a derivação não é determinística e o defeito é dela. |
| `tests/w13-init-gate.sh` | 72 (cenário `[5]`) | roda o contrato bats em `generated` mode | **EXIGE AÇÃO INDIRETA** — idem. A linha 38 (`[ -f settings.json ]`) essa sim é intocada, e foi a única que eu tinha olhado. |
| `tests/w14-adapters-gate.sh` | 87 (cenário `[7]`) | roda o contrato bats em `generated` mode | **EXIGE AÇÃO INDIRETA** — idem. A linha 21 (o wrapper executando) continua intocada. |
| `tests/w62-handoff-hook-gate.sh` | 26 (`COUNT1 -eq 1`) e 47 (`COUNT2 -eq 3`) — números de linha corrigidos na revisão 2 | contagem literal de `"command":` com `handoff.auto` desligado e ligado | **EXIGE AÇÃO — quebra por construção.** As duas viram derivadas: a primeira afirma "os ganchos ativos de `pre-tool-use`, e nenhum de sessão"; a segunda, "os mesmos mais `SessionStart` e `SessionEnd`". O delta continua sendo dois, e **esse** é o número que o cenário protege. |
| `tests/w112-liaison-session-gate.sh` | 62, 69 | `node "$T/…/sync-adapters.mjs"` direto, com `\|\| true` | **intocado, e é a testemunha de D6.** É o arranjo exato em que o idioma de string crua falharia (§4.4). O `\|\| true` esconderia a regressão, e é por isso que Gate 3 `[3]` a mede sem ele. |
| `tests/w112-liaison-session-gate.sh` | 53 | valida um `forge.yaml` contra `forge.schema.json` **raiz** | **intocado, e registrado como achado** — §5.5 mede que essa validação é vácua. Vira item de ledger; a asserção do Gate 4 aponta para `$defs/forgeManifest`. |
| `tests/w151-heavy-mutex-gate.sh` | 66-67 (`export FORGE_HEAVY_MUTEX_TESTING=1`), 1343 (`SCENARIOS_RUN -gt 0`) | mutex pesado; contador derivado, não literal | **intocado SE E SOMENTE SE o escritor do registro ficar fora de `heavy_mutex_acquire`** — D10.2. Medido: nem `schema` nem `pattern` aparecem no arquivo (`grep -c` → `0` nos dois), então D9 sozinho não o toca; mas o gate define `TESTING=1` sem a variável nova, e uma trava estendida dentro de `acquire` o derrubaria por construção. São **1348** linhas. |
| `tests/w154-heavy-mutex-yaml-root-gate.sh` | 52 (`env -u FORGE_HEAVY_MUTEX_ROOT -u FORGE_HEAVY_MUTEX_TESTING`) | exercita a própria trava de teste | **intocado pela mesma condição.** `schema` e `pattern`: `0` ocorrências. A revisão 1 declarava os dois como "a conferir pelo implementador", dizendo em letra que eu tinha lido os nomes e não os cenários; li agora, e o recorte correto é este. |
| `tests/w101-update-preserve-gate.sh` | 67 (`[4]`) | `WARN: drift local em scripts/handoff-gen.sh` | **intocado por esta onda; a Onda C o inverte.** D2 mantém `hooks/` sendo sobrescrito, o que preserva o universo do `[4b]` que a Onda C cria. |
| `tests/w101-update-preserve-gate.sh` | 35, 59, 73, 91 | `= <rel>`, `(preservado — customização local)`, `(tombstone pulado` para `rules/` | **intocado** — as linhas de exceção de D3 têm token próprio e distinto. |
| `tests/w153-upgrade-safety-gate.sh` | 44-45 (`[71]`) | `grep -qE "^const ENRICHABLE_DIRS = \[[^]]*'templates'"` | **intocado** — D1 decide que `hooks` **não** entra em `ENRICHABLE_DIRS`, então a lista não muda. |
| `tests/w63-forge-update-gate.sh` | 168-181 (`[f]`) | destino do backup do `update` | **intocado** — a onda não muda destino de backup; consome o rótulo corrigido pela Onda C. |
| `tests/w139-secrets-gate.sh` | `[15]` | auto-varredura: **este repositório** passa no próprio detector | **EXIGE CUIDADO, não ação.** Nenhum literal com forma de credencial pode entrar nos gates novos nem nesta especificação; as cargas são construídas por concatenação em tempo de execução. E §2.4 acrescenta uma razão nova: o detector que essa auto-varredura usa é o `secret-scan.mjs`, o mesmo arquivo invisível ao `grep` de texto. |
| `tests/w200-readme-inventory-gate.sh` | `[6]`, linhas 258-272 | badge `gates-N passing` do `README.md` igual ao `find` de `tests/*-gate.sh` | **EXIGE AÇÃO.** Medido hoje: `grep -n "gates-" README.md` → linha 12, `gates-131`; `ls tests/*-gate.sh \| wc -l` → `131`. Os quatro gates novos levam a `135`, e o badge tem de ir junto **no mesmo commit**. |
| `tests/w200-readme-inventory-gate.sh` | `[1]`, linhas 53-75 | cada `<dir>/ (N)` do bloco de estrutura igual a `find <dir> -type f ! -name README.md \| wc -l` (recursivo) | **EXIGE VIGILÂNCIA.** Os sete conferem hoje, remedidos um a um: `agents 47`, `commands 56`, `contracts 5`, `skills 20`, `rules 50`, `schemas 27`, `scripts 136`. `hooks/` e `templates/` **não** aparecem no bloco, então a ponte em `lib/`, o `hooks.manifest.default` e o esqueleto de exceções não deslocam número nenhum. **Qualquer arquivo novo sob `template/.forge/scripts/` obriga a atualizar `scripts/ (136)` no mesmo commit** — e é por isso que D3 põe o leitor de exceções dentro de `bin/forge.mjs`, que não é distribuído. A guarda de piso do cenário é `>= 7` pares. |
| `tests/plugin-sync-gate.sh` | `[1]` | `plugin/forge` byte-idêntico ao regerado de `template/.forge/commands` | **EXIGE AÇÃO SE a onda documentar as exceções num comando.** Se `template/.forge/commands/harness/upgrade.md` mudar, roda-se `npm run build:plugin` no mesmo commit — **nunca** `build-plugin.sh`, que instala em `$HOME`. |
| `tests/w146-suite-invocation-gate.sh` | — | usa `template/.forge/scripts/tests/run-all.sh` como fixture | **intocado**, e citado aqui porque LDG-0175 é da mesma família de §4.3 e o implementador precisa ter os dois na cabeça ao escrever o Gate 3. |

### 13.4 As varreduras de ausência desta seção, refeitas com `-a` e com controle

```
$ CTL=tests/.l1-controle-positivo.tmp
$ printf 'machinery-exceptions\nhooks.manifest\npreToolUseWiring\n' > "$CTL"
  'machinery-exceptions': 1 arquivo(s) em tests/, dos quais 1 é o controle plantado → reais = 0
  'hooks.manifest':       1 arquivo(s) em tests/, dos quais 1 é o controle plantado → reais = 0
  'preToolUseWiring':     1 arquivo(s) em tests/, dos quais 1 é o controle plantado → reais = 0
$ rm -f "$CTL"
```

O controle sendo achado é o que autoriza os três zeros a significarem ausência. `SOBRESCRITO (não declarado)` não foi varrido como string porque o rótulo final é decisão de D2 coordenada com a Onda C (§7); a varredura dele é obrigação do implementador **depois** de o rótulo estar fixado, e ela entra na definição de pronto.

E a varredura que a invariante 15 exige na direção oposta — as strings que a **produção** hoje imprime e que D5 muda ao trocar `exit 1` por `exit 2` e ao meter a ponte no caminho. Nenhuma delas é afirmada por gate nem espelhada no plugin:

```
$ for s in 'POSSÍVEL VAZAMENTO' 'AWS Access Key ID detectada' '[HOOK]'; do
    grep -arlF "$s" tests/ plugin/ | grep -c .; done
0
0
0
$ grep -arlF "machinery-exceptions" plugin/ template/.forge/commands/ | grep -c .
0
```

Os três ganchos de conteúdo nunca foram invocados por ninguém (§2.3), então nenhum gate podia estar afirmando a saída deles — o zero aqui é consequência do defeito, não ausência de risco.

E a auto-varredura que o `w139` `[15]` vai fazer sobre **esta especificação**, adiantada aqui porque um documento reprovado no próprio detector do repositório trava a onda inteira. Ela roda com controle positivo, porque um `0` sem controle é a mesma armadilha de §1.2:

```
$ node scan3.mjs        # S.scanLines(path, texto), com a carga do controle montada em runtime
CONTROLE POSITIVO achado? true → AWS Access Key ID literal (valor mascarado, 20 car.)
achados na spec: 0
```

Na primeira tentativa eu chamei `scanLines(linhas, path)` com os argumentos invertidos — a assinatura real é `scanLines(path, text)`, `secret-scan.mjs:160` — e o controle **não** foi achado. O `0` sobre a spec veio idêntico nas duas execuções, uma cega e uma vidente. Registro porque é o quinto caso desta bancada em que o instrumento falhou produzindo um número plausível, e o que separou os dois foi o controle, não a leitura. O que a onda precisa vigiar é o **espelho**: se `template/.forge/commands/harness/upgrade.md` ganhar a documentação das exceções, `plugin/forge/commands/upgrade.md` sai do lugar e o `plugin-sync-gate` `[1]` morde. Hoje nenhum comando cita `machinery-exceptions`, então o espelho está limpo — e a linha de §13.3 diz o que fazer se deixar de estar.

### 13.5 Um achado de disciplina que eu produzi errando, na própria bancada da revisão 2

Rodando a fixture de M4 eu invoquei `node bin/forge.mjs update -y` **sem `--no-plugin`**, e o relatório trouxe:

```
plugin: 'forge' v0.14.0 → /Users/milton/.claude/skills/forge (56 comandos /forge:*)
```

O `update` de uma fixture sob `$TMPDIR` escreveu no `$HOME` do operador. A bancada que eu acreditava isolada não era. O harness já sabe disso — `bin/forge.mjs:856` diz em letra *"Pulável com `--no-plugin` (CI/testes não devem tocar `~/.claude`)"* —, e os seis gates existentes que rodam `update` todos passam a flag. Duas consequências para esta onda:

1. **Todo `init` e todo `update` dos quatro gates novos carrega `--no-plugin`**, sem exceção.
2. **A sentinela de cada um dos quatro gates se estende a `$HOME/.claude`**, não só à árvore de `template/`. LDG-0175 ensinou a olhar para o repositório; este caso mostra que o raio de dano de um gate não termina nele.

## 14. O que esta onda explicitamente NÃO faz

1. **Não põe `hooks/` em `ENRICHABLE_DIRS` nem em `PRESERVED_ON_DRIFT_DIRS`.** §6 D1, com a medição de congelamento e a tabela de exposição em que `hooks/git/pre-push` diverge do lock em **cinco** dos seis — o `quatro` que ficou aqui depois de §6 D1 já ter corrigido para cinco era contradição interna, apontada pelo revisor e remedida por mim com o `prepush.sh` de §16.
2. **Não mexe em `scripts/`.** É a Onda C, e §7 fecha a fronteira.
3. **Não corrige os literais `.forge.bak-N` das quatro mensagens de backup.** É a Onda C, P4. Esta onda **consome** o rótulo corrigido e depende dele em ordem.
4. **Não declara `heavy_mutex.stale_after_s` no schema.** `grep -rn "stale_after_s" template/` devolve vazio — a chave não tem leitor, e declará-la seria LDG-0151. Consequência escrita: o `forge.yaml` do `Axis.PadSimulator` continua reprovando contra `$defs/forgeManifest` por essa chave até #137 (L2) entregar o leitor.
5. **Não conserta o timeout de espera contra o teto de posse, nem o dono órfão.** São #137 e #144, em L2.
6. **Não conserta a validação vácua contra o schema raiz.** É falso-verde, da Onda D; §5.5 mede e §15 abre o item.
7. **Não põe guarda de principal nos outros 29 módulos que executam no import.** §15 abre o item com o predicado e o isolamento por módulo (sem ele a classificação não reproduz — §4.3); generalizar sem classificar cada sítio é o erro de LDG-0171.
8. **Não escreve em consumidor nenhum.** Toda leitura das seis árvores foi pura. O que a onda deve a eles é uma mensagem de canal, que é a Onda I — e ela precisa carregar, **por repositório**, três coisas: a lista de §12, porque a ativação de ganchos até então inertes é mudança de comportamento observável; para o `axis-fare-validator`, a obrigação de declarar `dispatch-file-hook.sh` com uma linha `dispatcher` antes de a guarda 2 passar a valer para ele (§D4.2 decidia isso e nenhuma seção registrava a obrigação — corrigido na revisão 3); e para o `axis-fare-validator` e o `Axis.PadSimulator`, que os manifestos deles **não serão lidos** por esta onda e que a convergência de esquema é LDG-0178.
9. **Não escolhe o esquema de coluna do `hooks.manifest` do consumidor, e não lê os dois que já existem.** §D4.3.1 mede os dois esquemas instalados; §D4.5 trata manifesto sem o marcador do produtor como terceiro estado. Escolher o esquema exige conversa com os dois adotantes pelo canal e está registrado **fora desta onda**, como LDG-0178. Enquanto ele não fechar, as duas árvores conservam a fiação que têm e não recebem a derivação.
10. **Não implementa descoberta de árvores irmãs.** D10 inverte a direção; a cobertura do registro é da população que executou pelo menos uma vez, e isso está declarado como limite, não escondido.
11. **Não muda o formato do `machinery.lock`.** O lock continua registrando o sha do template, e o arquivo de exceções é a **terceira** saída, ao lado dele — nunca uma reinterpretação dele.

---

## 15. Itens de ledger que esta onda abre

1. **`plugin-build.mjs:117` usa igualdade de string crua para detectar o principal**, e §4.4 mede que ela é falsa sob `$TMPDIR` no macOS. Não corrigido aqui porque o efeito dele no import é benigno (imprime uso e sai); mas o galho de CLI dele pode não disparar em fixture, e isso merece medição própria.
2. **Módulos de `template/.forge/scripts/lib/` que executam no import sem guarda de principal — 31 de 63 na medição de 2026-09-08.** Dois entram nesta onda (D6, D7: `sync-adapters.mjs` e `mermaid-to-drawio.mjs`, os dois da classe que mata o importador) e os demais precisam ser classificados sítio a sítio antes de qualquer generalização — é o erro de LDG-0171 e esta onda não o repete. **O item carrega o predicado, o isolamento e o critério, nunca só o número.** O `31` reproduz em seis execuções minhas e na do revisor; a partição em classes **não** reproduz sem isolamento por módulo, e isso é achado próprio da revisão 3: com a caixa compartilhada ela vale `21/7/3` no primeiro passe e `20/8/3` no segundo, porque um dos módulos cria `.forge/` dentro da caixa; com caixa nova por módulo ela é estável em `23/3/5` (morte = leitor não chega ao fim) ou `22/4/5` (morte = `rc≠0`). Predicado desta medição: cópia dos 63 para `$TMPDIR`, `cwd` em caixa vazia **recriada por módulo**, `await import()` em `try/catch`, caminho do módulo por variável de ambiente e nunca por `argv`, "executa" = `rc≠0` ou saída além das linhas do leitor; `node v26.0.0`, macOS. O leitor está colado em §16.
3. **O schema raiz de `forge.schema.json` não tem `$ref` para `$defs/forgeManifest`**, e validar contra ele é vácuo — `tests/w112-liaison-session-gate.sh:53` faz exatamente isso. Falso-verde, da família da Onda D.
4. **`heavy-run.sh:176` adquire o mutex incondicionalmente enquanto o `pre-push:242` só adquire com `enabled: true`.** Dois caminhos de participação do mesmo repositório discordando sobre uma chave de configuração; medido por leitura, não por execução.
5. **O merge do `forge.yaml` é por chave de topo e nenhuma sub-chave nova jamais alcança um consumidor que já tem o bloco** (§5.2). O cenário `[4]` do Gate 4 faz o update **relatar** isso, o que fecha o silêncio; fechar a lacuna em si é decisão de produto maior.
6. **Uma varredura de efeito colateral de import que reusa a caixa mede o resíduo tanto quanto o módulo** (§4.3). Medido nesta bancada: a mesma cópia dos 63 módulos, o mesmo leitor, dá `21/7/3` no primeiro passe de uma caixa compartilhada limpa e `20/8/3` no segundo passe da mesma caixa, porque pelo menos um dos módulos cria `.forge/` dentro dela. Com caixa nova por módulo a classificação para de se mexer. O item é de **método de medição**, não de produto, e ele explica de uma vez as três partições divergentes que três rodadas de revisão produziram sobre o mesmo universo.

**E um item que esta onda NÃO abre porque já está aberto, e do qual ela depende em letra: LDG-0178** — o esquema de coluna do `hooks.manifest` do consumidor, escrito duas vezes em campo, em formatos incompatíveis, antes de o produtor chegar (§D4.3.1). A dependência é nominal e tem consequência declarada: enquanto ele não fechar, `[6d]` e `[7e]` do Gate 1 afirmam que o produtor **não lê** os dois manifestos instalados e que as duas árvores conservam a fiação delas, e §14 item 9 registra que a escolha não é feita aqui.

---

## 16. Varredura da invariante 19 — os comandos que esta spec prescreve

**Executados por mim, com a saída colada ao lado do número:** o `forge init` e os `forge update` das fixtures de §2.1 (sem lock e com lock), §5.1 (bloco local preservado), §5.2 (bloco ausente mesclado) e §6 D1 (as duas montagens de M4, com controle e recontrole); as três montagens de entrada do gancho em §2.3; o `--dry-run` de §2.1; o import instrumentado de §4.2, com o manifesto de `sha256` da árvore antes e depois; a varredura dos 63 `.mjs` de §4.3, remedida na revisão 2 com predicado escrito e remedida de novo na revisão 3 com caixa nova por módulo, dois passes por isolamento e dois critérios de morte; as duas instrumentações de `sync-adapters.mjs` de §4.4, com restauração conferida por `cmp -s`; a validação contra `$defs/forgeManifest` por wrapper de §5.4; o censo de `heavy_mutex` das seis árvores; o `check-secrets.sh` contra fixture com carga concatenada de §2.4, e o censo de `secrets.enforce` das seis árvores; a auditoria de arquivos invisíveis ao `grep` de §1.2 e §2.4; as sete varreduras de ausência de §1.2, cada uma com controle positivo plantado e conferido; o censo de exposição, o de `pre-push` e o de fiação de §6 D1 e §12; a classificação das 34 exceções de §3; as varreduras de `tests/` de §13, inclusive as de `CLAUDE_CONTRACT_MODE`, as duas de `wired.*-eq`, as contagens do snapshot, o badge do `README.md` e as sete contagens do bloco de estrutura; e a contagem de `/var/folders/*/*/T` de D10.

**Acrescentados na revisão 3, todos por leitura pura ou por bancada sob `$TMPDIR`:** a enumeração asserção por asserção do teste C5 de `claude-contract.bats` (172-179) e a varredura de `matcher` em `tests/` e fora dela; o censo dos seis `hooks.manifest` (dois presentes, quatro ausentes), com `wc -l`, `grep -c '^[^#]'`, `awk -F'\t' '{print NF}'` e a leitura dos valores da quarta coluna de cada um; a leitura dos dois cabeçalhos, que é de onde saem o crédito recíproco e a ausência de marcador de formato do produtor; a contagem de `.sh` em profundidade 1 contra o número de declarações nas duas árvores, e a verificação de que `dispatch-file-hook.sh` só aparece em comentário no manifesto do `axis-fare-validator`; a leitura do contrato de entrada do `prevent-secrets-leak.sh` das duas árvores, que é o que mostra as duas soluções de campo; o `forge.yaml` do `azim-crm` com as chaves de topo, que derruba a linha de `heavy_mutex` que eu tinha; `_heavy_enabled` no `pre-push:237-241`, que é o que torna "bloco ausente" e `enabled: false` o mesmo estado; o `wc -l` do `w151`; o `expo.sh` e o `prepush.sh` refeitos sob `bash`, com prova de vida do instrumento; o `fiacao.sh` corrigido, com as seis linhas reproduzidas; e os quatro passes da varredura de import — dois com caixa compartilhada e dois com caixa nova por módulo — que explicam as três partições divergentes.

**Os quatro scripts de censo, colados porque a revisão 1 pediu o comando ao lado do número.** A revisão 2 escreveu aqui que eles "rodam com `export PATH=/usr/bin:/bin` no topo", como se o remédio fosse remontar o `PATH`. **A revisão 3 mediu que essa prescrição está errada, e mediu errando de novo:** rodei o `expo.sh` com exatamente esse `export` no topo, dentro do shell interativo do harness, que é `zsh`, e obtive `preservaria=13` nas **seis** árvores e `0 de 6 divergem` no `prepush.sh` — os mesmos números idênticos e plausíveis da quarta armadilha, agora **causados** pela linha que existia para evitá-la. A razão é que o `zsh` mantém tabela de hash de comandos e ela envelhece quando o `PATH` muda no meio da sessão; `shasum`, `cut`, `awk` e `basename` deixaram de ser encontrados, com as mensagens indo para o `stderr` e os contadores somando zero. Os dois remédios que sobrevivem à medição são outros, e são os que os scripts abaixo carregam: **rodar o censo sob `bash`**, com o arquivo em disco e `bash <script>`, nunca colando o corpo no shell interativo; e **abrir o script com uma prova de vida do instrumento** — `command -v shasum` e um `shasum` de teste impresso —, para que instrumento morto vire `rc 70` em vez de contador zerado. A prova de vida é a invariante 3 aplicada à bancada, e é o que separa "medi e deu zero" de "não consegui medir".

```
# expo.sh — exposição de hooks/ por consumidor (§6 D1). Roda sob `bash <arquivo>`, NUNCA colado num
# shell interativo com o PATH remontado — a tabela de hash do zsh envelhece e o instrumento morre em
# silêncio (medido na revisão 3, com preservaria=13 nas seis árvores).
command -v shasum >/dev/null && command -v cut >/dev/null || { echo "INSTRUMENTO MORTO"; exit 70; }
echo "prova de vida: $(printf x | shasum -a 256 | cut -d' ' -f1 | cut -c1-8)"
for d in "$@"; do
  L="$d/.forge/cache/machinery.lock"; [ -f "$L" ] || { echo "$d SEM LOCK"; continue; }
  tot=0; pres=0; limpo=0; ausente=0
  while read -r sha path; do
    case "$path" in hooks/*) ;; *) continue ;; esac
    tot=$((tot+1)); loc="$d/.forge/$path"; tpl="$TPL/$path"
    [ -f "$loc" ] || { ausente=$((ausente+1)); continue; }
    lsha=$(shasum -a 256 "$loc" | cut -d' ' -f1)
    tsha=""; [ -f "$tpl" ] && tsha=$(shasum -a 256 "$tpl" | cut -d' ' -f1)
    if [ "$lsha" != "$sha" ]; then pres=$((pres+1))
    elif [ -n "$tsha" ] && [ "$tsha" != "$sha" ]; then limpo=$((limpo+1)); fi
  done < <(grep '  hooks/' "$L")
  ...
done

# fiacao.sh — censo de fiação (§12). A versão da revisão 2 contava a PONTE como gancho e devolvia 7
# onde o censo diz 6 — o revisor pegou. O gancho julgado é o ÚLTIMO token `pre-tool-use/` do comando;
# o primeiro, quando há dois, é a ponte.
ptu_julgados() {
  awk -F'"' '/"command":/{n=split($4,t," "); last=""; for(i=1;i<=n;i++) if (t[i] ~ /pre-tool-use\//) last=t[i];
             if (last!="") {sub(/.*pre-tool-use\//,"",last); print last}}' "$1" | sort -u | grep -c .
}
rast=$(git -C "$d" ls-files --error-unmatch .claude/settings.json >/dev/null 2>&1 && echo sim || echo nao)
comandos=$(grep -ac '"command":' "$S")          # TODO comando, inclusive SessionStart/SessionEnd
julgados=$(ptu_julgados "$S")                    # ganchos de pre-tool-use que chegam a opinar
tokens=$(grep -ao 'pre-tool-use/[A-Za-z0-9._-]*\.sh' "$S" | sort -u | grep -c .)   # inclui a ponte
disco=$(ls -1 "$d/.forge/hooks/pre-tool-use"/*.sh 2>/dev/null | grep -c .)

# exc.sh — classificação das exceções (§3). Mesma prova de vida do expo.sh no topo.
command -v shasum >/dev/null || { echo "INSTRUMENTO MORTO"; exit 70; }
while read -r sha path _; do
  case "$sha" in ''|\#*) continue ;; esac
  t="$TPL/$path"; [ -f "$t" ] || { ociosa=$((ociosa+1)); continue; }
  [ "$(shasum -a 256 "$t" | cut -d' ' -f1)" = "$sha" ] && viva=$((viva+1)) || exp=$((exp+1))
done < "$F"

# leitor.mjs — varredura de efeito de import (§4.3). O caminho vem do AMBIENTE, nunca de argv.
# O laço que o invoca cria uma CAIXA NOVA por módulo (mktemp -d, cd, rm -rf ao fim): reusar a caixa
# contamina a classificação, medido na revisão 3.
import { pathToFileURL } from 'url';
console.log('__READER_START__');
try { await import(pathToFileURL(process.env.MOD).href); } catch (e) { console.log('__THROW__ ' + e.message.split('\n')[0]); }
console.log('__READER_END__');
```

**Declarados como propriedade, sem prescrever primitivo, porque eu não os executei:** a ponte `stdin` → `argv` de D5 e a prova de que ela discrimina; a declaração `dispatcher` da guarda 2 e a exclusão estrutural por `lib/` (D4.2 — o que eu medi foi o layout de campo, em duas árvores, e o precedente de `hooks/git/lib/`, não um gerador que os honre); o semeador de ativação de D4.3 e a guarda 3, nas três formas (`[7b]`, `[7c]`, `[7d]`); o marcador de formato e a guarda 4 de D4.5, com a recusa antes das guardas 2 e 3 (`[6d]`, `[7e]`) — o que eu medi foi que nenhum dos dois manifestos instalados carrega marcador do produtor e quais são os valores da quarta coluna em cada um; o sinal positivo de execução de `[9]` do Gate 1; a asserção *árvore intacta* de `[4]`, `[8]` e `[8b]` do Gate 2; o comportamento do matcher ancorado contra uma ferramenta cujo nome contém o de outra (`[8]` do Gate 1) — chegou pelo canal, o cabeçalho do `hooks.manifest` de campo o descreve com medição própria (*"uma chamada real de TodoWrite devolvia `rc=2` e a ferramenta não rodava"*), e eu **não** o reproduzi; o mecanismo de registro de D10, a alavanca de D10.1 e a recusa por `rc 69`; o conserto por modo do contrato bats (§13.1); e o efeito de M1, M2, M3, M5, M7 e M9.

**Um comando que esta spec deliberadamente NÃO prescreve:** copiar o `dispatch-file-hook.sh`, o `hooks.manifest` do `axis-fare-validator` ou o do `Axis.PadSimulator` para dentro do template ou de um gate. Eu os li para conhecer o desenho e dou o crédito; usá-los verbatim criaria dependência de árvores de consumidor que a suíte não controla e que não existem em CI. **A consequência dessa recusa não é de método, é de produto, e ela estava só aqui: ela mora agora em §12 e em §D4.3.1**, porque a razão original que eu tinha escrito — "o formato precisa ser reescrito com o cabeçalho do produtor" — supunha um formato só, e há dois, incompatíveis, com donos diferentes. O que os gates fazem no lugar de copiar é **reproduzir a forma** de cada esquema por escrita inline na fixture (`[6d]` e `[7e]`): cinco colunas com universo na quarta, quatro colunas com estado na quarta. Reproduzir a forma é obrigatório e não é cópia — sem isso, `[7d]` nasce verde sobre uma fixture no formato do produtor enquanto os dois adotantes reais seriam mal-lidos, que é exatamente o defeito que a revisão 3 derrubou.

**Seis armadilhas, e as duas últimas são da revisão 3 — a quinta eu evitei, a sexta eu não.** A primeira: a minha primeira mutação com `perl -0pi` era malformada e o `cmp` de controle a pegou como fantasma antes de qualquer linha de matriz ser escrita — a guarda funcionou porque estava no script, não na minha memória. A segunda: a primeira varredura de efeito de import mediu uma árvore **já reconciliada** e concluiu que `sync-adapters.mjs` era inofensivo; só a fixture com **edição pendente** revelou o dano. A terceira, e é a que me custou um arquivo rastreado: passar o caminho de um módulo como **argumento** de outro script põe esse caminho em `process.argv[2]`, que é exatamente onde `mermaid-to-drawio.mjs:16` procura o arquivo de entrada. A quarta: na bancada da revisão 2, o `PATH` sumiu dentro de uma substituição de processo e `shasum` deixou de existir; o contador devolveu `preservaria=13` em todas as seis árvores — um número idêntico e plausível, produzido por comando ausente. Só peguei porque as mensagens de `command not found` estavam no `stderr` que eu li. Um contador que soma zero quando o instrumento falha aprova por não ter medido, e é a invariante 3 aplicada à bancada em vez de ao gate.

A quinta, e ela é a que fecha a divergência de três rodadas sobre a mesma varredura: **importar os 63 módulos com o `cwd` na mesma caixa mede o resíduo tanto quanto o módulo.** Pelo menos um deles cria `.forge/` dentro da caixa, e a classificação dos importados depois muda por causa disso — `21/7/3` no primeiro passe, `20/8/3` no segundo, sobre a mesma cópia e o mesmo leitor. Evitei recriando a caixa por módulo, e aí a partição para de se mexer em dois passes consecutivos. O sinal de que havia algo errado não veio de nenhum dos números: veio de **dois passes seguidos do mesmo comando discordarem**, que é a verificação mais barata que existe e que eu não tinha feito nas duas rodadas anteriores.

**A sexta eu NÃO evitei, e ela é a quarta de novo, com o remédio no papel de causa.** A revisão 2 escreveu que os censos rodam com `export PATH=/usr/bin:/bin` no topo. Rodei assim, no shell interativo do harness, que é `zsh`: `shasum`, `cut`, `awk` e `basename` sumiram por hash envelhecida, e o `expo.sh` devolveu `preservaria=13` nas seis árvores enquanto o `prepush.sh` devolveu `0 de 6 divergem` — duas tabelas inteiras, plausíveis, uniformes e falsas, produzidas pela linha que existia para impedir exatamente isso. Só peguei porque as duas tabelas contradiziam a medição da revisão 2 que o revisor havia reproduzido. **A lição não é sobre `PATH`: é que uma linha de higiene copiada de uma bancada para outra é hipótese, não garantia, e o único jeito de saber é o instrumento se declarar vivo antes de contar.**

**E uma que eu NÃO evitei, na própria bancada da revisão 2:** rodei `forge update` sem `--no-plugin` e escrevi no `$HOME` do operador. Está em §13.5, com a consequência para os quatro gates novos.

## 17. Ordem de implementação e definição de pronto

1. **Vermelho primeiro, e observado.** Escrever os quatro gates completos, rodar cada um, e registrar a saída de cada cenário vermelho — inclusive a confirmação de que `[0]`/`[11]` do Gate 1, `[0]`/`[2]`/`[10]`/`[12]` do Gate 2, `[0]`/`[2]`/`[3]`/`[6]` do Gate 3 e `[0]`/`[1]` do Gate 4 nascem verdes, e por quê. `[7]` do Gate 4 é o único cenário desta onda que nasce **meio verde** — verde no eixo do lock, vermelho no do registro — e a saída dele precisa mostrar as duas metades separadas, senão a metade vermelha some dentro de um `FAIL` genérico. Vermelho que não foi visto não conta.
2. **A Onda C entra antes, ou junto.** §7. Sem o rótulo de backup de três valores, as mensagens de D2 nascem com o literal errado.
3. **Os ganchos e a ponte.** D5: `exit 2`, contrato de entrada, ponte. Os três ganchos de conteúdo passam a ser exercitáveis pelo canal real.
4. **O manifesto de duas camadas e a derivação.** D4, com as **quatro** guardas parando ou reprovando antes de escrever o `settings.json` — e a guarda 4 (D4.5) avaliada **primeiro**, senão a onda reprova o `axis-fare-validator` pela ponte não declarada antes de perceber que não entende o manifesto dele.
5. **A guarda de principal e as exportações.** D6 e D7, com a prova dos dois lados e o contrafactual de M6 colado.
6. **`bin/forge.mjs`.** D2 e D3: o relatório nominal por arquivo de `hooks/`, o leitor de exceções, os sete desfechos, os rc novos coordenados com a Onda C.
7. **O schema e o registro.** D9 e D10.
8. **Os gates existentes que a onda quebra — e este passo vem ANTES dos passos 3 e 4, não depois.** É a correção de ordem que a revisão 1 forçou, ampliada na revisão 3. `tests/snapshot/claude-contract.bats` precisa do conserto **por modo** de §13.1 nas **três** asserções, não em duas: o matcher literal de **176** (que morre quando D5 ancora o matcher, no passo 3), a contagem de **178** e a de **207** (que morrem quando D4 deriva a fiação, no passo 4). Em `source` os três literais ficam e ganham a guarda de modo que nunca tiveram; em `generated`, 176 vira a afirmação de casamento por igualdade, 178 vira igualdade de conjunto com os ativos e 207 vira o delta de dois. Sem isso, os três gates que o invocam em `generated` mode — `w12:32`, `w13:72`, `w14:87` — ficam vermelhos por construção **já no passo 3**, antes mesmo de a derivação existir. `tests/w62-handoff-hook-gate.sh` `26`/`47` entra junto, pela mesma razão. O vermelho de cada um é observado contra a implementação anterior.
9. **`README.md`.** Badge de gates, com o número que o `w200` calcula, no mesmo commit dos gates novos. E a linha `scripts/ (N)` **se e somente se** algum arquivo novo tiver caído sob `template/.forge/scripts/`.
10. **Mutação.** Executar M1 a M11, uma a uma, com restauração por checksum e recontrole, e colar a saída de cada uma no PR — inclusive as quatro que já têm contrafactual medido aqui, porque o contrafactual desta spec é sobre o código de hoje e o da matriz é sobre o código novo.
11. **Ledger e issues.** #125, #130, #131 e #142 fechadas com a evidência — e as fichas de #131 e #142 registram, em letra, que o defeito **não reproduzia como escrito** e o que foi entregue no lugar. Os cinco itens de §15 abertos.
12. **Suíte inteira, serializada pelo orquestrador.** Nunca em paralelo com gate manual.

**Definição de pronto:** os quatro gates verdes com os contadores fechando (`19`, `14`, `7` e `9` cenários); `claude-contract.bats` verde **nos dois modos**, com os **três** literais de `source` preservados sob guarda explícita (176, 178 e 207) e as três asserções de `generated` derivadas; `w62` verde com as duas asserções derivadas e o delta de dois preservado; `w12`, `w13` e `w14` verdes — e a definição registra em letra que os três dependem inteiramente do conserto do bats **nas três asserções**, porque os três o invocam em `generated` mode e porque 176 morre no passo 3 enquanto 178 e 207 morrem no passo 4; `w101`, `w63`, `w112` e `w153` verdes sem edição; `w151` e `w154` verdes sem edição, o que só vale enquanto o escritor do registro ficar fora de `heavy_mutex_acquire` (D10.2) — se o implementador o mover para lá, os dois entram na lista de gates a editar e o w151 tem 1348 linhas; `w139` verde, inclusive a auto-varredura `[15]` sobre esta especificação e sobre os gates novos; `w200` verde com o badge em `135` e a linha `scripts/ (N)` conferida; `plugin-sync-gate` verde depois do `build:plugin`, se algum comando tiver mudado; **todo `init` e todo `update` dos quatro gates novos carregando `--no-plugin`, e a sentinela de cada um cobrindo `$HOME/.claude` além de `template/`** (§13.5); a varredura de `tests/` pelo rótulo final de D2, feita depois de o rótulo estar fixado com a Onda C, com controle positivo; `bash -n` limpo em tudo que for tocado, sem `declare -A`, `${var,,}`, `${var^^}`, `mapfile` ou `readarray` (bash 3.2); as onze mutações com saída colada, controle e recontrole; nenhum literal de contagem de arquivo em asserção de gate; `git status --porcelain` vazio ao fim de cada gate; e o PR contra `develop`, sem uma linha de coautoria de IA.

---

## 18. Respostas ao veredito da revisão 1

O revisor reproduziu, com comando próprio, praticamente toda a espinha dorsal desta especificação, e as duas refutações de campo (#131 e #142) se sustentaram. O que reprovou foram seis defeitos de desenho e cinco medições sem lastro. Nenhum foi refutado — os seis bloqueadores confirmaram-se sob remedição minha, e as cinco medições ou foram remedidas com comando colado ou saíram. Abaixo, um a um, com o que mudou no documento.

### Os seis bloqueadores

**Bloqueador 1 — vermelho fabricado e varredura incompleta no contrato bats. CONFIRMADO, e era pior do que ele descreveu.** Remedi: o teste de 178 não tem guarda de modo (`grep -c 'skip\|MODE'` nas linhas 170-181 → `0`), o default é `source` (`sed -n '14p'`), o snapshot tem 4 ganchos e 1 comando, e está sob `MANIFEST.sha256:82`. A asserção que eu prescrevia reprovaria em `source` contra a implementação correta. O segundo literal existe e eu nunca o nomeei: linha 207, `-eq 3`. §13.1 é nova e o conserto passou a ser **por modo**; §17 moveu o passo 8 para antes do passo 4.

**Bloqueador 2 — a varredura da invariante 15 libera três gates que ela mesma quebra. CONFIRMADO.** `grep -rn CLAUDE_CONTRACT_MODE tests/` devolve `w14:87`, `w13:72` e `w12:32`, e os três rodam a suíte bats inteira. Eu tinha olhado a linha 38 do `w13` e a 21 do `w14`, que de fato são intocadas, e concluído sobre o gate a partir de uma linha só. §13.2 e §13.3 são a varredura corrigida; a definição de pronto agora diz em letra que os três dependem do conserto do bats.

**Bloqueador 3 — a ponte mora dentro do universo que o gate afirma. CONFIRMADO, e a saída veio de duas medições.** A primeira é o precedente que o revisor apontou e eu não tinha invocado: `template/.forge/hooks/git/lib/` existe, tem dois scripts e é chamado pelo `pre-push:37` via `HOOK_LIB_DIR`. A segunda é de campo: o `axis-fare-validator` tem **7 `.sh` no diretório e 6 entradas fiadas**, e a ponte aparece como primeiro token do comando de cada gancho `argv`, nunca como entrada própria. §D4.2 é nova: a ponte do produtor vai para `lib/` (regra estrutural, guarda 2 incondicional) e a base instalada declara a sua como `dispatcher` (regra declarativa). Sem a segunda metade, a onda reprovaria no primeiro `sync` exatamente o consumidor que resolveu o problema antes do produtor.

**Bloqueador 4 — o amaciamento de §12 não tem mecanismo e contradiz `[3]`. CONFIRMADO, e o argumento dele estava certo em cheio:** o mesmo arquivo distribuído não pode produzir estados diferentes. §D4.3 é nova. A ativação sai da camada distribuída e vai para o `hooks.manifest` do consumidor, que nunca é distribuído; quem difere não é o arquivo, é o **semeador** — `init` semeia tudo ativo, `update` semeia derivando da fiação que a árvore já tem, e o arquivo, uma vez escrito, não é mais tocado. E `[3]` mudou: a igualdade de conjunto é com o conjunto **ativo**, com a guarda 3 impedindo que "inativo" vire silêncio. Isso conserta de quebra um dano medido em §2.2 — as três árvores que armaram fiação à mão param de perdê-la.

**Bloqueador 5 — o registro de D10 não tem alavanca de isolamento. CONFIRMADO.** `heavy-mutex.sh:130-131` prende `FORGE_HEAVY_MUTEX_TESTING=1` a `FORGE_HEAVY_MUTEX_ROOT`, e essa trava governa a raiz do lock. §D10.1 acrescenta a alavanca com o mesmo idioma de asserção positiva e a mesma recusa `rc 69`, e explica por que ela não reintroduz a partição que D10 denuncia: a partição de D10 é acidental e silenciosa, a alavanca é explícita, exclusiva de bancada e ruidosa na ausência. §D10.2 é o achado que a remedição trouxe e que o revisor não tinha: **o escritor do registro não pode morar em `heavy_mutex_acquire`**, porque `w151:66-67` exporta `TESTING=1` sem a variável nova e `w154:52` desnuda a trava de propósito — os dois ficariam vermelhos por construção, e o w151 tem 1348 linhas (o `1277` da revisão 2 caiu na revisão 3). `[7]` do Gate 4 passou a cobrir o registro e ganhou `[7b]`, a recusa da alavanca.

**Bloqueador 6 — §2.4 conclui o oposto do que a árvore faz. CONFIRMADO, e é a minha pior linha.** Rodei o gate contra fixture com carga concatenada e ele acusa: `WARN secrets/provider-token — 1 ocorrência(s): x/conf.yaml:1: AWS Access Key ID literal`. `check-secrets.sh:162` delega, `secret-scan.mjs:123` tem a regra dentro de `PROVIDER_TOKEN_RULES`, e `provider-token` é uma das quatro classes de `:224`. §2.4 foi reescrita como retratação. A remedição trouxe três coisas que o veredito não pedia e que melhoram o piso de severidade em vez de destruí-lo: o censo de `secrets.enforce` (**um de seis bloqueia, cinco avisam**), a linhagem (`secret-scan.mjs:3` diz que foi *extraído* do `prevent-secrets-leak.sh` — o harness tirou a inteligência do gancho e deixou o canal original inerte), e a razão pela qual a minha varredura mentiu duas vezes.

### O achado do orquestrador, aplicado

LDG-0177 — `secret-scan.mjs` invisível ao `grep` sem `-a` — não é só a causa do bloqueador 6; é uma regra de método que esta spec passou a carregar em §1.2. Varri o universo inteiro atrás de outros casos e há **exatamente um** arquivo-fonte rastreado nessa condição, e é justamente o leitor canônico de segredos. As sete afirmações de ausência da spec foram refeitas com `-a` e com controle positivo plantado; seis sobreviveram, uma caiu (a do bloqueador 6), e uma sobreviveu **com um achado a mais** — a varredura cega de §2.3 não via a menção a `prevent-secrets-leak.sh` dentro do `secret-scan.mjs`, que é a linhagem que hoje sustenta o argumento de D5.

### As cinco medições sem lastro

**Remediadas com comando colado: quatro.**

1. *Os 31 de 63 módulos que executam no import.* Remedida: `31 de 63` reproduz, com predicado escrito, `node v26.0.0`, caminho por variável de ambiente e nunca por `argv`. Repeti de uma caixa com `.forge/FORGE.md` para descartar sensibilidade ao `cwd`: `31` de novo. A partição em três classes que eu publiquei aqui (`18/10/3`) **caiu na revisão 3**, e a causa não era critério: era resíduo de caixa compartilhada — §4.3 tem a medição. O `24` da revisão 1 e o `20/8/3` do revisor são o mesmo instrumento em estados de resíduo diferentes.
2. *A tabela de exposição de §6 D1.* Remedida com o script colado, e **a coluna `lock=N` saiu** — não sustentava argumento e envelhecia. Achei de passagem por que o revisor e eu não convergíamos: o lock não fica em `.forge/machinery.lock`, fica em `.forge/cache/machinery.lock`. Duas das seis linhas estavam erradas (`azim-crm` é `3/3`, não `0/0`; `axis-device-platform` é `7`, não `6`), e a linha nominal também: **`pre-push` diverge em cinco dos seis, não em quatro.**
3. *O censo de fiação de §12.* Remedido com script colado, e tinha três erros: faltava uma das seis árvores, o `axis-fare-validator` é `7 .sh / 6 fiados` e não `7 fiados / 8 no diretório`, e "quatro de cinco armaram à mão" é **três de seis**.
4. *A mutação M4.* Remedida com **controle e recontrole** — com `'hooks'` em `ENRICHABLE_DIRS` o gancho defasado é preservado e a correção não chega (`JWT = 0`); restaurado byte a byte, a mesma fixture recebe a correção (`JWT = 2`). Deixa de ser medição só minha.

**Removida: uma.** A aritmética de campo de #131 ("30 sobrescritas, 24 vivas, 9 expiradas"). O revisor está certo que 24 + 9 = 33 ≠ 30, e eu repeti sem conferir. Não há como remedir daqui — descreve um upgrade de outra data, em outra árvore. Saiu, e no lugar entrou o que eu consigo medir: `declaradas=34 vivas=34 expiradas=0`, das quais 8 sob `hooks/` — número que **bate com o `preservaria=8`** da tabela de exposição, medido por caminho independente. E isso derrubou outra frase minha, em §12: o próximo `update` naquela árvore **não** vai parar por exceção expirada, porque não há nenhuma.

### As três ressalvas

- *`[5]` do Gate 4, literal na prosa e derivado em §10.* Corrigida: a prosa não fixa mais números, e §10 registra que a separabilidade do denominador depende inteiramente da alavanca de D10.1.
- *`w151` e `w154`, "a conferir pelo implementador".* Li os cenários. O revisor está certo que a fronteira é mais folgada — `schema` e `pattern`: zero ocorrências nos dois — e que D9 sozinho não os toca. Mas a remedição achou uma fronteira **mais apertada** do lado de D10, e ela virou §D10.2: o arranjo de `TESTING` nos dois gates é o que proíbe o escritor do registro de morar em `acquire`.
- *A retratação da abertura, conferida.* Registro que ela continua verdadeira depois de toda a bancada da revisão 2: nenhum arquivo rastreado foi tocado nesta rodada, e todas as mutações rodaram sobre cópias sob `$TMPDIR`.

### O que a revisão 2 acrescentou por conta própria

Três coisas que o veredito não pediu. O desfecho **8** de D3 (duas declarações para o mesmo caminho), procurado ativamente porque a invariante 17 exige e porque eu tinha apresentado sete como exaustivos — com o registro do nono candidato que procurei e descartei. A disciplina de `--no-plugin` e a extensão da sentinela a `$HOME/.claude` (§13.5), que eu descobri **errando** na própria bancada. E a quarta armadilha de §16: `PATH` vazio dentro de substituição de processo produziu um contador idêntico e plausível em todas as seis árvores, a partir de comando ausente — invariante 3 aplicada à bancada em vez de ao gate.

---

## 19. Respostas ao veredito da revisão 2

O revisor registrou que a revisão 2 é "substancialmente honesta" e reproduziu com comando próprio quase tudo que ela remediou — o contrato bats, os três invocadores em `generated`, o precedente de `hooks/git/lib/`, a retratação inteira de §2.4, o censo de arquivos invisíveis, as sete varreduras de ausência, as 34 exceções, a tabela de exposição linha a linha, os 31 de 63 e o inventário do `w200`. O que reprovou foram dois defeitos, um remanescente e um novo, e seis medições sem lastro. **Nenhum dos dois defeitos foi refutado: os dois se confirmaram sob remedição minha, e o novo era pior do que o veredito descreve.** Abaixo, um a um.

### O bloqueador remanescente

**A varredura da invariante 15 estava incompleta num terceiro ponto do mesmo arquivo. CONFIRMADO, e é a terceira rodada seguida em que este arquivo me pega.** Remedi: `tests/snapshot/claude-contract.bats:176` é `grep -q '"matcher": "Bash"'`, é a **única** ocorrência de `matcher` em toda a suíte (com `-a` e sem), o teste que a contém (172-179) não tem `skip` nem guarda de `MODE` (`awk 'NR>=170 && NR<=181' | grep -c 'skip\|MODE'` → `0`), e D5 ancora o matcher — `"^Bash$"` não contém `"matcher": "Bash"`. A asserção fica vermelha em `generated` mode contra o código certo e leva junto `w12:32`, `w13:72` e `w14:87`.

O que eu acrescentei além do que o veredito pediu, porque o padrão que me derrubou três vezes é sempre o mesmo: **§13.1 passou a enumerar as CINCO asserções do teste C5, uma a uma, dizendo qual sobrevive e por quê** — `173` (JSON válido), `174` (`HOOK_PATH_FRAGMENT`, que é a asserção que impede a derivação de esvaziar o array), `175` (`"PreToolUse"`), `176` (morre sob D5, no passo 3) e `178` (morre sob D4, no passo 4). Enquanto eu afirmava sobre "o literal de contagem" de um teste que tem cinco asserções, a varredura ia continuar incompleta por mais uma rodada. E o conserto de `176` é **por modo**, como o de `178`: medi que o literal existe fora de `tests/` em exatamente um lugar — `snapshot/project-bootstrap/.claude/settings.json:5` —, o que confirma que em `source` ele continua correto.

Consequências propagadas: §13.2 diz "as três asserções", não "as duas"; §13.3 ganhou duas linhas (a de 176 e a das três intocadas); §17 passo 8 passou a vir antes dos passos **3 e 4**, não só do 4, porque 176 morre no passo 3; e a definição de pronto deixou de dizer que os três gates dependem "inteiramente" do conserto de 178 e 207.

### O bloqueador novo

**A base instalada já tem `hooks.manifest`, em dois formatos incompatíveis, e D4.3 mandava nunca tocá-los. CONFIRMADO, e a remedição achou quatro coisas em vez das três que o veredito lista.** §D4.3.1 é nova e mede: `axis-fare-validator` com 63 linhas, 6 declarações e cinco colunas (a quarta é o **universo**: `.cs,.java`, `comando`, `*`); `Axis.PadSimulator` com 38 linhas, 4 declarações e quatro colunas (a quarta é o **estado**: `armado`, `retido:<razão>`); os outros quatro sem o arquivo.

As três consequências do veredito, e o que cada uma virou:

1. *§12 promete que a semeadura conserva 6, 4 e 2, mas em duas árvores o semeador nunca roda.* **Certo, e a frase caiu.** A partição correta está em §12: o semeador alcança **uma** das três (`axis-device-platform`, 4 ganchos, sem manifesto) e as outras duas são conservadas pela **guarda 4**, que é outro mecanismo com outra razão — o semeador entrega, a guarda 4 não danifica.
2. *Um leitor da quarta coluna lê as duas árvores errado, e a spec não declara o desfecho.* **Certo, e o desfecho agora está declarado: não há leitor.** §D4.5 fixa que o gerador reconhece exclusivamente o esquema que ele mesmo semeia, marcado por uma linha de versão de formato que **nenhum dos dois arquivos de campo tem** (conferido nos dois cabeçalhos), e que manifesto sem marcador é **terceiro estado** — para antes de escrever, `settings.json` byte-idêntico, nomeia o arquivo e o LDG-0178, e nunca infere. Token desconhecido não cai para ativo: não cai para nada. `[6d]` e `[7e]` do Gate 1 são as asserções e `M11` é a mutação que prova que a guarda mede o desconhecimento.
3. *A guarda 2 reprova o `axis-fare-validator` e a obrigação não está registrada.* **Certo nas duas metades.** A ordem das guardas passou a ser normativa — a guarda 4 corre **antes** da 2 —, então aquela árvore nem chega a ser julgada pela ponte não declarada; e a obrigação de declarar `dispatch-file-hook.sh` com uma linha `dispatcher` está agora em §12 e em §14 item 8, que é onde ela fala com o consumidor.

**A quarta, que o veredito não tinha e que eu achei lendo os dois arquivos inteiros:** nem a **terceira** coluna é comparável entre as duas árvores. As duas declaram `prevent-secrets-leak.sh`, e o `axis-fare-validator` diz `argv` enquanto o `Axis.PadSimulator` diz `stdin-json` — porque os arquivos são diferentes. O primeiro manteve o gancho em `argv` e pôs uma ponte externa; o segundo reescreveu o gancho para ler o stdin quando `argv` não vem, com fail-closed medido em stdin vazio. **O campo resolveu o defeito de §2.3 pelos dois caminhos, e um deles é a alternativa que D5 descarta.** O descarte continua de pé como decisão de produto, mas deixou de ser apresentado como caminho único, e a existência de duas soluções independentes é a evidência mais forte de que o defeito é real.

E o que a onda **não** faz, em letra, porque o mandato é explícito: ela não inventa um terceiro esquema e não finge que o campo não escreveu nada. §14 ganhou o item 9; §15 registra LDG-0178 como item do qual esta onda **depende** em vez de item que ela abre; §16 corrigiu a frase que dizia "o formato precisa ser reescrito com o cabeçalho do produtor" — que supunha um formato só — e passou a exigir que os gates **reproduzam a forma** dos dois esquemas por escrita inline na fixture, o que não é cópia e é o que impede `[7d]` de nascer verde sobre uma fixture confortável.

### As seis medições sem lastro

**Remediadas com comando colado: quatro.**

1. *A linha do `azim-crm` no censo de `heavy_mutex`.* **Não reproduz, e o revisor está certo.** Medido por mim: aquele `forge.yaml` tem 67 linhas e as chaves de topo `version, harness, specs, graph, quality, handoff, ledger, autonomy, capabilities` — sem `heavy_mutex` e sem `secrets`. Logo `quatro de seis têm heavy_mutex` virou **três de seis**, e `os dois com enabled: false` virou **um**. §5.3 e §12 corrigidos. A remedição trouxe uma peça que aperta o argumento em vez de afrouxá-lo: `_heavy_enabled` (`pre-push:237-241`) devolve falso tanto para `enabled: false` quanto para bloco ausente, então para o `pre-push` **quatro de seis não participam de lock nenhum** — e o registro de D10 é o único lugar onde "desligado por declaração" e "desligado por bloco ausente" deixam de ser indistinguíveis.
2. *O `ganchos_ptu_fiados=6` que o `fiacao.sh` colado não produz.* **Certo: ele produz 7.** A linha contava tokens únicos, e a ponte é o **primeiro** token de cada comando `argv`. O gancho julgado é o **último**. Troquei o script por um que eu executei, e ele reproduz as seis linhas do censo (`6/1/2/1/1/4`). Acrescentei a distinção que faltava e que produziu a confusão: `comandos` conta todo `"command":`, inclusive `SessionStart`, e é por isso que o `axis-fare-validator` mostra 7 comandos para 6 ganchos.
3. *O `w151` tem 1348 linhas, não 1277.* **Certo.** Corrigido nos quatro sítios (§D10.2, §13.3, §17 e §18). O argumento — não é edição barata — sobrevive; o número não. As referências de linha do mesmo gate (`66-67`, `1343`) estão certas e as reconferi.
4. *`pre-push` em "quatro dos seis" contra a tabela corrigida.* **Certo, e era contradição interna do documento.** Remedi o `prepush.sh` sob `bash`, com prova de vida: `5 de 6` divergem do lock, só o `collatra` é idêntico. E a tabela de exposição, remedida: `preservaria > 0` em **cinco** das seis (`8/4/3/3/0/7`). Corrigi §14 item 1, §12 e a alternativa descartada de D2, que dizia "quatro dos seis consumidores parariam".

**Remediada com mecanismo, e é o achado que eu mais gosto desta rodada: uma.**

5. *A partição `18/10/3` contra os `20/8/3` do revisor.* Ele atribuiu a divergência a critério. **Não é critério: é resíduo da caixa**, e a medição está em §4.3. A varredura das duas rodadas importava os 63 módulos com o `cwd` na **mesma** caixa, e pelo menos um deles cria `.forge/` dentro dela. Medido: caixa compartilhada limpa dá `21/7/3` no primeiro passe e `20/8/3` no segundo — o número dele é o meu instrumento num estado de resíduo diferente. Com **caixa nova por módulo** a partição fica estável em `23/3/5` em dois passes consecutivos, e `22/4/5` trocando o critério de morte, com os três módulos que migram entre os critérios nomeados. O `31 de 63` é o único número robusto, e é o único que ficou. Virou item 6 de §15, como item de **método de medição**, e a quinta armadilha de §16.

**Sem remediação possível, e declarada como tal: uma.**

6. *M4, que o revisor não reproduziu.* Ele confirmou o estado de partida (`bin/forge.mjs:352`, sem `hooks`) e disse em letra que não montou a fixture. A medição continua sendo minha, com controle e recontrole colados, e continua sendo a única linha da matriz nessa condição. Não há como eu convertê-la em medição dele; o que eu posso fazer é o que já está escrito no passo 10 de §17 — a mutação roda de novo contra o código novo, e ali quem a executa é o implementador.

E os `37 diretórios /var/folders/*/*/T` continuam sem remedição de terceiro, como o revisor registrou. A propriedade que a spec usa é que o número é maior que um, e ela não depende do valor.

### As três ressalvas

- *§8.2 e §8.3 contradizem as próprias tabelas sobre quem nasce verde.* **Certo, e as duas frases estavam erradas.** §8.2 dizia três e são **quatro** (`[0]`, `[2]`, `[10]`, `[12]`); §8.3 dizia dois e são **quatro** (`[0]`, `[2]`, `[3]`, `[6]`). As tabelas e §17 estavam certos, e como o passo 1 de §17 manda registrar quem nasce verde, a prosa errada mandava o implementador procurar vermelho onde não há. Reconferi os quatro contadores declarados contra as tabelas, um a um, depois de acrescentar `[6d]` e `[7e]`: **19, 14, 7 e 9**.
- *O crédito de desenho ignora o `Axis.PadSimulator`.* **Certo, e a remedição mostrou que era pior do que ignorar: o crédito estava trocado.** O cabeçalho do manifesto dele diz em letra que a coluna `estado` *"É UMA ADIÇÃO NOSSA AO DESENHO ORIGINAL"* e credita o desenho ao `axis-fare-validator`. Ou seja, a ativação que D4.3 apresentava como decisão nova da revisão 2 foi inventada por ele, sobre o desenho do outro, e o produtor chega por último aos dois. §D4.3.1, §D4.2, §D4.4 e §12 nomeiam as duas árvores, e o layout `pre-tool-use/lib/` que §D4.2 escolhe já é o dele (`lib/pw-detector.sh`).
- *A frase de §16 sobre não copiar o manifesto está no lugar errado.* **Certo.** A frase ficou onde estava, porque é disciplina de método, mas a **consequência** foi para §12 e §D4.3.1, e a própria frase mudou: ela supunha um formato a reescrever, e há dois, com donos diferentes. No lugar da cópia, os gates **reproduzem a forma** de cada esquema inline (`[6d]`, `[7e]`).

### O que a revisão 3 acrescentou por conta própria

Três coisas que o veredito não pediu. A **guarda 4** e a ordem normativa entre as guardas (§D4.5), que é o que permite a onda conviver com LDG-0178 sem escolher por cima de dois adotantes. A **enumeração asserção por asserção** do teste C5 (§13.1), porque o defeito que me pegou três vezes não é o literal: é eu afirmar sobre "o literal" de um teste que tem cinco. E a **sexta armadilha** de §16, que é a quarta com o remédio no papel de causa: rodei os censos com o `export PATH=/usr/bin:/bin` que a revisão 2 prescrevia, sob `zsh`, e obtive `preservaria=13` nas seis árvores e `0 de 6 divergem` — duas tabelas uniformes, plausíveis e falsas, produzidas pela linha de higiene que existia para impedir exatamente isso. O remédio que sobrevive à medição é outro: rodar sob `bash`, a partir de arquivo, com o instrumento se declarando vivo antes de contar.
