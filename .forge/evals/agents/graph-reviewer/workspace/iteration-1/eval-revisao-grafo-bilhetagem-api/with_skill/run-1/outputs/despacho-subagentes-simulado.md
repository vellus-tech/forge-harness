# Despacho de subagentes (simulado, não executado)

Regras da tarefa proíbem spawn real neste run. Se subagentes fossem de fato despachados para a curadoria recomendada em `docs/qualidade/revisao-grafo-bilhetagem.md`, o despacho seria:

| # | Agente | Modelo | Prompt resumido |
|---|---|---|---|
| 1 | `file-analyzer` | haiku | Gerar summary de `src/domain/tarifa.ts` — maior fan-in do grafo (4 arestas de entrada), núcleo do domínio de tarifação. |
| 2 | `file-analyzer` | haiku | Gerar summary de `src/shared/money.ts` — segundo maior fan-in (4 arestas de entrada), kernel compartilhado de tipos monetários. |
| 3 | `file-analyzer` | haiku | Gerar summary de `src/domain/desconto.ts` — dentro da área da mudança de integração tarifária; hoje órfão falso no grafo. |
| 4 | `file-analyzer` | haiku | Gerar summary de `src/application/calcular-tarifa.ts` — dentro da área da mudança de integração tarifária. |

Nenhum desses foi de fato spawnado. Nenhuma escrita de summary foi feita em `.forge/graph/cache/summaries.json`.
