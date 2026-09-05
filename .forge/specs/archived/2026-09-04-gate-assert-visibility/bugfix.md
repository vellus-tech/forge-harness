# Bugfix — gate-assert-visibility

> Análise do bug do change `gate-assert-visibility`. Este artefato substitui `requirements.md` no tipo `bugfix`.
> Marque incertezas com `NEEDS CLARIFICATION`. O change só atinge `requirements-ready` quando a análise estiver completa e sem pendências.

## 1. Comportamento atual (incorreto)

Os gates de `tests/*.sh` usam o padrão `[ condição ] && comando_seguinte` (ou `grep -q A && grep -q B`) como asserção — "se a condição vale, faça mais uma checagem; senão, o gate deveria reprovar". Sob `set -e` (todo gate abre com `set -euo pipefail`), esse padrão tem **dois** comportamentos incorretos, verificados por execução direta e não apenas inferidos:

**(a) Se o comando FINAL da cadeia falha, o gate morre imediatamente e sem nenhuma mensagem.**

```bash
$ bash -c 'set -euo pipefail; echo "antes"; [ "1" = "1" ] && echo "abc" | grep -q "XYZ"; echo "depois — CHEGOU?"'
antes
$ echo $?
1
```
`"depois — CHEGOU?"` nunca imprime. Nenhum `FAIL [n]: ...` é emitido — o gate simplesmente para, e quem lê o log da suíte não sabe qual das linhas do arquivo matou o processo nem por quê. Instância real: `tests/check-authz-gate.sh:97` (`grep -q 'services/orders/handler.go' <<<"$out" && grep -q 'hasRole(...)' <<<"$out"`) — se o handler for encontrado (1ª cláusula OK) mas a chamada de autorização não (2ª cláusula, a última da lista, falha), o gate morre ali, sem nenhum `FAIL` explicando que a cobertura de autorização regrediu.

**(b) Se um comando NÃO-final da cadeia falha, o gate NÃO reprova — continua em silêncio, como se a checagem tivesse passado.**

```bash
$ bash -c 'set -euo pipefail; echo "antes"; [ "1" = "2" ] && echo "nunca deveria chegar aqui"; echo "depois — CHEGOU?"'
antes
depois — CHEGOU?
$ echo $?
0
```
Esta é a face mais grave do defeito, e o `LDG-0012` original não a registrou: a regra do bash é que a checagem de `set -e` é **ignorada para todo comando de uma lista `&&`/`||` que não seja o último**. Quando o primeiro `[ cond ]` de uma cadeia falha, o curto-circuito faz a cadeia inteira "falhar", mas como esse `[ cond ]` não é o último comando da lista, sua falha é isenta de `set -e` — o script segue para a próxima linha como se nada tivesse acontecido. Instância real: `tests/w32-archive-gate.sh:87` (`[ -n "$VRM" ] && [ -f "$VRM" ]`) — `$VRM` é a própria saída do `find` que a linha anterior calcula; se o `find` não localizar o run-manifest, `$VRM` fica vazio, `[ -n "$VRM" ]` (1ª cláusula, não-final) falha, e o gate **segue em silêncio** para o bloco `node -e '...'` seguinte, que passa a operar sobre um `manifestPath` vazio.

**A mesma linha pode cair em (a) ou em (b) dependendo de qual cláusula da cadeia quebra.** Exemplo didático, `tests/w13-init-gate.sh:28` (`[ -f "$T1/AGENTS.md" ] && [ -L "$T1/CLAUDE.md" ]`, dentro do cenário `[1]`, cujo `echo "OK [1] (...)"` só aparece 13 linhas depois, na linha 41): se `AGENTS.md` não existisse (1ª cláusula falsa, caso b), o gate **chegaria até `echo "OK [1] ..."` e imprimiria normalmente** — o cenário inteiro reporta sucesso apesar da asserção de instalação ter sido violada. Se em vez disso `CLAUDE.md` existisse mas não fosse o symlink esperado (2ª cláusula, a última, falsa, caso a), o gate morreria ali mesmo, sem alcançar nem `OK [1]` nem qualquer `FAIL` — mas ao menos o código de saída não-zero da suíte sinalizaria que algo quebrou, o que o caso (b) nem isso garante.

### Catálogo medido (correção do `LDG-0012`, que estimava "~15 gates", e da primeira versão desta análise)

A primeira varredura deste change usou apenas `grep -nE '^\s*\[ .+ \] && '`, que cobre só cadeias que abrem com `[ `. Isso subestimou a superfície real: o mesmo defeito ocorre em qualquer lista AND-OR bare, incluindo cadeias `grep -q A && grep -q B` sem `[ ]`. Varredura corrigida (`grep -nE '^\s*(\[ |grep |test )' tests/*.sh | grep -E ' && ' | grep -vE ' \|\| '`, cada ocorrência lida em contexto):

- **52 sites de asserção real** (bare, sem fallback explícito de falha) em **20 arquivos**: `changelog-merge-gate.sh` (3: 40,41,49), `check-authz-gate.sh` (4: 97,98,99,124), `gw1-conflict-gate.sh` (1: 38), `gw2-rules-anchor-gate.sh` (2: 54,74), `gw3-data-governance-gate.sh` (5: 28,29,45,58,71), `w102-capability-packs-gate.sh` (1: 32), `w13-init-gate.sh` (4: 28,29,30,31), `w14-adapters-gate.sh` (11: 25,26,27,33,34,37,54,59,61,62,63), `w20-spec-gate.sh` (3: 29,30,31), `w21-pipeline-gate.sh` (1: 86), `w22-close-gate.sh` (1: 78 — a linha 106 já está segura), `w30-schemas-gate.sh` (1: 75), `w32-archive-gate.sh` (3: 68,87,168), `w33-publish-gate.sh` (1: 83), `w41-graph-gate.sh` (1: 113), `w43-c4-gate.sh` (3: 27,55,80), `w50-story-shard-gate.sh` (1: 239 — formato especial, ver §2), `w51-waves-progress-gate.sh` (3: 86,104,129), `w80-suite-gate.sh` (2: 25,35), `w91-stage-contract-gate.sh` (1: 46).
- **9 sites de controle-de-fluxo legítimo** (não são asserção — constroem estado/side-effect condicional, não verificam invariante) — **não converter**: `check-authz-gate.sh:43`, `w112-liaison-session-gate.sh:24`, `w113-liaison-enforce-gate.sh:26`, `w131-surface-declaration-gate.sh:51,80`, `run-all.sh:47,53,54,77`.
- **Idioma A, já seguro e DOMINANTE na suíte** (`cond || { <mensagem>; exit N; }`, tipicamente com a mensagem no formato `echo "FAIL [n]: ..."`) — a varredura corrigida do §1 já filtra toda linha com ` || ` fora do catálogo, então nenhum site desse idioma aparece nos 52; ele não é exceção, é a norma da casa: `grep -cE '\|\| \{' tests/*.sh` soma **713 ocorrências em 40 arquivos** (ex.: os já citados `w100-spec-delta-pipeline-gate.sh:120,129`, `w107-red-replay-gate.sh:596`, `w131-surface-declaration-gate.sh:367`, `w22-close-gate.sh:106`, `w90-run-manifest-gate.sh:67` — nem todos com a mensagem literalmente prefixada por "FAIL", mas todos no mesmo idioma estrutural `cond || { ...; exit N; }`). Não tocar nenhum.
- **Idioma B, também já seguro** (`condição_de_falha && { echo FAIL...; exit N; }` — "se a condição RUIM ocorrer, reprove"): dezenas de sites adicionais espalhados por quase todo `tests/*.sh` (ex.: `graph-jvm-gate.sh:135,167,182`, `w106-red-first-gate.sh:172,447,979`, `w112-liaison-session-gate.sh:80,112,124,141`, `w131-surface-declaration-gate.sh:92,111,147,155,281,294,371`, entre muitos outros). Seguro pela mesma regra do §4: quando a condição ruim NÃO ocorre (caso comum), a 1ª cláusula falha, é isenta de `set -e` por não ser a última do `&&`, e o script segue — exatamente o desejado. Quando a condição ruim ocorre, a 1ª cláusula passa e o bloco `{ FAIL; exit }` roda e reporta. Fora do escopo desta correção.
- **Duas exceções ao critério objetivo do §2** (marcador `[n]` de cenário acima, sem `||`) que **não** são asserção a converter, apesar de terem `[n]` acima: `tests/w111-liaison-sync-gate.sh:259` (`grep ... | grep -vq "^.*#" && true`) sempre avalia para `true` — asserção vazia, nunca reprova; e `tests/w131-surface-declaration-gate.sh:305` (`sed -i.bak '...' "$F" && rm -f "$F.bak"`) — side-effect puro (limpa o backup do `sed -i`, não verifica invariante). Nenhum dos dois entra no catálogo de correção; o primeiro é candidato a um item de ledger separado (asserção vazia é um defeito de outra natureza — ver §6), o segundo está correto como está.

## 2. Comportamento esperado

Toda asserção do primeiro grupo do §1 passa a seguir o idioma A, já dominante na suíte (ver §1): `condição || { echo "FAIL [n]: <motivo> (<contexto: valores observados>)"; exit 1; }` — onde `[n]` é o número (ou identificador do cenário, que pode ser alfanumérico — ex.: `[1b]` em `w32-archive-gate.sh:80`) já presente no `echo "[n] ..."` mais próximo acima no mesmo arquivo. Essa presença de marcador é **necessária mas não suficiente** como critério: confirmada em todos os 52 sites do catálogo e ausente nos 9 de controle-de-fluxo, mas há duas exceções que têm `[n]` acima e ainda assim não são asserção a converter — listadas no §1 (`w111-liaison-sync-gate.sh:259`, `w131-surface-declaration-gate.sh:305`). Cadeias de 2+ condições viram `||` encadeado com a mesma mensagem final, ou um `if` explícito quando o motivo de falha precisa distinguir qual condição da cadeia falhou.

**Caso especial — `w50-story-shard-gate.sh:239`:** `[ "$task_count" -eq 0 ] && echo "invariante detectada: ..."` não é uma segunda checagem no "then", é uma mensagem informativa — mas sofre do mesmo defeito (b): se `task_count != 0` (invariante violada, deveria reprovar), a cláusula única é não-final-por-short-circuit-vazio e o script segue direto para `echo "OK [8]"` na linha seguinte. Converte para:
```bash
[ "$task_count" -eq 0 ] || { echo "FAIL [8]: story vazia deveria ter zero tasks identificáveis (achou $task_count)"; exit 1; }
echo "OK [8]"
```
descartando o echo informativo original (redundante com o `OK [8]` que já só imprime no caso bom).

Para toda entrada que a suíte atual já exercita (hoje verde), nenhum gate muda de veredito — a mudança é de **visibilidade** da reprovação (mensagem `FAIL [n]` + `exit 1` explícitos em vez de morte muda). Isso **não** se estende às entradas de violação que hoje são mascaradas: o caso (b) do §1, por definição, converte um veredito que hoje é um PASS silencioso e incorreto (a invariante está violada mas o gate não percebe) para um FAIL correto — essa é a correção pretendida, não um efeito colateral a evitar. O exemplo do `w50-story-shard-gate.sh:239` no bloco acima ilustra exatamente isso: com `task_count != 0`, hoje o gate sai 0 (passa, errado); depois da conversão sai 1 (reprova, correto). Nenhuma entrada coberta pela suíte hoje exercita esse ramo (é por isso que a suíte está verde), então a mudança não quebra nenhum teste existente — mas o comportamento sob violação real muda, deliberadamente.

## 3. Comportamento que deve permanecer inalterado

- Os 9 sites de controle-de-fluxo legítimo listados no §1 (constroem variável/copiam fixture/imprimem linha opcional) — converter esses quebraria a semântica pretendida (ação condicional opcional, não invariante).
- Os sites já seguros nos idiomas A (713 ocorrências em 40 arquivos, a norma da suíte — medição do §1) e B (dezenas) — já corretos, não são alvo desta correção.
- `tests/w111-liaison-sync-gate.sh:259` — defeito real, mas de outra natureza (assertion vazia); não corrigido aqui.
- O veredito de cada gate (PASS/FAIL) para toda entrada já coberta pela suíte atual — esta é uma correção de **observabilidade de falha**, não de lógica de negócio dos gates.

## 4. Root cause

**Mecanismo (bash, verificado por execução, não presumido):** a regra POSIX/bash para `set -e` isenta da checagem de erro todo comando de uma lista AND-OR (`&&`/`||`) que não seja o **último** comando dessa lista. Em `A && B`:
- se `A` falha, `B` nunca roda, e a falha de `A` é isenta (não é o último comando) → o script **continua** para a próxima linha, mesmo que a invariante que a asserção deveria proteger esteja violada (§1-b).
- se `A` passa e `B` falha, `B` **é** o último comando da lista → sua falha **não** é isenta → `set -e` mata o script imediatamente, sem que nenhuma linha `echo FAIL` seguinte (que existiria mais abaixo no arquivo, fora dessa mesma instrução) chegue a executar (§1-a).

**Por que foi introduzido:** `[ cond ] && cmd` é um idioma comum e compacto em bash para "se X, então Y" — natural de escrever quando a intenção do autor era genuinamente controle-de-fluxo (e nesses casos, como os 9 do §1, está correto). O defeito nasce quando o mesmo idioma compacto é reaproveitado para expressar uma **asserção** ("X deve valer, senão o gate reprova") sem o fallback explícito que a asserção exige — seja o idioma A (`cond || FAIL`) seja o idioma B (`cond_ruim && FAIL`), ambos seguros e ambos, juntos, a prática dominante e correta da suíte (§1). Os 52 sites bare são o desvio pontual dessa norma, não o padrão — o que também explica por que a correção é mecânica: o idioma certo já está estabelecido e só precisa ser aplicado nos sites que ainda não o seguem. Sintaticamente os usos bare e os dois idiomas seguros são parecidos; o critério objetivo que separa asserção-bare-quebrada de controle-de-fluxo-legítimo é a presença do marcador `[n]` de cenário acima, com as duas exceções documentadas no §1.

**Por que não foi detectado antes:** todo gate listado no §1 foi escrito e validado contra o cenário **feliz** (a condição realmente vale no momento da autoria) — nesse caminho, `A && B` executa `B` normalmente e o gate se comporta como esperado, sem nunca exercitar o ramo de falha da própria asserção. O defeito só se manifesta quando uma regressão real faz a condição falhar depois — e nesse momento, dependendo de qual cláusula da cadeia falha, o resultado é morte muda (§1-a, o que a nota original do `LDG-0012` já registrava) ou pior, passagem muda com `OK` impresso (§1-b, achado desta análise, não estava no registro original). Nenhuma suíte de meta-teste (gate que testa gate) cobria esse caminho — os 52 sites bare provavelmente nasceram de autores que, num momento de pressa ou por hábito de outra linguagem, usaram o idioma compacto errado num arquivo onde o idioma correto já convivia ao lado (a maioria dos 20 arquivos do catálogo tem sites bare E sites já seguros lado a lado — não é falta de convenção, é aplicação inconsistente dela).

## 5. Testes de regressão

Protocolo Red-first (ver `template/.forge/rules/testing/regression-red-first.md` — no dogfood raiz deste repo, a regra vive em `template/.forge/rules/`, não em `.forge/rules/`, que aqui não existe): o teste que reproduz o defeito é escrito **antes** da correção, roda na árvore pré-correção e é **observado** falhando por comportamento — nunca por erro de compilação ou fixture ausente. A observação é registrada com `/forge:red record` e reproduzida por `/forge:red replay`; declaração sem replay não vale como evidência.

**Teste de reprodução planejado (2ª correção — a mecânica anterior não era compatível com o motor de replay: `failure_pattern` não pode expressar "ausência de FAIL", o teste vivia em `tests/fixtures/` e nunca entraria na suíte via `run-all.sh --list`, e faltava `test_id`).** O teste roda sobre um site real do catálogo: `tests/w80-suite-gate.sh:25` (`[ -f "$B/src/money.ts" ] && [ -f "$B/src/billing.ts" ]`, cenário `[2]`), escolhido porque `$B = tests/fixtures/brownfield` é uma fixture **versionada e gate-própria** (não passa por instalador nem por código de produção) — remover `billing.ts` para forçar o caso (a) não corrompe nenhum artefato fora da suíte de teste.

**Arquivo:** `tests/gate-assert-visibility-gate.sh` (dentro de `tests/`, casado por `tests/*-gate.sh` — entra automaticamente no `--list` do `run-all.sh` e permanece na suíte depois do Green, conforme o item normativo 4 da rule). O próprio teste segue o idioma A que ele valida (é, ele mesmo, parte do catálogo de disciplina que esta correção estabelece):

```bash
#!/usr/bin/env bash
# Regressão do gate-assert-visibility (LDG-0012): w80-suite-gate.sh:25 deve reportar
# FAIL [2] explícito quando a fixture brownfield perde billing.ts — não morrer em silêncio.
set -euo pipefail
WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FX="$WS/tests/fixtures/brownfield/src/billing.ts"
BAK="$(mktemp)"; cp "$FX" "$BAK"
trap 'cp "$BAK" "$FX"; rm -f "$BAK"' EXIT
echo "[1] w80-suite-gate.sh reporta FAIL [2] explícito com billing.ts ausente"
rm -f "$FX"
set +e
out="$(bash "$WS/tests/w80-suite-gate.sh" 2>&1)"; rc=$?
set -e
cp "$BAK" "$FX"
echo "$out" | grep -qE '^FAIL \[2\]' \
  || { echo "FAIL [1]: w80-suite-gate.sh saiu rc=$rc sem emitir 'FAIL [2]: ...' ao remover billing.ts da fixture ($out)"; exit 1; }
echo "OK [1]"
```

`test_path`/`test_id`: `tests/gate-assert-visibility-gate.sh` / `[1]`. `command`: `bash tests/gate-assert-visibility-gate.sh`. `failure_pattern`: `FAIL \[1\]: w80-suite-gate\.sh saiu` — na árvore pré-correção (linha 25 do `w80-suite-gate.sh` ainda bare), este teste roda, detecta a ausência de `FAIL [2]` na saída do gate sob teste e **emite ele mesmo** `FAIL [1]: ...` seguido de `exit 1` — esse é o sinal que `red-classify.mjs` reconhece como `behavioral` (casa a assinatura `shell-gate` do motor, `/^FAIL \[[^\]\n]+\]/m`) e que `failure_pattern` casa no replay. Na árvore pós-correção (linha 25 convertida ao idioma A), `w80-suite-gate.sh` passa a emitir `FAIL [2]: ...` quando `billing.ts` falta, o `grep` do passo acima encontra, e `gate-assert-visibility-gate.sh` sai com `OK [1]` — verde. `fix_files` inclui `tests/w80-suite-gate.sh`; `tests/gate-assert-visibility-gate.sh` é o teste, não a correção, e é o próprio "removedor do risco" descrito na fixture — restauração garantida por `trap ... EXIT` (não por lógica ad hoc), com a fixture restaurada tanto no caminho de sucesso quanto no de falha do subprocesso.

Os outros 51 sites do catálogo do §1 não recebem, cada um, seu próprio Red individual — seria custo desproporcional para um catálogo mecânico e repetitivo. A garantia sobre eles é dupla: (i) a correção aplica o mesmo idioma A já provado Red→Green no site canônico acima, e (ii) a suíte completa roda antes/depois de cada task de conversão (ver "Teste que protege a §3" abaixo), confirmando que nenhum veredito muda para as entradas que ela já exercita.

**Pendência declarada para o gate humano:** se, durante a conversão dos 51 sites restantes, a suíte completa (`run-all.sh`) revelar um gate que HOJE passa (rc=0) e PASSA a reprovar (rc=1) após a conversão — isto é ambíguo por construção: pode ser regressão da conversão (bug na task) ou pode ser uma violação real que o caso (b) mascarava e que a correção revelou, exatamente o cenário que motiva este change. Este documento não resolve esse critério de aceite antecipadamente porque não é decidível sem ver o caso concreto — cada ocorrência (se houver) deve ser investigada individualmente na task correspondente, não descartada como "quebrou a suíte, reverter".

**Sequenciamento `record` vs. `replay` (correção sobre uma versão anterior desta análise, que tratava os dois como uma única task "antes de qualquer correção" — impossível aqui):** o motor de replay (`template/.forge/scripts/lib/red-replay.mjs`) exige que o comando declarado **passe em HEAD** como pré-condição antes de derivar a árvore pré-correção — e `tests/gate-assert-visibility-gate.sh` só passa em HEAD depois que `tests/w80-suite-gate.sh:25` (um dos `fix_files`) já estiver convertido, porque é exatamente essa conversão que o teste verifica. `record` (a declaração — escrever o teste, registrar `test_path`/`test_id`/`failure_pattern`/`--fix-files tests/w80-suite-gate.sh`) precede toda correção, como a norma exige — mas `replay` (a observação real) só pode rodar **depois** que a task que converte `tests/w80-suite-gate.sh` (que cobre as linhas 25 e 35 do catálogo, como qualquer outra task de arquivo) tiver sido commitada. O teste em si nasce e é commitado antes da correção (Red-first item 1 satisfeito: o teste não nasce depois do fato); só a confirmação por execução (`replay`) fica para depois da correção que ela mede — que é exatamente a ordem que a norma descreve como "roda na árvore pré-correção [via reconstrução do motor] e é observado" (a reconstrução da árvore pré-correção é responsabilidade do `replay`, não de rodar o teste manualmente antes de existir o que reverter).

- Propriedades/PBT: não se aplica — o domínio é controle de fluxo de shell, não invariante de dados.
- Teste que protege a §3: a suíte completa (`tests/run-all.sh`) já cobre o veredito de cada gate; rodá-la ANTES e DEPOIS da correção, comparando que nenhum veredito muda, é o teste que guarda "comportamento que deve permanecer inalterado".

### 5.1 Declaração de evidência do Red

A preencher via `/forge:red record` na primeira task da implementação (`evidence/red/red-evidence.json`, schema `red-evidence/v1`) — não preenchido manualmente aqui, conforme a norma (o campo é uma declaração verificada por execução real, não por edição direta do artefato).

## 6. Rastreabilidade

- Origem: `LDG-0012` (ledger durável, promovido a este change — ver `manifest.yaml > ledger_origin`).
- Descoberto na sessão de 2026-08-04 durante o diagnóstico do `w32-archive-gate` (nota original do ledger).
- Achado adicional desta análise (§1-b, o ramo de passagem silenciosa) não estava documentado na entrada original do ledger — a severidade real do defeito é maior do que a descrição original registrava.
- Achado incidental fora de escopo: `tests/w111-liaison-sync-gate.sh:259` é uma asserção vazia (sempre `true`) — candidato a um novo item de ledger (`known-bug`, P3), não corrigido por este change.
