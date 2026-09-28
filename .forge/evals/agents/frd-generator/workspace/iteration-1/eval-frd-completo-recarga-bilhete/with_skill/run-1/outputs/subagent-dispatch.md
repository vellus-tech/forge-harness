# Despacho de subagentes (simulado — não executado)

As regras desta execução de eval proíbem spawnar subagentes reais. Este arquivo registra o despacho que o agente `frd-generator` faria em condições normais de operação, conforme §11 da sua especificação (delegação a `adr-writer`), caso o orquestrador decidisse executá-lo imediatamente em vez de agrupar para uma rodada de ADRs ao final.

## Despacho 1

- **Agente:** adr-writer
- **Modelo:** sonnet (padrão de módulo/integração, conforme convenção de spawn do usuário)
- **Prompt resumido:** "Criar ADR-0001 — mecanismo-de-idempotencia-de-recarga — a partir de FRD-recharge-05 (BR-02, proteção contra recarga duplicada em menos de 2 minutos e mesmo valor). Decidir entre token de idempotência gerado pelo cliente e verificação por janela de tempo/hash de payload no servidor. Severidade Alta — bloqueante para implementação de FRD-recharge-05."
- **Entregável esperado:** docs/product/adr/000N-mecanismo-de-idempotencia-de-recarga.md

## Despacho 2

- **Agente:** adr-writer
- **Modelo:** sonnet
- **Prompt resumido:** "Criar ADR-0002 — politica-de-retencao-de-cpf-e-dados-de-pagamento — a partir de FRD-auth-01 (cadastro com CPF) e FRD-recharge-03 (pagamento com dados de cartão de crédito). Definir política de retenção/tokenização vinculante, com precedente de compliance (LGPD, PCI DSS). Severidade Média — necessária antes do release."
- **Entregável esperado:** docs/product/adr/000N-politica-de-retencao-de-cpf-e-dados-de-pagamento.md

Nenhum dos dois despachos foi executado nesta run; nenhum arquivo em `docs/product/adr/` foi criado ou alterado.
