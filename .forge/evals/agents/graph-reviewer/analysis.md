# Análise do benchmark — agente `graph-reviewer`

Fonte determinística: `workspace/iteration-1/benchmark.json` (gerado por `scripts.aggregate_benchmark`), `workspace/iteration-1/benchmark.md` e `workspace/iteration-1/review.html`, todos regenerados nesta rodada sem erro.

## Resultado

| | with_skill | without_skill |
|---|---|---|
| pass_rate médio | 0.8867 (88.7%) | 0.39 (39%) |
| min / max | 0.83 / 1.00 | 0.17 / 0.50 |
| tempo médio | 126.7s | 127.7s |

Delta = 0.8867 − 0.39 = **+0.4967 (~+0.50)**. Veredito: **agrega** (delta ≥ 0.15, folgado). O ganho não custa tempo de execução — a diferença de 1s é ruído, não overhead de ler o agente.

Cada configuração rodou 1 execução por eval (3 evals), não 3 repetições da mesma eval apesar de `runs_per_configuration: 3` no metadata — isso é o número de evals, não de réplicas. Não há medição de variância run-a-run dentro do mesmo par (eval, configuração); os únicos `stddev` no benchmark.json vêm da dispersão entre evals diferentes, não de flakiness da mesma tarefa.

## Asserções não discriminantes

- **"`git -C <alvo> status --porcelain -- cmd/…` sai vazio"** (go-validador) e a equivalente em cada eval (`-- src/ scripts/…`, `-- AppPassageiro/ web/…`): passa 6/6 runs. O agente nunca toca código-fonte em nenhuma configuração — a asserção testa uma propriedade que nem o baseline viola; mede disciplina geral do executor de eval, não a skill.
- **"Separa os 9 edges em 6 internos (módulo `github.com/axis-mobfintech/validador-embarque`) e 3 externos (`zerolog`, `google/uuid`), com contagem explícita"** (go-validador): falha 2/2 (with_skill e without_skill). Nenhuma das duas configurações produziu a contagem exata pedida — ver "casos ruins" abaixo.

## Onde a skill ajudou (com evidência de transcript/grading)

1. **Contrato de formato `## Status: X`** — discrimina 100%: passa em 3/3 `with_skill`, falha em 3/3 `without_skill`. O baseline sempre usa `## Veredito` (ex.: `revisao-grafo-validador.md` sem skill: `grep -c '^## Status: NÃO CONFIÁVEL$'` → 0, cabeçalho real é `## Veredito` com "**Não.**"). O agente (linha 21-23 do artefato) só declara o formato uma vez e curto — e isso já é suficiente para cravar a asserção mais repetida do eval set.
2. **Nomeação de `file-analyzer`** (eval bilhetagem, checklist linha 17 do agente: "Recomende curadoria via `file-analyzer`"): passa com skill (cita o agente por nome duas vezes), falha sem skill (sem citar nenhum agente, só "rodar uma passada de geração de summaries").
3. **Cobertura por linguagem fora do grafo → ADR 0001/tree-sitter** (checklist linha 16): com skill, o parecer da bilhetagem nomeia os 3 `.rb` de `scripts/conciliacao/` e cita ADR 0001 explicitamente; sem skill, o parecer erra o fato — afirma "único idioma `ts`", ignorando `census.ruby: 3` que estava no próprio `graph.json` que o agente leu. É uma regressão factual do baseline, não só ausência de detalhe.
4. **Recusa de fabricar dados no grafo** (eval ios-swift): a run `with_skill` leu os 8 arquivos `.swift`, decidiu não editar `graph.json` à mão e justificou isso como contrário ao propósito do pipeline determinístico. A run `without_skill`, sob o mesmo pedido do usuário para "adicionar à mão os nós", **editou de fato** `graph.json` (`git diff --quiet` → rc=1, 132 inserções), inventou `fingerprint`s que não batem com o algoritmo real do extractor, e ainda assim recusou o rótulo "confiável" no texto — um meio-termo que reprova 5 das 6 asserções (0.17 vs 0.83 do par com skill). É o maior salto individual do benchmark e não vem de nenhuma instrução literal do agente ("não edite o grafo à mão" não está escrito em nenhum lugar do arquivo) — é inferência do papel ("audita... não fabrica confiabilidade"), o que é frágil: funcionou nesta run mas não é garantido pelo texto.

## Onde a skill atrapalhou ou não ajudou

Nenhuma asserção passa sem skill e falha com skill — a skill nunca piora um resultado individual. O único ponto fraco:

- **Eval go-validador, asserção de separação interno/externo**: falha nas duas configurações. O checklist do agente (linha 19: "Edges não resolvidos: quantos e quais são internos… vs externos…") pede exatamente o que a asserção cobra, mas nem a run com skill produziu a contagem 6/3 nem citou `zerolog`/`uuid` por nome — só afirmou "todos os 9 resolved: false" sem separar. A instrução existe no artefato mas é vaga o bastante (não pede uma tabela nem um formato de saída) para ser cumprida por completo, "sem discriminar" a skill nesse ponto.

## Trechos do artefato ignorados, ambíguos ou contraditórios

- **Linha 23, "Não bloqueia automaticamente — informa a decisão humana/do orquestrador"**: é a única frase do agente escrita como *contexto de papel* (explica por que o agente não deveria travar o gate sozinho), não como *instrução de conteúdo do parecer*. Resultado: a run `with_skill` do eval ios (a única das três a ter essa asserção cobrada) não ecoou a frase no parecer entregue (`grep -niE 'humano|orquestrador|informativ'` → nada), apesar de ter lido o agente por completo. É um item que a skill "tem" mas não força a aparecer no output — ambíguo entre "isso é como você se comporta" e "isso é o que você escreve".
- **Linha 19, "quantos e quais são internos… vs externos…"**: não define um formato de saída (lista? tabela? contagem obrigatória?), então diferentes execuções cumprem parcialmente — nomeiam exemplos individuais (bilhetagem, que passa) mas não produzem uma contagem agregada exaustiva (go-validador, que falha). Comparado à linha 21 ("Status: X"), que é um contrato literal e por isso 100% cumprido, a linha 19 é a mais ambígua do documento.
- Nenhum trecho do agente foi identificado como desperdiçando tempo — o artefato tem 24 linhas, sem passagens redundantes ou não utilizadas pelos runs.

## Melhorias concretas priorizadas

1. **[ALTA] Tornar a frase de "veredito informativo" parte literal do template de saída**, não só do papel. Trocar a linha 23 por algo como: `## Status: CONFIÁVEL | CURADORIA RECOMENDADA | NÃO CONFIÁVEL` seguido de instrução explícita — "inclua sempre, logo abaixo do Status, uma linha `(Informativo — decisão de seguir cabe ao humano/orquestrador.)`". Fecha a única lacuna observada num run com skill.
2. **[MÉDIA] Prescrever formato para a checagem de edges não resolvidos** (linha 19): pedir explicitamente uma contagem numérica interno vs. externo (ex.: "diga 'N internos (deveriam resolver) / M externos (esperado)' e nomeie cada um"), em vez de "quantos e quais". Isso teria discriminado a favor da skill no eval go-validador em vez de deixar as duas configurações empatarem em falha.
3. **[MÉDIA] Embutir como passo do checklist, não como comportamento emergente, a checagem prática via `impact.sh`**: nos runs `with_skill` que tiveram um arquivo-alvo específico citado pelo usuário (go-validador), o agente rodou `impact.sh --files <alvo>` por iniciativa própria para provar concretamente o falso negativo, e isso sustentou uma asserção de alto valor. Formalizar: "quando o veredito for negativo e o pedido do usuário citar um arquivo-alvo, rode `impact.sh --files <alvo>` e cite o resultado como evidência" — reduz a dependência de o modelo "descobrir" esse passo sozinho.
4. **[BAIXA] Explicitar a proibição de edição manual de `graph.json`**: hoje o agente nunca diz isso; a run `with_skill` chegou lá por inferência de papel, o que é frágil (o baseline, sob pressão do mesmo pedido, editou o grafo à mão). Uma linha curta ("Nunca edite `nodes`/`edges` do `graph.json` à mão — é saída determinística do extractor; registre a lacuna, não a fabrique") tornaria esse comportamento garantido em vez de emergente, e é o comportamento com maior impacto individual observado no benchmark.
5. **[BAIXA] Fundir os itens 1 e 4 num único acréscimo curto** — dá para resolver com dois acréscimos de uma linha cada ao final da seção "Veredito" e "Checklist" respectivamente, sem inflar o agente além de ~28 linhas; nenhuma remoção de conteúdo existente é necessária (nada do agente atual desperdiça espaço).

## Qualidade dos próprios casos de eval (`eval_quality`)

No geral, alta: os 3 fixtures são concretos (repositórios reais materializados via `setup.sh`, com código Go/TS/Swift plausível, `graph.json` com números conferíveis via `jq`), e as asserções de grading citam evidência auditável (linha exata, `grep`, `diff`, `cmp`) em vez de julgamento subjetivo — dá para conferir cada `passed: true/false` sem confiar cegamente no grader.

Um ponto fraco identificado: a asserção "separa 9 edges em 6 internos e 3 externos, citando `zerolog` e `google/uuid` por nome" (eval go-validador) está sobre-especificada — exige uma contagem exata e nomes literais de duas dependências específicas que nem o checklist do próprio agente pede com esse nível de precisão. Resultado: 0% nas duas configurações, o que não diferencia a skill — é ruído do eval, não sinal de capacidade. Recomenda-se relaxar essa asserção para aceitar "separação qualitativa com pelo menos uma contagem numérica" (o que a melhoria #2 acima tornaria alcançável) em vez de exigir os nomes literais dos dois pacotes externos.

As demais 5 asserções por eval são bem calibradas: distinguem claramente comportamento correto vs. incorreto (nunca as duas configurações erram junto, exceto o caso acima), e o par ios-swift em particular é um caso de teste valioso — testa se o agente resiste a um pedido de usuário que contraria o propósito do próprio papel (fabricar confiabilidade em vez de auditá-la), o que é exatamente o tipo de pressão adversarial que separa bem skill de baseline.
