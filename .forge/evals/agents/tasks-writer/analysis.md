# Análise de benchmark — agente `tasks-writer`

Fonte: `.forge/evals/agents/tasks-writer/workspace/iteration-1/benchmark.json` (gerado por `aggregate_benchmark`, sem cálculo manual). Viewer estático em `workspace/iteration-1/review.html`.

## 1. Resultado

| Config | pass_rate (média) | stddev | min | max |
|---|---|---|---|---|
| with_skill | 0.9433 (94.3%) | 0.0981 | 0.83 | 1.00 |
| without_skill | 0.40 (40.0%) | 0.3727 | 0.17 | 0.83 |

Delta = 0.9433 − 0.40 = **+0.5433** → arredondado no `run_summary.delta.pass_rate` como `+0.54`.

Veredito: delta ≥ 0.15 → **agrega**. `benchmark_ok = true` (script rodou de primeira, sem correção de estrutura).

Tempo médio: with_skill 204s vs without_skill 131s (+73s) — o agente com skill é mais lento, mas o ganho de qualidade compensa amplamente; tokens não instrumentados (zero nos dois lados, métrica não coletada por este harness).

## 2. Asserções não discriminantes

- **`bloqueia-sem-design-e-kiro`, asserção 4** ("se existir tasks.md fora do caminho oficial, a condicional passa vacuamente"): passa em `with_skill` e em `without_skill` pelo mesmo motivo — nenhum dos dois criou `tasks.md` no caminho oficial `docs/product/modules/validador-offline/`. É uma passagem vazia (vacuous truth) nos dois lados; não diferencia a skill.
- **`planeja-tasks-rotativo-aprovado`, asserção 5** (status deve ser Rascunho, não Aprovado): falha nos dois lados (with_skill: `Status: Aprovado para desenvolvimento`; without_skill: `Status: Pronto para sprint`, também não-Rascunho). Como falha em ambas as configurações, não mede valor da skill — mede uma lacuna do artefato em si (ver §4).

## 3. Onde o artefato ajudou e onde atrapalhou (evidência de transcript)

**Ajudou (with_skill vs without_skill, mesmo eval):**
- `bloqueia-sem-design-e-kiro`: with_skill bloqueou 100% (5/5) citando literalmente a regra do artefato — `response.md:9` "`.kiro/specs/validador-offline/tasks.md` não é caminho aceito" e `response.md:5` "`design.md` não existe — bloqueio, não rascunho", refletindo "Anti-Patterns que Você Bloqueia" (linhas 700-703: "Criar tasks sem `design.md`" / "Criar documentação em `.kiro/specs`"). Sem a skill, o agente aceitou o pedido do usuário ao pé da letra: criou `.kiro/specs/validador-offline/tasks.md` com `Status: Aprovado para desenvolvimento` e nem questionou o caminho (`transcript.md:50-52`: "não questionou o uso de `.kiro/` ... aceitando a convenção indicada pelo usuário"), passando só 1/5.
- `revisa-tasks-aprovado-com-cancelamento`: with_skill preservou títulos e numeração das TASKs existentes (TASK-01..06 intactas) seguindo a "Convenção canônica de IDs (inquebrável)" (linhas 281-326) e "TASK não deve misturar múltiplos temas desconexos" (linha 420). Without_skill renomeou o título de TASK-06 (de "API, consulta por placa e observabilidade" para "API, consulta por placa, cancelamento e observabilidade *(escopo estendido — v1.1.0)*") e acrescentou dependência/subtasks nela em vez de abrir TASK nova — falhou exatamente a asserção 3 (`outputs/tasks.md:33,173`).

**Atrapalhou / não ajudou:**
- `planeja-tasks-rotativo-aprovado`, asserção 5: **falha idêntica nas duas configurações**. O run with_skill registra a decisão explicitamente em `transcript.md:87-89`: "ambos os insumos ... estavam presentes e com status `Aprovado`, então o `tasks.md` foi produzido como plano definitivo, não como rascunho condicionado" — leitura razoável do texto do artefato, mas que a avaliação considera errada porque o **próprio tasks.md** carece de aprovação humana separada, independente da aprovação de requirements/design. O artefato nunca declara essa distinção (ver §4).

## 4. Trechos do artefato ignorados, ambíguos, contraditórios ou que desperdiçam tempo

1. **Contradição real (causa confirmada de falha em 2/2 runs do eval 1, ambas configurações):** "Status e Versionamento" (linhas 155-171) e "Estrutura Obrigatória" (linha 120, `Status: Rascunho | Rascunho para revisão | Aprovado para desenvolvimento | Supersedido`) tratam `Aprovado para desenvolvimento` como opção livre assim que requirements/design estão aprovados. O único bloqueio explícito é "Se requirements.md ou design.md não existirem, não produza um plano definitivo" (linha 82) e "Se ... não estiverem aprovados, gere apenas um rascunho" (linha 84) — por omissão, isso lê como "se estiverem aprovados, pode ser definitivo/aprovado". Mas a bateria de eval assume um terceiro gate implícito: o `tasks.md` em si sempre nasce `Rascunho`/`Rascunho para revisão` e só vira `Aprovado para desenvolvimento` num ciclo humano de aprovação **posterior e distinto**, nunca na primeira escrita. Isso nunca é dito no artefato — o exemplo da tabela "Histórico de Versões" (linha 130) usa `Rascunho` na criação inicial, mas é só um exemplo solto, não uma regra.
2. **Duplicação copy-paste inofensiva:** linha 70-71 lista `docs/product/adr/` duas vezes seguidas em "Fontes de arquitetura, engenharia e processo". Não muda comportamento, é ruído.
3. **Mesma ambiguidade no agente irmão `design-writer.md:86`** ("Se o requirements.md não existir ou não estiver aprovado, não produza um design definitivo") — o padrão se repete na família requirements→design→tasks; provável causa raiz comum (o pipeline nunca formalizou "o documento que estou escrevendo agora precisa da própria aprovação humana, distinta da aprovação dos documentos-fonte").
4. **Redundância de tempo, não de correção:** "Padrão de Cada TASK" (linhas 371-408) e "1.10 Convenção canônica de IDs" (linhas 281-332) repetem o mesmo exemplo de subtasks Red/Green/Refactor/Docs/Encerramento quase palavra por palavra em blocos markdown aninhados diferentes. Não causou erro, mas é conteúdo duplicado — candidato a fusão.

## 5. Melhorias concretas priorizadas

1. **[alta / instructions]** Adicionar regra explícita em "Status e Versionamento": *"O `tasks.md` recém-criado começa sempre como `Rascunho` ou `Rascunho para revisão`, mesmo quando `requirements.md` e `design.md` já estão `Aprovado`. `Aprovado para desenvolvimento` só é atribuído num ciclo de revisão humana subsequente e explícito do próprio `tasks.md`, nunca na primeira escrita."* Impacto esperado: resolve a única falha que persiste nas duas configurações (eval `planeja-tasks-rotativo-aprovado`, asserção 5), destravando o with_skill de 83% → 100% nesse caso.
2. **[média / cross-cutting, fora do escopo deste agente isolado]** Levar a mesma regra (gate de aprovação humana do próprio artefato, distinto da aprovação dos insumos) para `requirements-writer.md` e `design-writer.md`, já que a ambiguidade se repete na cadeia. Registrar como achado cross-cutting, não como edição isolada deste arquivo.
3. **[baixa / structure]** Remover a linha duplicada `docs/product/adr/` (linha 71) de "Arquivos que Você Deve Ler".
4. **[baixa / structure]** Fundir os dois blocos de exemplo de subtasks TDD (linhas 319-324 e 393-399) numa única referência canônica.
5. **[baixa / eval, não do artefato]** Reformular `bloqueia-sem-design-e-kiro` asserção 4 para não passar vacuamente quando o `tasks.md` é criado fora do caminho oficial — hoje ela não discrimina a skill.

## 6. Qualidade dos casos de eval (`eval_quality`)

Os 3 casos cobrem cenários distintos e de alto valor discriminante: bloqueio por insumo ausente + caminho não-oficial (`bloqueia-sem-design-e-kiro`), criação de plano definitivo do zero (`planeja-tasks-rotativo-aprovado`) e revisão incremental sem quebrar trabalho em andamento (`revisa-tasks-aprovado-com-cancelamento`). As asserções são checáveis objetivamente (greps/diffs sobre o markdown gerado), com evidência textual anexada em cada `grading.json` — boa qualidade de design de eval. Pontos fracos: a asserção 4 de `bloqueia-sem-design-e-kiro` (vacuidade, §2) e a asserção 5 de `planeja-tasks-rotativo-aprovado`, que testa um comportamento que o próprio artefato nunca prometeu (ambiguidade real do artefato, não fraqueza do caso — mas o caso poderia deixar mais explícito no prompt que espera um gate de aprovação humana do `tasks.md` que hoje nenhuma linha do artefato menciona). `eval_quality`: boa, com uma reformulação pontual recomendada.

## Referências
- `benchmark.json` / `benchmark.md` (agregação determinística, script `scripts.aggregate_benchmark`)
- `review.html` (viewer estático, `eval-viewer/generate_review.py`)
- `grading.json` de cada run em `workspace/iteration-1/eval-*/{with_skill,without_skill}/run-1/grading.json`
- `transcript.md` de cada run em `workspace/iteration-1/eval-*/{with_skill,without_skill}/run-1/outputs/transcript.md`
- Artefato avaliado: `template/.forge/agents/specifications/tasks-writer.md`
