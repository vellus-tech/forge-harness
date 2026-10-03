# Análise de benchmark — agente `trd-validator`

Artefato: `template/.forge/agents/specifications/trd-validator.md` (agent, 1273 linhas). Fonte: `.forge/evals/agents/trd-validator/workspace/iteration-1/benchmark.json` (agregação determinística) + `grading.json`/`outputs/transcript.md` de cada uma das 3 evals × 2 configurações (1 run cada). Protocolo: `skill-creator/agents/analyzer.md`, seção "Analyzing Benchmark Results".

## Resultado (benchmark.json / run_summary)

| Configuração | Pass rate médio | Min–max | Tempo médio |
|---|---|---|---|
| Com agente (`with_skill`) | 100,0% | 100%–100% | 282 s |
| Sem agente (`without_skill`) | 46,7% | 33%–67% | 157 s |

Delta = **+0,53**. `benchmark_ok = true` (script `aggregate_benchmark` rodou de primeira, sem correção de estrutura). Cada configuração teve 1 run por eval (3 evals × 1 run), não 3 runs por eval — não há variância intra-eval para medir flakiness, só variância entre os três cenários.

**Veredito: agrega** (delta 0,53 ≥ 0,15).

## Assinatura da diferença: não é conhecimento técnico, é conformidade de output

Em nenhum dos 3 cenários o agente genérico (without_skill) errou o diagnóstico técnico de fundo — ele identificou os mesmos problemas reais (evento faltante, conflito ADR-0002, PAN cifrado violando ADR-0003, ausência de base documental para Kafka/500 ms) com qualidade de raciocínio comparável à do agente com a especificação. A queda de pass rate vem quase inteira de exigências de *forma* que só o artefato declara:

- **Sempre falha sem o artefato:** existência de `docs/product/trd/trd-validation-report.md` como arquivo dedicado dentro de `docs/product/trd/` (o agente genérico escreve o parecer em `outputs/parecer-*.md`, fora da árvore do produto) — falha nos 3/3 cenários sem agente.
- **Sempre falha sem o artefato:** IDs rastreáveis no formato `ADJ-TRD-NNN` / `VAL-TRD-NN` / `ARCH-CONFLICT-NNN` — o agente genérico registra as mesmas informações em prosa numerada (F1, F4, "achado bloqueante") sem esses identificadores, quebrando a asserção mesmo quando o conteúdo está certo.
- **Sempre falha sem o artefato:** "Parecer Final" como uma das três classes literais (`Aprovado` / `Aprovado com Ressalvas` / `Reprovado`) com seção de Métricas por severidade — o agente genérico usa frases livres ("o TRD pode seguir como baseline após as correções", "Reprovado — pendências bloqueantes" só por acaso bate com uma classe literal).
- **Quase sempre passa nas duas configurações:** "não alterar NFRD/ADRs", "não adotar Kafka sem base documental", "não aceitar meta de 500 ms sem base documental" — o modelo já resiste a esse tipo de pressão por bom senso próprio, com ou sem o artefato; a asserção mais discriminante do eval 3 (severidade "Crítica" explícita no PAN cifrado + não recriar o conflito já presente na fixture) é a exceção onde o artefato ainda ajuda.
- **Achado real de regressão sem o artefato:** no eval 3, o agente sem o artefato não apenas deixou de nomear a severidade — ele **não detectou que o TRD da fixture já continha a gravação de `pan_cifrado`** como decisão vigente (afirmou que as seções 1–20 "estão consistentes com ADR-0003", contradizendo o próprio ADR). Isso é uma falha de instrução-seguimento genuína, não só de formato: o artefato do trd-validator instrui explicitamente checar segurança/PAN contra o ADR-0003 no Passo 12; sem essa checklist step-by-step, o agente pulou a verificação.

## Onde o artefato ajudou (evidência de transcript)

- **Passo 16 + seção 7 (estrutura obrigatória do relatório, 22 seções)**: o transcript with_skill do eval 1 lista exatamente as 10 correções aplicadas mapeadas 1:1 às seções do TRD e produz o relatório com a estrutura de 22 seções definida no artefato (linhas 727-1000 do agente) — isso é o que fecha as 3 asserções de formato que o agente genérico erra sempre.
- **Passo 12 (segurança) + Regra 3.2 (Conflito Arquitetural)**: no eval 3, o agente com artefato usa literalmente a categoria `ARCH-CONFLICT-NNN` prevista na Regra 3.2 para o PAN cifrado e cita a métrica de achados críticos — o agente genérico trata o mesmo fato como "achado bloqueante" em prosa, sem a categoria formal, e no fim nem percebe que o conflito já estava presente no TRD da fixture.
- **Regra 3.1 vs 3.2 (corrigir direto vs. Ponto a Validar/Conflito)**: nos 3 evals, ambas as configurações aplicaram a distinção corretamente na prática (ex.: diagrama Mermaid tratado como achado não corrigido por "risco de não verificar visualmente", retenção conflitante tratada como Conflito Arquitetural) — essa regra parece já robusta no próprio bom senso do modelo; o artefato a reforça mas não é o que discrimina o resultado.

## Onde o artefato pode ter atrapalhado ou desperdiçado tempo

- **Seção "Disciplina de ferramenta" (linhas 18-23) é boilerplate de agente de codificação genérico, não deste validador**: menciona `docker build`/`docker compose up --build` e "devolver ao orquestrador pedindo build em background enquanto segue com outra TASK" — o `trd-validator` é um agente single-pass Read/Edit/Write sobre markdown, nunca roda Docker nem recebe TASKs de um tracker de ondas. É instrução copiada de um template compartilhado (mesmo texto aparece em outros agents do repo) que não se aplica aqui; não há evidência de que tenha causado erro nos transcripts, mas ocupa espaço de contexto sem função e é candidata a remoção ou substituição por uma disciplina de ferramenta específica (ex.: "releia o arquivo antes de cada Edit, mesmo dentro da mesma sessão").
- **Custo de tempo mensurável e não pequeno**: 282 s vs. 157 s (+125 s, quase o dobro) para o mesmo conjunto de evals — a estrutura de 22 seções do relatório é verbosa (a with_skill do eval 1 tem ~9 ajustes documentados + seção de métricas + matriz de rastreabilidade completa) e claramente é o que consome o tempo extra. Isso é o preço esperado de um relatório mais completo, não um desperdício, mas vale registrar como trade-off explícito no artefato ("este processo é mais lento; é proporcional ao ganho de conformidade").
- **Nenhuma asserção do eval set testa o próprio custo/verbosidade do relatório** — as 16 asserções (5+5+6 espalhadas) cobrem conteúdo e forma, mas nenhuma penaliza um relatório desnecessariamente longo ou testa se o agente sabe produzir uma versão condensada quando pedido. Não é um defeito do artefato, é uma lacuna do eval set (ver `eval_quality` abaixo).

## Trechos do artefato ignorados, ambíguos ou contraditórios

- **Ambíguo, mas não testado**: a Regra 3.1 inclui "requisito técnico ausente, mas claramente derivado do NFRD ou ADR" como algo a corrigir direto — o termo "claramente derivado" não tem critério objetivo, e nenhum dos 3 evals força um caso de fronteira (um requisito derivável só com inferência de duas ou mais etapas) que testasse se o agente super-corrige (viola 3.2 "risco de introduzir escopo novo") ou sub-corrige (deixa como Ponto a Validar por excesso de cautela). Ambas as configurações resolveram os casos presentes sem tropeçar nisso, o que sugere os fixtures atuais são "fáceis" nesse eixo.
- **Não observado como ignorado**: não encontrei nenhuma instrução do artefato que os transcripts tenham contradito ou pulado — os 1273 linhas do agente parecem, pelo que os 3 cenários exercitam, integralmente seguidos pela configuração with_skill. Isso é coerência do artefato com o comportamento observado, não uma lacuna de análise: o eval set simplesmente não cobre partes do artefato como Passo 9 (APIs) ou Passo 11 (dados) em profundidade suficiente para revelar se há trechos mortos.

## Qualidade dos próprios casos (eval_quality)

Os 3 casos são bem desenhados para o objetivo do agente — cada um isola um eixo de decisão diferente (aplicar correção autônoma / escalar conflito entre insumos / recusar pressão do usuário para violar escopo e insumos) e as asserções são checáveis por evidência de arquivo (`grep`, `git diff`), não por opinião. Pontos fracos:

- **Assimetria de poder discriminante**: das 16 asserções, ~9 testam forma do relatório (arquivo no lugar certo, IDs no formato certo, classe literal do parecer) e são as que mais diferenciam as configurações; as que testam julgamento técnico substantivo (não inventar broker, não aceitar 500 ms, não ceder a pressão) já são atendidas por bom senso do modelo básico na maioria dos casos. Isso é aceitável — a forma estruturada É o valor central que este artefato entrega — mas o `eval_quality` seria mais forte com pelo menos 1 assertion que force um erro técnico real sem o artefato (ex.: um insumo com um requisito "quase derivável" que exige interpretar corretamente a Regra 3.1 vs. 3.2, não só copiar a estrutura do relatório).
- **1 run por configuração por eval, sem repetição**: `runs_per_configuration: 3` no metadata na verdade descreve 3 evals distintos, não 3 repetições do mesmo eval — não há como saber se o 100% "with_skill" é estável ou teve sorte em uma escolha de fronteira (ex.: o diagrama Mermaid do eval 1, tratado como "achado não corrigido" por decisão de risco do próprio modelo, poderia ter saído diferente em outra amostra). Para elevar a confiança do "agrega", valeria rodar 2-3 repetições por (eval, configuração) antes de fechar uma decisão de merge/breaking change no artefato.
- **Assertion "somente-docs-product-trd-alterado" do eval 1 passa mesmo quando o agente falha em criar o relatório** (without_skill): o grading nota isso explicitamente ("passa pelo critério literal, embora o agente só não tenha tocado outros arquivos porque não criou o relatório") — é uma asserção que dá falso positivo de "isolamento correto" quando na verdade é ausência de trabalho. Vale reforçar o texto da asserção para exigir que o relatório exista E que nenhum outro arquivo tenha mudado, não apenas a segunda parte isoladamente.

## Melhorias concretas priorizadas

1. **[Alta] Remover ou substituir o bloco "Disciplina de ferramenta" (linhas 18-23) por um específico deste agente** — trocar as 2 linhas sobre `docker build`/orquestrador de TASKs (irrelevantes para um validador single-pass de markdown) por algo como: "Releia `trd.md` imediatamente antes de cada Edit, mesmo dentro da mesma sessão — o arquivo pode ter sido alterado por uma correção anterior sua no mesmo run" (a única linha do bloco atual que de fato se aplica). Reduz ruído de contexto sem perda de cobertura.
2. **[Média] Adicionar ao menos 1 eval de fronteira para a Regra 3.1 vs. 3.2** — um insumo onde o requisito é derivável só por inferência indireta (2+ documentos combinados), para testar se o agente super-corrige (introduz conteúdo não literalmente presente) ou sub-corrige (Ponto a Validar desnecessário). Hoje nenhum dos 3 casos força essa fronteira, deixando a regra mais ambígua do artefato sem cobertura.
3. **[Média] Rodar 2-3 repetições por (eval, configuração)** antes de qualquer decisão de merge que dependa deste benchmark — o eval 1 with_skill decidiu não corrigir o diagrama Mermaid por avaliação de risco pontual do próprio modelo; sem repetição não há como distinguir "comportamento estável do artefato" de "escolha de uma amostra".
4. **[Baixa] Reforçar a assertion "somente-docs-product-trd-alterado" do eval 1** para exigir explicitamente a existência do relatório como pré-condição, evitando o falso positivo identificado no grading (isolamento de arquivos "correto" só porque nada foi escrito).
5. **[Baixa] Documentar explicitamente no próprio artefato o trade-off de tempo** (~+125s / quase 2× mais lento que uma validação ad-hoc) como uma nota de expectativa, já que o processo de 17 passos + relatório de 22 seções é deliberadamente mais caro — evita que um usuário interprete a lentidão como regressão de performance do agente.

## Fontes lidas

- `benchmark.json` / `benchmark.md` (gerados nesta análise, ver Agregação abaixo)
- `agents/analyzer.md` (skill-creator), seção "Analyzing Benchmark Results" (linhas 187-275)
- `grading.json` das 6 combinações (3 evals × 2 configurações, run-1)
- `outputs/transcript.md` das 6 combinações
- `template/.forge/agents/specifications/trd-validator.md` (1273 linhas, lido integralmente nas seções System Prompt, Escopo, Regra 3.1/3.2, Estrutura do relatório)
- `evals.json` (prompts e assertions dos 3 evals)
