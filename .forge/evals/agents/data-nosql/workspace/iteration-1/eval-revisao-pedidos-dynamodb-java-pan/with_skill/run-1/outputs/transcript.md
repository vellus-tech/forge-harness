# Transcript — eval-revisao-pedidos-dynamodb-java-pan / with_skill / run-1

Papel: `data-nosql` (agente consultivo, sem Write/Edit/Agent — devolve recomendação na resposta).

## 1. Bootstrap e preparação

- `date +%s > .t0` — instante inicial registrado.
- `mkdir -p work outputs`.
- `bash .forge/evals/agents/data-nosql/fixtures/revisao-pedidos-dynamodb-java-pan/setup.sh work` — populou `work/` com `.forge/` (rules, scripts, adapters, product) e `work/services/pedidos/` (Java 21 + AWS SDK v2 + Terraform).

## 2. Leitura do agente e do artefato do harness

- Li `template/.forge/agents/data/data-nosql.md` (definição do agente que sigo à risca): escopo (transacional de negócio da casa = MongoDB, salvo ADR SQL), protocolo de 6 passos fixos (rules → conflito → dado sensível → varredura → julgamento → resposta), bloco `CONFLITO`, checklist e antipatterns bloqueados.
- Li `template/.forge/skills/data-nosql-practices/SKILL.md` (a skill que o agente carrega): protocolo equivalente, aviso explícito de que o scanner "lê texto" e que write skew/idempotência/filtro de tenant não têm detector confiável — revisão manual obrigatória.
- Li `template/.forge/skills/data-nosql-practices/references/antipatterns.md`, seções N-06, N-07, N-08, N-10, N-11, N-13 (as relevantes para DynamoDB/Cassandra) — sintoma, correção, detecção e evidência de cada id.
- Esses arquivos ficam em `template/.forge/` (fonte read-only do harness) porque `work/.forge/skills/` veio vazio da fixture — o protocolo permite ler a definição do agente e o que ele referencia ali.

## 3. Inventário do código sob revisão

Li os quatro arquivos de `work/services/pedidos/`:

- `data-classification.json` — `numeroCartao` classificado como `pan` (masking "primeiros 6 e últimos 4", `tokenization_boundary: true`); `clienteId` como `public`. Tratado como autoridade sobre PAN/PII (protocolo passo 3).
- `infra/dynamo.tf` — tabela `pedidos`, `PAY_PER_REQUEST`, `hash_key = "status"`, `range_key = "pedidoId"`, GSI `por-cliente` (`hash_key = clienteId`, `range_key = pedidoId`, `projection_type = "ALL"`).
- `src/.../Pedido.java` — `record Pedido(id, clienteId, status, valorCentavos, numeroCartao)`.
- `src/.../PedidoRepository.java` — `salvar()` grava `numeroCartao` como `AttributeValue.fromS(...)` (string em claro); `ultimosDoCliente()` faz `Query` no GSI `por-cliente` com `.consistentRead(true)` + `.limit(20)` + `.scanIndexForward(false)` (comentário: chamado a cada abertura do app); `pendentes()` faz `Scan` com `filterExpression` sobre `status` (comentário: painel de operação a cada 5s).

## 4. Rules e decisões do projeto (protocolo passo 1)

- `work/.forge/rules/data/data-governance.md` — H-01(a): transacional de negócio (inclui "pedido") é MongoDB com transação multi-documento, `write concern majority`, P-S-S, salvo ADR do projeto que escolha SQL.
- `work/.forge/rules/data/data-transactional-nosql.md` — regra derivada, específica de MongoDB (isolamento multi-tenant, write concern, idempotência) — não se aplica diretamente a uma tabela DynamoDB, mas confirma que o dono da decisão de store para "pedido" é essa rule.
- `work/.forge/rules/domain/money-as-cents.md` (citado, não integralmente reproduzido aqui) — `valorCentavos` como `long` já está conforme.
- `work/.forge/product/current/adr/` — só contém `.gitkeep`: **nenhum ADR no projeto**, logo nenhum ADR escolhendo SQL nem justificando DynamoDB para o domínio pedidos.

## 5. Conflito relevante (protocolo passo 2)

Decisão relevante por `conflict-handling.md` (estratégia de persistência): o serviço usa DynamoDB para um domínio que a rule da casa atribui a MongoDB (salvo ADR SQL), e não há ADR. Registrei bloco `CONFLITO` em `outputs/review.md`, sem recomendar a favor de manter DynamoDB como está (essa é a parte em conflito) — mas segui com a revisão técnica pedida (chave, índices, PAN), que vale independente de qual store for a decisão final.

## 6. Dado sensível (protocolo passo 3)

Comando executado (via Bash — um dos dois únicos comandos que o hook do agente permite):

```
$ cd work && bash .forge/scripts/check-data-governance.sh --path services/pedidos
FAIL data-governance/universo-vazio — 0 arquivo(s) examinado(s) (services/pedidos): o gate não examinou nada.
      Universo vazio não é ausência de violação, é ausência de verificação [...]
EXIT=1
```

Interpretação pela linha, não só pelo exit code (o agente exige isso): é `FAIL .../universo-vazio`, ou seja "não verificado por escopo" — o verificador só lê `.go/.kt/.ts/.rego/.py/.md`, e `services/pedidos` é Java. Não é aprovação nem conflito; fica com o detector da skill e a revisão manual, exatamente como o protocolo prevê. Isso responde diretamente à afirmação do usuário de que "o gate não reclamou de nada" — o gate não viu o código, não é que o código passou.

Sem o gate para PAN, fui à leitura manual: `data-classification.json` marca `numeroCartao` como PAN com mascaramento definido e `tokenization_boundary: true`; `Pedido.java` e `PedidoRepository.salvar()` levam o valor completo, sem mascarar nem tokenizar, até virar `AttributeValue.fromS` gravado no item — e o GSI com `projection_type = "ALL"` replica esse valor em claro para dentro do índice. Registrado como achado crítico em `outputs/review.md`.

## 7. Varredura (protocolo passo 4)

Comando executado (o segundo dos dois comandos permitidos pelo hook):

```
$ cd work && bash "<template>/.forge/skills/data-nosql-practices/scripts/scan.sh" --root services/pedidos
INFO data-nosql-practices motor=rg raizes=1 universo=codigo iac cql cypher
FOUND N-06 [aviso] services/pedidos/infra/dynamo.tf:4: hash_key = "status"
FOUND N-08 [aviso] services/pedidos/src/.../PedidoRepository.java:9,45 (ScanRequest / dynamo.scan)
FOUND N-10 [aviso] services/pedidos/infra/dynamo.tf:24: projection_type = "ALL"
(demais ids: OK/nenhuma ocorrência)
ARQUIVOS-VARRIDOS 4
EXIT=0
```

Usei o script `template/.forge/skills/.../scan.sh` (a instalação da fixture não trouxe cópia própria em `work/.forge/skills/`) contra o alvo em `work/services/pedidos`, exatamente como o passo 4 do protocolo manda: um `--root` por path afetado, sem `--json`.

## 8. Julgamento (protocolo passo 5)

Cada `FOUND` foi lido no arquivo e decidido contra `antipatterns.md`, não aceito no valor de face:

- **N-06** (hash_key=status): confirmado achado — cruzei com o volume dado pelo usuário (8 mil pedidos/s no pico) contra o limite de throughput por partição física do DynamoDB (documentado, independente de `PAY_PER_REQUEST`); é o achado de maior prioridade.
- **N-08** (Scan em `pendentes()`): confirmado achado, mas contextualizado — é chamado a cada 5s (não a 8 mil/s), então o risco é custo/latência crescente com o tamanho da tabela, não o caminho de pico diretamente; ainda assim compete pela mesma capacidade de partição que as escritas.
- **N-10** (projeção ALL no GSI): confirmado achado, e cruzado com o achado de PAN — a duplicação do item inteiro no índice inclui o `numeroCartao` em claro.
- **N-11** (GSI + ConsistentRead): o scanner reportou `OK`, mas o protocolo (e o `SKILL.md`) avisam que esse detector é heurístico e escapa quando a chamada está em várias linhas — exatamente o caso do builder em `ultimosDoCliente()`. Fui ler o método manualmente e encontrei `.indexName("por-cliente")` + `.consistentRead(true)` no mesmo `QueryRequest`: essa combinação é rejeitada pela API do DynamoDB em runtime (`ValidationException`), então não é só um antipattern de custo — é o endpoint de abertura do app quebrado. Registrado como achado manual, com a evidência da limitação do detector citada.

## 9. Resposta (protocolo passo 6)

Escrevi `outputs/review.md` com: correção direta sobre o gate de governança (não verificou, não aprovou), bloco `CONFLITO` sobre a escolha de store sem ADR, achado crítico de PAN em claro (tabela + índice), os três achados do scanner com id + arquivo:linha + evidência, o achado manual N-11 com a limitação do detector documentada, checklist do protocolo e resumo de prioridades para quem decide. Nenhum arquivo de `services/pedidos` foi alterado — só leitura e os dois comandos de script permitidos.

## 10. Despacho de subagente (não executado)

O artefato do agente não instrui spawn de subagente nesta tarefa (é um agente-folha, sem `Agent` nas tools). Nenhum despacho foi necessário; nada a registrar aqui além desta nota.

## 11. Fechamento

- `t1=$(date +%s)`; `timing.json` escrito com `duration_ms`/`total_duration_seconds` calculados a partir de `.t0`.
- Tamanho de `work/`: ~5,5 MB — abaixo do limite de 20 MB, não apagado.
