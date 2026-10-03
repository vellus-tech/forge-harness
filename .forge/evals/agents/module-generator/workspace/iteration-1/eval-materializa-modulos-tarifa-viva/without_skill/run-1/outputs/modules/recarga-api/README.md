# recarga-api

Microservice. Bounded context: **Recarga** (subdomínio Recarga, Supporting Subdomain).

## Responsabilidade

Orquestra o pedido de recarga de saldo feito pelo app com cartão de crédito/débito. Nunca recebe o PAN do cartão — delega a tokenização e a autorização ao `tokenizacao-cartao-adapter` e trabalha só com o token retornado. Também trata o estorno de recargas não confirmadas pela adquirente em até 24 h.

## Aggregates e linguagem ubíqua

- **PedidoRecarga** — o pedido de recarga em curso.
- Termos: Recarga, Token de Cartão, Estorno.

## API

| Método | Endpoint | Requisito |
|---|---|---|
| POST | /v1/recargas | FR-02 |

## Eventos

| Evento | Direção | Publicado/consumido |
|---|---|---|
| RecargaConfirmada | Publica | Consumido por Validação |
| RecargaEstornada | Publica | Consumido por Validação |

## Dependências

- **tokenizacao-cartao-adapter** — chamada síncrona (gRPC interno) para tokenizar e autorizar o cartão na adquirente; é o único ponto do sistema que manipula PAN.
- **Validação** (`validacao-embarque-api`) — downstream via Published Language (eventos `RecargaConfirmada`/`RecargaEstornada`).

## Dados

| Tabela | Campos sensíveis |
|---|---|
| pedidos_recarga | token_cartao, ultimos4 |

`token_cartao` e `ultimos4` são os únicos dados relacionados ao cartão persistidos aqui — nunca PAN ou CVV.

## Requisitos não funcionais

- NFR-02 (PCI DSS 4.0.1) — este módulo é escopo PCI por manipular token de cartão de pagamento, mas fica fora do CDE estrito porque nunca recebe PAN; ainda assim precisa seguir os controles de proteção de dados de token e de logging (sem PAN/CVV em log, inclusive em erros de integração com a adquirente).
- NFR-05 — disponibilidade 99,5%.
- FR-03 — estorno automático de recarga não confirmada pela adquirente em até 24 h.

## Segurança e compliance

**Recorte PCI DSS.** Este é o segundo módulo, junto com `tokenizacao-cartao-adapter`, que o time de segurança deve revisar antes do go-live. Regra de design inegociável (NFR-02): `recarga-api` só manipula token de cartão, nunca PAN; a fronteira exata do CDE é a chamada gRPC para `tokenizacao-cartao-adapter` — tudo o que atravessa essa fronteira em direção a `recarga-api` já deve estar tokenizado. Validar em code review e em teste de integração que nenhum campo de request/response, log ou mensagem de erro deste serviço carrega PAN ou CVV.

## Stack

Go; gRPC para comunicação interna (com `tokenizacao-cartao-adapter`); REST na superfície externa (app); PostgreSQL como persistência.
