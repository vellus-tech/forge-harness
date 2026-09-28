# Bounded Context Canvas - Card & Identity

## 1. Objetivo
Gerir o ciclo de vida do cartão (emissão, ativação, bloqueio) e a autenticação do passageiro no app.

## 2. Classificação DDD
- Tipo: Supporting Subdomain
- Justificativa: necessário ao produto, mas segue padrões relativamente estabelecidos; não é o diferencial competitivo.

## 3. Responsabilidades
- Emitir e ativar cartões físicos/virtuais.
- Processar bloqueio de cartão (passageiro ou gestor).
- Autenticar passageiro (CPF + senha, MFA opcional).

## 4. Fora do Escopo
- Saldo e recarga (Wallet & Recharge).
- Decisão de embarque (Fare & Boarding, que apenas consome a projeção de bloqueio).

## 5. Linguagem Ubíqua
| Termo | Definição | Observações |
|---|---|---|
| Card | Cartão físico ou virtual associado a um passageiro | — |
| Block List | Lista de cartões bloqueados | Propagada por sincronização, não em tempo real |

## 6. Atores e Sistemas Relacionados
| Ator/Sistema | Relação com o contexto |
|---|---|
| Passageiro | Solicita bloqueio, se autentica |
| Gestor do consórcio | Pode bloquear cartão administrativamente |

## 7. Agregados e Entidades
| Tipo | Nome | Descrição | Dono |
|---|---|---|---|
| Aggregate | Card | Cartão e seu estado de bloqueio | Card & Identity |
| Aggregate | Passenger | Identidade e credenciais do passageiro | Card & Identity |

## 8. Comandos
| Comando | Descrição | Ator/Sistema origem |
|---|---|---|
| BloquearCartao | Bloqueia um cartão | Passageiro/Gestor |
| AutenticarPassageiro | Autentica login | Passageiro |

## 9. Eventos de Domínio
| Evento | Quando ocorre | Consumidores |
|---|---|---|
| CartaoBloqueado | Cartão entra na lista de bloqueio | Fare & Boarding (projeção de bloqueio) |
| PassageiroAutenticado | Login validado | — |

## 10. APIs Expostas
| API | Método | Finalidade |
|---|---|---|
| POST /cards/{id}/block | POST | Bloquear cartão |
| POST /auth/login | POST | Autenticar passageiro |
| GET /cards/block-list-projection | GET | Projeção de bloqueio consumida por Fare & Boarding |

## 11. Integrações
| Contexto/Sistema | Tipo de relação | Padrão DDD |
|---|---|---|
| Fare & Boarding | Publica projeção de lista de bloqueio | Open Host Service / Published Language |

## 12. Dados Próprios
| Entidade/Tabela/Collection | Finalidade | Retenção |
|---|---|---|
| cards | Cartões e estado de bloqueio | Enquanto o cartão existir |
| passengers | Identidade e credenciais | Conforme política de conta ativa (não especificada nos insumos) |

## 13. Requisitos Não Funcionais Específicos
| Categoria | Requisito |
|---|---|
| Segurança | Credenciais e MFA (FR-09) |
| Performance | — |
| Observabilidade | — |
| Disponibilidade | — |
| Compliance | — |

## 14. Decisões Arquiteturais Relacionadas
| ADR | Decisão |
|---|---|
| — | Nenhum ADR formal ainda |

## 15. Riscos e Pontos de Atenção
- Prazo de propagação de bloqueio até o validador não está definido (ver Ponto a Validar em Fare & Boarding).
