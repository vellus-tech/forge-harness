# Card & Identity

## 1. Classificação
- Tipo: Supporting Subdomain

## 2. Descrição
Ciclo de vida do cartão (físico/virtual, bloqueio) e autenticação do passageiro (CPF + senha, MFA opcional).

## 3. Justificativa da Classificação
Necessário para o produto operar, mas segue padrões relativamente estabelecidos de gestão de identidade/cartão; não é o diferencial competitivo da Tarifa Viva (diferente de Fare & Boarding e Wallet & Recharge).

## 4. Capacidades Relacionadas
| Código | Capacidade | Descrição |
|---|---|---|
| CAP-05 | Card Lifecycle | Emitir, ativar e bloquear cartão |
| CAP-06 | Passenger Identity | Autenticar passageiro |

## 5. Eventos de Negócio Relacionados
| Evento | Descrição |
|---|---|
| CartaoBloqueado | Cartão entra na lista de bloqueio |
| PassageiroAutenticado | Login validado |

## 6. Regras de Negócio Relevantes
| Regra | Descrição |
|---|---|
| RULE-04 | Bloqueio de cartão só chega ao validador na próxima sincronização |

## 7. Bounded Contexts Relacionados
| Bounded Context | Relação |
|---|---|
| Card & Identity | Implementação direta deste subdomínio |
| Fare & Boarding | Consome projeção de lista de bloqueio |

## 8. Pontos a Validar
- Nenhum ponto adicional identificado nos insumos atuais.
