# Análise do benchmark — agente `frd-generator`

## 1. Resultado (benchmark.json, `run_summary`)

- **Com artefato:** pass_rate média 0,8867 (min 0,83, max 1,00; stddev 0,0981) — 3 execuções (evals 1, 2, 3), 1 run cada.
- **Sem artefato:** pass_rate média 0,4000 (min 0,17, max 0,83; stddev 0,3727).
- **Delta:** +0,49 (0,8867 − 0,4000).
- **Tempo:** com artefato 241,3 s em média (178–329 s) vs. 138,0 s sem (117–169 s) — o artefato custa +103 s (+75%) de execução.
- **Tokens/tool_calls:** zerados nos dois lados (`0`) — o harness de avaliação não instrumentou esses campos nesta rodada; a comparação de custo real fica só pelo `time_seconds`.
- `benchmark_ok = true` (o script `aggregate_benchmark` rodou de primeira, sem erro de estrutura).
- **Veredito:** delta = +0,49 ≥ 0,15 → **agrega**.

## 2. Asserções não discriminantes

De 17 asserções totais (6+6+5), **7 não discriminam** com/sem artefato porque dão o mesmo resultado nas duas configurações:

- **Eval 2 (atualiza-frd) — 5 das 6 asserções são idênticas nas duas configurações** (pass_rate 0,83 = 0,83, empate exato): asserções 1, 2, 3, 4 e 6 passam em ambas. Só a asserção 5 (marcação `ADR-0004` inline) falha nas duas. Ou seja, **este eval não contribui em nada para o delta agregado** — ele mede apenas se o modelo sabe fazer um diff incremental preservando códigos existentes, tarefa que o baseline já executa bem sem o artefato.
- **Eval 1 (frd-completo) asserção 6** (`git diff` dos arquivos de entrada vazio) passa nas duas — não discrimina (é higiene básica, não conhecimento do artefato).
- **Eval 1 asserção 3** (Matriz de Rastreabilidade com coluna Status restrita a um enum fechado) falha nas duas configurações, mas por motivos diferentes: com artefato falha por anotar a célula com texto extra ("Parcialmente Coberto — bloqueio em nome do passageiro pelo SAC é Ponto a Validar (VAL-02)"), sem artefato falha porque a tabela nem usa códigos `FRD-*`. É uma asserção rígida demais (ver §4).
- **Eval 3 asserção 1** (`git diff` do PRD vazio ao recusar edição fora de escopo) passa nas duas — não discrimina, mede só se o modelo respeita "não altere entradas", regra que já está em quase todo prompt de sistema, com ou sem o artefato.

**Asserção que mais vale a pena manter mesmo falhando nas duas** (não discrimina, mas expõe uma lacuna real do artefato, não do avaliador): eval 2 / asserção 5 — ver §3 e §4.

## 3. Onde o artefato ajudou / atrapalhou (evidência de transcript)

**Ajudou fortemente — eval 1 (FRD do zero, 6 funcionalidades, tarefa completa):**
Sem artefato, o baseline (`without_skill/run-1`, pass_rate 0,17) comete quatro falhas estruturais que o artefato evita por completo no lado `with_skill` (pass_rate 0,83):
- gravou em `docs/product/frd/frd.md`, não em `docs/product/frd-nfrd/frd.md` (path canônico da spec, §6);
- usou códigos `RF-01..RF-06` em vez de `FRD-<módulo>-NN`, sem seções obrigatórias (Controle de Versão, Mensagens de Erro, Matriz de Permissões, Premissas, Pontos a Validar não existem no documento gerado);
- **inventou valores que o PRD deixa como pendência**: "valor inicial de R$ 500,00" para o teto de recarga da RN-04 e "prazo de 90 dias corridos" para contestação, tratando-os como regra definida em vez de registrar como `VAL-NN` (evidência: `grading.json` do eval, linhas 27/126 e 26/189 do frd.md gerado);
- não usou `VAL-NN` em nenhum ponto (`grep -n 'VAL-'` vazio).
No lado `with_skill`, o transcript (`outputs/transcript.md`, eval-frd-completo, passo 14) mostra o mesmo tipo de lacuna do PRD (teto de recarga RN-04, prazo de contestação, permissão do SAC) tratado corretamente como `VAL-01..VAL-08`, sem inventar número. O artefato está fazendo exatamente o trabalho para o qual foi desenhado: impedir que o modelo "resolva" ambiguidade do PRD com um chute silencioso.

**Ajudou fortemente — eval 3 (recusa de escopo/técnica fora do PRD):**
Sem artefato, o baseline: (a) registrou o pedido de cashback como pendência genérica em vez de `VAL-NN` explícito referenciando o conflito com "Fora de Escopo" do PRD; (b) deixou `Kafka` aparecer dentro da própria seção de Requisitos Funcionais (RF-07, coluna Notas) — exatamente o vazamento de decisão técnica que o artefato proíbe; (c) transformou os NFRs pedidos pelo usuário (300 ms p99, 99,95%) em requisitos formais `RNF-01`/`RNF-02` em vez de barrá-los. Com artefato, as quatro asserções correspondentes passam: nenhum termo técnico entra nas seções de requisito, nenhum `FRD-*`/`BR-*` trata do cashback, e o cashback fica isolado em `VAL-01` referenciando o PRD.

**Onde o artefato não ajudou (nem atrapalhou) — eval 2:**
Tarefa de atualização incremental de um FRD já aprovado. Baseline e artefato produzem resultado equivalente (mesmo pass_rate, 5/6). O ganho do artefato aqui é só qualitativo — nomes de BR mais descritivos, formatação idêntica — não medido por nenhuma asserção que discrimine.

**Onde o artefato falhou apesar de ler a própria instrução — eval 2, asserção 5:**
O transcript do `with_skill` (passo 10) mostra que o agente **leu e seguiu §11.1–§11.3** da spec (registrou a sugestão de ADR-0004 na tabela "§6 ADRs Sugeridos" do resumo final, não criou o ADR ele mesmo), mas **não aplicou §11.4** ("Como referenciar ADRs no corpo do FRD"), que pede a marcação `**Dependência arquitetural:** ADR-NNNN — ...` na própria linha de BR-04/FRD-rec-05 dentro do `frd.md`. Curiosamente, no eval 1 o mesmo agente (mesmo artefato) **aplicou corretamente** essa marcação na linha de FRD-recharge-05 (transcript eval-frd-completo, "Decisões relevantes"), então a instrução é seguível — é inconsistência de execução, não impossibilidade. O baseline sem artefato falha na mesma asserção pela razão oposta: nunca considerou a tokenização uma "dependência arquitetural" (o transcript sem artefato não menciona ADR em nenhum ponto).

## 4. Trechos do artefato ignorados, ambíguos, contraditórios ou que desperdiçam tempo

1. **§11.2–§11.4 duplicam o lugar onde a sugestão de ADR deve aparecer, sem check cruzado.** §11.2 diz "registre a sugestão de ADR no relatório final (§6 do resumo)"; §11.4, três subseções depois, exige *também* uma marcação inline no `frd.md`. Nada no texto obriga o agente a verificar, ao final, que toda linha do §6 tem uma marcação correspondente no corpo do FRD — e é exatamente essa lacuna que aparece no eval 2 (marcação de §6 presente, marcação de §11.4 ausente). **Sugestão concreta:** adicionar ao Passo 10 (resumo final) um subitem de auto-checagem: "para cada linha da tabela §6, confirme com grep que a marcação `Dependência arquitetural: ADR-NNNN` existe no `frd.md` na seção do RF/BR correspondente; se não existir, adicione antes de finalizar."

2. **Asserção do eval1 sobre a Matriz de Rastreabilidade ("a coluna Status usa apenas os valores X, Y, Z ou W") é mais rígida do que o próprio artefato permite.** A spec não proíbe anotações complementares na célula de Status (ex.: "Parcialmente Coberto — motivo (VAL-02)"), e essa é uma prática razoável para rastrear o *porquê* do "Parcialmente Coberto". O próprio `eval_feedback` gerado no benchmark já sinaliza isso ("decidir se o enum é estrito... e escrever isso na asserção"). **Não é falha do artefato — é uma asserção que pune uma boa prática não vedada pelo texto.**

3. **A asserção "cashback/boleto/transferência aparecem apenas na seção Fora de Escopo" é impossível de cumprir literalmente** quando o próprio PRD reintroduz "transferência" no meio do texto de uma funcionalidade em escopo (F-06, "preservando o saldo para transferência futura"). O `eval_feedback` do próprio benchmark já registra essa observação. Isso é um problema do **eval**, não do artefato — mas indiretamente desperdiça o "orçamento de precisão" do artefato: um agente que segue a letra do PRD (citando a ressalva de F-06) é penalizado por uma asserção mal redigida.

4. **Nenhuma seção da spec instrui o agente a validar a própria matriz de rastreabilidade contra os módulos** listados na seção "Módulos Funcionais" — o eval não encontrou esse problema desta vez, mas as seções 9 (Módulos) e 16 (Matriz) são preenchidas em passos distantes (Passo 2 e Passo 9) sem um passo de conciliação explícito entre elas. Risco latente, não observado nos 3 casos rodados.

5. **Custo de tempo:** o artefato tem 1028 linhas e o transcript do eval 1 relata leitura integral em todo run. O tempo médio de execução quase dobra (+103 s, +75%) frente ao baseline. Para uma spec desse tamanho, vale considerar seccionar em "core" (obrigatório, lido sempre) + "referência" (convenções detalhadas, lidas sob demanda) para reduzir o custo de leitura sem perder a cobertura que gera o ganho de +49 pontos de pass_rate.

## 5. Melhorias concretas priorizadas

1. **[Alta] Fechar o loop §11.2→§11.4 com autochecagem obrigatória.** Adicionar ao final do Passo 10 (ou como item explícito do "Resumo final obrigatório", §10): "Antes de finalizar, para cada linha da tabela §6 (ADRs Sugeridos), confirme com grep/busca textual que existe a marcação `Dependência arquitetural: ADR-NNNN` na seção correspondente do `frd.md`. Se faltar, adicione." Isso teria corrigido a única falha realmente atribuível ao artefato nos 3 evals (eval 2 / asserção 5) e é a mudança de maior alavancagem porque fecha uma lacuna que já se mostrou reproduzível mesmo quando o resto da spec é seguido corretamente.

2. **[Média] Unificar §11.2–§11.4 numa única subseção "Protocolo de ADR" com uma checklist de 3 passos** (sugerir na tabela §6 → marcar inline no FRD → não criar o ADR), em vez de três subseções (§11.2, §11.3, §11.4) que descrevem o mesmo fluxo em fatias — reduz a chance de o modelo tratar §11.4 como "detalhe de formatação" opcional e não como parte do mesmo protocolo obrigatório.

3. **[Média] Seccionar a spec em núcleo obrigatório + referência de convenções**, movendo exemplos extensos de formatação (tabelas MoSCoW, templates de mensagem, exemplos de ADR) para um anexo que o agente só precisa consultar quando for escrever aquela seção específica, em vez de carregar as 1028 linhas de uma vez. Reduz o tempo de execução (hoje +75% vs. baseline) sem alterar o conteúdo normativo.

4. **[Baixa] Nenhuma mudança de texto do artefato é necessária para os casos de "invenção de valor" e "vazamento técnico"** (eval 1 e eval 3) — esse comportamento já funciona bem com o artefato; o risco ali é de regressão silenciosa, então vale considerar um teste de regressão permanente (os próprios evals 1 e 3) em vez de mudança de texto.

## 6. Qualidade dos casos de eval (`eval_quality`)

- **Cobertura dos 3 casos é boa e complementar:** eval 1 testa geração do zero (amplitude), eval 2 testa atualização incremental sem quebrar contratos existentes (regressão), eval 3 testa recusa de escopo/técnica (guarda de fronteira). As três dimensões são relevantes e não redundantes.
- **Mas o "poder discriminante" real é desigual:** eval 1 e eval 3 discriminam fortemente (4 de 6 e 4 de 5 asserções, respectivamente, mudam de falha para sucesso com o artefato); eval 2 **não discrimina nada no agregado** (mesmo pass_rate nas duas configurações) — ele está inflando o denominador de "evals rodados" sem mover o delta. Vale revisar o que tornaria o eval 2 mais discriminante (ex.: uma asserção sobre um comportamento onde o baseline tipicamente erra ao atualizar, como renumerar BR-01/BR-03 ou mudar o campo Status do cabeçalho — comportamentos que o próprio `eval_feedback` do benchmark já registrou como não cobertos: "without_skill mudou o campo 'Status' para 'Em Elaboração'" e "estendeu Requisitos Relacionados de BR-01/BR-03", ambas regressões reais que nenhuma asserção pegou).
- **Duas asserções têm redação frágil, já sinalizada pelo próprio `eval_feedback` gerado no benchmark:**
  - eval 1/3: "usa apenas os valores [enum fechado]" na Matriz de Rastreabilidade é mais estrita do que a spec exige — penaliza anotação complementar legítima.
  - eval 1: "aparecem apenas na seção Fora de Escopo" é logicamente inconsistente com o próprio texto do PRD de entrada (F-06 menciona "transferência futura" fora da seção de Fora de Escopo).
  - eval 3 (duas asserções): exigir literalmente o código `FRD-*`/`BR-*` deixa escapar um agente que usa outra nomenclatura (`RF-`/`RNF-`) mas ainda comete a violação de fundo (vazamento técnico, invenção de NFR) — a parte que realmente importa (VAL-NN, ausência do termo técnico nas seções de requisito) já está corretamente coberta em paralelo na mesma asserção, então a única correção necessária é trocar "`FRD-*`/`BR-*`" por "qualquer requisito (de qualquer prefixo)".
- **Nenhum caso testa runs múltiplos** (`runs_per_configuration` no metadata diz 3, mas só há 1 run por configuração nos dados) — a variância reportada (stddev 0,0981 com artefato, 0,3727 sem) é calculada sobre 3 evals diferentes, não sobre repetições do mesmo eval; não há evidência de estabilidade/flakiness real do artefato em runs repetidos do mesmo caso.
- **Conclusão de qualidade:** os casos são bem desenhados na intenção, mas duas asserções têm redação que penaliza comportamento correto (falso negativo) e um eval inteiro (atualiza-frd) não discrimina o valor do artefato — a amostra de 3 casos é pequena demais e um deles não contribui informação, então o delta de +0,49 medido é real, mas se apoia essencialmente em 2 dos 3 casos.
