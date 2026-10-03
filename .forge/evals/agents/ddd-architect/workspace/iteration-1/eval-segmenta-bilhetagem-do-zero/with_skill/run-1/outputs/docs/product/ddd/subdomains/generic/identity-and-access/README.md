# Identity and Access

## 1. Classificação
- Tipo: Generic Subdomain

## 2. Descrição
Autentica o passageiro no app por CPF e senha, com MFA opcional.

## 3. Justificativa da Classificação
Login com CPF/senha e MFA é uma capacidade comum a praticamente qualquer aplicação com conta de usuário — não diferencia o produto e é substituível por um provedor de identidade de mercado.

## 4. Capacidades Relacionadas
| Código | Capacidade | Descrição |
|---|---|---|
| CAP-05 | Identity and Access | Autenticar o passageiro no app |

## 5. Eventos de Negócio Relacionados
| Evento | Descrição |
|---|---|
| PassengerAuthenticated | Passageiro autenticado com sucesso |

## 6. Regras de Negócio Relevantes
| Regra | Descrição |
|---|---|
| — | Nenhuma regra de negócio específica além de MFA opcional (FR-09) |

## 7. Bounded Contexts Relacionados
| Bounded Context | Relação |
|---|---|
| Identity and Access | Contexto 1:1 com o subdomínio |

## 8. Pontos a Validar
- VAL-02 — avaliar compra de IdP (Auth0/Cognito/Keycloak) em vez de construir
