# Module - Consortium Backoffice Web

## 1. Objetivo
Interface administrativa do gestor do consórcio para bloqueio de cartões e acompanhamento do clearing.

## 2. Bounded Context Relacionado
- Transversal — BFF/frontend que consome Passenger Wallet e Settlement. Não possui bounded context próprio.

## 3. Capabilities Atendidas
| Capability | Descrição |
|---|---|
| CAP-02, CAP-04 | Bloqueio de cartão e acompanhamento de clearing |

## 4. Responsabilidades
- Bloquear/desbloquear cartão (Passenger Wallet).
- Consultar e acompanhar o clearing diário e emitir ajustes (Settlement).

## 5. Componentes Técnicos
| Componente | Tipo | Descrição |
|---|---|---|
| — | — | SPA administrativa; sem lógica de domínio própria |

## 6. APIs
| Método | Endpoint | Descrição |
|---|---|---|
| — | — | Consumidor de /wallets/{cardId}/block e /clearings/* |

## 7. Eventos
| Evento | Publica/Consome | Descrição |
|---|---|---|
| — | — | Não publica nem consome eventos de domínio diretamente |

## 8. Dados Próprios
| Entidade/Tabela/Collection | Finalidade |
|---|---|
| — | Nenhum dado de domínio próprio |

## 9. Deployable Candidato
| Deployable | Justificativa |
|---|---|
| backoffice-web | Interface administrativa consolidada, consumindo múltiplos contextos via BFF/API |

## 10. Observações
- Acoplamento de navegação é o risco conhecido de uma SPA consolidada sobre múltiplos contextos — ver `docs/product/ddd/diagrams` para a fronteira real dos serviços por trás dela.
