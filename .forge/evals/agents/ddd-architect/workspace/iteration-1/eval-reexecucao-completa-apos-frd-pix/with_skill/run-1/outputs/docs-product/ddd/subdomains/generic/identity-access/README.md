# Identity Access

## 1. Classificação
- Tipo: Generic Subdomain

## 2. Descrição
Autenticação do passageiro no app por CPF e senha, com MFA opcional.

## 3. Justificativa da Classificação
Login e MFA são capacidades genéricas resolvidas por qualquer provedor de identidade padrão — não há regra de domínio específica da Tarifa Viva.

## 4. Capacidades Relacionadas
| Código | Capacidade | Descrição |
|---|---|---|
| CAP-06 | Identity Access | Autenticar passageiro com CPF/senha e MFA opcional |

## 5. Eventos de Negócio Relacionados
| Evento | Descrição |
|---|---|
| PassengerAuthenticated | Passageiro autenticou com sucesso no app |

## 6. Regras de Negócio Relevantes
| Regra | Descrição |
|---|---|
| FR-09 | Login no app por CPF e senha, com MFA opcional |

## 7. Bounded Contexts Relacionados
| Bounded Context | Relação |
|---|---|
| Identity Access | Mesmo contexto |

## 8. Pontos a Validar
- Nenhum ponto novo identificado nesta execução (v1.1) — subdomínio inalterado desde v1.0.
