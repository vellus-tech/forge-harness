# Despacho de subagentes (simulado — não executado)

Regras da tarefa proíbem spawnar subagentes nesta execução. Registro aqui o despacho que o agente `nfrd-generator` faria caso o orquestrador real estivesse ativo, conforme a §3 (delegação a `adr-writer`) da especificação:

## 1. `adr-writer` — ADR-0003 (idempotência de webhook de pagamento)

- **Agente:** `adr-writer`
- **Modelo:** sonnet (padrão do harness para ADR; effort não é `max` pois é registro de decisão já delineada pelo NFRD, não design de agregados)
- **Prompt resumido:** "Registrar ADR-0003 — `idempotencia-webhook-pagamento-psp`. Origem: NFR-RES-01 (nfrd.md v1.1). Decisão a documentar: padrão de idempotência para processamento do webhook de confirmação de pagamento do PSP na recarga Pix (chave natural = identificador de pagamento do PSP; rejeição/no-op idempotente em reenvio). Severidade Alta — bloqueante para o design do time de pagamentos que começa quarta-feira. Referenciar PRD R-04 e a trilha auditável de NFR-AUD-01."

## 2. `adr-writer` — ADR-0004 (mTLS na fronteira com parceiro externo)

- **Agente:** `adr-writer`
- **Modelo:** sonnet
- **Prompt resumido:** "Registrar ADR-0004 — `mtls-webhook-parceiro-externo`. Origem: NFR-SEG-02 (nfrd.md v1.1). Decisão a documentar: modelo de confiança mTLS para o webhook do PSP, distinto do `internal-ca` de `.forge/rules/architecture/mtls-internal-services.md` (que cobre apenas serviço-a-serviço interno). Cobrir: como o certificate bundle do PSP é distribuído/validado, processo de rotação do lado do PSP (fora do cert-manager interno). Severidade Alta — bloqueante para o design do time de pagamentos que começa quarta-feira. Referenciar PRD R-05."

## Ordem sugerida ao orquestrador

Ambos os ADRs são Altos (bloqueantes) — o orquestrador decidiria a ordem; sugestão: ADR-0003 antes de ADR-0004, pois o padrão de idempotência normalmente restringe o desenho do endpoint que o mTLS protege. Após criação, o orquestrador atualizaria as linhas "Dependência arquitetural" de NFR-RES-01 e NFR-SEG-02 no `nfrd.md` substituindo "a ser criado via `adr-writer`" pelo link definitivo, e só então invocaria o `frd-nfrd-validator`.

Nenhum outro subagente foi necessário para esta atualização (o próprio `nfrd-generator` produziu o `nfrd.md` diretamente, sem TASKs paralelizáveis).
