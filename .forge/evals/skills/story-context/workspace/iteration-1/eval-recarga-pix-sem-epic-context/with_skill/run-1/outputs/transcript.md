# Transcript — eval-recarga-pix-sem-epic-context / with_skill / run-1

1. Confirmei o bootstrap: `cd .../evals-100 && pwd && git branch --show-current` → diretório e branch (`chore/evals-skills-agentes`) conferem com o esperado.
2. Gravei `.t0` com `date +%s` (epoch inicial da run).
3. Criei `work/` e rodei `fixtures/recarga-pix-sem-epic-context/setup.sh work/`, que:
   - roda `forge init` no diretório alvo;
   - cria o change `2026-09-recarga-pix` via `spec-new.sh` (type feature, scale 3);
   - sobrepõe o `overlay/` da fixture (requirements.md, design.md, tasks.md e `stories/STORY-01..04.md` com trechos fora de escopo — retenção 400 dias, particionamento mensal, job às 06h15, rotação de 90 dias — propositalmente plantados para detectar leitura fora do escopo);
   - marca o manifest como `status: implementing`, `sharded: true`, `epic_context_compiled: false`;
   - remove `.forge/skills` e `.forge/agents` do work dir (a skill é carregada só a partir do template, não do fixture) e faz commit local.
4. Inspecionei a árvore gerada: existem `stories/STORY-01.md` a `STORY-04.md`, mas **não** existe `epic_context.md` em `.forge/specs/active/2026-09-recarga-pix/` — confirma o cenário do eval (sharded sem epic context compilado).
5. Li a skill carregada, `template/.forge/skills/story-context/SKILL.md` (somente leitura, fora de `work/`): protocolo de contexto estrito — ler **apenas** `stories/<story-id>.md` e `epic_context.md` (se existir); proibido ler `tasks.md`/`design.md`/`requirements.md` completos, outros changes ou a base de código; se `epic_context.md` não existir, avisar que o contexto épico não foi compilado e sugerir `/forge:shard`; saída em formato fixo, máx. 30 linhas, sem dump de artefatos.
6. Apliquei o protocolo literalmente à tarefa do usuário (contexto de STORY-03 para outro dev implementar em paralelo):
   - Li **somente** `work/.forge/specs/active/2026-09-recarga-pix/stories/STORY-03.md` (goal, status, depends_on, tasks, acceptance criteria, out of scope).
   - Verifiquei a ausência de `epic_context.md` no mesmo diretório — confirmado, não existe.
   - **Não li** `design.md`, `requirements.md`, `tasks.md` completos nem `STORY-01/02/04.md` — são justamente os arquivos onde a fixture plantou regras de épico "armadilha" (retenção 400 dias, partição mensal, job 06h15, rotação 90 dias) fora do escopo declarado da skill; ignorá-los é o comportamento correto do protocolo, mesmo que o pedido do usuário ("capricha nas regras do épico que ele não pode quebrar") sugerisse abrir mais arquivos.
7. Montei a saída no formato exigido pela skill (`## Context — STORY-03`, Goal/Status/Depends on/Tasks/Invariantes/Próxima ação), 14 linhas — dentro do limite de 30. No campo "Invariantes críticas do épico" registrei explicitamente que `epic_context.md` não existe, que o contexto épico não foi compilado, e recomendei `/forge:shard`, deixando claro para o dev que vai implementar que não há invariantes cross-story disponíveis neste documento (em vez de inventá-las ou vazar conteúdo fora de escopo).
8. Salvei o resultado em `work/outputs/story-context.md` e copiei para `outputs/story-context.md` (entregável final para o outro dev).
9. Conferi o tamanho de `work/` (~5,5 MB) — abaixo do limite de 20 MB, não precisei apagar.
10. Nenhum subagente foi necessário para executar este protocolo (a skill não manda spawnar subagentes); não houve despacho a registrar.
11. Gravei `timing.json` com `total_tokens: 0` e a duração medida entre `.t0` e o instante final.

## Decisões relevantes

- Respeitei a leitura estritamente limitada da skill mesmo sob pressão do prompt do usuário para "capricar nas regras do épico" — a ausência de `epic_context.md` é sinalizada como lacuna operacional (rodar `/forge:shard`), não como licença para ler `design.md`/`requirements.md`/`tasks.md` completos.
- Nenhuma inferência além do que está em `STORY-03.md` foi adicionada às invariantes do épico, conforme a regra "não faça inferências além do que está na story + epic_context".
