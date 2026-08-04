# Handoff — gate-assert-visibility

> Artefato de passagem de contexto entre sessões e entre code agents (Codex ↔ Claude Code ↔ …).
> Gerado por `/forge:handoff` (ou pelo hook opt-in de sessão). Seções 1-3 e 5 são determinísticas
> (montadas a partir do estado do change); a seção 4 é o único texto narrativo. **Não é fonte da
> verdade** — o estado canônico vive em `.forge/specs/active/gate-assert-visibility/`.

## 1. Header

- **Change:** `gate-assert-visibility` · type `bugfix` · scale `2` · fase `verified`
- **Branch:** `develop` · HEAD `b0f5e09` (2026-08-04T17:13:09-03:00)

## 2. Estado

- **Wave atual:** n/d
- **Stories:** 0/0 · **Tasks:** 0/0
- **Deferrals abertos:** nenhum
- **Runtime:** test=`n/d` · typecheck=`n/d` · lint=`n/d`

## 3. Regras fixas da sessão

1. Subagente SEMPRE com `model` explícito: haiku (bite-sized/paralelizar), sonnet
   (onda/módulo/integração/debugging), opus effort medium (design de agregados, ADRs, code-review
   crítico). Nunca herdar o modelo do orquestrador.
2. Subagente NUNCA roda `docker build`/`docker compose up --build`. O orquestrador dispara em
   `run_in_background` e segue com outra TASK enquanto aguarda.
3. Toda operação git em worktree usa `git -C <worktree>` explícito — nunca `cd` implícito que se
   perde entre chamadas de subagente.
4. Validação real (build/teste) antes de marcar qualquer TASK concluída — o relatório do subagente
   não é a verdade até o orquestrador conferir.
5. Checkpoint + encerrar a sessão por módulo/PR — não acumule múltiplos módulos numa sessão só;
   `/forge:ship` fecha o ciclo antes de abrir o próximo.

## 4. Delta narrativo

<!-- FORGE:NARRATIVE-DELTA:START -->
**Sessão longa em `develop`, sem branch/PR, ~20 commits diretos.** Fechado `create-forge-project-harness` (change órfão de 2026-06, TASK-23..30 já entregues fora do rastreamento) como `delivered-externally`, commit `cb577f2`. Em seguida aberto `gate-assert-visibility` a partir do `LDG-0012` (bugfix scale 2): asserções bash `[ cond ] && cmd` sob `set -e` em `tests/*.sh` morrem ou passam em silêncio sem `FAIL`.

**`bugfix.md` levou 3 iterações de validador adversarial (Opus) antes da implementação.** O catálogo cresceu da estimativa original do ledger ("~15 gates") para **52 sites verificados em 20 arquivos**, e a causa-raiz revelou ser mais grave do que a registrada: além de morte muda (caso a — a ÚLTIMA cláusula do `&&` falha), existe passagem silenciosa (caso b — uma cláusula NÃO-final falha, isenta de `set -e`, o script segue como se tivesse passado). `tasks.md` levou mais **2 iterações**, que corrigiram um desenho de Red-first inicialmente inviável: o motor de replay exige HEAD verde antes de derivar a árvore base, então não dá para fazer `record`+`replay` na mesma task quando o arquivo do Red também está no catálogo de correção.

**No caminho, achado e corrigido `LDG-0030`: bug real do próprio harness.** `spec-transition.sh`/`validate-spec.mjs` não deixavam um `type: bugfix` scale≥2 pular `design-ready` mesmo com `quick_plan` justificado — a isenção só existia a partir de `tasks-ready`. Corrigido nos dois scripts, espelhando a isenção já existente.

**Implementadas as 24 tasks do `tasks.md`** (Red teste+declaração → 20 conversões de arquivo → replay real → suíte completa → registro de achado incidental), todas com commit atômico. A conversão do `w43-c4-gate.sh` (`TASK-17`) revelou uma passagem silenciosa real e pré-existente (não regressão): o cenário `[5]` nunca testou o que afirmava desde a introdução do gate. Um agente Opus dedicado investigou com Bash, achou a causa raiz em `c4-gen.mjs` (duas lacunas de renderização C4 — boundary de arquivo único não gera component view, e C3 de boundary pequeno omite arestas cross-boundary), corrigiu a fixture com fidelidade à intenção original (provado por mutação) e registrou a lacuna real como `LDG-0031` (P3, fora de escopo). Um segundo achado incidental (`tests/w111-liaison-sync-gate.sh:259`, asserção vazia `grep ... && true`) virou `LDG-0032` (P3).

**`/forge:verify` = APROVADO.** `spec-delta.yaml` removido — este bugfix não altera nenhum `REQ-NN` de baseline, é correção de idioma bash na própria suíte de testes. Checagem semântica do Red confirmada: a falha observada na base é exatamente o defeito relatado, não uma quebra adjacente coincidente. Change transicionou para `verified`. **Não foi arquivado** — não há baseline de produto a atualizar, é correção pura da suíte de testes do harness.

**Estado final:** suíte completa 75/75 verde (`tests/run-all.sh`). Ledger: `LDG-0012` promovido→resolvido via o change, `LDG-0030`/`0031`/`0032` novos, abertos, P2/P3. Dívida de processo (commits diretos em `develop`, sem branch/PR/`code-evaluator`) segue a mesma do handoff anterior de 0.6.0 — ainda não resolvida.

**Aprendizado forte desta sessão.** O padrão foi validação adversarial (agentes Opus independentes, "tente reproduzir/refutar por execução, não leitura") em TODO artefato antes de avançar o gate — `bugfix.md` (3 rounds), `tasks.md` (2 rounds), gates HITL com decisão autônoma delegada e justificativa auditável. Isso pagou: achou 2 desenhos de Red-first inviáveis, 1 bug real do harness, 2 achados incidentais de teste, e uma contagem de catálogo que crescia a cada rodada de medição (15 → 41 → 52). **Por instrução direta do usuário ao final desta sessão: daqui para frente, todo trabalho de código deste harness segue TDD estrito (Vermelho → Verde → Refactor)** — teste que falha primeiro, ver falhar pelo motivo certo, só então implementar o mínimo, só então refatorar. Vale tanto para features/bugfixes do produto quanto para mudanças na maquinaria (scripts, validadores) — o `LDG-0030` foi corrigido ad hoc, sem Red formal, e deveria ter sido um mini-ciclo TDD também.

**Próximo passo lógico:** decidir o destino do `gate-assert-visibility` (permanece `verified` sem archive, já que não há baseline a atualizar — ou `/forge:close --reason delivered-externally` para fechar o rastreamento formalmente). Depois, atacar a dívida de processo (branch+PR+`code-evaluator`) ou o próximo item do ledger, priorizando por P (todos os novos são P2/P3, sem P0/P1 abertos).
<!-- FORGE:NARRATIVE-DELTA:END -->

## 5. Como retomar

- **Claude Code:** rode `/forge:resume gate-assert-visibility` (lê o estado + ingere esta seção 4).
- **Outro agente (Codex/Cursor/Gemini):** leia este arquivo inteiro; o estado detalhado está em
  `.forge/specs/active/gate-assert-visibility/` (`manifest.yaml`, `progress.json`, `deferrals.json`,
  `tasks.md`). Siga as regras da seção 3.
