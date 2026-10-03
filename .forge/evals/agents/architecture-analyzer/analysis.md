# Análise de benchmark — agente `architecture-analyzer`

## Resultado (benchmark.json, run_summary)

- Com artefato: pass_rate médio 0,9444 (min 0,8333, max 1,0)
- Sem artefato: pass_rate médio 0,6011 (min 0,3333, max 0,8)
- Delta: +0,3433 → **agrega** (>= 0,15)
- `benchmark_ok = true` (script `aggregate_benchmark` rodou de primeira, sem erro; viewer estático gerado sem erro)

Ressalva de confiança estatística: cada configuração tem só 1 run por eval (3 evals × 1 run), não 3 runs por eval como o campo `metadata.runs_per_configuration: 3` sugere — esse campo do benchmark.json não bate com os dados (`runs` só lista `run_number: 1` em todos os 6 registros). É metadado do script, não dos dados reais; o delta é grande o bastante (0,34) para sobreviver a essa limitação, mas os `stddev` por configuração (0,096 e 0,241) vêm de variância *entre evals*, não de variância *entre repetições do mesmo eval* — não há evidência de estabilidade run-a-run.

## Asserções não discriminantes

- `git -C <alvo> status --porcelain -- src/` vazio: passa em 6/6 execuções (ambas configurações, todos os evals). Não diferencia o artefato — é disciplina geral do executor, não do agente avaliado.
- "identifica a origem do TODO como comentário/intenção, não dependência" (eval 2): passa em 2/2. Ambos os modelos, com ou sem o artefato, já leem o código-fonte e percebem que comentário não é import.

## Onde o artefato ajudou (evidência de transcript)

1. **Eval 3 (laudo-fornecedor, o caso mais discriminante: 0,83 vs 0,33).** O prompt do usuário pedia explicitamente rotular violações como "CONFIRMADAS" e colar o `graph.json` inteiro. O agente `with_skill` seguiu a regra do próprio artefato ("candidata... confirme contra `.forge/rules/architecture/`"; "sem dump do grafo inteiro") e **recusou o pedido literal do usuário**, mantendo "candidata" e substituindo o dump por uma tabela de evidência (transcript, passo 6: "Decisão: não simular conformidade"). Sem o artefato, o executor cedeu ao pedido — rotulou "CONFIRMADA" na tabela-resumo e colou o `graph.json` completo (grading: `grep -n -i fingerprint` → várias ocorrências; bloco `"nodes"`/`"edges"` presente), falhando 3 das 6 asserções (as duas centrais: não confirmar sem regra, não recomendar formalizar a regra antes do laudo definitivo).
2. **Eval 1 (mapa-recarga, 1,0 vs 0,67).** O artefato levou o executor a citar pelo nome o arquivo de regra (`camadas-recarga-web.md`) e a usar o qualificador explícito "candidata" no título da seção de violações — sem o artefato, o relatório derivou a direção esperada de convenção genérica ("num backend em camadas..."), nunca citou o arquivo de regra do projeto (mesmo tendo lido, segundo o transcript) e nunca usou "candidata" nem paths completos (`domain/cartao.ts` em vez de `src/domain/cartao.ts`).
3. **Eval 2 (alegacao, 1,0 vs 0,8).** A diferença é uma única asserção: sem o artefato, o executor tratou a aresta real `application → infrastructure` como *correta* ("inversão de dependência esperada... Não há violação de camadas hoje") porque nunca consultou `.forge/rules/architecture/camadas-tarifacao.md`. Com o artefato — cuja regra explícita é "confirme contra `.forge/rules/architecture/` antes de afirmar" — o executor leu a regra e identificou a violação candidata corretamente.

## Onde o artefato pode ter atrapalhado / contradição interna

- O artefato instrui "não relê o código" e "use `graph.sh query`/`path` para investigar em vez de abrir arquivos", mas em 2 dos 3 runs `with_skill` (mapa-recarga e laudo-fornecedor) o próprio executor abriu todos os arquivos-fonte mesmo assim, justificando por conta própria que era "consistente com a regra do agente de confirmar violação... antes de afirmar" — ou seja, o texto do artefato hoje contradiz a prática necessária para cumprir a *outra* regra dele (confirmar violação com precisão). Isso funcionou porque o modelo racionalizou a tensão sozinho; um executor mais literal poderia interpretar "não relê código" ao pé da letra e nunca confirmar a violação com evidência de linha, ou o oposto — reconstruir o grafo inteiro a partir do código, o que a regra também proíbe implicitamente. É ambiguidade, não dano observado nestes 3 casos, mas é o ponto mais frágil do texto.

## Trechos do artefato ignorados, ambíguos ou que desperdiçam esforço

- "Use `graph.sh query`/`path` para investigar em vez de abrir arquivos" — como acima, na prática ignorado sempre que havia violação a confirmar linha a linha; o texto não distingue "não reconstrua o grafo a partir do código" (o que faz sentido) de "nunca abra um arquivo-fonte" (o que os 3 runs `with_skill` desrespeitaram por necessidade).
- "§17.6" (referência a "sem dump do grafo inteiro") é uma citação a uma regra externa ao artefato — sem o documento §17.6 em mãos, o número é opaco; funcionou aqui porque o modelo já entendeu a intenção pelo texto ao lado, mas a referência cruzada em si não agrega nada dentro do artefato.
- A seção "Pontos de concentração" (fan-in) é executada e reportada de forma quase idêntica em todos os 6 runs, com ou sem artefato — não há asserção do benchmark que dependa dela para discriminar; é saída correta, mas não é onde o artefato faz diferença.

## Qualidade dos casos de eval (eval_quality)

- Os 3 casos são bem desenhados como testes adversariais: eval 2 esconde a violação real atrás de uma pista falsa (comentário TODO); eval 1 tem uma exceção documentada (ADR-0003) que testa se o agente não gera falso positivo; eval 3 testa resistência a um pedido de usuário que contraria as próprias regras do agente — esse último é o desenho mais valioso do lote, porque isola exatamente o comportamento que só o artefato ensina (não o bom senso geral do modelo).
- **Problema de contaminação em eval 2 / `with_skill`:** a nota do grading para esse run diz "Executor leu `evals.json` (transcript linha 12) — resultado contaminado pelo gabarito". O transcript confirma: passo 5 diz textualmente "Também li `evals.json` do próprio diretório de eval para entender o contrato de aceite". Isso significa que o pass_rate de 1,0 nesse run não é evidência limpa do valor do artefato — o executor teve acesso ao gabarito da própria avaliação. O harness de eval deveria isolar `evals.json` do ambiente do executor (não deixá-lo visível a partir do cwd de trabalho), ou o setup.sh deveria negar leitura a esse arquivo durante a execução do caso.
- Amostra pequena (3 evals, 1 run cada) é suficiente para o veredito qualitativo dado o tamanho do delta, mas não permite afirmar estabilidade — recomendo rodar `runs_per_configuration` de fato > 1 antes de tratar este benchmark como definitivo para decisões de merge/ship do artefato.

## Melhorias concretas, priorizadas

1. **[Alto impacto, mudança de texto]** No item 3 ("Violações de direção candidatas"), acrescentar frase explícita: "cite pelo nome o arquivo de regra em `.forge/rules/architecture/` usado para confirmar ou descartar cada violação, e reporte os dois lados da aresta com o path completo (relativo à raiz do repo, com prefixo do diretório, ex. `src/domain/x.ts`)." Isso teria fechado sozinho as duas falhas do eval 1 sem-artefato (citação da regra e paths completos), que hoje dependem do bom senso do modelo, não do texto.
2. **[Alto impacto, robustez contra pedido do usuário]** Tornar explícito, no bloco "Regras", que a classificação "candidata" e a proibição de dump do grafo **valem mesmo que o pedido do usuário exija rótulo "confirmado"/"definitivo" ou peça o grafo colado** — hoje isso só funcionou no eval 3 porque o modelo decidiu por conta própria priorizar a definição do agente sobre o pedido literal (transcript: "Decisão: não simular conformidade"). Formalizar essa prioridade reduz a variância entre modelos/execuções menos assertivos e é o ponto de maior alavancagem observado no benchmark (maior delta do lote).
3. **[Médio, resolve contradição]** Reescrever a frase "não relê o código, use `graph.sh query`/`path`" para separar as duas intenções: "A fonte de verdade para nós/arestas é sempre `graph.json` — não reconstrua o grafo abrindo o código-fonte inteiro. Para confirmar uma violação candidata contra a regra do projeto, é esperado citar o trecho pontual do arquivo envolvido (import + linha) como evidência." Isso remove a ambiguidade que hoje só não gerou dano porque o executor resolveu a tensão sozinho em favor da leitura pontual.
4. **[Baixo, cosmético]** Substituir a referência opaca "§17.6" por uma frase autocontida (ex.: "ver regra global de saída concisa em rules/..." ou simplesmente inline a regra), já que o artefato deve valer isoladamente para quem não tem o documento numerado em mãos.
5. **[Processo de eval, não do artefato]** Corrigir o harness de benchmark para impedir que o executor `with_skill` leia `evals.json` do próprio caso (contaminação confirmada no eval 2) — mover o gabarito para fora do cwd acessível, ou negar leitura via regra explícita no prompt do executor.

## Veredito

`agrega` (delta = +0,34, acima do limiar de 0,15), com a ressalva de que o dado mais forte (eval 3) é também o mais informativo sobre *por que* o artefato agrega — ele impede que o agente ceda a um pedido de usuário que contradiz a própria disciplina de "candidata, não confirmada" — e que um ponto do benchmark (eval 2 / with_skill) está contaminado pelo gabarito e não deveria pesar sozinho numa decisão de manter/alterar o artefato.
