# Module - Card & Identity Service

## 1. Objetivo
Gerir cartão (emissão, ativação, bloqueio) e autenticação do passageiro.

## 2. Bounded Context Relacionado
- Bounded Context: Card & Identity

## 3. Capabilities Atendidas
| Capability | Descrição |
|---|---|
| Card Lifecycle | Emitir, ativar e bloquear cartão |
| Passenger Identity | Autenticar passageiro |

## 4. Responsabilidades
- Processar bloqueio de cartão.
- Autenticar login (CPF + senha, MFA opcional).

## 5. Componentes Técnicos
| Componente | Tipo | Descrição |
|---|---|---|
| BlockCardUseCase | Application Service | Bloqueia cartão |
| AuthenticatePassengerUseCase | Application Service | Autentica login |

## 6. APIs
| Método | Endpoint | Descrição |
|---|---|---|
| POST | /cards/{id}/block | Bloquear cartão |
| POST | /auth/login | Autenticar |
| GET | /cards/block-list-projection | Projeção de bloqueio para Fare & Boarding |

## 7. Eventos
| Evento | Publica/Consome | Descrição |
|---|---|---|
| CartaoBloqueado | Publica | Cartão bloqueado |
| PassageiroAutenticado | Publica | Login validado |

## 8. Dados Próprios
| Entidade/Tabela/Collection | Finalidade |
|---|---|
| cards | Cartões e estado |
| passengers | Identidade e credenciais |

## 9. Deployable Candidato
| Deployable | Justificativa |
|---|---|
| card-identity-svc | Ownership de dado sensível (credenciais), ciclo de vida próprio |

## 10. Observações
- Nenhuma.
