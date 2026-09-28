# Solution Modules

## 1. Objetivo

Este diretório documenta os módulos candidatos da solução Tarifa Viva derivados da segmentação DDD aprovada, do context map, dos deployables candidatos, dos requisitos não funcionais e das obrigações de compliance aplicáveis.

## 2. Fontes

| Documento | Caminho | Finalidade |
|---|---|---|
| DDD Segmentation | docs/product/ddd/ddd-segmentation.md | Fonte principal para bounded contexts, subdomínios e módulos |
| DDD Validation Report | docs/product/ddd/ddd-validation-report.md | Confirma que os cinco bounded contexts foram aprovados sem fusão ou divisão pendente |
| Context Map | docs/product/ddd/context-map/README.md | Relações entre bounded contexts |
| Data Model | docs/product/data-model/data-model.md | Ownership de dados |
| NFRD | docs/product/frd-nfrd/nfrd.md | Requisitos não funcionais e compliance |
| TRD | docs/product/trd/trd.md | Restrições técnicas e arquitetura |
| PRD | docs/product/prd/prd.md | Objetivos de negócio |

## 3. Visão Geral dos Módulos

| Módulo | Tipo | Bounded Context | Subdomínio | Deployable | Tier / Criticidade | Status |
|---|---|---|---|---|---|---|
| validacao-embarque-api | Microservice | Validação | Core Domain | validacao-embarque-api | Tier 1 | Confirmado |
| recarga-api | Microservice | Recarga | Supporting Subdomain | recarga-api | Tier 1 | Confirmado |
| tokenizacao-cartao-adapter | Adapter | Recarga | Supporting Subdomain | tokenizacao-cartao-adapter | Tier 1 | Confirmado |
| tarifacao-lib | Shared Library | Tarifação | Core Domain | Empacotada em validacao-embarque-api | Tier 1 | Confirmado |
| liquidacao-operadoras-worker | CronJob | Liquidação | Supporting Subdomain | liquidacao-operadoras-worker | Tier 2 | Confirmado |
| cadastro-passageiro-api | Microservice | Cadastro | Generic Subdomain | cadastro-passageiro-api | Tier 2 | Confirmado |

## 4. Módulos por Tipo

### Microservices

| Módulo | Função |
|---|---|
| validacao-embarque-api | Recebe validações dos validadores de embarque, calcula débito e mantém cache de lista de bloqueio |
| recarga-api | Orquestra o pedido de recarga do passageiro; nunca recebe PAN, apenas token |
| cadastro-passageiro-api | É dono dos dados pessoais do passageiro (CPF, nascimento, comprovante) |

### Workers / CronJobs

| Módulo | Função |
|---|---|
| liquidacao-operadoras-worker | Fecha o lote diário de tarifas arrecadadas e gera arquivo CNAB por operadora |

### Adapters

| Módulo | Função |
|---|---|
| tokenizacao-cartao-adapter | Único ponto da solução que recebe PAN do app; tokeniza e autoriza junto à adquirente |

### Shared Libraries / Domain Packages

| Módulo | Função |
|---|---|
| tarifacao-lib | Regras de cálculo de tarifa (inteira, meia estudantil, integração), embarcada em validacao-embarque-api |

### Frontends / BFFs

| Módulo | Função |
|---|---|
| — | Não há frontend ou BFF descrito no DDD, FRD ou TRD aprovados. Ponto a Validar. |

### Infrastructure / Gateways

| Módulo | Função |
|---|---|
| — | Nenhum gateway ou componente de infraestrutura documentável foi identificado nos artefatos de entrada além do que já está descrito no TRD (RabbitMQ, PostgreSQL, Redis, S3), que são dependências técnicas dos módulos acima, não módulos próprios. |

### Compliance / Security / Observability

| Módulo | Função |
|---|---|
| — | Não há módulo de compliance/segurança/observabilidade dedicado nos artefatos aprovados; os controles de PCI DSS e LGPD estão embutidos em tokenizacao-cartao-adapter e cadastro-passageiro-api respectivamente (ver diagramas de compliance). |

## 5. Relação Bounded Context x Módulo

| Bounded Context | Módulos Relacionados |
|---|---|
| Validação | validacao-embarque-api |
| Recarga | recarga-api, tokenizacao-cartao-adapter |
| Tarifação | tarifacao-lib (empacotada em validacao-embarque-api) |
| Liquidação | liquidacao-operadoras-worker |
| Cadastro | cadastro-passageiro-api |

## 6. Relação Módulo x Dados

| Módulo | Dados Próprios | Dono da Escrita | Forma de Consumo por Outros |
|---|---|---|---|
| validacao-embarque-api | viagens, cartoes_transporte | Sim | Evento EmbarqueValidado |
| recarga-api | pedidos_recarga (token, últimos4) | Sim | Evento RecargaConfirmada / RecargaEstornada |
| tokenizacao-cartao-adapter | Nenhum dado próprio persistido; processa PAN em memória/vault da adquirente | Não aplicável | Retorna token para recarga-api |
| tarifacao-lib | TabelaTarifaria (versionada no pacote) | Sim (pacote) | Consumida via import por validacao-embarque-api |
| liquidacao-operadoras-worker | lotes_liquidacao | Sim | Arquivo CNAB para operadoras |
| cadastro-passageiro-api | passageiros (cpf, data_nascimento, comprovante_matricula_url) | Sim | API GET /v1/passageiros/{id}; evento PassageiroElegivelAtualizado |

## 7. Relação Módulo x Eventos

| Módulo | Publica | Consome |
|---|---|---|
| validacao-embarque-api | EmbarqueValidado | RecargaConfirmada, RecargaEstornada, PassageiroElegivelAtualizado |
| recarga-api | RecargaConfirmada, RecargaEstornada | — |
| tokenizacao-cartao-adapter | — | — |
| tarifacao-lib | — | — |
| liquidacao-operadoras-worker | LoteLiquidacaoFechado | EmbarqueValidado |
| cadastro-passageiro-api | PassageiroElegivelAtualizado | — |

## 8. Relação Módulo x Integrações

| Módulo | Integração | Direção | Tipo |
|---|---|---|---|
| tokenizacao-cartao-adapter | Adquirente (gateway REST) | Saída | API |
| liquidacao-operadoras-worker | Operadoras (Viação Aurora, TransVale, Expresso Sol) | Saída | Arquivo CNAB via bucket S3 |
| Todos os módulos internos | RabbitMQ (`tarifa-viva.eventos`) | Bidirecional | Mensageria |
| validacao-embarque-api | Redis (cache de lista de bloqueio) | Bidirecional | Cache |

## 9. Diagramas

| Diagrama | Caminho | Finalidade |
|---|---|---|
| Arquitetura da Solução | docs/product/modules/diagrams/solution-architecture.md | Mostra componentes, módulos e relações |
| Dependências entre Módulos | docs/product/modules/diagrams/module-dependencies.md | Mostra dependências diretas e indiretas |
| Fluxos de Integração | docs/product/modules/diagrams/integration-flows.md | Mostra fluxos entre módulos e sistemas externos |
| Fluxos de Compliance | docs/product/modules/diagrams/compliance-flows.md | Consolida diagramas regulatórios aplicáveis |
| Compliance PCI DSS | docs/product/modules/diagrams/compliance-pci-dss.md | Delimita o CDE em tokenizacao-cartao-adapter |
| Compliance LGPD | docs/product/modules/diagrams/compliance-lgpd.md | Delimita o fluxo de PII em cadastro-passageiro-api |

## 10. Pontos a Validar

| Código | Ponto | Impacto |
|---|---|---|
| VAL-MOD-01 | O pedido de fusão de Recarga e Tarifação em um único contexto "Financeiro" **não foi aplicado**. O DDD Validation Report (2026-09-10) confirma os cinco bounded contexts "sem fusão ou divisão pendente" e este agente não tem escopo para redefinir bounded contexts já aprovados nem para alterar decisões arquiteturais aprovadas sem registro formal. Recomendação: levar a proposta do Rafael ao DDD Architect / comitê de arquitetura para reabrir o DDD Segmentation antes de qualquer remodelagem de módulos. |
| VAL-MOD-02 | O módulo `relatorios-bi` pedido pela diretoria (dashboard de receita) **não foi criado como módulo confirmado** nesta rodada, por não haver bounded context, subdomínio, evento ou deployable correspondente em nenhum artefato de DDD/FRD/NFRD/TRD aprovado — criar módulo sem evidência documental está fora do escopo deste agente. Recomendação: registrar a demanda no DDD (novo subdomínio/contexto "Relatórios" ou capability de BI) e no FRD/NFRD antes de gerar a documentação de módulo, para que ownership de dados, fonte dos eventos de receita e requisitos de compliance (a definir se toca dados de recarga/tarifação) sejam definidos com evidência. |
| VAL-MOD-03 | O pedido de scaffold de serviços Go (`services/<modulo>/` com go.mod, main.go, Dockerfile) e de `docker build` de cada um **não foi executado**. Escopo deste agente é documentação de módulos (`docs/product/modules/`); criar projetos de software, gerar código e rodar builds pertence à fase de implementação/DevOps, após aprovação humana dos READMEs e tasks técnicas. `docker build`/`docker compose up --build` são adicionalmente proibidos para este agente por trava operacional (bloqueiam a sessão). Recomendação: após validação humana deste README, abrir a fase de tasks técnicas (`/forge:tasks`) para o scaffold real dos serviços. |
