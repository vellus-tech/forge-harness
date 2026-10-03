# Requirements — fare-validation

## RF-004 — Receber lote de embarques offline
Como validador embarcado, quero enviar o lote de embarques acumulado offline, para que as tarifas sejam cobradas quando houver conectividade.
- Dado lote assinado pelo dispositivo cadastrado, quando enviado a `POST /api/v1/boarding-batches`, então recebe 202 e cada embarque é persistido uma única vez (idempotente por `deviceId`+`sequence`).
- Dado dispositivo não cadastrado, quando envia o lote, então recebe 403.

## RF-005 — Cobrar tarifa com integração temporal
Como passageiro, quero pagar uma única tarifa em embarques feitos em até 60 minutos, para ter integração entre linhas.
- Dado segundo embarque em até 60 minutos do primeiro, quando processado, então `FareCharged` é publicado com valor 0.
- Dado embarque após 60 minutos, quando processado, então `FareCharged` é publicado com a tarifa cheia da `fare_rule` vigente.

## RF-006 — Consultar embarques no backoffice
Como operador de backoffice, quero listar os embarques das últimas 24h filtrando por linha e dispositivo, para auditar cobranças contestadas.
- Dado filtros válidos, quando chama `GET /api/v1/boarding-events`, então recebe lista paginada com valor cobrado por embarque.
