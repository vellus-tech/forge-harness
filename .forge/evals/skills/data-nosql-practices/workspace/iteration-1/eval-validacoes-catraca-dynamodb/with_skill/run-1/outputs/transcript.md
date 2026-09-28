# Transcript — eval-validacoes-catraca-dynamodb / with_skill / run-1

Caso: skill `data-nosql-practices` carregada como skill do harness (protocolo em
`template/.forge/skills/data-nosql-practices/SKILL.md`).

## 1. Bootstrap

- `date +%s > .t0` — instante inicial gravado.
- `mkdir -p work` e `bash fixtures/validacoes-catraca-dynamodb/setup.sh work` — projeto fixture
  materializado em `work/` (inclui `.forge/`, `.claude/`, `docs/padroes-de-acesso-validacoes.md`,
  `services/validacoes/{infra,src/handlers,scripts/backfill}`).

## 2. Leitura da skill (protocolo, ordem fixa)

Li `SKILL.md`, `references/best-practices.md` (108 linhas) e `references/antipatterns.md`
(166 linhas, catálogo N-01 a N-23) do artefato do harness (`template/.forge/skills/data-nosql-practices/`).
Confirmado no `SKILL.md`: escopo cobre chave-valor persistente (DynamoDB); transacional de negócio
(pedido/pagamento/ledger) é MongoDB por regra da casa — a tabela `validacoes-catraca` é log
operacional de passagem, não transacional de negócio, então o roteamento para DynamoDB está certo
e não há `CONFLITO` a levantar.

## 3. Escopo (passo 1 do protocolo)

Padrões de acesso inventariados de `docs/padroes-de-acesso-validacoes.md` antes de tocar em chave:
escrita ~12.000/s no rush (todas com a data do dia corrente), leitura do histórico do cartão por
30 dias ~3.000 req/s (maior parte do tráfego de leitura), painel do operador por tenant/status
tolerando segundos de atraso, cartão frequente > 2.000 validações/ano, multi-tenant por operadora.
Paths afetados: `services/validacoes/infra/dynamodb.tf`, `services/validacoes/src/handlers/*.ts`,
`services/validacoes/scripts/backfill/*.ts` (a tarefa autorizou deixar como está se estiver ok).

## 4. Rules do projeto (passo 2)

Li `.forge/rules/data/data-governance.md` e `.forge/rules/data/data-transactional-nosql.md` (no
artefato do harness). A rule de tenant obrigatório com filtro de repositório é específica de
MongoDB/transacional de negócio — não se aplica como bloqueio a esta tabela DynamoDB, mas o
princípio "tenant como prefixo/parte da chave em desenho multi-tenant" das boas práticas do
`data-nosql-practices` (`best-practices.md`) foi aplicado na GSI do painel do operador.

## 5. Detecção (passo 3) — antes da correção

```
bash template/.forge/scripts/check-data-governance.sh --path work
  -> OK (sem divergência de governança; universo de 6 arquivos)

bash template/.forge/skills/data-nosql-practices/scripts/scan.sh --root work
  -> FOUND N-06 dynamodb.tf:22          hash_key = "status" (GSI, baixa cardinalidade)
  -> FOUND N-08 historicoCartao.ts:5    ScanCommand no caminho da requisição
  -> FOUND N-08 reprocessarTarifas.ts   ScanCommand (backfill offline)
  -> FOUND N-09 registrarValidacao.ts:14  list_append sem teto
  -> FOUND N-10 dynamodb.tf:24          projection_type = "ALL"
  -> FOUND N-11 historicoCartao.ts:15   ConsistentRead:true + IndexName de GSI
```

## 6. Julgamento (passo 4)

- **N-06, dois casos.** O scanner só achou a GSI (`hash_key = "status"`). Revisão manual achou um
  segundo caso mais grave que o detector estático não pega: a chave de partição da **tabela base**
  era `data_validacao` — um único valor por dia, com ~12.000 escritas/s do rush inteiras carimbadas
  com a data corrente caindo numa partição só (muito acima do teto de 1.000 WCU/s por partição).
  Esse é o achado central da revisão: o catálogo avisa explicitamente ("o scanner localiza; quem
  revisa decide") que ele não mede cardinalidade real — aqui nem precisou de runtime, bastou ler o
  padrão de acesso (toda escrita "com a data do dia corrente").
- **N-08, dois casos, julgamento oposto.** `historicoCartao.ts` usa `Scan` no caminho de uma
  requisição HTTP do app do passageiro — antipattern real, current tabela em 40M itens. O
  `reprocessarTarifas.ts` usa `Scan` com `Segment`/`TotalSegments` num job de migração offline
  manual — o próprio catálogo ("O que o scanner não faz") diz que Scan em migração offline é o uso
  certo; mantido sem alteração, como a tarefa autorizou.
- **N-09.** `list_append` sem teto em `cartoes-transporte.passagens`, e além do risco de tamanho
  (item até 400 KB), a escrita duplicava dado já consultável na própria tabela de validações depois
  do redesenho de chave — removida, não só corrigida com um teto.
- **N-10.** GSI com `projection_type = "ALL"` — o painel do operador só precisa de alguns campos;
  trocado por `INCLUDE`.
- **N-11.** `ConsistentRead: true` numa `Query` com `IndexName` de GSI — o DynamoDB recusa essa
  combinação (é um bug funcional, não só um desvio de boas práticas). Corrigido removendo
  `ConsistentRead` da leitura da GSI (aceitável: o padrão de acesso tolera segundos de atraso).

## 7. Desenho e correções aplicadas

- `services/validacoes/infra/dynamodb.tf`: tabela base repartida por `cartao_id`/`validacao_sk`
  (em vez de `data_validacao`/`validacao_id`); GSI `por-tenant-status` com `hash_key =
  tenant_status_shard` (write sharding por sufixo, `SHARD_COUNT = 10`, heurística de partida a
  validar com Contributor Insights em homologação) e projeção `INCLUDE`, substituindo a GSI
  `por-status` com `hash_key = status` e projeção `ALL`.
- `services/validacoes/src/handlers/registrarValidacao.ts`: grava o item com a nova chave e o
  atributo `tenant_status_shard`; removida a escrita em `cartoes-transporte.passagens`
  (`list_append`); acrescentei `ConditionExpression: attribute_not_exists(validacao_sk)` para
  idempotência do `Put` (o validador embarcado pode reenviar em falha de rede) — decisão extra,
  fora dos antipatterns do catálogo, registrada aqui para transparência.
- `services/validacoes/src/handlers/historicoCartao.ts`: `historicoCartao()` passa a fazer `Query`
  por `cartao_id` com corte de 30 dias (`ScanIndexForward: false`, `ConsistentRead: true` — válido
  na tabela base); `pendentes()` passa a fazer `SHARD_COUNT` queries paralelas na GSI
  `por-tenant-status` e juntar o resultado, sem `ConsistentRead`.
- `docs/design-validacoes.md`: desenho de chaves/índices/consistência, alternativas descartadas
  (GSI por `status`, GSI por `tenant` sem shard) e por que perdiam, tabela de rastreio dos
  antipatterns endereçados, e o ponto de atenção fora do escopo pedido (o backfill precisa ser
  adaptado à nova chave, ou os 40M itens de homologação migrados, antes de rodar em produção —
  não implementado, só registrado, porque a tarefa autorizou deixar o backfill como está).

## 8. Detecção (passo 3) — depois da correção

```
bash template/.forge/skills/data-nosql-practices/scripts/scan.sh --root work
  -> N-06: OK, nenhuma ocorrência
  -> N-08: FOUND só no backfill (esperado, uso correto — ver julgamento acima)
  -> N-09: FOUND numa linha de comentário que cita "list_append" ao explicar a remoção
           (falso positivo textual do scanner, não é código)
  -> N-10: OK, nenhuma ocorrência
  -> N-11: FOUND numa linha de comentário que cita "ConsistentRead: true" ao explicar a correção
           (falso positivo textual do scanner, não é código)
```

## 9. Relatório (passo 5) — uma linha por regra do catálogo tocado nesta revisão

| Id | Status | Local |
|---|---|---|
| N-01 | limpo | não se aplica (não é MongoDB) |
| N-04 | limpo | não se aplica |
| **N-06** | **achado, corrigido** | `dynamodb.tf` — chave da tabela (revisão manual) e chave da GSI (scanner) |
| N-07 | limpo | não se aplica |
| **N-08** | **achado, corrigido** em `historicoCartao.ts`; **confirmado OK** no backfill | ambos revisados |
| **N-09** | **achado, corrigido** (removido, não só limitado) | `registrarValidacao.ts` / `cartoes-transporte` |
| **N-10** | **achado, corrigido** | `dynamodb.tf` — GSI |
| **N-11** | **achado, corrigido** | `historicoCartao.ts` — `pendentes()` |
| N-12/13/14/15/17/18/19/20/21/23 | limpo | fora do escopo desta tabela |

## 10. Encerramento

Nenhum subagente foi spawnado (proibido pelas regras da tarefa). Nenhum comando de escrita externa
(git, gh, npm publish, docker) foi executado. Entregáveis copiados para `outputs/`:
`docs/design-validacoes.md`, `services/validacoes/infra/dynamodb.tf`,
`services/validacoes/src/handlers/registrarValidacao.ts`,
`services/validacoes/src/handlers/historicoCartao.ts`, e este `transcript.md`.
