# Handoff — create-forge-project-harness

> Artefato de passagem de contexto entre sessões e entre code agents (Codex ↔ Claude Code ↔ …).
> Gerado por `/forge:handoff` (ou pelo hook opt-in de sessão). Seções 1-3 e 5 são determinísticas
> (montadas a partir do estado do change); a seção 4 é o único texto narrativo. **Não é fonte da
> verdade** — o estado canônico vive em `.forge/specs/active/create-forge-project-harness/`.

## 1. Header

- **Change:** `create-forge-project-harness` · type `greenfield` · scale `3` · fase `implementing`
- **Branch:** `develop` · HEAD `b079645` (2026-08-04T11:29:26-03:00)

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
**`0.6.0` publicada (2026-08-04), `develop` e tag `v0.6.0` empurrados, working tree limpa em `b079645`.** Cinco itens do ledger fechados em sequência (`LDG-0011`, `0026`, `0004`, `0019`, `0018`) e um sexto (`LDG-0010`) medido e **recusado**. Baseline `forge-harness-template` foi de 17 para **53 requisitos** nesta sessão; suíte em 74 gates, 100% verde; nenhum change órfão. O único ativo é o `create-forge-project-harness`, parado em `implementing` desde 2026-06-11 — ele não foi tocado e continua sendo a decisão pendente mais antiga (retomar ou `/forge:close --reason delivered-externally`).

**O aprendizado que vale mais que os seis itens: a descrição do ledger envelhece, e sempre para pior.** Em **quatro** dos seis, o item descrevia um defeito maior ou diferente do que existia. `LDG-0011` afirmava "30 tasks e ZERO arestas" — eram 19 de 30 com metadados. `LDG-0019` afirmava que desambiguar `MapEndpoints` homônimo exigiria "resolver namespace/using, fora do alcance de um scanner por regex" — `namespace X;` e `using X;` são regexáveis e são exatamente o que o compilador usa. `LDG-0018` afirmava "Nest resolve um controller por arquivo" — multi-controller já funcionava desde o PR #40. `LDG-0010` supunha que o oráculo de rota destravaria a promoção do `SRF-01` — a medição mostrou que o obstáculo é outro. **Medir antes de escrever o `bugfix.md` pegou os quatro.** Implementar a partir da descrição teria construído para problemas que não existiam mais.

**Segundo aprendizado: o defeito mais grave da sessão não veio de teste, veio de medir.** Depois de cinco casos verdes no `w132`, rodei a medição de cobertura num fixture com `const r = require('express').Router()` e obtive **zero rotas e zero irresolúveis** — pior que reprovar, porque deixa o cruzamento verde por vacuidade. É a forma exata do `LDG-0021`: a prova de mutação mede as regras escritas, não a superfície de entrada que elas deixam passar. **Depois de todo gate verde, medir num caso realista ainda encontra coisa.**

**O que a medição do `LDG-0010` produziu, e que fica como insumo.** Contra `axis-go-cloud`, com o scanner já corrigido: 343 rotas resolvidas (o plano original media 41 — o "zero irresolúveis" de então media a estreiteza do reconhecedor), 83 irresolúveis (38 `producer-not-found`, 23 `group-path-not-literal`, 12 `producer-never-invoked`, 5+5 dos guards), `SUR-01` = `inconclusive` com 49 abstidos. Sobre 35 changes reais, 11 achados `SRF-01`: **7 em células escritas em prosa** (o oráculo não decide), 2 com endpoint que existe (defeito de declaração), 2 com endpoint ausente (código **ou** cegueira). Daí o `SRF-03` (aviso, cobra `VERB /path`), o rebaixamento do `LDG-0010` para P3 e o `LDG-0029` novo para a cegueira.

**Dívida de processo assumida nesta sessão, e que precisa mudar na próxima.** Os 17 commits foram para `develop` **direto**, sem branch e sem PR — logo **sem `code-evaluator`**. Cada change teve `verification.md` REQ-a-REQ, suíte verde e gate humano de archive, mas revisão crítica independente do diff não houve, e o `/forge:ship` ao final não teve o que revisar. Duas saídas: rodar `/code-review` sobre `v0.5.0..v0.6.0` e tratar achados como `0.6.1`, ou aceitar e mudar o fluxo daqui para frente. **Recomendação: trabalhar em branch por item (`fix/<escopo>/<descricao>`) e deixar o `/forge:ship` fazer o ciclo inteiro.**

**Gotchas operacionais confirmados na prática.** (1) Reverter mutação com `git checkout -- <arquivo>` **apaga edição não commitada** — aconteceu com o `installer/install.sh` e só foi pego pelo `grep` de conferência; use cópia de backup ou `git stash`. (2) Asserção de gate por substring livre quebra quando outra mensagem cita o mesmo código — o `w130[15]` grepava `SRF-01` solto e passou a casar a menção em prosa dentro do `SRF-03`. (3) O replay de Red-first precisa de `setup_command: npm ci` neste repo (o `w41` importa o pacote `yaml`), e o gate precisa emitir `FAIL [n] (...)` para o classificador reconhecer a falha como comportamental. (4) `install.sh` **não** aceita `--yes`/`--no-plugin`; só `--target/--source/--slug/--name/--desc/--adapters/--force/--no-symlink`.
<!-- FORGE:NARRATIVE-DELTA:END -->

## 5. Como retomar

- **Claude Code:** rode `/forge:resume create-forge-project-harness` (lê o estado + ingere esta seção 4).
- **Outro agente (Codex/Cursor/Gemini):** leia este arquivo inteiro; o estado detalhado está em
  `.forge/specs/active/create-forge-project-harness/` (`manifest.yaml`, `progress.json`, `deferrals.json`,
  `tasks.md`). Siga as regras da seção 3.
