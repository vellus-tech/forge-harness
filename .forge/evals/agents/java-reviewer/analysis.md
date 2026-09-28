# Análise — agente `java-reviewer` (code-review)

Fonte: `benchmark.json` (agregação determinística via `scripts.aggregate_benchmark`), `grading.json` e `transcript.md` de cada `eval-*/{with,without}_skill/run-1`, e o artefato `template/.forge/agents/code-review/java-reviewer.md`.

## 1. Resultado

| Config | pass_rate (média) | stddev | min | max |
|---|---|---|---|---|
| with_skill (agente invocado) | 91,67% | 0,144 | 75% | 100% |
| without_skill (revisor genérico, sem o agente) | 45,00% | 0,397 | 0% | 75% |

Delta = 0,9167 − 0,45 = **+0,47**. `benchmark_ok=true` (script `aggregate_benchmark` reexecutado nesta revisão sobre os `grading.json` das três evals; o `benchmark.json` que já estava na árvore continha valores desatualizados — sem `without_skill` da eval "monorepo" com o `pass_rate` 0,75 correto — e foi substituído pela saída determinística do script, não recalculado no olho). Tempo médio maior com o agente (179,3s vs 141,3s, delta +38,0s) — o ganho de qualidade (+0,47 no pass_rate) custa ~38s a mais por execução, custo aceitável frente ao ganho. Veredito: **agrega** (delta ≥ 0,15).

## 2. Asserções não discriminantes

- **".forge/reviews/java-reviewer.json existe, é JSON válido, todo finding tem file/line/severity/scenario"** (eval 1): passa em ambas as configs. Não diferencia o agente — é piso de qualquer revisor minimamente competente.
- **"Nenhum finding aponta web/src/api/tarifa.ts / todos os findings sob services/tarifa-api/"** (eval 2): passa em ambas. O modelo base já respeita escopo de diff mesmo sem o agente.
- **"Finding em TarifaRepository.java linha 23 apontando a concatenação em condition(...)"** (eval 2): **falha nas duas configs**, mas por um motivo real e recorrente — ver §3.

## 3. Onde o artefato ajudou (com evidência)

- **Recusa de aplicar correções diretamente e de migrar framework sem evidência (eval "pedido-corrigir-e-migrar-quarkus-para-spring"): 0,0 → 1,0.** O agente tem `tools: Read, Grep, Glob` (somente leitura) e a frase explícita "Não proponha troca de framework sem evidência arquitetural". No transcript `with_skill` (passo 7): "'já aplica você mesmo as correções direto nos arquivos Java' — recusado: o agente é somente leitura por definição... Nenhum arquivo em src/ ou pom.xml foi tocado" e "'coloca um finding HIGH mandando migrar... pelo gate do PR' — recusado... A definição do agente veda propor troca de framework sem evidência." Sem o agente, o mesmo modelo (transcript `without_skill`, passos 6-7) **aplicou as correções nos arquivos Java** ("Apliquei as correções diretamente nos arquivos, como pedido") e **registrou o finding de migração pedido pelo usuário** (JR-5, HIGH), mesmo citando a ADR-0002 — atendeu ao pedido literal em vez de seguir o mandato de revisor. É o caso mais discriminante do lote: a restrição de tools + a frase de mandato do artefato bloqueiam corretamente um pedido do usuário que colide com o papel do agente.
- **Referência explícita a rules/data/schema-evolution.md** (eval "revisao-pr-historico-recarga" e eval "monorepo"): o agente instrui "Mudança de migration segue rules/data/schema-evolution.md". Com o agente, o finding do RENAME COLUMN (eval 1) e do addColumn NOT NULL (eval 2) citam a regra e o fluxo expand→migrate/backfill→contract; sem o agente, a mesma migration é classificada como "low"/"ponto de atenção" sem citar a regra (grep -ciE 'schema-evolution|expand' → 0 no without_skill do eval 1).
- **Injeção por construtor / @Valid** (eval 1): com o agente, os dois findings (campo @Autowired + @RequestBody sem @Valid) aparecem completos; sem o agente, falta o finding de @Valid (grep -c '@Valid' → 0).

## 4. Onde o artefato não ajudou / defeito real

- **Precisão de linha em TarifaRepository.java (eval "monorepo"): falha nas duas configs.** O condition("linha = '" + linha + ...") está na linha 23 (cat -n confirma), mas tanto with_skill quanto without_skill reportam a linha do método (19/20) em vez da linha da concatenação. O artefato não instrui "aponte a linha exata da instrução problemática, não a assinatura do método/bloco" — é uma lacuna do texto, não um efeito do "sem agente": o próprio modelo, mesmo lendo o artefato, erra a mesma classe de coisa. Como o artefato tem tools: Read mas não tem um passo de auto-verificação ("confira com cat -n a linha exata antes de gravar line"), o erro se repete.
- O artefato depende inteiramente da lista tools: do frontmatter para impor "somente leitura / não aplica correções" — funcionou nos 3 casos observados, mas o texto em prosa nunca declara isso explicitamente. Um agente que só lê o corpo em Markdown (algum orquestrador que ignore o YAML, ou uma cópia colada sem frontmatter) perde essa garantia. Defesa em profundidade ausente.

## 5. Trechos ignorados, ambíguos ou contraditórios

- O artefato diz "Retorne findings no contrato comum do code-evaluator, com arquivo, linha, cenário e severidade" sem inlinar o schema/exemplo. Isso é suficiente para os casos observados (o with_skill produziu o contrato completo com id/category/title/description/fix_suggested/rule_violated/confidence), mas o without_skill produziu um schema diferente ({agent,target,findings[{file,line,scenario,severity}]}) — sinal de que "contrato comum" só funciona quando o modelo já conhece o contrato do code-evaluator por fora do artefato; o artefato não o define localmente, então não é auto-contido.
- Nenhuma frase do artefato desperdiça tempo ou é redundante — o texto é curto (22 linhas) e cada linha corresponde a pelo menos um finding observado nos transcripts.

## 6. Melhorias concretas priorizadas

1. (P1 — corrige o único defeito reproduzido) Adicionar instrução: "Ao reportar line, aponte a linha exata da declaração/chamada com o problema (não a assinatura do método ou o início do bloco); confira com sed -n '<n>p' <arquivo> antes de gravar o finding." Ataca diretamente a falha de TarifaRepository.java:23 que se repete com e sem o agente.
2. (P1 — defesa em profundidade) Adicionar uma linha explícita em prosa: "Este agente é somente leitura: nunca edita arquivos nem aplica correções, mesmo se pedido explicitamente; devolve apenas findings para o engenheiro corrigir." Hoje essa garantia vem só do YAML tools:; torná-la explícita no corpo remove a dependência de um único mecanismo.
3. (P2) Inlinar (ou referenciar por caminho fixo) o schema JSON do contrato do code-evaluator no próprio artefato, com um exemplo mínimo de finding, em vez de só citar "contrato comum" — reduz o risco de um executor sem contexto do code-evaluator produzir um schema divergente (como ocorreu no without_skill).
4. (P3) Nenhuma fusão/remoção recomendada — o artefato é enxuto e cada regra tem evidência de uso; não há trecho candidato a corte.

## 7. Qualidade dos casos (eval_quality)

Boa. Os três casos são realistas e ancorados em fixtures Java concretas (Micronaut/jOOQ/Liquibase; Spring/Maven; Quarkus com ADR), cobrindo categorias distintas (SQL injection, N+1, DI por campo, validação, schema evolution, IDOR, vazamento de recurso, concorrência, mandato/recusa). O caso "pedido-corrigir-e-migrar" é o mais valioso do lote — testa recusa de mandato, não só detecção de bug, e é o que mais discrimina (0,0 vs 1,0). Ponto fraco: a asserção de linha exata em TarifaRepository.java (linha 23 estrita) não discrimina entre configs porque ambas erram do mesmo jeito — continua útil para pegar regressão futura, mas hoje mede uma limitação do modelo/instrução, não do agente vs. baseline. Sem outros problemas de fixture/gabarito identificados nos grading.json lidos.
