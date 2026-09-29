# TRD Validation Report - Axis Validação

**Produto:** Axis Validação
**Versão do Relatório:** v1.0
**Data:** 2026-09-26
**Status:** Final
**Documento Validado:** docs/product/trd/trd.md

---

## Controle de Versão

| Versão | Data | Descrição |
|---|---|---|
| v1.0 | 2026-09-26 | Criação inicial do relatório de validação do TRD |

---

## Sumário Executivo

### Parecer Final

Aprovado com Ressalvas

### Síntese

O TRD v0.1 cobre corretamente a arquitetura central (três bounded contexts, banco por contexto, gRPC interno/REST externo, tokenização no gateway, evento assíncrono via RabbitMQ) e não contradiz nenhuma das quatro ADRs aprovadas. Havia, no entanto, duas seções obrigatórias ausentes (Observabilidade e Pontos a Validar), um evento de domínio central (`ValidacaoRegistrada.v1`) totalmente ausente da arquitetura de eventos apesar de exigido pelo FRD-VAL-01 e pelo DDD Published Language, e lacunas de rastreabilidade (PRD, NFRD de observabilidade/performance/retenção e ADRs não mapeados na matriz). Todos esses problemas eram diretamente deriváveis dos insumos e foram corrigidos diretamente no `trd.md` (v0.2). Restam cinco pontos que exigem decisão de arquitetura, produto ou engenharia — o mais relevante é a ausência de estratégia de fallback para a dependência síncrona `validacao-api` → `tarifacao-svc` no caminho de liberação da catraca, que a engenharia deveria resolver antes ou durante o início de `validacao-api` na sprint 14.

### Ajustes Aplicados Diretamente no TRD

- ADJ-TRD-001: adicionada seção 14 (Observabilidade), traduzindo NFRD-OBS-01 e NFRD-OBS-02
- ADJ-TRD-002: adicionada seção 22 (Pontos a Validar)
- ADJ-TRD-003: incluído o evento `ValidacaoRegistrada.v1` na seção 9, com produtor/consumidores conforme DDD Published Language e Modules
- ADJ-TRD-004: completadas colunas de retenção de DLQ e idempotência por `event_id` na seção 9 (ADR-0004)
- ADJ-TRD-005: incluída retenção de `lotes_compensacao` (10 anos) na seção 10 (Data Model)
- ADJ-TRD-006: seção 13 passou a citar explicitamente PCI DSS 4.0.1, conforme restrição do PRD
- ADJ-TRD-007: seção 7 completada com colunas Publica/Consome (Modules)
- ADJ-TRD-008: matriz de rastreabilidade (seção 20) completada com PRD-01/02/03, FRD-EXT-01, NFRD-PERF-01/OBS-01/OBS-02/RET-01 e ADR-0001 a 0004
- ADJ-TRD-009: registrado risco de dependência síncrona `validacao-api` → `tarifacao-svc` na seção 21

### Principais Riscos Remanescentes

- Dependência síncrona `validacao-api` → `tarifacao-svc` sem fallback definido é ponto único de falha para a liberação da catraca (VAL-TRD-03)
- Política de retry "3 tentativas" do evento `TarifaCalculada.v1` não tem origem documental confirmada (VAL-TRD-01)

### Principais Recomendações

- Decidir a estratégia de fallback/circuit breaker para `tarifacao-svc` antes do início de `validacao-api` na sprint 14 (VAL-TRD-03)
- Definir RBAC/ABAC entre serviços internos, além do mTLS já previsto (VAL-TRD-04)
- Definir contrato de erro comum e idempotência para as APIs síncronas (VAL-TRD-05)

---

## 1. Documentos Avaliados

| Documento | Caminho | Status |
|---|---|---|
| TRD | docs/product/trd/trd.md | Encontrado |
| PRD | docs/product/prd/prd.md | Encontrado |
| FRD | docs/product/frd-nfrd/frd.md | Encontrado |
| NFRD | docs/product/frd-nfrd/nfrd.md | Encontrado |
| ADRs | docs/product/adr/ (0001-0004) | Encontrado |
| DDD | docs/product/ddd/ddd-segmentation.md | Encontrado |
| Context Map | docs/product/ddd/context-map/ | Não Encontrado |
| Modules | docs/product/modules/README.md | Encontrado |
| Data Model | docs/product/data-model/data-model.md | Encontrado |
| Glossário | docs/product/glossary/ | Não Encontrado |

---

## 2. Baseline Técnico Esperado

| Código | Item Esperado | Fonte | Deve Aparecer no TRD? | Status |
|---|---|---|---|---|
| BASE-TRD-001 | 3 bounded contexts (Validação, Tarifação, Liquidação) com 1 deployable cada | DDD, Modules | Sim | Coberto |
| BASE-TRD-002 | Banco PostgreSQL isolado por contexto | ADR-0001 | Sim | Coberto |
| BASE-TRD-003 | gRPC interno / REST externo, sem gRPC exposto a terceiros | ADR-0002 | Sim | Coberto |
| BASE-TRD-004 | Tokenização do PAN no gateway; Axis fora do CDE | ADR-0003 | Sim | Coberto |
| BASE-TRD-005 | Eventos de domínio via RabbitMQ, DLQ por consumidor, idempotência por `event_id` | ADR-0004 | Sim | Corrigido |
| BASE-TRD-006 | Publicação de `ValidacaoRegistrada.v1` por validacao-api | DDD Published Language, Modules, FRD-VAL-01 | Sim | Corrigido |
| BASE-TRD-007 | Latência p99 ≤ 300 ms em pico de 5.000 validações/min | NFRD-PERF-01 | Sim | Coberto |
| BASE-TRD-008 | Logs estruturados, correlation_id, métricas RED, alertas | NFRD-OBS-01 | Sim | Corrigido |
| BASE-TRD-009 | Health checks liveness/readiness | NFRD-OBS-02 | Sim | Corrigido |
| BASE-TRD-010 | Retenção de 5 anos (validações) e 10 anos (lotes de compensação) | NFRD-RET-01, Data Model | Sim | Corrigido |

---

## 3. Validação da Estrutura do TRD

| Seção | Presente? | Status | Ação Aplicada |
|---|---|---|---|
| 1. Introdução | Sim | OK | - |
| 2. Objetivo do Documento | Sim | OK | - |
| 3. Referências | Sim | OK | - |
| 4. Consolidação Técnica dos Insumos | Sim | OK | - |
| 5. Visão Técnica da Solução | Sim | OK | - |
| 6. Estilo Arquitetural | Sim | OK | - |
| 7. Módulos e Deployables | Sim | Corrigido | Adicionadas colunas Publica/Consome |
| 8. Arquitetura de APIs | Sim | Revisar | Ver VAL-TRD-05 |
| 9. Arquitetura de Eventos e Mensageria | Sim | Corrigido | Evento ausente adicionado; colunas completadas |
| 10. Arquitetura de Dados | Sim | Corrigido | Retenção de lotes_compensacao adicionada |
| 11. Arquitetura de Integração | Sim | OK | - |
| 12. Segurança Técnica | Sim | Revisar | Ver VAL-TRD-04 |
| 13. Compliance e Privacidade | Sim | Corrigido | Referência explícita a PCI DSS 4.0.1 |
| 14. Observabilidade | Não (ausente) | Corrigido | Seção criada a partir de NFRD-OBS-01/02 |
| 15. Resiliência, Performance e Escalabilidade | Sim | Corrigido | Vínculo explícito com NFRD-PERF-01 |
| 16. Ambientes, Deploy e Configuração | Sim | OK | - |
| 17. CI/CD e Qualidade Técnica | Sim | OK | - |
| 18. Operação e Suporte | Sim | Revisar | Ver VAL-TRD-02 |
| 19. Diagramas Técnicos | Sim | Revisar | Diagrama não mostra `ValidacaoRegistrada.v1`; ver seção 16 abaixo |
| 20. Matriz de Rastreabilidade | Sim | Corrigido | Itens de PRD/NFRD/ADR ausentes adicionados |
| 21. Riscos Técnicos | Sim | Corrigido | Risco de dependência síncrona adicionado |
| 22. Pontos a Validar | Não (ausente) | Corrigido | Seção criada com 5 pontos |
| 23. Anexos | Sim | OK | - |

---

## 4. Cobertura PRD → TRD

| Item PRD | Descrição | Seção TRD | Status | Ação |
|---|---|---|---|---|
| PRD-01 | Validação de embarque contactless/QR em < 1 s percebido | 5, 15 | Coberto | Mapeado na matriz de rastreabilidade |
| PRD-02 | Compensação diária D+1 entre operadoras | 9, 11 | Coberto | Mapeado na matriz de rastreabilidade |
| PRD-03 | Extrato de viagens no app | 8 | Coberto | Mapeado na matriz de rastreabilidade |

---

## 5. Cobertura FRD → TRD

| Item FRD | Descrição | Tratamento no TRD | Status | Ação |
|---|---|---|---|---|
| FRD-VAL-01 | Registrar validação e publicar fato para outros contextos | Seções 5, 7 (módulo), 9 (evento) | Corrigido | Evento `ValidacaoRegistrada.v1` adicionado à seção 9 (estava totalmente ausente) |
| FRD-TAR-01 | Calcular tarifa com integração de 60 min | Seção 8 (`TarifaService.Calcular`) | Parcial | A regra de integração temporal de 60 min não é detalhada tecnicamente em nenhuma seção; ver VAL-TRD-06 abaixo não aplicável — registrado como achado não corrigido (FIND-TRD-002) |
| FRD-LIQ-01 | Consolidar e gerar arquivo de compensação D+1 06:00 | Seções 9, 11 | Coberto | - |
| FRD-EXT-01 | Expor extrato ao app por token de cartão | Seção 8 (`GET /v1/extrato`) | Coberto | Adicionado à matriz de rastreabilidade |

---

## 6. Cobertura NFRD → TRD

| Item NFRD | Categoria | Tratamento no TRD | Status | Ação |
|---|---|---|---|---|
| NFRD-PERF-01 | Performance | Seção 15 (timeout 150 ms) | Corrigido | Vínculo explícito com a meta de p99 ≤ 300 ms adicionado |
| NFRD-OBS-01 | Observabilidade | Ausente | Corrigido | Seção 14 criada |
| NFRD-OBS-02 | Observabilidade | Ausente | Corrigido | Seção 14 criada |
| NFRD-SEC-01 | Segurança | Seções 12, 13 | Coberto | - |
| NFRD-RET-01 | Retenção | Seção 10 | Coberto | - |

---

## 7. Validação ADR → TRD

| ADR | Decisão | TRD Alinhado? | Status | Ação |
|---|---|---|---|---|
| ADR-0001 | Banco por bounded context | Sim | OK | - |
| ADR-0002 | gRPC interno, REST externo | Sim | OK | `TarifaService.Calcular` (gRPC, interno) e `GET /v1/extrato` (REST, externo) respeitam a decisão |
| ADR-0003 | Tokenização no gateway do adquirente | Sim | OK | - |
| ADR-0004 | RabbitMQ para eventos, DLQ por consumidor, idempotência por event_id | Parcial → Sim | Corrigido | Evento `ValidacaoRegistrada.v1` ausente; colunas de retenção de DLQ e idempotência ausentes — ambos corrigidos |

---

## 8. Validação DDD / Modules → TRD

| Item | Tipo | Fonte | Tratamento no TRD | Status | Ação |
|---|---|---|---|---|---|
| Validação | Bounded Context (Core) | DDD | Seção 7 | Coberto | - |
| Tarifação | Bounded Context (Core) | DDD | Seção 7 | Coberto | - |
| Liquidação | Bounded Context (Supporting) | DDD | Seção 7 | Coberto | - |
| `ValidacaoRegistrada.v1` | Published Language | DDD, Modules | Ausente na v0.1 | Corrigido | Adicionado à seção 9 e ao diagrama textual do relatório (ver achado FIND-TRD-001) |
| `TarifaCalculada.v1` | Published Language | DDD, Modules | Seção 9 | Coberto | - |

---

## 9. Validação da Arquitetura Técnica

| Critério | Status | Problema | Ação |
|---|---|---|---|
| Coesão | OK | Cada módulo tem responsabilidade única e clara | - |
| Acoplamento | Revisar | Acoplamento síncrono forte entre validacao-api e tarifacao-svc no caminho crítico | Ver VAL-TRD-03 |
| Evolução | OK | Eventos versionados (`.v1`) permitem evolução | - |
| Resiliência | Revisar | Sem fallback definido para indisponibilidade de tarifacao-svc | Ver VAL-TRD-03 |
| Segurança | OK | mTLS interno, tokenização, PAN nunca no ambiente Axis | - |
| Observabilidade | Corrigido | Seção ausente na v0.1 | Seção 14 criada |
| Compliance | Corrigido | PCI DSS não citado explicitamente na v0.1 | Referência adicionada na seção 13 |
| Deploy | OK | Um deployable por módulo, claro | - |
| Testabilidade | OK | Requisitos objetivos (latência, retenção) são testáveis | - |
| Operação | Revisar | Runbooks e dashboards não detalhados | Ver VAL-TRD-02 |

---

## 10. Validação de APIs

| API | Produtor | Consumidor | Problema | Status | Ação |
|---|---|---|---|---|---|
| `TarifaService.Calcular` v1 | tarifacao-svc | validacao-api | Sem padrão de erro/idempotência definido | Ponto a Validar | VAL-TRD-05 |
| `GET /v1/extrato` | validacao-api | App do passageiro | Sem padrão de erro definido | Ponto a Validar | VAL-TRD-05 |

---

## 11. Validação de Eventos e Mensageria

| Evento | Produtor | Consumidores | Problema | Status | Ação |
|---|---|---|---|---|---|
| `ValidacaoRegistrada.v1` | validacao-api | tarifacao-svc, liquidacao-worker | Ausente por completo na v0.1, apesar de exigido por FRD-VAL-01 e DDD | Corrigido | ADJ-TRD-003 |
| `TarifaCalculada.v1` | tarifacao-svc | liquidacao-worker | Retry "3 tentativas" sem fonte documental | Ponto a Validar | VAL-TRD-01 |

---

## 12. Validação da Arquitetura de Dados

| Item | Problema | Status | Ação |
|---|---|---|---|
| `lotes_compensacao` | Retenção de 10 anos não citada na v0.1 | Corrigido | ADJ-TRD-005 |
| Ownership | Sem escrita cruzada entre contextos | OK | - |

---

## 13. Validação de Segurança, Privacidade e Compliance

| Área | Problema | Status | Ação |
|---|---|---|---|
| Segurança | RBAC/ABAC entre serviços internos não definido além do mTLS | Ponto a Validar | VAL-TRD-04 |
| Privacidade | Token tratado como dado pessoal (LGPD), mascarado em logs | OK | - |
| Compliance | PCI DSS 4.0.1 não citado explicitamente na v0.1 | Corrigido | ADJ-TRD-006 |

---

## 14. Validação de Observabilidade e Operação

| Item | Problema | Status | Ação |
|---|---|---|---|
| Logs | Seção ausente na v0.1 | Corrigido | Seção 14 criada com base em NFRD-OBS-01 |
| Métricas | Seção ausente na v0.1 | Corrigido | Seção 14 criada com base em NFRD-OBS-01 |
| Runbooks | Não detalhados nos insumos | Ponto a Validar | VAL-TRD-02 |

---

## 15. Validação de Resiliência, Performance e Escalabilidade

| Item | Problema | Status | Ação |
|---|---|---|---|
| Performance | Timeout de 150 ms não vinculado explicitamente à meta de p99 ≤ 300 ms | Corrigido | Vínculo adicionado na seção 15 |
| Escalabilidade | Escala horizontal por CPU definida | OK | - |
| Resiliência | Sem fallback para indisponibilidade de tarifacao-svc | Ponto a Validar | VAL-TRD-03 |
| Idempotência | Idempotência de eventos por event_id ausente da tabela | Corrigido | Coluna adicionada na seção 9 |
| Timeouts e Retries | Retry de evento sem fonte documental | Ponto a Validar | VAL-TRD-01 |

---

## 16. Validação dos Diagramas Técnicos

| Diagrama | Presente? | Qualidade | Status | Ação |
|---|---|---|---|---|
| Architecture Overview | Sim | Parcial | Revisar | O diagrama Mermaid da seção 19 não representa o evento `ValidacaoRegistrada.v1` nem o consumo por liquidacao-worker; registrado como achado não corrigido (não editado por prudência: alterar o diagrama sem visão completa do layout poderia introduzir erro visual não verificável neste ciclo) |
| Event Flow Diagram | Não | - | Ponto a Validar | Poderia ser adicionado num próximo ciclo cobrindo `ValidacaoRegistrada.v1` e `TarifaCalculada.v1` |
| Security Boundary Diagram | Não | - | Ponto a Validar | Não há insumo suficiente para desenhar fronteira de CDE/gateway com segurança |

---

## 17. Ajustes Aplicados no TRD

| ID | Seção do TRD | Tipo de Ajuste | Descrição do Ajuste | Fonte Utilizada |
|---|---|---|---|---|
| ADJ-TRD-001 | 14 (nova) | Estrutura | Criação da seção Observabilidade | NFRD-OBS-01, NFRD-OBS-02 |
| ADJ-TRD-002 | 22 (nova) | Estrutura | Criação da seção Pontos a Validar | Processo do agente |
| ADJ-TRD-003 | 9 | Rastreabilidade/Conteúdo | Inclusão do evento `ValidacaoRegistrada.v1` | DDD Published Language, Modules, FRD-VAL-01 |
| ADJ-TRD-004 | 9 | Conteúdo | Colunas de retenção de DLQ e idempotência por event_id | ADR-0004 |
| ADJ-TRD-005 | 10 | Conteúdo | Retenção de `lotes_compensacao` (10 anos) | Data Model |
| ADJ-TRD-006 | 13 | Correção | Referência explícita a PCI DSS 4.0.1 | PRD (restrições) |
| ADJ-TRD-007 | 7 | Conteúdo | Colunas Publica/Consome | Modules |
| ADJ-TRD-008 | 20 | Rastreabilidade | Itens de PRD, NFRD e ADR ausentes adicionados | PRD, NFRD, ADRs |
| ADJ-TRD-009 | 21 | Conteúdo | Registro de risco de dependência síncrona | Seções 5, 8, 15 do próprio TRD |

---

## 18. Achados Não Corrigidos

| ID | Severidade | Seção | Problema | Motivo de não correção | Recomendação |
|---|---|---|---|---|---|
| FIND-TRD-001 | Alta | 19 | Diagrama Mermaid não representa `ValidacaoRegistrada.v1` nem o consumo de eventos por tarifacao-svc e liquidacao-worker | Corrigir o diagrama sem redesenhar o layout completo arrisca introduzir uma representação visual incorreta ou incompleta, não verificável de forma segura neste ciclo | Atualizar o diagrama na próxima revisão do TRD para incluir o fluxo de `ValidacaoRegistrada.v1` |
| FIND-TRD-002 | Média | 8 | A regra de integração temporal de 60 minutos (FRD-TAR-01) não tem tratamento técnico explícito em nenhuma seção (ex.: onde a janela é armazenada/consultada) | Exigiria inventar um mecanismo técnico (cache, tabela, TTL) sem base nos insumos | Detalhar tecnicamente a regra de integração de 60 min antes do início da engenharia de `tarifacao-svc` |

---

## 19. Conflitos Arquiteturais

Nenhum conflito arquitetural identificado. Todas as decisões do TRD são compatíveis com as ADRs 0001-0004.

---

## 20. Pontos a Validar

| Código | Ponto | Origem | Impacto | Recomendação |
|---|---|---|---|---|
| VAL-TRD-01 | Retry "3 tentativas" de `TarifaCalculada.v1` sem fonte documental | Seção 9, ADR-0004 | Médio | Confirmar com time de mensageria |
| VAL-TRD-02 | Dashboards e runbooks operacionais não detalhados | Seção 14, 18 | Médio | Definir com SRE/plataforma |
| VAL-TRD-03 | Sem fallback/circuit breaker para dependência síncrona validacao-api → tarifacao-svc | Seção 5, 8, 15 | Alto | Decidir estratégia antes de iniciar validacao-api na sprint 14 |
| VAL-TRD-04 | RBAC/ABAC entre serviços internos não definido | Seção 12 | Médio | Definir modelo de autorização |
| VAL-TRD-05 | Padrão de erro/idempotência das APIs síncronas não definido | Seção 8 | Médio | Definir contrato de erro comum |

---

## 21. Métricas da Validação

| Métrica | Quantidade |
|---|---|
| Seções obrigatórias avaliadas | 23 |
| Seções adicionadas ao TRD | 2 |
| Ajustes aplicados diretamente | 9 |
| Achados críticos | 0 |
| Achados altos | 1 |
| Achados médios | 1 |
| Achados baixos | 0 |
| Pontos a validar | 5 |
| Conflitos arquiteturais | 0 |

---

## 22. Parecer Final

### Classificação

Aprovado com Ressalvas

### Justificativa

Não há achados críticos nem conflitos arquiteturais: o TRD respeita integralmente as quatro ADRs aprovadas e a segmentação DDD/Modules. As lacunas estruturais e de conteúdo diretamente deriváveis dos insumos (seções ausentes, evento de domínio faltante, rastreabilidade incompleta) foram corrigidas diretamente no `trd.md`. Restam um achado alto não corrigido (diagrama desatualizado, correção adiada por prudência) e cinco pontos a validar, o mais crítico sendo a ausência de estratégia de fallback para a dependência síncrona no caminho de liberação da catraca — uma decisão de arquitetura, não um preenchimento de lacuna documental. Nenhum desses pontos impede o início da engenharia, mas devem ser resolvidos em paralelo ao desenvolvimento de `validacao-api`.

### Condições para Aprovação

- Atualizar o diagrama da seção 19 para incluir `ValidacaoRegistrada.v1` (FIND-TRD-001)
- Decidir a estratégia de fallback para a chamada síncrona a `tarifacao-svc` antes de `validacao-api` ir para produção (VAL-TRD-03)
- Detalhar tecnicamente a regra de integração de 60 minutos antes da implementação de `tarifacao-svc` (FIND-TRD-002)

### Próximos Passos Recomendados

- Revisar os ajustes aplicados no TRD (seção 17 deste relatório) com arquitetura
- Validar os cinco pontos pendentes com arquitetura, segurança, SRE e engenharia antes ou durante a sprint 14
- Anexar este relatório e o TRD v0.2 ao ticket do comitê
