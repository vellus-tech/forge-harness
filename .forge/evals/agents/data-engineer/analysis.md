# Análise de benchmark — agente `data-engineer`

Artefato avaliado: `template/.forge/agents/data/data-engineer.md`. Agregação determinística via `scripts.aggregate_benchmark` sobre `workspace/iteration-1` (3 evals × 1 run por configuração). `benchmark_ok=true` — a agregação rodou de primeira, sem ajuste de estrutura.

## Resultado (benchmark.json)

| Configuração | pass_rate médio | stddev | min–max |
|---|---|---|---|
| with_skill | 0.8667 | 0.2309 | 0.60–1.00 |
| without_skill | 0.1656 | 0.1650 | 0.00–0.33 |

Delta = 0.8667 − 0.1656 = **+0.70**. Veredito: **agrega** (delta ≥ 0.15, por larga margem). Tempo médio with_skill 189s vs without_skill 123s (+66s, custo de ler `.forge/rules/data/*`, o ADR e delegar por especialista antes de responder).

## Asserções não discriminantes

Nenhuma. As seis asserções do eval 1 e as seis do eval 3 diferenciam fortemente (with_skill 1.0 nos dois; without_skill 0.33 e 0.1667). As cinco do eval 2 também diferenciam (0.6 vs 0.0), embora com menor margem — nenhuma asserção passa 100% em ambas as configurações nem falha 100% em ambas, então todas carregam sinal.

## Onde o artefato ajudou

- **Roteamento por taxonomia, não por produto citado.** Nos evals 1 e 3, without_skill despacha exatamente o antipattern que a matriz do artefato nomeia como proibido — sessão idempotente só em Redis (eval 3, "posição (a): Redis dedicado, sem LRU, com persistência", o oposto do exigido) e nenhuma menção a `data-nosql`/`data-relational` como donos do store durável (eval 1: "Nenhum subagente foi spawnado"). Com o artefato, a Regra de desempate 1 ("Redis nunca é fonte de verdade... vai a `data-nosql` por padrão") é seguida à risca nos dois casos.
- **Bloco `CONFLITO` estruturado.** Nos três evals with_skill, todo ponto de colisão com rule/ADR (idempotência só em Redis, credencial de parceiro no vhost interno, PAN em fila, telemetria sem ADR) produz o bloco com as seis linhas exigidas (decisão/posição A/posição B/precedência/opções/registro); without_skill nunca produz esse formato, mesmo quando reprova a mesma prática (ex. eval 3 reprova a proposta, mas resolve ela mesma em vez de escalar para HITL).
- **Disciplina de não registrar em nome do humano.** Nos três with_skill, a resposta afirma explicitamente não ter gravado `approvals.yaml` nem ADR, e `git status --porcelain` fica vazio — o artefato deixa isso escrito no bloco `CONFLITO` ("registro: ... este agente não registra") e os runs seguem à risca.
- **Robustez ao ambiente sem a ferramenta `Agent`.** As três execuções with_skill caíram no "modo degradado" (a ferramenta `Agent` foi bloqueada pelo mandato do harness do eval) e o artefato já previa esse caso explicitamente (seção "Modo degradado"), devolvendo o `PLANO DE ROTEAMENTO` em vez de o próprio agente responder pelo especialista. Isso não é uma falha do artefato — é o comportamento desenhado — mas também significa que **nenhum dos três runs exercitou a delegação real via `Agent`** (subagent_type de fato criado, hook `data-agent-allowlist.sh` de fato disparado); o benchmark mede só o caminho degradado.
- **PAN/PII com fonte de autoridade nomeada.** No eval 1 with_skill, a resposta cita `data-classification.json` como autoridade e nomeia os antipatterns T-02 (PAN em evento) e T-04 (hash sem chave em chave de cache) pelo id do checklist transversal do próprio artefato; without_skill chega a metade da conclusão (tira o PAN do evento) mas erra a forma (máscara em vez de token) e não identifica o antipattern de hash sem chave.

## Onde o artefato atrapalhou ou não decidiu por si

- **Eval 2 é o único onde with_skill não bate 100%** (0.6, 2 de 5 falham) — as duas falhas são a mesma causa raiz: o protocolo manda "não siga com a parte em conflito" (item 3) assim que há colisão, e o agente interpretou isso como bloquear **toda** a telemetria, inclusive o roteamento por default (Regra de desempate 6: "sem ADR vai para `data-nosql`"). O eval esperava que o roteamento ao `data-nosql` acontecesse *apesar* do conflito sobre a sugestão do usuário (a posição A do próprio bloco `CONFLITO` já recomendava MongoDB) — e a ausência de roteamento arrasta consigo a segunda falha (checklist transversal sem exigência de filtro de tenant no Mongo, porque a telemetria nunca chegou a ser desenhada). Isso é uma leitura defensável do texto como está — "não siga com a parte em conflito" é literal — mas o artefato não distingue "conflito sobre qual store usar, com um lado já recomendado pela rule" de "conflito onde não há default seguro nenhum"; o segundo caso justifica bloqueio total, o primeiro poderia registrar o `CONFLITO` sobre a sugestão do usuário e ainda assim rotear pelo default da matriz.
- **Trecho ambíguo identificado:** item 3 do Protocolo ("devolva o bloco CONFLITO... e não siga com a parte em conflito — nunca 'registre e siga'. A parte do pedido que não depende do conflito pode seguir") não esclarece se "a parte que não depende do conflito" inclui o *roteamento por default* quando o próprio bloco `CONFLITO` já aponta uma posição vencedora pela precedência (rule > pedido do usuário sem ADR). O agente tratou a pergunta inteira da telemetria como dependente do conflito; uma leitura alternativa igualmente válida trataria só a *escolha entre SQL e NoSQL* como aberta a decisão humana, mas o *roteamento ao especialista* (que é reversível — o especialista pode ser re-acionado se a decisão mudar) como não dependente.
- **Nenhum trecho do artefato foi ignorado** nos runs with_skill — os transcripts mostram leitura de `.forge/rules/data/*`, do ADR e da matriz de taxonomia nos três evals, e cada resposta cita caminho de arquivo específico para cada decisão.

## Melhorias concretas, priorizadas

1. **[Alto impacto — resolve a única falha observada]** No item 3 do Protocolo, distinguir explicitamente dois casos de conflito: (a) quando a fonte de maior autoridade já aponta um default inequívoco (ex.: regra de desempate 6, ausência de ADR → `data-nosql`), o roteamento ao especialista pelo default **segue**, e o bloco `CONFLITO` serve só para a divergência entre o default e a sugestão do usuário/pedido; (b) quando não há default seguro (nenhuma fonte resolve a colisão), a parte inteira bloqueia. Isso alinha o comportamento do agente com a intenção da Regra de desempate 6 ("O critério é o ADR, não o volume, para que a pergunta tenha um único dono") mesmo quando o usuário propõe a alternativa perdedora.
2. **[Médio impacto]** No checklist transversal (item "Multi-tenant"), explicitar que a exigência de RLS/filtro de tenant se aplica também à *pergunta delegada ao default*, não só ao que foi de fato desenhado — hoje o artefato deixa implícito que o checklist só entra quando a decisão já foi tomada, o que amplifica o efeito do problema 1 (telemetria bloqueada → checklist de tenant para ela nem aparece).
3. **[Baixo impacto, mas observado nos três runs]** A seção "Modo degradado" cobre bem o caso de a ferramenta `Agent` estar ausente, mas nenhum dos três evals with_skill exercitou a delegação real (`Agent` de fato criado com `subagent_type`, hook de allowlist de fato disparado). O comportamento correto do modo degradado é bem coberto pelo benchmark atual; a fidelidade da delegação real (formato da pergunta que o especialista recebe, hook `data-agent-allowlist.sh` bloqueando tipo indevido) não é — vale um eval específico que rode com `Agent` liberado, se o ambiente de teste permitir, para não deixar esse caminho sem cobertura.

## Notas do analyzer (per-assertion/cross-eval)

- Eval 1 e eval 3 são "fáceis" para diferenciar o artefato: with_skill bate 6/6 nos dois; without_skill cai para 1/6 e 2/6 respectivamente — sem variância entre eles (min=max dentro de cada configuração, já que é 1 run por config).
- Eval 2 é o mais difícil para o artefato mesmo com skill (0.6) e o único onde without_skill zera (0/5) — a lacuna absoluta (0.6 vs 0.0) ainda é grande, mas a margem relativa ao "teto" de 1.0 é menor que nos outros dois evals.
- As duas asserções que falham em with_skill no eval 2 têm a mesma causa raiz (não roteamento da telemetria) — não são dois defeitos independentes, e sim um efeito em cascata de uma única decisão do agente na leitura do item 3 do Protocolo.
- without_skill eval 2 falha nas 5/5 asserções por um padrão consistente: a resposta resolve tudo sozinha (desenha DDL, propõe ADR novo, decide TimescaleDB por volume) em vez de citar o ADR-0004 existente ou escalar a divergência via bloco `CONFLITO` — sem o artefato, não há disciplina de citar fonte de autoridade nem de bloquear para HITL.
- Sem dados de tokens/tool_calls no benchmark.json (ambos zerados nas três configurações) — o eval harness não capturou essas métricas nesta rodada; só `time_seconds` tem sinal real.
