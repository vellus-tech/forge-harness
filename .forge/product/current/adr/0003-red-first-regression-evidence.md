# 0003. Red-first em bugfix: evidência declarada + replay determinista

- **Status:** accepted
- **Data:** 2026-07-28
- **Decisores:** Milton (gate HITL da Onda A)

## Contexto e Problema

O template de bugfix (`templates/bugfix/bugfix.md`, §5) já pedia um "teste que reproduz o bug (falha antes da correção, passa depois)" na forma de checkbox. Checkbox é declaração de intenção: nada no harness confere que o teste algum dia falhou, que falhou por comportamento e não por build quebrado, ou que falhou pelo defeito descrito. Na prática, um teste de regressão que nunca foi visto vermelho pode estar verde pelo motivo errado — mock complacente, asserção fraca, caminho de código que não é o do defeito — e a regressão volta sem que ninguém perceba.

O precedente interno é concreto e desconfortável: o bloqueio de deferrals do próprio harness — "o change não pode concluir com deferral `open`" — é **puramente protocolar**. Nenhum script lê `deferrals.json` para impedir a transição; a garantia depende de o agente lembrar de olhar. Regra normativa sem enforcement determinista é, empiricamente, regra ignorada. Repetir esse padrão no Red-first significaria escrever uma rule que soa rigorosa e não muda nada.

## Drivers da Decisão

- **Determinismo onde for possível** (constitution, item 3): a decisão do gate deve sair de script, não de julgamento do modelo.
- O custo do falso-verde em bugfix é assimétrico — o defeito reaparece em produção com a suíte verde.
- Fricção de brownfield é regressão conhecida do harness (issues #20/#21): repositório sem suíte instalada não pode ser travado.
- Evidência precisa ser reproduzível por terceiro, não apenas afirmada por quem escreveu.

## Opções Consideradas

1. **Checkbox honor-system** — manter a §5 como está.
2. **Coverage-diff** — exigir que as linhas corrigidas apareçam cobertas no diff de cobertura.
3. **Evidência declarada + replay determinista, com bloqueio opt-in** — registrar a observação do Red (teste, comando, commit base, padrão de falha, trecho e hash da saída) e reconstruir a árvore pré-correção para reproduzi-la.
4. **Bloquear tudo, sem exceção** — nenhum bugfix conclui sem Red observado, inclusive em brownfield sem suíte.

## Decisão

**Opção 3 — evidência declarada + replay determinista.** `/forge:red record` grava `evidence/red/*.json` conforme `schemas/red-evidence.schema.json`; `red-evidence.sh replay <change-id>` reconstrói a árvore no `base_commit`, roda o teste declarado e exige falha comportamental casando com o padrão registrado, mais passagem em HEAD. A prova é a reprodução, não a declaração — evidência declarada e nunca replicada não conta.

O regime de bloqueio é deliberadamente estreito e não rebaixável por modo: ausência de evidência em change `type: bugfix`, teste que já passava na base, falha classificada como erro de build, ou saída que não casa com o padrão declarado. Tudo o mais — inclusive o proxy de alcançabilidade do teste até os arquivos corrigidos no grafo — **avisa**, porque a alcançabilidade estática não enxerga injeção de dependência, reflexão, e2e sobre processo HTTP nem message bus, e transformar esse sinal em veto produziria falso-positivo em código legítimo. Os casos em que o Red não é possível saem por waiver tipado (`non-behavioral`, `no-test-infra`, `external-unreproducible`, `hotfix-under-incident`), com deferral e dívida técnica registrados onde couber.

**Opção 1 descartada** — é o que já existe e não funciona; é a origem do problema, não a solução. **Opção 2 descartada** — coverage-diff mede linha executada, não comportamento observado: uma linha coberta por um teste que passaria de qualquer jeito satisfaz a métrica sem provar nada sobre o defeito, e o custo de instrumentação de cobertura por stack é alto para uma garantia mais fraca. **Opção 4 descartada** — travar brownfield sem suíte repete exatamente a fricção das issues #20/#21, em que o pre-push bloqueou push em repositório sem `node_modules`; o waiver `no-test-infra` preserva o sinal (deferral aberto, dívida no ledger) sem travar quem ainda não tem a infraestrutura.

## Consequências

- **Positivas:** o item mais frágil do bugfix — "o teste realmente reproduz o defeito?" — deixa de ser autodeclaração e passa a ter prova reproduzível por terceiro; o critério de bloqueio é decidido por script, coerente com o item 3 da constitution; brownfield e incidente têm saída explícita e auditável, em vez de saída informal; o schema versionado (`red-evidence/v1`) permite evoluir o gate sem reescrever changes antigos.
- **Negativas/débitos:** permanece um resíduo honor-system — o replay prova que houve falha comportamental reprodutível e específica, não que ela seja *semanticamente* o defeito relatado, e não uma quebra adjacente que casa com o padrão; o replay tem custo real de tempo, pois reconstrói a árvore pré-correção e roda a suíte alvo mais de uma vez, o que o torna inadequado para loop apertado de desenvolvimento e o coloca no `/forge:verify`, não no salvamento de arquivo; o waiver `non-behavioral` depende do grafo de código estar atualizado para recusar diffs que tocam código, herdando a cobertura por linguagem do extractor (ADR-0001).

## Adenda — a primeira implementação da Opção 3 era circular (Onda B/C, rejeitada)

As duas primeiras rodadas de implementação tentaram fechar "evidência declarada e nunca replicada não conta" **acrescentando campos ao artefato** `evidence/red/red-evidence.json`: primeiro `excerpt`/`classification` (Onda B), depois `replayed_at`/`replay_head` (Onda C, na tentativa de detectar que um `status: observed` nunca tinha passado pelo motor de replay). A auditoria seguinte derrubou as duas pela mesma razão estrutural: **todo campo do artefato é escrito por quem está sendo verificado**. O check estático (`check-red-first.mjs`) decidia "houve replay?" lendo `data.replayed_at`/`data.replay_head` do próprio JSON — um autor podia escrever esses dois campos à mão, com um `replay_head` igual ao HEAD atual e um `excerpt`/`classification`/`excerpt_sha256` internamente consistentes, e o check aprovava sem que nenhum teste jamais tivesse rodado de verdade. Nenhum campo novo resolveria isso — qualquer terceira tentativa na mesma direção (mais um campo auto-declarado) falharia pelo motivo idêntico.

A correção (Onda D) moveu a prova do **artefato** para a **execução**: `evidence/red/red-evidence.json` continua sendo a declaração da intenção verificável (qual teste, qual comando, qual padrão de falha, quais arquivos), mas nenhum campo dele decide "observado" sozinho. `/forge:verify` e o pré-flight de `/forge:archive` passaram a **executar o replay incondicionalmente** para todo change `type: bugfix`, com um cache local (`.forge/cache/red-replay/`, fora do versionado, chaveado por `hash(artefato) + commit que tocou test_path/fix_files`) como único atalho de custo — cache é escrito unicamente por uma execução real e nunca é lido como prova para um terceiro (outro clone, outro CI), só como "não preciso re-rodar isto que acabei de rodar". `replayed_at`/`replay_head` permanecem no schema como metadado informativo (quando o último replay rodou), mas nenhum caminho de decisão os lê. Esse desenho também fechou, de graça, um livelock relatado na Onda C: comitar a própria evidência mudava o HEAD do repositório e invalidava uma corroboração ancorada em "HEAD inteiro"; ancorar no commit que toca especificamente `test_path`/`fix_files` remove essa dependência espúria.

Documentado aqui em vez de apagado da história porque um ADR que esconde a alternativa que foi tentada e falhou perde a serventia — a lição ("nenhum campo do artefato prova a si mesmo") é generalizável a qualquer gate futuro que precise distinguir declaração de observação.

## Adenda 2 — o cache local (Onda D) também caiu, pelo mesmo motivo estrutural (Onda E, rejeitada)

O cache local descrito na Adenda 1 era, na prática, uma **terceira tentativa** de resolver o mesmo problema sem reler campo algum do artefato: em vez de um campo auto-declarado, um arquivo local (`.forge/cache/red-replay/<change-id>.json`) escrito unicamente por uma execução real, chaveado por `hash(artefato) + commit que tocou test_path/fix_files`. Isso corrigia o defeito estrutural das duas primeiras tentativas — o cache não é escrito por quem está sendo verificado no sentido em que os campos do JSON são, porque só uma execução real do motor o produz. Mas trouxe dois problemas próprios, descobertos numa auditoria de brownfield:

1. **Versionável por acidente.** `.forge/cache/` só entra no `.gitignore` quando o installer acrescenta o bloco `# >>> forge (managed) >>>` — e ele só faz isso quando o marcador está **ausente**. Projetos que instalaram o harness antes deste patch (axis-go-cloud, axis-fare-validator, collatra, azim-crm, entre outros) nunca receberiam a linha nova automaticamente; o cache de replay virava artefato versionado por omissão de atualização do `.gitignore`, não por decisão de ninguém.
2. **Fonte de livelock.** A chave do cache dependia de HEAD (na primeira formulação) ou do commit mais recente que tocasse `test_path`/`fix_files` (na correção); em ambos os casos, o gate de verify/archive podia entrar num ciclo de invalidação-reexecução em cenários de commit intercalado que não deveriam ter relação com o conteúdo do teste.

Mas o problema mais sério não era nenhum dos dois acima — era o que a auditoria seguinte (Onda E) revelou sobre os PRÓPRIOS TESTES do gate: w106 havia crescido, ao longo de três rodadas, para **exigir** que evidência fabricada e cache fabricado passassem com sucesso — helpers como `write_ev_d` e `write-cache.mjs` escreviam o cache local diretamente (sem nunca invocar o motor de replay de verdade) só para que os itens rebaixáveis (5–8) pudessem chegar a `status: observed`. O teste virou proteção do próprio furo: qualquer correção genuína no design (por exemplo, remover o cache) fazia o gate ficar vermelho e seria lida como regressão, não como o comportamento certo. Esse é o padrão que este ADR já havia identificado na Adenda 1 sob outra forma — "o atalho vira, ele mesmo, o alvo que os gates passam a exigir para aprovar" — só que desta vez o alvo era o teste do gate, não o gate em si.

**Decisão (Onda E):** o cache local foi removido por inteiro (`lib/red-replay-cache.mjs` apagado, todo consumo removido). `ensure` — chamado por `/forge:verify` e pela transição para `verified` (`validate-spec.mjs`) — passa a executar o motor de replay **sempre**, sem nenhum atalho de custo. O único caminho que permanece sem execução é `check-red-first.sh check` sozinho (usado por `pre-push`/`doctor`, que precisam ser rápidos): ele confirma o que é estático — completude, classificação real do excerto, casamento com `failure_pattern`, e que um waiver referencia um deferral/ledger que existe de verdade — mas não confirma que um replay real aconteceu por trás de `status: observed`. Uma evidência editada à mão com campos internamente consistentes passa por esse check sozinho; isso é um **limite aceito e documentado**, não um descuido, porque a garantia real está nos dois gates que decidem de fato (`/forge:verify` e a transição para `verified`), que sempre executam o replay antes de avaliar.

O custo é real: o teste declarado roda de novo a cada `/forge:verify` e a cada transição para `verified` — medido no gate w107 em ~1s por chamada de `ensure` para uma fixture Node mínima (`node --test` sobre um único arquivo), pago toda vez, sem hit de cache algum. Aceito deliberadamente: um atalho local havia se tornado, duas vezes seguidas, o alvo que a própria suíte de testes do harness passava a exigir para aprovar — o custo de sempre executar é menor que o custo de manter uma suíte de testes que protege um furo.

A generalização da lição da Adenda 1 fica mais precisa: não é só "nenhum campo do artefato prova a si mesmo" — é **"nenhum estado produzido inteiramente pela parte sendo verificada, dentro de um ambiente que ela controla, prova nada a um terceiro adversarial"**. Campo de JSON, cache local, qualquer atalho futuro na mesma família cairá pelo mesmo motivo. A norma correspondente (`rule testing/regression-red-first.md`, seção "O limite desta norma") deixou de tentar fechar essa classe inteira e declara, com todas as letras, que ela é calibrada para a ameaça de **descuido**, não de autor adversarial — e nomeia os três vetores que continuam abertos por decisão, não por lacuna esquecida: comando declarado arbitrário, defeito introduzido no próprio PR, e waiver com justificativa externamente inverificável. Fechar esses três de verdade exige mover a execução para um ambiente que o autor não controla (ver item de roadmap no ledger do projeto) — não mais um campo, nem mais um cache.

## Links

- Rule derivada: `template/.forge/rules/testing/regression-red-first.md`
- Schema: `template/.forge/schemas/red-evidence.schema.json`
- Precedente de enforcement ausente: bloqueio de deferrals (§17.4) sem script leitor de `deferrals.json`
- Fricção de brownfield: issues #20 e #21
- Cache local de replay (removido na Onda E — ver Adenda 2): histórico em `template/.forge/scripts/lib/red-replay-cache.mjs` até o commit que o apagou
