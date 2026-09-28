# Bounded Context Canvas - Identity and Access

## 1. Objetivo
Autenticar o passageiro no app por CPF e senha, com MFA opcional.

## 2. Classificação DDD
- Tipo: Generic Subdomain
- Justificativa: capacidade comum, substituível por provedor de identidade de mercado.

## 3. Responsabilidades
- Gerenciar credenciais do passageiro (CPF/senha).
- Executar autenticação e, quando habilitado, MFA.

## 4. Fora do Escopo
- Qualquer regra de negócio de bilhetagem, saldo ou recarga.

## 5. Linguagem Ubíqua
| Termo | Definição | Observações |
|---|---|---|
| Passenger Account | Credencial de acesso do passageiro ao app | Distinto do Cartão (Card) — a conta é acesso, o cartão é meio de embarque |

## 6. Atores e Sistemas Relacionados
| Ator/Sistema | Relação com o contexto |
|---|---|
| Passageiro | Autentica-se para usar o app |

## 7. Agregados e Entidades
| Tipo | Nome | Descrição | Dono |
|---|---|---|---|
| Aggregate | PassengerAccount | Credencial e estado de MFA do passageiro | Identity and Access |

## 8. Comandos
| Comando | Descrição | Ator/Sistema origem |
|---|---|---|
| Authenticate | Autenticar com CPF/senha (+ MFA opcional) | Passageiro |

## 9. Eventos de Domínio
| Evento | Quando ocorre | Consumidores |
|---|---|---|
| PassengerAuthenticated | Autenticação bem-sucedida | App (emissão de sessão/token) |

## 10. APIs Expostas
| API | Método | Finalidade |
|---|---|---|
| /auth/login | POST | Autenticar passageiro |
| /auth/mfa/verify | POST | Verificar segundo fator, quando habilitado |

## 11. Integrações
| Contexto/Sistema | Tipo de relação | Padrão DDD |
|---|---|---|
| Passenger Wallet | Wallet conforma-se à identidade emitida aqui | Conformist (a partir do ponto de vista do Wallet) |

## 12. Dados Próprios
| Entidade/Tabela/Collection | Finalidade | Retenção |
|---|---|---|
| passenger_accounts | Credenciais e configuração de MFA | Vigência da conta |

## 13. Requisitos Não Funcionais Específicos
| Categoria | Requisito |
|---|---|
| Segurança | Hash de senha com algoritmo forte; MFA opcional |
| Performance | Não especificado nos insumos |
| Observabilidade | Monitorar tentativas de login falhas |
| Disponibilidade | Não especificado nos insumos |
| Compliance | Não especificado além de dados pessoais (CPF) |

## 14. Decisões Arquiteturais Relacionadas
| ADR | Decisão |
|---|---|
| — | Candidato: "ADR — Build vs. buy de Identity and Access" (resolve VAL-02) |

## 15. Riscos e Pontos de Atenção
- Risco: investir modelagem tática além do necessário em um subdomínio genérico (VAL-04).
