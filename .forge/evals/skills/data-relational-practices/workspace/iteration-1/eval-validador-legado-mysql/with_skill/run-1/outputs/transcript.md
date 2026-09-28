# Transcript — eval-validador-legado-mysql / with_skill / run-1

Caso de eval executado sob mandato de workflow computado (harness), sem escrita fora do diretório designado, sem git/tests/ledger/liaison/gh/publish reais, sem sleep em foreground, sem spawn de subagente (nenhum foi necessário nesta tarefa).

## Passos, comandos e decisões, em ordem

1. **Bootstrap** — `cd .../worktrees/evals-100 && pwd && git branch --show-current` confirmou `pwd` e branch `chore/evals-skills-agentes` conforme esperado. Prossegui.

2. **Setup do run** — gravei `.t0` (`date +%s`), criei `work/` e rodei o fixture: `bash .../fixtures/validador-legado-mysql/setup.sh .../run-1/work`. O fixture materializou um projeto Forge completo (`.forge/`, `.claude/`) com `services/validador-legado/{docs/banco.md, db/migrations/*.sql, src/main/kotlin/.../ValidacaoRepository.kt}`.

3. **Leitura da skill carregada** — li `template/.forge/skills/data-relational-practices/SKILL.md` por inteiro e segui o protocolo nele descrito (Escopo → Rules do projeto → Detecção → Julgamento → Relatório), incluindo `references/antipatterns.md` (catálogo R-01..R-22) e `references/best-practices.md` (defaults de isolamento por motor, correção de troca de tipo no MySQL).

4. **Leitura dos artefatos do usuário** — li `services/validador-legado/docs/banco.md` (contexto: MySQL 8.4, ~180M linhas, 2 mil inserts/s, sem janela de manutenção), as duas migrations novas (`20260930_idx_linha_data.sql`, `20260930_cartao_uid_varchar.sql`), a migration já aplicada em produção (`20260815_idx_dispositivo.sql`, para servir de padrão de convenção) e `ValidacaoRepository.kt`.

5. **Passo 2 do protocolo (Rules do projeto)** — listei `work/.forge/rules/data/*` e `work/.forge/rules/domain/*`; li `data-governance.md` (isolamento multi-tenant por store — não aplicável, tabela sem `tenant_id`), `schema-evolution.md` (fluxo expand→migrate→contract, usado depois na correção) e `money-as-cents.md` (não aplicável — nenhuma coluna monetária na tabela `validacoes`). Nenhum conflito de rule/ADR (`data-transacional de negócio` não é o caso; MySQL já é o engine estabelecido do serviço, sem pedido de trocar de store).

6. **Passo 3 do protocolo (Detecção)** — rodei `bash .forge/scripts/check-data-governance.sh --path services/validador-legado` (OK, sem divergência de governança/PII) e `bash .forge/skills/data-relational-practices/scripts/scan.sh --root services/validador-legado`. Achados: `R-04` [aviso] e `R-13` [alto] e `R-21` [aviso] na migration de `cartao_uid`; `R-21` [aviso] e `R-22` [aviso] na migration de índice; nenhum achado em `R-03`, `R-10`, código.

7. **Passo 4 do protocolo (Julgamento)** — para cada `FOUND`, li o trecho e decidi contra `references/antipatterns.md`:
   - `R-13` [alto] confirmado: `ALGORITHM=COPY, LOCK=SHARED` na troca de tipo `cartao_uid` bloqueia escrita numa tabela de 180M linhas sem janela de manutenção — bloqueante.
   - `R-22` [aviso] confirmado: `ADD INDEX` de `idx_linha_data` sem `ALGORITHM=INPLACE, LOCK=NONE` explícitos, quebrando a convenção da migration anterior do mesmo repositório.
   - `R-04` e `R-21` dispensados como falso positivo de engine: ambos escopados a PostgreSQL (`char(n)` do Postgres e GUC `lock_timeout` do Postgres) e disparados por coincidência textual/estrutural em SQL de MySQL.
   - Revisão adicional fora do scanner (ele não entende semântica de tipo/isolamento nem código Kotlin): a alegação de `banco.md` de que o InnoDB usa READ COMMITTED por default está errada — o default é REPEATABLE READ (`references/best-practices.md`, linha "Defaults: PostgreSQL Read Committed; InnoDB REPEATABLE READ").
   - Revisão do `ValidacaoRepository.kt` contra `R-11` (deadlock sem retry correto): dois problemas — código de erro errado (1205 tratado como deadlock; o deadlock real do MySQL é 1213) e retry que reexecuta só `validacoes.last()` após uma falha no meio do lote, descartando silenciosamente os itens anteriores não commitados (perda de dados sem exceção visível).

8. **Correções** — escrevi as quatro correções (SQL da migration de índice, SQL da migration de tipo reformulada como expand-only + roteiro migrate/contract, `ValidacaoRepository.kt` com retry do lote inteiro em transação nova + backoff + ordem estável de chave, `banco.md` com o isolamento correto), salvas em `outputs/` e também aplicadas em `work/` para a árvore ficar coerente com o parecer.

9. **Parecer** — escrito em `work/services/validador-legado/docs/parecer-validador.md`, seguindo o passo 5 do protocolo (uma seção por achado, id do catálogo citado, `arquivo:linha` quando o scanner achou, recomendação com evidência), com tabela-resumo do que bloqueia o merge.

10. **Timing** — `.t0`/`timing.json` gravados ao final conforme o mandato; `work/` ficou em ~5,4 MB, abaixo do limite de 20 MB — não apagado.

## Decisões de escopo do mandato

- Não rodei `git commit/push/checkout/stash`, `tests/run-all.sh`, `npm test`, `docker`, `ledger-ops.sh`, `liaison-ops.sh`, `gh` (escrita) nem `npm publish` — nenhuma dessas ações fez parte da tarefa, então não havia nada a simular/registrar aqui além desta nota.
- Não spawnei subagentes — a tarefa (uma revisão de migrations + um trecho de Kotlin) coube inteira nesta execução, sem necessidade de despacho paralelo.
- Nenhum comando com `sleep` em foreground foi usado.
