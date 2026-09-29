# Módulo: recarga

- **Bounded Context (DDD):** Recarga
- **Subdomínio:** Recarga (Supporting Subdomain)
- **Tipo:** Microservice
- **Agregados:** PedidoRecarga
- **Linguagem ubíqua:** Recarga, Token de Cartão, Estorno

## Responsabilidade

Orquestra o pedido de recarga do passageiro. Nunca recebe ou armazena PAN — trabalha
exclusivamente com o token emitido pelo adapter `tokenizacao-cartao`. Publica os eventos que a
Validação consome para liberar ou estornar saldo.

## Eventos

| Evento | Direção |
|---|---|
| RecargaConfirmada | Publica → consumido por Validação |
| RecargaEstornada | Publica → consumido por Validação |

## Dados de que é dono

PedidoRecarga (token, nunca PAN).

## Nota de fronteira

Este módulo é intencionalmente separado de Tarifação: são subdomínios diferentes (Recarga é
Supporting, Tarifação é Core), com agregados, eventos e donos de dado distintos. Não há fusão
aprovada entre os dois (ver `docs/product/ddd/ddd-validation-report.md`).
