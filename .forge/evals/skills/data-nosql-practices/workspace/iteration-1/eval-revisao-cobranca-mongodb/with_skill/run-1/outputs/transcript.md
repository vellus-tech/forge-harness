# Transcript — eval-revisao-cobranca-mongodb / with_skill / run-1

## Bootstrap
- `cd .forge/worktrees/evals-100 && pwd && git branch --show-current` — confirmou diretório e branch
  `chore/evals-skills-agentes` conforme esperado pelo prompt.

## Preparação
1. `date +%s > .t0` — instante inicial gravado.
2. `mkdir -p .../run-1/work` e `bash .../fixtures/revisao-cobranca-mongodb/setup.sh .../run-1/work` — o
   script montou a fixture: `node bin/forge.mjs init --target work -y --no-plugin`, copiou o overlay do caso
   (`docs/contexto-cobranca.md` + `services/cobranca/**`), removeu `.forge/skills`, `.forge/agents`,
   `.claude/skills`, `.claude/agents` e `plugin/` do alvo (para não contaminar o baseline com a skill sob
   teste) e fez `git init` + commit inicial dentro do próprio diretório `work/` (repositório novo e isolado,
   distinto da árvore do worktree `evals-100`).

## Leitura do caso
- `docs/contexto-cobranca.md`: serviço multi-tenant, MongoDB 7.0 replica set P-S-S; padrões de acesso —
  extrato de carteira a ~1.800 req/s, listagem de faturas do backoffice, fechamento noturno 02:00,
  transferência de crédito entre carteiras (centenas/hora, picos concorrentes no início do mês), faturas com
  até milhares de eventos.
- Arquivos do serviço lidos por inteiro: `src/repositorios/faturaRepositorio.ts`,
  `src/transferencia/transferirCredito.ts`, `src/relatorios/fechamentoNoturno.ts`,
  `src/api/extratoHandler.ts`, `infra/mongod.conf`, `test/seed.ts`.

## Skill carregada (protocolo `data-nosql-practices`, seguido à risca)
1. **Escopo** — path `services/cobranca`, padrões de acesso listados acima (a partir do contexto de uso, como
   o passo 1 do protocolo pede).
2. **Rules do projeto** — li `.forge/rules/data/data-transactional-nosql.md` (tenant obrigatório, filtro no
   repositório, índice composto por tenant, `majority`) e a seção "Regras da casa" de
   `references/best-practices.md` (que também cita `money-as-cents.md`).
3. **Detecção** —
   - `bash .forge/scripts/check-data-governance.sh --path .../work/services/cobranca` → `OK` (5 arquivos de
     código, sem divergência).
   - `bash template/.forge/skills/data-nosql-practices/scripts/scan.sh --root .../work/services/cobranca` →
     achados N-01, N-04 (×2), N-07 (×2), N-18, N-20, N-21 (×3), N-23; N-06/08/09/10/11/13/15/17/19 sem
     ocorrência. Rodei o `scan.sh` do template (somente leitura), como autorizado pela tarefa, já que a
     fixture removeu `.forge/skills` do próprio `work/`.
4. **Julgamento** — cruzei cada `FOUND` com `references/antipatterns.md` e decidi severidade/ação; fiz
   também a revisão manual que o scanner declara não cobrir: filtro de tenant em runtime (achei ausência em
   `buscarPorCliente`) e write skew entre documentos (N-22 — achei a transferência lendo `saldos` e nunca
   escrevendo nele, o pior caso do padrão descrito na própria referência da skill).
5. **Relatório** — escrito em `docs/revisao-nosql.md` dentro do projeto (`work/`), uma seção por achado com
   id do catálogo, arquivo:linha e correção, mais os itens verificados sem achado e o que ficou fora do
   alcance por exigir runtime/produção — no formato pedido pelo passo 5 do protocolo.

## Achados principais (ver `docs/revisao-nosql.md` para o detalhe)
1. **Bloqueante** — `transferirCredito.ts` nunca atualiza o saldo consolidado (`saldos`/`carteiras`); duas
   transferências concorrentes passam no teste de saldo e ambas commitam (write skew, N-22), agravado pelos
   picos de concorrência do início do mês citados no contexto.
2. **Bloqueante** — `faturaRepositorio.buscarPorCliente` não filtra por `tenant`: conflito direto com
   `data-transactional-nosql.md` ("conflito bloqueante").
3. `readConcern: "local"` na transação de dinheiro (N-20).
4. `Decimal128` no valor da fatura, violando `money-as-cents.md` (N-21) — inconsistente com o resto do
   serviço, que já usa centavos inteiros.
5. `writeConcern: { w: 1 }` na criação de fatura (N-07).
6. `$lookup` no caminho quente do extrato (~1.800 req/s), sem `$sort`/`$limit` no pipeline e sem índice
   declarado para `lancamentos` por `carteira` (N-04).
7. Commit sem retry de `UnknownTransactionCommitResult` — `startTransaction`/`commitTransaction` manual em
   vez de `withTransaction` (N-23).
8. `bindIp: 0.0.0.0` em `infra/mongod.conf` (N-18).

## Decisões de escopo
- Não corrigi o código — a tarefa do usuário pediu só o diagnóstico.
- Não rodei `git commit`/`push` nem qualquer comando de escrita fora de `work/` e `outputs/`; o único commit
  git executado foi o do próprio `setup.sh` da fixture, dentro do repositório novo criado por ele em `work/`.
- Não spawnei subagentes (a tarefa não pediu para o `data-engineer` delegar formalmente; segui o protocolo da
  skill como especialista único, que é o desenho previsto para "ferramenta sem subagentes" descrito no
  `CLAUDE.md` do projeto de teste).
- `work/` ficou bem abaixo de 20 MB (repositório novo, poucos arquivos de texto) — não foi necessário apagar.

## Finalização
- `t0=$(cat .t0)`, `t1=$(date +%s)`, `timing.json` escrito com `duration_ms=(t1-t0)*1000` e
  `total_duration_seconds=(t1-t0)`; `total_tokens: 0` (não medido nesta execução).
- Tamanho de `work/` conferido — abaixo de 20 MB, mantido.
