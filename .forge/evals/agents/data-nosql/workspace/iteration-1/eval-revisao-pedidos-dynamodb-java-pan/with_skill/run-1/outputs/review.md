# Revisão — services/pedidos (Java 21, AWS SDK v2, DynamoDB)

Resposta do especialista `data-nosql` à pergunta do usuário. Não escrevo na árvore (uma árvore, um escritor) — quem aplica é o agente de engenharia ou o `task-coder`.

## Sobre o gate de governança de dados não ter reclamado

O gate **não verificou nada** — não é aprovação, é ausência de verificação. Rodei `check-data-governance.sh --path services/pedidos` e o resultado foi `FAIL data-governance/universo-vazio — 0 arquivo(s) examinado(s)`. Esse verificador só lê `.go`, `.kt`, `.ts`, `.rego`, `.py` e `.md`; `services/pedidos` é Java, então o universo dele aqui é vazio por desenho, não porque o código esteja limpo. A resposta sobre PAN vem da leitura manual do código contra `data-classification.json` (que trato como autoridade sobre quais campos são PAN/PII, protocolo passo 3), não do gate.

## CONFLITO — persistência do transacional de negócio sem ADR

```text
CONFLITO
decisão: store do transacional de negócio "pedido" (H-01 (a))
posição A: DynamoDB (implementação atual em infra/dynamo.tf) — fonte: código do projeto, sem ADR que a justifique
posição B: MongoDB com transação multi-documento, write concern majority, P-S-S — salvo ADR que escolha SQL — fonte: rules/data/data-governance.md (H-01 a, decisão do dono 2026-09-26) e rules/data/data-transactional-nosql.md
precedência: rule vence contexto/skill na ordem do FORGE.md §2.1 (constitution > baseline/ADRs > rules > contexto); não há ADR do projeto que escolha SQL nem que justifique DynamoDB — .forge/product/current/adr/ está vazio (só .gitkeep)
opções: aplicar a fonte de maior autoridade (recomendado: migrar para MongoDB, ou abrir ADR justificando DynamoDB para este domínio) | abrir ou atualizar ADR | bloquear
registro: a decisão humana vai para approvals.yaml do change em curso, ou para ADR — quem registra é a sessão principal ou o pipeline /forge:* em curso; este agente não registra
```

Não recomendo a favor de manter DynamoDB como está — isso é a parte em conflito. Dito isso, a pergunta concreta do usuário (chave, índices, PAN) vale para qualquer store escolhido, e os achados abaixo valem tanto para hoje quanto para uma eventual migração.

## Achado crítico — PAN em claro na tabela e no índice

`data-classification.json` classifica `numeroCartao` como `pan`, com `masking: "primeiros 6 e últimos 4"` e `tokenization_boundary: true` — ou seja, o próprio projeto já declara que a fronteira de tokenização deveria estar em algum ponto antes deste serviço reter o valor.

O código não respeita essa classificação:

- `Pedido.java:3` carrega `numeroCartao` como `String` inteira dentro do agregado de domínio.
- `PedidoRepository.java` (`salvar`) grava `AttributeValue.fromS(p.numeroCartao())` — o PAN completo, em claro, como atributo de string do item. Nada de mascaramento nem tokenização antes da escrita.
- `dynamo.tf:16-22` — o GSI `por-cliente` tem `projection_type = "ALL"` (achado N-10 do scanner), o que **duplica o item inteiro, PAN incluído, dentro do índice**: uma segunda cópia em claro do dado mais sensível da tabela, sujeita a um padrão de acesso e permissionamento diferente do da tabela base.

Criptografia at-rest do DynamoDB (SSE) não resolve isso: protege contra acesso ao disco/backup, não contra quem tem `dynamodb:GetItem`/`Query`/`Scan` na tabela ou no índice — é exatamente o requisito de mascaramento/tokenização que a `data-classification.json` já registra e que não está implementado. Recomendação: tokenizar `numeroCartao` na borda de ingestão (antes de chegar a `Pedido`), manter no agregado só o token e, quando exibição for necessária, o valor mascarado (`primeiros 6 e últimos 4`, conforme a própria classificação); o PAN completo deve viver só no provedor/vault PCI, nunca em `services/pedidos`. E excluir explicitamente esse campo da projeção do GSI (`INCLUDE`, nunca `ALL`).

## Achados de modelagem (DynamoDB)

Varredura (`scan.sh --root services/pedidos`, sem `--json`):

```
FOUND N-06 [aviso] services/pedidos/infra/dynamo.tf:4: hash_key = "status"
FOUND N-08 [aviso] services/pedidos/src/main/java/.../PedidoRepository.java:9,45 (import ScanRequest; dynamo.scan(...))
FOUND N-10 [aviso] services/pedidos/infra/dynamo.tf:24: projection_type = "ALL"
```

### N-06 — chave de partição de baixa cardinalidade — bloqueante dado o pico informado
`hash_key = "status"` na tabela principal. `status` tem um punhado de valores (pendente, pago, enviado, cancelado...). No pico de Black Friday informado (~8 mil pedidos/segundo), toda escrita se concentra fisicamente em poucas partition keys — e o limite de throughput por partição física do DynamoDB (≈1000 WCU / 3000 RCU) é por partição, **independente do modo de billing** (`PAY_PER_REQUEST` não contorna isso). Com 8 mil pedidos/s distribuídos por poucos valores de `status`, o throttling é praticamente garantido mesmo sobrando capacidade agregada na tabela — é o sintoma que o próprio catálogo descreve (N-06: "throttling com a capacidade total sobrando"). É o achado de maior prioridade dado o volume citado pelo usuário.
Correção: chave de alta cardinalidade alinhada ao padrão de acesso dominante (ex.: `pedidoId` como hash key da tabela, ou `clienteId`); se a listagem por `status` for necessária, mover para um índice dedicado (idealmente esparso, ver N-08 abaixo) em vez de campo de baixa cardinalidade como chave primária. Mudar a chave é migração com cópia para tabela nova — não é ajuste in-place.
Evidência: [J] antipattern documentado (base da skill); análise de capacidade por partição: [1F] limites documentados do DynamoDB.

### N-08 — Scan no caminho da requisição
`pendentes()` (`PedidoRepository.java:45`) roda `Scan` com `filterExpression` a cada 5 segundos, chamado pelo painel de operação. `Scan` lê a tabela inteira (paginada a 1 MB) e consome capacidade de todas as partições, mesmo filtrando por `status = PENDENTE` só depois de ler tudo. Não é o caminho de maior volume (5 em 5 segundos, não 8 mil/s), mas sem TTL/arquivamento visível no schema a tabela só cresce, e cada Scan concorre pela mesma capacidade de partição que as escritas do pico — exatamente na janela em que N-06 já deixa a tabela mais sensível a throttling.
Correção: GSI esparso por `status` (atributo presente só quando `PENDENTE`, ausente nos demais estados — assim o índice fica pequeno e a leitura vira `Query`, não `Scan`); ou fila/stream de eventos de mudança de status para o painel, em vez de poll.
Evidência: [1F] DynamoDB (Scan consome capacidade de todas as partições).

### N-10 — GSI com projeção ALL
Já coberto acima (junto do achado de PAN). Além de duplicar o PAN, dobra o custo de escrita (toda escrita na tabela replica o item inteiro no índice). Correção: projeção `KEYS_ONLY` ou `INCLUDE` com só os atributos que o padrão de acesso "últimos 20 pedidos do cliente" realmente usa.
Evidência: [1F] DynamoDB.

### N-11 (achado manual — não pego pelo scanner) — leitura forte pedida num GSI
`ultimosDoCliente()` monta a `QueryRequest` com `.indexName("por-cliente")` **e** `.consistentRead(true)` no mesmo builder (`PedidoRepository.java`, linhas do método `ultimosDoCliente`). GSI só entrega leitura eventual — a API do DynamoDB **rejeita** `ConsistentRead: true` combinado com `IndexName`, com `ValidationException` em runtime. O detector estático do scanner é heurístico e exige as duas chaves na mesma linha de texto (documentado no próprio `SKILL.md`: "objeto em várias linhas escapa") — aqui o builder está em várias linhas, por isso o scanner reportou `OK`. Mas é leitura obrigatória (protocolo passo 5: todo `FOUND`/candidato exige leitura do arquivo, e aqui a ausência de `FOUND` não dispensa a leitura do trecho).
Isto não é só um antipattern de custo: é o endpoint chamado a cada abertura do app (`GET /pedidos?clienteId=...`) e, do jeito que está, **essa chamada nunca funciona** — não é degradação sob carga, é erro de validação da API em toda invocação.
Correção: remover `.consistentRead(true)` da query no GSI (aceitar eventual, que é o padrão aceitável para "últimos 20 pedidos" numa tela de app) ou, se leitura forte for requisito de produto, fazer `Query`/`GetItem` na tabela base em vez do índice.
Evidência: [2F] comportamento documentado da API DynamoDB; detector [Heurística] (limitação documentada no SKILL.md da skill).

## Checklist (protocolo)

- Padrões de acesso inventariados antes da chave: sim — "últimos 20 pedidos do cliente" (alto volume, leitura por cliente) e "pendentes a cada 5s" (painel) são os dois padrões dominantes; nenhum dos dois é `status` como chave primária, que é justamente o que a tabela usa hoje (raiz do N-06).
- Chave de alta cardinalidade alinhada ao predicado dominante: **não** — ver N-06.
- Consistência por operação: GSI só eventual — violado em `ultimosDoCliente()` (N-11).
- Teto de crescimento no agregado: não há TTL/arquivamento visível; alimenta o custo crescente do Scan (N-08).
- Multi-tenant: fora de escopo aqui — `data-transactional-nosql.md` é regra para MongoDB; não achei campo de tenant no domínio pedidos (aparenta ser single-tenant), não tratei como violação.
- Dinheiro em inteiro na menor unidade: `valorCentavos` é `long` em centavos — conforme `money-as-cents.md`, sem achado.
- PCI/LGPD — PAN nunca em claro: **violado** — ver achado crítico acima.
- Custo: RU/WCU pela unidade dominante — Scan (N-08) e GSI projeção ALL (N-10) são exatamente os dois itens que explodem fatura, citados também no `data-nosql.md`.

## Resumo para quem decide

1. Abrir/decidir o CONFLITO de store (DynamoDB sem ADR para um domínio que a rule da casa manda em MongoDB, salvo ADR SQL) — decisão humana, registrada em ADR ou approvals.yaml, não deste agente.
2. Tratar como bloqueante, independente da decisão acima: PAN completo em claro na tabela e replicado no GSI — tokenizar/mascarar antes de persistir, conforme a própria `data-classification.json` do projeto já exige.
3. Corrigir `ultimosDoCliente()` — a combinação `IndexName` + `ConsistentRead: true` quebra o endpoint mais usado do app (abertura do app) em toda chamada.
4. Redesenhar a chave de partição da tabela principal antes da Black Friday — `status` como hash key não sustenta 8 mil pedidos/segundo (limite de partição física do DynamoDB), independente do modo de capacidade.
5. Trocar `Scan` do painel de pendentes por `Query` num GSI esparso, e a projeção `ALL` do GSI `por-cliente` por `INCLUDE` sem `numeroCartao`.

Nenhum arquivo de `services/pedidos` foi alterado, conforme pedido.
