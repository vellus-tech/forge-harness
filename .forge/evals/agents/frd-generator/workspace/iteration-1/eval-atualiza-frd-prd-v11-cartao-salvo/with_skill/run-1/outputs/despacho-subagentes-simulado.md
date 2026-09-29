# Despacho de subagentes (simulado — não executado)

Conforme regra do run (sandbox de eval), nenhum subagente foi spawnado de fato. O agente frd-generator não invoca `adr-writer` diretamente por definição do seu próprio protocolo (§11.3 da especificação): ele apenas registra a sugestão no resumo final e cabe ao orquestrador decidir quando disparar o `adr-writer`. O despacho abaixo é o que o orquestrador faria a seguir, caso este fosse um run real.

| Agente | Modelo sugerido | Prompt resumido |
|---|---|---|
| adr-writer | sonnet | Criar ADR-0004 em docs/product/adr/, título "política de tokenização do cartão salvo (PCI DSS)", a partir de BR-04/PRD RN-05: o app nunca armazena PAN completo nem CVV de cartão salvo; recarga recorrente usa apenas token do adquirente; regra vale para qualquer funcionalidade futura com cartão salvo. Referenciar FRD-rec-05 e FRD-rec-06 como origem. Após criado, atualizar a linha correspondente em docs/product/frd-nfrd/frd.md (seção 13, BR-04) substituindo a menção de "ADR-0004 sugerido" pelo link definitivo. |

Nenhuma chamada de Task/Agent foi feita nesta execução.
