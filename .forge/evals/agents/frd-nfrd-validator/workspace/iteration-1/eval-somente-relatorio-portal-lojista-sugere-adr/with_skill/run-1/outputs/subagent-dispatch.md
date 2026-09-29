# Despacho de subagentes (simulado — regra do harness proíbe spawn real neste eval)

O `frd-nfrd-validator` nunca invoca o `adr-writer` diretamente (spec § 11 — "Você não invoca `adr-writer` diretamente"). A delegação é feita registrando a sugestão de ADR no relatório (§ 18) e cabe ao orquestrador decidir a ordem de invocação.

Se este fosse um run real (fora do eval), o despacho que o orquestrador executaria seria:

| Ordem | Agente | Modelo | Prompt resumido |
|---|---|---|---|
| 1 | `adr-writer` | sonnet | "Criar ADR-0003 — política de senha e hash de credenciais. Origem: FIND-001/FIND-002 do `frd-nfrd-validation-report.md`. Decidir algoritmo de hash (ex.: argon2id vs bcrypt), parâmetros de custo, comprimento mínimo, regras de complexidade e periodicidade de troca para BR-03. Severidade Alta — bloqueante para o próximo detalhamento de NFRD-SEC-01." |
| 2 | `adr-writer` | sonnet | "Criar ADR-0004 — política de retenção e expurgo de dados de vendas. Origem: FIND-003. Decidir prazo de retenção (pendente do jurídico) e estratégia de expurgo, dado o escopo PCI DSS 4.0.1 do portal. Severidade Alta — bloqueante para NFRD-RET-01." |
| 3 (após 1 e 2) | `frd-generator`/`nfrd-generator` | sonnet | "Nova rodada de FRD/NFRD incorporando os dois ADRs aceitos + achados editáveis (FIND-004 a FIND-010) do relatório de validação de 2026-09-26. Coordenar com a branch paralela do Rafael para evitar conflito de merge." |

Nenhum desses agentes foi de fato spawnado nesta execução — esta tabela é apenas o registro do que seria despachado, conforme instruído pelo harness de eval.
