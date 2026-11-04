# Plano: o que absorver do `unclebob/ub-mode` no forge-harness

## Resumo executivo

Vale absorver pouco, e com cuidado. Das 24 regras do ub-mode, 17 já existem no harness, quase sempre com mecanismo mais forte do que a prosa dele. Duas seriam regressão se copiadas: push direto para main e limpeza de worktree decidida pelo agente. As lacunas reais são quatro. Falta uma métrica de complexidade/CRAP, falta um detector de duplicação estrutural, falta mutação sistemática no código dos consumidores, e o "Attack the Premise" existe só pela metade. Há também um ponto pequeno: nenhum scanner do harness pega supressão de compilador. O valor está nas ferramentas companheiras, não no `SKILL.md`. Absorver as duas primeiras lacunas como portão bloqueante contraria decisões já registradas no harness, então a recomendação é absorver como sinal não bloqueante.

## Fatos verificados sobre o ub-mode

- **O repositório.** Tem só `SKILL.md` (152 linhas) e `README.md`. São 4 commits, todos em 2026-10-25, 6.478 estrelas, 365 forks, nenhum release e **nenhuma licença** (a issue #5 pergunta qual será). Sem licença, copiar o texto não é permitido, só a ideia.
- **Correções à pesquisa preliminar.** (1) As ferramentas existem, só que em repositórios próprios: `unclebob/crapper`, `dryer`, `mutator` e `uml-viewer`. As três primeiras são em Python, licença 0BSD, criadas em 2026-09-30, sem releases e com 5 a 11 commits cada. (2) A mutação tem meta definida: "Kill the survivors", e o `mutator` sai com código 3 se sobrar qualquer mutante vivo, ou seja, zero sobreviventes. (3) O limiar de duplicação é 0,8 no `SKILL.md`, mas o padrão do `dryer` é 0,82.
- **Linguagens suportadas pelas ferramentas.** Clojure, Java, Go, TypeScript/JS (inclusive `.mjs`), Rust e Python. **Não suportam C#/.NET, Kotlin nem Bash.**
- **Issues abertas que importam aqui.**
  - #2 e a PR #8 apontam que "push to main" e "reclaim the disk" dão autoridade demais ao agente.
  - #3 diz que a skill não ensina a rodar o crapper.
  - #10 relata problemas de segurança no crapper: ele instala `@vitest/coverage-v8` sozinho (CWE-829) e há um XXE no parser JaCoCo (CWE-776). O crapper também instala `coverage`/`pytest` no interpretador do projeto.

## Regra do ub-mode → equivalente no forge-harness

| Regra do ub-mode | Situação | Onde está no harness |
|---|---|---|
| Laziness: uma decisão num lugar só | Coberto, com violação conhecida | Princípio de fonte canônica e fiação derivada (`tests/w215-hook-wiring-derived-gate.sh`). A violação é o LDG-0152 (aberto): `fm_field` repetido em três lugares |
| Menor edição que resolve | Coberto | `template/.forge/rules/testing/tdd.md:22` |
| Formato dos dados antes da lógica | Coberto pelo pipeline | Fase de design obrigatória em scale ≥ 2; `templates/spec/design.md` |
| Escritor concorrente → não compartilhar estado | Coberto, com mecanismo | `rules/conventions/liaison-protocol.md:28,41` (um escritor por arquivo); `heavy-resource-serialization.md:17` (`lib/heavy-mutex.sh`) |
| TDD: vermelho antes, falhando pelo motivo certo | Coberto e **imposto** | `commands/specs/implement.md:41-44` + `red-evidence.sh task`, testado em `tests/w242-implement-red-mecanismo-gate.sh` |
| Teste honesto impraticável → não escreva um ruim | Coberto | `rules/testing/regression-red-first.md:78` (waiver em vez de teste fabricado); `tdd.md:43` |
| Redesign from first principles | Coberto só no artefato | `templates/spec/design.md:13` (alternativas consideradas). Nada mecânico; é julgamento |
| **Attack the Premise** | **Parcial** | `implement.md:54` e `session-discipline.md`: depois de 2 tentativas, marca `[!]` e para. Não exige nomear a premissa, não conta tentativas e nenhum gate cobre isso (grep `2 tentativas` em `tests/*-gate.sh` não acha nada) |
| Subtract before you add | Não existe | É só julgamento; não recomendo virar regra (ver abaixo) |
| Resultado verificável; quebra planejada e reversível | Coberto | Tasks com `Teste (comando)` e `Padrão de falha`; waves; expand-contract em `templates/refactor/refactor.md` §5 |
| Build the Lever | Coberto (é a filosofia central) | Tudo "operado por script determinista"; 218 gates |
| Domínio sem estados ilegais; glossário | Coberto | `rules/architecture/ddd.md:20`; `rules/conventions/naming.md:19-23`; `ddd.md:132` |
| Validar na borda, confiar dentro | Coberto | `rules/conventions/code-style.md:81,105` |
| Não silenciar o compilador | **Coberto em .NET, prosa no resto** | `dotnet-baseline.sh` (`TreatWarningsAsErrors`) e `quality-gates.md:128`. Nenhum scanner procura `@ts-ignore`/`eslint-disable` sem motivo (grep em `scan.sh` e `scripts/*.sh` vazio) |
| Operações idempotentes | Coberto | `tdd.md:41` (propriedade de idempotência obrigatória); `internal-grpc-communication.md:50`; `session-discipline.md:27` |
| Corrigir a causa raiz; guarda que esconde não é correção | Coberto e imposto | `regression-red-first.md` inteiro, com replay no CI (`red-evidence.sh ci`) |
| Unidades verificáveis em sequência | Coberto | Commit atômico por task, waves, `[X]` só com prova (`implement.md:44-46`) |
| Teste que passa com tudo retornando nada → jogar fora | **Coberto e imposto, mais forte que o ub-mode** | `implement.md:42-43`: os stubs devolvem valor neutro e o teste precisa falhar por asserção; reprova com `vermelho-passa` (w242) |
| **CRAP < 10 (crapper)** | **Lacuna confirmada, com decisão contrária registrada** | Nenhum gate mede complexidade: os hits de "duplicata/complexity" em 13 gates são sobre dados, não código. `code-style.md:58` diz que complexidade é "gatilho de extração, não um portão"; `code-style.md:135` diz "não é novo gate bloqueante"; o `eslint.config.mjs` do pack Node não tem regra `complexity` |
| **Duplicação ≥ 0,8 (dryer)** | **Lacuna confirmada, com filosofia diferente** | Não há detector de clones. `code-style.md:99` manda extrair só na terceira repetição, o oposto de "eliminar ≥ 0,8" |
| **Mutator (cobrir, matar sobreviventes, apagar código morto)** | **Lacuna para consumidores; artesanal no próprio harness** | 73 dos 218 gates têm prova de mutação escrita à mão (controle e recontrole), cobrindo só os gates. Nenhuma ferramenta (Stryker, PIT, mutmut) para código de consumidor. LDG-0021 aberto e relacionado |
| Refactoring: fixar, mudar, provar | Coberto no artefato | Tipo `refactor` com invariantes e suíte antes/depois (`templates/refactor/refactor.md` §1 e §6); `verify.md:30` |
| Keep a Log e reportar no fim | Coberto de forma durável; o relatório em chat seria regressão | `approval-log.sh`, `progress.json`, `run-manifest`, `/forge:handoff`, commit por task. `session-discipline.md` proíbe resumo narrativo por task |
| Guard the Context Window | Coberto | `rules/conventions/session-discipline.md` inteira; stories/shard; grafo de código |
| Worktree cleanup | **Coberto melhor; o ub-mode é regressão** | `scripts/worktree-reconcile.sh` (`--triage`) só propõe e nunca remove, com medição que justifica: 23 de 36 worktrees "limpas" tinham estado ignorado irrecuperável. Gates w175 e w210 |
| Commit and push na main | **Regressão** | `commands/git/ship.md:17,122`: alvo sempre `develop`, merge com confirmação humana e code-evaluator APPROVED |

## Propostas para as lacunas confirmadas

Todos os gates novos aparecem como "wNNN". `gate-ordinal.sh next` estima **w321** hoje (nota: no momento desta análise o ordinal w321 já havia sido reivindicado em paralelo por um hotfix de segurança, PR #256 — o número real só se define no merge, porque PRs paralelos sempre colidem).

**P1. Attack the Premise no protocolo `[!]`** (esforço pequeno, prioridade alta)
- Editar `commands/specs/implement.md:54`, `rules/conventions/session-discipline.md` (Falha irrecuperável), `agents/coding/task-coder.md` §3.7 e o bloco "Última falha" de `commands/coding/coding-loop.md:67`.
- O `[!]` por gate reprovado repetidamente passa a exigir dois campos: `Premissa:` (uma frase dizendo qual suposição as duas correções compartilhavam) e `Tentativas: N`.
- Se `progress.schema.json` tiver estado por task, acrescentar `premise` obrigatório quando o motivo for `gate-retry`. Isso precisa ser confirmado no design; não verifiquei o schema a fundo.
- Gate wNNN: um `[!]` sintético sem `Premissa:` reprova, com controle e recontrole por mutação da cláusula.
- Estender ao `/forge:red`: duas correções que falham no mesmo replay param e exigem a premissa antes da terceira.

**P2. Sinal de complexidade/CRAP restrito ao diff** (esforço médio, prioridade média)
- Script novo `template/.forge/scripts/crap-scan.sh` (ou skill `complexity-scan`), com `--changed` e saída de uma linha por função, no padrão do `node-quality-scan`. Os achados entram como candidatos no `quality-reviewer`/`code-evaluator`.
- Por stack:
  - JS/TS: complexidade via AST com `@babel/parser`, que já é devDependency, cruzada com cobertura LCOV de c8/vitest. A fórmula é trivial (CC² × (1 − cov)³ + CC) e pode ser vendorizada sem trazer o crapper.
  - .NET: CA1502 ou Sonar S3776 como INFO no `dotnet-baseline.sh:168-177`.
  - Java e Python: crapper opcional, ou lizard (suporte de linguagem não verificado).
- Gate wNNN com três estados (universo vazio reprova, no padrão do w144) e prova de mutação: uma função com CC 12 e 0% de cobertura precisa aparecer.
- Dogfood: as 19.788 linhas de `.mjs` do harness.
- **Não bloqueante** enquanto não existir ADR revendo `code-style.md:58` e `:135`.

**P3. Detector de duplicação estrutural** (esforço médio, prioridade média-baixa)
- Mesma arquitetura do P2 (script, sinal, candidatos para o revisor).
- Motor: jscpd, que é multi-linguagem e talvez cubra C#, Kotlin e shell (verificar no spike), ou `dryer` só para JS/Python/Java.
- Conciliar com a regra de três de `code-style.md:99`: duas ocorrências são informativas, três ou mais são candidatas a extração.
- Teste de valor: ele deveria achar o LDG-0152. Mas esse caso é em Bash, que o dryer não lê.

**P4. Mutação no código de consumidor, no `/forge:verify`** (esforço grande, prioridade baixa)
- Só sobre arquivos alterados, como sinal no `verification.md`.
- Ferramentas: StrykerJS, Stryker.NET, PIT e mutmut, em vez do `mutator`, que não cobre .NET e exige `../crapper` ao lado.
- Roda sob `heavy-mutex`.
- **Não aplicar ao próprio harness**: cada mutante rodaria `run-all.sh` (218 gates, que o CI divide em 3 shards), custo proibitivo. A mutação artesanal por gate continua.
- Encaixar no LDG-0021.

**P5. Supressão de compilador sem motivo** (esforço pequeno, prioridade média)
- Nova regra no `skills/node-quality-scan/scripts/scan.sh`, ou ESLint `@typescript-eslint/ban-ts-comment` com `allow-with-description` no `capabilities/backend-node-postgres/assets/eslint.config.mjs`.
- Pegar `@ts-ignore`, `eslint-disable` e `# noqa`/`# type: ignore` (Python) sem referência de issue, como pede `quality-gates.md:74,128`.
- Gate com mutação.

## O que não absorver

Push para main e limpeza de disco feita pelo agente seriam retrocesso: `ship.md` e `worktree-reconcile.sh` já resolvem melhor, e as issues #2 e #8 do próprio ub-mode reconhecem o problema.

"Keep a Log" como relatório no chat contraria `session-discipline.md`, e o harness já guarda esse registro em arquivo.

"Subtract Before You Add", "Laziness" e "Redesign from First Principles" entrariam como prosa sem verificação. Isso contraria a norma do projeto de que toda regra vem com verificação determinística. No máximo caberiam como item de checklist no `design-validator`.

Nada do texto do `SKILL.md` pode ser copiado, porque o repositório não tem licença.

## Riscos e trade-offs

| Proposta | Riscos |
|---|---|
| P1 | Burocracia na hora do `[!]`; a premissa é auto-declarada, então o gate prova que ela foi escrita, não que está certa (o mesmo resíduo do Red-first) |
| P2 | Falso positivo em `switch` e tabela de despacho (o próprio ub-mode diz "consider whether case statements are worth reducing"); cobertura gerada pelo scanner altera o ambiente do consumidor (é o problema da issue #10); fatiamento cosmético perto do limiar, já visto com `max-lines` (LDG-0061); o Bash, que é 77 mil das cerca de 97 mil linhas do harness, fica fora |
| P3 | Ruído alto em código gerado e testes; empurra para a abstração prematura que `code-style.md:99` evita |
| P4 | Tempo de CI, mutantes que não compilam contam como mortos, e mantém quatro ferramentas por stack |
| Dependência das ferramentas UB | Autor único, um mês de vida, sem release, com problemas de segurança abertos. O precedente do LDG-0061 (vibe-coding-toolkit) recomenda vendorizar uma cópia nossa, nunca depender do upstream |

## Ordem recomendada

1. **P1**, que é barato e fecha a lacuna mais clara de método.
2. **P5**, pequeno e já previsto em `quality-gates.md`.
3. **Spike de medição**, antes de P2 e P3: rodar os detectores de complexidade e duplicação em modo leitura sobre os `.mjs` do harness e sobre um consumidor Node, e contar achados por limiar. Não foi executada nenhuma ferramenta nesta análise, então não há número ainda.
4. **ADR** decidindo se complexidade e duplicação continuam sinal ou viram portão.
5. **P2**, depois **P3**.
6. **P4**, só se houver um consumidor com lógica crítica (pagamentos, por exemplo) que justifique o custo.

---

*Análise gerada por agente Opus (effort high) em 2026-11-02, a partir de leitura direta do `SKILL.md`/`README.md` do `unclebob/ub-mode`, dos repositórios `crapper`/`dryer`/`mutator`, e de grep real sobre os ~219 gates (`tests/*-gate.sh`), `template/.forge/rules/`, `template/.forge/commands/`, `template/.forge/agents/` e `template/.forge/scripts/` do forge-harness. Nenhum arquivo do repositório foi alterado nesta análise.*
