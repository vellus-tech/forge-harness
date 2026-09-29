# Análise do benchmark — skill `data-streaming-practices`

Agregação determinística via `scripts.aggregate_benchmark` sobre `workspace/iteration-1` (3 evals × 1 run por configuração; `benchmark.json` e `benchmark.md` gerados no próprio diretório de iteração, dentro da árvore permitida). Não foi necessário corrigir estrutura de diretórios/JSON — a agregação passou na primeira tentativa.

## Resultado

- **Com skill**: pass rate médio 87,8% (min 80%, max 100%; eval 3 = 100%, eval 2 = 80%, eval 1 = 83,3%).
- **Sem skill**: pass rate médio 38,9% (min 16,7%, max 60%; eval 3 = 40%, eval 2 = 60%, eval 1 = 16,7%).
- **Delta**: +0,49 (com − sem). Tempo: com skill +46,7s em média (173,0s vs 126,3s) — custo de leitura do protocolo e das referências, não um outlier isolado.
- `benchmark_ok = true`.

O delta é dominado pelo eval 1 (revisão de mensageria RabbitMQ pré-upgrade): 83,3% com skill contra 16,7% sem skill, a maior distância das três. Os evals 2 (retry em fila ordenada) e 3 (pedido do parceiro adquirente) têm distância menor (0,20 e 0,60 respectivamente).

## Asserções não discriminantes

Não há, nas três evals, asserção que passe 100% em ambas as configurações "de graça". As mais próximas de não discriminar:

- Eval 3, asserção 3 (PAN em claro não aparece no AsyncAPI final) — passou nas duas configurações, nos dois casos por decisão explícita de rejeitar o campo, não por omissão. Não diferencia a skill, mas também não é ruído: mostra que a proibição de PAN em claro é intuitiva mesmo sem o catálogo.
- Eval 3, asserção 1 (ausência de manifesto k8s expondo gRPC) — passou nas duas configurações no estado final do `work/`, mas por razões distintas: com skill foi abstenção deliberada e documentada; sem skill o agente chegou à mesma superfície final por acaso (a proposta do adaptador aponta para outro backend, não para o `payment-service`/50051). O próprio grading registra essa diferença de mérito na evidência da asserção 2, que reprovou o `without_skill` "por coincidência, não por decisão".

## Onde o artefato ajudou

1. **Vocabulário auditável do catálogo (ids + linha).** No eval 1, a skill levou a citar os cinco ids RMQ-AP com `arquivo:linha` exatos; sem skill, zero ids de catálogo aparecem no relatório, mesmo descrevendo os mesmos sintomas em prosa. Isso sozinho decide duas das seis asserções do eval 1.
2. **Causa raiz correta do incidente 1.** Com skill, o diagnóstico aponta `publish` sem `confirms`/`persistent` como causa mais provável de a recarga sumir após reinício de nó (RMQ-AP-08/12). Sem skill, o agente atribuiu a mesma perda ao guarda de `redelivered` no consumidor — plausível, mas não é o que a asserção de referência cobra, e a asserção específica de nack/delivery-limit falhou também sem skill.
3. **Recusa e HITL bem formados (eval 3).** Com skill, a resposta final recusa implementar os três pedidos do parceiro citando pelo menos dois ids (D-AP-01/02, RMQ-AP-27, T-02) e propõe alternativa completa (adaptador REST + broker de borda dedicado + shovel/federation, conciliação por token). Sem skill, o agente também recusa e também propõe adaptador REST, mas não cita nenhum id do catálogo, não pede decisão explícita ao usuário (entrega como proposta pronta "a levar ao parceiro") e não propõe broker de borda dedicado nem shovel/federation — mantém o usuário do parceiro no cluster interno e concilia por PAN truncado em vez de token/transaction_id.
4. **Localização correta de DLX/policy vs. arguments (eval 2).** Com skill, DLX e overflow foram postos na `policy` (onde vale também para filas futuras do mesmo padrão); sem skill, a DLX foi posta em `arguments` da fila individual — funcionalmente parecido, mas reprova a asserção que verifica especificamente a definition da policy.
5. **Reconhecimento do que o scanner não cobre.** Nas três evals com skill, o transcript registra explicitamente quais achados são de scanner (`scan.sh`) e quais são de leitura manual/revisão de runtime, sem dar como aprovado o que não foi verificado — comportamento pedido pela seção "O que o scanner não faz" do próprio SKILL.md e cobrado por uma asserção do eval 1.

## Onde o artefato atrapalhou ou não ajudou

- **Nenhum caso de "atrapalhou"**: não há asserção em que `with_skill` reprove e `without_skill` passe.
- **Onde não ajudou o suficiente**: a explicação da fórmula do retry nativo do 4.3 (`min(delayed-retry-min × delivery-count, delayed-retry-max)`, linear, sem jitter) falhou em ambas as configurações no eval 2 — com skill, o design menciona "linear e sem jitter" de passagem, mas não apresenta a fórmula nem conecta explicitamente à incompatibilidade com os patamares 5s/30s/5min pedidos. Sugere que a referência da skill trata a mecânica do retry nativo do 4.3 em nível insuficiente de detalhe operacional para ser reproduzida no relatório, mesmo quando lida.
- No eval 1, mesmo com skill, a recomendação de "desabilitar/remover" o plugin delayed exchange ficou condicional ("manter habilitado só se algo mais o usa hoje") em vez de categórica — falhou a asserção mais estrita, embora tenha identificado corretamente o plugin como depreciado/arquivado e proposto a alternativa certa.

## Trechos ignorados, ambíguos ou contraditórios

- **SKILL.md não resolve a mecânica completa do retry nativo do 4.3.** A referência (`best-practices.md`) aparentemente registra a existência e as chaves (`delayed-retry-type/min/max`), mas não a fórmula de cálculo do atraso nem o comportamento linear-com-teto-sem-jitter de forma explícita o bastante para duas execuções distintas (eval 1 e eval 2, ambas com skill) reproduzirem esse detalhe no relatório final. Sintoma consistente, não isolado — mesma lacuna em duas evals diferentes.
- **"Desabilitar/remover" vs. "não adotar" o plugin delayed exchange.** O protocolo diz para nunca recomendar o que a seção "Refutado" da base derrubou, mas não deixa explícito que a recomendação correta é a remoção ativa do plugin (não apenas a não-adoção para o caso em mãos). A execução com skill no eval 1 tratou isso como recomendação condicional, o que a asserção de referência trata como insuficiente.
- **Sem contradição entre SKILL.md e as evals** — os ids e a ordem do protocolo (Escopo → Rules do projeto → Detecção → Julgamento → Relatório) foram seguidos de forma consistente nas três execuções `with_skill`, sem desvio.
- **Achado de dedupe em memória (`Set` em português, `processados`) não é pego pelo scanner** porque os padrões de detecção são específicos de nomes em inglês (`processedIds`/`seenMessages`); o próprio transcript com skill registra isso como gap do detector e compensa com revisão manual — ponto cego real do `scan.sh`, não só da skill.

## Melhorias concretas priorizadas

1. **(Alto impacto) Detalhar a fórmula do retry nativo do 4.3 em `references/best-practices.md`.** Adicionar explicitamente `atraso = min(delayed-retry-min × delivery-count, delayed-retry-max)`, marcado como linear com teto e sem jitter, com nota de que não reproduz patamares exponenciais custom (ex.: 5s/30s/5min) sem ajuste. Impacto esperado: teria virado a asserção que falhou em ambas as configurações no eval 2 (0,8→1,0 nesse run) e provavelmente teria evitado a resposta condicional no eval 1.
2. **(Alto impacto) Tornar categórica a recomendação sobre o plugin delayed exchange depreciado.** No catálogo (`antipatterns.md`, RMQ-AP-17) ou em `best-practices.md`, adicionar frase explícita: "recomendar desabilitar/remover o plugin, não apenas evitar seu uso no caso em análise, mesmo que outros consumidores o usem hoje — abrir ADR/plano de migração para esses usos, mas não deixar o plugin habilitado por padrão". Remove a ambiguidade que levou à resposta condicional observada.
3. **(Médio impacto) Explicitar que DLX/overflow de fila quorum devem ir na `policy`, não em `arguments` da fila individual, quando o padrão é reutilizável.** Uma linha no protocolo ou em `RMQ-BP` cobrindo esse ponto teria dado ao caso sem skill (que já chegou à decisão certa de adicionar DLX) uma chance real de acertar a localização. Como está, a skill já orienta isso implicitamente (o resultado com skill acerta em 100% dos casos observados), mas vale registrar de forma mais explícita para reforçar consistência entre execuções.
4. **(Médio impacto) Adicionar padrões de nome em português ao `scan.sh` para dedupe em memória.** `processados`, `vistos`, `ids_processados` como sinônimos de `processedIds`/`seenMessages` — fecha um ponto cego real do detector que hoje depende inteiramente de revisão manual (e, sem skill, provavelmente nem seria identificado).
5. **(Baixo impacto) Reforçar no protocolo (`## Relatório`) a exigência de "decisão pendente (HITL) com ids citados" como formato de saída padrão** ao lidar com pedido de terceiro que viole a regra do dono — o comportamento já ocorreu corretamente nas execuções com skill observadas (100% de acerto na asserção de recusa formal), mas explicitar o formato no protocolo reduziria variância entre modelos/execuções futuras.

## Asserções candidatas a remoção por não discriminar

Nenhuma das três evals tem asserção candidata a remoção — mesmo as duas que passaram em ambas as configurações (PAN em claro, ausência de manifesto k8s) carregam evidência de mérito distinto entre `with_skill` e `without_skill` no grading, então valem manter como estão.
