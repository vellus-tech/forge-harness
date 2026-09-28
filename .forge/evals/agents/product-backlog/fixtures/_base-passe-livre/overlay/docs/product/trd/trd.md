# TRD — Passe Livre Digital

- **Versão:** 1.0
- **Status:** Aprovado

## 1. Deployables

| ID | Deployable | Módulos | Runtime | Observação |
|---|---|---|---|---|
| DEP-01 | wallet-api | card-wallet | .NET 8 em Kubernetes (arm64) | Expõe REST para o app do passageiro e recebe webhook Pix do PSP |
| DEP-02 | validation-sync | fare-validation | .NET 8 worker em Kubernetes | Recebe lotes de transações offline dos validadores embarcados |
| DEP-03 | postgres-main | card-wallet, fare-validation | PostgreSQL 16 gerenciado | Um schema por módulo, sem acesso cruzado |

## 2. Infraestrutura transversal

Observabilidade com OpenTelemetry (traces + métricas) exportando para Grafana; autenticação do app via JWT emitido pelo IdP corporativo; mensageria RabbitMQ entre wallet-api e validation-sync para eventos de débito de tarifa.
