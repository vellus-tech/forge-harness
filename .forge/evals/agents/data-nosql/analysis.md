# Análise do benchmark — agente `data-nosql`

Adendo R03, issue #176. Agregação determinística via `scripts.aggregate_benchmark` sobre `workspace/iteration-1` (3 evals × 1 run por configuração). `benchmark_ok=true`.

## Resultado

- Com skill: pass rate médio 88,67% (0,83 / 0,83 / 1,00), tempo médio 145,7 s, tokens médios 5021.
- Sem skill: pass rate médio 33,33% (0,50 / 0,50 / 0,00), tempo médio 116,3 s, tokens médios 4751,7.
- Delta = 0,8867 − 0,3333 = **+0,5533**.
- Veredito: **agrega** (delta ≥ 0,15).

Os tokens só foram medidos nos dois runs do eval 1 (with_skill 15063, without_skill 14255); os demais runs reportam `tokens: 0` por ausência de instrumentação no transcript, não por custo zero — a média de tokens acima não é comparável em base plena e não deve ser lida como "a skill quase não gasta mais tokens".

## Asserções não discriminantes

Nenhuma asserção passa igualmente em ambas as configurações (todas as 17 comparações mostram diferença a favor de with_skill ou reprovam nas duas). As duas que reprovam com a skill também são as únicas onde with_skill não bate 100%:

- Eval 1, asserção Decimal128/inteiro de 64 bits: falha nas duas configurações, mas por motivos distintos — with_skill entrega `number` (double IEEE-754) como correção principal, oferecendo Int64/Long só como condicional; without_skill oferece Decimal128 como correção válida. A skill move o erro (de "unidade errada" para "tipo ainda impreciso"), não o elimina.
- Eval 2, asserção N-08/Scan→Query com write sharding: falha nas duas — with_skill troca Scan por Query num GSI esparso por status, que concentra os pendentes numa única partição no pico (~8 mil/s), sem distribuir a carga; without_skill nem cita N-08.

Isso indica que a asserção de Decimal128 e a de sharding testam uma exigência mais específica (write-sharding explícito) do que o agente atualmente entrega, e vale investigar se o catálogo/checklist do agente cobre write sharding como alternativa a GSI esparso quando a carga é de escrita concentrada.

## Onde o artefato ajudou

- Eval 3 (recusa "saldo só no Redis"): with_skill acerta 5/5, without_skill 0/5. Sem a skill/agente, o executor nem consulta `.forge/rules/data/*`, entrega desenho completo de Redis-only (chaves, script Lua de débito, `appendonly`/`appendfsync`) e ainda instrui o task-coder a criar um ADR registrando a decisão — violando "uma árvore, um escritor" e o protocolo de não registrar decisão. O bloco `CONFLITO` do artefato (seção "Protocolo", passo 2) é o mecanismo que produz essa diferença: sem ele o executor trata o pedido do usuário como contexto de mesma autoridade que a rule.
- Eval 1 (ledger MongoDB/TS): with_skill localiza N-07/N-03/N-01/N-23 por id e `arquivo:linha`, cita a topologia P-S-S do README e recomenda `withTransaction` com retry embutido; without_skill acerta os antipatterns de array sem teto e de transação, mas não cita nenhum id de catálogo, não vincula o árbitro ao risco de perda de escrita (P-S-A → P-S-S) e cobre só duas das três pernas do isolamento por tenant (falta o filtro injetado no repositório).
- Eval 2 (pedidos DynamoDB/Java): with_skill interpreta corretamente a saída do gate `check-data-governance` como "não verificado" (universo vazio, projeto Java) em vez de tratá-la como aprovação — comportamento descrito explicitamente no passo 3 do protocolo do artefato ("`FAIL data-governance/universo-vazio` é 'não verificado'... Nenhum dos dois últimos vira aprovação"). O without_skill nem executa o gate e especula sobre o motivo da ausência de achado, sem afirmar a não-verificação de forma explícita — a asserção correspondente reprova por essa omissão.

## Onde o artefato atrapalhou ou não bastou

- Nenhuma evidência de que a skill piora uma asserção que sem ela passaria (nenhum caso "sempre falha com skill, passa sem skill").
- Tempo de execução: with_skill é ~29 s mais lento em média (145,7 s vs 116,3 s), com alta variância (stddev 62,5 s) — o eval 2 with_skill levou 208 s, quase o dobro do eval 3 (83 s). Plausível que a diferença venha da varredura obrigatória (`scan.sh` + `check-data-governance.sh`) e da leitura de rules/ADRs no protocolo, mas o benchmark não captura tool_calls (todos os runs reportam `tool_calls: 0`), então essa hipótese não é verificável pelos dados agregados.
- N-06/N-10 (partition key de baixa cardinalidade / projeção GSI `ALL`) no eval 2: with_skill cita os dois ids corretamente; without_skill identifica os mesmos pontos em substância (hash_key status, projection ALL→INCLUDE) mas sem os ids do catálogo e com uma escolha de partition key (pedidoId) que não se alinha ao padrão de acesso dominante (por cliente) exigido pela asserção — reprova por não citar N-06/N-10, não por divergência de conteúdo relevante.

## Trechos ignorados, ambíguos ou contraditórios

- O artefato diz, no passo 3, que `check-data-governance.sh` "só lê `.go`, `.kt`, `.ts`, `.rego`, `.py` e `.md`" — Java fica de fora por design, e isso é exatamente o que o with_skill do eval 2 reporta corretamente. É um ponto de conhecimento explícito no artefato que o without_skill não tem acesso e por isso erra.
- O bloco `CONFLITO` (seção "Protocolo") lista `registro:` como responsabilidade da sessão principal ou pipeline `/forge:*`, nunca do próprio agente — mas o campo é redigido como texto livre dentro da resposta, e a grading do eval 3 confirma que a marca "este agente não registra" foi suficiente para passar. Não há ambiguidade nesse ponto; é reforço, não achado.
- A frase do artefato "consulte o context7 ... antes de afirmar um default" (passo 6) não aparece testada em nenhuma das três asserções lidas — os três evals não exercitam versão de produto/default de biblioteca, então essa parte do protocolo fica sem cobertura de eval, não sem cobertura de comportamento.
- Achado tangencial no eval 2, with_skill: a citação da faixa de linhas do GSI ("dynamo.tf:16-22") saiu imprecisa mas não decidiu a passagem — grading tolerou por não ser exigida no critério. Sinal de que o agente é impreciso em citação de linha para blocos multi-linha (Terraform), mesmo quando acerta a linha de âncora de recursos simples.

## Melhorias concretas, priorizadas

1. **Cobrir write sharding como alternativa explícita ao GSI esparso quando a partição quente é de escrita concentrada.** O checklist atual do artefato lista "N-08 (Scan no caminho quente)" mas não distingue Scan→Query-simples (ainda quente) de Scan→Query-distribuída (sharding por sufixo). Adicionar ao passo 5 (Julgamento) ou ao checklist um critério: "se o volume de escrita por partição estimado excede X/s, GSI por status sozinho não resolve — avalie sharding por sufixo calculado". Referência: eval 2, asserção N-08, falha em with_skill.
2. **Fechar a lacuna de Decimal128 vs. inteiro de 64 bits.** O checklist já diz "nunca `Decimal128` nem ponto flutuante", mas a resposta with_skill do eval 1 recomendou `number` (double) como correção principal e citou Int64/Long só condicionalmente. Vale reforçar no artefato ou na skill `data-nosql-practices` (não só no checklist, mas na seção de recomendação) que a correção de Decimal128 deve ser categórica: inteiro de 64 bits, sem alternativa condicional a `number`. Referência: eval 1, asserção Decimal128, falha em with_skill.
3. **Padronizar citação de faixa de linha em blocos Terraform/YAML multi-linha.** Não bloqueou grading neste run, mas é um padrão de imprecisão observável (dynamo.tf:16-22 quando o recurso relevante está em outra linha). Baixa prioridade — mencionar no passo 6 que trecho multi-linha deve citar a linha de início do bloco relevante, não uma faixa aproximada.
4. **Instrumentar tokens e tool_calls no runner de eval**, não no artefato em si — sem esses dados não é possível confirmar se o custo adicional de tempo do with_skill vem da varredura obrigatória (scan.sh + check-data-governance.sh) ou de outro fator. Isso é melhoria de tooling de benchmark, não do agente, mas impede avaliar o trade-off tempo/qualidade com confiança.

Nenhuma melhoria aqui é urgente o bastante para bloquear o veredito: a skill/agente já produz o comportamento de maior impacto (recusa de Redis-only, interpretação correta do gate "não verificado", citação de antipatterns por id) que o executor sem ela simplesmente não tem.
