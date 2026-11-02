# Proposal — adopt-ub-mode-practices

> Change `adopt-ub-mode-practices` (type: `feature`, scale 2) — criado em 2026-11-02 por milton.

## 1. Por quê (problema / motivação)

Avaliação comparativa entre o `forge-harness` e a skill pública `unclebob/ub-mode` (Robert C. Martin), feita por agente dedicado (opus, effort high) em 2026-11-02, encontrou 4 lacunas reais confirmadas por grep direto sobre os ~219 gates (`tests/*-gate.sh`), as rules de convenção e os comandos do harness — não hipóteses, achados verificados linha a linha:

1. **(P1)** "Attack the Premise" existe só pela metade: o harness já para depois de 2 tentativas repetidas no mesmo gate (`[!]`), mas não exige que o agente nomeie a premissa compartilhada pelas tentativas falhas, nem conta as tentativas, nem há gate cobrindo isso.
2. **(P2)** Não há sinal de complexidade ciclomática/CRAP sobre o código dos consumidores — decisão anterior (`code-style.md:58,135`) tratou complexidade como gatilho de extração, nunca como gate bloqueante, e essa decisão permanece válida, mas não existe hoje nem o sinal não-bloqueante.
3. **(P3)** Não há detector de duplicação estrutural de código — a convenção vigente (`code-style.md:99`, regra de três) é filosoficamente distinta do limiar fixo do ub-mode (duplicação ≥ 0,8), e essa distinção deve ser preservada numa eventual adoção.
4. **(P5)** Supressão de compilador/linter sem justificativa (`@ts-ignore`, `eslint-disable`, `# noqa`) não é varrida por nenhum scanner hoje, embora `quality-gates.md:74,128` já peça isso em prosa.

Um quinto item, **(P4)**, mutação sistemática sobre código de consumidor, não tem item numerado nesta lista porque não é uma lacuna de convenção — é um gap de ferramenta (nenhum Stryker/PIT/mutmut amarrado ao `/forge:verify`), registrado só como follow-up condicionado (ver §3 e REQ-07).

O relatório completo (tabela regra-a-regra do ub-mode com equivalente real ou lacuna, por arquivo:linha; riscos e trade-offs de cada proposta) está versionado neste mesmo change em `reference/plano-ub-mode-vs-forge-harness.md` (cópia idêntica à entregue em `~/Downloads/plano-ub-mode-vs-forge-harness.md`) e é a referência de verdade para as seções abaixo — este proposal resume a decisão de escopo, não repete a tabela inteira.

Decisão explícita do usuário: aceitar a ordem recomendada do plano, mas por ora **só a documentação SDD** (proposal → requirements → design → tasks) — sem `/forge:implement`. A implementação de cada peça é trabalho de uma sessão futura, decidida item a item.

## 2. O que muda

Este change produz APENAS artefatos de planejamento (requirements.md, design.md, tasks.md) para as duas peças já aprovadas sem pendência (P1 e P5) e para o par spike-de-medição + ADR que a ordem recomendada exige antes de qualquer gate novo de complexidade/duplicação (P2/P3). P4 (mutação de código de consumidor) e a decisão final do ADR ficam fora do tasks.md executável — aparecem apenas como trabalho futuro condicionado ao resultado do spike/ADR, documentado no design.

Nenhum arquivo de `.forge/rules/`, `.forge/commands/`, `.forge/agents/` ou `tests/*-gate.sh` é alterado NESTA SESSÃO (requirements/design/tasks) — essa é a afirmação, não uma garantia sobre a implementação futura. O `tasks.md` resultante descreve TASKs prontas para execução numa sessão futura, com TDD red-first e teste/gate explícitos por TASK, e essas TASKs VÃO editar os arquivos citados quando `/forge:implement` rodar — só não nesta rodada.

## 3. O que NÃO muda (fora de escopo)

- P2 (gate de complexidade/CRAP) e P3 (gate de duplicação) não são implementados aqui — ficam descritos no design como trabalho condicionado à decisão do ADR (item do próprio plano desta proposta), que também não é escrito como ADR formal nesta rodada, só desenhado.
- P4 (mutação de código de consumidor) não entra em tasks.md executável — fica registrado como item de ledger/follow-up no design, condicionado a um consumidor crítico (ex.: pagamentos) que justifique o custo de CI.
- Nenhuma dependência das ferramentas `crapper`/`dryer`/`mutator` do próprio ub-mode é adotada como dependência externa — o plano já recomenda vendorizar/reimplementar, nunca depender do upstream (autor único, sem release, achado de segurança aberto no `crapper`).
- Nada do texto do `SKILL.md` do ub-mode é copiado literalmente — o repositório ganhou licença MIT em 2026-11-02 (commit `3da62bf`, posterior a esta proposta), mas a decisão de não copiar o texto permanece por escopo e filosofia diferentes, não por ausência de licença.

## 4. Impacto

- **Capacidades afetadas:** `forge-harness-template` (rules de convenção `session-discipline.md`, `code-style.md`, `quality-gates.md`; comandos `implement.md`, `coding-status.md`, `verify.md`, `archive.md`, `ship.md`; agent `task-coder.md`; comando `coding-loop.md`; skill `gate-runner`; hook `hooks/git/pre-push`) — confirmado em design.md §2 (o caminho `/forge:red` foi avaliado e removido do escopo durante a fase de design — ver design.md §2.1; `verify.md`/`archive.md`/`ship.md`/`pre-push` entraram na 6ª-7ª rodada de revisão, ao fechar a fiação real da mitigação do REQ-01 e da base do diff do REQ-03/04).
- **Paths afetados:** nenhum nesta rodada (documentação apenas); os paths que as TASKs do `tasks.md` tocarão numa implementação futura serão listados no próprio `tasks.md`.
- **Dependências:** nenhuma spec/código pré-existente bloqueia este change. Depende do relatório externo citado na seção 1 como insumo, não como gate.
- **Riscos:** o maior risco é a P1 (Attack the Premise) introduzir burocracia no protocolo `[!]` sem valor real, já que a premissa é auto-declarada pelo próprio agente (o mesmo resíduo epistêmico do Red-first, onde o teste prova que algo foi escrito, não que está certo). O design deve registrar esse risco e propor mitigação (ex.: a premissa entra no relatório de verificação humana, não é só um campo que o agente preenche e segue).

## 5. Próximos passos

`/forge:requirements` → `/forge:design` (scale 2 exige design) → `/forge:tasks`. Parar aí — sem `/forge:implement` nesta rodada, por instrução explícita do usuário.
