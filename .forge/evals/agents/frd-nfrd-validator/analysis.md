# Análise de benchmark do agente frd-nfrd-validator

Fonte: workspace/iteration-1/benchmark.json (aggregate_benchmark.py, sem erro, sem correção estrutural).
Viewer: workspace/iteration-1/review.html (generate_review.py, sem erro).

## 1. Resultado

with_skill: pass_rate média 0.8667 (min 0.80, max 1.00, stddev 0.1155), tempo médio 310.3s
without_skill: pass_rate média 0.2333 (min 0.00, max 0.50, stddev 0.2517), tempo médio 178.7s
delta = +0.6333 (run_summary.delta.pass_rate arredonda para +0.63)
Veredito pelo limiar do harness (>=0.15 agrega): agrega. benchmark_ok = true.
tokens ficaram zerados nos 6 runs (não instrumentado nesta rodada).

## 2. Asserções não discriminantes

Eval 1 (aplica-correcoes-editaveis-recarga-pix): 3 das 6 asserções passam em ambas as configurações
(substituição de FRD-XX, métrica NFRD-PERF-01 com 10s, contagem de 3 RFs/3 NFRs sem mudança de
escopo). Um validador genérico sem o artefato já resolve essas correções pontuais lendo o PRD
diretamente. O que de fato diferencia with/without nesse eval é o caminho canônico do relatório, a
convenção FIND-NNN/PRD-BASE-NN/severidade fechada, o bump de versão citando FIND-NNN e a marcação
"Aplicado" com localização por achado.

Eval 2 (somente-relatorio-portal-lojista-sugere-adr): a asserção 1 (nenhuma alteração em
frd.md/nfrd.md/prd.md) passa em ambas as configurações — sem skill o modelo também se absteve de
editar quando não houve pedido de correção, então essa asserção isoladamente não evidencia o
artefato.

## 3. Onde o artefato ajudou

- Estrutura e vocabulário fechado do relatório: nos 3 evals with_skill o relatório nasce sempre em
  docs/product/frd-nfrd/frd-nfrd-validation-report.md com as 18 seções da spec, IDs
  FIND-NNN/PRD-BASE-NN/VAL-NN e severidade no conjunto fechado {Crítica, Alta, Média, Baixa}. Sem o
  artefato vira prosa livre em outputs/validation-report.md (eval 1 without_skill, grep por
  PRD-BASE/FIND- = 0) ou nem existe no caminho esperado (eval 3 without_skill).
- Resistência a pedido de correção sob parecer Reprovado: no eval 3, o transcript with_skill (linhas
  41-49) mostra o agente citando textualmente a regra do artefato ("Se o parecer for Reprovado — não
  aplique correções, devolva para regeneração", seções 4 e 12) para recusar o pedido explícito e com
  pressão de prazo do usuário. git diff ficou vazio em frd.md/nfrd.md, confirmado por hash. Sem o
  artefato, no mesmo eval, o modelo cedeu e reescreveu os documentos na hora (RF-3 EMV/offline/
  temporal/sincronização adicionados, versão para 0.2.0) — a asserção correspondente falha 100% sem
  skill.
- Delegação a ADR em vez de decisão arquitetural improvisada: nos evals 2 e 3 o artefato aciona o
  gatilho da seção 11.1 (política de senha/hash, retenção sem definição jurídica, PCI DSS) e o agente
  registra sugestão de ADR com origem rastreável a FIND-NNN; sem skill a menção a ADR é prosa solta
  sem ID nem rastreabilidade.

## 4. Onde o artefato atrapalhou ou não foi suficiente

- Contradição real entre a seção 11.2/11.4 e a escala de severidade do ADR: a seção 11.2 diz que a
  severidade do ADR sugerido deve ser igual ou superior à do FIND-NNN de origem, mas a mesma seção
  lista as únicas severidades de ADR como Alta/Média/Baixa — sem opção "Crítica". Quando o FIND de
  origem é Crítica (uso legítimo e frequente na seção 13), é impossível cumprir a regra. Isso se
  materializou no eval 2 with_skill: ADR-0004 saiu com severidade Alta tendo origem FIND-003
  classificado Crítica na tabela de achados — falha confirmada no benchmark.json (eval_id 2,
  with_skill, expectation 4), com a própria nota do avaliador registrando a tensão entre as
  asserções. Não é erro do executor, é um buraco de especificação do próprio artefato.
- O template da seção 6 (item 14, "Achados de Validação") não tem coluna Status, mas a seção 4.3
  exige marcá-la (Aplicado / Pendente — ADR / Pendente — produto / Pendente — regeneração / Não
  aplicável). A tabela template na seção 6 e o resumo final obrigatório (seção 10, item 4) usam o
  mesmo cabeçalho sem essa coluna. No eval 3 with_skill o agente seguiu a estrutura obrigatória à
  risca e não incluiu status por achado — falha confirmada (grep por pendente/aplicado sem resultado
  na tabela de achados), mesmo com o resto do relatório correto (próximos passos citando nova rodada
  do gerador). O artefato instrui uma coisa na seção 4.3 e contradiz o próprio template estrutural
  que manda seguir "integralmente".
- Sobrecarga estrutural vs. ganho marginal: o relatório de 18 seções obrigatórias é seguido à risca
  mesmo quando várias seções ficam vazias ou triviais para o caso concreto (ex.: eval 2, seções de
  Permissões Funcionais e Mensagens quando a fixture não tem perfis/mensagens relevantes) — não causa
  falha de asserção, mas consome tempo: with_skill gasta em média +131.7s a mais que without_skill
  (310s vs 179s), plausivelmente por preencher as 18 seções completas mesmo quando irrelevantes.

## 5. Trechos ignorados, ambíguos ou contraditórios

- Seção 4.1 critério 1 ("cabe em <= 5 edições cirúrgicas") é uma régua sem instrumentação — nenhum
  transcript mostra o agente contando edições antes de decidir "editável"; a decisão parece guiada
  pelos exemplos da mesma seção, não pelo número. Não causou falha observada, mas é regra decorativa.
- Seção 11.4 ("Se houver >= 3 sugestões de ADR Altas, considere parecer Reprovado") usa "considere",
  não "deve" — ambíguo quanto a ser regra dura ou heurística; nenhum eval atinge esse limiar (máximo
  observado foi 2 ADRs Alta no eval 2), então a ambiguidade não foi exercitada.
- Seção 3 lista discovery-notes.md e docs/discovery/discovery-notes.md como entradas possíveis, mas
  nenhuma das 3 fixtures fornece esse arquivo nem os transcripts mencionam procurá-lo — parte do
  artefato nunca exercitada pelos casos atuais (lacuna de cobertura de eval, não defeito do artefato).
- A ordem de leitura entre "Política de aplicação de correções" (linha 119), a lista de arquivos de
  saída (seção 4) e o critério de "achado editável" (seção 4.1) obriga forward-reference; não é bug
  funcional, mas é atrito de leitura.

## 6. Melhorias concretas, priorizadas

1. [Alta — corrige falha reproduzida] Alinhar a escala de severidade de ADR com a de FIND: incluir
   Crítica no vocabulário de severidade de ADR (seções 11.2, 18 e 10) ou reformular a regra dizendo
   explicitamente o que fazer quando o FIND de origem é Crítica (ex.: "ADR de origem Crítica sempre
   recebe severidade Alta, o teto do vocabulário de ADR, e o parecer não pode ser Aprovado com
   Ressalvas, deve ser Reprovado"). Remove a contradição matemática com uma regra executável.
2. [Alta — corrige falha reproduzida] Adicionar coluna "Status" ao template da seção 6 item 14 e ao
   resumo final obrigatório da seção 10 item 4 — hoje só a seção 4.3 menciona a coluna. Duas edições
   de tabela eliminam a contradição estrutural sem tocar em regra de conteúdo.
3. [Média] Tornar "<= 5 edições cirúrgicas" operacional (instruir como contar) ou remover o número e
   confiar nos outros três critérios de "achado editável" (localizado, sem mudança de escopo, solução
   inequívoca), já que hoje o número não é verificável nem pelo executor nem pelo avaliador.
4. [Média] Marcar seções do relatório (seção 6) como condicionais quando não houver conteúdo
   aplicável (ex.: "se não houver perfis/papéis relevantes, registre uma linha 'não aplicável' e não
   expanda a tabela") — reduz tempo de execução sem arriscar completude.
5. [Baixa] Fortalecer "considere Reprovado" da seção 11.4 para "deve", ou documentar explicitamente
   que é heurística sujeita a julgamento — hoje convida interpretações diferentes entre execuções.

## 7. Qualidade dos casos de eval

- Cobertura de cenário é boa para os três casos existentes: aplicar correções sem fricção (eval 1),
  modo somente-relatório com sugestão de ADR (eval 2), e reprovação sob pressão do usuário para
  corrigir mesmo assim (eval 3) — cobrem os três ramos centrais da política de aplicação do artefato.
- Eval 1 tem baixa capacidade discriminante em metade das suas asserções (seção 2 acima): 3 de 6
  passam com e sem skill. Recomenda-se reforçar com uma asserção que dependa estritamente do
  vocabulário/estrutura do artefato e fundir ou remover as asserções 2/3/6 para não inflar
  artificialmente a pass_rate do without_skill.
- Eval 2 tem uma asserção (severidade de ADR >= severidade de FIND) que virou "double bind" pelo
  próprio bug do artefato descrito na seção 4. É uma boa asserção — expôs um defeito real — mas
  merece nota explícita no evals.json de que testa esse conflito de propósito, para não ser confundida
  com "eval mal escrito" quando o artefato for corrigido.
- Eval 3 é o mais forte dos três: sem asserções não discriminantes (without_skill 0%, with_skill
  80%), testa resistência a pressão social/temporal do usuário, e a única falha with_skill é
  atribuível ao artefato, não ao executor.
- Nenhum caso testa o gatilho ">=3 ADRs Alta -> considere Reprovado" nem o uso de
  discovery-notes.md/data-model.md como insumo — lacunas de cobertura para uma próxima rodada.

## 8. Conclusão

Resultado: with_skill 86,67% vs without_skill 23,33%; delta = +0,6333 -> agrega (limiar >=0,15
folgadamente superado, benchmark_ok = true). O artefato entrega valor real e mensurável, sobretudo em
disciplina de saída (caminho canônico, IDs, severidade fechada) e em resistir a pedidos de correção
fora de política sob pressão do usuário. As duas falhas with_skill observadas (severidade de ADR vs.
FIND Crítica; ausência de coluna Status no template) são defeitos localizados e de baixo custo de
correção no próprio texto do artefato — não comprometem o veredito agregado, mas devem ser corrigidos
porque produzem falhas reproduzíveis mesmo quando o executor segue a especificação corretamente.
