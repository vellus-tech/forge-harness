# Revisão de qualidade do grafo — bilhetagem-api

> Gerada pelo agente `graph-reviewer` antes do pré-flight de `/forge:impact` na mudança da janela de integração tarifária.

## Status: CURADORIA RECOMENDADA

O grafo não deve ser usado como pré-flight de impacto para a área `tarifa`/`desconto` sem antes corrigir a resolução de imports quebrada pela migração ESM NodeNext — ela esconde exatamente o arquivo (`desconto.ts`) que a mudança de integração tarifária vai tocar. Fora dessa área, a base do grafo está íntegra (todo import TypeScript interno relevante resolve e nenhum ciclo aparece).

## O que o `graph.sh validate` encontrou

```
OK graph (10 nodes, 15 edges; 1 warning(s) — 2 orphan node(s) to review — dead code or unresolved imports: src/domain/desconto.ts, src/jobs/expurgo-legado.ts)
```

## 1. Cobertura — 70% classificado, e um buraco fora da taxonomia

- `layer_coverage`: 7 de 10 nós classificados (70%); os 3 restantes (`src/main.ts`, `src/jobs/expurgo-legado.ts`, `src/shared/money.ts`) caíram em `unknown` por não baterem com nenhuma convenção de pasta da heurística nativa — pelo §7 do FORGE.md isso conta como gap real (heurística sem match), não como "fora da taxonomia por design". Ação: declarar esses três caminhos em `codegraph.layers` no FORGE.md (`src/main.ts` como entrypoint, `src/jobs/**` como camada própria, `src/shared/**` como shared/kernel) para que a próxima extração já os classifique.
- **Lacuna de linguagem não reportada nas stats de camada:** o census interno do extractor aponta 3 arquivos Ruby (`scripts/conciliacao/lancamento.rb`, `importar_arquivo_sptrans.rb`, `layout_cnab.rb`) que não geraram nenhum nó — o extractor nativo só cobre TypeScript. Esses scripts de conciliação não fazem parte do fluxo de tarifação/emissão em si, então não bloqueiam o `/forge:impact` desta mudança, mas ficam fora de qualquer análise de impacto futura que toque conciliação. Candidato a extractor tree-sitter opt-in (ADR 0001), registrar como dívida conhecida.

## 2. Órfãos — um é ruído esperado, o outro é o achado crítico

`graph.sh validate` aponta 2 órfãos:

- **`src/jobs/expurgo-legado.ts`** — código morto legítimo (comentário no próprio arquivo: "desligado desde a migração para cartão NFC"). É um órfão *by design*, não uma falha do extractor. Ação: declarar em `codegraph.orphans_by_design` para parar de poluir o `validate` a cada rodada.
- **`src/domain/desconto.ts`** — **não é código morto**, é usado ativamente por `tarifa-controller.ts` (aplica o desconto de estudante/idoso sobre a tarifa). Aparece como órfão porque o único import que aponta para ele já vem com sufixo `.js` (`'../domain/desconto.js'`, exigido pela resolução NodeNext desde a migração de maio) e o extractor nativo não reescreve `.js` → `.ts` na hora de casar o alvo do import com o nó do grafo. Resultado: o grafo não enxerga nenhuma aresta entrando em `desconto.ts`, e uma análise de impacto que caminhe pelo grafo **não vai identificar `desconto.ts` como afetado** por mudanças em `tarifa-controller.ts` (ou o inverso). Isso é justamente a lógica de desconto que fica embutida na tarifa — sensível numa mudança de janela de integração.

## 3. Edges não resolvidos — 3 no total, 2 internos e falsos-negativos

| Origem | Alvo declarado | Tipo | Por quê não resolveu |
|---|---|---|---|
| `tarifa-controller.ts` | `../../config/tarifas.json` | externo | JSON não é nó do grafo (esperado, não é gap) |
| `tarifa-controller.ts` | `../application/calcular-tarifa.js` | **interno** | sufixo `.js` pós-migração NodeNext, arquivo real é `calcular-tarifa.ts` |
| `tarifa-controller.ts` | `../domain/desconto.js` | **interno** | mesma causa — é a aresta que produz o órfão do item 2 |

Achado consolidado: a extração TypeScript não trata a convenção ESM NodeNext (import relativo com sufixo `.js` apontando para arquivo-fonte `.ts`). Como a migração para NodeNext aconteceu em maio e `tarifa-controller.ts` é justamente o arquivo que a mudança de integração tarifária vai tocar, esse é um gap concentrado exatamente na área de risco da mudança, não um ruído disperso pela base.

## 4. Summaries — 100% stale, priorize por fan-in antes de confiar no grafo para onboarding/impacto

Todos os 10 nós estão com `summary: null` (cache de summaries vazio). Para uma base deste tamanho isso não bloqueia o `/forge:impact` (que opera sobre arestas, não sobre prosa), mas compromete qualquer leitura humana do grafo. Priorização por fan-in (maior primeiro):

1. `src/domain/tarifa.ts` — 4 arestas de entrada (`tarifa-controller`, `calcular-tarifa`, `emitir-bilhete`, `bilhete-repository`) — maior fan-in da base, núcleo do domínio de tarifação.
2. `src/shared/money.ts` — 4 arestas de entrada (`tarifa-controller`, `calcular-tarifa`, `emitir-bilhete`, `tarifa.ts`) — kernel compartilhado, qualquer mudança de tipo (`Centavos`) se propaga por toda a base.
3. `src/domain/desconto.ts` e `src/application/calcular-tarifa.ts` — diretamente na área da mudança de integração tarifária.

Ação: rodar `file-analyzer` nesses quatro arquivos antes de usar o grafo como onboarding para a mudança; os demais (controllers, repository, jobs) podem esperar uma curadoria posterior sem risco imediato.

## Ação recomendada antes do `/forge:impact`

1. **Bloqueante para a área tocada:** corrigir (ou contornar manualmente) a resolução de imports `.js` → `.ts` do extractor nativo para NodeNext, ou — mais rápido — rodar `/forge:impact` e conferir manualmente se `desconto.ts` e `calcular-tarifa.ts` aparecem na análise de impacto de `tarifa-controller.ts`; se não aparecerem, tratar como falso-negativo conhecido e incluí-los manualmente no escopo da mudança.
2. Declarar `codegraph.layers` para `src/main.ts`, `src/jobs/**` e `src/shared/**` no FORGE.md.
3. Declarar `src/jobs/expurgo-legado.ts` em `codegraph.orphans_by_design`.
4. Rodar `file-analyzer` em `tarifa.ts`, `money.ts`, `desconto.ts` e `calcular-tarifa.ts`.
5. Registrar a lacuna de cobertura Ruby (`scripts/conciliacao/**`) como dívida conhecida (ADR 0001 / tree-sitter opt-in) — não bloqueante para esta mudança.

Fora desses pontos, os demais 12 edges resolvem corretamente e não há ciclos nem duplicidade de nós — a estrutura geral do grafo é confiável.
