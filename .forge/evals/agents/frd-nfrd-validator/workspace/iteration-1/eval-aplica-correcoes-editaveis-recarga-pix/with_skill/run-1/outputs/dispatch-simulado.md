# Despacho de subagentes simulado (não executado)

Regras da tarefa proíbem spawn real de subagentes nesta execução. Este arquivo registra o que
seria despachado se a regra permitisse, para fins de auditoria do eval.

## Avaliação de necessidade

A especificação do `frd-nfrd-validator` (§ 11) prevê delegação a **um único** agente —
`adr-writer` — e apenas quando algum achado exige decisão arquitetural formal (gatilhos do § 11.1).

Nesta rodada:

- Os quatro achados (FIND-001 a FIND-004) são todos **editáveis** segundo o § 4.1 (correção
  localizada, sem mudança de escopo de produto, solução inequívoca a partir do próprio PRD ou de
  convenção de nomenclatura já vigente) e foram aplicados diretamente no `frd.md`/`nfrd.md`.
- O único ponto de fronteira FRD/TRD (FIND-003 — detalhe de stack no FRD-REC-01) foi resolvido por
  **remoção** do conteúdo do FRD, não por uma escolha de arquitetura ainda em aberto — logo não
  dispara os gatilhos do § 11.1 (não há decisão pendente a fechar, a decisão de stack simplesmente
  não pertence a este documento).
- Os pontos remanescentes (VAL-01 a VAL-04) são lacunas de detalhamento a resolver por nova rodada
  do `frd-generator`/`nfrd-generator` (fora do escopo deste agente) e por decisão de produto — não
  são gatilho de ADR.

## Conclusão

**Nenhum despacho a `adr-writer` foi necessário nesta rodada.** Se um achado futuro disparar os
gatilhos do § 11.1 (ex.: VAL-01 evoluir para uma escolha de arquitetura irreversível sobre retry/
circuit breaker na integração com o PSP), o despacho seria:

| Campo | Valor |
|---|---|
| Agente | `adr-writer` |
| Modelo | (herdado da política de spawn do orquestrador — nunca implícito; ver regra global "NUNCA spawnar subagente sem `model` explícito") |
| Prompt resumido | "Redigir ADR a partir de VAL-01 (resiliência/segurança/retenção da integração Pix/PSP do RecargaJá): registrar a decisão de retry/circuit breaker, requisitos de segurança da integração Pix e política de retenção de dados de recarga, com origem rastreada ao `frd-nfrd-validation-report.md` § 16." |
| Severidade sugerida | A definir conforme a decisão de produto que resolver VAL-01 (Alta se bloquear implementação da confirmação assíncrona) |

Este despacho não foi enviado — é apenas o registro do que seria feito, conforme instrução da
tarefa.
