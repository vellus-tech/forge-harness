# NFRD - App Cartão Cidade

## Controle de Versão

NFRD Generator - 2026-06-05 - Versão 1.0 gerada a partir do PRD v1.0.

## Sumário

## 1. Introdução

Requisitos não funcionais do app Cartão Cidade (consulta de saldo e extrato).

## 2. Objetivo do Documento

Detalhar os atributos de qualidade derivados do PRD v1.0.

## 3. Referências

- docs/product/prd/prd.md (v1.0)
- docs/product/adr/0002-tracing-com-opentelemetry-e-correlation-id.md

## 4. Visão Geral dos Atributos de Qualidade

Foco em latência de consulta, disponibilidade e privacidade.

## 5. Escopo Não Funcional

Consulta de saldo e extrato.

## 6. Fora de Escopo

Recarga (fora do PRD v1.0).

## 7. Decisão por Categoria

| Categoria | Aplicável? | Justificativa (quando não aplicável) | NFRs |
|---|---|---|---|
| PERF | Sim | | NFR-PERF-01 |
| DISP | Sim | | NFR-DISP-01 |
| ESC | Não | Volumetria atendida pela capacidade nominal | |
| RES | Não | Sem integrações externas na v1.0 | |
| SEG | Sim | | NFR-SEG-01 |
| PRIV | Sim | | NFR-PRIV-01 |
| COMP | Não | Sem regulação setorial na v1.0 | |
| OBS | Sim | | NFR-OBS-01 |
| AUD | Não | Sem operação de escrita na v1.0 | |
| INT | Não | Sem integrações externas na v1.0 | |
| USA | Não | Fora do escopo deste ciclo | |
| MAN | Não | Coberto por rules de testing | |
| POR | Não | Ambiente único | |
| OPS | Não | Sem dados transacionais próprios na v1.0 | |

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

### NFR-DISP-01 - Disponibilidade do backend

| Campo | Conteúdo |
|---|---|
| **Categoria** | Disponibilidade |
| **Descrição** | Disponibilidade mensal do backend |
| **Meta** | ≥ 99,5% mensal |
| **Método de medição** | Probe sintético a cada 1 min |
| **Fonte de dados** | Blackbox exporter |
| **Escopo** | APIs públicas do app |
| **Prioridade** | Alta |
| **Origem** | PRD R-02 |
| **Critérios de aceite** | Relatório mensal ≥ 99,5% |
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

### NFR-OBS-01 - Tracing distribuído com correlationId

| Campo | Conteúdo |
|---|---|
| **Categoria** | Observabilidade |
| **Descrição** | Toda requisição propaga correlationId e gera trace |
| **Meta** | 100% das requisições com trace_id nos logs |
| **Método de medição** | Consulta de amostragem no Loki |
| **Fonte de dados** | Logs estruturados |
| **Escopo** | Todos os serviços |
| **Prioridade** | Média |
| **Origem** | Inferência Não Funcional |
| **Critérios de aceite** | Amostra diária sem log sem trace_id |
| **Dependência arquitetural** | [ADR-0002 — `tracing-com-opentelemetry-e-correlation-id`](../adr/0002-tracing-com-opentelemetry-e-correlation-id.md) |

## 9. Restrições Técnicas Não Funcionais

- Dados residem em região Brasil (Inferência Não Funcional).

## 10. Matriz de Rastreabilidade PRD → NFRD

| Item do PRD | NFRs relacionados | Cobertura |
|---|---|---|
| KPI-01 | NFR-PERF-01 | Total |
| R-01 | NFR-PRIV-01 | Total |
| R-02 | NFR-DISP-01 | Total |

## 11. Critérios de Validação Não Funcional

Teste de carga pré-release; testes de autorização no CI.

## 12. Dependências

ADR-0002.

## 13. Premissas

Nenhuma.

## 14. Pontos a Validar

Nenhum.

## 15. Anexos

Nenhum.
