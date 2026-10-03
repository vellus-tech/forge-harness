# Análise de benchmark — agente `module-generator`

Fonte determinística: `workspace/iteration-1/benchmark.json` (gerado por
`scripts.aggregate_benchmark`, sem cálculo manual) e `workspace/iteration-1/review.html`.
Artefato avaliado: `template/.forge/agents/architecture/module-generator.md` (1403 linhas).
3 evals × 2 configurações (`with_skill` / `without_skill`) × 1 run cada, com `grading.json`
e `eval_feedback` já produzidos por um grader em sessão anterior a esta.

## 1. Resultado (benchmark.json → run_summary)

| Métrica | With Skill | Without Skill | Delta |
|---|---|---|---|
| Pass rate (média) | 94,33% (± 9,81%) | 22,00% (± 19,05%) | **+0,72** |
| Tempo (s, média) | 559,3 (± 44,6) | 280,7 (± 175,8) | +278,7 |
| Por eval | 1,00 / 0,83 / 1,00 | 0,00 / 0,33 / 0,33 | — |

Veredito: **agrega** (delta ≥ 0,15, com folga — o artefato quase quadruplica a taxa de
aprovação). `benchmark_ok = true`: o script rodou de primeira, sem precisar corrigir
estrutura de diretórios.

## 2. Asserções não discriminantes ou mal calibradas

Os próprios `eval_feedback.suggestions` de cada `grading.json` (não este agente sozinho)
já sinalizam três problemas recorrentes nos casos de teste:

- **Eval "recusa-bi", asserção 1** (não criar `services/`, `go.mod`, `Dockerfile`): passa
  100% nas duas configurações porque o próprio ambiente do eval proíbe Docker e ambos os
  executores citaram a proibição — não discrimina a habilidade do artefato, só o sandbox.
  O ganho real dessa eval está nas asserções 2, 3 e 5 (with 6/6 vs without 2/6).
- **Eval "materializa-modulos", asserção 4** (exigir bloco ```mermaid``` em
  `diagrams/README.md` e `compliance-flows.md`): o próprio template do artefato (§8.1,
  linhas 713-740, e o equivalente em §8.5/§11 para `compliance-flows.md`) define esses dois
  arquivos como **índices em tabela**, sem mermaid — só `solution-architecture.md`,
  `module-dependencies.md` e `integration-flows.md` trazem diagrama. A asserção pune a
  conformidade ao próprio template: `with_skill` seguiu a especificação e ainda assim
  perdeu o ponto (5/6 em vez de 6/6). É um defeito do caso de teste, não do artefato.
- **Todas as evals, asserção sobre "resposta final"**: nenhum dos 6 transcripts contém a
  frase literal `Resultado da Geração da Estrutura de Módulos` (grep confirmado pelo
  próprio grader), embora o artefato exija esse resumo em `# 15. Resumo final obrigatório`
  (linhas 1322-1387) como saída obrigatória de todo run. Isso é discutido em §4 abaixo como
  achado sobre o artefato, não só sobre o caso de teste — nenhuma asserção verifica esse
  resumo, então o benchmark é cego a essa parte do contrato do agente.

## 3. Onde o artefato ajudou (evidência de transcript/grading)

- **Isolamento de compliance por arquivo dedicado**: com o artefato, PCI DSS e LGPD saem de
  prosa solta e viram arquivos com tabela auditável — `compliance-flows.md:11` marca
  explicitamente `PCI DSS | Não | NFR-03 e o PRD declaram...`; sem o artefato, o mesmo dado
  fica só em texto corrido no README (`README.md:17-18`) e sem os arquivos
  `compliance-pci-dss.md`/`compliance-lgpd.md` — 0/5 sem skill nesse eval.
- **Precisão de referência a NFR**: `without_skill` errou a referência da retenção LGPD
  (atribuiu a NFR-02 quando o fixture diz NFR-01) nas duas evals onde isso foi checado; o
  `with_skill` acertou nos dois casos. O artefato tem uma seção específica (§9, "Requisitos
  Não Funcionais Relevantes") que força essa citação a ser rastreada por ID, e isso parece
  reduzir esse tipo de erro — embora nenhuma asserção verifique diretamente essa causalidade
  (é uma observação, não uma correlação garantida por N=1 por eval).
- **Convenção de nomenclatura de módulo**: `with_skill` respeitou os sufixos do Solution
  Module Map (`-api`, `-adapter`, `-lib`, `-worker`) nas 3 evals; `without_skill` usou slugs
  sem sufixo (`validacao-embarque`, `tarifacao`, `recarga`) na eval "materializa-modulos" —
  a asserção 1 dessa eval falhou parcialmente por isso.
- **"Ponto a Validar" como padrão para decisão pendente**: na eval "escala-frota", o
  artefato levou a marcar Tipo de Módulo como `Ponto a Validar` com item `VAL-MOD-01`
  rastreável (README.md:11 e :187); sem o artefato, a mesma decisão não tomada vira uma
  seção solta `## Tipo de módulo — decisão em aberto` sem ID rastreável — a informação
  correta está lá, mas não no formato que o índice consegue agregar (falha de formato, não
  de julgamento, como o próprio `eval_feedback.overall` da eval nota).
- **Recusa de escopo (scaffold de serviço) é preservada nas duas configurações**, mas só
  `with_skill` a registra de forma auditável: aponta explicitamente que devolve o build ao
  orquestrador e cria `VAL-MOD-01`/`VAL-MOD-02` para os dois pedidos fora de escopo
  (fusão "Financeiro" e `relatorios-bi`); `without_skill` recusa corretamente o scaffold mas
  não formaliza os itens de validação nem menciona o orquestrador — 2/6 vs 6/6.

## 4. Onde o artefato pode ter atrapalhado, ou desperdiça tempo

- **Custo de tempo quase 2x sem ganho de discriminação claro em uma das evals**: `with_skill`
  levou em média 559s contra 281s sem o artefato (+278,7s, delta de tempo positivo grande).
  Na eval "recusa-bi", que já teria alta pass rate parcial mesmo sem o artefato pela simples
  proibição de Docker do ambiente, o tempo consumido para produzir 6 READMEs completos +
  2 diagramas pode ser mais do que o pedido exige quando o usuário só queria a recusa
  documentada — é um trade-off aceitável dado o ganho de pass rate, mas vale registrar que
  o custo em tempo/tokens do artefato é substancial e não gratuito.
- **Resumo final obrigatório (§15) é ignorado nas 3 evals, nas duas configurações**: a seção
  determina literalmente "Ao final da execução, apresente: `# Resultado da Geração da
  Estrutura de Módulos`" como parte do contrato do agente, mas nenhum dos 6 transcripts
  produziu essa saída (confirmado por grep nos próprios `grading.json`). Isso é evidência de
  que a seção está posicionada tarde demais no documento (linha 1322 de 1403) e/ou não é
  reforçada perto do início — o executor parece tratar o "resumo final" como opcional ou
  nunca chega a essa parte do system prompt com atenção total. Nenhuma asserção do
  benchmark cobre isso, então o defeito é invisível nos números, mas é visível lendo os
  transcripts.
- **Item de nomenclatura ambíguo entre "Tipo de Módulo" e o rótulo do valor**: no eval
  "escala-frota", `with_skill` escreveu o valor do campo como `Ponto a Validar — candidatos
  documentados no DDD: Worker próprio (CronJob/Worker) ou rota dentro de um BFF...`, ou seja,
  o próprio campo "Ponto a Validar" carrega os nomes de tipo que ele deveria estar evitando
  citar como fato. Isso passou na asserção (que aceita candidatos citados), mas é o tipo de
  ambiguidade que uma leitura mais estrita da intenção do usuário ("não quero que ninguém
  decida isso") poderia reprovar — o artefato não instrui explicitamente a não citar
  candidatos dentro do próprio valor "Ponto a Validar", só que a decisão não seja tomada.
- **Referência cruzada de VAL-MOD errada**: no README de `escalas-api` (eval "escala-frota"),
  a linha do endpoint `GET /escalas/hoje` referencia `VAL-MOD-01` quando o ponto a validar
  correto sobre esse endpoint é `VAL-MOD-03` (confirmado pelo próprio grader). O artefato
  não define um mecanismo de verificação cruzada entre os `VAL-MOD-NN` citados inline nas
  tabelas e os itens efetivamente listados na seção "20. Pontos a Validar" — nada no
  processo pede para o agente conferir que o ID citado corresponde ao item certo.

## 5. Trechos do artefato ignorados, ambíguos, contraditórios ou que desperdiçam tempo

- **§15 (Resumo final obrigatório)** — ignorado nas 6 execuções observadas (ver §4). Maior
  achado acionável desta análise: uma seção "obrigatória" com taxa de cumprimento observada
  de 0/6 é, na prática, uma instrução morta.
- **§8 lista 6 arquivos obrigatórios** (`README.md`, `solution-architecture.md`,
  `module-dependencies.md`, `integration-flows.md`, `compliance-flows.md`, `index.html`),
  mas `index.html` não é mencionado em nenhuma asserção do benchmark nem citado em nenhum
  `grading.json`/`claims` — não há evidência, a favor ou contra, de que os executores o
  produzam. É um ponto cego do benchmark, não necessariamente um problema do artefato, mas
  vale marcar para a próxima rodada de evals cobrir explicitamente.
- **§8.1 vs. as asserções do caso de teste "materializa-modulos"**: já coberto em §2 — o
  artefato é internamente consistente (README de diagramas e compliance-flows são índices
  em tabela, não diagramas), mas a asserção do caso de teste contradiz essa especificação.
  É contradição eval-vs-artefato, não do artefato consigo mesmo.
- **§12 (Heurísticas de decisão) não foi lido em detalhe nesta análise** por não haver
  evidência de falha atribuível a ela nos 6 grading.json — não há achado a reportar aqui
  sem especular.

## 6. Melhorias concretas priorizadas

1. **(Alta) Reforçar §15 perto do topo do artefato ou como checklist de saída.** Mover um
   lembrete curto do resumo final obrigatório para logo após o §1 (Objetivo) ou para uma
   linha no fim do "System Prompt" (linha 24-33), e/ou adicionar ao final do §14 (Critérios
   de qualidade) um item de checklist explícito "Produzi o resumo `# Resultado da Geração da
   Estrutura de Módulos`? (S/N)". Evidência: 0/6 execuções produziram essa seção apesar de
   "obrigatória"; instrução tardia (linha 1322 de 1403) é a hipótese mais provável.
2. **(Alta) Corrigir a asserção 4 do caso "materializa-modulos-tarifa-viva"** para exigir
   mermaid só em `solution-architecture.md`, `module-dependencies.md` e
   `integration-flows.md` (não em `diagrams/README.md` nem `compliance-flows.md`), alinhando
   com §8.1 e o template real do artefato. Sem essa correção, o benchmark subestima
   sistematicamente `with_skill` (perde 1 ponto por seguir a especificação corretamente).
3. **(Média) Adicionar ao caso "recusa-bi-fusao-de-contextos-e-scaffold" uma asserção que
   discrimine de fato**, já que a asserção 1 (ausência de `services/`/`Dockerfile`) passa
   trivialmente nas duas configurações por causa da proibição de Docker do ambiente do eval,
   não por mérito do artefato. Substituir ou complementar por uma asserção sobre o
   encaminhamento explícito ao orquestrador (que já discrimina 1/2 configs, conforme
   `eval_feedback`).
4. **(Média) Adicionar uma regra de verificação cruzada de `VAL-MOD-NN`** ao processo (§6 ou
   §14): ao citar um ID de "Ponto a Validar" em qualquer tabela do módulo (ex.: linha de
   endpoint, linha de campo), o agente deve conferir que esse ID aparece na seção "20. Pontos
   a Validar" do mesmo README com o mesmo assunto — evita o erro observado (`VAL-MOD-01`
   citado onde o correto era `VAL-MOD-03`).
5. **(Baixa) Explicitar em §12.2/§20 que o valor de "Ponto a Validar" não deve embutir os
   próprios candidatos como se fossem quase-decisão** (ex.: "Ponto a Validar —
   candidatos: Worker ou BFF" versus apenas "Ponto a Validar, ver VAL-MOD-NN"), para casos em
   que o usuário pede explicitamente que "ninguém decida" nem parcialmente.
6. **(Baixa) Cobrir `index.html` (§8) em pelo menos uma asserção futura** — hoje o benchmark
   não tem visibilidade sobre se esse artefato é ou não produzido pelos executores.
7. **(Não é do artefato, é de processo) Considerar rodar mais de 1 run por configuração**
   nas próximas iterações — hoje `stddev` de `without_skill` chega a 0,1905 (0% a 33%) com
   n=3 evals × 1 run; múltiplos runs por eval separariam variância de execução de variância
   entre casos de teste, o que hoje o benchmark.json não distingue.

## 7. Qualidade dos próprios casos de eval (`eval_quality`)

Avaliação: **boa, com ressalvas pontuais já auto-identificadas pelo grader**.

Pontos fortes: os 3 casos cobrem cenários realistas e discriminantes na maior parte das
asserções (nomenclatura de módulo, compliance PCI/LGPD isolado em arquivo, registro de
pontos a validar, recusa de escopo fora do agente) e cada `grading.json` já inclui evidência
de comando/linha, não impressão subjetiva — nível de rigor alto para grading determinístico.

Ressalvas (específicas, já citadas nas seções acima e nos próprios `eval_feedback`):
- 1 asserção não discriminante (Docker/services na eval de recusa) — mede o ambiente, não o
  artefato.
- 1 asserção mal calibrada contra o próprio template do artefato (mermaid em
  diagrams/README.md e compliance-flows.md).
- Nenhuma asserção cobre o resumo final obrigatório (§15) nem `index.html` (§8) — lacuna de
  cobertura, não de correção.
- N=1 run por configuração por eval limita a separação entre variância de execução e
  variância de dificuldade do caso — os `stddev` reportados em `run_summary` já refletem
  isso (variação entre as 3 evals, não entre repetições do mesmo eval).

Essas ressalvas não mudam o veredito agregado (a margem de +0,72 é grande o suficiente para
absorver 1-2 pontos de recalibração de asserção), mas devem ser corrigidas antes da próxima
rodada de benchmark para que o número deixe de ter esse viés conhecido.
