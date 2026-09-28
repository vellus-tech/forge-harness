# Análise de benchmark — agente `sprint-orchestrator`

## Resultado

- **Com artefato**: 89% ± 19% (média de 3 evals: 0,67 / 1,00 / 1,00)
- **Sem artefato**: 26,7% ± 23% (0,00 / 0,40 / 0,40)
- **Delta**: +0,62
- **Veredito**: **agrega** (delta ≥ 0,15)
- Tempo: com artefato 190s ± 61s vs. sem artefato 128s ± 17,5s (+62s) — custo de tempo proporcional ao ganho de acerto, não parece patológico.
- `benchmark_ok = true` (script `aggregate_benchmark` rodou de primeira, sem erro de estrutura).

Agregação e viewer gerados sem intervenção manual em dados/estatística — `benchmark.json`, `benchmark.md` e `review.html` são saída direta dos dois scripts determinísticos.

## Asserções não discriminantes (mesmo resultado com e sem artefato)

Duas asserções do eval 1 (`abre-pr-onda-2-recarga`) falharam nas duas configurações pelo mesmo motivo, e o próprio grader já registrou isso em `eval_feedback`:

- A exigência de que `docs/product/modules/recarga/PROGRESS-TRACKING.md` seja atualizado **no checkout principal** (Fase 4 do artefato) foi tratada como "escrita externa proibida" tanto pela execução com artefato quanto sem — o enunciado do eval diz "não execute nada externo (git push, gh, Jira)" mas não distingue editar um arquivo local (sem commit/push) de uma ação de rede. As duas execuções erraram para o mesmo lado por ambiguidade do prompt do eval, não por falha do artefato.
- A exigência de `jira_sync.attempted = 4` em `resultado.json` colide com a mesma restrição ("não chame Jira"): tentativa zero é defensável quando o enunciado proíbe a chamada real. O grader sugere separar essa asserção do requisito de schema (`pr_number`/`pr_url`/`branch`/`next_steps` na raiz), que é a parte que efetivamente discriminou (passou com artefato, falhou sem).

Nenhuma asserção hoje pune uma chave Jira "chutada" sem busca por JQL — as duas configurações inventaram `REC-21..24` por continuidade numérica sem consultar nada, e isso passou batido.

## Onde o artefato ajudou (evidência de transcript/grading)

- **Fase 1 (push) seguida ao pé da letra.** Com artefato: `CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)` + guarda de branch, `[ -z "$(git status --porcelain)" ]`, `--force-with-lease` condicionado a `git ls-remote --heads`. Sem artefato: checagem de árvore feita com `git status` informal (sem `--porcelain`), sem `rev-parse --abbrev-ref HEAD`, e no eval de reinvocação (PR #58 já aberto) nem sequer registrou `--force-with-lease`. Essa é a asserção 1/6 do eval 1 e 2/5 do eval de reinvocação — falhou nas duas execuções sem artefato.
- **`gh pr list --head` antes de `gh pr create`, com `--label auto-review`.** Sem artefato, o eval 1 não registrou `gh pr list` nenhuma vez e omitiu `--label auto-review` por completo (`grep -c -- '--label auto-review'` → 0). Com artefato, os dois comandos e a label saíram exatamente como o pipeline (Fase 2) descreve.
- **Busca Jira por JQL antes de transicionar.** No eval de reinvocação, a execução sem artefato pulou direto para `transitionJiraIssue` com chaves presumidas, sem nenhuma busca por `labels = task:TASK-NN` (Fase 3 do artefato exige a busca primeiro). Com artefato, a busca por JQL, a transição e o comentário citando o PR saíram na ordem certa.
- **Schema de saída (Fase 5).** No eval de reinvocação, a execução sem artefato aninhou `pr.number`/`pr.url` em vez das chaves de topo `pr_number`/`pr_url` que a asserção (e o próprio template do artefato) exigem — falha só nessa configuração. O artefato tem o JSON de exemplo bem explícito na Fase 5 e isso se refletiu 1:1 no resultado com artefato.
- **Recusa disciplinada no eval 3 (onda com falha + árvore suja).** Sem artefato, a execução decidiu "aceitar parcialmente" e propor um PR rascunho simulado mesmo com TASK-12 `[!]` e arquivo não commitado — indo contra a seção "Anti-Patterns que Você Bloqueia" do próprio artefato (que exige onda 100% `[X]`, sem exceção de rascunho). Com artefato, a recusa foi explícita, citou os dois motivos exatos (TASK-12 e `conciliacao.go` não commitado) e devolveu ao task-coder — 5/5 nesse eval. Sem artefato, 2/5, com as três reprovações batendo diretamente na diferença de comportamento (PR "rascunho" proposto, não atribuição do Done ao deploy-orchestrator, e ausência de recusa explícita do PR).

## Trechos do artefato ignorados, ambíguos ou contraditórios

1. **Fase 4.5 (avanço do `manifest.yaml` via `spec-advance-module.sh`) foi pulada mesmo com artefato**, apesar de ser um script puramente local/idempotente (Bash, sem rede). A execução com artefato justificou a omissão como "evitar estado parcial inconsistente" e tratou como fora do escopo da simulação — mas o artefato não diz em nenhum lugar que esse script deve ou não rodar sob restrição de "nada externo". Resultado: as duas asserções que dependiam do avanço de status (`tasks-ready` → `implementing`) falharam nas duas configurações do eval 1. **Melhoria concreta**: adicionar uma frase na Fase 4.5 do tipo "Este script não tem efeito de rede — rode-o mesmo em modo simulado/dry-run; documente como bloqueadas apenas as Fases 1–3 (push, PR, Jira)".
2. **Fase 4 mistura duas coisas sem separar o que é "edição local" do que é "commit + push".** O bloco de bash da Fase 4 já começa com `git checkout main && git pull --ff-only` e termina em `git push origin main`, então uma execução cautelosa lê o bloco inteiro como uma única operação de rede e recua de editar o arquivo também. **Melhoria concreta**: separar visualmente "editar o arquivo" (sempre permitido, mesmo em simulação) de "commit/push" (a etapa de rede), com um subtítulo tipo "4a. Edição local" / "4b. Publicar".
3. **Template do corpo de PR ("TASKs entregues") mostra só 2 itens de exemplo com "... (lista derivada do tracker)"**, sem instruir explicitamente a incluir todos os commits da branch. Na execução com artefato do eval 1, o `pr-body.md` omitiu 3 commits reais (`chore(specs): TASK-0N — concluída`) do `git log main..branch`, listando só os 4 commits `feat(recarga)` — nenhuma asserção pegou isso, mas é uma alucinação por omissão que o "claims" do grader registrou. **Melhoria concreta**: instruir explicitamente "liste TODOS os commits retornados por `git log --oneline main..$BRANCH`, agrupando por TASK quando houver mais de um commit por TASK", em vez de deixar implícito.
4. **Fase 3 diz "restrinja o JQL também ao épico/módulo para desambiguar TASK-NN entre módulos"** mas não dá o nome do campo/label a usar para isso — é a única instrução do artefato que fica sem exemplo concreto (todas as outras fases têm bash/JSON literal). Não gerou falha observável nos 3 evals (nenhum tinha múltiplos módulos com o mesmo TASK-NN), mas é o ponto mais frágil do artefato caso apareça esse cenário.

## Qualidade dos casos de eval (`eval_quality`)

- Só 3 casos, 1 run cada — sem repetição para medir variância/flakiness da mesma configuração-cenário (o desvio-padrão reportado no `benchmark.json` é a dispersão *entre os 3 cenários diferentes*, não entre repetições do mesmo prompt). Para uma leitura de estabilidade por caso, seria preciso rodar `run_eval.py` com `runs_per_configuration > 1` de fato.
- Os 3 cenários cobrem bem o miolo do agente (abertura de PR, reinvocação idempotente sobre PR já aberto, recusa por onda incompleta/árvore suja) e são bem discriminantes na maioria das asserções (assertion-level: 8 de 10 asserções distintas do eval 1+2 diferenciam corretamente com/sem artefato).
- Duas fraquezas concretas de design de eval, já sinalizadas pelo próprio grader em `eval_feedback` e confirmadas na leitura manual acima: (a) a asserção de tracker duplicado no eval de reinvocação passa por omissão (uma execução que não toca o arquivo passa igual a uma que atualiza corretamente o bloco "Sync Jira falhou" in-place) — vale exigir que o bloco registre a nova tentativa; (b) nenhuma asserção pune chave Jira inventada sem busca — as duas configurações "chutaram" `REC-21..24` e isso não custou pontos a nenhuma.
- Nenhum caso testa o branch de "múltiplos issues Jira encontrados para o mesmo TASK-NN" (Fase 3, item 4) nem o de "MCP Atlassian retorna erro estruturado" versus "MCP simplesmente ausente" (Fase 3, bloco de warning) — são ramos do próprio artefato sem cobertura de eval.

## Melhorias concretas priorizadas

1. **[Alta] Artefato — Fase 4.5**: adicionar frase explícita de que o script `spec-advance-module.sh` não tem efeito de rede e deve rodar mesmo em modo simulado/dry-run; hoje isso derruba 2 asserções nas duas configurações do eval 1 por ambiguidade evitável.
2. **[Alta] Artefato — Fase 4**: separar "edição local do tracker" de "commit + push para main" em subseções distintas, para que a restrição de "nada externo" de um eval não contamine a parte que é puramente local.
3. **[Média] Eval — asserção de tracker duplicado (eval de reinvocação)**: exigir que o bloco "Sync Jira falhou" registre a nova tentativa (carimbo/contador), não só a ausência de duplicação, para deixar de passar por omissão.
4. **[Média] Eval — nova asserção**: proibir chave Jira usada em transição/comentário que não veio de um resultado de busca JQL registrado no mesmo output (pega o "chute" de `REC-21..24` que hoje passa liso nas duas configurações).
5. **[Baixa] Artefato — template de PR body**: instruir explicitamente listar todos os commits de `git log --oneline main..$BRANCH` (não só os `feat(...)`) para fechar a lacuna que gerou a alucinação por omissão registrada em `claims` no eval 1.
6. **[Baixa] Artefato — Fase 3**: dar um exemplo concreto do campo/label usado para desambiguar TASK-NN entre módulos (hoje é a única instrução do artefato sem exemplo literal).
7. **[Baixa] Eval — cobertura]**: adicionar um caso para "múltiplos issues Jira para o mesmo TASK-NN" e outro para "MCP Atlassian ausente vs. retorna erro", ambos ramos já descritos no artefato mas não exercitados.
