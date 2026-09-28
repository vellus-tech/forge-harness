# Análise de benchmark — agente `design-writer`

Fonte: `.forge/evals/agents/design-writer/workspace/iteration-1/benchmark.json` (regenerado nesta rodada via `scripts.aggregate_benchmark`, determinístico, 3 evals × 1 run por configuração — o `runs_per_configuration: 3` do metadata é herdado do template do script e não reflete runs reais; há só `run-1` em cada branch, então stddev entre "runs" é na prática variância entre os 3 casos, não entre repetições do mesmo caso).

## Resultado

| Configuração | Pass rate médio | min–max | Tempo médio |
|---|---|---|---|
| Com skill (agente) | 94,33% | 83%–100% | 211,7 s |
| Sem skill | 54,33% | 33%–80% | 144,3 s |
| **Delta** | **+0,40** | | +67,3 s |

Veredito: **agrega** (delta 0,40 ≥ 0,15). `benchmark_ok = true` — o script rodou limpo, sem correção de estrutura necessária. Tokens não são medidos (`timing.json` grava `total_tokens: 0` nos seis runs) — métrica indisponível na instrumentação atual, não uma lacuna do artefato.

## Asserções não discriminantes

Nenhuma asserção passa 100% em ambas as configurações — todas as 15 (6+6+5, com duplicatas conceituais entre evals) diferenciam a presença da skill em pelo menos um caso. A mais próxima de não discriminar é "identificadores RF/RNF/PBT rastreados" no eval 1, que passa em ambas as configurações (True/True) — o agente base já cita os IDs no corpo do texto mesmo sem a skill; o que a skill agrega ali é a *estrutura* ao redor desses IDs, não a citação em si.

## Onde o artefato ajudou (evidência de transcript/grading)

- **Estrutura obrigatória de 20 seções**: sem skill, o agente produziu só 8 headings livres ("## 1. Visão geral" .. "## 8. Riscos e pontos em aberto"), omitindo `## 14. Multi-tenancy` e `## 17. Decisões Inline` por inteiro (`eval-escreve-design-recarga-aprovada/without_skill/run-1/grading.json`). Com skill, as 20 seções e as subseções 16.1–16.5 aparecem na ordem exigida — efeito direto da seção "Estrutura Obrigatória" do artefato, que lista o esqueleto completo e proíbe omissão.
- **Cabeçalho com `Status` explícito**: sem skill, o cabeçalho usa rótulos livres ("Baseado em" em vez de "Referência base", sem campo `Status`); com skill, os cinco campos do cabeçalho (Versão/Data/Status/Referência base/ADRs aplicáveis) aparecem literalmente — efeito da seção "Estrutura Obrigatória" copiada quase ao pé da letra pelo agente.
- **Decisões inline DD-NNN**: sem skill, zero ocorrências de `### DD-` ou dos cinco rótulos (**Contexto**/**Decisão**/**Justificativa**/**Alternativas**/**Impacto**); com skill, o formato completo aparece — efeito direto do template em "Decisões Inline DD-NNN".
- **Kafka vs. RabbitMQ (eval 2, o caso mais crítico)**: sem skill, o agente adotou Kafka como pedido pelo usuário, sem registrar conflito com ADR-0002; com skill, o Kafka foi recusado e registrado como conflito com recomendação de nova ADR — efeito direto da regra "Tecnologia é aceitável quando já está definida em ADR... Quando houver dúvida, registre alternativa e decisão inline DD-NNN" combinada com "Design que contradiz ADR aceita exige nova ADR ou registro explícito de conflito" em Status e Versionamento.
- **Bloqueio explícito quando requirements está em rascunho (eval 3)**: sem skill, o agente escreveu "o time pode quebrar em tasks hoje mesmo" — o oposto do bloqueio esperado — apesar de citar a versão 0.3.0/Rascunho no cabeçalho; com skill, o bloqueio foi declarado explicitamente. Efeito da seção "Arquivos que Você Deve Ler" ("Se o requirements.md não existir ou não estiver aprovado, não produza um design definitivo... Gere apenas uma análise de bloqueio") e do primeiro anti-pattern listado.
- **Rastreabilidade RF-06/PBT-03 na seção de Testes (eval 2)**: sem skill, a seção de testes citou só PBT-01/PBT-02 pré-existentes e não amarrou o novo RF-06/PBT-03 a um teste; com skill, a ligação apareceu. Efeito da seção "Testes" ("Cada requisito crítico deve ter cobertura indicada") e do "Princípio Central de Rastreabilidade".

## Onde o artefato atrapalhou ou não bastou

- **Saldo em centavos não modelado (eval 1, único fail *com* skill)**: o design com skill declara `valor_em_centavos` na tabela de recarga, mas nunca declara o **saldo do cartão** como campo persistido com unidade explícita — só menciona "credita saldo" em prosa (`design.md:19,67,82,122,323`). PBT-01 do `requirements.md` exige explicitamente "o saldo final é o saldo inicial + valor da recarga", então a grandeza é parte do contrato, mesmo que a persistência do saldo em si viva na bilhetagem (outro bounded context). O artefato instrui "money como float/double" e "decimal em cálculo monetário" como anti-patterns, mas não cobre o caso de uma grandeza monetária referenciada por um PBT que é *emitida* (evento) e não *armazenada* neste módulo — o agente tratou "saldo" como responsabilidade alheia e nunca tipou a grandeza em nenhum lugar auditável (nem no payload do evento `RecargaPaga`, nem numa nota explícita).
- **Trecho potencialmente desperdiçado — duplicação de referência a ADR**: linhas 77–78 do artefato repetem `docs/product/adr/` duas vezes na lista de "Fontes de produto, domínio e arquitetura" (provável erro de copy-paste, sem efeito funcional observado nos transcripts, mas é ruído que não agrega).
- **Ambiguidade sobre limite de tamanho do design**: o artefato não define um teto de linhas/seções vazias aceitável; nos transcripts, o design com skill do eval 1 passou de 400+ linhas para cobrir as 20 seções, o que aumentou o tempo (272s vs. 128s no mesmo eval) sem que a skill oriente quando é aceitável condensar seções pouco relevantes ao módulo além do rótulo genérico "Não aplicável nesta versão" — não chegou a causar falha de asserção, mas é o maior fator de custo de tempo observado.

## Padrões cross-eval

- O eval 2 (edição de design já aprovado) é o mais discriminante: 100% com skill vs. 50% sem skill, e é o único onde a ausência da skill produz uma violação de arquitetura ativa (adoção de Kafka contra ADR aceita) em vez de só uma omissão estrutural.
- O eval 3 (recusa) é o que sem skill mais se aproxima do comportamento correto (80% mesmo sem skill) — o modelo base já tende a sinalizar "requirements em rascunho" no cabeçalho; o que falta sem a skill é a declaração *explícita* de bloqueio na resposta final, não a detecção do estado.
- Tempo médio com skill é ~1,47× o tempo sem skill (211,7s vs. 144,3s) — custo aceitável dado o delta de 0,40 em pass rate; não há evidência de tempo desperdiçado em retrabalho (sem re-leituras ou edições revertidas nos transcritos revisados).

## Qualidade dos casos (eval_quality)

Os três casos são de boa qualidade — bem discriminantes, com fixtures realistas (ADRs, glossário, requirements versionado) e asserções ancoradas em evidência textual verificável (greps, diffs), não em julgamento subjetivo. Pontos de atenção:

- `benchmark.json`/`evals.json` só registram 1 run por configuração apesar do metadata dizer `runs_per_configuration: 3` — os "3" na verdade são os 3 evals distintos, não repetições. Isso limita a leitura de variância intra-caso (não dá para saber se o fail do eval 1 com skill é sistemático ou um artefato de uma única amostra). Recomenda-se rodar ≥2 repetições por (eval, configuração) antes de decisões de merge/regressão baseadas neste benchmark.
- A asserção "saldo... em centavos" do eval 1 é boa (ancorada em PBT-01, não arbitrária), mas é a única do lote que exige inferência sobre uma grandeza que pode legitimamente viver fora do módulo — vale documentar no próprio eval, como comentário, que o item também é satisfeito se o design declarar explicitamente que o saldo é responsabilidade de outro bounded context e tipar a grandeza no payload do evento, para não penalizar um design correto que apenas emite a informação em vez de persisti-la.
- `total_tokens: 0` em todos os `timing.json` — métrica de custo de tokens não instrumentada nestes fixtures; a análise de custo ficou limitada a tempo de parede.

## Melhorias concretas priorizadas

1. **Alta prioridade — corrigir a lacuna de saldo/grandezas externas.** Adicionar à seção "5. Persistência e Schema" (ou a "7. Schema / Modelo de Persistência" na estrutura obrigatória) uma regra explícita: *"Quando uma grandeza monetária referenciada por um requisito ou PBT não é persistida neste módulo (ex.: saldo mantido por outro bounded context), declare seu tipo e unidade (centavos) no ponto onde ela aparece pela primeira vez — payload de evento publicado, command ou nota explícita — em vez de tratá-la apenas em prosa."* Isso fecha o único fail residual com skill observado no benchmark.
2. **Média prioridade — remover a duplicação de `docs/product/adr/`** nas linhas 77–78 da seção "Arquivos que Você Deve Ler" (ruído de leitura, sem efeito funcional, mas barato de corrigir).
3. **Média prioridade — orientar poda de seções não aplicáveis.** Acrescentar uma frase à seção "Estrutura Obrigatória" balizando quando condensar uma seção "Não aplicável nesta versão" em uma linha vs. desenvolvê-la, para conter o crescimento de tempo/tamanho sem ferir a regra de não omitir seções.
4. **Baixa prioridade — reforçar teste de regressão do benchmark.** Não é mudança no artefato, é mudança no processo de avaliação: rodar `runs-per-configuration >= 2` de fato (hoje o script aceita o parâmetro mas os fixtures só têm `run-1`) antes de usar este benchmark para decisão de merge, para distinguir falha sistemática de amostragem única.

## Rastro de execução (conforme REGRAS do BOOTSTRAP)

- Passo 1 (agregação): executado com sucesso, script real (`python3 -m scripts.aggregate_benchmark`), sem necessidade de correção — saída "Summary: With Skill 94.3% / Without Skill 54.3% / Delta +0.40".
- Passo 2 (viewer estático): executado com sucesso — `review.html` gerado em `workspace/iteration-1/review.html` (156 KB).
- Passo 3–4 (esta análise): baseada em leitura de `agents/analyzer.md` (seção "Analyzing Benchmark Results"), dos 6 `grading.json`, do `evals.json` e do artefato `design-writer.md` (775 linhas) — sem subagentes spawnados (não autorizado pelas regras do bootstrap).
