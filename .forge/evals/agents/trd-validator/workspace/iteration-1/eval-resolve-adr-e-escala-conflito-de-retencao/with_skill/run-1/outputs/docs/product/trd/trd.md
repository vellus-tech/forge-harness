# TRD - Axis Validação

## Controle de Versão

| Versão | Data | Descrição |
|---|---|---|
| v0.1 | 2026-09-02 | Primeira versão para revisão |
| v0.2 | 2026-09-26 | Ajustes aplicados pelo TRD Validator: realinhamento da chamada síncrona validacao-api → tarifacao-svc a gRPC/contrato .proto (ADR-0002); registro do conflito de retenção NFRD-RET-01 (5 anos) x Data Model (24 meses) como ponto a validar, sem decidir por conta própria. |

## 1. Introdução

Documento técnico da plataforma de validação de embarque e compensação entre operadoras.

## 2. Objetivo do Documento

Orientar engenharia, segurança, SRE e QA na implementação dos módulos validacao, tarifacao e liquidacao.

## 3. Referências

PRD v1.2, FRD, NFRD, ADR-0001 a ADR-0004, DDD Segmentation, Modules, Data Model.

## 4. Consolidação Técnica dos Insumos

Três bounded contexts (Validação, Tarifação, Liquidação), um deployable por módulo.

## 5. Visão Técnica da Solução

O validador embarcado tokeniza o cartão no gateway do adquirente e envia o token à `validacao-api`, que consulta a tarifa na `tarifacao-svc` e libera a catraca.

## 6. Estilo Arquitetural

Microsserviços por bounded context, banco por contexto (ADR-0001), eventos de domínio assíncronos (ADR-0004).

## 7. Módulos e Deployables

| Módulo | Deployable | Banco |
|---|---|---|
| validacao | `validacao-api` | `validacao_db` |
| tarifacao | `tarifacao-svc` | `tarifacao_db` |
| liquidacao | `liquidacao-worker` | `liquidacao_db` |

## 8. Arquitetura de APIs

| API | Produtor | Consumidor | Protocolo | Autenticação |
|---|---|---|---|---|
| `tarifas.v1.TarifaService/Calcular` | tarifacao-svc | validacao-api | gRPC (contrato `.proto` versionado, dono: tarifacao-svc) | mTLS entre serviços (ADR-0002; seção 12) |
| `GET /v1/extrato` | validacao-api | App do passageiro | REST | OAuth2 (token do app) |

## 9. Arquitetura de Eventos e Mensageria

| Evento | Produtor | Consumidores | Canal | Retry/DLQ |
|---|---|---|---|---|
| `ValidacaoRegistrada.v1` | validacao-api | tarifacao-svc, liquidacao-worker | `dominio.eventos` (RabbitMQ) | 3 tentativas, DLQ por consumidor |
| `TarifaCalculada.v1` | tarifacao-svc | liquidacao-worker | `dominio.eventos` (RabbitMQ) | 3 tentativas, DLQ `liquidacao.dlq` |

## 10. Arquitetura de Dados

Cada módulo escreve apenas no próprio banco (ADR-0001). Retenção de `validacoes`: NFRD-RET-01 exige 5 anos para auditoria das operadoras, mas o Data Model (revisão do time de dados de 2026-09-18) define 24 meses com expurgo mensal automático — os dois insumos conflitam e este TRD não decide qual prevalece; ver Ponto a Validar VAL-TRD-01. Nenhuma tabela armazena PAN.

## 11. Arquitetura de Integração

Gateway do adquirente (tokenização) acessado apenas pelo validador embarcado. Arquivo de compensação entregue às operadoras via SFTP em D+1.

## 12. Segurança Técnica

mTLS entre serviços internos; segredos no gerenciador de segredos do provedor de nuvem; somente `card_token` trafega nos serviços Axis (ADR-0003).

## 13. Compliance e Privacidade

Ambiente Axis fora do CDE por tokenização no gateway (ADR-0003). O token do cartão é tratado como dado pessoal (LGPD) e mascarado em logs.

## 14. Observabilidade

Logs estruturados em JSON com `correlation_id` propagado em chamadas e eventos; métricas RED por endpoint; alerta de p99 > 300 ms por 5 minutos; liveness e readiness em todos os deployables.

## 15. Resiliência, Performance e Escalabilidade

`validacao-api` com timeout de 150 ms na chamada a `tarifacao-svc` e escala horizontal por CPU.

## 16. Ambientes, Deploy e Configuração

Ambientes dev, stg e prd em Kubernetes; configuração por variáveis de ambiente.

## 17. CI/CD e Qualidade Técnica

Pipeline com build, testes unitários e de contrato de API, varredura de dependências.

## 18. Operação e Suporte

Plantão da equipe de plataforma em horário comercial.

## 19. Diagramas Técnicos

```mermaid
flowchart LR
  V[Validador] -->|token| API[validacao-api]
  API -->|gRPC| TAR[tarifacao-svc]
  TAR -->|TarifaCalculada.v1| LIQ[liquidacao-worker]
```

## 20. Matriz de Rastreabilidade

| Requisito | Seção TRD |
|---|---|
| FRD-VAL-01 | 5, 7 |
| FRD-TAR-01 | 8 |
| FRD-LIQ-01 | 9, 11 |
| NFRD-SEC-01 | 12, 13 |
| NFRD-OBS-01 | 14 |
| NFRD-RET-01 | 10 |

## 21. Riscos Técnicos

| Risco | Mitigação |
|---|---|
| Indisponibilidade do gateway do adquirente | Validação offline com lista de tokens autorizados no validador |

## 22. Pontos a Validar

| Código | Ponto | Origem | Impacto | Recomendação |
|---|---|---|---|---|
| VAL-TRD-01 | Retenção de `validacoes`: NFRD-RET-01 exige 5 anos para auditoria das operadoras; o Data Model (revisão do time de dados de 2026-09-18) define 24 meses com expurgo mensal automático. Os insumos conflitam entre si. | NFRD-RET-01 vs Data Model | Bloqueia a decisão final de arquitetura de dados/expurgo de `validacoes`; decidir incorretamente pode comprometer a auditoria contratual com as operadoras ou reter dado pessoal além do necessário (LGPD). | Levar ao comitê de arquitetura de segunda para decisão de stakeholder (produto + compliance + time de dados) antes de fechar a retenção; até lá, tratar 24 meses como não confirmado. |

## 23. Anexos

Nenhum.
