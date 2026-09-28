# Análise do benchmark — skill `data-relational-practices`

Fonte: `.forge/evals/skills/data-relational-practices/workspace/iteration-1/benchmark.json` (gerado por `aggregate_benchmark`, run em 2026-09-28). 3 evals (`pedidos-pagamentos-sem-adr`, `revisao-migracoes-tarifas-config`, `validador-legado-mysql`), 1 execução por configuração cada — não 3 repetições por eval, apesar do rótulo `runs_per_configuration: 3` do metadata (esse campo conta evals, não repetições; não há dado de variância intra-eval).

## Resultado agregado

| Config | pass rate médio | min–max | tempo médio |
|---|---|---|---|
| with_skill | 83,33% (0,8333) | 50%–100% | 180,0 s |
| without_skill | 25,56% (0,2556) | 0%–60% | 120,3 s |

Delta = +0,58 (0,8333 − 0,2556). Veredito: **agrega** (delta ≥ 0,15, com folga larga).

benchmark_ok = true (agregação rodou de primeira, sem correção de estrutura).

## Padrões por eval

- **`pedidos-pagamentos-sem-adr` (conflito ADR × data-governance.md):** with_skill 5/5 (100%), without_skill 0/5 (0%). É o contraste mais nítido do lote e a validação mais forte do design da skill: com a skill, o agente emite o bloco `CONFLITO`, reconhece que o ADR-0001 exclui pedidos/pagamentos do escopo (não pode ser invocado como autorização) e não cria `V003__pedidos_pagamentos.sql`. Sem a skill, o agente lê o "fora de escopo" do ADR-0001 mas mesmo assim conclui "não há decisão de motor a tomar" e cria as tabelas em Postgres — exatamente o antipattern que a seção "Escopo" do `SKILL.md` (linha 13) foi escrita para prevenir.
- **`revisao-migracoes-tarifas-config` (revisão de migração Postgres):** with_skill 3/6 (50%), without_skill 1/6 (16,67%). É o eval mais fraco para a skill em termos absolutos, apesar de melhorar 3x sobre a baseline. Ver "onde a skill não fechou" abaixo.
- **`validador-legado-mysql` (revisão de migração MySQL + retry de deadlock):** with_skill 5/5 (100%), without_skill 3/5 (60%). A baseline sem skill já acerta boa parte por competência genérica do modelo (códigos de erro do MySQL, nível de isolamento do InnoDB); o que falta sem a skill é disciplina de citação de id do catálogo (`R-22`, `R-13`), que a skill impõe no protocolo (passo 5: "todo antipattern apontado cita o id").

## Asserções não discriminantes (passam nas duas configurações)

Três asserções do eval `validador-legado-mysql` passaram em ambas as configurações e não diferenciam o valor da skill: (1) códigos MySQL 1213=deadlock / 1205=lock wait timeout com retry corrigido reprocessando o lote inteiro; (2) correção de que o isolamento default do InnoDB é REPEATABLE READ, não READ COMMITTED; (3) não sinalizar `20260815_idx_dispositivo.sql` (já correta) como achado. São conhecimento geral de MySQL/InnoDB, não prática específica do catálogo da skill — o modelo já os tem sem o artefato. No `revisao-migracoes-tarifas-config`, a asserção sobre não converter `fator_tarifa`/`taxa_desconto_percentual` para BIGINT (são fator/percentual, não dinheiro) também passou nas duas.

## Padrão que falha nas duas configurações

A asserção do eval `revisao-migracoes-tarifas-config` que exige "uma entrada por regra examinada com status explícito (achado, OK/limpo ou não verificado)" falhou tanto com quanto sem a skill. O `SKILL.md`, passo 5 do protocolo, exige literalmente isso ("Uma linha por regra, inclusive as limpas"), mas o relatório produzido com a skill lista só as regras com achado — nenhuma linha "OK/limpo" para as regras sem problema. A instrução existe no artefato; o executor não a aplicou. Isso não é lacuna de conteúdo da skill, é lacuna de conformidade/checklist: nada no protocolo força reconciliação contra a lista completa de ids do catálogo antes do relatório final.

## Onde o artefato ajudou

- Protocolo de conflito ADR × rule (seção "Escopo" + bloco `CONFLITO`): eval `pedidos-pagamentos-sem-adr` vai de 0% para 100%, o ganho mais alto e mais acionável do lote — evita criação de schema fora de governança.
- Disciplina de citação de id do catálogo (`R-NN`) exigida no passo 5 do protocolo: eleva `validador-legado-mysql` de 60% para 100%, mesmo quando a substância técnica sem a skill já estava correta.
- Reconhecimento de RLS como obrigatório (não sugestão) via `data-governance.md`, e SQL corrigido com `ENABLE`/`FORCE ROW LEVEL SECURITY` + `CREATE POLICY`: presente com a skill em `revisao-migracoes-tarifas-config`, ausente (tratado como sugestão genérica) sem ela.

## Onde o artefato atrapalhou ou não fechou

- **Custo de tempo:** with_skill roda ~50% mais devagar em média (180s vs 120s, +59,7s) — plausível pelo protocolo de 5 passos (ler `rules/`, rodar `scan.sh` + `check-data-governance.sh`, julgar cada `FOUND`) rodar por completo mesmo em pedidos pequenos. Não dá para confirmar a causa com os dados agregados: os campos `tokens`/`tool_calls` vieram zerados em todas as execuções (não instrumentados pelo executor), então não há como decompor o tempo extra em leitura de referências vs. execução de scripts vs. escrita do relatório.
- **Correção técnica incompleta mesmo com a skill:** no eval `revisao-migracoes-tarifas-config`, a correção do `SET NOT NULL` não usou `CHECK (...) NOT VALID` + `VALIDATE CONSTRAINT` — optou por `ADD COLUMN ... DEFAULT 0 NOT NULL`, que evita o full-scan sob lock mas não é o padrão prescrito. E a correção de RLS não mencionou que o papel da aplicação precisa ser diferente do dono da tabela e criado sem `BYPASSRLS`. As duas exigências estão documentadas em `references/antipatterns.md` (R-03 linha 24: "`CHECK (...) NOT VALID` + `VALIDATE CONSTRAINT` antes de `SET NOT NULL`"; R-20 linha 143: "papel da aplicação diferente do dono... criado com `NOBYPASSRLS`"), ou seja, o conteúdo certo já existe no artefato — o executor não o superfíciou no relatório final. Indica um ponto cego do protocolo: o passo 4 ("Julgamento") não força releitura da seção "Correção" de cada entrada do catálogo linha a linha antes de redigir o relatório.
- **Rename in-place:** a asserção esperava que a correção do `RENAME COLUMN` seguisse expand→migrate→contract; o relatório com a skill preferiu recomendar não fazer o rename (mantendo o nome já correto pela convenção do projeto) — tecnicamente defensável e coerente com a seção "naming" do próprio relatório, mas não bate com o critério literal da asserção. É mais um desalinhamento de asserção rígida do que falha do artefato: a skill não instrui "sempre fazer expand→migrate→contract mesmo quando o nome já está certo".

## Trechos ignorados, ambíguos ou contraditórios no artefato

- A linha 27 do `SKILL.md` ("a rule declara `applies_to` para .NET, React e Kotlin; ... esta skill estende a mesma recomendação a toda stack... por conta própria, sem mudar o `applies_to` da rule, e diz isso na resposta") foi seguida de forma fraca no eval 1: o grader aceitou como "atende ao núcleo... de forma fraca" porque o relatório citou a extensão e a decisão do dono, mas não enumerou explicitamente o `applies_to` original (.NET/React/Kotlin). Não é ambiguidade do artefato — é a instrução sendo seguida parcialmente pelo executor.
- Nenhuma contradição interna encontrada no `SKILL.md` nem entre ele e `references/antipatterns.md`: as correções que faltaram no relatório do executor (CHECK NOT VALID/VALIDATE CONSTRAINT, NOBYPASSRLS) estão documentadas de forma inequívoca na referência; o gap é de aplicação, não de conteúdo.
- A seção "O que o scanner não faz" é densa (uma frase-parágrafo cobrindo R-01, R-02, R-05, R-09, R-16, regras de MySQL vs. Postgres, universo do harness) — nenhuma evidência direta de que isso causou erro nesta rodada, mas é candidata a ponto de atenção/redução de carga cognitiva por densidade, não por conteúdo errado.

## Melhorias concretas, priorizadas

1. **Adicionar um passo de reconciliação final ao protocolo** (novo passo 5, empurrando o atual "Relatório" para 6): antes de escrever o relatório, o agente confere cada `FOUND` contra a "Correção" completa da entrada correspondente em `references/antipatterns.md` (não só o "Por quê") e cada entrada do catálogo sem achado ganha uma linha "OK/não verificado" explícita. Ataca diretamente os dois gaps mais caros observados (SET NOT NULL/CHECK NOT VALID, RLS/NOBYPASSRLS, tabela de status completa) e o único padrão que falhou nas duas configurações.
2. **Adicionar ao catálogo/SKILL.md uma nota de "não regredir o nome já correto"** para o antipattern de rename in-place, cobrindo o caso em que a convenção do projeto já bate com o nome atual (a skill hoje só descreve o caso de rename necessário). Reduz falso-negativo do tipo "recomendação certa, mas em formato diferente do esperado" — risco baixo, mas evita ambiguidade de interpretação em revisões futuras.
3. **Instrumentar tempo/tokens/tool_calls no harness de eval** (fora do escopo do artefato, mas bloqueia diagnóstico): sem esses campos populados, não dá para saber se os 60s extras de with_skill vêm da leitura de `references/`, da execução de `scan.sh`/`check-data-governance.sh` ou de retrabalho no relatório — o que limita qualquer decisão futura de "vale o custo de tempo".
4. **Considerar reforçar, com um exemplo curto, a citação obrigatória do `applies_to` original da rule estendida (dinheiro)** na seção "Regras da casa" — o gap observado foi de aplicação fraca, não de ausência da instrução, mas um exemplo concreto de frase-modelo reduziria a chance de omissão.

Nenhuma dessas melhorias foi aplicada nesta análise (escopo é só benchmark/análise, sem editar o artefato).
