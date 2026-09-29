# Bounded Context Canvas - Identity Access

## 1. Objetivo
Autenticar o passageiro no app por CPF e senha, com MFA opcional.

## 2. Classificação DDD
- Tipo: Generic Subdomain
- Justificativa: capacidade genérica de identidade, sem regra de domínio específica da Tarifa Viva.

## 3. Responsabilidades
- Validar credenciais (CPF/senha).
- Emitir e validar segundo fator quando MFA estiver habilitado.

## 4. Fora do Escopo
- Qualquer regra de saldo, embarque ou clearing.

## 5. Linguagem Ubíqua
| Termo | Definição | Observações |
|---|---|---|
| MFA | Autenticação multifator (Multi-Factor Authentication) | Sigla expandida na primeira ocorrência |

## 6. Atores e Sistemas Relacionados
| Ator/Sistema | Relação com o contexto |
|---|---|
| Passageiro | Autentica-se no app |

## 7. Agregados e Entidades
| Tipo | Nome | Descrição | Dono |
|---|---|---|---|
| Aggregate | PassengerCredential | Credencial do passageiro e estado de MFA | Identity Access |

## 8. Comandos
| Comando | Descrição | Ator/Sistema origem |
|---|---|---|
| AuthenticatePassenger | Autentica com CPF/senha e, se habilitado, MFA | Passageiro |

## 9. Eventos de Domínio
| Evento | Quando ocorre | Consumidores |
|---|---|---|
| PassengerAuthenticated | Login concluído com sucesso | Card Wallet, Fare Validation (via token de sessão) |

## 10. APIs Expostas
| API | Método | Finalidade |
|---|---|---|
| POST | /auth/login | Autenticar passageiro |
| POST | /auth/mfa/verify | Verificar segundo fator |

## 11. Integrações
| Contexto/Sistema | Tipo de relação | Padrão DDD |
|---|---|---|
| Card Wallet | Fornece identidade autenticada | Open Host Service |

## 12. Dados Próprios
| Entidade/Tabela/Collection | Finalidade | Retenção |
|---|---|---|
| passenger_credentials | Credenciais e estado de MFA | Enquanto a conta estiver ativa |

## 13. Requisitos Não Funcionais Específicos
| Categoria | Requisito |
|---|---|
| Segurança | MFA opcional (FR-09) |
| Performance | — |
| Observabilidade | — |
| Disponibilidade | — |
| Compliance | — |

## 14. Decisões Arquiteturais Relacionadas
| ADR | Decisão |
|---|---|
| — | Nenhum ADR registrado ainda |

## 15. Riscos e Pontos de Atenção
- Nenhum ponto novo identificado nesta execução (v1.1) — contexto inalterado pelo FRD v1.3.
