# FRD — Validador Embarcado
**Requisitos Funcionais**

- **Versão:** 0.2.0
- **Data:** 2026-09-26
- **Status:** Rascunho para revisão
- **Referência pai:** ../prd/prd.md

### Histórico de Versões

| Versão | Data | Status | Descrição da alteração |
|--------|------|--------|----------------------|
| 0.1.0 | 2026-09-20 | Substituída | Versão inicial |
| 0.2.0 | 2026-09-26 | Atual | Validação contra o PRD: completados RF-3 a RF-6 (cobertura de F3-F6, ausentes na versão anterior), removido RF de programa de fidelidade (sem respaldo no PRD) e adicionada rastreabilidade às regras de negócio do PRD |

## 1. Requisitos Funcionais

### RF-1 — Validar cartão de transporte (MIFARE)

O validador lê o cartão de transporte (tecnologia MIFARE) e debita a tarifa vigente (BR-01), sinalizando sucesso ao passageiro. Cartões presentes na lista de bloqueio local são recusados com aviso sonoro e visual (BR-02).

*Nota de validação:* a versão anterior descrevia detalhes de implementação (biblioteca libnfc 1.8, Kotlin, Android 13, Room 2.6, WorkManager como foreground service) dentro do requisito funcional. Detalhes de stack técnica não constam do PRD e pertencem ao design técnico, não ao FRD — foram removidos daqui; se precisarem ser preservados, devem migrar para o documento de design (DDD) na rodada de arquitetura.

*Origem:* PRD F1, BR-01, BR-02.

### RF-2 — Validar QR Code

O validador lê o QR Code emitido pelo aplicativo da operadora, valida sua autenticidade e vigência, debita a tarifa (BR-01) e libera o embarque. Cartões/códigos associados à lista de bloqueio local são recusados com aviso sonoro e visual (BR-02).

*Origem:* PRD F2, BR-01, BR-02.

### RF-3 — Validar cartão bancário por aproximação (EMV)

O validador lê o cartão bancário por aproximação (EMV contactless) e libera o embarque sem debitar a tarifa no ato; a cobrança é agregada e processada no fim do dia junto ao emissor/adquirente. Dados do cartão bancário devem ser tratados conforme PCI DSS (ver NFRD).

*Origem:* PRD F3.

### RF-4 — Operar offline

O validador opera sem conexão de rede por até 72 horas, mantendo localmente a lista de bloqueio e registrando as transações realizadas nesse período (MIFARE, QR Code e EMV) para sincronização posterior. Transações EMV offline não sincronizadas em até 72 horas bloqueiam o validador para novas validações EMV, conforme BR-03; validações por cartão de transporte e QR Code não são bloqueadas por esse limite.

*Origem:* PRD F4, BR-03.

### RF-5 — Aplicar integração temporal (segunda viagem com desconto)

Ao identificar uma segunda viagem do mesmo passageiro (mesmo cartão de transporte, QR Code ou cartão bancário) em até 60 minutos da primeira, o validador aplica desconto de 50% sobre a tarifa cheia (R$ 2,50 em vez de R$ 5,00), conforme BR-01.

*Origem:* PRD F5, BR-01.

### RF-6 — Sincronizar transações com o backend

Sempre que houver conectividade disponível, o validador envia ao backend as transações realizadas (validações por MIFARE, QR Code e EMV, incluindo as ocorridas em modo offline), garantindo que nenhuma transação seja perdida entre a validação e a sincronização (ver NFRD).

*Origem:* PRD F6.

## 2. Requisitos removidos nesta revisão

### ~~RF-3 (versão 0.1.0) — Programa de fidelidade~~

Removido. O PRD não descreve programa de fidelidade, acúmulo de pontos ou troca por viagens grátis em nenhum dos itens de escopo (F1-F6) nem nas regras de negócio (BR-01 a BR-03). Este requisito foi adicionado sem respaldo no PRD e não deve seguir para o design (DDD) sem validação explícita do time de produto — se for uma necessidade real, precisa antes ser incorporada ao PRD como novo item de escopo, com regra de negócio associada (critério de acúmulo, validade dos pontos, custo de fundo etc.).
