# Análise do benchmark — agente `nfrd-generator`

Fonte: `.forge/evals/agents/nfrd-generator/workspace/iteration-1/benchmark.json` (agregação determinística via `scripts.aggregate_benchmark`, sem cálculo manual). 3 evals × 2 configurações × 1 run cada.

## 1. Resultado

| Eval | with_skill | without_skill |
|---|---|---|
| 1 — nfrd-validador-embarque-do-prd | 5/6 = 0,8333 | 1/6 = 0,1667 |
| 2 — atualiza-nfrd-com-recarga-pix | 6/6 = 1,0000 | 6/6 = 1,0000 |
| 3 — recusa-sem-prd-portal-lojista | 4/4 = 1,0000 | 1/4 = 0,2500 |

`run_summary`: com skill 94,44% (stddev 0,0962), sem skill 47,22% (stddev 0,459). Delta = 0,9444 − 0,4722 = **+0,4722**.

**Veredito: agrega** (delta ≥ 0,15, `benchmark_ok = true` — o script rodou de primeira, sem erro de estrutura).

O tempo de execução subiu de 118 s (sem skill) para 220,7 s (com skill), +102,7 s em média — custo aceitável dado o ganho de 47 pontos percentuais em taxa de aprovação, mas concentrado no eval 1 (350 s), o mais longo dos três.

## 2. Asserções não discriminantes

O **eval 2 inteiro não discrimina**: as duas configurações passam 6/6. O próprio `grading.json` da execução já sinaliza isso (`eval_feedback.overall`: "as asserções são corretas mas fracas para A/B: um modelo competente sem o agente satisfaz todas"). As asserções de controle de versão, IDs preservados, matriz e referência ao ADR-0002 passam em ambos os lados sem diferenciar o valor do agente — nenhuma delas testa exatamente o ponto onde os dois transcritos divergem de fato (ver §3).

Dentro dos evals 1 e 3, uma asserção específica é fraca mesmo discriminando no agregado: "todos os requisitos têm Meta preenchida (nenhum vazio ou só '—')" aceita texto não numérico como meta ("RTO e RPO numéricos — Proposto pelo NFRD — validar com produto"), o que não é uma meta verificável apesar de passar.

## 3. Onde o artefato ajudou ou atrapalhou

**Ajudou, com evidência de transcript/grading:**

- **Caminho de saída.** O artefato fixa `docs/product/frd-nfrd/nfrd.md` (§5). Sem o skill, o executor do eval 1 escreveu em `docs/product/nfrd/nfrd.md` — transcript: "usei o padrão irmão do PRD (docs/product/nfrd/)" — reprovando a primeira asserção e todas as que dependiam desse caminho.
- **Decisão por categoria (§7 da estrutura).** Sem o skill, o nfrd.md do eval 1 nem tem a seção; usa títulos livres por tema (Desempenho, Disponibilidade, Segurança...) sem decisão explícita Sim/Não das 14 categorias — falha direta contra o critério "nenhuma categoria sem decisão".
- **Formato de ID `NFR-<CAT>-NN` (§10.1).** Sem o skill: `NFR-AVAIL-01`, `NFR-SEC-01`, `NFR-AUDIT-01`, `NFR-REL-01`, `NFR-SCALE-01` — nenhum usa os 14 códigos do artefato, e os requisitos viram bullets em prosa sem os campos Meta/Método de medição/Fonte de dados da tabela do §7.
- **Recusa por PRD ausente (§4 "sem PRD, pare e sinalize").** No eval 3, com o skill o agente bloqueia explicitamente ("Geração bloqueada... cita `.forge/agents/specifications/nfrd-generator.md §4`"); sem o skill, o executor decide sozinho contornar a instrução implícita e escreve um "rascunho provisório" em `docs/product/frd-nfrd/nfrd.md` mesmo sem PRD — exatamente o comportamento que o contrato proíbe (§12: "gerar NFRD sem matriz..." / "inventar sem marcar"). Sem o texto explícito do agente, o modelo trata a ausência de PRD como uma preferência de estilo, não como um bloqueio.

**Atrapalhou ou não resolveu, mesmo com o skill:**

- **Marcador de premissa vaga mal posicionado.** O §7 do artefato define que o campo **Origem** da tabela do NFR deve conter literalmente uma das opções, incluindo `Proposto pelo NFRD — validar com produto`. No eval 1 com skill, o agente colocou esse texto no campo **Meta** (sem valor numérico) e escreveu uma paráfrase em Origem ("PRD §8 (Premissas) — jargão não verificável..."), falhando a única asserção que reprovou com o skill. O artefato define o marcador mas não amarra explicitamente "o marcador vai em Origem, a meta numérica em Meta" — a ambiguidade permite as duas leituras.
- **Resumo final inconsistente com o corpo (eval 2, com skill).** O `resultado-geracao-nfrd.md` §3 diz "Total: 10 NFRs (5 herdados + 5 novos)"; o `nfrd.md` real tem 12 seções `### NFR-` (5 herdados + 7 novos: PERF-02, ESC-01, RES-01, SEG-02, AUD-01, INT-01, OPS-01). O artefato pede "Total e distribuição por prioridade" no §11 mas não instrui a derivar esse número por contagem determinística do próprio arquivo gerado — ficou sujeito a erro de recontagem manual do modelo.
- **Referência cruzada quebrada.** O mesmo nfrd.md (linha 268) referencia "`§ADRs Sugeridos, abaixo`" como se essa seção existisse dentro do próprio `nfrd.md` — mas a tabela de ADRs Sugeridos vive apenas no resumo externo (`resultado-geracao-nfrd.md`), por instrução do §3.5/§11. O artefato não deixa claro que o nfrd.md nunca deve se autorreferenciar a uma seção que só existe fora dele.

## 4. Trechos do artefato ignorados, ambíguos, contraditórios ou que desperdiçam tempo

- **Ambíguo:** §7 define o campo "Origem" com quatro valores possíveis, incluindo os dois marcadores de incerteza, mas não repete essa exigência na "Regra de escrita" (§9) nem no "Critério de qualidade" (§8) de forma a impedir que o marcador migre para o campo "Meta" (causa raiz do único caso de falha com skill, eval 1).
- **Contraditório em potencial:** o Passo 3 (linha "quando a meta implicar decisão arquitetural durável, aplique a §3") e a §11 (Resultado da Geração, seção 6 "ADRs Sugeridos") não deixam explícito se o corpo do `nfrd.md` pode se referir a essa seção externa por nome — o agente assumiu que sim e quebrou a referência (ver §3 acima).
- **Ignorado na prática, sem penalidade:** a exigência de "meta mensurável (número com unidade) ou condição binária verificável — nunca 'alta performance'" (Passo 3 e §8) foi contornada com texto de placeholder tipo "RTO e RPO numéricos — Proposto pelo NFRD — validar com produto", que tecnicamente não é nem número nem condição binária, mas passa despercebido porque nenhuma asserção do eval barra esse padrão especificamente (ver §2, eval_feedback já aponta isso).
- **Não desperdiça tempo perceptível:** as seções do artefato (§1–§12) são todas referenciadas em algum momento pelos transcritos revisados; não há trecho grande e claramente morto. O maior gasto de tempo (350 s no eval 1) parece proporcional ao tamanho do NFRD gerado (30 NFRs, 15 seções), não a instrução redundante.

## 5. Melhorias concretas priorizadas

1. **[Alta] Amarrar o marcador de incerteza ao campo Origem, não à Meta.** No §7 (estrutura da tabela) e no §9 (regras de escrita), adicionar uma frase explícita: "o marcador `Proposto pelo NFRD — validar com produto` ou `Inferência Não Funcional` vai sempre no campo **Origem**; o campo **Meta** continua exigindo valor numérico ou condição binária mesmo quando a origem é inferida — nunca preencher a Meta só com o marcador." Isso resolve diretamente a única falha observada com skill ligado.
2. **[Alta] Tornar a contagem do resumo final determinística.** No §11 ("Quantidade de Requisitos"), instruir: "o Total deve ser igual à contagem de seções `### NFR-` do `nfrd.md` gerado nesta mesma execução — confira antes de declarar o número." Evita o desalinhamento observado (10 declarados vs. 12 reais).
3. **[Média] Proibir autorreferência cruzada entre nfrd.md e o resumo externo.** No §3.5/§11, adicionar: "o corpo do `nfrd.md` nunca deve dizer 'ver ADRs Sugeridos abaixo' ou equivalente — essa tabela vive só no resumo da resposta, fora do arquivo; no `nfrd.md`, cada NFR aponta apenas para o ADR específico (existente ou 'sugerido, a criar') via campo Dependência arquitetural."
4. **[Média] Fundir o eval 2 com uma asserção discriminante ou substituí-lo.** Como está, não mede o valor do artefato (6/6 nas duas configurações). Duas asserções sugeridas pelo próprio grading (já capturadas em `eval_feedback.suggestions` dos runs) resolveriam isso sem reescrever o eval: (a) toda meta/critério numérico sem origem direta no PRD deve trazer o marcador de proposta — reprova o without_skill, que inventou "até 5 notificações" e "auditoria trimestral" sem marcação; (b) o total do resumo deve bater com a contagem real de NFRs no arquivo — reprovaria o with_skill no bug do item 2 acima, tornando a asserção mais rigorosa nas duas direções.
5. **[Baixa] Fortalecer a asserção de "Meta preenchida" nos evals 1/2 para exigir valor numérico ou condição binária explícita**, não apenas texto não vazio — hoje aceita placeholders como "RTO e RPO numéricos — Proposto pelo NFRD" que contrariam a própria regra do artefato (§8/§9) sem serem pegos.

## 6. Qualidade dos próprios casos (eval_quality)

- **Eval 1** (nfrd-validador-embarque-do-prd) e **eval 3** (recusa-sem-prd-portal-lojista) discriminam bem (0,83 vs 0,17 e 1,0 vs 0,25) e cobrem cenários realistas e distintos: geração completa vs. recusa por insumo ausente. Boa cobertura de categorias (14 códigos), formato de ID e rastreabilidade.
- **Eval 2** (atualiza-nfrd-com-recarga-pix) é o ponto fraco do conjunto: zero poder discriminante nesta rodada. O `expected_output` é rico (preserva IDs, referencia ADR existente, revisa Decisão por Categoria) mas as asserções testam só o que ambas as configurações já acertam por bom senso (não deletar seções antigas, não recriar do zero, referenciar ADR já citado no PRD/discovery). Faltam asserções sobre exatamente os dois pontos onde with_skill e without_skill divergiram de fato nesta execução: marcação de metas inventadas e consistência interna do resumo.
- Nenhuma fixture ou transcript revelou contaminação entre configurações (setup.sh remove `.forge/agents`/`.claude/agents` antes do without_skill, consistente com o desenho A/B).
- **`eval_quality`: boa em 2 dos 3 casos; o eval 2 precisa de pelo menos uma asserção discriminante antes da próxima rodada — do jeito que está, ele infla a média sem medir nada.**
