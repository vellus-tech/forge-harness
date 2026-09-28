# Diagrama de Dependências — Tarifa Viva

Relações extraídas do context map (`docs/product/ddd/context-map/README.md`): Shared Kernel, Published Language, Customer/Supplier e Anticorruption Layer.

```mermaid
flowchart LR
    tar["tarifacao-lib"] -->|"Shared Kernel<br/>(embarcado, sem rede)"| val["validacao-embarque-api"]
    cad["cadastro-passageiro-api"] -->|"Customer/Supplier<br/>evento PassageiroElegivelAtualizado"| tar
    rec["recarga-api"] -->|"Published Language<br/>eventos RecargaConfirmada / RecargaEstornada"| val
    val -->|"Published Language<br/>evento EmbarqueValidado"| liq["liquidacao-operadoras-worker"]
    aq["Adquirente (externo)"] -->|"Anticorruption Layer"| tok["tokenizacao-cartao-adapter"]
    rec -->|"gRPC síncrono<br/>(token, nunca PAN)"| tok

    style tok fill:#f8d7da,stroke:#c0392b,stroke-width:2px
    style cad fill:#fdebd0
```

## Leitura

- **Shared Kernel** (`tarifacao-lib` → `validacao-embarque-api`): mesmo processo, sem chamada de rede — mudança na lib exige recompilar/deploy de `validacao-embarque-api`.
- **Published Language** (eventos via RabbitMQ): `recarga-api` → `validacao-embarque-api` e `validacao-embarque-api` → `liquidacao-operadoras-worker`. Acoplamento fraco, assíncrono.
- **Customer/Supplier**: `cadastro-passageiro-api` é fornecedor de elegibilidade para `tarifacao-lib` — mudança de contrato do evento `PassageiroElegivelAtualizado` deve ser negociada com o consumidor.
- **Anticorruption Layer**: `tokenizacao-cartao-adapter` isola o domínio Recarga do modelo/protocolo da adquirente externa.
- A única dependência síncrona entre módulos internos é `recarga-api` → `tokenizacao-cartao-adapter` (gRPC); é também a fronteira do CDE de PCI DSS.
- Não há dependência direta de `validacao-embarque-api` ou `liquidacao-operadoras-worker` com dados pessoais (`cadastro-passageiro-api`) nem com dados de cartão (`tokenizacao-cartao-adapter`) — o isolamento de compliance nasce da própria topologia de dependências, não apenas de controle de acesso.
