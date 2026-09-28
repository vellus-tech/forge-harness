# Design — saldo do cartão de transporte no Redis

> Baseado em `docs/proposta-saldo-cartao.md` e `services/saldo-cartao/docker-compose.yml`. Escopo: chaves, estruturas e comandos para recarga (crédito) e débito de tarifa, com extrato. Valores monetários em centavos (inteiro), nunca float.

## Risco a decidir antes de implementar (não é só chaves)

A proposta usa Redis com AOF (`appendfsync everysec`) como único armazenamento do saldo — sem banco relacional por trás. Isso significa: (1) `everysec` reconhece o `fsync` a cada 1s, então uma queda do processo/container pode perder até ~1s de débitos e créditos já confirmados ao validador embarcado; (2) não há nenhum ADR registrado sobre essa decisão, apesar de ser saldo financeiro real (créditos via PIX). Recomendo registrar um ADR explícito aceitando esse risco (ou trocando para `appendfsync always`, que tem custo de latência, ou adicionando um banco durável como source of truth com Redis como cache/hot path). Sigo abaixo desenhando chaves e comandos como pedido, mas o ADR é bloqueante antes de produção.

## Convenções de chave

Namespace por tenant (operadora) e cartão, delimitado por `:`, sem espaços, tudo em minúsculas:

```
saldo:{tenant}:{card_id}                 -> String (centavos, inteiro)
extrato:{tenant}:{card_id}               -> List (JSON por entrada, mais recente primeiro)
idem:{tenant}:{card_id}:{tx_id}          -> String "1" com TTL (chave de idempotência)
```

- `tenant`: código curto da operadora (4 tenants previstos).
- `card_id`: identificador único do cartão (não o PAN/UID físico — usar o id lógico já emitido pelo sistema de bilhetagem).
- `tx_id`: id de transação gerado pelo validador/gateway de recarga, usado para idempotência em retries de rede.

Com 3 milhões de cartões ativos × 4 tenants, isso dá até 12M chaves de saldo + 12M listas de extrato — dimensionar memória do Redis para isso (String de saldo é barata; a lista de extrato é o item que cresce).

## Estrutura do saldo

`saldo:{tenant}:{card_id}` — String contendo um inteiro em centavos. Nunca usar float (viés de arredondamento em milhões de operações).

- Recarga (crédito): `INCRBY saldo:{tenant}:{card_id} {valor_centavos}`
- Débito de tarifa: `INCRBY saldo:{tenant}:{card_id} -{valor_centavos}` (equivalente a `DECRBY`)

Atenção: `INCRBY` sozinho não verifica saldo insuficiente — ele sempre aplica e pode deixar o saldo negativo. Se a regra de negócio exige bloquear passagem sem saldo, isso precisa ser decidido no validador (checar saldo antes, ex. `GET`, e só então debitar) ou via script Lua atômico (`EVAL`) que faz o `GET`+condição+`DECRBY` em uma única operação no servidor — decisão de negócio que falta na proposta e deveria estar no design, não só a mecânica do comando.

## Estrutura do extrato

`extrato:{tenant}:{card_id}` — List, um JSON por evento, inserido no topo (mais recente primeiro):

```
LPUSH extrato:{tenant}:{card_id} '{"ts":"2026-09-28T14:32:10Z","tipo":"debito","valor":-450,"tx_id":"...","ref":"validador-123"}'
```

- Recarga: `tipo:"credito"`, `valor` positivo.
- Débito: `tipo:"debito"`, `valor` negativo (espelha o sinal aplicado ao saldo).
- Listas de extrato crescem sem limite por padrão — com 3M cartões passando várias vezes ao dia, isso é a maior fonte de crescimento de memória do dataset. Aplicar `LTRIM extrato:{tenant}:{card_id} 0 199` logo após cada `LPUSH` para manter só as últimas 200 entradas em memória "quente"; histórico completo deveria viver em um armazenamento durável e consultável (fora do escopo deste documento, mas precisa existir — Redis não é ferramenta de consulta analítica/auditoria de longo prazo).

## Atomicidade e idempotência (crítico para dinheiro)

Toda operação de crédito ou débito deve:

1. Checar idempotência antes de aplicar: `SET idem:{tenant}:{card_id}:{tx_id} 1 NX EX 86400`. Se retornar nulo (chave já existia), a transação já foi processada — não repetir o `INCRBY`/`LPUSH` (retry do validador/gateway não pode debitar duas vezes).
2. Aplicar saldo e extrato na mesma transação Redis (`MULTI`/`EXEC`), para que os dois nunca fiquem dessincronizados:

```
MULTI
INCRBY saldo:{tenant}:{card_id} -450
LPUSH extrato:{tenant}:{card_id} '{"ts":"...","tipo":"debito","valor":-450,"tx_id":"..."}'
LTRIM extrato:{tenant}:{card_id} 0 199
EXEC
```

`MULTI`/`EXEC` garante atomicidade de execução (nenhum outro cliente intercala comandos no meio), mas não faz rollback condicional — se a regra de saldo mínimo importa, resolver isso no passo 1 (checagem) ou via Lua, não dentro do `MULTI`.

## Comandos de referência (resumo)

| Operação | Comando |
|---|---|
| Ler saldo | `GET saldo:{tenant}:{card_id}` |
| Creditar (recarga) | `INCRBY saldo:{tenant}:{card_id} {centavos}` |
| Debitar (tarifa) | `INCRBY saldo:{tenant}:{card_id} -{centavos}` |
| Registrar extrato | `LPUSH extrato:{tenant}:{card_id} '{json}'` |
| Limitar extrato quente | `LTRIM extrato:{tenant}:{card_id} 0 199` |
| Ler últimas N entradas | `LRANGE extrato:{tenant}:{card_id} 0 {n-1}` |
| Idempotência de transação | `SET idem:{tenant}:{card_id}:{tx_id} 1 NX EX 86400` |

## Pendências antes de implementar

1. ADR sobre Redis como source of truth do saldo (risco de perda de até 1s de dados com `appendfsync everysec`) — hoje não existe nenhum registrado.
2. Decisão de negócio sobre bloqueio de saldo insuficiente (checagem prévia vs. script Lua vs. permitir negativo e reconciliar depois).
3. Estratégia de retenção/auditoria do extrato completo fora do Redis (a lista truncada aqui é só cache operacional, não livro-razão).
4. Estratégia de backup/restore e teste de failover do container Redis (o compose atual não define volume nomeado nem política de restart/backup).
