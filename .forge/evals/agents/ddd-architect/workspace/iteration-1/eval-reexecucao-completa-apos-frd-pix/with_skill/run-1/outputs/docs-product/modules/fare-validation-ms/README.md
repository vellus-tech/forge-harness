# Module - Fare Validation MS

## 1. Objetivo
Decidir embarques (inclusive offline) e aplicar a integração temporal.

## 2. Bounded Context Relacionado
- Bounded Context: Fare Validation

## 3. Capabilities Atendidas
| Capability | Descrição |
|---|---|
| Decidir embarque | Aprovar/negar embarque com base em saldo e bloqueio |
| Aplicar integração temporal | Calcular desconto de 50% na segunda viagem em 60 minutos |

## 4. Responsabilidades
- Validar e registrar embarque em até 300 ms, inclusive offline.
- Sincronizar lote de até 5.000 embarques offline.

## 5. Componentes Técnicos
| Componente | Tipo | Descrição |
|---|---|---|
| ValidateBoardingUseCase | Application Service | Orquestra a decisão de embarque |
| ApplyFareIntegrationUseCase | Domain Service | Calcula o desconto de integração |
| BoardingRepository | Repository | Persiste `Boarding` |
| CardWalletClient | Adapter | Consulta saldo em Card Wallet |

## 6. APIs
| Método | Endpoint | Descrição |
|---|---|---|
| POST | /boardings | Registrar decisão de embarque |

## 7. Eventos
| Evento | Publica/Consome | Descrição |
|---|---|---|
| BoardingApproved | Publica | Embarque aprovado |
| FareIntegrationApplied | Publica | Desconto de integração aplicado |

## 8. Dados Próprios
| Entidade/Tabela/Collection | Finalidade |
|---|---|
| boardings | Registro de cada embarque |

## 9. Deployable Candidato
| Deployable | Justificativa |
|---|---|
| fare-validation-ms | Core Domain com requisito de latência (300 ms) e operação offline — ciclo próprio |

## 10. Observações
- Nenhuma mudança nesta execução (v1.1) — módulo inalterado pelo FRD v1.3.
