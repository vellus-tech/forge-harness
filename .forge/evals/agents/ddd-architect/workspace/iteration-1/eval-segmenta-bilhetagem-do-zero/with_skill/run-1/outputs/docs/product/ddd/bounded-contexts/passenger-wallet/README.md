# Bounded Context Canvas - Passenger Wallet

## 1. Objetivo
Manter o saldo autoritativo e a lista de bloqueio de cada passageiro, reconciliando os débitos provisórios de Fare Collection e os créditos aprovados por Recharge, e publicando a fotografia de saldo/blocklist consumida offline pelo validador.

## 2. Classificação DDD
- Tipo: Core Domain
- Justificativa: o saldo pré-pago é o ativo financeiro central do modelo de negócio; a conciliação offline/online é regra própria de alto risco.

## 3. Responsabilidades
- Manter o ledger de créditos e débitos do saldo de cada passageiro.
- Aplicar bloqueio/desbloqueio de cartão (RULE-05).
- Reconciliar o débito provisório de `FareCharged` como débito autoritativo.
- Publicar `BlocklistSnapshotPublished` para consumo offline por Fare Collection.
- Disparar `BalanceLow` quando o saldo cruzar o limiar de 2 tarifas (RULE-08).

## 4. Fora do Escopo
- Decidir o embarque em si — isso é do Fare Collection.
- Processar o pagamento da recarga (antifraude, tokenização) — isso é do Recharge.

## 5. Linguagem Ubíqua
| Termo | Definição | Observações |
|---|---|---|
| Balance (Saldo) | Crédito disponível do passageiro | Fonte autoritativa; ver VAL-01 sobre janela offline |
| Wallet (Carteira) | Agregado que representa o saldo e o estado de bloqueio de um cartão | — |
| Blocklist Snapshot | Fotografia periódica de saldo/blocklist publicada para consumo offline | Não é a fonte autoritativa em tempo real, é uma cópia consistente-em-ponto-no-tempo |

## 6. Atores e Sistemas Relacionados
| Ator/Sistema | Relação com o contexto |
|---|---|
| Passageiro | Solicita bloqueio do próprio cartão |
| Gestor do Consórcio | Bloqueia cartão perdido/fraudado |

## 7. Agregados e Entidades
| Tipo | Nome | Descrição | Dono |
|---|---|---|---|
| Aggregate | Wallet | Saldo e estado de bloqueio do cartão de um passageiro | Passenger Wallet |
| Entity | BalanceLedgerEntry | Lançamento individual de crédito ou débito | Passenger Wallet |
| Value Object | Money | Valor monetário em centavos | Passenger Wallet |

## 8. Comandos
| Comando | Descrição | Ator/Sistema origem |
|---|---|---|
| BlockCard | Bloquear cartão perdido/fraudado | Passageiro ou Gestor |
| UnblockCard | Desbloquear cartão | Gestor |
| ReconcileFareCharge | Aplicar débito autoritativo a partir de FareCharged | Fare Collection (evento) |
| CreditBalance | Aplicar crédito a partir de recarga aprovada | Recharge (evento) |

## 9. Eventos de Domínio
| Evento | Quando ocorre | Consumidores |
|---|---|---|
| BalanceCredited | Saldo creditado após recarga aprovada | Notification (indiretamente, via checagem de limiar) |
| BalanceDebited | Débito reconciliado a partir de um FareCharged | Settlement (auditoria) |
| CardBlocked | Cartão bloqueado | Fare Collection (via snapshot) |
| BalanceLow | Saldo abaixo de 2 tarifas | Notification |
| BlocklistSnapshotPublished | Snapshot publicado para consumo offline | Fare Collection |

## 10. APIs Expostas
| API | Método | Finalidade |
|---|---|---|
| /wallets/{cardId}/block | POST | Bloquear cartão |
| /wallets/{cardId}/balance | GET | Consultar saldo |
| /wallets/blocklist-snapshot | GET | Snapshot para o validador (consumido via ACL de Fare Collection) |

## 11. Integrações
| Contexto/Sistema | Tipo de relação | Padrão DDD |
|---|---|---|
| Fare Collection | Consome FareCharged; publica BlocklistSnapshot | Published Language |
| Recharge | Consome RechargeApproved | Customer/Supplier (Wallet é downstream) |
| Identity and Access | Depende da identidade do passageiro | Conformist |

## 12. Dados Próprios
| Entidade/Tabela/Collection | Finalidade | Retenção |
|---|---|---|
| wallets | Saldo corrente e estado de bloqueio por cartão | Vigência corrente |
| balance_ledger_entries | Histórico de créditos e débitos | 5 anos (NFR-04) |
| card_block_list | Lista de cartões bloqueados | Vigência corrente + histórico |

## 13. Requisitos Não Funcionais Específicos
| Categoria | Requisito |
|---|---|
| Segurança | Nenhum dado de cartão de crédito (PAN) é armazenado aqui — apenas saldo e identificador do cartão de transporte |
| Performance | Reconciliação assíncrona; não está no caminho crítico do embarque offline |
| Observabilidade | Monitorar divergência entre saldo local decidido offline e saldo autoritativo reconciliado |
| Disponibilidade | Alta — é a fonte de verdade consultada por Recharge e consumida por Fare Collection |
| Compliance | Retenção de 5 anos (NFR-04) |

## 14. Decisões Arquiteturais Relacionadas
| ADR | Decisão |
|---|---|
| — | Candidato: "ADR — Política de saldo transitório negativo offline" (resolve VAL-01) |

## 15. Riscos e Pontos de Atenção
- Risco: sem política explícita para VAL-01, o saldo pode ficar negativo por período indeterminado entre o embarque offline e a reconciliação.
- Risco: propagação de bloqueio depende do ciclo de sincronização do validador (RULE-05) — janela de exposição conhecida e aceita, mas deve ser monitorada.
