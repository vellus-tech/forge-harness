# NFRD - App Cartão Cidade

## Controle de Versão

NFRD Generator - 2026-06-05 - Versão 1.0 gerada a partir do PRD v1.0.
NFRD Generator - 2026-09-26 - Versão 1.1 gerada a partir do PRD v1.1 (seção 7 — recarga via Pix): adiciona atributos de qualidade de resiliência (idempotência de webhook), segurança (mTLS na fronteira com o PSP), integrabilidade, auditoria, operação (retenção de comprovantes) e escalabilidade (pico mensal), sem alterar os NFRs herdados da v1.0.

## Sumário

## 1. Introdução

Requisitos não funcionais do app Cartão Cidade: consulta de saldo e extrato (v1.0) e recarga de saldo via Pix através de PSP parceiro (v1.1).

## 2. Objetivo do Documento

Detalhar os atributos de qualidade derivados do PRD v1.0 (consulta de saldo e extrato) e do PRD v1.1 (recarga via Pix — geração de QR Code dinâmico, webhook de confirmação de pagamento do PSP e crédito no cartão).

## 3. Referências

- docs/product/prd/prd.md (v1.1, seção 7 aprovada por Rafael Costa em 2026-09-22)
- docs/product/adr/0001-backend-em-dotnet.md
- docs/product/adr/0002-tracing-com-opentelemetry-e-correlation-id.md
- .forge/rules/architecture/mtls-internal-services.md — modelo de mTLS via cert-manager hoje cobre apenas serviço-a-serviço interno no cluster; não cobre autenticação de webhook de parceiro externo (ver Ponto a Validar §14 e ADR sugerido §3)
- .forge/rules/domain/audit-immutability.md — mecanismo de trilha append-only aplicável aos eventos de recarga
- .forge/rules/architecture/pii-pci-classification.md — classificação de dados aplicável a comprovante de recarga e identificadores de pagamento
- .forge/rules/architecture/observability.md — correlationId e mascaramento de log, aplicável ao fluxo de webhook

## 4. Visão Geral dos Atributos de Qualidade

Foco em latência de consulta, disponibilidade e privacidade (v1.0), somado em v1.1 a: tempo de crédito pós-confirmação de pagamento, resiliência a duplicidade de notificação do PSP (idempotência), segurança da fronteira com o parceiro externo (mTLS), integrabilidade do contrato com o PSP, auditabilidade do fluxo de recarga, retenção de comprovantes e capacidade para o pico mensal de recargas.

## 5. Escopo Não Funcional

Consulta de saldo e extrato (v1.0). Recarga de saldo via Pix: geração de QR Code dinâmico, recebimento e processamento idempotente do webhook de confirmação do PSP, autenticação mTLS do webhook, crédito no cartão, retenção do comprovante e capacidade para o pico de volumetria do dia 5 de cada mês (v1.1).

## 6. Fora de Escopo

Emissão física do cartão de bilhetagem. Integração com meios de recarga além de Pix (ex.: boleto, cartão de crédito) — não previstos no PRD v1.1. Conciliação financeira contábil detalhada com o PSP (tratada como Ponto a Validar, §14).

## 7. Decisão por Categoria

| Categoria | Aplicável? | Justificativa (quando não aplicável) | NFRs |
|---|---|---|---|
| PERF | Sim | | NFR-PERF-01, NFR-PERF-02 |
| DISP | Sim | | NFR-DISP-01 |
| ESC | Sim | | NFR-ESC-01 |
| RES | Sim | | NFR-RES-01 |
| SEG | Sim | | NFR-SEG-01, NFR-SEG-02 |
| PRIV | Sim | | NFR-PRIV-01 |
| COMP | Não | Recarga via Pix não introduz, no PRD v1.1, obrigação regulatória setorial específica (ex.: BACEN/arranjo Pix) além da retenção contratual já coberta em OPS/AUD; regras do arranjo Pix aplicáveis ao emissor não foram detalhadas no PRD — registrado como Ponto a Validar (§14) | |
| OBS | Sim | | NFR-OBS-01 |
| AUD | Sim | | NFR-AUD-01 |
| INT | Sim | | NFR-INT-01 |
| USA | Não | Fora do escopo deste ciclo | |
| MAN | Não | Coberto por rules de testing | |
| POR | Não | Ambiente único | |
| OPS | Sim | | NFR-OPS-01 |

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

### NFR-PERF-02 - Tempo de crédito da recarga Pix

| Campo | Conteúdo |
|---|---|
| **Categoria** | Performance |
| **Descrição** | Tempo entre a confirmação de pagamento pelo PSP (recebimento do webhook) e o crédito refletido no saldo do cartão |
| **Meta** | p95 ≤ 10 s após confirmação do pagamento pelo PSP |
| **Método de medição** | Teste de carga simulando recebimento de webhook e medição do intervalo `webhook_received_at` → `credit_applied_at`; histograma em produção |
| **Fonte de dados** | Métrica dedicada `pix_recharge_credit_duration_seconds` (Prometheus), correlacionada por `correlationId` |
| **Escopo** | Fluxo de recarga Pix: recebimento do webhook até persistência do crédito |
| **Prioridade** | Alta |
| **Origem** | PRD KPI-02 |
| **Critérios de aceite** | p95 ≤ 10 s medido sobre amostra de 24h em produção, e em teste de carga a 15 recargas/s |
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

### NFR-ESC-01 - Capacidade para o pico mensal de recarga Pix

| Campo | Conteúdo |
|---|---|
| **Categoria** | Escalabilidade |
| **Descrição** | Capacidade do fluxo de recarga (geração de QR Code, recebimento de webhook, crédito) para absorver o pico concentrado no dia 5 de cada mês |
| **Meta** | Sustentar 15 recargas/s por, no mínimo, a janela de pico observada, sem violar a meta de NFR-PERF-02 (p95 ≤ 10 s) |
| **Método de medição** | Teste de carga k6 simulando 15 recargas/s sustentadas; monitoração de autoscaling (HPA) durante o dia 5 em produção |
| **Fonte de dados** | Relatório de teste de carga; métricas de replicas/CPU/memória do HPA (Prometheus) |
| **Escopo** | Serviço de recarga Pix (geração de QR Code + processamento de webhook) |
| **Prioridade** | Alta |
| **Origem** | PRD §4 (volumetria v1.1 — 60 mil recargas/dia, pico de 15 recargas/s no dia 5) |
| **Critérios de aceite** | Teste de carga a 15 recargas/s por 30 min contínuos sem violar p95 ≤ 10 s nem gerar erros 5xx acima de 0,1% |
| **Dependência arquitetural** | — |

### NFR-RES-01 - Idempotência do crédito de recarga Pix

| Campo | Conteúdo |
|---|---|
| **Categoria** | Resiliência |
| **Descrição** | O recebimento de mais de uma notificação de pagamento do PSP para a mesma recarga não pode gerar mais de um crédito no saldo do cartão |
| **Meta** | 0% de duplicidade de crédito por identificador de pagamento (condição binária) |
| **Método de medição** | Teste de replay: reenviar a mesma notificação de webhook N vezes e verificar que apenas 1 crédito foi aplicado; auditoria periódica de reconciliação (1 crédito por `payment_id`) |
| **Fonte de dados** | Tabela/trilha de eventos de recarga (ver NFR-AUD-01) cruzada com lançamentos de crédito |
| **Escopo** | Endpoint de recebimento do webhook do PSP e processamento de crédito |
| **Prioridade** | Alta |
| **Origem** | PRD R-04 |
| **Critérios de aceite** | Teste de replay com 5 reenvios da mesma notificação resulta em exatamente 1 crédito aplicado e 4 respostas idempotentes (sem novo efeito colateral) |
| **Dependência arquitetural** | ADR-0003 — `idempotencia-webhook-pagamento-psp` (a ser criado via `adr-writer`) |

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

### NFR-SEG-02 - Autenticação mTLS do webhook do PSP

| Campo | Conteúdo |
|---|---|
| **Categoria** | Segurança |
| **Descrição** | O endpoint que recebe a notificação de pagamento do PSP só aceita requisições autenticadas por certificado de cliente (mTLS) emitido pelo PSP |
| **Meta** | 100% das requisições ao endpoint de webhook autenticadas por certificado de cliente válido; requisição sem certificado ou com certificado inválido é rejeitada com HTTP 4xx antes de qualquer processamento de negócio (condição binária) |
| **Método de medição** | Teste automatizado de rejeição (certificado ausente, expirado, revogado ou de emissor não confiável) no CI; verificação de configuração TLS em auditoria de segurança pré-release |
| **Fonte de dados** | Relatório de teste de rotas/TLS; logs de handshake TLS rejeitado (mascarados, sem dado sensível) |
| **Escopo** | Endpoint público de recebimento do webhook do PSP |
| **Prioridade** | Alta |
| **Origem** | PRD R-05 |
| **Critérios de aceite** | 100% das tentativas sem certificado válido rejeitadas em teste automatizado; nenhuma exceção `InsecureSkipVerify`/equivalente no código |
| **Dependência arquitetural** | ADR-0004 — `mtls-webhook-parceiro-externo` (a ser criado via `adr-writer`) — `.forge/rules/architecture/mtls-internal-services.md` cobre hoje apenas mTLS serviço-a-serviço dentro do cluster (CA interna via cert-manager); a fronteira com um parceiro externo (PSP) exige confiar em uma CA/cert diferente e não está coberta pela rule existente |

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
| **Descrição** | Toda requisição propaga correlationId e gera trace, incluindo o recebimento do webhook do PSP e o processamento de crédito da recarga |
| **Meta** | 100% das requisições com trace_id nos logs |
| **Método de medição** | Consulta de amostragem no Loki |
| **Fonte de dados** | Logs estruturados |
| **Escopo** | Todos os serviços, incluindo o fluxo de recarga Pix |
| **Prioridade** | Média |
| **Origem** | Inferência Não Funcional |
| **Critérios de aceite** | Amostra diária sem log sem trace_id |
| **Dependência arquitetural** | [ADR-0002 — `tracing-com-opentelemetry-e-correlation-id`](../adr/0002-tracing-com-opentelemetry-e-correlation-id.md) |

### NFR-AUD-01 - Trilha auditável dos eventos de recarga Pix

| Campo | Conteúdo |
|---|---|
| **Categoria** | Auditoria |
| **Descrição** | Todo evento do ciclo de recarga (QR Code gerado, webhook recebido, crédito aplicado ou rejeitado por duplicidade) é registrado em trilha append-only, sustentando a evidência exigida por NFR-RES-01 e a comprovação de crédito |
| **Meta** | 100% dos eventos de recarga registrados em tabela imutável (condição binária) |
| **Método de medição** | Teste de integração verificando rejeição de UPDATE/DELETE na tabela de eventos (Testcontainers, conforme padrão da rule) |
| **Fonte de dados** | Tabela `pix_recharge_events` (ou equivalente), trigger de imutabilidade |
| **Escopo** | Serviço de recarga Pix |
| **Prioridade** | Alta |
| **Origem** | PRD R-04 (evidência de deduplicação) e PRD §7 (rastreabilidade da recarga) |
| **Critérios de aceite** | Teste de integração confirma exceção em tentativa de UPDATE/DELETE na tabela de eventos |
| **Dependência arquitetural** | `.forge/rules/domain/audit-immutability.md` (mecanismo já vinculante; não requer novo ADR) |

### NFR-INT-01 - Contrato de integração com o PSP parceiro

| Campo | Conteúdo |
|---|---|
| **Categoria** | Interoperabilidade |
| **Descrição** | O contrato de API com o PSP (geração de QR Code dinâmico e schema do payload do webhook) é versionado e validado automaticamente |
| **Meta** | 100% dos payloads de webhook recebidos validados contra o schema do contrato antes do processamento; quebra de contrato detectada antes de produção (condição binária) |
| **Método de medição** | Testes de contrato contra o sandbox do PSP no CI; validação de schema em tempo de execução com rejeição de payload inválido |
| **Fonte de dados** | Relatório de testes de contrato; métrica de payloads rejeitados por schema inválido |
| **Escopo** | Integração de geração de QR Code e webhook de confirmação com o PSP |
| **Prioridade** | Média |
| **Origem** | PRD §7 (J-02) |
| **Critérios de aceite** | Suíte de contrato passa no CI antes de cada deploy que toque a integração |
| **Dependência arquitetural** | — |

### NFR-OPS-01 - Retenção de comprovantes de recarga

| Campo | Conteúdo |
|---|---|
| **Categoria** | Operabilidade |
| **Descrição** | Comprovantes de recarga via Pix são retidos pelo prazo exigido pelo contrato de concessão |
| **Meta** | Retenção mínima de 5 anos, com recuperação íntegra do comprovante a qualquer momento dentro do prazo |
| **Método de medição** | Auditoria de política de retenção do storage/objeto; teste de recuperação de comprovante amostral |
| **Fonte de dados** | Configuração de lifecycle do storage de comprovantes; relatório de auditoria |
| **Escopo** | Comprovantes de recarga Pix |
| **Prioridade** | Alta |
| **Origem** | PRD R-03 |
| **Critérios de aceite** | Política de retenção configurada com prazo ≥ 5 anos e sem exclusão automática antes do prazo |
| **Dependência arquitetural** | — |

## 9. Restrições Técnicas Não Funcionais

- Dados residem em região Brasil (Inferência Não Funcional).
- O webhook de confirmação de pagamento do PSP só é aceito com mTLS válido — nenhuma exceção de bypass em produção (PRD R-05; ver NFR-SEG-02 e ADR-0004 sugerido).
- Processamento de notificação de pagamento deve ser idempotente por design (chave natural = identificador de pagamento do PSP) — nunca depender apenas de "melhor esforço" da aplicação (PRD R-04; ver NFR-RES-01 e ADR-0003 sugerido).

## 10. Matriz de Rastreabilidade PRD → NFRD

| Item do PRD | NFRs relacionados | Cobertura |
|---|---|---|
| KPI-01 | NFR-PERF-01 | Total |
| R-01 | NFR-PRIV-01 | Total |
| R-02 | NFR-DISP-01 | Total |
| OBJ-02 (v1.1) | NFR-ESC-01, NFR-INT-01 | Total |
| KPI-02 (v1.1) | NFR-PERF-02 | Total |
| §4 volumetria recarga (v1.1) | NFR-ESC-01 | Total |
| J-02 (v1.1) | NFR-PERF-02, NFR-RES-01, NFR-SEG-02, NFR-INT-01, NFR-AUD-01 | Total |
| R-03 (v1.1) | NFR-OPS-01 | Total |
| R-04 (v1.1) | NFR-RES-01, NFR-AUD-01 | Total |
| R-05 (v1.1) | NFR-SEG-02 | Total |

## 11. Critérios de Validação Não Funcional

Teste de carga pré-release (consulta de saldo e pico de recarga a 15 recargas/s); testes de autorização no CI; teste de replay de webhook para idempotência; teste automatizado de rejeição mTLS (certificado ausente/inválido/expirado); testes de contrato contra sandbox do PSP; teste de integração de imutabilidade da trilha de eventos de recarga; auditoria de política de retenção de comprovantes (recorrente, anual).

## 12. Dependências

ADR-0002 (tracing). ADR-0003 e ADR-0004 sugeridos nesta revisão (§ADRs Sugeridos, abaixo) — bloqueantes para o início do design de payments na quarta-feira, pois definem o padrão de idempotência e o modelo de confiança mTLS que o design do time de pagamentos precisa assumir.

## 13. Premissas

Assume-se que o PSP parceiro já está contratado e que o certificado de cliente usado no mTLS do webhook é emitido e gerenciado pelo PSP (fora do domínio do `internal-ca` do cert-manager do projeto) — Proposto pelo NFRD — validar com produto/arquitetura.

## 14. Pontos a Validar

- Processo de confiança e rotação do certificado do PSP no lado do app (o mecanismo hoje documentado em `.forge/rules/architecture/mtls-internal-services.md` cobre apenas certificados emitidos pela CA interna do cluster; falta definir como o certificate bundle do PSP é distribuído/atualizado). Quem decide: arquitetura + segurança. Impacto se não decidido: bloqueia a implementação segura do NFR-SEG-02 antes de quarta-feira.
- Política de retry do PSP em caso de falha no recebimento do webhook (timeout, 5xx) não está descrita no PRD — afeta o desenho de NFR-RES-01. Quem decide: produto + PSP parceiro. Impacto: sem essa informação, o teste de idempotência pode não cobrir o pior caso real de reenvio.
- Enquadramento regulatório do arranjo Pix aplicável ao emissor (ex.: exigências específicas do BACEN sobre custódia/relato de recarga) não foi detalhado no PRD — mantido como categoria COMP não aplicável nesta versão, mas pode mudar essa decisão em revisão futura. Quem decide: jurídico/compliance. Impacto: possível NFR de compliance não coberto.
- Meta de disponibilidade específica para o fluxo de recarga Pix (distinta da disponibilidade geral do backend em NFR-DISP-01) não foi declarada no PRD. Quem decide: produto. Impacto: sem meta própria, uma indisponibilidade pontual do PSP pode ser tratada com o mesmo SLA da consulta de saldo, o que pode não refletir a realidade de uma integração externa.

## 15. Anexos

Nenhum.
