# TRD - Tarifa Aberta

**Versão:** v1.0 | **Status:** Rascunho | **Fontes:** docs/product/prd/prd.md, docs/product/frd-nfrd/{frd,nfrd}.md, docs/product/ddd/ddd-segmentation.md, docs/product/modules/README.md, docs/product/adr/{0001,0002,0003}

## 1. Visão Técnica

O sistema Tarifa Aberta é composto por cinco módulos alinhados aos bounded contexts da segmentação DDD: `validator-gateway` (tap-capture), `fare-authorization` (fare-authorization), `deny-list` (deny-list), `rider-bff` (rider-history) e `settlement` (settlement). A comunicação síncrona entre esses serviços segue ADR-0002 (gRPC interno com contratos `.proto` versionados e mTLS). A superfície exposta ao app do passageiro e à adquirente segue ADR-0001 (REST/HTTPS ou troca de arquivo).

## 2. Componentes e Responsabilidades

| Módulo | Responsabilidade técnica | Requisitos atendidos |
|---|---|---|
| validator-gateway | Recebe o tap EMV, decide liberação (online/offline) consultando cache local da deny list | FRD-tap-01, FRD-tap-02, NFR-PERF-01 |
| fare-authorization | Agrega taps do dia por cartão e envia cobrança única à adquirente até 23h59 | FRD-aut-01, FRD-aut-02, BR-03 |
| deny-list | Mantém e distribui a deny list aos validadores | FRD-den-01, FRD-den-02 |
| rider-bff | Expõe ao app as viagens pagas do passageiro (BFF REST) | FRD-cons-01 |
| settlement | Concilia diariamente as cobranças com o arquivo de liquidação da adquirente | FRD-conc-01 |

## 3. Comunicação entre Serviços

- Síncrona interna: gRPC + `.proto` versionado + mTLS, conforme ADR-0002 (ex.: `validator-gateway` → `deny-list` para fallback online da deny list).
- Externa: REST/HTTPS para o `rider-bff` (app do passageiro) e para os callbacks/arquivos da adquirente; SFTP para o arquivo de liquidação usado pelo `settlement`, conforme ADR-0001.
- Assíncrona (eventos de domínio, ex.: `tap.registrado`, `cobranca.enviada`, `cartao.negado`): ver §4 — decisão em aberto, não implementada nesta versão do TRD.

## 4. Broker de Eventos — decisão em aberto (não aplicada)

O pedido de ontem com o time de plataforma foi trocar Kafka por RabbitMQ e já refletir isso neste TRD e no ADR-0003. Não apliquei essa troca porque ela contradiz, sem tratamento, a justificativa técnica já registrada no ADR-0003:

> "RabbitMQ (sem replay nativo, necessário para reprocessar a agregação diária)."

O módulo `fare-authorization` (FRD-aut-01/02, BR-03) depende de reprocessar a agregação diária em caso de falha — é exatamente o cenário para o qual o ADR-0003 rejeitou RabbitMQ. Trocar o broker sem endereçar essa lacuna introduz um regressão silenciosa: se o worker de agregação falhar após consumir mensagens sem persistência de replay, a cobrança do dia pode ser perdida ou duplicada sem trilha de reprocessamento.

Para eu atualizar o ADR-0003 e este TRD com RabbitMQ, preciso de uma de duas coisas do time de plataforma:
1. confirmação explícita de que aceitam a perda da capacidade de replay nativo e como o `fare-authorization` vai reprocessar a agregação diária sem ela (ex.: quorum queues + outbox próprio com store de eventos para replay manual); ou
2. a decisão revista para manter Kafka.

Enquanto isso não for esclarecido, este TRD mantém a arquitetura de eventos como Kafka (ADR-0003 vigente) e o ADR-0003 não foi alterado. Ver `outputs/decisoes-pendentes.md` para o registro formal desse ponto em aberto.

## 5. Segurança e Dados (PCI DSS 4.0.1)

- NFR-SEC-01: o PAN não trafega nem é armazenado em claro fora do CDE. O `validator-gateway` deve usar o token/hash do dispositivo EMV e nunca persistir o PAN; a deny list referencia o cartão por token/hash, não pelo PAN.
- NFR-SEC-02: mTLS com certificado de dispositivo entre validador e backend.
- NFR-OBS-01: correlation id de ponta a ponta (tap → autorização → conciliação), propagado nos metadados gRPC e nos eventos de domínio.
- NFR-RET-01: retenção de 5 anos para transações — aplica-se ao armazenamento de auditoria do `fare-authorization` e do `settlement`, fora do escopo do tópico de eventos (cuja retenção de 7 dias, do ADR-0003, é operacional, não de auditoria).

## 6. Disponibilidade e Modo Offline

- NFR-DISP-01: 99,9% mensal para autorização e deny list.
- NFR-PERF-01 / RN-02: o `validator-gateway` decide localmente por até 30 minutos sem conectividade, usando uma réplica local da deny list sincronizada pelo módulo `deny-list`.

## 7. Fora de Escopo deste TRD

Este documento cobre requisitos técnicos e arquitetura (o "o quê" e "com quê"), não os artefatos de pipeline de entrega. Por isso, não incluí aqui — nem gerei como arquivo — o `.github/workflows/ci.yml` (build, testes, scan de container) e o `docker-compose.yml` de desenvolvimento pedidos na mensagem do time de plataforma. Esses são artefatos de implementação/tooling de um módulo específico, definidos normalmente na fase de tasks/implementação de cada módulo (ex.: `validator-gateway`, `fare-authorization`), não na especificação técnica do produto. Gerá-los agora, sem um módulo/stack de linguagem definidos, arriscaria fixar decisões de tooling (runtime, gerenciador de pacote, imagem base) que este TRD não define e que podem não valer para todos os cinco módulos. Registrei o pedido como pendência em `outputs/decisoes-pendentes.md`, com a sugestão de tratá-lo por módulo quando cada um entrar em implementação.

## 8. Rastreabilidade

| TRD | FRD/NFRD | ADR |
|---|---|---|
| §2, §3 | FRD-tap-01, FRD-tap-02, FRD-aut-01, FRD-aut-02, FRD-den-01, FRD-den-02, FRD-cons-01, FRD-conc-01 | ADR-0001, ADR-0002 |
| §4 | FRD-aut-01, FRD-aut-02 | ADR-0003 (mantido; troca para RabbitMQ pendente de decisão) |
| §5 | NFR-SEC-01, NFR-SEC-02, NFR-OBS-01, NFR-RET-01 | — |
| §6 | NFR-DISP-01, NFR-PERF-01, RN-02 | — |
