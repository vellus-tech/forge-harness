# NFRD - Validador de Embarque Contactless

## Controle de Versão

NFRD Generator - 2026-09-26 - Versão 1.0 gerada a partir do PRD v1.0 (aprovado pelo comitê em 2026-09-10) e das notas de discovery.

## Sumário

1. Introdução
2. Objetivo do Documento
3. Referências
4. Visão Geral dos Atributos de Qualidade
5. Escopo Não Funcional
6. Fora de Escopo
7. Decisão por Categoria
8. Detalhamento dos Requisitos Não Funcionais
9. Restrições Técnicas Não Funcionais
10. Matriz de Rastreabilidade PRD → NFRD
11. Critérios de Validação Não Funcional
12. Dependências
13. Premissas
14. Pontos a Validar
15. Anexos

## 1. Introdução

Este NFRD detalha os requisitos não funcionais do Validador de Embarque Contactless a partir do `docs/product/prd/prd.md` (versão 1.0, aprovada pelo comitê de produto em 2026-09-10) e das notas de discovery em `docs/discovery/discovery-notes.md`. O produto permite pagamento de tarifa por aproximação de cartão EMV ou carteira digital no validador embarcado, com validação local offline-first e liquidação agregada em backend.

## 2. Objetivo do Documento

Estabelecer os atributos de qualidade — performance, disponibilidade, escalabilidade, resiliência, segurança, privacidade, compliance, observabilidade, auditoria, interoperabilidade, usabilidade, manutenibilidade, portabilidade e operabilidade — que o validador embarcado e o backend de liquidação devem atender, com metas verificáveis e rastreáveis ao PRD, para apoiar a reunião de arquitetura com SRE e AppSec.

## 3. Referências

- `docs/product/prd/prd.md` — versão 1.0, aprovada pelo comitê de produto em 2026-09-10.
- `docs/discovery/discovery-notes.md` — notas de discovery do validador EMV.
- `.forge/rules/architecture/security-and-compliance.md` — controles obrigatórios de segurança/LGPD/PCI DSS.
- `.forge/rules/architecture/pii-pci-classification.md` — classificação PII/PAN, mascaramento, fronteira de tokenização.
- `.forge/rules/architecture/observability.md` — três pilares, correlationId, golden signals.
- `.forge/rules/testing/quality-gates.md` — thresholds de cobertura e níveis de teste obrigatórios.
- Não há `docs/product/frd-nfrd/frd.md` nem `docs/product/adr/` nesta base — sem decisões arquiteturais prévias a referenciar; nenhum FRD para checagem cruzada de consistência funcional.

## 4. Visão Geral dos Atributos de Qualidade

O sistema opera em dois planos com exigências distintas: o validador embarcado, que precisa responder em até 500 ms mesmo offline por até 72 h, e o backend de liquidação, que processa até 250 validações/segundo em pico e deve estar disponível 99,5% ao mês sob multa contratual. Dados de cartão (PAN) e dados pessoais de passageiros colocam o sistema simultaneamente sob PCI DSS 4.0.1 e LGPD. O incidente de 2025 (queda de 6 h do backend, perda estimada de R$ 180 mil) e a exigência de trilha de quem altera a lista de restrição elevam resiliência e auditoria a atributos críticos, não apenas desejáveis.

## 5. Escopo Não Funcional

Ver §7 (Decisão por Categoria) e §8 (Detalhamento dos NFRs) para o escopo completo: performance, disponibilidade, escalabilidade, resiliência, segurança, privacidade, compliance, observabilidade, auditoria, interoperabilidade, usabilidade/acessibilidade, manutenibilidade, portabilidade e operabilidade.

## 6. Fora de Escopo

- Requisitos funcionais do fluxo de validação, agregação de tarifas e consulta de extrato — pertencem ao FRD (inexistente nesta base; ver Ponto a Validar §14).
- Arquitetura técnica completa (escolha de banco, broker, runtime) — pertence ao TRD; este NFRD apenas fixa metas que a restringem.
- Modelo de domínio — pertence ao DDD Architect.
- Venda de créditos de bilhetagem própria e gratuidades/meia-passagem — fora de escopo do próprio PRD (§7).

## 7. Decisão por Categoria

| Categoria | Aplicável? | Justificativa (quando não aplicável) | NFRs |
|---|---|---|---|
| Performance (PERF) | Sim | — | NFR-PERF-01, NFR-PERF-02, NFR-PERF-03 |
| Disponibilidade (DISP) | Sim | — | NFR-DISP-01, NFR-DISP-02 |
| Escalabilidade (ESC) | Sim | — | NFR-ESC-01 |
| Resiliência (RES) | Sim | — | NFR-RES-01, NFR-RES-02 |
| Segurança (SEG) | Sim | — | NFR-SEG-01, NFR-SEG-02, NFR-SEG-03, NFR-SEG-04 |
| Privacidade (PRIV) | Sim | — | NFR-PRIV-01, NFR-PRIV-02 |
| Compliance (COMP) | Sim | — | NFR-COMP-01, NFR-COMP-02, NFR-COMP-03 |
| Observabilidade (OBS) | Sim | — | NFR-OBS-01, NFR-OBS-02, NFR-OBS-03 |
| Auditoria (AUD) | Sim | — | NFR-AUD-01, NFR-AUD-02, NFR-AUD-03 |
| Interoperabilidade (INT) | Sim | — | NFR-INT-01, NFR-INT-02 |
| Usabilidade e acessibilidade (USA) | Sim | PRD cita apenas premissa qualitativa ("rápido e fácil") sem meta verificável — NFR derivado por inferência, meta concreta é Ponto a Validar | NFR-USA-01 |
| Manutenibilidade (MAN) | Sim | — | NFR-MAN-01 |
| Portabilidade (POR) | Não | PRD não menciona requisito de multi-ambiente, multi-cloud ou multi-arch para o backend, nem stack técnica definida; sem evidência para derivar meta | — |
| Operabilidade (OPS) | Sim | — | NFR-OPS-01, NFR-OPS-02, NFR-OPS-03 |

## 8. Detalhamento dos Requisitos Não Funcionais

### NFR-PERF-01 - Latência de validação na catraca

| Campo | Conteúdo |
|---|---|
| **Categoria** | Performance |
| **Descrição** | Tempo entre a aproximação do cartão/carteira digital e a liberação da catraca (luz verde) deve ser baixo o suficiente para não formar fila de embarque. |
| **Meta** | p95 ≤ 500 ms, medido do evento de aproximação à liberação da catraca. |
| **Método de medição** | Teste de carga sintético no validador embarcado + telemetria de produção agregada por dia. |
| **Fonte de dados** | Log de eventos do validador (timestamp de aproximação e de liberação). |
| **Escopo** | Todos os 1.200 validadores embarcados, fluxo J-01. |
| **Prioridade** | Alta |
| **Origem** | KPI-01 |
| **Critérios de aceite** | p95 diário ≤ 500 ms em pelo menos 95% dos dias do mês de medição. |
| **Dependência arquitetural** | — |

### NFR-PERF-02 - Throughput de pico do backend de liquidação

| Campo | Conteúdo |
|---|---|
| **Categoria** | Performance |
| **Descrição** | O backend deve absorver o pico de validações da janela de pico da manhã sem degradar KPI-01/KPI-02. |
| **Meta** | ≥ 250 validações/segundo sustentadas, sem aumento de latência p95 acima da meta de NFR-PERF-01 nem de taxa de erro acima de NFR-PERF-03/KPI-02. |
| **Método de medição** | Teste de carga com perfil de tráfego reproduzindo a janela 6h–8h. |
| **Fonte de dados** | Métricas de throughput e latência do backend (Prometheus). |
| **Escopo** | Backend de recepção e processamento de lotes de validação. |
| **Prioridade** | Alta |
| **Origem** | PRD §4 (Volumetria) |
| **Critérios de aceite** | Teste de carga em pré-release sustenta 250 req/s por 2 h sem violar NFR-PERF-01 nem KPI-02. |
| **Dependência arquitetural** | — |

### NFR-PERF-03 - Taxa de recusa técnica de validação

| Campo | Conteúdo |
|---|---|
| **Categoria** | Performance |
| **Descrição** | Recusas por falha técnica (não por restrição legítima do cartão) devem ser raras para não penalizar o passageiro nem a receita. |
| **Meta** | < 0,5% das validações recusadas por falha técnica. |
| **Método de medição** | Contagem de recusas classificadas como técnicas sobre total de validações, por dia. |
| **Fonte de dados** | Log de validação do validador embarcado, com campo de motivo de recusa. |
| **Escopo** | Todos os validadores, fluxo J-01. |
| **Prioridade** | Alta |
| **Origem** | KPI-02 |
| **Critérios de aceite** | Taxa mensal de recusa técnica < 0,5%. |
| **Dependência arquitetural** | — |

### NFR-DISP-01 - Disponibilidade mensal do backend

| Campo | Conteúdo |
|---|---|
| **Categoria** | Disponibilidade |
| **Descrição** | O backend de liquidação, portal da gestora e API para o app do passageiro devem cumprir o SLA contratual com a prefeitura. |
| **Meta** | ≥ 99,5% de disponibilidade mensal. |
| **Método de medição** | Cálculo de uptime mensal a partir de health checks e incidentes registrados. |
| **Fonte de dados** | Monitoramento de uptime (ex.: probes sintéticos) e registro de incidentes. |
| **Escopo** | Backend de liquidação, portal da gestora, API de extrato do app. |
| **Prioridade** | Alta |
| **Origem** | R-04 |
| **Critérios de aceite** | Relatório mensal de disponibilidade ≥ 99,5%, sem glosa contratual por descumprimento. |
| **Dependência arquitetural** | — |

### NFR-DISP-02 - Janela de manutenção sem impacto no SLA

| Campo | Conteúdo |
|---|---|
| **Categoria** | Disponibilidade |
| **Descrição** | Manutenções planejadas do backend não podem consumir a margem de indisponibilidade do SLA de 99,5% sem contabilização explícita. |
| **Meta** | Manutenções planejadas comunicadas com antecedência mínima e contabilizadas no cálculo de disponibilidade — valor de antecedência é Inferência Não Funcional. |
| **Método de medição** | Auditoria do calendário de manutenções versus janelas efetivamente executadas. |
| **Fonte de dados** | Calendário de change management (a definir). |
| **Escopo** | Backend de liquidação. |
| **Prioridade** | Média |
| **Origem** | Inferência Não Funcional (decorre de R-04; PRD não define política de manutenção) |
| **Critérios de aceite** | Nenhuma manutenção não comunicada reduz a disponibilidade medida abaixo de 99,5%. |
| **Dependência arquitetural** | — |

### NFR-ESC-01 - Escalabilidade para crescimento de volumetria

| Campo | Conteúdo |
|---|---|
| **Categoria** | Escalabilidade |
| **Descrição** | O backend deve absorver o crescimento anual projetado de validações sem degradar as metas de performance e disponibilidade. |
| **Meta** | Suportar 20% de crescimento ao ano sobre a base de 900 mil validações/dia útil e 250 validações/segundo de pico, mantendo NFR-PERF-01/02/03 e NFR-DISP-01. |
| **Método de medição** | Teste de carga anual com projeção de volumetria futura (capacity planning). |
| **Fonte de dados** | Métricas de capacidade do backend (CPU, memória, conexões, filas) versus volumetria projetada. |
| **Escopo** | Backend de liquidação e ingestão de lotes. |
| **Prioridade** | Média |
| **Origem** | PRD §4 (Volumetria — "crescimento esperado de 20% ao ano") |
| **Critérios de aceite** | Teste de capacidade anual comprova headroom para o próximo ciclo de 20% de crescimento sem violar metas de PERF/DISP. |
| **Dependência arquitetural** | — |

### NFR-RES-01 - Operação offline do validador embarcado

| Campo | Conteúdo |
|---|---|
| **Categoria** | Resiliência |
| **Descrição** | O validador deve continuar aprovando localmente contra a lista de restrição e enfileirando transações mesmo sem conectividade celular, em áreas de cobertura intermitente. |
| **Meta** | Operação offline funcional por até 72 h contínuas, com fila local de transações e reenvio automático ao reconectar; 100% das validações offline enviadas ao backend em até 24 h após reconexão. |
| **Método de medição** | Teste de resiliência (desligamento de conectividade simulado) + auditoria de atraso de sincronização em produção. |
| **Fonte de dados** | Log local do validador (fila) e timestamp de recepção no backend. |
| **Escopo** | Todos os validadores embarcados, fluxo J-01/J-02. |
| **Prioridade** | Alta |
| **Origem** | R-01, KPI-03 |
| **Critérios de aceite** | Teste de chaos com 72 h de desconexão simulada não perde transações da fila; 100% sincronizado em até 24 h após reconexão. |
| **Dependência arquitetural** | — |

### NFR-RES-02 - Recuperação de desastre do backend de liquidação

| Campo | Conteúdo |
|---|---|
| **Categoria** | Resiliência |
| **Descrição** | O backend deve se recuperar de uma indisponibilidade prolongada (como a queda de 6 h registrada em 2025) dentro de um tempo que não repita a perda de receita observada. |
| **Meta** | RTO e RPO numéricos — Proposto pelo NFRD — validar com produto; nenhum valor de RTO/RPO consta no PRD. |
| **Método de medição** | DR drill cronometrado (tempo até restauração de serviço e ponto de recuperação de dados). |
| **Fonte de dados** | Log de execução do DR drill. |
| **Escopo** | Backend de liquidação e dados de validação/conciliação. |
| **Prioridade** | Alta |
| **Origem** | Proposto pelo NFRD — validar com produto (motivado pela nota de discovery sobre a queda de 6 h em 2025 e perda de R$ 180 mil, e por R-04) |
| **Critérios de aceite** | DR drill recorrente comprova RTO/RPO dentro da meta a ser definida; nenhum incidente de indisponibilidade prolongada sem plano de recuperação testado. |
| **Dependência arquitetural** | ADR-NNNN sugerido — `estrategia-dr-backend-liquidacao` (a ser criado via `adr-writer`) — ver §3 abaixo. |

### NFR-SEG-01 - Tokenização e não armazenamento de PAN em claro

| Campo | Conteúdo |
|---|---|
| **Categoria** | Segurança |
| **Descrição** | Nenhum componente do sistema (validador, backend, portal, app) armazena ou transmite PAN em texto claro fora da fronteira de tokenização. |
| **Meta** | 100% dos campos de PAN classificados com `tokenization_boundary` documentado; zero ocorrências de PAN em claro em banco de aplicação, log ou código. |
| **Método de medição** | Revisão de configuração + scan de dados sensíveis (data discovery) em bancos e logs; auditoria de código. |
| **Fonte de dados** | Mapa de classificação de dados (`data-classification.schema.json`), resultado de scan de PII/PAN. |
| **Escopo** | Validador, backend de liquidação, portal da gestora, app do passageiro. |
| **Prioridade** | Alta |
| **Origem** | R-02 |
| **Critérios de aceite** | Scan de dados sensíveis pré-release sem PAN em claro fora da fronteira de tokenização; auditoria de compliance PCI DSS 4.0.1 sem finding de PAN exposto. |
| **Dependência arquitetural** | — |

### NFR-SEG-02 - TLS na integração com a adquirente

| Campo | Conteúdo |
|---|---|
| **Categoria** | Segurança |
| **Descrição** | Toda comunicação com a API REST da adquirente e com o backend do validador deve usar TLS 1.2 ou superior. |
| **Meta** | TLS ≥ 1.2 em 100% das conexões externas (adquirente, portal, app). |
| **Método de medição** | Scan de configuração TLS (ex.: teste de handshake) em CI e em produção. |
| **Fonte de dados** | Relatório de scan de TLS/certificados. |
| **Escopo** | Integração com adquirente (R-05), portal da gestora, API do app do passageiro. |
| **Prioridade** | Alta |
| **Origem** | R-05 |
| **Critérios de aceite** | Nenhuma conexão externa aceita TLS < 1.2 em scan de configuração pré-release. |
| **Dependência arquitetural** | — |

### NFR-SEG-03 - Autenticação e RBAC no portal da gestora

| Campo | Conteúdo |
|---|---|
| **Categoria** | Segurança |
| **Descrição** | O portal usado pelo operador da gestora para consultar validações (J-03) deve exigir autenticação forte e controle de acesso por papel. |
| **Meta** | 100% das rotas do portal com autenticação obrigatória e verificação explícita de RBAC; nenhuma rota sensível sem controle de acesso. |
| **Método de medição** | Revisão de configuração de rotas + teste de autorização negativa (tentativa de acesso sem permissão). |
| **Fonte de dados** | Matriz de rotas versus permissões do portal. |
| **Escopo** | Portal da gestora, fluxo J-03. |
| **Prioridade** | Alta |
| **Origem** | Inferência Não Funcional (decorre de J-03 e do controle obrigatório de RBAC em `.forge/rules/architecture/security-and-compliance.md`) |
| **Critérios de aceite** | Pentest/revisão de acesso não encontra rota sensível sem RBAC. |
| **Dependência arquitetural** | — |

### NFR-SEG-04 - Controle de acesso para alteração da lista de restrição

| Campo | Conteúdo |
|---|---|
| **Categoria** | Segurança |
| **Descrição** | Alterações na lista de restrição usada para aprovação local (J-01) devem ser restritas a papéis autorizados, com autenticação forte. |
| **Meta** | 100% das alterações de lista de restrição associadas a um usuário autenticado e autorizado; zero alterações anônimas ou sem trilha. |
| **Método de medição** | Auditoria de acesso e revisão de logs de alteração da lista de restrição. |
| **Fonte de dados** | Log de auditoria de alteração (ver NFR-AUD-01). |
| **Escopo** | Serviço de gestão da lista de restrição. |
| **Prioridade** | Alta |
| **Origem** | Notas de discovery ("a gestora... pede trilha que prove quem alterou lista de restrição") |
| **Critérios de aceite** | Amostragem de auditoria mensal da gestora não encontra alteração sem autor identificado. |
| **Dependência arquitetural** | — |

### NFR-PRIV-01 - Acesso restrito ao extrato de viagens

| Campo | Conteúdo |
|---|---|
| **Categoria** | Privacidade |
| **Descrição** | O extrato de viagens do app do passageiro (J-04) é acessível apenas ao titular do cartão tokenizado correspondente. |
| **Meta** | 100% das consultas de extrato autenticadas e vinculadas ao titular; zero acesso de terceiro sem autorização do titular. |
| **Método de medição** | Teste de autorização negativa (tentativa de acesso ao extrato de outro titular). |
| **Fonte de dados** | Log de acesso ao endpoint de extrato. |
| **Escopo** | App do passageiro, API de extrato, fluxo J-04. |
| **Prioridade** | Alta |
| **Origem** | R-03 |
| **Critérios de aceite** | Pentest não encontra caminho para acessar extrato de titular diferente do autenticado. |
| **Dependência arquitetural** | — |

### NFR-PRIV-02 - Minimização e mascaramento de dados pessoais

| Campo | Conteúdo |
|---|---|
| **Categoria** | Privacidade |
| **Descrição** | Dados pessoais coletados (associados ao cartão tokenizado, ao veículo, ao horário) são o mínimo necessário para os fluxos J-01 a J-04, e nunca aparecem em log sem mascaramento. |
| **Meta** | Zero ocorrências de PII sem mascaramento em log, trace ou mensagem de erro. |
| **Método de medição** | Scan de logs por padrão de PII (CPF, nome, PAN) + revisão de mapa de classificação de dados. |
| **Fonte de dados** | Amostra de logs de produção, mapa de classificação de dados. |
| **Escopo** | Backend de liquidação, portal, app. |
| **Prioridade** | Alta |
| **Origem** | R-03 |
| **Critérios de aceite** | Scan de logs pré-release sem PII não mascarada. |
| **Dependência arquitetural** | — |

### NFR-COMP-01 - Conformidade PCI DSS 4.0.1

| Campo | Conteúdo |
|---|---|
| **Categoria** | Compliance |
| **Descrição** | Todo componente que manipula dados de cartão (validador, backend, integração com adquirente) opera dentro dos controles de PCI DSS 4.0.1. |
| **Meta** | Zero findings críticos/altos abertos em auditoria/QSA relacionados ao escopo do validador. |
| **Método de medição** | Auditoria PCI DSS 4.0.1 (QSA) e scan de vulnerabilidade do escopo de cartão. |
| **Fonte de dados** | Relatório de auditoria/ASV scan. |
| **Escopo** | Validador embarcado, backend de liquidação, integração com adquirente. |
| **Prioridade** | Alta |
| **Origem** | R-02 |
| **Critérios de aceite** | Certificação/atestado PCI DSS 4.0.1 válido para o escopo do validador. |
| **Dependência arquitetural** | — |

### NFR-COMP-02 - Conformidade LGPD

| Campo | Conteúdo |
|---|---|
| **Categoria** | Compliance |
| **Descrição** | Tratamento de dados pessoais do passageiro (extrato, identificação por cartão tokenizado) segue base legal documentada e direitos do titular. |
| **Meta** | 100% das categorias de dado pessoal com base legal documentada; direitos de acesso/correção/portabilidade/esquecimento implementados para o extrato de viagens. |
| **Método de medição** | Revisão de conformidade LGPD (checklist de bases legais e direitos do titular). |
| **Fonte de dados** | Registro de bases legais, funcionalidade de exercício de direitos no app. |
| **Escopo** | Dados pessoais associados ao cartão tokenizado e ao extrato de viagens. |
| **Prioridade** | Alta |
| **Origem** | R-03 |
| **Critérios de aceite** | Checklist de conformidade LGPD sem pendência para os fluxos J-04. |
| **Dependência arquitetural** | — |

### NFR-COMP-03 - Auditabilidade da conciliação com a adquirente

| Campo | Conteúdo |
|---|---|
| **Categoria** | Compliance |
| **Descrição** | O arquivo de conciliação diária trocado com a adquirente deve ser auditável e reconciliável linha a linha com as transações agregadas do backend. |
| **Meta** | 100% dos arquivos de conciliação diária conferidos automaticamente contra o lote agregado gerado internamente, com discrepância zero tolerada sem investigação. |
| **Método de medição** | Job de conciliação automática comparando arquivo da adquirente versus lote interno. |
| **Fonte de dados** | Arquivo de conciliação da adquirente, lote agregado interno (J-02). |
| **Escopo** | Processo de liquidação diária, fluxo J-02. |
| **Prioridade** | Alta |
| **Origem** | R-05, J-02, OBJ-03 |
| **Critérios de aceite** | Toda discrepância de conciliação gera alerta e é investigada em até um dia útil. |
| **Dependência arquitetural** | — |

### NFR-OBS-01 - Três pilares de observabilidade no backend

| Campo | Conteúdo |
|---|---|
| **Categoria** | Observabilidade |
| **Descrição** | O backend de liquidação expõe métricas, logs estruturados e traces distribuídos para os fluxos críticos (J-01/J-02). |
| **Meta** | Métricas (`http_requests_total`, `http_request_duration_seconds` p50/p95/p99, contagem de validações processadas), logs JSON estruturados e traces via OpenTelemetry implementados em 100% dos serviços do backend. |
| **Método de medição** | Revisão de configuração de instrumentação + verificação de dashboards/Grafana. |
| **Fonte de dados** | Configuração de métricas/logs/traces do serviço. |
| **Escopo** | Backend de liquidação, API do portal e do app. |
| **Prioridade** | Alta |
| **Origem** | Inferência Não Funcional (baseline vinculante de `.forge/rules/architecture/observability.md`) |
| **Critérios de aceite** | Nenhum serviço do backend vai a produção sem os três pilares implementados (checklist de release). |
| **Dependência arquitetural** | — |

### NFR-OBS-02 - CorrelationId e mascaramento de dados sensíveis em telemetria

| Campo | Conteúdo |
|---|---|
| **Categoria** | Observabilidade |
| **Descrição** | Todo request ao backend recebe e propaga `correlationId`; PAN e PII nunca aparecem em log/trace sem mascaramento. |
| **Meta** | 100% dos logs e traces com `correlationId`; zero ocorrências de PAN/PII não mascarada em telemetria (mesma meta de NFR-PRIV-02, aplicada à camada de observabilidade). |
| **Método de medição** | Scan automatizado de logs/traces por padrão de PAN/PII e verificação de presença de `correlationId`. |
| **Fonte de dados** | Amostra de logs/traces de produção. |
| **Escopo** | Backend de liquidação, portal, app. |
| **Prioridade** | Alta |
| **Origem** | Inferência Não Funcional (baseline vinculante de `.forge/rules/architecture/observability.md` e `pii-pci-classification.md`) |
| **Critérios de aceite** | Scan pré-release sem violação de mascaramento; `correlationId` presente em 100% da amostra. |
| **Dependência arquitetural** | — |

### NFR-OBS-03 - Alertas sobre degradação de KPI

| Campo | Conteúdo |
|---|---|
| **Categoria** | Observabilidade |
| **Descrição** | Degradação de latência (KPI-01), taxa de recusa técnica (KPI-02) ou disponibilidade (R-04) deve gerar alerta acionável antes de virar incidente visível ao usuário. |
| **Meta** | Alerta disparado quando p95 de latência > 500 ms por mais de 5 minutos consecutivos, taxa de recusa técnica > 0,5% em janela de 1 h, ou indisponibilidade detectada por mais de 1 minuto. |
| **Método de medição** | Revisão de regras de alerta versionadas (alerts-as-code) e simulação de degradação. |
| **Fonte de dados** | Configuração de alertas (Prometheus/Grafana) versionada em repositório. |
| **Escopo** | Backend de liquidação, validadores (telemetria agregada). |
| **Prioridade** | Alta |
| **Origem** | Proposto pelo NFRD — validar com produto (thresholds de janela de 5 min/1 h não vêm do PRD; metas de KPI/SLA vêm de KPI-01, KPI-02, R-04) |
| **Critérios de aceite** | Simulação de degradação dispara alerta dentro da janela definida, sem falso negativo. |
| **Dependência arquitetural** | — |

### NFR-AUD-01 - Trilha imutável de alteração da lista de restrição

| Campo | Conteúdo |
|---|---|
| **Categoria** | Auditoria |
| **Descrição** | Toda alteração na lista de restrição usada pela validação local (J-01) é registrada de forma imutável, com quem, quando e o que mudou. |
| **Meta** | 100% das alterações registradas em trilha append-only, com autor, timestamp e diff da alteração; retenção mínima compatível com a auditoria mensal por amostragem (retenção exata é Ponto a Validar). |
| **Método de medição** | Auditoria da trilha versus lista de mudanças reais (teste de integridade); tentativa de alteração/exclusão de registro de auditoria deve falhar. |
| **Fonte de dados** | Tabela/log de auditoria append-only da lista de restrição. |
| **Escopo** | Serviço de gestão da lista de restrição. |
| **Prioridade** | Alta |
| **Origem** | Notas de discovery ("a gestora audita as validações por amostragem mensal e pede trilha que prove quem alterou lista de restrição") |
| **Critérios de aceite** | Auditoria mensal da gestora encontra 100% das alterações rastreadas, sem lacuna. |
| **Dependência arquitetural** | ADR-NNNN sugerido — `padrao-trilha-auditoria-imutavel` (a ser criado via `adr-writer`) — ver §3 abaixo. |

### NFR-AUD-02 - Trilha de deploy de firmware nos validadores

| Campo | Conteúdo |
|---|---|
| **Categoria** | Auditoria |
| **Descrição** | Trocas de firmware realizadas pelo time de campo na garagem devem ficar registradas (quem, quando, versão, validador) mesmo ocorrendo fora de uma janela formal. |
| **Meta** | 100% das trocas de firmware registradas com identificação do técnico, versão instalada, validador afetado e timestamp. |
| **Método de medição** | Auditoria da trilha de deploy versus inventário de versões de firmware efetivamente instaladas (checagem por amostragem). |
| **Fonte de dados** | Log de deploy de firmware do validador (a instrumentar). |
| **Escopo** | Todos os 1.200 validadores embarcados. |
| **Prioridade** | Média |
| **Origem** | Notas de discovery ("o time de campo troca o firmware dos validadores na garagem, à noite, sem janela formal") |
| **Critérios de aceite** | Amostragem de validadores em campo não encontra versão de firmware sem registro correspondente na trilha. |
| **Dependência arquitetural** | — |

### NFR-AUD-03 - Retenção da trilha de auditoria

| Campo | Conteúdo |
|---|---|
| **Categoria** | Auditoria |
| **Descrição** | A trilha de auditoria (lista de restrição, firmware, acesso a dados de pagamento) deve ser retida por prazo suficiente para a auditoria mensal por amostragem e para requisitos regulatórios. |
| **Meta** | Prazo de retenção — Proposto pelo NFRD — validar com produto; nenhum prazo consta no PRD ou nas notas de discovery. |
| **Método de medição** | Verificação de política de retenção configurada versus prazo definido. |
| **Fonte de dados** | Configuração de retenção do armazenamento de auditoria. |
| **Escopo** | Toda trilha de auditoria do sistema. |
| **Prioridade** | Média |
| **Origem** | Proposto pelo NFRD — validar com produto |
| **Critérios de aceite** | Prazo de retenção definido e configurado cobre pelo menos um ciclo completo de auditoria mensal da gestora. |
| **Dependência arquitetural** | — |

### NFR-INT-01 - Idempotência no envio de lotes ao backend e à adquirente

| Campo | Conteúdo |
|---|---|
| **Categoria** | Interoperabilidade |
| **Descrição** | Reenvio de lotes de validação após reconexão (NFR-RES-01) ou retry de cobrança à adquirente (J-02) não pode gerar duplicidade de cobrança ao passageiro nem de crédito à gestora. |
| **Meta** | Zero cobranças duplicadas decorrentes de reenvio; 100% das submissões de lote com chave de idempotência. |
| **Método de medição** | Teste de reenvio duplicado proposital (replay) verificando ausência de efeito duplicado. |
| **Fonte de dados** | Log de submissão de lote com chave de idempotência e resultado. |
| **Escopo** | Envio de lotes do validador ao backend, submissão de cobrança do backend à adquirente. |
| **Prioridade** | Alta |
| **Origem** | Inferência Não Funcional (decorre de R-01 + J-02: reenvio após offline de até 72 h cria risco de duplicidade) |
| **Critérios de aceite** | Teste de replay de lote não gera cobrança duplicada nem crédito duplicado. |
| **Dependência arquitetural** | ADR-NNNN sugerido — `padrao-idempotencia-envio-lotes` (a ser criado via `adr-writer`) — ver §3 abaixo. |

### NFR-INT-02 - Versionamento do contrato com a adquirente

| Campo | Conteúdo |
|---|---|
| **Categoria** | Interoperabilidade |
| **Descrição** | A integração com a API REST da adquirente e o formato do arquivo de conciliação diária devem ser versionados para permitir evolução sem quebra. |
| **Meta** | 100% dos contratos de integração (API e arquivo de conciliação) versionados, com changelog de mudança incompatível comunicado com antecedência mínima definida pela adquirente. |
| **Método de medição** | Revisão do contrato/schema versionado e teste de compatibilidade retroativa (contract testing). |
| **Fonte de dados** | Especificação de contrato/schema da integração. |
| **Escopo** | Integração com a adquirente, fluxo J-02. |
| **Prioridade** | Média |
| **Origem** | R-05 |
| **Critérios de aceite** | Mudança de versão do contrato não quebra processamento de lotes anteriores sem plano de migração documentado. |
| **Dependência arquitetural** | — |

### NFR-USA-01 - Usabilidade mensurável do portal e do app

| Campo | Conteúdo |
|---|---|
| **Categoria** | Usabilidade e acessibilidade |
| **Descrição** | O PRD declara como premissa que "o portal da gestora e o app do passageiro devem ser rápidos e fáceis de usar" (§8), mas não fornece meta verificável. |
| **Meta** | Meta numérica de usabilidade (ex.: tempo de tarefa, taxa de sucesso de consulta) — Proposto pelo NFRD — validar com produto. |
| **Método de medição** | Teste de usabilidade com usuários reais (operador da gestora e passageiro) medindo tempo de tarefa e taxa de sucesso. |
| **Fonte de dados** | Sessões de teste de usabilidade, analytics de uso do portal/app. |
| **Escopo** | Portal da gestora (J-03), app do passageiro (J-04). |
| **Prioridade** | Baixa |
| **Origem** | PRD §8 (Premissas) — jargão não verificável na origem, meta concreta é inferência do NFRD |
| **Critérios de aceite** | Meta de usabilidade definida com produto e validada em teste com usuários antes do release. |
| **Dependência arquitetural** | — |

### NFR-MAN-01 - Cobertura de testes e testabilidade

| Campo | Conteúdo |
|---|---|
| **Categoria** | Manutenibilidade |
| **Descrição** | O backend de liquidação e a lógica de validação/agregação de tarifas devem seguir os thresholds de cobertura já vinculantes no projeto, dado o caráter financeiro do domínio. |
| **Meta** | Cobertura de linha ≥ 95% e branch ≥ 90% em Domain; linha ≥ 85% e branch ≥ 80% em Application; linha ≥ 70% em Infrastructure (thresholds de `.forge/rules/testing/quality-gates.md`). |
| **Método de medição** | Relatório de cobertura em CI por camada. |
| **Fonte de dados** | Ferramenta de cobertura de testes do pipeline de CI. |
| **Escopo** | Backend de liquidação (Domain/Application/Infrastructure). |
| **Prioridade** | Alta |
| **Origem** | Inferência Não Funcional (baseline vinculante de `.forge/rules/testing/quality-gates.md`, aplicável por se tratar de lógica financeira) |
| **Critérios de aceite** | Pipeline de CI falha build que não atinge os thresholds por camada. |
| **Dependência arquitetural** | — |

### NFR-OPS-01 - Backup e recuperação de dados de liquidação

| Campo | Conteúdo |
|---|---|
| **Categoria** | Operabilidade |
| **Descrição** | Dados de transação, conciliação e auditoria devem ter backup recuperável, dado o impacto financeiro de perda (OBJ-03, incidente de 2025). |
| **Meta** | Frequência de backup e teste de restauração — Proposto pelo NFRD — validar com produto; nenhum valor consta no PRD. |
| **Método de medição** | Drill de restauração de backup cronometrado e verificado (integridade dos dados restaurados). |
| **Fonte de dados** | Log de execução de backup e de drill de restauração. |
| **Escopo** | Dados de transação, conciliação e auditoria do backend. |
| **Prioridade** | Alta |
| **Origem** | Proposto pelo NFRD — validar com produto (motivado por OBJ-03 e pela nota de discovery sobre a queda de 2025) |
| **Critérios de aceite** | Drill de restauração recorrente recupera dados dentro do RPO a ser definido em NFR-RES-02. |
| **Dependência arquitetural** | Mesma dependência de NFR-RES-02 (ADR-NNNN — `estrategia-dr-backend-liquidacao`). |

### NFR-OPS-02 - Janela formal de atualização de firmware

| Campo | Conteúdo |
|---|---|
| **Categoria** | Operabilidade |
| **Descrição** | A prática atual de trocar firmware na garagem à noite sem janela formal deve evoluir para um processo de change management com aprovação e comunicação prévias. |
| **Meta** | 100% das atualizações de firmware associadas a uma janela de manutenção formalmente aprovada e comunicada — critério de aprovação é Ponto a Validar. |
| **Método de medição** | Auditoria de correspondência entre trocas de firmware registradas (NFR-AUD-02) e janelas formalmente aprovadas. |
| **Fonte de dados** | Registro de change management + trilha de deploy de firmware. |
| **Escopo** | Processo operacional do time de campo. |
| **Prioridade** | Média |
| **Origem** | Notas de discovery ("o time de campo troca o firmware... sem janela formal") |
| **Critérios de aceite** | Nenhuma troca de firmware sem janela formal associada, a partir da adoção do processo. |
| **Dependência arquitetural** | — |

### NFR-OPS-03 - Retenção de dados de transação

| Campo | Conteúdo |
|---|---|
| **Categoria** | Operabilidade |
| **Descrição** | Dados de transação de validação e conciliação devem ser retidos por prazo que atenda auditoria da gestora e obrigações regulatórias, sem violar minimização de dados (NFR-PRIV-02). |
| **Meta** | Prazo de retenção — Proposto pelo NFRD — validar com produto; nenhum prazo consta no PRD. |
| **Método de medição** | Verificação de política de retenção/expurgo configurada. |
| **Fonte de dados** | Configuração de retenção do armazenamento de transações. |
| **Escopo** | Dados de transação e conciliação do backend. |
| **Prioridade** | Média |
| **Origem** | Proposto pelo NFRD — validar com produto |
| **Critérios de aceite** | Prazo de retenção definido, documentado e não conflitante com LGPD (NFR-PRIV-02/NFR-COMP-02). |
| **Dependência arquitetural** | — |

## 9. Restrições Técnicas Não Funcionais

- Comunicação com a adquirente exclusivamente via a API REST dela, com TLS ≥ 1.2 (origem: R-05, NFR-SEG-02).
- PAN nunca armazenado em claro em nenhum componente (origem: R-02, NFR-SEG-01).
- Validador deve suportar operação totalmente desconectada por até 72 h (origem: R-01, NFR-RES-01).
- Extrato do passageiro acessível apenas ao titular (origem: R-03, NFR-PRIV-01).
- Logs nunca contêm PAN/PII sem mascaramento, por baseline vinculante do projeto (origem: `.forge/rules/architecture/observability.md` e `pii-pci-classification.md`, NFR-OBS-02/NFR-PRIV-02).

## 10. Matriz de Rastreabilidade PRD → NFRD

| Item do PRD | NFRs relacionados | Cobertura |
|---|---|---|
| OBJ-01 (30% validações EMV em 12 meses) | NFR-ESC-01 | Indireta — capacidade para sustentar crescimento de adoção |
| OBJ-02 (reduzir tempo de embarque) | NFR-PERF-01 | Direta |
| OBJ-03 (zerar perda de receita por validações não liquidadas) | NFR-COMP-03, NFR-RES-01, NFR-OPS-01 | Direta |
| KPI-01 (validação ≤ 500 ms p95) | NFR-PERF-01 | Direta |
| KPI-02 (recusa técnica < 0,5%) | NFR-PERF-03 | Direta |
| KPI-03 (100% offline sincronizado em 24 h) | NFR-RES-01 | Direta |
| Volumetria (900 mil/dia, pico 250/s, crescimento 20%/ano) | NFR-PERF-02, NFR-ESC-01 | Direta |
| J-01 (validação local offline-first) | NFR-RES-01, NFR-SEG-04, NFR-AUD-01 | Direta |
| J-02 (agregação e cobrança diária à adquirente) | NFR-INT-01, NFR-INT-02, NFR-COMP-03 | Direta |
| J-03 (portal da gestora) | NFR-SEG-03, NFR-USA-01 | Direta |
| J-04 (extrato do passageiro no app) | NFR-PRIV-01, NFR-USA-01 | Direta |
| R-01 (offline até 72 h) | NFR-RES-01 | Direta |
| R-02 (PCI DSS 4.0.1, PAN nunca em claro) | NFR-SEG-01, NFR-COMP-01 | Direta |
| R-03 (LGPD, extrato só ao titular) | NFR-PRIV-01, NFR-PRIV-02, NFR-COMP-02 | Direta |
| R-04 (disponibilidade 99,5%/mês com multa) | NFR-DISP-01, NFR-DISP-02 | Direta |
| R-05 (integração REST com adquirente, conciliação diária) | NFR-SEG-02, NFR-INT-01, NFR-INT-02, NFR-COMP-03 | Direta |
| Premissa §8 (portal/app rápidos e fáceis) | NFR-USA-01 | Direta (meta em aberto) |
| Discovery — queda de 6 h em 2025 (perda de R$ 180 mil) | NFR-RES-02, NFR-OPS-01 | Direta |
| Discovery — auditoria mensal por amostragem / trilha de alteração da lista de restrição | NFR-AUD-01, NFR-AUD-03 | Direta |
| Discovery — troca de firmware na garagem sem janela formal | NFR-AUD-02, NFR-OPS-02 | Direta |

Nenhum NFR ficou sem item de origem no PRD ou nas notas de discovery, e nenhum item do PRD com implicação de qualidade ficou sem NFR associado.

## 11. Critérios de Validação Não Funcional

| Categoria | Como validar | Quando |
|---|---|---|
| Performance | Teste de carga com perfil de tráfego real (pico 6h–8h) | Pré-release e recorrente (trimestral) |
| Disponibilidade | Monitoramento de uptime contínuo + relatório mensal de SLA | Contínuo (produção) |
| Escalabilidade | Teste de capacidade anual com projeção de crescimento | Anual, antes do ciclo de budget de infraestrutura |
| Resiliência | Teste de chaos (desconexão simulada) + DR drill | Pré-release e recorrente (semestral para DR drill) |
| Segurança | Pentest + scan de dados sensíveis + scan de TLS | Pré-release e recorrente (anual para pentest completo) |
| Privacidade | Revisão de conformidade LGPD + scan de PII em logs | Pré-release e recorrente (semestral) |
| Compliance | Auditoria/certificação PCI DSS 4.0.1 (QSA) + checklist LGPD | Anual (certificação) e contínuo (checklist) |
| Observabilidade | Checklist de release dos três pilares + simulação de degradação para alertas | Em CI/CD (checklist) e pré-release (simulação) |
| Auditoria | Auditoria de integridade da trilha (tentativa de alteração/exclusão) | Recorrente (mensal, alinhado à auditoria da gestora) |
| Interoperabilidade | Contract testing + teste de replay de idempotência | Em CI/CD |
| Usabilidade | Teste de usabilidade com usuários reais | Antes do release, após definição de meta com produto |
| Manutenibilidade | Relatório de cobertura por camada em CI | Em CI/CD, todo build |
| Operabilidade | Drill de restauração de backup + auditoria de change management de firmware | Recorrente (semestral para backup; mensal para firmware) |

## 12. Dependências

- Definição de RTO/RPO do backend de liquidação (NFR-RES-02) depende de decisão de produto/arquitetura ainda não tomada.
- Meta de usabilidade (NFR-USA-01) depende de rodada de teste com usuários, ainda não agendada nesta base.
- Prazo de retenção de auditoria (NFR-AUD-03) e de dados de transação (NFR-OPS-03) dependem de definição conjunta entre produto, jurídico (LGPD) e a gestora contratante.
- Este NFRD não pôde checar consistência com um FRD, pois `docs/product/frd-nfrd/frd.md` não existe nesta base.

## 13. Premissas

- Assume-se que o backend de liquidação é um serviço novo (greenfield), sem PRD ou FRD anteriores nesta base que definam requisitos não funcionais prévios além dos aqui derivados.
- Assume-se que "backend" no PRD cobre tanto o serviço de recepção/agregação de validações quanto o portal da gestora e a API do app do passageiro, por serem os únicos componentes server-side citados nas jornadas J-02/J-03/J-04.
- Assume-se que a antecedência de comunicação de manutenção planejada (NFR-DISP-02) e o critério de aprovação de janela de firmware (NFR-OPS-02) serão definidos em processo de change management a criar, não existente nesta base.

## 14. Pontos a Validar

| O que falta decidir | Quem decide | Impacto se não decidido |
|---|---|---|
| RTO/RPO do backend de liquidação (NFR-RES-02) | Produto + Arquitetura/SRE | Sem meta, o próximo incidente como o de 2025 não tem critério objetivo de tempo de recuperação nem de perda de dados aceitável |
| Frequência de backup e teste de restauração (NFR-OPS-01) | Arquitetura/SRE | Sem definição, backup pode existir sem garantia de recuperação testada |
| Meta numérica de usabilidade do portal/app (NFR-USA-01) | Produto + UX | "Rápido e fácil" permanece não verificável; risco de retrabalho de UX pós-lançamento |
| Prazo de retenção da trilha de auditoria (NFR-AUD-03) | Produto + Jurídico/LGPD | Retenção insuficiente compromete auditoria mensal da gestora; excessiva conflita com minimização de dados |
| Prazo de retenção de dados de transação (NFR-OPS-03) | Produto + Jurídico/LGPD | Mesmo risco de NFR-AUD-03, aplicado a dados transacionais |
| Antecedência mínima de comunicação de manutenção planejada (NFR-DISP-02) | Produto + Operação | Sem critério, manutenção pode ser tratada como indisponibilidade não planejada, afetando o SLA de 99,5% |
| Critério de aprovação da janela formal de firmware (NFR-OPS-02) | Operação de campo + Segurança | Sem processo, a prática atual de troca noturna sem janela formal persiste, mantendo o risco identificado em discovery |
| Threshold exato de antecedência para versionamento incompatível do contrato com a adquirente (NFR-INT-02) | Arquitetura + relação comercial com a adquirente | Mudança de contrato pela adquirente sem aviso suficiente pode quebrar conciliação (J-02) |
| Ausência de FRD nesta base para checagem cruzada funcional ↔ não funcional | Produto | Requisitos funcionais implícitos nas jornadas do PRD podem não ter contrapartida funcional formalizada, dificultando validação cruzada |

## 15. Anexos

Nenhum anexo adicional nesta versão.

---

## ADRs Sugeridos (delegação a adr-writer)

| ID sugerido | Título proposto | Origem (NFR) | Severidade | Justificativa breve |
|---|---|---|---|---|
| ADR-NNNN | `estrategia-dr-backend-liquidacao` | NFR-RES-02 | Alta | Define RTO/RPO e estratégia de recuperação de desastre — decisão durável com custo de reversão alto, motivada por incidente real de 2025 com perda de R$ 180 mil. |
| ADR-NNNN | `padrao-idempotencia-envio-lotes` | NFR-INT-01 | Alta | Mecanismo transversal de idempotência para reenvio de lotes após offline/retry — risco de cobrança ou crédito duplicado se não padronizado. |
| ADR-NNNN | `padrao-trilha-auditoria-imutavel` | NFR-AUD-01 | Média | Mecanismo transversal de trilha de auditoria append-only, aplicável não só à lista de restrição mas potencialmente a outras entidades sensíveis do domínio. |
