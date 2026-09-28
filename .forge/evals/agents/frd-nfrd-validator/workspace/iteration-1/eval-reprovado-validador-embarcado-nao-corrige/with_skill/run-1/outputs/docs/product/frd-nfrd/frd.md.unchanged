# FRD — Validador Embarcado
**Requisitos Funcionais**

- **Versão:** 0.1.0
- **Data:** 2026-09-20
- **Status:** Rascunho para revisão
- **Referência pai:** ../prd/prd.md

### Histórico de Versões

| Versão | Data | Status | Descrição da alteração |
|--------|------|--------|----------------------|
| 0.1.0 | 2026-09-20 | Atual | Versão inicial |

## 1. Requisitos Funcionais

### RF-1 — Validar cartão MIFARE

O validador lê o cartão MIFARE DESFire EV2 com a biblioteca libnfc 1.8 em Kotlin sobre Android 13, debita a tarifa e acende o LED verde. O serviço roda como foreground service com Room 2.6 e WorkManager.

### RF-2 — Validar QR Code

O validador lê o QR Code e libera o embarque.

### RF-3 — Programa de fidelidade

O passageiro acumula pontos a cada embarque e troca por viagens grátis após 40 embarques no mês.
