# Revisão de qualidade do grafo de código — bilhetagem-api

Data: 2026-09-26. Grafo avaliado: `.forge/graph/graph.json` (gerado em 2026-09-26T17:37:05.272Z, engine nativo, 10 nodes / 15 edges, único idioma `ts`).

## Veredito

**Não confiável como pré-flight isolado do `/forge:impact` para a mudança da janela de integração tarifária.** O grafo tem um problema estrutural de resolução de imports pós-migração para ESM NodeNext que esconde exatamente as duas peças de domínio mais prováveis de serem tocadas pela mudança (`calcular-tarifa.ts` e `desconto.ts`). Usar o grafo sem correção ou sem checagem manual complementar vai subestimar o raio de impacto.

## Cobertura por camada

- Classificados: 7 de 10 nodes (70%) — `api` (2), `application` (2), `domain` (2), `infrastructure` (1).
- Não classificados: 3 — `src/main.ts`, `src/shared/money.ts`, `src/jobs/expurgo-legado.ts`. Todos são código de backend legítimo (entrypoint, utilitário compartilhado, job) que simplesmente não bate com nenhuma camada declarada em `codegraph.layers` no FORGE.md. É lacuna de configuração, não de coleta — vale declarar essas três pastas (`src/`, `src/shared`, `src/jobs`) na taxonomia antes de confiar na métrica de cobertura por camada.
- Fora da taxonomia (`unknown` explícito): 0.

## Summaries

**0 de 10 summaries preenchidos** (`cache/summaries.json` está vazio; todo node tem `summary: null` e o `report.md` marca os 10 como "stale"). Não há curadoria LLM rodada ainda sobre este grafo. Qualquer revisão de impacto que dependa do resumo semântico dos nodes (não só da lista de edges) não tem material nenhum para se apoiar hoje.

## Órfãos

Órfão real, confirmado por leitura do código: `src/jobs/expurgo-legado.ts` — sem edges de entrada nem de saída, e o próprio comentário no arquivo confirma ("Job do sistema antigo de bilhetagem magnética; desligado desde a migração para cartão NFC"). Candidato a remoção, mas isso é assunto separado da mudança da janela tarifária.

`src/main.ts` aparece sem edge de entrada, o que é esperado por ser o entrypoint da aplicação — não é um órfão real.

**Órfãos falsos (mais importante para o pré-flight):** `src/application/calcular-tarifa.ts` e `src/domain/desconto.ts` não têm nenhuma edge de entrada **resolvida** no grafo — pareceriam desconectados do resto do sistema se alguém olhar só a lista de edges resolvidas. Na prática, os dois são consumidos por `src/api/tarifa-controller.ts`, só que por imports que o resolvedor do grafo marcou como não resolvidos (ver seção seguinte). Isso é um falso órfão introduzido pelo bug de resolução, não uma desconexão real do código.

## Edges não resolvidas

3 de 15 edges (20%) saem não resolvidas, e as três partem do mesmo arquivo, `src/api/tarifa-controller.ts`:

- `../application/calcular-tarifa.js` → não resolvida
- `../domain/desconto.js` → não resolvida
- `../../config/tarifas.json` → não resolvida (import de dado, não de código — esperado que o engine não trate isso como node de código, mas vale registrar porque `tabela.tarifa_base_centavos` alimenta o cálculo de tarifa)

O comentário no topo do próprio `tarifa-controller.ts` explica a causa raiz: "Migrado para ESM NodeNext em 2026-05: imports novos já usam o sufixo `.js` exigido pelo Node." O engine do codegraph resolve corretamente imports relativos sem extensão (`'../domain/tarifa'`, `'../shared/money'` — ambos aparecem como edges resolvidas para os mesmos arquivos `.ts`), mas não resolve o padrão NodeNext de import com sufixo `.js` apontando para um arquivo-fonte `.ts`. Como maio de 2026 foi quando a migração aconteceu, isso é provável que seja o padrão daqui para frente em todo import novo ou tocado no repositório — o grafo vai progressivamente perder mais edges reais à medida que mais arquivos forem migrados/tocados, não menos.

## Ação recomendada

1. **Bloqueante para o pré-flight do `/forge:impact`:** corrigir (ou contornar) a resolução de imports com sufixo `.js` no engine do codegraph antes de usar o grafo como fonte única de raio de impacto para a mudança da janela de integração tarifária. Sem isso, uma alteração em `calcular-tarifa.ts` ou `desconto.ts` não vai aparecer como afetando `tarifa-controller.ts` nem `main.ts` na análise de impacto automática.
2. **Enquanto o bug não for corrigido, complementar manualmente:** para esta mudança específica, confirmar por leitura/grep que o escopo de impacto inclui pelo menos `src/api/tarifa-controller.ts`, `src/application/calcular-tarifa.ts`, `src/domain/desconto.ts`, `src/domain/tarifa.ts` e `src/shared/money.ts` — não confiar apenas na travessia automática de edges resolvidas a partir do node alterado.
3. Rodar uma passada de geração de summaries antes de qualquer revisão que dependa de contexto semântico por node (hoje 0/10 preenchidos).
4. Declarar `src/`, `src/shared/` e `src/jobs/` em `codegraph.layers` no FORGE.md para fechar a lacuna de classificação de 30% (não bloqueante para o impacto, mas melhora a métrica de cobertura por camada).
5. Tratar `src/jobs/expurgo-legado.ts` como candidato a remoção em separado — está confirmado morto e não afeta a mudança da janela tarifária.
