# TRD - Tarifa Aberta

**Produto:** Tarifa Aberta | **Versão:** v1.0 | **Status:** Para revisão (Engenharia, DevOps, QSA) | **Data:** 2026-09-26
**Fontes:** docs/product/prd/prd.md · docs/product/frd-nfrd/frd.md · docs/product/frd-nfrd/nfrd.md · docs/product/ddd/ddd-segmentation.md · docs/product/modules/README.md · docs/product/adr/0001-0003

## 1. Visão geral e escopo técnico

O Tarifa Aberta implementa o pagamento de tarifa de ônibus por cartão contactless EMV sem cadastro prévio, cobrindo a captura do tap no validador embarcado, a agregação e cobrança junto à adquirente, o controle de risco por deny list, a consulta do passageiro e a conciliação diária. Este TRD traduz PRD, FRD, NFRD, a segmentação DDD e os ADRs 0001-0003 em arquitetura executável para as cinco entregas (deployables), suas APIs, eventos, dados, segurança/PCI, observabilidade e operação. Fora de escopo técnico: bilhete estudantil, integração tarifária entre linhas e pagamento por QR Code (PRD, seção 5).

## 2. Arquitetura de solução

A arquitetura segue os bounded contexts da segmentação DDD, um deployable por contexto, comunicação síncrona interna em gRPC (ADR-0002), superfícies externas em REST/HTTPS ou SFTP (ADR-0001) e eventos de domínio em Kafka com Outbox Pattern (ADR-0003).

```
Validador embarcado (firmware, fora deste TRD)
        │ mTLS + client cert de dispositivo (NFR-SEC-02)
        ▼
┌─────────────────┐   gRPC    ┌──────────────────────┐   evento tap.registrado   ┌────────────┐
│ validator-gateway │ ───────▶ │ fare-authorization    │ ─────────────────────────▶│   Kafka    │
│  (tap-capture)    │          │ (fare-authorization)  │                            └─────┬──────┘
└─────────┬─────────┘          └──────────┬────────────┘                                  │
          │ gRPC (consulta)                │ REST/HTTPS (cobrança agregada)                │ evento cobranca.*
          ▼                                ▼                                                ▼
   ┌─────────────┐                 ┌───────────────┐                              ┌────────────────┐
   │  deny-list   │◀── evento ─────│  Adquirente    │                              │   settlement    │
   │ (deny-list)  │  cobranca.negada│  (parceira)   │──arquivo SFTP liquidação────▶│ (settlement)    │
   └─────────────┘                 └───────────────┘                              └────────────────┘
          ▲                                                                                 │
          │ REST (BFF)                                                                       │ evento
   ┌─────────────┐                                                                            ▼
   │  rider-bff   │◀── evento tap.registrado ──────────────────────────────────────── (consumo assíncrono)
   │(rider-history)│
   └─────────────┘
          ▲
          │ REST/HTTPS
      App do passageiro
```

Racional: um deployable por bounded context evita acoplamento entre o caminho crítico de liberação de catraca (validator-gateway) e os caminhos assíncronos de risco, consulta e conciliação, permitindo escalar e implantar cada um de forma independente. Alternativa descartada: um único serviço monolítico "fare-service" cobrindo captura+autorização+deny-list — rejeitada porque o NFR-PERF-01 (p95 ≤ 500 ms, inclusive offline) exige que o caminho de liberação de catraca não dependa de chamadas de rede para autorização ou conciliação; a separação também respeita o ADR-0002 (contrato `.proto` por serviço dono).

## 3. Deployables

| Deployable | Bounded Context (DDD) | Tipo | Rastreabilidade |
|---|---|---|---|
| validator-gateway | tap-capture | Serviço de borda (gRPC server para o validador, cliente gRPC de deny-list) | FRD-tap-01, FRD-tap-02, NFR-PERF-01, NFR-SEC-02 |
| fare-authorization | fare-authorization | Serviço + worker de agregação diária | FRD-aut-01, FRD-aut-02, BR-01, BR-03 |
| deny-list | deny-list | Serviço de leitura/distribuição, cache replicado no validador | FRD-den-01, FRD-den-02 |
| rider-bff | rider-history | BFF REST para o app do passageiro | FRD-cons-01 |
| settlement | settlement | Worker batch de conciliação | FRD-conc-01 |

Cada deployable corresponde 1:1 ao módulo listado em docs/product/modules/README.md; nenhum módulo foi desdobrado em mais de um deployable nem fundido, pois nenhum FRD exige granularidade diferente da já definida na segmentação DDD.

## 4. APIs

### 4.1 Superfícies externas (REST/HTTPS, ADR-0001)

| API | Consumidor | Endpoint (indicativo) | Rastreabilidade |
|---|---|---|---|
| Consulta de viagens | App do passageiro → rider-bff | `GET /v1/riders/{riderId}/trips` | FRD-cons-01 |
| Callback de liquidação | Adquirente → settlement | `POST /v1/settlements/callbacks` (ou arquivo via SFTP, conforme contrato da adquirente) | FRD-conc-01 |
| Cobrança agregada | fare-authorization → Adquirente | `POST /charges` (API pública da adquirente parceira, fora do controle deste TRD) | FRD-aut-02, BR-03 |

### 4.2 Malha interna (gRPC, ADR-0002, mTLS obrigatório)

| Serviço `.proto` | Dono do contrato | Consumidores | Rastreabilidade |
|---|---|---|---|
| `TapCaptureService` | validator-gateway | fare-authorization (consumo via evento, não chamada direta) | FRD-tap-01 |
| `DenyListQueryService` | deny-list | validator-gateway (consulta local com cache; ver §4.3) | FRD-tap-02, FRD-den-01 |
| `FareAuthorizationService` | fare-authorization | rider-bff (para status de cobrança, se necessário em versão futura) | FRD-aut-01 |

### 4.3 Consulta offline no validador

O NFR-PERF-01 exige decisão p95 ≤ 500 ms inclusive offline e a RN-02/BR-02 exige liberação por até 30 minutos sem conectividade. O validator-gateway mantém cache local da deny list, atualizado por assinatura do tópico Kafka `deny-list.atualizada` (não por chamada gRPC síncrona a cada tap); a chamada gRPC a `DenyListQueryService` é usada apenas na reconciliação periódica do cache, nunca no caminho crítico do tap. Isso resolve a aparente contradição entre "consultar a deny list" (PRD RN-02) e "operar offline": a consulta é sempre local.

## 5. Eventos de domínio (Kafka, ADR-0003, Outbox Pattern, retenção mínima 7 dias)

| Tópico | Produtor | Consumidores | Payload (campos-chave) | Rastreabilidade |
|---|---|---|---|---|
| `tarifa-aberta.tap.registrado` | validator-gateway | fare-authorization, rider-bff | tapId, cartãoTokenizado, linha, veículo, horário, validadorId | FRD-tap-01 |
| `tarifa-aberta.cobranca.enviada` | fare-authorization | settlement | cobrancaId, cartãoTokenizado, valorTotal, dataCompetência | FRD-aut-02 |
| `tarifa-aberta.cobranca.negada` | fare-authorization | deny-list | cartãoTokenizado, cobrancaId, motivo | FRD-den-01, BR-04 (RN-04) |
| `tarifa-aberta.cobranca.quitada` | settlement | deny-list | cartãoTokenizado, cobrancaId | FRD-den-02 |
| `deny-list.atualizada` | deny-list | validator-gateway (todos os validadores, via gateway) | versão, lista incremental (hash + tokens) | FRD-den-01, FRD-den-02, NFR-PERF-01 |

Publicação via Outbox Pattern em todos os produtores, conforme ADR-0003, garantindo atomicidade entre a escrita transacional e a publicação do evento.

## 6. Modelo de dados

| Entidade | Deployable dono | Campos-chave | Observação PCI |
|---|---|---|---|
| Trip (viagem) | validator-gateway / fare-authorization | tapId, cartãoTokenizado, linha, veículo, horário, status | Nenhum PAN armazenado; apenas token/hash (NFR-SEC-01) |
| Charge (cobrança agregada) | fare-authorization | cobrancaId, cartãoTokenizado, valorTotal, dataCompetência, status | idem |
| DenyListEntry | deny-list | cartãoTokenizado, motivo, dataInclusão, dataQuitação | idem |
| RiderTripView | rider-history (rider-bff) | riderId (ou identificador por token de cartão), últimos 4 dígitos, linha, horário, valor | Exibe apenas os 4 últimos dígitos (FRD-cons-01), nunca o PAN completo |
| SettlementRecord | settlement | cobrancaId, valorLiquidado, dataLiquidação, divergência | idem |

O identificador de cartão que circula entre validator-gateway, fare-authorization, deny-list e rider-bff é sempre o token gerado na tokenização do PAN (ver §7); nenhuma dessas entidades armazena PAN em claro, atendendo NFR-SEC-01. Retenção de transações (Trip, Charge, SettlementRecord) por 5 anos para auditoria, conforme NFR-RET-01.

## 7. Segurança e PCI DSS 4.0.1

| Controle | Requisito de origem | Implementação |
|---|---|---|
| PAN nunca em claro fora do ambiente de dados de cartão | NFR-SEC-01 | O PAN é lido pelo validador certificado EMV e tokenizado no ponto de captura (HSM/serviço de tokenização da adquirente ou gateway de pagamento); validator-gateway e demais deployables tratam exclusivamente o token. Escopo PCI (CDE) fica restrito ao firmware do validador e ao serviço de tokenização, isolando os demais deployables do CDE. |
| Autenticação validador-backend por certificado de dispositivo | NFR-SEC-02 | mTLS com certificado por validador, emitido e rotacionado por PKI própria; validator-gateway rejeita conexão sem certificado válido. Consistente com mTLS obrigatório na malha interna (ADR-0002). |
| Segregação de ambiente de dados de cartão | Requisito PCI DSS 4.0.1 (Req. 1, 3, 4) | validator-gateway e fare-authorization operam fora do CDE por tratarem apenas tokens; qualquer componente que toque PAN (tokenização) fica em rede segmentada, revisada pelo QSA. |
| Logs sem dado sensível | Requisito PCI DSS 4.0.1 (Req. 10) | Logs e eventos Kafka carregam apenas token e metadados de viagem, nunca PAN, CVV ou trilha magnética. |
| Deny list e retenção | RN-04, NFR-RET-01 | Deny list indexada por token; retenção de transações por 5 anos em armazenamento com controle de acesso e trilha de auditoria. |

Este TRD não substitui a avaliação formal do QSA; a tabela acima é o ponto de partida para a revisão de escopo PCI solicitada na tarefa.

## 8. Observabilidade

| Requisito | Origem | Implementação |
|---|---|---|
| Correlação fim a fim do tap à cobrança | NFR-OBS-01 | `correlationId` gerado no tap (validator-gateway) e propagado em headers gRPC, eventos Kafka (header `correlation-id`) e chamadas REST à adquirente; presente em 100% das mensagens. |
| SLO de disponibilidade 99,9% mensal | NFR-DISP-01 | Dashboards de disponibilidade por deployable (fare-authorization, deny-list) com alertas de erro budget; validator-gateway monitorado à parte por operar em modo degradado tolerável (offline até 30 min). |
| SLO de latência p95 ≤ 500 ms | NFR-PERF-01 | Métrica de latência de decisão no validator-gateway, segmentada por modo online/offline, com alerta em breach de p95. |
| Auditoria de deny list | RN-04, FRD-den-01/02 | Log de auditoria de toda inclusão/remoção na deny list, correlacionado ao `cobrancaId` de origem. |

## 9. Deploy e operação

- Cada deployable é implantado de forma independente (um pipeline por módulo), respeitando os limites de bounded context; validator-gateway recebe atenção especial por rodar próximo ao validador embarcado (baixa latência de rede até o veículo).
- fare-authorization roda como serviço (autorização por tap) mais um worker agendado para fechar a agregação diária até as 23h59 (BR-03); o worker precisa de janela de execução monitorada, com alerta se não concluir antes do horário-limite contratual com a adquirente.
- settlement roda como worker batch diário, disparado após a adquirente disponibilizar o arquivo de liquidação (SFTP); falhas de conciliação geram alerta operacional e não bloqueiam a operação dos demais deployables (execução assíncrona).
- deny-list precisa garantir propagação da lista a todos os validadores mesmo em conectividade intermitente; operação deve monitorar o atraso de propagação como métrica operacional (não coberta explicitamente pelo NFRD, sinalizado aqui como lacuna a esclarecer com o time de produto).
- Rollout de validator-gateway deve ser gradual (canário por lote de validadores), dado que uma regressão afeta a liberação de catraca em campo.

## 10. Rastreabilidade consolidada

| Artefato de origem | Itens cobertos neste TRD |
|---|---|
| PRD | OBJ-01 a OBJ-03 (§2, §9); F-01 a F-05 (§3); RN-01 a RN-04 (§4.3, §5, §6) |
| FRD | FRD-tap-01, FRD-tap-02, FRD-aut-01, FRD-aut-02, FRD-cons-01, FRD-den-01, FRD-den-02, FRD-conc-01 (§3 a §6) |
| NFRD | NFR-PERF-01, NFR-DISP-01, NFR-SEC-01, NFR-SEC-02, NFR-OBS-01, NFR-RET-01 (§7, §8) |
| DDD | Todos os 5 bounded contexts mapeados 1:1 a deployables (§3) |
| Módulos | validator-gateway, fare-authorization, deny-list, rider-bff, settlement (§3) |
| ADR-0001 | REST/SFTP em todas as superfícies externas (§4.1) |
| ADR-0002 | gRPC + mTLS na malha interna (§4.2, §7) |
| ADR-0003 | Kafka + Outbox em todos os eventos de domínio (§5) |

## 11. Lacunas e pontos abertos para a revisão

- O NFRD não define SLA/SLO específico para o worker de conciliação (settlement) nem para a propagação da deny list; sinalizado em §9 para decisão do time de produto/DevOps.
- O contrato exato da API de callback/arquivo de liquidação da adquirente depende de especificação externa não incluída nos artefatos de origem; a linha de §4.1 é indicativa.
- Este documento assume tokenização do PAN no próprio validador ou via serviço de tokenização integrado; a arquitetura exata de tokenização (HSM próprio vs. serviço da adquirente) precisa ser confirmada com o QSA antes da implementação, dado o impacto no escopo do CDE.
