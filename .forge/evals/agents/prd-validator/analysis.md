# Análise do benchmark — agente `prd-validator`

## Resultado (benchmark.json, iteration-1)

Pass rate com o artefato: 100% (média 1.0, desvio 0.0, 3 evals × 1 run cada). Pass rate sem o artefato: 52,33% (média 0.5233, desvio 0.3219, min 0.17 no eval 1, max 0.80 no eval 2). Delta = 1.0 − 0.5233 = **+0.4767 (~+0.48)**. `benchmark_ok = true` — o `aggregate_benchmark` rodou de primeira, sem precisar corrigir estrutura de diretório ou JSON; o viewer estático (`review.html`) também gerou sem erro. Como o delta é ≥ 0.15, o veredito é **agrega**.

Ressalva de rótulo do próprio script: `benchmark.md` imprime "3 runs each per configuration", mas na prática são 3 evals distintos com 1 run cada por configuração, não 3 repetições do mesmo eval — o desvio-padrão de 0.32 em `without_skill` mistura variação entre casos com variação de execução, não mede flakiness de um caso isolado. Isso é uma limitação do desenho do experimento (n=1 por eval), não do script de agregação.

## Asserções não discriminantes

Passaram em ambas as configurações em pelo menos 2 dos 3 evals, então não isolam o valor do artefato: "discovery-notes.md byte a byte igual à fixture" (evals 2 e 3), "prd.md byte a byte igual à fixture quando não há aprovação aplicável" (evals 2 e 3), a recusa de fabricar entrevista da Carla e a indicação de como destravar (eval 3), a detecção do conflito do cartão de crédito e da meta de NPS sem lastro (eval 1, sub-asserções 4 e 5), e a preservação de P1–P4 sem renumeração no segundo ciclo (eval 2). Em todos esses pontos o modelo base, mesmo sem ler a especificação do agente, já produz o comportamento certo por bom senso de produto e por instrução explícita de não alterar arquivos de origem — o artefato reforça mas não cria essa capacidade.

## Onde o artefato ajudou (evidência do transcript)

O ganho real está inteiramente na camada de formato/contrato de arquivo, não na análise crítica em si:

- Eval 1 (`valida-prd-recarga-pix`), without_skill: o modelo fez a mesma análise substantiva (achou o cartão de crédito, a meta de NPS, o excesso técnico do RF-02), mas gravou o relatório em `outputs/revisao-critica-prd.md`, num formato de prosa com seções "1. Inventado / 2. Fora de lugar / 3. Faltando", sem `docs/product/prd/prd-validation.md`, sem IDs `Pn`, sem os cinco subcampos (Evidência/Impacto/Sugestão/Decisão do usuário/Status de aplicação). Resultado: 1/6 (17%) — a especificação de arquivo e formato do Passo 3 é o que muda esse número para 6/6.
- Eval 3 (`recusa-alterar-discovery-para-validar`), without_skill: a recusa de fabricar a entrevista foi correta, mas o relatório saiu como `docs/product/prd/validation-result.md` (nome errado) com "Status: Não Validado" (fora do vocabulário `Em validação | Aguardando ajustes | Validado com ressalvas | Validado`) e sem IDs `Pn` nem os campos "Decisão do usuário"/"Status de aplicação" — 3/5 (60%) contra 5/5 com o artefato.
- Eval 2 (`aplica-aprovacoes-parciais-segundo-ciclo`), without_skill: a edição do PRD e a lógica de aprovação parcial (aprova P2/P3, rejeita P1, não mexe em P4) saíram corretas, mas o campo obrigatório "Status de aplicação" de P1 foi escrito como "NÃO APLICADO (rejeitado pelo usuário)" em vez do valor do vocabulário fechado `REJEITADO`, e os marcadores de cabeçalho viraram `[APROVADO]` (fora do vocabulário `PENDENTE|APLICADO|REJEITADO`) — 4/5 (80%) contra 5/5.

Ou seja: o artefato não ensina o modelo a pensar criticamente sobre PRD (isso o modelo já sabe fazer razoavelmente bem), ensina onde gravar e em que vocabulário fechado gravar — e é exatamente aí que o `without_skill` tropeça nos três evals.

## Trechos do artefato ignorados, ambíguos ou contraditórios

- O arquivo termina abruptamente no exemplo de template (linha 172, só até "P2"), sem uma linha de fechamento nem instrução do que fazer além de dois problemas de exemplo — não chegou a causar falha nos runs observados, mas é um artefato com aparência de truncado.
- O campo é rotulado "Status de aplicação" mas um de seus três valores válidos é `REJEITADO` — semanticamente estranho para um campo de "aplicação" (o item não foi "aplicado como rejeitado", foi simplesmente não aplicado porque a decisão foi negativa). É exatamente essa aspereza de nomenclatura que o run without_skill "corrigiu" sozinho para "NÃO APLICADO", e é plausível que o mesmo aconteça eventualmente mesmo com o artefato lido, já que a única defesa contra esse desvio é o modelo copiar o vocabulário do template ao pé da letra, sem checagem automatizada.
- A especificação lista `Validado` como valor legítimo de "Status geral" mas não diz explicitamente "nunca marque Validado enquanto houver P-item PENDENTE" — nos três runs with_skill o modelo evitou isso por inferência correta (é obviamente o objetivo do processo), mas a regra não está escrita; é uma lacuna latente que as evals atuais não testam diretamente (nenhum eval verifica o caso "todos os itens resolvidos, o agente marca Validado corretamente").
- Não há nenhum script/lint embutido na especificação para verificar deterministicamente o próprio formato do relatório (existência do arquivo no path certo, vocabulário fechado dos campos, IDs sequenciais sem lacuna) — hoje essa conformidade depende inteiramente da leitura atenta do template pelo modelo, exatamente o ponto que mais diferencia with/without.

## Custo observado

O artefato custa em média +83,0s por execução (204,7s com vs 121,7s sem) — plausível, já que o relatório estruturado com 5 campos por problema (6 a 8 problemas no eval 1) é mais texto que a prosa livre do `without_skill`. O `without_skill` também tem desvio-padrão alto (55,2s, min 84s no eval 1 a max 185s no eval 2) porque é uma média entre 3 casos diferentes com 1 run cada, não repetições do mesmo caso — não é uma medida de estabilidade de tempo de um caso isolado, mesma ressalva da nota sobre `pass_rate.stddev`. Não há dado de tokens (`tokens: 0` em todos os runs — o campo não foi instrumentado nesta rodada de eval), então não dá para confirmar se o custo em tokens acompanha o custo em tempo.

## Melhorias concretas priorizadas

1. Adicionar uma checklist de auto-verificação determinística ao fim do Passo 3 — antes de devolver a resposta, o agente deve confirmar por si mesmo (ou por grep local): arquivo em `docs/product/prd/prd-validation.md`; todo `Pn` com as 5 subentradas; `Decisão do usuário` ∈ {Aguardando decisão, Aprovado, Rejeitado}; `Status de aplicação` ∈ {PENDENTE, APLICADO, REJEITADO} — sem sinônimos. Isso fecha exatamente as três lacunas achadas no without_skill e reduz a dependência de o modelo "lembrar" o vocabulário fechado.
2. Renomear ou esclarecer o campo "Status de aplicação" quando a decisão é Rejeitada — por exemplo, documentar explicitamente que rejeição também é um "estado de aplicação final" e por isso usa o rótulo `REJEITADO` (não "não aplicado"), com uma frase que previna a paráfrase natural que o run without_skill produziu.
3. Tornar explícita a regra "nunca marcar Status geral como Validado com P-item PENDENTE aberto" — hoje é inferência, não regra escrita; um eval futuro deveria testar o caso positivo (todos os itens resolvidos → Validado) para confirmar que a passagem de "Aguardando ajustes" para "Validado" realmente acontece quando deveria, não só que o agente evita marcá-lo cedo demais.
4. Fechar a lacuna do exemplo de template: completar o bloco de código do Passo 3 com uma frase de fechamento (ex.: "adicione quantos problemas forem necessários, sempre numerados sequencialmente sem lacunas") em vez de terminar no meio do exemplo P2.
5. Não é prioridade mudar o núcleo de análise crítica — os 20 critérios do Passo 2 já produzem, mesmo sem o artefato, detecção substantiva de invenção de escopo, métrica sem lastro e excesso técnico; o retorno de investimento maior está em formato/vocabulário, não em ensinar criticidade.

## Qualidade dos casos de eval (eval_quality)

Os três casos cobrem facetas distintas e não redundantes do agente: validação inicial do zero (eval 1), ciclo de aprovação parcial com edição real do PRD (eval 2) e um teste de pressão adversarial — pedido explícito para fabricar dado de discovery e pular a validação por urgência de prazo (eval 3). As asserções são concretas e verificáveis por comando (grep/diff/awk), incluem checagens negativas fortes ("byte a byte igual à fixture") que impedem o agente de "passar" só por não ter feito nada, e cobrem tanto conteúdo quanto formato. Pontos fracos: (a) n=1 execução por eval por configuração, então não há medida de variância intra-caso, só entre casos — o desvio-padrão relatado no `run_summary` não deve ser lido como estabilidade do comportamento; (b) a asserção 3 do eval 1 e a asserção 4 do eval 2 são conjuntivas (misturam checagem de conteúdo com checagem de formato numa única asserção), o que no eval 1 ainda gerou sinal claro (falhou pela metade errada, registrado explicitamente na evidência), mas em geral esconde qual das duas metades falhou quando ambas podem falhar independentemente — seria mais diagnóstico separar em duas asserções. Qualidade geral: boa — mediram exatamente a coisa certa (formato + substância) e capturaram um cenário adversarial real, mas caberia rodar 2–3 repetições por eval antes de tratar o desvio-padrão como sinal de flakiness.

## Veredito

`with_pass_rate = 1.0`, `without_pass_rate = 0.5233`, `delta = +0.4767`, `benchmark_ok = true` → agrega (delta ≥ 0.15).
