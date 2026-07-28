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

## Links

- Rule derivada: `template/.forge/rules/testing/regression-red-first.md`
- Schema: `template/.forge/schemas/red-evidence.schema.json`
- Precedente de enforcement ausente: bloqueio de deferrals (§17.4) sem script leitor de `deferrals.json`
- Fricção de brownfield: issues #20 e #21
