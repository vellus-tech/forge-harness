# Module - Identity API

## 1. Objetivo
Autenticar o passageiro no app.

## 2. Bounded Context Relacionado
- Bounded Context: Identity and Access

## 3. Capabilities Atendidas
| Capability | Descrição |
|---|---|
| CAP-05 | Identity and Access |

## 4. Responsabilidades
- Validar credenciais (CPF/senha).
- Executar MFA quando habilitado.

## 5. Componentes Técnicos
| Componente | Tipo | Descrição |
|---|---|---|
| AuthenticatePassengerUseCase | Application Service | Autentica e emite sessão/token |
| PassengerAccountRepository | Repository | Persistência de credenciais |

## 6. APIs
| Método | Endpoint | Descrição |
|---|---|---|
| POST | /auth/login | Autenticar |
| POST | /auth/mfa/verify | Verificar segundo fator |

## 7. Eventos
| Evento | Publica/Consome | Descrição |
|---|---|---|
| PassengerAuthenticated | Publica | Autenticação bem-sucedida |

## 8. Dados Próprios
| Entidade/Tabela/Collection | Finalidade |
|---|---|
| passenger_accounts | Credenciais e configuração de MFA |

## 9. Deployable Candidato
| Deployable | Justificativa |
|---|---|
| identity-service | Candidato a substituição por IdP de mercado (VAL-02); isolado para facilitar essa troca futura |

## 10. Observações
- Antes de investir em features (ex.: recuperação de senha, SSO), avaliar VAL-02 (buy vs. build).
