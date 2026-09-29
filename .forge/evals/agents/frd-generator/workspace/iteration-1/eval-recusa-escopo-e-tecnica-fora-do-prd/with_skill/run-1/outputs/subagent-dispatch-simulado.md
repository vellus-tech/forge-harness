# Despacho de subagentes que seria feito (NÃO executado — regra do prompt: "não spawne")

O artefato da especificação (`frd-generator.md`, §11) instrui que este agente, ao final, **não invoca**
diretamente outros agentes — apenas registra sugestões de ADR no resumo final para o orquestrador
decidir a ordem de execução. Ou seja, para este caso específico, a própria especificação do agente já
não pede um `spawn` direto; ela pede um **registro de delegação**, que já está feito na seção
"6. ADRs Sugeridos" de `outputs/docs/product/frd-nfrd/frd.md`.

Ainda assim, para cumprir a regra do prompt de registrar "o despacho que faria" caso o artefato
mandasse spawnar subagentes, seguem os despachos que o **orquestrador** (não este agente) faria a
partir do resumo final:

| Agente | Modelo sugerido | Prompt resumido |
|---|---|---|
| `adr-writer` | sonnet | "Crie o ADR-0001 (mecanismo de publicação do evento de recarga confirmada — Kafka vs. alternativa) a partir de FRD-recarga-01/VAL-06 em docs/product/frd-nfrd/frd.md, severidade Média." |
| `adr-writer` | sonnet | "Crie o ADR-0002 (modelo de persistência do saldo do cartão — schema/tabela) a partir de FRD-recarga-05/VAL-07, severidade Baixa." |
| `nfrd-generator` | sonnet | "Gere o NFRD do módulo de recarga cobrindo os pontos de VAL-08 (p99 < 300 ms na confirmação de recarga, disponibilidade 99,95%) pedidos pelo comercial, a partir do frd.md recém-criado." |
| (humano — comitê de produto) | n/a | "Decidir se o cashback de 2% (VAL-01) entra na v1, revisando a exclusão explícita em PRD §7; só depois disso um agente de PRD atualiza o documento formalmente." |

Nenhum desses agentes foi de fato invocado nesta execução.
