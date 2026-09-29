# TRD - Axis Validação

## Controle de Versão

| Versão | Data | Descrição |
|---|---|---|
| v0.1 | 2026-09-02 | Primeira versão para revisão |
| v0.2 | 2026-09-26 | Revisão pré-comitê: corrigido protocolo `tarifacao-svc` para gRPC (ADR-0002), adicionada rastreabilidade de FRD-EXT-01 e registrado conflito de retenção NFRD-RET-01 × Data Model como pendência de decisão (não resolvido nesta revisão) |

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
| `TarifasCalculadorService/Calcular` | tarifacao-svc | validacao-api | gRPC, contrato `.proto` versionado (ADR-0002) | mTLS de malha interna |
| `GET /v1/extrato` | validacao-api | App do passageiro | REST | OAuth2 (token do app) |

> **Correção desta revisão:** a v0.1 descrevia a chamada `validacao-api → tarifacao-svc` como
> REST/JSON. Como ambos são serviços internos com chamada síncrona (confirmado em Modules), o
> ADR-0002 exige gRPC com contrato `.proto` versionado, cujo dono é o serviço provedor
> (`tarifacao-svc`). REST fica reservado à borda externa (app do passageiro, operadoras,
> parceiros). Diagrama da seção 19 e Riscos/Resiliência (seção 15) também foram alinhados.

## 9. Arquitetura de Eventos e Mensageria

| Evento | Produtor | Consumidores | Canal | Retry/DLQ |
|---|---|---|---|---|
| `ValidacaoRegistrada.v1` | validacao-api | tarifacao-svc, liquidacao-worker | `dominio.eventos` (RabbitMQ) | 3 tentativas, DLQ por consumidor |
| `TarifaCalculada.v1` | tarifacao-svc | liquidacao-worker | `dominio.eventos` (RabbitMQ) | 3 tentativas, DLQ `liquidacao.dlq` |

## 10. Arquitetura de Dados

Cada módulo escreve apenas no próprio banco (ADR-0001). `validacoes` retida por 24 meses com expurgo mensal automático, conforme Data Model (revisão do time de dados em 2026-09-18). Nenhuma tabela armazena PAN.

> **Conflito não resolvido nesta revisão:** NFRD-RET-01 exige retenção de 5 anos das validações
> de embarque para auditoria das operadoras; o Data Model já implementa expurgo automático em 24
> meses. São fontes de mesma hierarquia (ambas aprovadas) descrevendo comportamentos
> incompatíveis do mesmo dado — não é um erro de redação que se resolva escolhendo um texto. Ver
> seção 22.

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
| NFRD-RET-01 | 10 (conflito aberto — ver seção 22) |
| FRD-EXT-01 | 8 |

## 21. Riscos Técnicos

| Risco | Mitigação |
|---|---|
| Indisponibilidade do gateway do adquirente | Validação offline com lista de tokens autorizados no validador |

## 22. Pontos a Validar

1. **[BLOQUEIO — decisão de negócio/compliance] Conflito de retenção de `validacoes`:**
   NFRD-RET-01 pede 5 anos de retenção para auditoria das operadoras; o Data Model — já
   revisado e aprovado pelo time de dados em 2026-09-18 — implementa expurgo automático em 24
   meses. Esta revisão do TRD **não escolheu um lado**: documentar 5 anos contradiria um Data
   Model já aprovado e em operação; documentar 24 meses (como a v0.1 fazia, silenciosamente)
   descumpre um NFRD sem registro da exceção, expondo a Axis a falha de auditoria de
   compensação entre operadoras sem que ninguém tenha decidido isso conscientemente. É uma
   decisão de produto/compliance — não uma inconsistência editorial — e por isso deve ser levada
   ao comitê de arquitetura de segunda-feira para decisão explícita entre três caminhos: (a)
   estender a retenção do `validacoes` para 5 anos (custo de armazenamento e possível
   remodelagem do expurgo já implementado), (b) reduzir formalmente o NFRD-RET-01 para 24 meses
   com aval de quem responde pela auditoria das operadoras, ou (c) reter os dados agregados
   necessários à auditoria por 5 anos em uma tabela/formato separado enquanto o detalhe
   transacional segue com expurgo em 24 meses. Nenhuma opção foi aplicada ao TRD; a seção 10
   permanece com o comportamento hoje implementado (24 meses) para não descrever um sistema que
   não existe, com a ressalva explícita acima.
2. Confirmar com o time de dados se a retenção de `tarifas_aplicadas` (5 anos) e
   `lotes_compensacao` (10 anos) tem base regulatória documentada, já que o TRD hoje só cita a
   base para `validacoes`.

## 23. Anexos

Nenhum.
