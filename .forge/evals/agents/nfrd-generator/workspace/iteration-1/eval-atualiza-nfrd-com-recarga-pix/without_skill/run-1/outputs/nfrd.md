# NFRD - App Cartão Cidade

## Controle de Versão

NFRD Generator - 2026-06-05 - Versão 1.0 gerada a partir do PRD v1.0.
NFRD Generator - 2026-09-26 - Versão 1.1 gerada a partir do PRD v1.1 (seção 7 — recarga via Pix).

## Sumário

## 1. Introdução

Requisitos não funcionais do app Cartão Cidade (consulta de saldo e extrato, e recarga via Pix a partir da v1.1).

## 2. Objetivo do Documento

Detalhar os atributos de qualidade derivados do PRD v1.1.

## 3. Referências

- docs/product/prd/prd.md (v1.1)
- docs/product/adr/0002-tracing-com-opentelemetry-e-correlation-id.md

## 4. Visão Geral dos Atributos de Qualidade

Foco em latência de consulta e de crédito da recarga, disponibilidade, privacidade e, a partir da v1.1, segurança e resiliência da integração com o PSP parceiro (webhook de pagamento Pix), além de retenção de comprovantes e auditoria de crédito.

## 5. Escopo Não Funcional

Consulta de saldo e extrato; recarga via Pix, incluindo geração de QR Code dinâmico, recepção do webhook de confirmação do PSP e crédito no cartão.

## 6. Fora de Escopo

Meios de recarga diferentes de Pix (ex.: cartão de crédito, boleto).

## 7. Decisão por Categoria

| Categoria | Aplicável? | Justificativa (quando não aplicável) | NFRs |
|---|---|---|---|
| PERF | Sim | | NFR-PERF-01, NFR-PERF-02 |
| DISP | Sim | | NFR-DISP-01 |
| ESC | Não | Pico de 15 recargas/s (dia 5) atendido pela capacidade nominal já dimensionada para 120 consultas/s | |
| RES | Sim (v1.1) | | NFR-RES-01 |
| SEG | Sim | | NFR-SEG-01, NFR-SEG-02 |
| PRIV | Sim | | NFR-PRIV-01 |
| COMP | Sim (v1.1) | | NFR-COMP-01 |
| OBS | Sim | | NFR-OBS-01 |
| AUD | Sim (v1.1) | | NFR-AUD-01 |
| INT | Sim (v1.1) | | NFR-INT-01 |
| USA | Não | Fora do escopo deste ciclo | |
| MAN | Não | Coberto por rules de testing | |
| POR | Não | Ambiente único | |
| OPS | Não | Sem operação própria de dados adicional além do já coberto por AUD/COMP nesta versão | |

## 8. Detalhamento dos Requisitos Não Funcionais

### NFR-PERF-01 - Latência de consulta de saldo

| Campo | Conteúdo |
|---|---|
| **Categoria** | Performance |
| **Descrição** | Tempo de resposta da API de saldo |
| **Meta** | p95 ≤ 800 ms em 120 RPS |
| **Método de medição** | Teste de carga k6 pré-release e histograma em produção |
| **Fonte de dados** | http_request_duration_seconds (Prometheus) |
| **Escopo** | GET /saldo |
| **Prioridade** | Alta |
| **Origem** | PRD KPI-01 |
| **Critérios de aceite** | p95 ≤ 800 ms por 15 min contínuos a 120 RPS |
| **Dependência arquitetural** | — |

### NFR-PERF-02 - Latência de crédito da recarga Pix (v1.1)

| Campo | Conteúdo |
|---|---|
| **Categoria** | Performance |
| **Descrição** | Tempo entre a confirmação de pagamento pelo PSP (recebimento do webhook) e o crédito do valor no saldo do cartão |
| **Meta** | p95 ≤ 10 s, medido a partir de 15 recargas/s (pico do dia 5) |
| **Método de medição** | Teste de carga do endpoint de webhook + histograma em produção (timestamp de recebimento do webhook até timestamp de crédito) |
| **Fonte de dados** | Métrica pix_credito_latencia_segundos (Prometheus) |
| **Escopo** | Webhook de confirmação do PSP → crédito no cartão |
| **Prioridade** | Alta |
| **Origem** | PRD KPI-02 |
| **Critérios de aceite** | p95 ≤ 10 s por 15 min contínuos a 15 recargas/s |
| **Dependência arquitetural** | — |

### NFR-DISP-01 - Disponibilidade do backend

| Campo | Conteúdo |
|---|---|
| **Categoria** | Disponibilidade |
| **Descrição** | Disponibilidade mensal do backend |
| **Meta** | ≥ 99,5% mensal |
| **Método de medição** | Probe sintético a cada 1 min |
| **Fonte de dados** | Blackbox exporter |
| **Escopo** | APIs públicas do app, incluindo endpoint de recebimento do webhook Pix |
| **Prioridade** | Alta |
| **Origem** | PRD R-02 |
| **Critérios de aceite** | Relatório mensal ≥ 99,5% |
| **Dependência arquitetural** | — |

### NFR-RES-01 - Idempotência do crédito de recarga Pix (v1.1)

| Campo | Conteúdo |
|---|---|
| **Categoria** | Resiliência |
| **Descrição** | O recebimento repetido da mesma notificação de pagamento do PSP não pode gerar crédito duplicado no cartão |
| **Meta** | 0 créditos duplicados para uma mesma transação Pix (condição binária) |
| **Método de medição** | Teste automatizado que reenvia o mesmo webhook N vezes e verifica saldo creditado uma única vez |
| **Fonte de dados** | Relatório do teste de idempotência (CI) + reconciliação diária com o extrato do PSP |
| **Escopo** | Endpoint de recebimento do webhook do PSP |
| **Prioridade** | Alta |
| **Origem** | PRD R-04 |
| **Critérios de aceite** | Reenvio de até 5 notificações idênticas resulta em exatamente 1 crédito |
| **Dependência arquitetural** | — |

### NFR-SEG-01 - Autenticação do passageiro

| Campo | Conteúdo |
|---|---|
| **Categoria** | Segurança |
| **Descrição** | Todas as APIs exigem JWT válido do passageiro |
| **Meta** | 100% das rotas exceto /health exigem JWT (condição binária) |
| **Método de medição** | Teste automatizado de rotas no CI |
| **Fonte de dados** | Relatório do teste de rotas |
| **Escopo** | APIs públicas |
| **Prioridade** | Alta |
| **Origem** | Inferência Não Funcional |
| **Critérios de aceite** | Nenhuma rota sem autenticação além de /health |
| **Dependência arquitetural** | — |

### NFR-SEG-02 - mTLS no webhook do PSP (v1.1)

| Campo | Conteúdo |
|---|---|
| **Categoria** | Segurança |
| **Descrição** | O endpoint que recebe a notificação de pagamento do PSP exige autenticação mútua por certificado (mTLS) emitido pelo PSP |
| **Meta** | 100% das chamadas ao endpoint de webhook autenticadas por mTLS; requisições sem certificado válido rejeitadas (condição binária) |
| **Método de medição** | Teste automatizado no CI com certificado válido, inválido e ausente |
| **Fonte de dados** | Relatório de teste de rotas + logs de rejeição do proxy/gateway |
| **Escopo** | Endpoint de webhook do PSP |
| **Prioridade** | Alta |
| **Origem** | PRD R-05 |
| **Critérios de aceite** | Chamada sem certificado do PSP ou com certificado inválido é rejeitada com 4xx antes de qualquer processamento de negócio |
| **Dependência arquitetural** | Exige rotação e validação de certificado do PSP no gateway/proxy; ponto a validar com o time de pagamentos antes do início do design (quarta-feira) |

### NFR-PRIV-01 - Extrato restrito ao titular

| Campo | Conteúdo |
|---|---|
| **Categoria** | Privacidade |
| **Descrição** | Extrato só retorna dados do cartão do titular autenticado |
| **Meta** | 0 respostas com dados de outro titular (condição binária) |
| **Método de medição** | Teste de autorização no CI |
| **Fonte de dados** | Relatório de testes |
| **Escopo** | GET /extrato |
| **Prioridade** | Alta |
| **Origem** | PRD R-01 |
| **Critérios de aceite** | Teste IDOR passa |
| **Dependência arquitetural** | — |

### NFR-COMP-01 - Retenção de comprovantes de recarga (v1.1)

| Campo | Conteúdo |
|---|---|
| **Categoria** | Compliance |
| **Descrição** | Comprovantes de recarga via Pix devem ser retidos pelo prazo exigido pelo contrato de concessão |
| **Meta** | Retenção de 5 anos, sem exclusão ou perda de comprovante nesse período (condição binária) |
| **Método de medição** | Auditoria trimestral de amostragem dos comprovantes armazenados vs. transações registradas |
| **Fonte de dados** | Repositório de comprovantes + log de transações Pix |
| **Escopo** | Comprovantes de todas as recargas via Pix |
| **Prioridade** | Alta |
| **Origem** | PRD R-03 |
| **Critérios de aceite** | Amostra trimestral sem comprovante ausente dentro da janela de 5 anos |
| **Dependência arquitetural** | — |

### NFR-OBS-01 - Tracing distribuído com correlationId

| Campo | Conteúdo |
|---|---|
| **Categoria** | Observabilidade |
| **Descrição** | Toda requisição propaga correlationId e gera trace, incluindo o recebimento do webhook do PSP |
| **Meta** | 100% das requisições com trace_id nos logs |
| **Método de medição** | Consulta de amostragem no Loki |
| **Fonte de dados** | Logs estruturados |
| **Escopo** | Todos os serviços, incluindo o endpoint de webhook Pix |
| **Prioridade** | Média |
| **Origem** | Inferência Não Funcional |
| **Critérios de aceite** | Amostra diária sem log sem trace_id |
| **Dependência arquitetural** | [ADR-0002 — `tracing-com-opentelemetry-e-correlation-id`](../adr/0002-tracing-com-opentelemetry-e-correlation-id.md) (a decisão já cobre chamadas a parceiros externos e webhooks recebidos, aplicável ao webhook do PSP) |

### NFR-AUD-01 - Trilha de auditoria do crédito de recarga (v1.1)

| Campo | Conteúdo |
|---|---|
| **Categoria** | Auditabilidade |
| **Descrição** | Todo crédito de saldo originado por recarga Pix gera registro auditável com identificador da transação do PSP, valor, timestamp e resultado (creditado/rejeitado/duplicado) |
| **Meta** | 100% dos créditos de recarga com registro de auditoria correspondente (condição binária) |
| **Método de medição** | Reconciliação diária automatizada entre registros de auditoria e notificações do PSP |
| **Fonte de dados** | Log de auditoria de crédito (armazenamento append-only) |
| **Escopo** | Fluxo de crédito de recarga Pix (webhook → crédito no cartão) |
| **Prioridade** | Alta |
| **Origem** | Inferência Não Funcional (decorre de PRD R-03 e R-04 — retenção e não duplicação exigem rastreabilidade do crédito) |
| **Critérios de aceite** | Reconciliação diária sem divergência entre notificações do PSP e registros de auditoria |
| **Dependência arquitetural** | — |

### NFR-INT-01 - Integração resiliente com o PSP (v1.1)

| Campo | Conteúdo |
|---|---|
| **Categoria** | Integração |
| **Descrição** | A integração com o PSP parceiro (geração de QR Code dinâmico e recepção do webhook de confirmação) deve tolerar indisponibilidade e lentidão do PSP sem impacto no restante do app |
| **Meta** | Timeout e circuit breaker configurados nas chamadas ao PSP; indisponibilidade do PSP não deve impactar a disponibilidade de consulta de saldo/extrato (condição binária, verificada por teste de falha) |
| **Método de medição** | Teste de injeção de falha (chaos) simulando PSP lento/indisponível, verificando isolamento do impacto |
| **Fonte de dados** | Relatório do teste de injeção de falha |
| **Escopo** | Chamadas de saída ao PSP (geração de QR Code) e endpoint de entrada do webhook |
| **Prioridade** | Alta |
| **Origem** | PRD J-02 |
| **Critérios de aceite** | Com PSP indisponível, consulta de saldo/extrato mantém p95 ≤ 800 ms; requisições de geração de QR Code falham de forma controlada (erro tratado, sem exceção não tratada) |
| **Dependência arquitetural** | Ponto a validar com o time de pagamentos: contrato de timeout/retry do PSP ainda não definido — necessário antes do início do design (quarta-feira) |

## 9. Restrições Técnicas Não Funcionais

- Dados residem em região Brasil (Inferência Não Funcional).
- O endpoint de webhook do PSP exige mTLS com o certificado do PSP (PRD R-05) — implica gateway/proxy com suporte a validação de certificado de cliente.

## 10. Matriz de Rastreabilidade PRD → NFRD

| Item do PRD | NFRs relacionados | Cobertura |
|---|---|---|
| KPI-01 | NFR-PERF-01 | Total |
| KPI-02 | NFR-PERF-02 | Total |
| R-01 | NFR-PRIV-01 | Total |
| R-02 | NFR-DISP-01 | Total |
| R-03 | NFR-COMP-01, NFR-AUD-01 | Total |
| R-04 | NFR-RES-01, NFR-AUD-01 | Total |
| R-05 | NFR-SEG-02 | Total |
| J-02 | NFR-INT-01 | Total |

## 11. Critérios de Validação Não Funcional

Teste de carga pré-release (consulta e crédito de recarga); testes de autorização no CI; teste de idempotência de webhook; teste de mTLS (certificado válido/inválido/ausente); teste de injeção de falha do PSP; reconciliação diária de auditoria.

## 12. Dependências

ADR-0002. Contrato técnico do PSP (formato do webhook, certificado mTLS, política de retry) — a confirmar com o time de pagamentos antes do início do design.

## 13. Premissas

- O PSP parceiro está definido e disponibiliza ambiente de homologação com certificado mTLS de teste.
- O formato exato do payload do webhook do PSP será detalhado no design técnico.

## 14. Pontos a Validar

- Rotação de certificado mTLS do PSP (owner: time de pagamentos) — necessário antes do início do design na quarta-feira.
- Contrato de timeout/retry nas chamadas ao PSP (owner: time de pagamentos) — necessário antes do início do design na quarta-feira.

## 15. Anexos

Nenhum.
