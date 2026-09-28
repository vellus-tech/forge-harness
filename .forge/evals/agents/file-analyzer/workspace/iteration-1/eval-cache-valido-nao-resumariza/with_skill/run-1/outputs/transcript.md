# Transcript — eval-cache-valido-nao-resumariza / with_skill / run-1

## Nota sobre o pedido de spawn de subagentes relayado no início da tarefa

O pedido relayado do usuário no início desta sessão instrui a usar subagentes para orquestrar/manter o contexto limpo. As regras explícitas desta tarefa específica ("Se o artefato mandar spawnar subagentes, NÃO spawne: registre em outputs/") tratam de um passo mecânico do fluxo de eval (não recursar em spawns reais dentro de um caso de eval sandboxado), não de uma instrução de negócio para este caso. Segui as regras específicas da tarefa: não spawnei nenhum subagente e registrei em `outputs/subagent-dispatch-log.md` o que seria despachado, caso fosse necessário (não foi, ver abaixo).

## Passos executados, em ordem

1. **Bootstrap.** `cd .forge/worktrees/evals-100 && pwd && git branch --show-current` → confirmou diretório e branch esperados (`chore/evals-skills-agentes`).
2. **Instante inicial.** `date +%s > run-1/.t0`.
3. **Preparo do projeto.** `mkdir -p run-1/work` e execução de `fixtures/cache-valido-nao-resumariza/setup.sh run-1/work`, que:
   - roda `forge.mjs init` no diretório-alvo;
   - copia o overlay (projeto TS de bilhetagem: `src/shared/money.ts`, `src/tarifacao/tarifa-repository.ts`, `src/integracao/calculo-integracao.ts`);
   - constrói o grafo determinista (`graph.sh build`), summaries nascem `null`;
   - semeia `.forge/graph/cache/summaries.json` com summaries curados amarrados ao fingerprint atual de cada nó (inclui o summary do nó sob teste);
   - reconstrói o grafo para carregar os summaries semeados;
   - faz `git init` + commit do estado inicial (fixture) — commit isolado dentro do diretório de trabalho `work/`, não afeta a árvore do worktree principal;
   - sobrescreve `src/integracao/calculo-integracao.ts` com a versão cosmética do usuário (comentários citando a portaria SMT 14/2025 + indentação de 4 espaços), **sem commitar** — simula a edição "de hoje";
   - remove `.forge/skills`, `.forge/agents`, `.claude/skills`, `.claude/agents`, `plugin` do diretório-alvo para não contaminar o baseline com o artefato sob avaliação.
4. **Leitura do artefato do agente.** Li `template/.forge/agents/graph/file-analyzer.md` (somente leitura) — regras-chave: o agente só preenche semântica; a estrutura (fingerprint/edges/loc) já vem do extractor; "determinismo de cache: se a estrutura não mudou, você não é reinvocado (zero tokens)".
5. **Simulação da tarefa do usuário.** Dentro de `work/`, executei `git status --short` (confirma que só `src/integracao/calculo-integracao.ts` está modificado em relação ao commit da fixture) e `bash .forge/scripts/graph.sh update`, que respondeu `OK graph up to date (no structural change — zero tokens)`.
6. **Verificação do fingerprint.** Comparei o nó `src/integracao/calculo-integracao.ts` em `graph.json` antes/depois: fingerprint `5dda5a77...082d56` inalterado; único campo que mudou foi `loc` (10→21, não usado para invalidar cache) e `generated_at` do grafo (timestamp de build, também não usado para invalidar cache). O `summary` no `graph.json` e em `.forge/graph/cache/summaries.json` permaneceu byte-idêntico ao semeado pela fixture.
7. **Decisão do agente.** Como o fingerprint estrutural não mudou, a regra de determinismo de cache do `file-analyzer.md` diz explicitamente que o agente não deve ser reinvocado. Não gerei nenhum summary novo, não editei `summaries.json` nem `graph.json` além do que o próprio `graph.sh update` determinístico já havia tocado (metadados não estruturais), e não toquei no arquivo do usuário. Registrei a resposta explicando essa decisão em `outputs/agent-response.md`, citando o `up to date (no structural change — zero tokens)` do `graph.sh` e a comparação de fingerprint, em vez de simplesmente dizer "atualizei".
8. **Coleta de entregáveis.** Copiei para `outputs/work-snapshot/` o `graph.json`, o `summaries.json` e o `calculo-integracao.ts` finais de `work/`; salvei o diff de `graph.json` (`outputs/graph-json.diff`) e o `git status --short` completo de `work/` (`outputs/git-status-work.txt`) como evidência de que nada além de metadados não estruturais mudou.
9. **Registro de dispatch.** Como nenhum subagente precisou ser despachado (a checagem de fingerprint já é resolvida pelo script determinista, sem necessidade de invocar o `file-analyzer`), registrei isso em `outputs/subagent-dispatch-log.md`, incluindo o despacho hipotético que seria feito no caso contrário.
10. **Fechamento.** Calculei `timing.json` a partir de `.t0` e do instante final; verifiquei o tamanho de `work/` (bem abaixo de 20 MB, não foi apagado).

## Assertivas do caso (auto-checagem, não autoritativa — o harness de eval é quem valida oficialmente)

- `summary-cacheado-preservado-byte-a-byte`: confirmado — `summaries.json` mantém summary e fingerprint semeados.
- `graph-json-mantem-o-mesmo-summary-do-no`: confirmado — mesmo summary/fingerprint no `graph.json`; nenhum summary menciona a portaria SMT 14/2025.
- `recusa-resumarizar-citando-fingerprint-estrutural`: confirmado — resposta cita `up to date`/`zero tokens` e a comparação de fingerprint.
- `nao-propoe-summary-substituto`: confirmado — nenhum summary alternativo proposto.
- `arquivo-do-usuario-intocado`: confirmado — arquivo permanece com a versão cosmética do usuário (portaria SMT 14/2025, indentação 4 espaços).

## Retomada (2026-09-28)

Esta sessão foi invocada com a tarefa "retome" sobre este mesmo caso. Ao chegar em `run-1/`, encontrei o run já completo: `work/` com o commit da fixture e a edição cosmética intactos, `outputs/` com `agent-response.md`/`transcript.md`/evidências já gravados, e `grading.json` (26/09, 15:59) já com as 5 expectativas do caso passando (`pass_rate: 1`). Não refiz o setup (`setup.sh` recusaria sem `--force`, e não havia motivo para descartar o estado já avaliado) nem editei a resposta do agente, que permanece válida. Reverifiquei por conta própria, direto em `work/`: `git status --short` só lista a edição cosmética não commitada em `src/integracao/calculo-integracao.ts`; o fingerprint do nó em `.forge/graph/graph.json` e em `.forge/graph/cache/summaries.json` seguem `5dda5a779b965793220640b1e46ab7266bb1404344ff5026491330b721082d56`, idênticos entre si e ao commit da fixture; o arquivo do usuário permanece byte-idêntico à fixture cosmética. Copiei `graph.json`/`summaries.json`/`calculo-integracao.ts`/o diff do arquivo para `outputs/` (redundantes com `outputs/work-snapshot/`, já removidos por serem duplicata) e depois desfiz essa cópia para não duplicar evidência. Único artefato que esta retomada atualiza de fato é `timing.json`, recalculado com o novo `.t0` desta invocação — o conteúdo de negócio do run (resposta do agente, evidências, grading) não mudou.
