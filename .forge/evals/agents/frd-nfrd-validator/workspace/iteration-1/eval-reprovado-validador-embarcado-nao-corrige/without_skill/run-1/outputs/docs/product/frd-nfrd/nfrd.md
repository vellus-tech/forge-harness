# NFRD — Validador Embarcado
**Requisitos Não Funcionais**

- **Versão:** 0.2.0
- **Data:** 2026-09-26
- **Status:** Rascunho para revisão
- **Referência pai:** ../prd/prd.md

### Histórico de Versões

| Versão | Data | Status | Descrição da alteração |
|--------|------|--------|----------------------|
| 0.1.0 | 2026-09-20 | Substituída | Versão inicial |
| 0.2.0 | 2026-09-26 | Atual | Validação contra o PRD: requisitos vagos ("rápido", "seguro", "sempre disponível") substituídos por critérios mensuráveis derivados da seção 4 do PRD e das regras de negócio; removido requisito de infraestrutura (Kubernetes/Istio) sem respaldo funcional explícito no PRD |

## 1. Requisitos Não Funcionais

### NFR-1 — Desempenho de validação

A validação (do toque/leitura ao sinal verde) deve ser concluída em até 500 ms em 99% dos casos, para as três formas de embarque (cartão de transporte, QR Code e cartão bancário EMV).

*Origem:* PRD, seção 4 (Requisitos de qualidade esperados).

### NFR-2 — Segurança dos dados de pagamento

Dados de cartão bancário (EMV) capturados, armazenados ou transmitidos pelo validador devem ser tratados em conformidade com o padrão PCI DSS vigente, inclusive quando retidos temporariamente para a cobrança agregada de fim de dia (RF-3).

*Origem:* PRD, seção 4 (Requisitos de qualidade esperados); PRD F3.

### NFR-3 — Confiabilidade da sincronização

Nenhuma transação validada (MIFARE, QR Code ou EMV) pode ser perdida entre o momento da validação e a sua sincronização com o backend; o validador deve reter localmente toda transação ainda não confirmada como sincronizada.

*Origem:* PRD, seção 4 (Requisitos de qualidade esperados); PRD F6.

### NFR-4 — Disponibilidade em modo offline

O validador deve continuar operando (validando embarques e aplicando a lista de bloqueio local) por até 72 horas contínuas sem conectividade de rede, sem degradação perceptível no tempo de resposta descrito em NFR-1.

*Origem:* PRD F4.

## 2. Requisitos removidos ou reclassificados nesta revisão

### ~~NFR-4 (versão 0.1.0) — Kubernetes com HPA e Istio no backend de sincronização~~

Removido do NFRD do validador embarcado. Trata-se de uma decisão de infraestrutura para o *backend* de sincronização, não um requisito não funcional do dispositivo/aplicativo embarcado escopo deste documento, e não tem requisito de negócio correspondente explícito no PRD (que não descreve o backend). Se for de fato uma necessidade validada, deve ser tratada no design técnico (DDD) do serviço de backend, com o requisito não funcional que a justifique (ex.: elasticidade de carga, resiliência) formulado a partir de um objetivo mensurável, não como escolha de tecnologia direta no NFRD.
