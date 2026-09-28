# Padrões Estratégicos Utilizados

| Padrão DDD | Onde é usado | Justificativa |
|---|---|---|
| Open Host Service / Published Language | Wallet & Recharge → Fare & Boarding (saldo); Card & Identity → Fare & Boarding (bloqueio) | Fare & Boarding precisa de uma projeção estável e de leitura rápida, sem acoplar-se ao modelo interno completo dos dois contextos |
| Published Language | Fare & Boarding → Wallet & Recharge / Settlement & Clearing | Eventos de embarque como contrato estável entre contextos |
| Anti-Corruption Layer | Wallet & Recharge → Adquirente de cartão de crédito (externo); Notification → Provider de push (externo) | Protege o modelo interno contra mudanças de contrato de sistemas externos |

## Padrão explicitamente descartado

**Nenhum Shared Kernel ou banco compartilhado (`core_db`) foi adotado.** O pedido original de consolidar todos os contextos em um banco único com join direto foi avaliado e recusado — ver `docs/product/ddd/ddd-segmentation.md §0.3`. Um Shared Kernel real (código de domínio compartilhado) também não se justifica aqui: os contextos não compartilham modelo de domínio, apenas trocam eventos e projeções.
