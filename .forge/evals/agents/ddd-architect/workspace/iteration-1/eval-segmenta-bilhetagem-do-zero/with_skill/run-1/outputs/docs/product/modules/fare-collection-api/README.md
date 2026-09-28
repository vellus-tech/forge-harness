# Module - Fare Collection API

## 1. Objetivo
Registrar embarques a partir dos lotes sincronizados pelo validador, aplicar a política de tarifa e integração, e expor o histórico de viagens do passageiro.

## 2. Bounded Context Relacionado
- Bounded Context: Fare Collection

## 3. Capabilities Atendidas
| Capability | Descrição |
|---|---|
| CAP-01 | Fare Collection |

## 4. Responsabilidades
- Ingerir lotes já traduzidos pelo ValidaBus Sync Adapter.
- Aplicar RULE-01 e RULE-03 (blocklist/saldo já refletidos no snapshot local; integração tarifária).
- Publicar FareCharged / BoardingRejected.
- Servir o read model de histórico de viagens (30 dias).

## 5. Componentes Técnicos
| Componente | Tipo | Descrição |
|---|---|---|
| RecordBoardingUseCase | Application Service | Orquestra a decisão e persistência de um embarque |
| Boarding | Domain Service | Regras de tarifa e integração temporal |
| BoardingRepository | Repository | Persistência de boardings e tariff_rules |
| BoardingHistoryQuery | Adapter | Read model de histórico para o app |

## 6. APIs
| Método | Endpoint | Descrição |
|---|---|---|
| POST | /boardings/sync-batches | Ingestão do lote traduzido pelo ValidaBus Sync Adapter |
| GET | /boardings/history | Histórico de viagens do passageiro (30 dias) |

## 7. Eventos
| Evento | Publica/Consome | Descrição |
|---|---|---|
| FareCharged | Publica | Embarque aprovado e tarifa debitada |
| BoardingRejected | Publica | Embarque negado |

## 8. Dados Próprios
| Entidade/Tabela/Collection | Finalidade |
|---|---|
| boardings | Registro de embarques |
| tariff_rules | Tarifa vigente por linha |

## 9. Deployable Candidato
| Deployable | Justificativa |
|---|---|
| fare-collection-service | Alta criticidade, ciclo próprio, NFR de latência exclusivo |

## 10. Observações
- Nunca consulta diretamente o banco do Passenger Wallet; consome apenas o BlocklistSnapshot publicado.
