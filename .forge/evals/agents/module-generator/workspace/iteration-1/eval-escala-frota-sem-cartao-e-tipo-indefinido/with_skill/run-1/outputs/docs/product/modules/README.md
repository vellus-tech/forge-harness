# Solution Modules

## 1. Objetivo

Este diretório documenta os módulos candidatos da solução Frota Certa, derivados da segmentação DDD (Solution Module Map e Data Ownership), do FRD, do NFRD e do PRD. O produto monta e publica a escala diária de motoristas e veículos da Viação Aurora, controla a jornada do motorista conforme a CLT e avisa o motorista da escala do dia seguinte; não processa pagamentos nem dados de cartão.

## 2. Fontes

| Documento | Caminho | Finalidade |
|---|---|---|
| DDD Segmentation | docs/product/ddd/ddd-segmentation.md | Fonte principal para bounded contexts, subdomínios, eventos e Solution Module Map |
| PRD | docs/product/prd/prd.md | Objetivo do produto e limites de escopo (sem pagamento/cartão) |
| FRD | docs/product/frd-nfrd/frd.md | Requisitos funcionais |
| NFRD | docs/product/frd-nfrd/nfrd.md | Requisitos não funcionais e compliance (LGPD, disponibilidade, não aplicabilidade de PCI) |

Não havia Context Map, Data Model, TRD, ADR ou Glossário disponíveis nesta base — os campos correspondentes foram preenchidos com a menor inferência arquitetural segura possível ou marcados como Ponto a Validar.

## 3. Visão Geral dos Módulos

| Módulo | Tipo | Bounded Context | Subdomínio | Deployable | Tier / Criticidade | Status |
|---|---|---|---|---|---|---|
| escalas-api | Microservice | Programação de Escalas | Core Domain | Sim | Tier 1 | Confirmado |
| publicador-escala-worker | CronJob | Programação de Escalas | Core Domain | Sim | Tier 1 | Confirmado |
| jornada-api | Microservice | Jornada do Motorista | Supporting Subdomain | Sim | Tier 1 | Confirmado |
| notificacao-motoristas | Ponto a Validar (Worker ou rota dentro de um BFF do painel) | Comunicação | Generic Subdomain | Ponto a Validar | Tier 2 | Ponto a Validar |
| painel-despachante-web | Frontend | — (consumidor de escalas-api e jornada-api) | — | Sim | Tier 2 | Confirmado |

## 4. Módulos por Tipo

### Microservices

| Módulo | Função |
|---|---|
| escalas-api | Monta, fecha e consulta a escala de motoristas e veículos; dono de Escala e Turno |
| jornada-api | Cadastra motoristas (CPF, CNH, telefone) e registra jornada, bloqueando excesso de 10h diárias |

### Workers / CronJobs

| Módulo | Função |
|---|---|
| publicador-escala-worker | Publica a escala fechada às 18:00 para o sistema de catraca da garagem |
| notificacao-motoristas | Ponto a Validar — ver observação abaixo. Se confirmado como worker, envia SMS/push ao motorista quando a escala mudar |

### Adapters

Nenhum adapter externo dedicado foi identificado com evidência suficiente nesta base (a integração com o sistema de catraca é tratada como parte do publicador-escala-worker — ver Ponto a Validar VAL-MOD-04).

### Shared Libraries / Domain Packages

Nenhuma biblioteca compartilhada foi identificada com evidência documental nesta base.

### Frontends / BFFs

| Módulo | Função |
|---|---|
| painel-despachante-web | Painel web onde o despachante monta a escala do dia seguinte |

Observação: o DDD cita a possibilidade de a notificação virar "uma rota dentro do painel-despachante-bff", mas nenhum BFF está listado no Solution Module Map como módulo confirmado. Não foi criado módulo `painel-despachante-bff` — criar um módulo novo sem evidência no Solution Module Map seria anti-pattern. Ver VAL-MOD-01.

### Infrastructure / Gateways

Nenhum gateway ou módulo de infraestrutura documentável foi identificado com evidência suficiente nesta base.

### Compliance / Security / Observability

Nenhum módulo de compliance, segurança ou observabilidade dedicado foi identificado como deployable candidato. Os requisitos de compliance (LGPD) são tratados como responsabilidade transversal do jornada-api e do notificacao-motoristas — ver diagrama de compliance LGPD.

## 5. Relação Bounded Context x Módulo

| Bounded Context | Módulos Relacionados |
|---|---|
| Programação de Escalas | escalas-api, publicador-escala-worker |
| Jornada do Motorista | jornada-api |
| Comunicação | notificacao-motoristas |
| — (consumidor, sem bounded context próprio) | painel-despachante-web |

## 6. Relação Módulo x Dados

| Módulo | Dados Próprios | Dono da Escrita | Forma de Consumo por Outros |
|---|---|---|---|
| escalas-api | Escala, Turno | Sim | API / Evento |
| publicador-escala-worker | Nenhum dado próprio (stateless) | Não | Não aplicável |
| jornada-api | Motorista (CPF, CNH, telefone), RegistroJornada | Sim | API / Evento |
| notificacao-motoristas | Nenhum dado próprio conhecido (Ponto a Validar) | Não | Não aplicável |
| painel-despachante-web | Nenhum dado próprio (stateless, consome API) | Não | Não aplicável |

## 7. Relação Módulo x Eventos

| Módulo | Publica | Consome |
|---|---|---|
| escalas-api | EscalaAlterada | JornadaExcedida |
| publicador-escala-worker | EscalaPublicada (Inferência Arquitetural — ver VAL-MOD-02) | — |
| jornada-api | JornadaExcedida | — |
| notificacao-motoristas | — | EscalaPublicada, EscalaAlterada |
| painel-despachante-web | — | — |

## 8. Relação Módulo x Integrações

| Módulo | Integração | Direção | Tipo |
|---|---|---|---|
| publicador-escala-worker | Sistema de catraca da garagem (externo) | Saída | API / Arquivo (Ponto a Validar — protocolo não especificado) |
| notificacao-motoristas | Provedor de SMS/push (externo) | Saída | API (Ponto a Validar — provedor não especificado) |
| painel-despachante-web | escalas-api | Saída | API |
| painel-despachante-web | jornada-api | Saída | API (Ponto a Validar — FR-02 não define o consumidor da consulta de escala do motorista; ver VAL-MOD-03) |

## 9. Diagramas

| Diagrama | Caminho | Finalidade |
|---|---|---|
| Arquitetura da Solução | docs/product/modules/diagrams/solution-architecture.md | Mostra componentes, módulos e relações |
| Dependências entre Módulos | docs/product/modules/diagrams/module-dependencies.md | Mostra dependências diretas e indiretas |
| Fluxos de Integração | docs/product/modules/diagrams/integration-flows.md | Mostra fluxos entre módulos e sistemas externos |
| Fluxos de Compliance | docs/product/modules/diagrams/compliance-flows.md | Consolida diagramas regulatórios aplicáveis |
| Compliance LGPD | docs/product/modules/diagrams/compliance-lgpd.md | Fluxo de dados pessoais (CPF, CNH, telefone) |

Não foi criado `compliance-pci-dss.md`: o NFR-03 declara explicitamente que o produto não trata dados de cartão nem movimenta dinheiro, e o PRD reforça a ausência de pagamento — não há obrigação PCI DSS aplicável.

## 10. Pontos a Validar

| Código | Ponto | Impacto |
|---|---|---|
| VAL-MOD-01 | O comitê ainda não decidiu se `notificacao-motoristas` é um worker próprio ou uma rota dentro do BFF do painel do despachante. Este documento não decide isso — ambas as formas continuam candidatas até deliberação do comitê. | Define se `notificacao-motoristas` permanece como módulo deployável independente (worker) ou se é absorvido como componente interno de um futuro `painel-despachante-bff` |
| VAL-MOD-02 | Não há evidência documental de qual módulo publica tecnicamente o evento `EscalaPublicada` — o DDD atribui a publicação ao bounded context "Programação de Escalas" como um todo. Atribuiu-se por inferência ao `publicador-escala-worker`, por ser o responsável funcional descrito (FR-03) | Pode mudar o dono técnico do evento e o ponto de emissão no diagrama de integração |
| VAL-MOD-03 | FR-02 ("Motorista consulta a escala do dia") não define o endpoint nem o canal de consumo (app do motorista? consulta via notificação?); "endpoint ainda não definido pela equipe de integração" | Impacta a API principal de `escalas-api` e a existência (ou não) de um canal dedicado ao motorista |
| VAL-MOD-04 | Não há especificação do protocolo de integração com o sistema de catraca da garagem (API, arquivo, mensageria) nem do provedor de SMS/push | Impacta as dependências técnicas de `publicador-escala-worker` e `notificacao-motoristas` |
| VAL-MOD-05 | Não há Context Map, Data Model, TRD ou ADR nesta base; nomes de tabelas/persistência e tecnologia de banco são Ponto a Validar em cada módulo | Impacta o detalhamento técnico das seções de Dados Próprios e Dependências Técnicas |
