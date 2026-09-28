# Despacho de subagentes que seria feito (não executado — modo eval)

A especificação `frd-nfrd-validator.md` (Seção 11 — Delegação a `adr-writer`) não manda este agente
spawnar um subagente diretamente: ela instrui que o agente **registre a sugestão de ADR no relatório**
e que **instrua o orquestrador** a invocar o agente `adr-writer` depois. Ou seja, o "despacho" aqui é
uma recomendação textual ao orquestrador, não uma chamada de subagente feita por mim.

Registro, ainda assim, o despacho que o orquestrador executaria a seguir, caso este fosse um caso real:

| Campo | Valor |
|---|---|
| Agente a invocar | `adr-writer` |
| Modelo sugerido | sonnet (padrão do harness para módulos/ADRs; `opus` effort medium se o orquestrador tratar como decisão de arquitetura crítica) |
| Prompt resumido | "Redigir ADR-0001 — política de proteção de dados de cartão bancário (tokenização/criptografia, escopo PCI DSS) — motivada por FIND-007/VAL-02 do relatório `docs/product/frd-nfrd/frd-nfrd-validation-report.md`. Severidade Alta. Não avançar o NFRD de segurança antes deste ADR." |
| Pré-condição | Parecer desta validação é Reprovado — o orquestrador deve resolver ADR-0001 antes de solicitar nova rodada de `frd-generator`/`nfrd-generator`, pois a decisão arquitetural muda o que precisa ser detalhado nos documentos regenerados (Seção 11.3 da especificação). |
| Spawn real nesta sessão | Não realizado (regra do harness de eval: nunca spawnar subagentes; apenas registrar o despacho). |

Nenhum outro subagente seria necessário nesta rodada: a especificação do `frd-nfrd-validator` não
prevê `docker build`, testes automatizados ou builds — apenas leitura/análise/edição de documentos
Markdown, e, no caso deste eval (parecer Reprovado), nenhuma edição foi aplicada.
