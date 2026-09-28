# Diagnóstico — laço na fila `pagamentos`

Revisei `src/consumidor.js`, `src/pagamentos.js` e `infra/rabbitmq/policy.json` (cluster RabbitMQ 4.1, três nós), seguindo o protocolo do especialista `data-streaming`: rules/ADRs do projeto → governança de dados → `scan.sh` da skill `data-streaming-practices` → julgamento manual de cada achado. Não alterei nada no repositório — o diagnóstico e a correção estão só nesta resposta.

## 0. Rules e ADRs do projeto

Não há rule de mensageria nem ADR de RabbitMQ no baseline deste projeto (`.forge/rules/data/*` cobre só SQL, NoSQL e cache; `.forge/product/current/adr/` está vazio). Nenhuma divergência relevante entre a skill e uma decisão do projeto — sem bloco `CONFLITO`.

## 1. Governança de dados

`bash .forge/scripts/check-data-governance.sh --path src` → `FAIL data-governance/universo-vazio` (0 arquivos examinados). O verificador só lê `.go`, `.kt`, `.ts`, `.rego`, `.py` e `.md`; este projeto é `.js`, então **PAN/PII em `src/` não foi verificado por esse gate** — isso não é aprovação nem "limpo", fica com o `scan.sh` e esta revisão.

`bash .forge/scripts/check-data-governance.sh --path infra/rabbitmq` → `OK` (examinou só o `README.md`; `policy.json` também está fora da lista de extensões do gate — mesma ressalva: não verificado por PAN/PII por ele).

## 2. Varredura (`scan.sh --root src --root infra/rabbitmq`)

Achados altos relevantes ao caso (lista completa executada; ver `transcript.md`):

- `FOUND RMQ-AP-01 [alto]` — `src/consumidor.js:16` (`noAck: true`)
- `FOUND RMQ-AP-06 [alto]` — `infra/rabbitmq/policy.json:6-7` (`ha-mode`/`ha-sync-mode`)
- `FOUND RMQ-AP-10 [alto]` — `src/consumidor.js:14` (`ch.nack(msg)`)
- `FOUND RMQ-AP-08 [aviso]` — `src/pagamentos.js:18` (publish sem confirms)
- `FOUND RMQ-AP-03 [aviso]` — conexão AMQP fora de bootstrap único (não é o problema do laço; ambos os arquivos abrem conexão própria, confirme que cada uma é de processo, não por mensagem)

O scanner **não** aponta o dual write em `pagamentos.js` — isso só a revisão manual acha (ver item 3.4).

## 3. Causa raiz e demais achados, julgados

### 3.1 RMQ-AP-10 — requeue infinito (`src/consumidor.js:14`) — **causa do laço**

```js
ch.nack(msg);
```

`ch.nack(message, allUpTo, requeue)` no amqplib tem `requeue = true` por padrão. Todo `nack` sem terceiro argumento recoloca a mensagem na cabeça da fila `pagamentos`, que é reentregue imediatamente — é exatamente o laço observado (CPU a 100%, a mesma mensagem voltando sem parar). Agrava: em fila **quorum**, `basic.nack` não incrementa o `delivery-count` (só `acquired-count`); ele não conta para o `delivery-limit`, então nem migrar para quorum sozinho conteria esse laço — é preciso trocar o `nack(msg)` por `reject`/`nack(requeue=false)` para erro permanente.

### 3.2 RMQ-AP-01 — auto-ack (`src/consumidor.js:16`)

```js
}, { noAck: true });
```

Com `noAck: true` o broker marca a mensagem como entregue no envio, antes do efeito (a atualização do pedido) persistir — se o worker cair no meio do processamento, a mensagem se perde. Precisa de ack manual, feito só depois do `processarPagamento` concluir com sucesso, com `prefetch` explícito para limitar quantas mensagens ficam em voo por consumidor.

### 3.3 RMQ-AP-06 — espelhamento clássico (`infra/rabbitmq/policy.json:6-7`)

```json
"ha-mode": "all",
"ha-sync-mode": "automatic"
```

`ha-mode`/`ha-sync-mode` são o espelhamento clássico, **removido no RabbitMQ 4.0** — num cluster 4.1 essa policy não faz HA nenhuma (o cluster ignora ou falha ao importar, dependendo da definição). A fila `pagamentos` precisa ser **quorum queue**, com `delivery-limit` sempre acompanhado de `dead-letter-exchange` (sem DLX, a mensagem que estoura o limite é descartada em silêncio) e `dead-letter-strategy: at-least-once`. Migração de fila clássica para quorum não é troca de policy — o tipo da fila é fixado na criação (`x-queue-type`); é preciso declarar a fila quorum nova e migrar (blue-green, com `rabbitmqadmin` v2 ou drenando a fila antiga antes do cutover).

### 3.4 OBX-AP-01 — dual write sem outbox (`src/pagamentos.js:15-18`) — achado só na revisão manual

```js
await db.query('UPDATE pedidos SET status = $1 WHERE id = $2', ['PAGO', evento.pedidoId]);
const ch = await canalDePublicacao();
ch.publish('pedidos', 'pedido.pago', ...);
```

`UPDATE` no PostgreSQL e `publish` no RabbitMQ não estão na mesma transação: se o processo cair entre as duas linhas, ou se o `publish` falhar (sem publisher confirms — ver 3.5 — o produtor nem saberia), o pedido fica marcado como pago sem o evento sair, ou o evento pode sair sem o commit (se a ordem fosse invertida). É dual write clássico. Correção: outbox transacional — gravar o evento numa tabela `outbox_eventos` na **mesma transação** do `UPDATE`, e um relay separado (polling ou CDC) publica com confirms e marca a linha como enviada.

### 3.5 RMQ-AP-08 — publish sem confirms (`src/pagamentos.js:18`)

`ch.publish(...)` sem `confirmSelect()`/`createConfirmChannel()` antes: o produtor não sabe se o broker aceitou a mensagem — ela pode se perder num restart do broker sem erro nenhum do lado do produtor. Isso se resolve junto com o outbox: o relay publica pelo canal com confirms.

## Correção proposta

Ver `outputs/correcao/` — `consumidor.js.patch.md`, `pagamentos.js.patch.md` e `policy.json.patch.md` com o trecho corrigido e a explicação de cada mudança. Nada foi aplicado no repositório (`git status --porcelain` no diretório da fixture só mostra a instalação do artefato `data-streaming`/`data-streaming-practices` usada para esta revisão — nenhum arquivo revisado foi tocado).

## Devolução ao orquestrador

Esta resposta é toda do domínio `data-streaming` (RabbitMQ: ack, requeue, quorum/DLX, publisher confirms, e o mecanismo de relay do outbox). O **schema** da tabela `outbox_eventos` e a transação que a grava junto com o `UPDATE` em `pedidos` são do dono do store relacional (`data-relational`, PostgreSQL) — se o schema da outbox também precisar de revisão, acione esse especialista.
