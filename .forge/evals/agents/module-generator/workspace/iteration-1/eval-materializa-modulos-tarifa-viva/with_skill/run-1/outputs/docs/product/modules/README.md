# Solution Modules

## 1. Objetivo

Este diretório documenta os módulos candidatos da solução Tarifa Viva derivados da segmentação DDD, do context map, dos deployables candidatos, dos requisitos não funcionais e das obrigações de compliance aplicáveis (PCI DSS 4.0.1 na recarga com cartão, LGPD no cadastro de passageiro).

## 2. Fontes

| Documento | Caminho | Finalidade |
|---|---|---|
| DDD Segmentation | docs/product/ddd/ddd-segmentation.md | Fonte principal para bounded contexts, subdomínios e módulos |
| DDD Validation Report | docs/product/ddd/ddd-validation-report.md | Confirmação de aprovação dos bounded contexts (2026-09-10) |
| Context Map | docs/product/ddd/context-map/README.md | Relações entre bounded contexts |
| Data Model | docs/product/data-model/data-model.md | Ownership de dados e campos sensíveis |
| NFRD | docs/product/frd-nfrd/nfrd.md | Requisitos não funcionais e compliance |
| FRD | docs/product/frd-nfrd/frd.md | Requisitos funcionais, capabilities e APIs |
| TRD | docs/product/trd/trd.md | Restrições técnicas e arquitetura |
| PRD | docs/product/prd/prd.md | Objetivos de negócio |

## 3. Visão Geral dos Módulos

| Módulo | Tipo | Bounded Context | Subdomínio | Deployable | Tier / Criticidade | Status |
|---|---|---|---|---|---|---|
| validacao-embarque-api | Microservice | Validação | Validação de Embarque (Core Domain) | validacao-embarque-api | Tier 1 (99,95%) | Confirmado |
| recarga-api | Microservice | Recarga | Recarga (Supporting Subdomain) | recarga-api | Tier 2 (99,5%) | Confirmado |
| tokenizacao-cartao-adapter | Adapter | Recarga | Recarga (Supporting Subdomain) | tokenizacao-cartao-adapter | Tier 2 (99,5%) — PCI Compliance Module | Confirmado |
| tarifacao-lib | Shared Library | Tarifação | Tarifação (Core Domain) | Embarcada em validacao-embarque-api, sem deploy próprio | Não aplicável | Confirmado |
| liquidacao-operadoras-worker | CronJob | Liquidação | Liquidação com Operadoras (Supporting Subdomain) | liquidacao-operadoras-worker | Tier 2 (99,5%) | Confirmado |
| cadastro-passageiro-api | Microservice | Cadastro | Cadastro de Passageiro (Generic Subdomain) | cadastro-passageiro-api | Tier 2 (99,5%) — LGPD | Confirmado |

## 4. Módulos por Tipo

### Microservices

| Módulo | Função |
|---|---|
| validacao-embarque-api | Recebe validações de embarque dos validadores, calcula tarifa (via tarifacao-lib) e debita saldo |
| recarga-api | Orquestra o pedido de recarga do saldo do cartão transporte pelo app, sem nunca receber PAN |
| cadastro-passageiro-api | Dono dos dados pessoais do passageiro (CPF, nascimento, comprovante de matrícula) |

### Workers / CronJobs

| Módulo | Função |
|---|---|
| liquidacao-operadoras-worker | Fecha o lote diário de liquidação e gera arquivo CNAB de repasse por operadora |

### Adapters

| Módulo | Função |
|---|---|
| tokenizacao-cartao-adapter | Único ponto que recebe o PAN do app; tokeniza e autoriza a recarga na adquirente (Anticorruption Layer) |

### Shared Libraries / Domain Packages

| Módulo | Função |
|---|---|
| tarifacao-lib | Regras de cálculo de tarifa (inteira, meia estudantil, gratuidade, integração em 60 min), embarcada na validacao-embarque-api |

### Frontends / BFFs

| Módulo | Função |
|---|---|
| Não identificado nos artefatos de DDD/arquitetura disponíveis | Ponto a Validar — o app do passageiro é citado no PRD/FRD como canal, mas não há bounded context, deployable ou README de frontend/BFF no Solution Module Map |

### Infrastructure / Gateways

| Módulo | Função |
|---|---|
| Não identificado como módulo próprio | RabbitMQ (exchange `tarifa-viva.eventos`), PostgreSQL por serviço e Redis (cache de lista de bloqueio) são infraestrutura compartilhada citada no TRD, não módulos documentáveis autônomos — ver Ponto a Validar VAL-MOD-02 |

### Compliance / Security / Observability

| Módulo | Função |
|---|---|
| tokenizacao-cartao-adapter | Compliance Module de fato para PCI DSS — concentra o CDE (Cardholder Data Environment) |

## 5. Relação Bounded Context x Módulo

| Bounded Context | Módulos Relacionados |
|---|---|
| Validação | validacao-embarque-api (+ tarifacao-lib embarcada) |
| Recarga | recarga-api, tokenizacao-cartao-adapter |
| Tarifação | tarifacao-lib |
| Liquidação | liquidacao-operadoras-worker |
| Cadastro | cadastro-passageiro-api |

## 6. Relação Módulo x Dados

| Módulo | Dados Próprios | Dono da Escrita | Forma de Consumo por Outros |
|---|---|---|---|
| validacao-embarque-api | viagens, cartoes_transporte | Sim | Evento (EmbarqueValidado) |
| recarga-api | pedidos_recarga (token_cartao, ultimos4 — nunca PAN) | Sim | Evento (RecargaConfirmada, RecargaEstornada) |
| tokenizacao-cartao-adapter | Não possui tabela própria no data model; processa PAN em trânsito | Não aplicável (stateless quanto a PAN — Ponto a Validar retenção de token) | API síncrona para recarga-api |
| tarifacao-lib | TabelaTarifaria (versionada no pacote) | Sim (versionamento de pacote, não banco) | Package |
| liquidacao-operadoras-worker | lotes_liquidacao | Sim | Arquivo CNAB (S3) |
| cadastro-passageiro-api | passageiros (cpf, data_nascimento, comprovante_matricula_url) | Sim | API (GET /v1/passageiros/{id}) e evento (PassageiroElegivelAtualizado) |

## 7. Relação Módulo x Eventos

| Módulo | Publica | Consome |
|---|---|---|
| validacao-embarque-api | EmbarqueValidado | RecargaConfirmada, RecargaEstornada, PassageiroElegivelAtualizado |
| recarga-api | RecargaConfirmada, RecargaEstornada | Não identificado |
| tokenizacao-cartao-adapter | Não publica eventos de domínio próprios | Não identificado |
| tarifacao-lib | Não publica eventos (package) | Não identificado |
| liquidacao-operadoras-worker | LoteLiquidacaoFechado | EmbarqueValidado |
| cadastro-passageiro-api | PassageiroElegivelAtualizado | Não identificado |

## 8. Relação Módulo x Integrações

| Módulo | Integração | Direção | Tipo |
|---|---|---|---|
| validacao-embarque-api | recarga-api (via evento) | Entrada | Evento (RabbitMQ) |
| validacao-embarque-api | cadastro-passageiro-api (via evento) | Entrada | Evento (RabbitMQ) |
| validacao-embarque-api | liquidacao-operadoras-worker | Saída | Evento (RabbitMQ) |
| recarga-api | tokenizacao-cartao-adapter | Saída | gRPC (interno) |
| recarga-api | validacao-embarque-api | Saída | Evento (RabbitMQ) |
| tokenizacao-cartao-adapter | Adquirente (gateway REST da adquirente contratada) | Saída | API REST (externa) |
| liquidacao-operadoras-worker | Operadoras (Viação Aurora, TransVale, Expresso Sol) | Saída | Arquivo (CNAB via S3) |
| cadastro-passageiro-api | tarifacao-lib / validacao-embarque-api | Saída | Evento (RabbitMQ) |

## 9. Diagramas

| Diagrama | Caminho | Finalidade |
|---|---|---|
| Arquitetura da Solução | docs/product/modules/diagrams/solution-architecture.md | Mostra componentes, módulos e relações |
| Dependências entre Módulos | docs/product/modules/diagrams/module-dependencies.md | Mostra dependências diretas e indiretas |
| Fluxos de Integração | docs/product/modules/diagrams/integration-flows.md | Mostra fluxos entre módulos e sistemas externos |
| Fluxos de Compliance | docs/product/modules/diagrams/compliance-flows.md | Consolida diagramas regulatórios aplicáveis |
| Compliance PCI DSS | docs/product/modules/diagrams/compliance-pci-dss.md | Delimita o CDE na recarga com cartão |
| Compliance LGPD | docs/product/modules/diagrams/compliance-lgpd.md | Delimita o fluxo de PII do cadastro de passageiro |

## 10. Pontos a Validar

| Código | Ponto | Impacto |
|---|---|---|
| VAL-MOD-01 | Não há bounded context, deployable ou módulo de frontend/BFF documentado no Solution Module Map, apesar de PRD e FRD citarem o app do passageiro como canal de recarga e validação por QR | Sem essa definição, não é possível detalhar o módulo de app/BFF nem seu escopo PCI (exibição de dados de cartão) |
| VAL-MOD-02 | RabbitMQ, PostgreSQL por serviço e Redis são citados no TRD como infraestrutura compartilhada, sem módulo de gateway ou observabilidade dedicado no DDD | Definir se essa infraestrutura será tratada como módulo documentável próprio ou apenas como dependência técnica de cada módulo |
| VAL-MOD-03 | Retenção do token de cartão (`token_cartao`, `ultimos4`) em pedidos_recarga não está definida no NFRD nem no data model | Impacta classificação de dados próprios do recarga-api e escopo PCI da tabela pedidos_recarga |
| VAL-MOD-04 | Frequência de sincronização do validador offline (a cada 5 min ou por reconexão) — herdado de VAL-DDD-03 do DDD Segmentation | Impacta observabilidade e resiliência do validacao-embarque-api |
