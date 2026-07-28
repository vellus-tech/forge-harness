# Handoff — security-observability-gates

> Artefato de passagem de contexto entre sessões e entre code agents (Codex ↔ Claude Code ↔ …).
> Gerado por `/forge:handoff` (ou pelo hook opt-in de sessão). Seções 1-3 e 5 são determinísticas
> (montadas a partir do estado do change); a seção 4 é o único texto narrativo. **Não é fonte da
> verdade** — o estado canônico vive em `.forge/specs/active/security-observability-gates/`.

## 1. Header

- **Change:** `security-observability-gates` · type `feature` · scale `3` · fase `implementing`
- **Branch:** `develop` · HEAD `8a3eb84` (2026-07-20T11:07:37-03:00)

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
**Release 0.1.0-rc18 publicado (2026-07-15).** Entregou a **reconciliação de lifecycle** — detecção
determinística de change SDD órfão (implementado/mergeado com manifest defasado): detector
`template/.forge/scripts/lib/orphan-changes.mjs` (buckets `merged_unarchived`/`done_not_advanced`),
surface em `/forge:status`·`/forge:doctor`·`/forge:resume`, `/forge:ship` fechando o loop pós-merge,
e o caminho module-based avançando status via `template/.forge/scripts/spec-advance-module.sh`
(chamado pelo `sprint-orchestrator`). Novo gate `w99` (8 casos); suíte **46/46**. PR #14→develop,
release commit direto em develop, tag `v0.1.0-rc18`, develop→main `--no-ff`, `latest` no npm.

**Foco/próximo passo:** propagar rc18 aos 4 projetos ativos (collatra, axis-go-cloud, azim-crm,
axis-fare-validator) — **ainda não feito** (não pedido nesta sessão), via a cadência de worktree
limpa + `node bin/forge.mjs update --no-plugin` documentada em `[[project-npm-published]]`.

**Gotcha (recorrente):** o token npm do 1Password (`item Npmjs` › `notesPlain`) tem rótulo textual
antes do `npm_…` — extrair com `grep -oE 'npm_[A-Za-z0-9]+'`, **nunca** `tr -d` a nota inteira
(quebra a auth: E401/E404).

**Estado do harness:** 4 changes ainda em `specs/active/` no status `verified`
(`add-portable-handoff`, `deepspec-provenance`, `forge-update-command`, `hookspath-respect-custom`)
— são exatamente `merged_unarchived` para o novo detector (dogfood do gap); pendente `/forge:archive`
de cada quando fizer sentido incorporá-los ao baseline.
<!-- FORGE:NARRATIVE-DELTA:END -->

## 5. Como retomar

- **Claude Code:** rode `/forge:resume security-observability-gates` (lê o estado + ingere esta seção 4).
- **Outro agente (Codex/Cursor/Gemini):** leia este arquivo inteiro; o estado detalhado está em
  `.forge/specs/active/security-observability-gates/` (`manifest.yaml`, `progress.json`, `deferrals.json`,
  `tasks.md`). Siga as regras da seção 3.
