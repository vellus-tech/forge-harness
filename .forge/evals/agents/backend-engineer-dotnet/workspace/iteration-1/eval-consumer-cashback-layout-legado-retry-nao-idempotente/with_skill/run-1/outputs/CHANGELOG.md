# Changelog — cashback-worker

## [Unreleased]

### Adicionado

- `ViagemValidadaConsumer`: consome `ViagemValidada` (exchange `bilhetagem.viagens`, publicada pela validadora) e credita 2% de cashback na carteira via `CarteiraClient` (TASK-07, REQ-011).
- Publicação de `CashbackCreditado` na exchange `cashback.creditado` após o crédito confirmado.
- `contracts/asyncapi/cashback.yaml` (0.4.0): documenta o canal `bilhetagem.viagens` consumido.

### Alterado

- `CarteiraClient.CreditarAsync` passou a exigir `idempotencyKey` e enviá-la no header `Idempotency-Key`, evitando crédito duplicado em retry ou em redelivery da mensagem (a API da carteira não é idempotente por padrão — ver `docs/integracoes/carteira-api.md`).
- `AddHttpClient<ICarteiraClient, CarteiraClient>` ganhou um handler de resiliência (`CarteiraResiliencia`) com até 5 tentativas, backoff exponencial e jitter, para absorver os timeouts de pico (p99 ~4 s) sem duplicar crédito.

## [0.3.0] - 2026-08-20

### Adicionado

- Regra de cashback de 2% sobre a tarifa (`RegraCashback`).
