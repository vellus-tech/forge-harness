# Bounded Context Canvas - Fare Validation

## 1. Objetivo
Decidir e registrar embarques, aplicando saldo, bloqueio e integração temporal, inclusive offline.

## 2. Classificação DDD
- Tipo: Core Domain
- Justificativa: linguagem, regras e ciclo de vida próprios (decisão de embarque em até 300 ms, inclusive offline); diferencia o produto.

## 3. Responsabilidades
- Decidir se um embarque é aprovado (saldo suficiente e cartão não bloqueado).
- Debitar a tarifa vigente da linha.
- Aplicar o desconto de integração temporal (60 minutos, 50%) entre embarques do mesmo cartão.
- Operar offline até 5.000 embarques e sincronizar em lote.

## 4. Fora do Escopo
- Gerir saldo e recarga do cartão (pertence a Card Wallet).
- Apurar o repasse financeiro às operadoras (pertence a Operator Clearing).
- Autenticar o passageiro (pertence a Identity Access).

## 5. Linguagem Ubíqua
| Termo | Definição | Observações |
|---|---|---|
| Embarque | Ato de "validação" no validador que debita a tarifa | Ver `docs/product/glossary/ubiquitous-language.md` |
| Integração temporal | Desconto de 50% na segunda viagem em até 60 minutos | |

## 6. Atores e Sistemas Relacionados
| Ator/Sistema | Relação com o contexto |
|---|---|
| Passageiro | Embarca com o cartão |
| Validador (dispositivo físico) | Executa a decisão de embarque, inclusive offline |

## 7. Agregados e Entidades
| Tipo | Nome | Descrição | Dono |
|---|---|---|---|
| Aggregate | Boarding | Representa a decisão de embarque e seu resultado | Fare Validation |
| Value Object | FareAmount | Valor monetário da tarifa aplicada | Fare Validation |

## 8. Comandos
| Comando | Descrição | Ator/Sistema origem |
|---|---|---|
| ValidateBoarding | Decide se o embarque é aprovado | Validador |

## 9. Eventos de Domínio
| Evento | Quando ocorre | Consumidores |
|---|---|---|
| BoardingApproved | Embarque aprovado e tarifa debitada | Card Wallet (débito), Operator Clearing |
| BoardingDenied | Embarque negado por saldo ou bloqueio | — |
| FareIntegrationApplied | Desconto de integração aplicado na segunda viagem | Operator Clearing |

## 10. APIs Expostas
| API | Método | Finalidade |
|---|---|---|
| POST | /boardings | Registrar decisão de embarque (sincronização em lote quando offline) |

## 11. Integrações
| Contexto/Sistema | Tipo de relação | Padrão DDD |
|---|---|---|
| Card Wallet | Consulta saldo e debita | Customer/Supplier |
| Operator Clearing | Publica evento de embarque para apuração | Published Language |

## 12. Dados Próprios
| Entidade/Tabela/Collection | Finalidade | Retenção |
|---|---|---|
| boardings | Registro de cada embarque decidido | 5 anos (NFR-04) |

## 13. Requisitos Não Funcionais Específicos
| Categoria | Requisito |
|---|---|
| Segurança | — |
| Performance | Decisão em até 300 ms, inclusive offline (NFR-01) |
| Observabilidade | — |
| Disponibilidade | Deve operar mesmo sem conectividade (até 5.000 embarques offline) |
| Compliance | Retenção de 5 anos (NFR-04) |

## 14. Decisões Arquiteturais Relacionadas
| ADR | Decisão |
|---|---|
| — | Nenhum ADR registrado ainda |

## 15. Riscos e Pontos de Atenção
- Limite de 5.000 embarques offline não confirmado pelo fornecedor ValidaBus (VAL-01).
- Bloqueio de cartão só chega ao validador na próxima sincronização — janela de risco entre bloqueio e sincronização.
