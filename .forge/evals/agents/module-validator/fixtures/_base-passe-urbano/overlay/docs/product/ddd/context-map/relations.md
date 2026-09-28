# Relações do Context Map

| Downstream (depende de) | Upstream | Padrão | Meio |
|---|---|---|---|
| recarga | tarifacao | OHS/PL — tarifacao expõe Open Host Service `TarifaVigente` | gRPC |
| recarga | cadastro-passageiro | ACL — recarga traduz o modelo de cartão via Anti-Corruption Layer | gRPC `CreditarSaldo` |
| notificacoes | recarga | PL — evento publicado `RecargaConfirmada` | RabbitMQ |
| notificacoes | cadastro-passageiro | Conformist — lê contato do passageiro sem tradução | gRPC `ObterContato` |

Nenhuma outra dependência entre contextos é permitida.
