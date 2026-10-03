# Revisão de mensageria — serviço de recarga (pré-upgrade RabbitMQ 3.13 → 4.3)

## Escopo

Fluxo assíncrono interno, evento de domínio `recarga.confirmada`: `src/recarga/publicador.js` publica na exchange `recarga.eventos` (topic); `src/recarga/consumidor.js` consome a fila `saldo.creditar-recarga`; `src/infra/rabbit.js` faz o bootstrap da conexão AMQP; `infra/rabbitmq/definitions.json` e `infra/rabbitmq/enabled_plugins` definem a topologia e os plugins do cluster. Não há `.proto`/contrato síncrono envolvido — é mensageria interna pura, o que está de acordo com a regra do dono (`.forge/rules/architecture/internal-grpc-communication.md`: evento assíncrono entre módulos é mensageria, não gRPC).

Os dois incidentes relatados em `docs/contexto-mensageria.md` têm causa raiz identificável nesta revisão: (1) recarga paga que some depois de reinício de nó — publicação sem confirms e sem marca de persistência; (2) fila `saldo.creditar-recarga` girando a mesma mensagem por horas com o Postgres fora do ar — `nack` com requeue em loop, sem limite nem DLX.

## Rules do projeto

Nenhum conflito com `.forge/rules/domain/money-as-cents.md` — o evento usa `valor_centavos` como inteiro, sem `decimal`/`float` no payload. `.forge/rules/architecture/internal-grpc-communication.md` não se aplica a este fluxo (é evento assíncrono, exceção explícita da regra). `.forge/rules/data/data-governance.md` não tem violação aqui — o repositório de saldo (`saldo-repositorio.js`) não expõe consulta cross-tenant no trecho revisado. `bash .forge/scripts/check-data-governance.sh --path <projeto>` voltou `OK` (3 arquivos `.md`, sem divergência).

## Detecção

`bash .forge/skills/data-streaming-practices/scripts/scan.sh --root <projeto>` (8 arquivos varridos):

| Regra | Nível | Achado |
|---|---|---|
| RMQ-AP-03 | aviso | `rabbit.js:7` — `amqp.connect` |
| RMQ-AP-06 | alto | `definitions.json:15` — policy `ha-mode: all` |
| RMQ-AP-08 | aviso | `publicador.js:11` — publish sem confirms |
| RMQ-AP-10 | alto | `consumidor.js:24` — `canal.nack(msg)` |
| RMQ-AP-12 | aviso | `publicador.js:11` — publish sem `persistent` |
| RMQ-AP-17 | alto | `enabled_plugins:1` — `rabbitmq_delayed_message_exchange` habilitado |
| INB-AP-02 | aviso | `consumidor.js:10` — `redelivered` como condição de descarte |

Demais 25 regras do catálogo: `OK`, sem ocorrência. `check-data-governance.sh`: `OK`.

O scanner lê texto e não vê ausência de coisas (limite de fila, DLX, retenção) nem dedupe em `Set` com nome em português — os três pontos abaixo (RMQ-AP-02, RMQ-AP-11/23, INB-AP-01) são achados de revisão manual, fora do alcance do `scan.sh` (ver `## O que o scanner não faz` do `SKILL.md`).

## Julgamento — ponto a ponto

### 1. `src/infra/rabbit.js` — bootstrap da conexão

`RMQ-AP-03` é falso positivo: `amqp.connect` está exatamente no lugar certo — módulo de bootstrap, chamado uma vez na subida do processo (RMQ-BP-06). Nada a mudar aqui quanto à conexão em si.

**O que falta:** nenhum handler para `connection.blocked`/`connection.unblocked` (RMQ-AP-25). Quando o cluster dispara alarme de memória ou disco, o RabbitMQ bloqueia toda conexão que publica até o alarme cessar; sem o handler, o publicador do serviço de recarga fica bloqueado às cegas (timeout ou trava), sem alertar ninguém. Adicionar o listener em `rabbit.js` e propagar um evento (log + métrica) para o publicador pausar/alertar em vez de acumular publicação.

### 2. `src/recarga/publicador.js` — publisher confirms e persistência

Duas lacunas que, juntas, explicam o incidente 1 (recarga paga que some depois de reinício de nó):

- **RMQ-AP-08 — sem publisher confirms.** `canal.publish(...)` não usa `confirmSelect`/`waitForConfirms` (nem versão assíncrona com callback). Sem confirm, o publicador não sabe se o broker aceitou a mensagem antes de responder "recarga confirmada" ao chamador — se o broker cair ou a mensagem for perdida em trânsito, ninguém percebe.
- **RMQ-AP-12 — mensagem transiente em fila durável.** `canal.publish` não passa `{ persistent: true }` (`delivery_mode=2`). As filas em `definitions.json` são `durable: true`, mas fila durável só recupera mensagem persistente depois de um restart — mensagem transiente é descartada na recuperação mesmo em fila durável. **Isto é a causa mais provável do incidente 1**: a recarga é publicada, o nó reinicia antes de a mensagem sair da fila, e ela simplesmente não existe mais quando o broker volta — sem erro, sem rastro.

**Correção (RMQ-BP-02, RMQ-BP-05):** habilitar confirms assíncronos no canal de publicação (não confirm síncrono por mensagem — RMQ-AP-09, mata o throughput) e marcar toda publicação de negócio como persistente. Só marcar a recarga como "publicada com sucesso" depois do confirm do broker, não do retorno síncrono do `publish`.

### 3. `src/recarga/consumidor.js` — ack/nack e dedupe

- **RMQ-AP-10 — requeue infinito, causa direta do incidente 2.** `canal.nack(msg)` chamado sem segundo/terceiro argumento: em amqplib, `nack(msg)` tem `requeue=true` por padrão — a mensagem volta para a cabeça da fila e é reentregue imediatamente. Quando `creditarSaldo` falha porque o Postgres está fora do ar, todo `nack` volta a mesma mensagem, que falha de novo, em loop, consumindo CPU e bloqueando a fila atrás dela. Pior: como a fila hoje é clássica (ver ponto 4), não há `delivery-limit` nenhum contendo esse loop; mesmo migrando para quorum, `basic.nack` não incrementa o `delivery-count` da quorum (só `basic.reject` incrementa) — **`nack` com requeue nunca é contido pelo `delivery-limit`**, migrar para quorum sozinho não resolve isto.
- **INB-AP-02 — `redelivered` como prova de duplicata.** Linha 10, `if (msg.fields.redelivered) { ack; return; }` descarta a mensagem só porque foi reentregue, sem checar se o crédito realmente foi feito. `redeliver=true` é pista, não prova: se o processo caiu depois de creditar o saldo mas antes do `ack`, a reentrega é uma duplicata legítima que precisa ser ack'd sem reprocessar — mas se o processo caiu **antes** de creditar, essa mesma linha descarta uma mensagem que nunca produziu efeito, e o saldo nunca é creditado. É outro caminho plausível para "recarga paga que some".
- **INB-AP-01 — dedupe em memória (achado manual, fora do scanner).** `const processados = new Set()` mais `processados.has(evento.event_id)`/`.add(...)` é exatamente o antipattern "dedupe em `Set` do processo": o estado zera a cada restart e não é compartilhado entre réplicas do consumidor. Combinado com o ponto acima, o serviço não tem nenhuma proteção real contra duplicata — nem por `redelivered` (pista fraca) nem pelo `Set` (não sobrevive a restart/scale-out). O `scan.sh` não pegou este caso porque o heurístico procura nomes como `processedIds`/`seenMessages`; `processados` (nome em português) escapou — vale registrar como gap do detector, não como ausência de antipattern.

**Correção (RMQ-BP-14):** substituir `redelivered` + `Set` por inbox transacional — tabela `(subscriber_id, message_id)` com chave única, inserida na **mesma transação Postgres** que credita o saldo em `saldo-repositorio.js`; `ack` só depois do commit dessa transação. Isso também fecha a lacuna: se a transação (insert na inbox + update de saldo) falhar e for revertida, a mensagem pode ser reprocessada com segurança; se ela já commitou, o insert na inbox falha por PK duplicada e o consumidor só faz `ack` sem repetir o crédito.

Erro permanente (payload inválido, cartão inexistente) deve virar `reject`/`nack(msg, false, false)` (terceiro argumento `requeue=false`) para a DLX — nunca o `nack(msg)` atual. Erro transitório (Postgres fora do ar) não deve ser tratado como falha "reentrega na hora": ver seção de retry abaixo.

### 4. `infra/rabbitmq/definitions.json` — topologia

- **RMQ-AP-06 — policy de espelhamento clássico, bloqueante para o upgrade.** A policy `ha-todas` (`ha-mode: all`, `ha-sync-mode: automatic`, `pattern: ".*"`) usa espelhamento clássico, **removido no RabbitMQ 4.0**. Rodando ainda em 3.13, funciona; no upgrade para 4.3 essa policy não tem mais efeito — silenciosamente, a fila perde a HA que hoje tem. É o achado mais crítico do ponto de vista do upgrade e precisa ser resolvido antes da janela.
- **Filas ainda são clássicas (achado manual — `arguments: {}`, sem `x-queue-type: quorum`).** Nenhuma das duas filas (`saldo.creditar-recarga`, `extrato.registrar-recarga`) declara `"x-queue-type": "quorum"`. Sem essa declaração, a policy de HA de fato em vigor é a clássica acima — migrar para quorum é pré-requisito para ter HA real no cluster 4.3 e para ganhar `delivery-limit`/retry atrasado nativo.
- **RMQ-AP-02 / sem `max-length` (achado manual — não coberto pelo scanner, que só audita isso em runtime).** Nenhuma fila declara `max-length`/`max-length-bytes`/`overflow`. Sem teto, um backlog (por exemplo o Postgres fora do ar represando `saldo.creditar-recarga`) cresce até disparar alarme de memória/disco do cluster, que bloqueia publicação em todo o cluster — inclusive de outros serviços, não só o de recarga.
- **RMQ-AP-11 / RMQ-AP-23 — sem DLX em nenhuma fila (achado manual).** Nenhuma fila tem `dead-letter-exchange` configurado. Combinado com o `nack(requeue=true)` do consumidor, hoje não há nenhum destino para mensagem envenenada — ela só faz loop infinito, nunca "sai" da fila principal. Depois da migração para quorum (que já vem com `delivery-limit=20` por padrão desde o 4.0), a ausência de DLX passa a significar descarte silencioso após 20 tentativas, em vez de loop infinito — troca um problema visível (fila travada, fácil de notar) por um invisível (mensagem sumida sem log). **DLX é pré-requisito da migração, não opcional.**

**Correção (receita de referência do catálogo, RMQ-BP-01/08/09/10/20):** para cada fila de trabalho (`saldo.creditar-recarga`, `extrato.registrar-recarga`) — `x-queue-type: quorum` na declaração; policy com `max-length` (ou `max-length-bytes`) + `overflow: reject-publish`; `dead-letter-exchange` apontando para uma exchange `recarga.dlx`; `dead-letter-strategy: at-least-once` + `overflow: reject-publish` na fila DLX também (requisito da plataforma para at-least-once); `delivery-limit` explícito (ou aceitar o default 20, mas documentado). Cada fila de trabalho ganha uma fila `*.parking` correspondente atrás da DLX, com alerta de profundidade > 0 e dono — hoje não existe.

Remover a policy `ha-todas` (`ha-mode`/`ha-sync-mode`) inteira: sem efeito e sem sentido em quorum queue, e ela é o que trava o `rabbitmq-diagnostics check_if_any_deprecated_features_are_used` no upgrade.

### 5. `infra/rabbitmq/enabled_plugins` — plugin delayed exchange

- **RMQ-AP-17 — plugin depreciado e arquivado, e o time pretende usá-lo para o retry com espera.** `docs/contexto-mensageria.md` diz explicitamente: "*o time quer usar o plugin de delayed exchange que já está habilitado para fazer retry com espera*". Isto é o antipattern RMQ-AP-17 por definição: o `rabbitmq-delayed-message-exchange` foi depreciado e arquivado por limitação arquitetural, documentado no blog da versão 4.3. Não usar, mesmo estando habilitado hoje — usar retry nativo da quorum (ver seção seguinte) é a alternativa direta e já alinhada com o destino do upgrade.

## Como fazer o retry com espera (RMQ-BP-12)

O cluster está em 3.13 hoje e vai para 4.3; a estratégia de retry precisa cobrir os dois momentos sem depender do plugin depreciado em nenhum deles.

**Antes do upgrade (3.13, hoje) — filas de espera por patamar:**
Como o retry atrasado nativo só existe a partir do 4.3, o padrão pré-4.3 é uma fila de espera por patamar de tempo, com TTL de fila (não de mensagem — TTL por mensagem só expira na cabeça da fila) e DLX de volta para a fila principal:

- `saldo.creditar-recarga.retry.5s` (TTL de fila 5s, `dead-letter-exchange` apontando de volta para `recarga.eventos`/routing key original, ou direto para a fila de trabalho).
- `saldo.creditar-recarga.retry.30s`, `saldo.creditar-recarga.retry.5m` — mesmo padrão, patamares crescentes.
- No consumidor: erro transitório (falha de conexão com Postgres, timeout) → `reject`/`nack(msg, false, false)` publicado explicitamente na fila do primeiro patamar (via `x-death` para saber em qual patamar está), nunca `nack(msg, true)`. Contar `x-death` para decidir quando parar de tentar e mandar para o `parking` definitivo.
- Erro permanente (evento malformado, cartão inexistente) vai direto para `parking`, sem passar pelos patamares.

**Depois do upgrade (4.3+) — retry atrasado nativo da quorum:**
Trocar as filas de espera pelo argumento nativo na fila `saldo.creditar-recarga` (já quorum, do ponto 4): `delayed-retry-type: failed`, `delayed-retry-min` (ex.: `1000` ms) e `delayed-retry-max` (ex.: `60000` ms) — atraso = `min(delayed-retry-min × delivery-count, delayed-retry-max)`, backoff linear com teto, sem jitter nativo (se o efeito colateral do retry for uma chamada remota, aplicar jitter no cliente, não no broker). O `delivery-limit` (20 por padrão) some a mensagem para a DLX depois do teto — por isso a DLX do ponto 4 é obrigatória antes de ligar isto, não depois.

**Em ambos os casos:** o consumidor nunca decide "espera" chamando `nack(requeue=true)` — isso é sempre o loop do incidente 2. "Retry com espera" é sempre uma republicação explícita (fila de patamar) ou uma configuração declarativa de fila (retry nativo 4.3+), nunca requeue na fila principal.

**Ordem:** este fluxo não promete ordem entre recargas do mesmo cartão (não há SAC nem consistent hash exchange aqui), então o retry atrasado tirar a mensagem da posição original não é um problema de ordem neste caso — não é preciso o cuidado de RMQ-AP-26/RMQ-BP-23.

## Resumo — o que muda em cada ponto (sem alterar código ainda)

| Arquivo | Mudança |
|---|---|
| `src/infra/rabbit.js` | Adicionar handler `connection.blocked`/`unblocked` |
| `src/recarga/publicador.js` | Publisher confirms assíncronos + `persistent: true` em toda publicação |
| `src/recarga/consumidor.js` | Trocar `nack(msg)` por `reject`/`nack(requeue=false)` em erro permanente; substituir `redelivered` + `Set` em memória por inbox transacional (`subscriber_id, message_id`) na mesma transação do `UPDATE` de saldo; erro transitório publica na fila de retry, nunca requeue |
| `infra/rabbitmq/definitions.json` | `x-queue-type: quorum` nas duas filas; `max-length`/`overflow: reject-publish`; `dead-letter-exchange` + filas `*.parking` com alerta; remover a policy `ha-todas`; criar as filas `*.retry.<patamar>` (pré-4.3) |
| `infra/rabbitmq/enabled_plugins` | Não adotar o delayed exchange para o retry (plugin depreciado); manter habilitado só se algo mais o usa hoje — nada neste fluxo deveria depender dele |
| Pré-upgrade | Rodar `rabbitmq-diagnostics check_if_any_deprecated_features_are_used` e `GET /api/deprecated-features/used` depois de tirar a policy `ha-todas` e migrar para quorum; confirmar que o cluster já está em Khepri antes de ir para 4.3 (Mnesia removido na 4.3) |

## Fora do escopo revisado (mencionar, não investigar agora)

O código que cria a recarga e chama `publicarRecargaConfirmada` não está nos arquivos revisados — se o `publish` acontece dentro da mesma transação/handler que grava a recarga como paga (dual write, sem outbox — OBX-AP-01), isso é uma terceira via para "recarga que some" além dos pontos 2 e 3: o commit da recarga pode ter sucesso e o publish falhar (ou vice-versa) sem nenhuma garantia atômica entre os dois. Vale confirmar isso à parte antes do upgrade.
