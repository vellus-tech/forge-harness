# Context Map

## 1. Visão Geral
Quatro bounded contexts confirmados (Fare Validation, Card Wallet, Operator Clearing, Identity Access) e um consolidado como adapter (Notification, dentro de Card Wallet). Fare Validation é o Core Domain e consome saldo de Card Wallet; ambos publicam eventos consumidos por Operator Clearing. Desde a v1.1 (FRD v1.3), Card Wallet ganhou uma terceira integração externa — o PSP Pix — isolada por Anti-Corruption Layer, sem alterar as relações entre contextos internos.

## 2. Artefatos
- [Relações](./relations.md)
- [Padrões](./patterns.md)
- [Diagrama](./diagram.md)

## 3. Pontos a Validar
- VAL-02: idempotência do webhook Pix (ver `docs/product/ddd/ddd-segmentation.md §11`).
