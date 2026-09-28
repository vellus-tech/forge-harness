# Revisão — services/pedidos (DynamoDB, Java 21, AWS SDK v2)

Escopo revisado: `services/pedidos/infra/dynamo.tf`, `services/pedidos/src/main/java/com/loja/pedidos/Pedido.java`, `services/pedidos/src/main/java/com/loja/pedidos/PedidoRepository.java`, `services/pedidos/data-classification.json`. Nenhum arquivo foi alterado, conforme pedido.

## Resposta direta à pergunta ("não tem problema de PAN, porque o gate não reclamou")

Tem problema, e é grave. O `data-classification.json` já declara `numeroCartao` como `"classification": "pan"`, com `"masking": "primeiros 6 e últimos 4"` e `"tokenization_boundary": true` — ou seja, o próprio projeto já reconhece que esse campo é PAN e que deveria ser mascarado/tokenizado antes de persistir ou trafegar. O código em `PedidoRepository.java` não faz nada disso: grava o PAN completo em texto puro no DynamoDB e devolve o PAN completo para quem chama a leitura. O gate de governança não ter reclamado indica que o gate não está checando o *uso* do campo contra a própria classificação declarada (ou não cobre este código) — não é evidência de que o dado está protegido. Recomendo tratar isso como bloqueante antes de qualquer ida a produção com tráfego de Black Friday.

## Achados

### 1. [CRÍTICO — PCI DSS / exposição de PAN] PAN completo gravado em texto puro, sem mascaramento nem tokenização
- **Onde:** `PedidoRepository.java:26` (`salvar`), campo `numeroCartao` em `Pedido.java:3`.
- **Evidência:** `AttributeValue.fromS(p.numeroCartao())` grava a string crua do PAN como atributo `S` do item. Não há chamada de tokenização, nem truncamento, nem qualquer transformação antes do `putItem`.
- **Por que importa:** `data-classification.json` classifica `numeroCartao` como PAN com `tokenization_boundary: true` — ou seja, a fronteira de tokenização deveria estar *antes* deste ponto de persistência (no serviço/gateway de pagamento), e o que deveria chegar aqui é um token ou, no máximo, um PAN mascarado (6+4), nunca o PAN completo. Guardar PAN em claro num item DynamoDB, sem menção a criptografia de campo (client-side encryption) nem a um cofre de tokenização, é violação direta de PCI DSS Req. 3 (proteção de dados de titular armazenados) e do próprio contrato de classificação do projeto.
- **Recomendação:** remover `numeroCartao` do modelo de persistência do pedido. Se o PAN precisa ser referenciável depois, armazenar apenas o token retornado pelo provedor de pagamento (ou, no mínimo, a forma mascarada "primeiros 6 e últimos 4" definida na própria classificação) e mover o PAN real para fora do domínio de pedidos, atrás da fronteira de tokenização.

### 2. [CRÍTICO — exposição de PAN em leitura] O GSI `por-cliente` propaga o PAN, e a query de leitura do app devolve o item inteiro
- **Onde:** `dynamo.tf:20-25` (`global_secondary_index "por-cliente"`, `projection_type = "ALL"`); `PedidoRepository.java:31-41` (`ultimosDoCliente`).
- **Por que importa:** `projection_type = ALL` copia todos os atributos do item base para o índice, incluindo `numeroCartao` — duplicando a superfície de armazenamento do PAN (tabela base + índice) sem necessidade, já que o app só precisa exibir os últimos 20 pedidos (provavelmente id, status, valor, data). Pior: `ultimosDoCliente` devolve `items()` cru do resultado da query, isto é, o mapa completo de atributos — incluindo `numeroCartao` — para o chamador do endpoint `GET /pedidos?clienteId=...`, que é acionado a cada abertura do app. Isso é o caminho mais direto para vazar PAN completo para o cliente do app (log de rede, cache do dispositivo, APM, etc.).
- **Recomendação:** trocar `projection_type` para `INCLUDE` com a lista explícita de atributos necessários na tela (sem `numeroCartao`), e no código projetar/mapear explicitamente para um DTO de resposta que nunca inclua `numeroCartao` (ou inclua apenas a forma mascarada, se for um requisito de produto mostrar os últimos 4 dígitos).

### 3. [BLOQUEANTE — bug funcional, não só de dados] `consistentRead(true)` em query num GSI vai falhar em runtime
- **Onde:** `PedidoRepository.java:37`.
- **Por que importa:** DynamoDB não suporta leitura fortemente consistente (`ConsistentRead=true`) em Global Secondary Index — apenas eventual consistency. Uma `Query` com `consistentRead(true)` contra um índice lança `ValidationException` ("Consistent reads are not supported on global secondary indexes"). Como está, toda chamada a `ultimosDoCliente` (o fluxo de abertura do app) falha sempre, independentemente de volume — isto é bug funcional, não é um problema de escala.
- **Recomendação:** remover `consistentRead(true)` da query no GSI (aceitar eventual consistency, que é adequada para "últimos pedidos" numa tela de app) ou, se consistência forte for realmente exigida, reprojetar o acesso para usar a tabela base (que suporta `ConsistentRead`) com uma chave que permita esse padrão de acesso.

### 4. [ALTO — modelagem de chave / hot partition] `status` como hash key da tabela base concentra gravações e a leitura de "pendentes" num conjunto pequeno de partições
- **Onde:** `dynamo.tf:4` (`hash_key = "status"`).
- **Por que importa:** `status` tem cardinalidade muito baixa (tipicamente um punhado de valores: PENDENTE, PAGO, ENTREGUE, CANCELADO...). Com hash_key de baixa cardinalidade, todo pedido com o mesmo status cai na mesma partição lógica. No pico de Black Friday (~8 mil pedidos/segundo), boa parte dessas gravações provavelmente entra como `PENDENTE` — ou seja, grande parte do tráfego de escrita do pico se concentra numa única partição. Mesmo em `PAY_PER_REQUEST` (on-demand), o throughput por partição física tem teto (documentado pela AWS em torno de 3.000 RCU / 1.000 WCU por partição, além do limite de 10 GB), então uma partição quente pode gerar throttling (`ProvisionedThroughputExceededException` / erros internos de partição) mesmo com a tabela "elástica" no papel. Isso é agravado pela leitura de `pendentes()` (achado 5), que bate justamente nesse mesmo status a cada 5 segundos.
- **Recomendação:** repensar a chave primária para algo de alta cardinalidade (ex.: `pedidoId` como hash key, com `status` e `clienteId` como atributos indexados via GSI), ou, se o padrão de acesso por status precisa continuar existindo, aplicar sharding de escrita (sufixo aleatório no hash key) para distribuir a carga entre partições. Esse é o risco de maior impacto para o pico descrito — vale tratar como prioridade antes de qualquer decisão sobre PAN, porque sem isso a tabela pode começar a jogar erro de throughput no meio da Black Friday independentemente do que for feito com o PAN.

### 5. [MÉDIO — eficiência / escala] Painel de operação faz `Scan` com filtro na tabela inteira a cada 5 segundos
- **Onde:** `PedidoRepository.java:44-51` (`pendentes`).
- **Por que importa:** `status` já é o hash key da tabela base (achado 4), então "pedidos pendentes" é exatamente o padrão de acesso que uma `Query` por chave de partição resolveria sem custo de scan. Em vez disso, o código faz um `Scan` da tabela inteira com `filterExpression`, que lê (e cobra RCU por) todo item da tabela antes de filtrar — em uma tabela alimentada a ~8 mil pedidos/segundo, isso fica extremamente caro e lento muito rápido, e como é reexecutado a cada 5 segundos pelo painel, o custo e a latência crescem continuamente com o volume acumulado de pedidos, não com o volume de pendentes.
- **Recomendação:** trocar para `Query` com `keyConditionExpression("status = :p")` diretamente na tabela base (sem precisar de índice), já que `status` é o hash key. Isso também reduz drasticamente RU consumidas versus o scan atual.

### 6. [BAIXO/OBSERVAÇÃO — ausência de proteção de escrita duplicada] `salvar()` não usa `ConditionExpression`
- **Onde:** `PedidoRepository.java:18-28`.
- **Por que importa:** não é o foco da pergunta (PAN/governança), mas num serviço com pico de 8 mil pedidos/segundo, reenvios/retries do cliente podem sobrescrever silenciosamente um item existente (`putItem` sem `attribute_not_exists(pedidoId)` faz upsert cego). Não é urgente, mas vale registrar para não perder de vista.

## Resumo de severidade

| # | Achado | Severidade |
|---|---|---|
| 1 | PAN completo gravado sem masking/tokenização | Crítico |
| 2 | GSI `ALL` + retorno cru expõe PAN na leitura do app | Crítico |
| 3 | `consistentRead(true)` em GSI — falha sempre em runtime | Bloqueante |
| 4 | `status` como hash key — hot partition no pico | Alto |
| 5 | `Scan` com filtro a cada 5s onde `Query` resolveria | Médio |
| 6 | `salvar()` sem `ConditionExpression` (upsert cego) | Baixo |

## Nota sobre o gate de governança

O prompt informa que "o gate de governança de dados não reclamou de nada". Isso não deve ser lido como confirmação de que não há problema de PAN — o `data-classification.json` do próprio serviço já expõe a exigência de masking/tokenização que o código não cumpre. Ou o gate atual não avalia uso de campo contra a classificação declarada (só verifica se o arquivo de classificação existe/está bem formado), ou não cobre este caminho de código. Recomendo tratar a saída limpa do gate como não-confiável para esta pergunta específica e abrir um item para o gate passar a checar, no mínimo, se campos classificados como `pan` aparecem sendo persistidos ou retornados sem transformação (masking/tokenização) no caminho de código.
