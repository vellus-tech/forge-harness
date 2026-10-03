# Padrões Estratégicos Utilizados

| Padrão DDD | Onde é usado | Justificativa |
|---|---|---|
| Anti-Corruption Layer | Fare Collection → Firmware ValidaBus | Protege o domínio interno do modelo de dados instável entre versões de firmware (TEC-03) |
| Anti-Corruption Layer | Recharge → Adquirente de Cartão de Crédito | Isola o domínio interno do contrato de tokenização/antifraude e garante que PAN nunca entre no modelo (NFR-03) |
| Anti-Corruption Layer | Recharge → PSP de Pix | Mesma razão, aplicada ao meio de pagamento Pix (Ponto a Validar VAL-03) |
| Published Language | Fare Collection → Passenger Wallet, Fare Collection → Settlement | FareCharged é um contrato de evento estável consumido por dois contextos distintos |
| Published Language / Read Model | Passenger Wallet → Fare Collection | BlocklistSnapshot é uma fotografia consistente publicada para consumo offline, não uma leitura direta do banco do Wallet |
| Customer/Supplier | Recharge → Passenger Wallet | Wallet (downstream) depende do formato de RechargeApproved definido por Recharge (upstream), mas Recharge não depende do Wallet |
| Customer/Supplier | Passenger Wallet → Notification | Notification (downstream, genérico) consome BalanceLow sem influenciar o modelo do Wallet |
| Open Host Service | Settlement → Operadoras | O arquivo/API de repasse é um contrato público e estável para múltiplos consumidores externos (3 operadoras) |
| Open Host Service | Recharge → Ponto de Venda Credenciado | API de registro de recarga exposta a uma rede externa de pontos de venda |
| Conformist | Passenger Wallet → Identity and Access | O Wallet aceita o modelo de identidade tal como emitido, sem traduzir |
| Conformist | Notification → Firebase Cloud Messaging | Notification adapta-se ao contrato do provedor terceirizado sem exigir tradução reversa |

## Nota sobre Shared Kernel

Nenhum Shared Kernel foi identificado nos insumos disponíveis. O único candidato a modelo compartilhado seria o Value Object `Money` (usado em Fare Collection, Passenger Wallet, Recharge e Settlement) — recomenda-se tratá-lo como um **pacote de tipos compartilhado** (biblioteca `shared-kernel` de tipos de valor, sem lógica de negócio), não como Shared Kernel de agregados ou regras.
