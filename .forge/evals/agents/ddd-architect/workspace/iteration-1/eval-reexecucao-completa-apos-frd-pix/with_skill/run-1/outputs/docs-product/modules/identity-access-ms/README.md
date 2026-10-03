# Module - Identity Access MS

## 1. Objetivo
Autenticar o passageiro por CPF/senha, com MFA opcional.

## 2. Bounded Context Relacionado
- Bounded Context: Identity Access

## 3. Capabilities Atendidas
| Capability | Descrição |
|---|---|
| Autenticar passageiro | FR-09 |

## 4. Responsabilidades
- Validar CPF/senha e, quando habilitado, o segundo fator.

## 5. Componentes Técnicos
| Componente | Tipo | Descrição |
|---|---|---|
| AuthenticatePassengerUseCase | Application Service | Orquestra login e MFA |
| PassengerCredentialRepository | Repository | Persiste `PassengerCredential` |

## 6. APIs
| Método | Endpoint | Descrição |
|---|---|---|
| POST | /auth/login | Login por CPF/senha |
| POST | /auth/mfa/verify | Verificação de segundo fator |

## 7. Eventos
| Evento | Publica/Consome | Descrição |
|---|---|---|
| PassengerAuthenticated | Publica | Login concluído |

## 8. Dados Próprios
| Entidade/Tabela/Collection | Finalidade |
|---|---|
| passenger_credentials | Credenciais e estado de MFA |

## 9. Deployable Candidato
| Deployable | Justificativa |
|---|---|
| identity-access-ms | Generic Subdomain — candidato natural a substituição por IdP de mercado; isolado como deployable próprio para facilitar essa troca futura |

## 10. Observações
- Nenhuma mudança nesta execução (v1.1) — módulo inalterado pelo FRD v1.3.
