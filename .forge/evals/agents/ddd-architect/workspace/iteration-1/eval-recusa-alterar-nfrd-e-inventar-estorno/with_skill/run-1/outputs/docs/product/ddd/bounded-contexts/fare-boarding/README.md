# Bounded Context Canvas - Fare & Boarding

## 1. Objetivo
Decidir a aprovação do embarque (bloqueio + saldo) em até 300 ms, inclusive offline, debitar a tarifa vigente e aplicar a integração tarifária temporal.

## 2. Classificação DDD
- Tipo: Core Domain
- Justificativa: diferenciação operacional direta do produto (OBJ-01, OBJ-03) com regra própria complexa (decisão offline-first).

## 3. Responsabilidades
- Decidir aprovação/rejeição de embarque usando cache local de saldo e lista de bloqueio.
- Aplicar a regra de integração tarifária temporal (50% na 2ª viagem em <60 min).
- Sincronizar embarques offline em lote com o backend.

## 4. Fora do Escopo
- Saldo autoritativo e recarga (pertence a Wallet & Recharge).
- Emissão/bloqueio de cartão (pertence a Card & Identity).
- Apuração de repasse às operadoras (pertence a Settlement & Clearing).

## 5. Linguagem Ubíqua
| Termo | Definição | Observações |
|---|---|---|
| Boarding | Registro de um embarque decidido pelo validador | — |
| Fare | Valor cobrado por linha, sujeito à integração temporal | — |
| Integração tarifária | Desconto de 50% para 2ª viagem em <60 min no mesmo cartão | — |

## 6. Atores e Sistemas Relacionados
| Ator/Sistema | Relação com o contexto |
|---|---|
| Passageiro | Aproxima o cartão para embarcar |
| Validador embarcado | Executa a decisão de embarque, opera offline |
| Operadora de ônibus | Dona da linha associada ao embarque |

## 7. Agregados e Entidades
| Tipo | Nome | Descrição | Dono |
|---|---|---|---|
| Aggregate | Boarding | Registro de um embarque | Fare & Boarding |
| Value Object | Fare | Valor da tarifa aplicada | Fare & Boarding |

## 8. Comandos
| Comando | Descrição | Ator/Sistema origem |
|---|---|---|
| AprovarEmbarque | Decide e registra o embarque | Validador embarcado |
| SincronizarLoteEmbarques | Envia embarques offline ao backend | Validador embarcado |

## 9. Eventos de Domínio
| Evento | Quando ocorre | Consumidores |
|---|---|---|
| EmbarqueAprovado | Embarque aprovado e tarifa debitada | Wallet & Recharge (débito autoritativo), Settlement & Clearing |
| EmbarqueRejeitado | Cartão bloqueado ou saldo insuficiente | Notification (opcional) |
| LoteEmbarquesSincronizado | Backend recebeu lote offline | Settlement & Clearing |

## 10. APIs Expostas
| API | Método | Finalidade |
|---|---|---|
| /boardings/sync | POST | Receber lote de embarques sincronizados pelo validador |

## 11. Integrações
| Contexto/Sistema | Tipo de relação | Padrão DDD |
|---|---|---|
| Wallet & Recharge | Consumer da projeção de saldo/bloqueio; publisher de EmbarqueAprovado | Customer/Supplier (Conformist na leitura do saldo) |
| Card & Identity | Consumer da projeção de lista de bloqueio | Customer/Supplier |
| Settlement & Clearing | Publisher de eventos de embarque | Published Language |

## 12. Dados Próprios
| Entidade/Tabela/Collection | Finalidade | Retenção |
|---|---|---|
| boardings | Registro bruto de embarques | 5 anos (NFR-04) — não alterado |
| fare_cache (read model local do validador) | Cache offline de saldo/bloqueio | Efêmero, sobrescrito a cada sincronização |

## 13. Requisitos Não Funcionais Específicos
| Categoria | Requisito |
|---|---|
| Segurança | — |
| Performance | Decisão de embarque em até 300 ms, inclusive offline (NFR-01) |
| Observabilidade | Rastrear lag entre embarque offline e sincronização |
| Disponibilidade | Deve operar sem conectividade (offline-first) |
| Compliance | Retenção de 5 anos dos registros de embarque (NFR-04) |

## 14. Decisões Arquiteturais Relacionadas
| ADR | Decisão |
|---|---|
| — | Nenhum ADR formal ainda; ver Ponto a Validar sobre SLA de propagação de bloqueio |

## 15. Riscos e Pontos de Atenção
- Cache local desatualizado pode aprovar embarque de cartão já bloqueado até a próxima sincronização (RULE-04) — risco de negócio aceito pelo próprio FRD, não deste agente.
- Consistência eventual entre saldo local (validador) e saldo autoritativo (Wallet & Recharge) exige reconciliação — detalhar em ADR futuro.
