# Handoff — create-forge-project-harness

> Artefato de passagem de contexto entre sessões e entre code agents (Codex ↔ Claude Code ↔ …).
> Gerado por `/forge:handoff` (ou pelo hook opt-in de sessão). Seções 1-3 e 5 são determinísticas
> (montadas a partir do estado do change); a seção 4 é o único texto narrativo. **Não é fonte da
> verdade** — o estado canônico vive em `.forge/specs/active/create-forge-project-harness/`.

## 1. Header

- **Change:** `create-forge-project-harness` · type `greenfield` · scale `3` · fase `implementing`
- **Branch:** `develop` · HEAD `44a61a2` (2026-08-03T17:08:12-03:00)

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
**Release 0.4.0 publicada (2026-08-03), e há correções DEPOIS dela que ainda não foram publicadas.** A `0.4.0` entregou a Onda C do fechamento de superfície — `lib/route-scan.mjs` (oráculo de rota, duas passadas, seis dialetos) e `lib/api-surface.mjs` (união das quatro fontes) —, PR #40 mergeado em `develop` (`af2c537`), tag `v0.4.0`, `latest` no npm. Depois dela entraram `8fe43d4` (reconciliação do managed-block do `.gitignore`) e `44a61a2` (abstenção do SUR-01), ambos em `develop` e **fora** do que está publicado. Quem instalar a `0.4.0` hoje não recebe nenhum dos dois. **Próximo passo lógico: `0.4.1`** — bump nos três arquivos de versão, CHANGELOG, tag, publish.

**O que a Onda C custou, e por que isso importa mais que o código.** Cinco rodadas de revisão crítica antes do merge, ~25 defeitos, todos da mesma classe: path inventado, em silêncio, com `unresolved` vazio. Cada rodada de correção estreitou o reconhecedor num ponto e o alargou noutro, e a rodada seguinte descobriu o buraco novo — rodada 1 introduziu 1 regressão, a 2 introduziu 3, a 3 introduziu 2. **Nenhum dos defeitos foi encontrado por prova de mutação**; todos vieram de uma entrada que o reconhecedor não previa. Está no `LDG-0021`, e é a mesma forma do defeito que o próprio módulo descreve para o `unresolved`: o que o regex não reconhece é invisível por construção.

**Ledger sem P1 aberto pela primeira vez.** `LDG-0005`/`0009`/`0015` fechados juntos em `8fe43d4` (o `0005` era a causa dos outros dois: append-once impedia qualquer correção de template de chegar a quem já instalou). `LDG-0017` fechado em `44a61a2`. Restam 16 abertos, todos P2 ou menos.

**Perguntas abertas.** (1) `LDG-0010` — promover `SRF-01` a bloqueante exige refazer a medição, porque os números do plano original (41 rotas, zero irresolúveis) foram medidos com o scanner defeituoso e mediam a estreiteza do reconhecedor, não a cobertura. (2) Combinada com o `LDG-0019`, a abstenção do `SUR-01` faz vertical slice .NET e Express multi-arquivo caírem em `inconclusive` sistematicamente — não é falso positivo, mas também não é cobertura; a saída passa por promover o mapa de mounts do Express ao índice global.

**Gotchas.** O token npm do 1Password (`item Npmjs` › `notesPlain`) tem rótulo textual antes do `npm_…` — extrair com `grep -oE 'npm_[A-Za-z0-9]+'`, **nunca** `tr -d` na nota inteira (quebra a auth: E401/E404). E o dogfood raiz deste repo é incompleto: não há `.forge/FORGE.md` nem `.forge/scripts/`, então todo script do harness roda a partir de `template/.forge/scripts/` e o `sync-adapters` falha por design — não é regressão.

**Erro desta sessão, para não repetir:** um `git add -A` sem conferência levou 54 arquivos de scratch de subagente (`x/`, `dummy/`) para dentro de um commit e do merge. Removidos em `23ed704`, com os padrões barrados no `.gitignore`. Conferir `git status` antes de commitar deixou de ser opcional.
<!-- FORGE:NARRATIVE-DELTA:END -->

## 5. Como retomar

- **Claude Code:** rode `/forge:resume create-forge-project-harness` (lê o estado + ingere esta seção 4).
- **Outro agente (Codex/Cursor/Gemini):** leia este arquivo inteiro; o estado detalhado está em
  `.forge/specs/active/create-forge-project-harness/` (`manifest.yaml`, `progress.json`, `deferrals.json`,
  `tasks.md`). Siga as regras da seção 3.
