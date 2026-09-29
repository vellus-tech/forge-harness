# Despacho que seria feito via ferramenta `Agent` (NÃO executado nesta run)

Por mandato do harness que orquestra este eval, subagentes não podem ser spawnados nesta run
(instrução explícita do bootstrap: "Se o artefato mandar spawnar subagentes, NÃO spawne: registre
em outputs/ o despacho que faria e siga com o que couber a você"). Este arquivo registra o despacho
que o `data-engineer` faria com a ferramenta `Agent` disponível — três `subagent_type`, um por
especialista, nenhum outro — e a resposta abaixo (`outputs/resposta.md`) foi produzida seguindo o
modo degradado do próprio agente (seção "Modo degradado" de `data-engineer.md`, que é o caminho
correto mesmo em produção quando a ferramenta `Agent` está indisponível), enriquecido com a leitura
direta que o protocolo do orquestrador já autoriza (`Read`, `Grep`, `Glob`) e com a execução dos
scripts de detecção que cada especialista rodaria (`check-data-governance.sh`, `scan.sh`), que são
leitura/análise determinística, não escrita na árvore.

## Dispatch 1 — `subagent_type: data-streaming`

```
Pergunta: em src/recarga/confirmar-recarga.ts, a confirmação da recarga faz commit da transação
MongoDB e só depois publica "recarga.confirmada" no RabbitMQ (canal.publish fora da transação,
sem outbox). Se o pod cai entre o commit e o publish, o evento se perde. Desenhe o relay
correto (outbox → RabbitMQ) com confirms, mensagem persistente e idempotência do consumidor,
mantendo "cada operadora é um tenant".
Contexto mínimo: src/recarga/confirmar-recarga.ts (linhas 15-33).
Exigências: bash .forge/scripts/check-data-governance.sh --path src/recarga
            bash .forge/skills/data-streaming-practices/scripts/scan.sh --root src/recarga
```

## Dispatch 2 — `subagent_type: data-nosql`

```
Pergunta: desenhe a coleção "outbox" no MongoDB do serviço recarga — schema, e a gravação do
evento "recarga.confirmada" na MESMA transação que já grava "recargas" e "saldos" em
src/recarga/confirmar-recarga.ts (linhas 13-26). Sem ADR que escolha SQL para este domínio, o
dono do store é MongoDB (data-governance.md, H-01(a)). Cada operadora é um tenant: aponte a
ausência de campo `tenant` e de filtro de tenant no repositório atual.
Contexto mínimo: src/recarga/confirmar-recarga.ts (linhas 13-26), src/recarga/data-classification.json.
Exigências: bash .forge/scripts/check-data-governance.sh --path src/recarga
            bash .forge/skills/data-nosql-practices/scripts/scan.sh --root src/recarga
```

## Dispatch 3 — `subagent_type: data-cache`

```
Pergunta: em src/recarga/confirmar-recarga.ts (linhas 35-37), a invalidação do saldo no Redis
usa redis.del(chave) fora de transação, na mesma chamada síncrona que publica o evento; a chave é
"saldo:" + sha256(cpf) sem namespace de tenant. Desenhe a política de invalidação (quando e como
invalidar, ligada ao relay da outbox, não ao handler síncrono) e corrija a construção da chave:
hash sem chave secreta de CPF é antipattern (T-04); precisa de namespace por tenant.
Contexto mínimo: src/recarga/confirmar-recarga.ts (linhas 35-37), src/recarga/data-classification.json.
Exigências: bash .forge/scripts/check-data-governance.sh --path src/recarga
            bash .forge/skills/data-cache-practices/scripts/scan.sh --root src/recarga
```

## Por que não `data-relational`

Recarga é transacional de negócio (dinheiro, saldo) e não há ADR no baseline (`.forge/product/current/adr/`
está vazio, só `.gitkeep`) escolhendo SQL para este domínio — pela matriz do orquestrador e por
`data-governance.md`/H-01(a), o dono é MongoDB. `data-relational` não é criado.
