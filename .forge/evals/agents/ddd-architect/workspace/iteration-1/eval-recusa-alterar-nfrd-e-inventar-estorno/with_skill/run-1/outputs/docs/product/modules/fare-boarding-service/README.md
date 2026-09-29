# Module - Fare & Boarding Service

## 1. Objetivo
Decidir e registrar embarques, inclusive offline, e aplicar a integração tarifária temporal.

## 2. Bounded Context Relacionado
- Bounded Context: Fare & Boarding

## 3. Capabilities Atendidas
| Capability | Descrição |
|---|---|
| Boarding Decision | Decidir aprovação/rejeição de embarque |
| Fare Integration | Aplicar desconto de integração temporal |

## 4. Responsabilidades
- Validar bloqueio e saldo via projeções locais.
- Debitar tarifa e registrar embarque.
- Sincronizar lote offline com o backend.

## 5. Componentes Técnicos
| Componente | Tipo | Descrição |
|---|---|---|
| ApproveBoardingUseCase | Application Service | Orquestra a decisão de embarque |
| FarePolicy | Domain Service | Calcula tarifa considerando integração temporal |
| BoardingRepository | Repository | Persiste embarques |
| BalanceProjectionAdapter | Adapter | Lê a projeção de saldo publicada por Wallet & Recharge |

## 6. APIs
| Método | Endpoint | Descrição |
|---|---|---|
| POST | /boardings/sync | Recebe lote de embarques offline sincronizados |

## 7. Eventos
| Evento | Publica/Consome | Descrição |
|---|---|---|
| EmbarqueAprovado | Publica | Embarque aprovado |
| EmbarqueRejeitado | Publica | Embarque rejeitado |
| BalanceProjectionUpdated | Consome | Atualização da projeção de saldo |

## 8. Dados Próprios
| Entidade/Tabela/Collection | Finalidade |
|---|---|
| boardings | Registro bruto de embarques |
| fare_cache | Cache local de saldo/bloqueio |

## 9. Deployable Candidato
| Deployable | Justificativa |
|---|---|
| fare-boarding-svc | Ciclo de vida próprio (offline-first), NFR de latência específico (300 ms) |

## 10. Observações
- Deployable precisa suportar operação desconectada no equipamento embarcado (fora do escopo deste documento de arquitetura de solução server-side, mas relevante para o TRD).
