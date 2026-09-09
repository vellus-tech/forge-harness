# Onda — o `detail` que some e o pagamento que não tem onde ser registrado

Data: 2026-09-08. Branch de especificação: `feat/fase1-dogfood-completo`. Alvo: `template/.forge/scripts/ledger-ops.sh`, subcomando `update` e um verbo novo. Ordinal alocado para o gate: **`w210`**.

Esta especificação lê do plano-mestre `docs/plans/2026-09-07-backlog-zero.md` (invariantes 1 a 19) e não do contexto de quem a invocou. Toda medição abaixo foi produzida nesta sessão, em fixture sob `$TMPDIR`, com `FORGE_ROOT` apontando para a fixture — nenhuma escrita tocou `.forge/ledger/` do repositório real, que carrega hoje 24 itens abertos.

## Sumário executivo

São dois defeitos no mesmo comando, e eles se alimentam. O primeiro: `update --detail` sobrescreve o campo por atribuição direta, e isso já destruiu 3.497 bytes de medição num único item. O segundo: não existe verbo para registrar que uma dívida foi parcialmente paga sem fechá-la, então a única forma de registrar progresso é reescrever o `detail` — que é exatamente o que apaga o histórico. A onda fecha os dois com uma decisão única de desenho: **o `detail` deixa de ser um campo que se substitui e passa a ser um registro que se acumula**, com uma porta nova que só acrescenta (`note`) e uma guarda na porta antiga que recusa a substituição destrutiva a menos que ela seja pedida em letra (`--replace-detail`). O status do item não é o veículo do progresso, e a razão é medida: usar `--status in-progress` tira o item da contagem `open` que a definição de pronto do plano-mestre usa como critério, o que é fechar por reclassificação silenciosa — a saída que o plano proíbe em letra.

## 1. O que eu medi

### 1.1 A bancada

Fixture criada por `mktemp -d` sob `$TMPDIR`, com `cp -R template/.forge` para dentro dela, `git init` mais um commit inicial (o script exige data de commit HEAD), e todo comando invocado como `env FORGE_ROOT="$T" bash "$T/.forge/scripts/ledger-ops.sh" …` com o `cwd` dentro da fixture. É o mesmo idioma de bancada do `w194` e do `w201`.

### 1.2 O censo das perdas — reproduzido, e depois ampliado

Reproduzi o censo do orquestrador com script próprio, comparando o `detail` de cada item entre commits consecutivos que tocaram `.forge/ledger/ledger.json` e contando os casos em que ele encolheu mais de 25% sem que o texto novo contivesse o antigo. **Os seis casos reproduzem exatamente, com os mesmos bytes e os mesmos percentuais** — nenhum número do relato precisou de correção.

Ampliei o denominador de 60 para **todos os 70 pares de commit** que a história do arquivo permite formar (são 71 commits, e o primeiro não tem par porque o arquivo não existe no pai), e o resultado não muda: continuam sendo exatamente 6 perdas. Isso é informação, não redundância — significa que as perdas se concentram em dois commits e não são uma corrente contínua de dano espalhada pela história.

| commit | item | antes | depois | perdido | status hoje |
|---|---|---|---|---|---|
| `d7d4ad46` | LDG-0021 | 4126 | 629 | 85% | open |
| `26ee11b6` | LDG-0010 | 3215 | 609 | 81% | open |
| `26ee11b6` | LDG-0029 | 3642 | 1497 | 59% | open |
| `d7d4ad46` | LDG-0003 | 2658 | 1515 | 43% | resolved |
| `d7d4ad46` | LDG-0008 | 2529 | 1737 | 31% | open |
| `d7d4ad46` | LDG-0029 | 5210 | 3642 | 30% | open |

Medi também a superfície inteira de mutações do campo, porque um censo que só conta perdas não diz qual é a taxa: das **92** mutações de `detail` em toda a história do arquivo, **68** preservaram o texto anterior como prefixo, **16** cresceram sem conter o texto anterior, **8** encolheram sem conter o anterior — e é dessas 8 que saem as 6 acima, quando se aplica o limiar de 25%. Vinte e quatro de noventa e duas mutações, ou 26%, não preservaram literalmente o texto que havia.

### 1.3 A convenção que já existe na prática, medida em vez de suposta

O relato dizia que os autores vinham concatenando à mão. Medi **como**, porque o formato da concatenação é decisão de desenho e imitá-lo errado seria inventar convenção nova com cara de convenção velha. De todas as mutações em que o texto anterior sobreviveu literalmente, **53 são append** (o texto antigo é prefixo do novo), **0 são prepend** e **0 colocam o texto antigo no meio**. Não há ambiguidade: a convenção de campo é acrescentar no fim.

O separador tem duas famílias, e as duas são reais. Uma vem do próprio script: o `resolve` já concatena, em `ledger-ops.sh:273`, com ` — Resolvido: ` ou ` — Wont-fix: `. A outra é a manual, e usa quebra dupla mais um cabeçalho em caixa alta com a data entre parênteses — colhidos do arquivo real desta rodada: `RE-MEDIDO EM 2026-09-05 (decisão do dono…`, `DECISÃO (2026-09-05, dono do repositório)`, `ADENDO DE ESCOPO (2026-09-05, decisão …)`, `REMEDIÇÃO E REVISÃO DE ESCOPO (2026-09-…)`, `PRIMEIRA FATIA ENTREGUE EM 2026-09-05`, `PRIMEIRA METADE ENTREGUE EM 2026-09-05`, `CORREÇÃO DE REGISTRO.`. Cinco dos 24 itens ativos carregam ao menos um desses blocos.

O ponto que importa para o desenho: **o `resolve` do próprio script já faz append e o `update` não faz**, e as duas portas moram no mesmo arquivo, a quarenta linhas uma da outra. O defeito não é a ausência de uma convenção; é uma convenção que existe em metade das portas.

### 1.4 O defeito 1, reproduzido na bancada

```
add   --detail "MEDIÇÃO ORIGINAL (2026-09-01): o defeito é X, medido em 42 sítios, e a razão pela qual o item existe está toda aqui."   → 116 bytes
update --detail "andei metade: fiz a fatia A."                                                                                        → OK update — LDG-0001 atualizado, rc 0
detail depois                                                                                                                          → "andei metade: fiz a fatia A."   (28 bytes)
```

Oitenta e oito bytes de medição destruídos, `rc 0`, `OK` na saída, nenhum aviso, nenhum backup. A linha responsável é `template/.forge/scripts/ledger-ops.sh:229`, dentro do heredoc node do `update`: `if (de) e.detail = de;`.

### 1.5 O defeito 2, reproduzido na bancada — e o achado que ele carrega

O verbo não existe: `ledger-ops.sh progress LDG-0001 --note "paguei metade"` responde `FAIL: comando desconhecido 'progress'`, e o mesmo vale para `note` e `append`. Até aqui é o relato confirmado.

O que a medição acrescenta, e que muda a decisão, é o comportamento de `--status in-progress`. Esse valor **já está no enum do schema** (`ledger.schema.json`, `status`: `open`, `planned`, `in-progress`, `resolved`, `wont-fix`, `promoted`) e o `update` **já o aceita** — só `resolved` e `wont-fix` são recusados, pela issue #78. Ou seja, o estado intermediário existe e está armado. Medi o que ele faz aos leitores, na mesma fixture, sobre o mesmo item:

| leitor | com `status: open` | com `status: in-progress` |
|---|---|---|
| `ledger-ops.sh status` (one-line, usado por `/forge:status`) | 1 ativo | **1 ativo** |
| `ledger-render.mjs` → `LEDGER.md` | ativo | **ativo** |
| `ledger-ops.sh list --status open` | lista o item | **`(nenhuma entrada)`** |
| definição de pronto do plano-mestre, que conta `open` | conta 1 | **conta 0** |

Os quatro leitores do mesmo arquivo não concordam. `status` e `render` usam o conjunto `CLOSED = {resolved, wont-fix, promoted}` e tratam `in-progress` como ativo; `list --status` é filtro de igualdade exata e não o vê; e a definição de pronto do plano-mestre — `node -e '…ledger.json…' | grep -c open → 0` — também não. Um agente que registrasse pagamento parcial mudando o status faria o item **sair do denominador do plano** sem que a dívida tivesse sido paga. Isso é fechar por reclassificação silenciosa, precisamente a saída que o plano-mestre proíbe em letra e que o harness já reprovou em LDG-0053 e LDG-0061.

E não é hipótese de laboratório: os consumidores **já usam** esses estados. Medido nos ledgers instalados hoje — `axis-go-cloud` tem 3 entradas `in-progress`, `axis-fare-validator` tem 8 `in-progress` e 1 `planned`, `azim-crm` tem 3 `planned`. São **15 entradas de campo** que qualquer contagem por `status == open` já não enxerga.

### 1.6 A superfície de retrocompatibilidade, medida

`ledger-ops.sh` está instalado em quatro consumidores, e os ledgers deles não são pequenos:

| consumidor | entradas | ativas | com `detail` acima de 800 bytes | com `detail` vazio |
|---|---|---|---|---|
| `axis-go-cloud` | 1405 | 1031 | 1133 | 63 |
| `axis-fare-validator` | 881 | 540 | 612 | 9 |
| `azim-crm` | 242 | 77 | 167 | 11 |
| `lionclaw` | 8 | 8 | 3 | 0 |
| `forge-harness` | 109 | 24 | — | 0 |

Mil novecentas e quinze entradas com `detail` substancial estão hoje atrás de uma porta que substitui sem perguntar, e elas chegam à árvore de cada consumidor no próximo `forge update`.

### 1.7 O contrafactual que decide o desenho: concatenar sempre derruba dois gates

Antes de escolher, executei a alternativa mais óbvia — trocar `if (de) e.detail = de;` por uma concatenação incondicional — numa cópia integral de `template/` e `tests/` sob `$TMPDIR`, e rodei os sete gates que tocam `ledger-ops` em três passadas: controle, mutado, recontrole com restauração por cópia do original verificada por `cmp`.

| gate | controle | mutado (concatena sempre) | recontrole |
|---|---|---|---|
| `w194-ledger-write-discipline-gate.sh` | rc 0 | **rc 1** | rc 0 |
| `w201-flag-como-valor-gate.sh` | rc 0 | **rc 1** | rc 0 |
| `w98-ledger-roundtrip-gate.sh` | rc 0 | rc 0 | rc 0 |
| `w203-ledger-render-bucket-gate.sh` | rc 0 | rc 0 | rc 0 |
| `w207-ledger-render-write-port-gate.sh` | rc 0 | rc 0 | rc 0 |
| `w157-ledger-integrity-gate.sh` | rc 1 | rc 1 | rc 1 |
| `w202-ledger-schema-conformance-gate.sh` | rc 1 | rc 1 | rc 1 |

Denominador declarado: **7 gates examinados, 5 exercitáveis nesta bancada, 2 derrubados pela mutação**. Os dois vermelhos nas três passadas são o terceiro estado, não um resultado: `w157` e `w202` leem `$WS/.forge/ledger/ledger.json`, isto é, o ledger real do repositório, e a bancada não tem um — eles não foram verificados aqui, e essa é a resposta honesta.

As duas quedas, nominalmente:

- `w194` cenário **[4]**, o controle do caminho feliz: `FAIL [4]: detail não gravado (got 'conteúdo inicial\n\ndetalhe novo do cenário 4')`. A asserção é igualdade exata, `[ "$got4" = "detalhe novo do cenário 4" ]`.
- `w201` cenário **[P3]**, o controle que existe para pegar o aborto mudo: `FAIL [P3]: update caminho feliz quebrou — got rc=0: OK update — LDG-0002 atualizado`. A asserção também é igualdade exata do `detail`.

Isto é a invariante 15 mordendo em forma de comportamento e não de string: **qualquer** mudança na semântica de `update --detail` derruba esses dois cenários, inclusive a que esta especificação escolhe. A consequência entra na definição de pronto: os dois gates são editados na mesma onda, nominalmente, e a edição é parte da entrega.

### 1.8 O que se perdeu de fato nas seis perdas

Antes de decidir se a onda restaura, medi se as reescritas foram reformulação preservadora ou perda pura. Para cada caso, extraí do texto antigo as frases com mais de 60 caracteres e contei quantas não aparecem no `detail` de hoje.

| commit | item | bytes perdidos | frases longas do texto antigo ausentes do `detail` de HEAD |
|---|---|---|---|
| `26ee11b6` | LDG-0010 | 2606 | 14 de 14 |
| `26ee11b6` | LDG-0029 | 2145 | 20 de 20 |
| `d7d4ad46` | LDG-0003 | 1143 | 10 de 10 |
| `d7d4ad46` | LDG-0008 | 792 | 11 de 11 |
| `d7d4ad46` | LDG-0021 | 3497 | 17 de 17 |
| `d7d4ad46` | LDG-0029 | 1568 | 20 de 20 |

**Oitenta e seis de oitenta e seis.** Nenhuma das seis foi reformulação: o texto anterior não sobrevive em nenhuma forma reconhecível. E cinco dos seis itens estão abertos hoje, entre eles LDG-0008, LDG-0021 e LDG-0029, que são justamente itens que as ondas H e G desta rodada precisam ler para decidir o que fazer.

## 2. Decisões fechadas

### Decisão 1 — o `detail` é registro que acumula, e a onda instala isso em duas peças, não em uma

A peça positiva é um verbo novo que só acrescenta. A peça negativa é uma guarda na porta antiga que recusa a substituição destrutiva. As duas são obrigatórias e a razão de serem duas está medida: um verbo novo sozinho não impede a próxima perda, porque ninguém é obrigado a usá-lo — as seis perdas foram cometidas por autores que conheciam a convenção de append e a aplicavam à mão em outros itens no mesmo dia. E uma guarda sozinha, sem verbo, transformaria a recusa num beco: o agente que quer registrar progresso seria recusado e não teria para onde ir.

**Alternativa descartada (a): `update --detail` passa a concatenar sempre, sem verbo novo.** Descartada por duas razões medidas. A primeira é que ela elimina a capacidade de **corrigir** um `detail`, e a correção é um caso real e legítimo deste ledger — LDG-0029 carrega literalmente o bloco `CORREÇÃO DE REGISTRO.` porque o item se contradizia entre título e detalhe, e sob concatenação incondicional a contradição teria de permanecer no arquivo para sempre, com a correção pendurada embaixo. A segunda é a §1.7: ela derruba `w194[4]` e `w201[P3]` sem oferecer nada em troca que a decisão escolhida não ofereça.

**Alternativa descartada (b): só o verbo novo, deixando `update --detail` exatamente como está.** Descartada porque o dano medido veio dessa porta e ela continuaria armada, com 1.915 entradas de `detail` substancial atrás dela nos cinco consumidores. O relato do dono é explícito ao chamá-la de armadilha; deixar a armadilha e acrescentar uma alternativa ao lado é documentação, não correção.

**Alternativa descartada (c): fazer o `update --detail` gravar, mas salvar o valor anterior num campo de histórico no JSON.** Descartada pelo custo de contrato, medido: o `ledger.schema.json` declara `additionalProperties: false` em cada entrada, o `w202-ledger-schema-conformance-gate.sh` valida o `ledger.json` **real** contra esse schema, e 2.645 entradas nos cinco ledgers instalados passariam a existir sob dois formatos. Campo novo é mudança de contrato para todo adotante, e o benefício — preservar o texto — já é obtido dentro do campo que existe.

### Decisão 2 — o verbo novo é `note`, com `--kind` de enum fechado e `--text` obrigatório

```
ledger-ops.sh note <LDG-NNNN> --kind progress|measurement|correction|decision --text "<txt>"
```

O enum é fechado e cada valor é lastreado num marcador que já existe no ledger real, medido em §1.3 — a onda **imita** a convenção de campo em vez de inventar uma:

| `--kind` | marcador gerado | de onde veio |
|---|---|---|
| `progress` | `PROGRESSO (<data>): ` | `PRIMEIRA FATIA ENTREGUE EM 2026-09-05` (LDG-0008), `PRIMEIRA METADE ENTREGUE EM 2026-09-05` (LDG-0140) |
| `measurement` | `MEDIÇÃO (<data>): ` | `RE-MEDIDO EM 2026-09-05`, `REMEDIÇÃO E REVISÃO DE ESCOPO (2026-09-…)` |
| `correction` | `CORREÇÃO DE REGISTRO (<data>): ` | `CORREÇÃO DE REGISTRO.` (LDG-0029) |
| `decision` | `DECISÃO (<data>): ` | `DECISÃO (2026-09-05, dono do repositório)`, `ADENDO DE ESCOPO (2026-09-05, decisão …)` |

`progress` é o verbo do pagamento parcial que o dono pediu, e os outros três existem porque o mesmo append serve a três usos reais que aparecem no arquivo — restringir o verbo a `progress` obrigaria quem quer corrigir um registro a escolher entre um rótulo mentiroso e a porta destrutiva.

O rótulo é **enum fechado, nunca texto livre**: um rótulo livre não é contrato, não é verificável por gate e produziria em dois meses a mesma variedade de marcadores manuais que hoje só um humano consegue reconhecer. Um `--kind` fora do enum reprova nomeando os quatro valores aceitos, no idioma de recusa que `resolve --status` já usa.

**Alternativa descartada: dois verbos, `progress` para pagamento e `note` para o resto.** Descartada porque dobra a superfície de parsing para expressar o que um parâmetro expressa, e porque o `--kind` obrigatório força a escolha explícita que o verbo separado apenas sugeria.

### Decisão 3 — o formato do bloco anexado imita a convenção de campo: append, separador de linha em branco, cabeçalho com data

O texto novo vai para o **fim** do `detail` — as 53 concatenações preservadoras medidas são todas append, e zero são prepend. Quando o `detail` corrente é não-vazio, o bloco é separado por uma linha em branco; quando é vazio, o bloco é o próprio `detail` e não há separador à toa. O bloco começa pelo marcador da Decisão 2, com a data.

A data é **a do commit HEAD**, obtida pela mesma `_require_git_date` que `add`, `update`, `resolve` e `promote` já usam, e nunca o relógio de parede — o cabeçalho do arquivo promete `created_at` = data do commit HEAD e trocar a fonte num verbo novo criaria duas noções de tempo no mesmo arquivo. Esta é a propriedade; o recorte do ISO-8601 para a forma de data é escolha do implementador, que a prova com o cenário `[7]`.

Medi o efeito do separador no renderizador antes de escolhê-lo, porque `ledger-render.mjs:78` faz `entry.detail.replace(/\n+/g, ' ')` e **achata** quebras de linha no `LEDGER.md`. O resultado, na fixture: `MEDIÇÃO ORIGINAL (2026-09-01): o defeito é X, medido em 42 sítios. PROGRESSO (2026-09-08): fatia A entregue; a fatia B continua aberta.` — uma linha só, com os dois blocos legíveis porque o marcador em caixa alta sobrevive ao achatamento. Isto não é regressão nem novidade: é exatamente o que o `LEDGER.md` já faz hoje com os cinco itens que carregam blocos manuais. `w203` e `w207` passaram sob a mutação de §1.7, que usava esse mesmo separador.

### Decisão 4 — `update --detail` ganha três desfechos, e o terceiro exige `--replace-detail`

A porta antiga não muda de nome nem de assinatura; ela ganha uma guarda. Os desfechos, e o critério é **preservação**, não tamanho:

1. **O `detail` corrente está vazio** — grava, como hoje. Não há o que destruir, e este é o caminho que o próprio `add` recomenda no `WARN` da linha 187 (`Complete com: ledger-ops.sh update <id> --detail "…"`). Nos consumidores há 83 entradas nessa situação.
2. **O texto novo preserva integralmente o `detail` corrente** — grava, como hoje. Nenhum byte se perde. É o caso pelo qual o orquestrador escapou hoje ao corrigir LDG-0177: ele reescreveu o detalhe inteiro incluindo a medição original dentro do texto novo, e escapou pela redação, não pelo comando. Sob esta decisão o comando passa a garantir o que a redação garantiu por acaso.
3. **O texto novo não preserva o `detail` corrente** — **recusa**, com `rc` diferente de zero, sem gravar nada, nomeando os dois caminhos legítimos: `note` para acrescentar e `--replace-detail` para substituir de propósito. É o único desfecho que muda o comportamento de hoje.

`--replace-detail` é flag booleana, sem valor, no idioma de `--by-priority` que o `list` já usa, e entra em `UPDATE_FLAGS` para que o teste de pertencimento de `forge_reject_flag_as_value` a reconheça. Quando passada, a substituição ocorre e o script **emite em stderr quantos bytes do texto anterior foram descartados** — a substituição continua possível e deixa de ser silenciosa. A forma da recusa é a mesma que a issue #78 já instalou duas vezes neste arquivo para `add --status resolved` e `update --status resolved`: fecha a porta errada e aponta a certa, em vez de tentar adivinhar a intenção.

**Alternativa descartada: recusar toda substituição, sem flag de escape.** Descartada porque tornaria impossível corrigir um `detail` errado pela porta do harness, e a saída de quem precisasse fazê-lo seria editar o `ledger.json` à mão — que é pior por dois motivos, o segundo dos quais é que a edição manual não re-renderiza o `LEDGER.md` e produz a divergência que `w98` e `w203` existem para pegar.

### Decisão 5 — o pagamento parcial **não** mexe no `status`, e quem fecha continua sendo o `resolve` no arquivamento

`note --kind progress` grava o progresso e **preserva o `status`** byte a byte. Não há status novo, não há transição automática para `in-progress`, e a razão está medida em §1.5: mudar o status tira o item da contagem `open` que a definição de pronto do plano-mestre usa, e um item que ainda tem dívida sairia do denominador sem ter sido pago. Quem conta `open` hoje continua contando exatamente o mesmo conjunto depois desta onda — essa é a garantia, e ela é verificável.

**Alternativa descartada: criar um status `partially-paid` ou passar a usar `in-progress` como parte do verbo.** Descartada pelo custo de contrato medido: seriam quatro leitores a reconciliar (`status`, `render`, `list --status`, definição de pronto) mais os gates que os afirmam, mais 15 entradas de campo já existentes nesses estados em dois consumidores, e o benefício seria uma distinção que o marcador `PROGRESSO (<data>)` no `detail` já dá — com a diferença de que o marcador é **gerado pelo script em formato fixo**, e portanto legível por gate sem heurística sobre prosa humana, que é a classe de erro de LDG-0062 e LDG-0140.

### Decisão 6 — `note` sobre item já terminal é aceito, com aviso

Anotar um item `resolved` é legítimo — "voltou a reproduzir em tal versão" é informação que pertence ao item e não a um item novo — e `note` não muda status, então não há o fechamento duplo que a Decisão 12 da Onda E recusa no `resolve`. O aviso vai para stderr, no idioma do `WARN` da linha 187, e não muda o `rc`. Registro a fronteira porque as duas decisões parecem opostas e não são: a Onda E recusa **refechar**, esta onda permite **anotar**.

### Decisão 7 — o `resolve` não é tocado

O `resolve` continua concatenando com ` — Resolvido: ` / ` — Wont-fix: `, exatamente como hoje, e a onda não unifica o separador dele com o da Decisão 3. Duas razões. A primeira é de escopo: `resolve` é território da Onda E, que já especifica a recusa de re-resolve sobre entrada terminal. A segunda é de evidência: a Onda E prova o nascimento com `detail` vazio das 8 entradas de harvest **pela ausência do ` — ` antes do `Resolvido: `**, e mudar o separador destruiria a prova dela dentro da onda seguinte.

### Decisão 8 — nenhum campo novo no `ledger.json` e nenhuma mudança no `ledger.schema.json`

Consequência direta da Decisão 1(c). O contrato com os cinco consumidores fica intocado, nenhum ledger instalado precisa migrar, e `w202` continua validando o ledger real contra o mesmo schema.

### Decisão 9 — as seis perdas são restauradas, e o procedimento entra na onda

As seis são recuperáveis por `git show <commit>^:.forge/ledger/ledger.json`, cinco dos seis itens estão abertos, e §1.8 mostra que a perda é integral e não reformulação — 86 de 86 frases longas ausentes. Restaurar custa seis blocos de texto que já existem no histórico, e não restaurar deixa cinco itens abertos sem a medição que os sustenta, o que é a forma de item que o próprio harness reprova.

A restauração é feita **pela maquinaria que a onda cria**: `note --kind correction` com o texto recuperado, o que preserva o `detail` atual, acrescenta o antigo com marcador datado e serve de prova de ponta a ponta de que o verbo novo funciona sobre o dado real. Ela roda **uma vez, pelo orquestrador, na árvore real, depois de a suíte estar verde** — nunca por gate e nunca por subagente, porque escrever no `.forge/ledger/` real é operação de dono. O implementador entrega o script de recuperação e a lista dos seis blocos; ele não os aplica.

**Alternativa descartada: declarar as perdas fora de escopo e apenas registrar a possibilidade.** Descartada porque o texto perdido é insumo de ondas desta mesma rodada — LDG-0021 é o item da Onda H, LDG-0029 e LDG-0010 são a Onda G inteira — e quem for executá-las leria hoje um item que perdeu 85% da razão de existir.

## 3. O contrato, depois da onda

```
ledger-ops.sh note   <LDG-NNNN> --kind progress|measurement|correction|decision --text "<txt>"
ledger-ops.sh update <LDG-NNNN> [--status ST] [--priority P] [--severity S] [--title "<txt>"]
                                [--detail "<txt>"] [--replace-detail]
```

Propriedades que passam a valer, e é por elas que o gate mede, não pela implementação:

- **P1 — `note` nunca perde byte.** Depois de `note`, o `detail` anterior é prefixo do `detail` novo.
- **P2 — `note` nunca fecha.** Depois de `note`, `status` e `resolved_at` são idênticos aos de antes.
- **P3 — `note` marca.** O `detail` novo contém o marcador do `--kind` pedido, com a data do commit HEAD.
- **P4 — `update --detail` não destrói em silêncio.** Se o `detail` corrente é não-vazio e o texto novo não o preserva, ou o comando recusa com `rc` diferente de zero e nada é gravado, ou `--replace-detail` foi passado e a perda foi anunciada em stderr com o número de bytes.
- **P5 — o denominador de `open` não muda.** Nenhuma porta desta onda altera o `status` de nenhuma entrada.
- **P6 — `note` é acumulativo.** N invocações produzem N marcadores, todos presentes, na ordem em que foram feitas.

## 4. O vermelho, antes do verde

Cada cenário abaixo falha hoje pela ausência real da funcionalidade, e cada um traz a saída de hoje medida nesta sessão. O implementador cola o vermelho observado antes de escrever uma linha de implementação; vermelho por fixture ausente ou caminho errado não conta e é achado na revisão adversarial.

O gate é **um só**, `tests/w210-ledger-detail-acumulativo-gate.sh`, e a razão de não serem dois é que os dois defeitos compartilham bancada, item de fixture e o campo que ambos disputam — separá-los custaria um ordinal a mais e duplicaria a montagem.

**`[1]` — o verbo `note` existe.** `note LDG-0001 --kind progress --text "fatia A entregue"` responde `rc 0` e uma linha `OK`. *Como falha hoje:* `FAIL: comando desconhecido 'note'`, medido na bancada; o `case "$cmd"` de `ledger-ops.sh` tem oito ramos e nenhum é `note`.

**`[2]` — P1, `note` preserva.** Item semeado com `detail` não-vazio; depois de `note`, o `detail` anterior é prefixo do novo e o comprimento cresceu estritamente. *Como falha hoje:* o verbo não existe, e a única porta que grava `detail` substitui — medido em §1.4, 116 bytes viram 28.

**`[3]` — P2, `note` não fecha.** `status` e `resolved_at` idênticos antes e depois, sobre um item `open` e sobre um item `planned`. *Como falha hoje:* o verbo não existe; e a porta que hoje serviria de sucedâneo, `update --status in-progress`, muda o status por construção — medido em §1.5, com o item saindo de `list --status open`.

**`[4]` — P3, o marcador e a data.** O `detail` novo contém o marcador do `--kind` pedido, e a data nele é a do commit HEAD da fixture, não a de hoje. A fixture cria o commit com `GIT_COMMITTER_DATE` numa data distante do dia da execução, para que relógio de parede e data de commit sejam distinguíveis — sem isso o cenário passaria por coincidência em qualquer implementação. *Como falha hoje:* não há marcador porque não há verbo.

**`[5]` — P6, acumulação.** Três `note` seguidos, de `kind` diferentes; ao fim, os três marcadores estão presentes e na ordem de emissão. *Como falha hoje:* três `update --detail` seguidos deixam apenas o terceiro texto — é a forma exata das seis perdas de §1.2.

**`[6]` — `--kind` fora do enum reprova.** `--kind lixo` responde `rc` diferente de zero, nomeia os quatro valores aceitos e não grava. Contador de controle pareado: os **quatro** valores legítimos são exercitados no mesmo cenário e os quatro gravam, com o denominador derivado da própria lista do gate. Sem o par, uma implementação que recusasse tudo passaria. *Como falha hoje:* não há verbo, logo não há enum.

**`[7]` — `note` sem `--text`, com `--text ""`, e com `--text --kind` reprova.** As três recusas são as que `forge_require_value` e `forge_reject_flag_as_value` já oferecem, e o cenário existe para provar que o verbo novo nasce **dentro** da disciplina da issue #103, e não ao lado dela. *Como falha hoje:* não há verbo; e este é o cenário que impede o verbo novo de reintroduzir por uma porta nova o defeito que `w194` e `w201` fecharam nas antigas.

**`[8]` — P4, `update --detail` destrutivo recusa.** Item com `detail` não-vazio; `update --detail "texto que não contém o anterior"` responde `rc` diferente de zero, o `ledger.json` fica **byte a byte idêntico** (comparação por `cmp` contra uma cópia feita antes), e a mensagem nomeia `note` e `--replace-detail`. *Como falha hoje, com a saída colada:* `OK update — LDG-0001 atualizado`, `rc 0`, e o `detail` passa de 116 para 28 bytes.

**`[9]` — os dois caminhos que continuam gravando.** Sobre `detail` vazio, `update --detail "texto"` grava e responde `OK`; sobre `detail` não-vazio, `update --detail "<atual> mais coisa"` grava e responde `OK`. *Hoje passa* — é o controle de retrocompatibilidade da Decisão 4, e existe para que a guarda não vire uma recusa geral. Medido hoje na bancada: o segundo caso já responde `OK update — LDG-0002 atualizado` com `rc 0`.

**`[10]` — `--replace-detail` substitui e anuncia.** Com a flag, o `detail` é substituído, o `rc` é 0, e o stderr informa o número de bytes descartados. Asserção sobre o número, não só sobre a presença da linha: uma mensagem que dissesse "0 bytes" sobre uma perda de 88 seria a forma de aviso que treina o operador a ignorar. *Como falha hoje:* a flag não existe e é recusada por `forge_reject_unknown`.

**`[11]` — `--replace-detail` sem `--detail` reprova.** Flag sem alvo é erro de uso, e o desfecho é recusa nomeando a flag. *Como falha hoje:* a flag não existe.

**`[12]` — o caso-limite que a enumeração precisa cobrir: texto novo idêntico ao atual.** `update --detail` com exatamente o texto que a entrada já carrega continua sendo `NOCHANGE`, com `rc` diferente de zero, e **não** é reclassificado como "preserva, logo grava". *Hoje passa*, e é justamente por isso que ele entra: a guarda da Decisão 4 tem de ser aplicada **depois** da detecção de no-op, nunca antes, e sem este cenário a ordem seria escolhida por acidente. Medido hoje: a saída atual é `NOCHANGE` seguido de `FAIL: ledger-ops: 'update LDG-0002' não alterou nenhum campo`.

**`[13]` — `note` sobre id inexistente reprova; `note` sobre item `resolved` grava e avisa.** Os dois desfechos da Decisão 6 no mesmo cenário. *Como falha hoje:* não há verbo.

**`[14]` — P5, o denominador de `open` é invariante.** Fixture com entradas em `open`, `planned`, `in-progress` e `resolved`; conta-se `status == open` antes, roda-se a bateria inteira de `note` do gate, conta-se depois. Os dois números são iguais, e o denominador é **derivado da fixture na execução**, nunca escrito como literal. É o cenário que traduz em asserção a razão da Decisão 5.

**`[15]` — propriedade sobre entrada gerada.** Para uma sequência de textos gerados na execução — variando comprimento, acentuação, quebras de linha internas, aspas e sequências que coincidem com nomes de flag — cada `note` mantém P1 e P6: o `detail` anterior continua prefixo do novo, e todos os marcadores anteriores continuam presentes. O número de casos gerados é publicado, e zero casos reprova o cenário. Cobre a superfície que três exemplos escolhidos a dedo não cobrem, que é o que a invariante 5 pede.

**`[16]` — contrato: o resultado continua conforme ao schema.** Depois da bateria, o `ledger.json` da fixture é validado contra `.forge/schemas/ledger.schema.json` pelo mesmo validador que `w202` usa, sobre a **fixture** e nunca sobre o ledger real. Prova a Decisão 8 em vez de a afirmar.

**`[17]` — integração de ponta a ponta, e é o cenário que fecha o ciclo do relato do dono.** `add` com medição, `note --kind progress` uma vez, `note --kind progress` outra vez, verificar que o item continua `open` e que `list --status open` continua listando-o, `resolve --note "…"`, e por fim `render`. Asserções: o `LEDGER.md` final contém as duas notas e o fecho; o `status` só mudou no `resolve`; e o `detail` final contém, na ordem, a medição original, as duas notas e o `Resolvido:`. *Como falha hoje:* os dois `note` não existem, e substituí-los por dois `update --detail` deixa o `LEDGER.md` final com apenas o último texto mais o fecho — a medição original some, que é a forma de dano de §1.2.

## 5. Prova de mutação

Três mutações, cada uma com controle antes, mutação, restauração verificada e recontrole depois. A restauração é por cópia do arquivo original preservado no início, conferida por `cmp` — nunca por uma segunda edição que desfaça a primeira, que é o `restore()` quebrado de `feedback-mutacao-fantasma-restore`.

A especificação declara, para cada mutação, a **propriedade que ela ataca** e o **contrafactual que ela precisa produzir**; o primitivo de edição é escolhido pelo implementador, que prova que ele discrimina. Em particular, um `perl -0pi -e 's/x/y$var/'` tem o `$var` do lado direito interpretado como variável do **perl**, vazia, o que torna a mutação um no-op enquanto o `cmp` confirma alegremente que o arquivo mudou — é LDG-0164, e a defesa contra ele não é escrever o comando com cuidado, é exigir que a mutação **produza o contrafactual declarado** antes de o cenário aceitar que ela ocorreu.

| # | alvo | propriedade atacada | contrafactual exigido |
|---|---|---|---|
| M1 | a guarda de preservação no `update` | P4 | `[8]` passa a responder `rc 0` e o `detail` da fixture encolhe; `[9]` e `[12]` continuam como estavam, o que prova que a mutação atingiu a guarda e não a detecção de no-op |
| M2 | o append do `note`, trocado por atribuição direta | P1 e P6 | `[2]` observa `detail` que não contém o texto anterior, e `[5]` observa um marcador em vez de três |
| M3 | a fonte da data do `note`, trocada do commit HEAD para o relógio de parede | P3 | `[4]` observa no marcador a data de hoje em vez da data distante que a fixture carimbou no commit |

M1 e M2 têm um par obrigatório que a matriz não pode omitir: cada uma precisa deixar **os outros** cenários verdes. Uma mutação que derrubasse o gate inteiro provaria apenas que o arquivo foi editado.

**O contrafactual já medido, que entra na matriz sem custo:** a mutação de §1.7 — `if (de) e.detail = de;` trocado por concatenação incondicional — derruba `w194[4]` e `w201[P3]` e deixa `w98`, `w203` e `w207` verdes. Esse par medido é a prova de canal do gate novo: ele mostra que os gates existentes de fato observam a semântica de `update --detail`, e portanto que a edição deles na §7 não é cosmética.

## 6. Contadores de controle

Denominador **fixo por construção** para os cenários do próprio gate: são 17, e a divergência entre o número declarado no cabeçalho e o número de cenários efetivamente executados é o achado — é a única exceção legítima que a invariante 14 admite ao literal numérico.

Denominadores **derivados na execução**, nunca escritos como literal, porque contam coisas da árvore que envelhecem: o número de valores do enum de `--kind` exercitados em `[6]`, o número de textos gerados em `[15]`, o número de entradas `open` da fixture em `[14]`, e o número de subcomandos de `ledger-ops.sh` varridos por qualquer cenário que enumere portas. Cada um publica o número que examinou, e **zero reprova**.

Três estados, nunca dois, em todo cenário que dependa de ferramenta externa: `node` ausente, `git` sem commit ou fixture não montada produzem `NÃO VERIFICADO` com código próprio, distinto de `sem violação`. É a lição de LDG-0157 e de `w194`, e ela vale para o gate novo desde a primeira linha.

Uma advertência de ferramenta que esta rodada mediu e que o implementador precisa carregar: **o `grep` do `PATH` desta máquina é o ugrep 7.8.4**, e sobre arquivo com byte de controle ele devolve saída vazia com `rc 1` — indistinguível de "não há ocorrência" — enquanto `/usr/bin/grep` encontra e avisa; o CI roda GNU grep. Nenhuma asserção deste gate pode concluir ausência a partir de uma varredura vazia sem antes provar que a varredura enxerga um positivo plantado.

## 7. Gates existentes a editar, nominalmente

A invariante 15 exige a varredura antes da mudança, e ela foi feita: **10 gates** citam `ledger-ops`, **4** deles usam `--detail`, e **2** têm asserções que a mudança derruba — medido por execução pareada em §1.7, não por leitura.

| gate | cenário | por que quebra | o que muda na edição |
|---|---|---|---|
| `tests/w194-ledger-write-discipline-gate.sh` | `[4]` | asserção de igualdade exata do `detail` depois de `update --detail` sobre entrada com `detail` não-vazio | o cenário passa a exercitar o caminho `[9]` da Decisão 4 (texto que preserva, ou entrada com `detail` vazio), mantendo o que ele mede: que o caminho feliz do `update` não regride |
| `tests/w201-flag-como-valor-gate.sh` | `[P3]` | mesma asserção de igualdade exata, sobre `$U3ID` | mesma correção; `[P3]` existe para pegar o aborto mudo de `forge_reject_flag_as_value`, e essa medição é preservada |

Nenhum dos dois perde poder na edição, e isso é condição da entrega: um cenário afrouxado para caber na mudança é a forma de dívida que esta rodada já pagou. `w98`, `w137`, `w157`, `w193`, `w202`, `w203`, `w207` e `w32` não são tocados — `w193` e `w137` não foram exercitados na bancada pareada porque criam worktrees e há outras cadeias em voo neste repositório, e para eles a conclusão é por leitura: `w193:169` usa `--detail "prop $RANDOM"`, valor distinto a cada chamada, e `w137:47` só usa `add`. O implementador confirma os dois por execução antes de fechar.

Documentação que muda junto, porque descreve o contrato: `template/.forge/commands/harness/ledger.md` (o bloco de protocolo e a seção "Disciplina de escrita") e o cabeçalho de uso de `template/.forge/scripts/ledger-ops.sh`. Como `template/.forge/commands/` é tocado, o espelho `plugin/forge/commands/ledger.md` precisa de `npm run build:plugin` — nunca `build-plugin.sh`, que instala em `$HOME`. A rule `rules/conventions/ledger-consultation.md` ganha a frase que faltava: progresso se registra com `note`, e quem fecha é o arquivamento.

## 8. Retrocompatibilidade com os consumidores

Nota de precisão sobre o número: o relato fala em cinco consumidores, e o que eu **medi** foram quatro árvores externas com `ledger-ops.sh` de fato instalado sob `.forge/scripts/` — `axis-go-cloud`, `axis-fare-validator`, `azim-crm` e `lionclaw` — mais o próprio `forge-harness`, o que dá cinco ledgers e quatro instalações externas. Se existe uma quinta árvore externa fora de `~/Documents/projects`, ela não entrou na medição, e o implementador a acrescenta ou registra a ausência.

O que **não** muda para nenhum deles: nenhum campo novo no `ledger.json`, nenhuma mudança no `ledger.schema.json`, nenhum `status` alterado por porta alguma desta onda, nenhuma mudança no `resolve`, no `harvest`, no `promote`, no `render`, no `status` ou no `list`, e nenhuma mudança na assinatura de `update` além de uma flag opcional acrescentada.

O que muda: `update --detail` passa a recusar a substituição destrutiva. Alcança as 1.915 entradas com `detail` substancial dos quatro consumidores no próximo `forge update`, e a recusa é o comportamento pretendido — é a armadilha sendo fechada. A recusa nomeia as duas saídas, então um operador humano segue em frente na mesma sessão.

O risco residual é um script de consumidor que chame `update --detail` em laço e passe a receber `rc` diferente de zero. Varri os quatro consumidores por chamadas de `ledger-ops.sh` fora da maquinaria instalada e a varredura não terminou dentro do orçamento de tempo desta especificação, então **declaro isso como não verificado** em vez de afirmar que não existem. A mitigação não depende da varredura: a recusa é acompanhada de mensagem que nomeia `--replace-detail`, e um consumidor que precise do comportamento antigo o obtém acrescentando uma flag. O implementador conclui a varredura, com `--exclude-dir` para `.forge/specs` e `node_modules`, e registra o resultado com número.

Um item para o canal de liaison, porque quatro repositórios têm o script instalado e a mudança é de comportamento observável: a onda emite uma mensagem `contract-change` descrevendo a recusa nova e o verbo novo, **depois** do merge, para que o aviso carregue a entrega e não uma promessa.

## 9. O que esta onda explicitamente não faz

Não toca `resolve`, `harvest`, `promote`, `add`, `render`, `status` nem `list` — os quatro primeiros são território da Onda E, e os três últimos não têm defeito medido aqui. Não cria status novo nem muda o significado de nenhum status existente. Não acrescenta campo ao `ledger.json` nem altera o `ledger.schema.json`. Não unifica o separador do `resolve` com o do `note`. Não reconcilia a divergência entre os quatro leitores de status medida em §1.5, nem migra as 15 entradas `in-progress` e `planned` dos consumidores. Não aplica a restauração das seis perdas no ledger real: entrega o procedimento e a lista, e a escrita é do orquestrador. Não roda `npm test` nem `tests/run-all.sh` durante a implementação, porque há outras cadeias trabalhando neste repositório; os gates do escopo são rodados um a um.

## 10. Achados adjacentes, para o ledger e não para esta onda

Dois, os dois medidos nesta sessão, e nenhum deles cabe aqui sem ampliar o escopo.

**Os quatro leitores de status do ledger não concordam sobre o que é um item ativo.** `status` e `render` usam `CLOSED = {resolved, wont-fix, promoted}`; `list --status` é igualdade exata; a definição de pronto do plano-mestre conta `status == open`. Consequência medida: 15 entradas em `in-progress` e `planned` nos consumidores são ativas para dois leitores e invisíveis para os outros dois. É defeito de contrato entre leitores, é anterior a esta onda, e a correção certa é decidir o vocabulário uma vez e fiar os quatro no mesmo predicado.

**Vinte e quatro itens abertos hoje, contra os 22 que o plano-mestre registra.** Não é discrepância a corrigir: é a invariante 14 em ação — o número é testemunha de data, e o plano já previu que rodada que mede de verdade encontra defeito novo. Registro para que ninguém trate o 22 como critério.

## 11. Definição de pronto

O gate `tests/w210-ledger-detail-acumulativo-gate.sh` existe, declara 17 cenários, executa 17, e passa. O vermelho de cada cenário foi observado e colado antes da implementação. As três mutações da §5 produziram os contrafactuais declarados, com restauração conferida por `cmp` e recontrole verde. `w194` e `w201` foram editados nominalmente e passam, sem perder o que mediam. Os oito gates de ledger não tocados passam, rodados um a um. `bash -n` limpo em tudo que foi tocado, sem `declare -A`, `${var,,}`, `${var^^}`, `mapfile` ou `readarray`. `template/.forge/commands/harness/ledger.md` atualizado e `npm run build:plugin` executado, com o espelho `plugin/forge/commands/ledger.md` em paridade. A varredura de call sites nos consumidores concluída, com número. O procedimento de restauração das seis perdas entregue, com os seis blocos recuperados de `d7d4ad46^` e `26ee11b6^` e conferidos byte a byte contra o que o `git show` devolve.

---

## Correções da implementação

Seção escrita por quem implementou, depois da revisão que reprovou a especificação. Cada item diz o que a spec afirmava, o que a implementação mediu, e o que passou a valer. As duas primeiras correções são os bloqueadores da revisão; as demais são as ressalvas, mais três achados que só apareceram ao executar.

### C1 — o ordinal do gate é `w211`, não `w210`

A spec alocou `w210`. Na hora de implementar, `tests/w210-worktree-branch-obrigatoria-gate.sh` já existia na árvore local, não commitado, criado pela cadeia da branch obrigatória por worktree que roda em paralelo. `gate-ordinal.sh next --path tests` devolveu `w211` (máximo remoto `w207`, máximo local `w210`), e é esse o ordinal do gate entregue: `tests/w211-ledger-detail-acumulativo-gate.sh`. É exatamente o cenário do LDG-0173 — ordinal conferido contra branches em voo, não contra o que a spec reservou horas antes.

### C2 — bloqueador 1: `w201[11a]` deixa de ser mascarado pela guarda nova, e a correção é outra

A revisão mediu certo o defeito: com a guarda instalada, `_scn1_rejects` (`update LDG-0001 --detail --title`, sobre uma entrada com `detail` não-vazio) continuaria reprovando mesmo com o pertencimento desligado, porque `--title` não preserva `detalhe real` — a guarda nova mascararia a guarda que a issue #103 instalou, e a mutação (a) do `w201` deixaria de provar o que afirma provar.

A correção aplicada não é nenhuma das duas que a revisão sugeriu (semear com `detail` vazio, ou com `detail` que seja subcadeia do valor engolido). É a terceira, e ela é estrutural em vez de circunstancial: **a flag engolidora do cenário `[1]` passou a ser `--title`, e não `--detail`**. O comando é `update LDG-0001 --title --detail`, o campo corrompido pela flag engolida passa a ser o `title`, e `title` não tem guarda nenhuma além do pertencimento. As três asserções de `[1]` seguem idênticas (rc≠0, mensagem nomeando as duas flags, `ledger.json` byte a byte igual), e a mutação (a) volta a discriminar: medido, com o pertencimento desligado o comando devolve `rc 0` e grava `title = "--detail"`.

Por que essa e não as sugeridas: semear `detail` vazio conserta o caso de hoje, mas deixa a mutação amarrada à ausência de conteúdo num campo que qualquer onda futura pode voltar a preencher. Observar o pertencimento por um campo sem segunda guarda é o que torna a prova estável — e é a regra geral que fica registrada: **prova de mutação de uma guarda tem de ser observada por um caminho onde nenhuma outra guarda decide o mesmo desfecho.**

Medido depois da correção: `w201` passa, `[3]` declara 7 subcomandos, `[11]` passa com as duas mutações isoladas.

### C3 — bloqueador 2: `note` chama `_render` e entra na lista de divergência de raiz, e os dois estão medidos

A revisão está certa: as duas obrigações transversais de toda porta de escrita deste script não estavam nem escritas nem medidas, e o cenário `[17]` da spec passaria verde sobre um `note` que jamais re-renderiza, porque invoca `render` explicitamente antes de assertar.

O que passou a valer:

- `note` chama `_render`, e o gate ganhou o cenário `[18]`, que roda `render` explícito **antes**, guarda uma cópia do `LEDGER.md`, roda `note` e exige que o markdown tenha mudado e carregue o texto da nota — sem nenhum `render` no meio. A mutação **M4** remove o `_render` do ramo `note` e o cenário reprova.
- `note` entra em `case "$cmd" in add|update|note|resolve|promote|harvest|render)`. O gate ganhou o cenário `[19]`, que cria um worktree na própria fixture, invoca `note` de dentro dele sem `FORGE_ROOT` e exige a linha de aviso; com controle positivo pareado (`add`, que avisa desde o LDG-0068, avisa na mesma bancada — sem isso a asserção seria satisfeita por uma fixture que não diverge) e controle negativo (`list`, porta de leitura, segue silenciosa). A mutação **M5** tira `note` da lista e o cenário reprova, com o par obrigatório de que `add` **continua** avisando, o que prova que a mutação atingiu a entrada do `note` e não o lib inteiro.
- O cenário `[17]` foi corrigido por outra razão, achada na execução: a asserção original exigia que o texto das notas e o fecho aparecessem no `LEDGER.md` **depois** do `resolve`, e isso é falso por desenho do renderizador — `renderSection` só imprime o corpo das entradas ativas e reduz as encerradas a um contador. A conferência do markdown passou para antes do `resolve` (item ainda ativo), e depois do fecho o cenário confere que o `LEDGER.md` contabiliza a entrada encerrada.

`w193` **não** foi editado. Sua matriz de portas é uma lista fixa de cinco com `[ "$n" -eq 5 ]`, continua verde (nenhuma das cinco mudou) e criar worktrees ali colidiria com a cadeia de worktree em voo neste repositório. A divergência de raiz da porta nova é medida por `w211[19]`, com mutação. Fica registrado que a lista de `w193[9]` segue sem enxergar a sexta porta — é redundância perdida, não cobertura perdida.

### C4 — 'preserva' é containment NÃO-ESTRITO, e está escrito no fonte

A ressalva da revisão está aceita na íntegra e virou letra, no cabeçalho do `ledger-ops.sh` e no cenário `[12]`: **preserva = o `detail` corrente é subcadeia do texto novo, incluindo o caso de igualdade**. Sob containment estrito, o texto idêntico passaria a ser recusado pela guarda em vez de pela detecção de no-op, e a mutação (a2) do `w194` deixaria de discriminar. A guarda é aplicada **depois** da detecção de no-op, dentro do mesmo heredoc node, e `w211[12]` afirma a ordem pela mensagem: exige que a recusa do texto idêntico seja a de `NOCHANGE`, não a da guarda.

### C5 — os dois casos de `detail` de `w194[5]` foram reescritos, e o cenário `[4]` também

Aceita. `w194[4]` passou a gravar `conteúdo inicial — detalhe novo do cenário 4`, que preserva o `detail` corrente, e os casos `detail-novo`/`detail-repetido` de `PROP_CASES` passaram a carregar um texto que preserva **esse** valor. Sem isso os dois casos ficariam recusados pela guarda e satisfariam a asserção trivialmente (`rc≠0` nunca viola 'OK implica gravação'), e nenhum dos doze casos seria sobre `detail`. Medido depois da correção: `w194[5]` declara 12 casos e 0 violações, com os dois casos de `detail` exercitando de fato a gravação e a detecção de no-op.

### C6 — as duas listas fixas de subcomandos ganharam `note`

Aceita. `w194[7]` passou de `(update resolve promote harvest list)` para `(update note resolve promote harvest list)` — 6 subcomandos declarados pelo contador de universo — e `w201[3]` ganhou a linha `note|note $U3ID --kind --text|--kind|--text`, indo a 7. As duas varreduras — flag desconhecida e flag-como-valor — passam a alcançar a porta nova pela redundância dos gates existentes, além do cenário `[7]` do gate novo.

### C7 — `w207` PRECISA ser editado, e a spec o listava como intocado

Este é o achado que a §1.7 não podia ver, porque o contrafactual dela ('concatenar sempre') não mexe na lista de portas. O desenho entregue mexe: `note` entra em `add|update|note|resolve|promote|harvest|render)`. E `w207[6]` muta exatamente essa linha, com o padrão `s/\badd\|update\|resolve\|promote\|harvest\|render\)/.../`, que deixou de casar. Medido: `w207` reprovou com `FAIL [6] mutação: mesmo sem 'render' na lista de portas o aviso apareceu`.

Duas correções, e a segunda é maior que a primeira:

1. O padrão passou a ser ancorado no fecho, `s/^(  add\|[a-z|]*)\|render\)/$1)/m`, removendo apenas o `|render`. A entrada de outras portas na lista deixa de exigir reescrita do alvo a cada onda.
2. **A restauração por `git checkout -- "$LEDGER_OPS"` destruía trabalho não commitado**, e isso não é teoria: a execução do `w207` nesta sessão apagou a implementação inteira desta onda, que estava na árvore de trabalho sem commit. Pior, a guarda de "a mutação mudou mesmo o arquivo?" era `git -C "$WS" diff --quiet`, isto é, comparação com o **HEAD** e não com o estado **anterior à mutação**: com o arquivo já sujo por uma edição legítima, ela aprovou mesmo com o `perl` não casando nada — que é exatamente a mutação fantasma do LDG-0164 que ela existe para impedir. As duas correções são a mesma: o gate preserva uma cópia antes de mutar (`$PRISTINE`), decide "mutou?" por `cmp` contra essa cópia, restaura por `cp` e confere a restauração byte a byte. O trap de `MUTATED` passou a restaurar pela cópia também.

Medido depois: `w207` passa nos seis cenários, e o `ledger-ops.sh` da árvore de trabalho fica byte a byte idêntico ao que era antes da execução (conferido com `cmp` contra uma cópia externa).

### C8 — idempotência do `note`: avisa, não recusa; e o procedimento de restauração confere antes de escrever

A spec não tratava o caso. Decisão: repetir o mesmo `--text` **acrescenta assim mesmo** (P6 é a propriedade desejada e recusar quebraria o uso legítimo de anotar duas vezes o mesmo fato em datas diferentes), mas o script **avisa em stderr** quando o texto de `--text` já aparece no `detail`, sem mudar o `rc`. É o idioma do `WARN` que o `add` sem `--detail` já usa: fecha o silêncio sem fechar a porta.

O risco concreto que a revisão nomeou — a restauração das seis perdas rodada duas vezes — é fechado no próprio procedimento: `docs/plans/spikes/restaura-seis-perdas-do-detail.sh` roda em **dry-run por padrão**, e para cada um dos seis blocos confere se o texto recuperado já está no `detail` de hoje antes de escrever, pulando os que estiverem. Medido: a sonda de contenção do script discrimina (`sim` sobre um ledger sintético que já carrega o bloco, `nao` sobre um que não carrega), e o dry-run sobre a árvore real lista os seis com o `sha256` do ledger idêntico antes e depois.

### C9 — colisão do marcador: a leitura é de presença e ordem, nunca de contagem

Aceita, e virou letra em dois lugares. O comentário do ramo `note` no `ledger-ops.sh` declara que a leitura por marcador é de presença e ordem e nunca de contagem, justamente porque um `--text` do usuário pode conter uma sequência idêntica à do marcador gerado. E o cenário `[15]` do gate gera, entre os sete textos, um que **é** um marcador colidente (`PROGRESSO (<data da fixture>): marcador colidente escrito pelo próprio usuário`) — P1 e P6 continuam valendo sobre ele.

### C10 — as medições da spec que não reproduzem, corrigidas

- §1.3, "53 são append": o número medido na implementação, como na revisão, é **68** append entre as mutações preservadoras, com 0 prepend e 0 no meio. A direção que sustenta a Decisão 3 vale, e vale mais forte do que o escrito. O comentário no fonte registra 68.
- O achatamento de quebras de linha está em `ledger-render.mjs:75`, não em `:78`.
- Os bytes das seis perdas na tabela da §1.2 foram medidos em caracteres; em **bytes** (que é como o `--replace-detail` os anuncia) os textos recuperados são 4189, 3333, 3761, 2724, 2595 e 5383. As seis perdas reproduzem, e nenhuma delas já está restaurada (`indexOf` do texto antigo no `detail` de hoje devolve -1 nas seis).
- Os dois blocos de `LDG-0029` **não** se contêm: o texto de `d7d4ad46^` (5383 B) não contém o de `26ee11b6^` (3761 B) nem vice-versa. São dois blocos a restaurar, não um — é por isso que são seis perdas em cinco itens.

### C11 — a varredura de call sites nos consumidores, concluída, com número e com controle positivo

A §8 declarava a varredura como não verificada. Ela foi concluída, e o primeiro achado é sobre o denominador: **são oito árvores externas com `ledger-ops.sh` instalado**, não quatro. Além de `axis-go-cloud`, `axis-fare-validator`, `azim-crm` e `lionclaw`, também `Axis.AcqSimulator`, `Axis.PadSimulator`, `collatra` e `docuseal` carregam `.forge/scripts/ledger-ops.sh`.

A varredura foi dirigida à maquinaria instalada de cada uma (`.forge/scripts`, `.forge/hooks`, `.forge/commands`, `scripts`, `.github`, `Makefile`), com `/usr/bin/grep` e não com o `grep` do PATH. Resultado: **24 ocorrências de `ledger-ops.sh update` nas oito árvores, e nenhuma delas é call site programático** — são a linha de uso do cabeçalho do próprio script, o comentário do `arg-guards.sh`, a linha do `ledger.md` de cada árvore, um `_unknown_arg` do `PadSimulator` e um comentário do `check-produto-sem-veredito.sh` do `axis-go-cloud` que descreve o defeito ("o marcador é gravado por `ledger-ops.sh update --detail`, que SOBRESCREVE o campo") sem invocar nada.

**Controle positivo obrigatório**, porque zero não prova ausência: a mesma varredura, nos mesmos diretórios, procurando apenas `ledger-ops.sh`, devolve **445 linhas** distribuídas nas oito árvores. A varredura enxerga.

Fica declarado o que **não** foi varrido: as árvores inteiras dos consumidores fora desses diretórios (o orçamento estourou duas vezes, como estourou para o especificador e para o revisor), e qualquer árvore fora de `~/Documents/projects`. O risco residual continua mitigado pela forma da recusa, que nomeia `--replace-detail`.

### C12 — o gate declara 21 cenários, não 17

O gate entregue tem `[0]` (controle do comparador de conteúdo, que planta um positivo e um negativo antes de qualquer conclusão por ausência — a defesa contra a armadilha do ugrep), os `[1]`–`[17]` da spec, mais `[18]` e `[19]` da correção C3 e `[20]` (a prova de mutação, com cinco mutações em vez de três). São 21 declarados no cabeçalho e 21 executados, conferidos por um contador que reprova na divergência.
