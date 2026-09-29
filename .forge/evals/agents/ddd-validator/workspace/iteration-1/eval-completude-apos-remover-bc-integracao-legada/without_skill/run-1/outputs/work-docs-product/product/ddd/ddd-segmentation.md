# Segmentação DDD — Embarque Fácil

## 1.2 Classificação de Subdomínios

| Subdomínio | Slug | Classificação | Justificativa |
|---|---|---|---|
| Validação de Embarque | validacao-embarque | Core | Tarifação com integração temporal e operação offline são o diferencial (PRD §Diferencial, FR-01, FR-02). |
| Carteira Digital | carteira-digital | Supporting | Mantém saldo pré-pago que apoia o embarque (FR-03). |
| Recarga | recarga | Supporting | Crédito via Pix (FR-04). |
| Conformidade PCI | conformidade-pci | Generic | Tokenização de cartão contratada de provedor certificado (NFR-03). |
| Notificações | notificacoes | Generic | Push commodity (FR-05). |

## 3. Event Storming

| Fluxo | Comando | Evento | Produtor |
|---|---|---|---|
| J2 | RegistrarEmbarque | EmbarqueRegistrado | Validação |
| J2 | DebitarTarifa | TarifaDebitada | Carteira |
| J1 | ConfirmarRecarga | RecargaConfirmada | Recarga |
| J1 | CreditarSaldo | SaldoCreditado | Carteira |

## 4.1 Bounded Context Candidates

| ID | Bounded Context | Slug | Subdomínio | Decisão |
|---|---|---|---|---|
| BC-01 | Validação | validacao | Validação de Embarque | Confirmar |
| BC-02 | Carteira | carteira | Carteira Digital | Confirmar |
| BC-03 | Recarga | recarga | Recarga | Confirmar |
| BC-04 | Notificações | notificacoes | Notificações | Confirmar como Generic |
| ~~BC-05~~ | ~~Integração Legada~~ | integracao-legada | — | ~~Removido em 2026-09-10: bilhete magnético descontinuado em outubro~~ |
