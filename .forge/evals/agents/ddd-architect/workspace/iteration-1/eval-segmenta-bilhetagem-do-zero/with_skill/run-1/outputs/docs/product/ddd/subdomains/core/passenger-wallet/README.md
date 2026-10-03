# Passenger Wallet

## 1. Classificação
- Tipo: Core Domain

## 2. Descrição
Mantém o saldo autoritativo e a lista de bloqueio de cada passageiro. Recebe crédito de Recharge, reconcilia o débito provisório aplicado offline por Fare Collection e publica a fotografia (snapshot) de saldo/blocklist consumida pelo validador embarcado.

## 3. Justificativa da Classificação
O saldo pré-pago é o ativo financeiro central do modelo de negócio. A conciliação entre o débito local (offline, no validador) e o débito autoritativo (no backend) é uma regra de negócio própria, de alto risco financeiro, que nenhum componente genérico resolve.

## 4. Capacidades Relacionadas
| Código | Capacidade | Descrição |
|---|---|---|
| CAP-02 | Passenger Wallet | Manter saldo autoritativo e blocklist do passageiro |

## 5. Eventos de Negócio Relacionados
| Evento | Descrição |
|---|---|
| BalanceCredited | Saldo creditado após recarga aprovada |
| BalanceDebited | Débito reconciliado a partir de um FareCharged |
| CardBlocked | Cartão bloqueado por solicitação do passageiro ou do gestor |
| BalanceLow | Saldo caiu abaixo de 2 tarifas |
| BlocklistSnapshotPublished | Fotografia de blocklist/saldo publicada para consumo offline |

## 6. Regras de Negócio Relevantes
| Regra | Descrição |
|---|---|
| RULE-05 | Bloqueio de cartão só propaga na próxima sincronização do validador |
| RULE-08 | Push de saldo baixo dispara quando saldo < 2 tarifas |
| RULE-10 | Registros retidos por 5 anos |

## 7. Bounded Contexts Relacionados
| Bounded Context | Relação |
|---|---|
| Passenger Wallet | Contexto 1:1 com o subdomínio |

## 8. Pontos a Validar
- VAL-01 — política de negócio para a janela de saldo transitório negativo (permitir até 1 tarifa negativa? bloquear preventivamente?)
