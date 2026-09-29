# TRD - Axis Validação

## Controle de Versão

| Versão | Data | Descrição |
|---|---|---|
| v0.1 | 2026-09-02 | Primeira versão para revisão |
| v0.2 | 2026-09-26 | Ajustes aplicados pelo TRD Validator: adicionada seção 14 (Observabilidade); adicionada seção 22 (Pontos a Validar); incluído evento `ValidacaoRegistrada.v1` na arquitetura de eventos; completadas colunas de idempotência/retenção de DLQ; adicionada retenção de `lotes_compensacao`; referência explícita a PCI DSS 4.0.1; matriz de rastreabilidade e módulos/deployables completados; risco de dependência síncrona registrado |

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

| Módulo | Deployable | Banco | Publica | Consome |
|---|---|---|---|---|
| validacao | `validacao-api` | `validacao_db` | `ValidacaoRegistrada.v1` | - |
| tarifacao | `tarifacao-svc` | `tarifacao_db` | `TarifaCalculada.v1` | `ValidacaoRegistrada.v1` |
| liquidacao | `liquidacao-worker` | `liquidacao_db` | - | `ValidacaoRegistrada.v1`, `TarifaCalculada.v1` |

## 8. Arquitetura de APIs

| API | Produtor | Consumidor | Protocolo | Autenticação |
|---|---|---|---|---|
| `TarifaService.Calcular` v1 | tarifacao-svc | validacao-api | gRPC | mTLS interno |
| `GET /v1/extrato` | validacao-api | App do passageiro | REST | OAuth2 (token do app) |

## 9. Arquitetura de Eventos e Mensageria

| Evento | Produtor | Consumidores | Canal | Retry/DLQ | Retenção DLQ | Idempotência |
|---|---|---|---|---|---|---|
| `ValidacaoRegistrada.v1` | validacao-api | tarifacao-svc, liquidacao-worker | `dominio.eventos` (RabbitMQ, exchange topic — ADR-0004) | DLQ por consumidor | 7 dias (ADR-0004) | Consumidor idempotente por `event_id` (ADR-0004) |
| `TarifaCalculada.v1` | tarifacao-svc | liquidacao-worker | `dominio.eventos` (RabbitMQ, exchange topic — ADR-0004) | 3 tentativas, DLQ `liquidacao.dlq` | 7 dias (ADR-0004) | Consumidor idempotente por `event_id` (ADR-0004) |

> Ponto a Validar: a política de "3 tentativas" para `TarifaCalculada.v1` não está especificada em ADR-0004 (que define apenas DLQ por consumidor e retenção de 7 dias) nem em nenhum outro insumo — confirmar com o time de mensageria se é o padrão adotado para todos os consumidores ou específico deste. Ver VAL-TRD-01.

## 10. Arquitetura de Dados

Cada módulo escreve apenas no próprio banco (ADR-0001). `validacoes` (validacao_db) retida por 5 anos; `tarifas_aplicadas` (tarifacao_db) retida por 5 anos; `lotes_compensacao` (liquidacao_db) retida por 10 anos. Nenhuma tabela armazena PAN; a chave do cartão é `card_token` emitido pelo gateway (ADR-0003).

## 11. Arquitetura de Integração

Gateway do adquirente (tokenização) acessado apenas pelo validador embarcado. Arquivo de compensação entregue às operadoras via SFTP em D+1.

## 12. Segurança Técnica

mTLS entre serviços internos; segredos no gerenciador de segredos do provedor de nuvem; somente `card_token` trafega nos serviços Axis (ADR-0003).

## 13. Compliance e Privacidade

Operação em conformidade com PCI DSS 4.0.1 (restrição do PRD): o PAN nunca é recebido, persistido ou logado pelos serviços Axis (NFRD-SEC-01), e o ambiente Axis fica fora do CDE por tokenização no gateway do adquirente (ADR-0003). O token do cartão (`card_token`) é tratado como dado pessoal (LGPD) e mascarado em logs.

## 14. Observabilidade

Todos os serviços (`validacao-api`, `tarifacao-svc`, `liquidacao-worker`) emitem logs estruturados em JSON com `correlation_id` propagado entre chamadas síncronas (gRPC/REST) e eventos assíncronos (RabbitMQ), conforme NFRD-OBS-01.

Métricas RED (rate, errors, duration) por endpoint, com alerta quando a latência p99 da validação de embarque ultrapassar 300 ms por 5 minutos consecutivos (NFRD-OBS-01, NFRD-PERF-01).

Health checks de liveness e readiness em todos os deployables (`validacao-api`, `tarifacao-svc`, `liquidacao-worker`), conforme NFRD-OBS-02.

> Ponto a Validar: dashboards e runbooks operacionais não estão detalhados nos insumos disponíveis — conteúdo pendente de detalhamento por ausência de insumo suficiente. Ver VAL-TRD-02.

## 15. Resiliência, Performance e Escalabilidade

`validacao-api` com timeout de 150 ms na chamada a `tarifacao-svc` e escala horizontal por CPU, dentro do orçamento de latência total p99 ≤ 300 ms exigido pelo NFRD-PERF-01 para 5.000 validações/min em horário de pico.

## 16. Ambientes, Deploy e Configuração

Ambientes dev, stg e prd em Kubernetes; configuração por variáveis de ambiente.

## 17. CI/CD e Qualidade Técnica

Pipeline com build, testes unitários e de contrato gRPC, varredura de dependências.

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
| PRD-01 | 5, 15 |
| PRD-02 | 9, 11 |
| PRD-03 | 8 |
| FRD-VAL-01 | 5, 7, 9 |
| FRD-TAR-01 | 8 |
| FRD-LIQ-01 | 9, 11 |
| FRD-EXT-01 | 8 |
| NFRD-PERF-01 | 14, 15 |
| NFRD-OBS-01 | 14 |
| NFRD-OBS-02 | 14 |
| NFRD-SEC-01 | 12, 13 |
| NFRD-RET-01 | 10 |
| ADR-0001 | 6, 10 |
| ADR-0002 | 8 |
| ADR-0003 | 12, 13 |
| ADR-0004 | 6, 9 |

## 21. Riscos Técnicos

| Risco | Mitigação |
|---|---|
| Indisponibilidade do gateway do adquirente | Validação offline com lista de tokens autorizados no validador |
| Chamada síncrona `validacao-api` → `tarifacao-svc` no caminho crítico do embarque é ponto único de falha para liberar a catraca | Estratégia de fallback/circuit breaker não definida nos insumos — ver VAL-TRD-03 |

## 22. Pontos a Validar

| Código | Ponto | Origem | Impacto | Recomendação |
|---|---|---|---|---|
| VAL-TRD-01 | Política de retry "3 tentativas" para `TarifaCalculada.v1` não está especificada em ADR-0004 | Seção 9, ADR-0004 | Médio — parâmetro operacional sem fonte confirmada | Confirmar com o time de mensageria se o valor é padrão ou específico deste consumidor; documentar a origem |
| VAL-TRD-02 | Dashboards e runbooks operacionais não detalhados nos insumos | Seção 14, 18 | Médio — afeta prontidão operacional do plantão | Definir com SRE/plataforma antes do início da sprint 14 |
| VAL-TRD-03 | Ausência de estratégia de fallback/circuit breaker para a chamada síncrona `validacao-api` → `tarifacao-svc` no caminho de liberação da catraca | Seção 5, 8, 15 | Alto — indisponibilidade de `tarifacao-svc` pode impedir embarque, ainda que o NFRD-PERF-01 exija p99 ≤ 300 ms | Decidir com arquitetura/produto se há fallback (ex.: tarifa em cache, liberação condicional) antes de iniciar `validacao-api` na sprint 14 |
| VAL-TRD-04 | RBAC/ABAC entre serviços internos não definido além do mTLS | Seção 12 | Médio — autenticação de transporte definida, autorização de operação não | Definir modelo de autorização entre `validacao-api`, `tarifacao-svc` e `liquidacao-worker` |
| VAL-TRD-05 | Padrão de erro e idempotência das APIs síncronas (`TarifaService.Calcular`, `GET /v1/extrato`) não definidos | Seção 8 | Médio — sem padrão, cada serviço pode implementar de forma divergente | Definir contrato de erro comum e, se aplicável, chave de idempotência para `TarifaService.Calcular` |

## 23. Anexos

Nenhum.
