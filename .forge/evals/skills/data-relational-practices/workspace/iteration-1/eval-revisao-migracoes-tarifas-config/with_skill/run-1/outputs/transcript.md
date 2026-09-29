# Transcript — eval-revisao-migracoes-tarifas-config / with_skill / run-1

## 1. Bootstrap e preparação da fixture

- `date +%s > .t0` — marca o instante inicial.
- `mkdir -p work` e `bash fixtures/revisao-migracoes-tarifas-config/setup.sh work` — monta o consumidor via `forge.mjs init --no-plugin` + overlay do caso (`services/tarifas-config`, `services/recargas-api`) + `git init`/commit inicial da fixture (script do próprio harness, não uma ação minha sobre o repositório real). O setup remove `.forge/skills`, `.forge/agents`, `.claude/skills`, `.claude/agents` e `plugin/` do alvo antes de commitar, para não contaminar o baseline com a maquinaria de skill.

## 2. Leitura dos arquivos do caso

- `services/tarifas-config/migrations/V001__cria_tarifas.sql` — baseline em produção: `tarifas` com `id bigint GENERATED ALWAYS AS IDENTITY`, `valor_tarifa_em_centavos bigint`, `fator_tarifa numeric(6,4)`, `taxa_desconto_percentual numeric(5,2)`, `vigente_desde timestamptz`, RLS completo (`ENABLE` + `FORCE` + `CREATE POLICY`), `SET lock_timeout = '5s'` no topo.
- `services/tarifas-config/migrations/V002__integracao_e_parametros.sql` — a migração sob revisão.
- `services/tarifas-config/src/repositorios/tarifas_repo.ts` — o acesso a dados sob revisão.
- `services/tarifas-config/README.md` — Node/TypeScript, PostgreSQL 16, pool `pg` sem PgBouncer, multi-tenant por operadora.

## 3. Protocolo da skill `data-relational-practices` (SKILL.md, seção "Protocolo")

Segui a ordem fixa que o SKILL.md declara: escopo → rules do projeto → detecção → julgamento → relatório.

### 3.1 Escopo
Dois arquivos afetados: a migração V002 e o repositório TypeScript, ambos dentro de `services/tarifas-config`. Não varri o resto do monorepo (o outro serviço da fixture, `recargas-api`, não foi tocado pela mudança).

### 3.2 Rules do projeto
Li `.forge/rules/data/data-governance.md`, `data-config-sql.md`, `data-transactional-nosql.md`, `data-cache.md`, `.forge/rules/domain/money-as-cents.md`, `.forge/rules/data/schema-evolution.md` e `.forge/rules/conventions/database-naming.md` e `conflict-handling.md`. Pontos que direcionaram o julgamento:
- `data-governance.md`/`data-config-sql.md`: RLS obrigatório em tabela multi-tenant de domínio no PostgreSQL, dispensa só por exceção formal — ausência sem exceção é "conflito bloqueante" (termo textual da rule).
- `money-as-cents.md` §4: `BIGINT NOT NULL` na menor unidade para dinheiro, nunca `NUMERIC`/`DECIMAL`.
- `schema-evolution.md`: expand → migrate → contract; gate de design exige engine, impacto, compatibilidade, rollback, dados históricos, evidência.
- `database-naming.md`: FK como `{tabela_referenciada_singular}_id` (sufixo) — relevante para julgar o rename `linha_id → id_linha`.

### 3.3 Detecção
Comandos executados (dentro de `work/`, cwd do fixture):

```
bash .forge/scripts/check-data-governance.sh --path services/tarifas-config
```
Saída: `OK data-governance/universo` e `OK data-governance` (sem PAN/PII, sem divergência) — nada a reportar aqui, registrado como "verificado e limpo".

```
bash <template>/.forge/skills/data-relational-practices/scripts/scan.sh --root services/tarifas-config
```
Nota: o `setup.sh` removeu `.forge/skills` do alvo (decisão do próprio fixture, para não contaminar o baseline), então rodei o `scan.sh` a partir da cópia read-only em `template/.forge/skills/data-relational-practices/scripts/scan.sh` (o artefato do harness que o item 3 da tarefa autoriza ler), com `--root` apontando para o path dentro de `work/` — o scanner é texto puro (sem estado), então rodar a cópia do template contra o alvo é equivalente a ter o `.forge/skills` instalado no projeto.

Saída relevante (exit 1, achado alto): `FOUND R-03 [alto]` 4 ocorrências na V002 (índice sem `CONCURRENTLY`, rename in-place, troca de tipo, `SET NOT NULL`); `FOUND R-04 [aviso]` (`serial`, `timestamp` sem fuso); `FOUND R-06 [aviso]` (`OFFSET` no repo); `FOUND R-12 [aviso]` (`set_config(..., false)` no repo); `FOUND R-14 [aviso]` (`SELECT *`); `FOUND R-19 [aviso]` (`numeric` em coluna monetária, V001 e V002); `FOUND R-20 [aviso]` (`tenant_id` sem `ENABLE ROW LEVEL SECURITY` no arquivo da V002); `FOUND R-21 [aviso]` (`ALTER`/`CREATE INDEX` sem `lock_timeout` no arquivo). `ARQUIVOS-VARRIDOS 3`.

### 3.4 Julgamento (arquivo:linha, decisão por achado)
Li `references/antipatterns.md` (R-01 a R-22) para confirmar sintoma/correção/evidência de cada id encontrado, e apliquei ao trecho real:
- R-03: os quatro achados são reais, não falso-positivo (nenhum tem `VALIDATE CONSTRAINT` nem é índice sobre tabela criada no mesmo arquivo). Tratados como bloqueantes dado o contexto declarado na task (40M linhas, deploy com serviço no ar).
- R-21: a V002 realmente não tem `SET lock_timeout`, diferente da V001 — subi a severidade de "aviso" para bloqueante no relatório, por causa do volume da tabela e do deploy ao vivo (julgamento contextual, o SKILL.md autoriza isso: "severidade `aviso` é heurística e pode ser exceção legítima" — aqui é o oposto, uma agravante).
- R-20: julguei como bloqueante de verdade (não heurística a descartar) porque `data-governance.md` usa o termo "conflito bloqueante" explicitamente para esse caso, e a V001 mostra que o padrão certo (RLS completo) é o próprio costume do time nesse serviço — `parametros_operador` diverge do próprio precedente.
- R-19: `valor_integracao` é dinheiro pelo nome e pelo contexto (é o companheiro de `valor_tarifa_em_centavos`); julguei `fator_tarifa` e `taxa_desconto_percentual` como não-dinheiro (fator multiplicador e percentual), condizente com a nota do próprio catálogo ("`taxa_juros NUMERIC` não é dinheiro").
- R-04: `serial` e `timestamp` sem fuso são reais e batem com o padrão que a própria V001 já evita.
- R-06/R-14: reais, mas não bloqueantes para quinta — a V002 não altera esse método; registrados como débito.
- R-01 (FK sem índice em `operador_id`): fora do scanner (o SKILL.md documenta que R-01 precisa de runtime), então revisão manual — candidato registrado, não bloqueante (tabela nova, sem tráfego ainda).
- R-12: o achado do scanner é sobre `set_config(..., false)`; ao ler o método inteiro (`pool.connect()` / `client.release()` sem `RESET`), o risco é maior que o rótulo "aviso" do catálogo sugere — é vazamento de tenant entre requisições reutilizando a mesma conexão física, então tratei como achado de segurança de severidade alta no relatório, com a correção (`true` + transação explícita) already coberta pelo próprio catálogo (R-12 "Correção").
- naming: o rename `linha_id → id_linha` foi julgado contra `database-naming.md` — a convenção já é seguida pelo nome atual; o rename é regressão de nomenclatura, não só custo operacional.

### 3.5 Relatório
Escrevi `outputs/docs/revisao-banco-tarifas.md`: tabela achado-por-regra com id do catálogo, severidade, arquivo:linha e a decisão; SQL corrigido em duas partes (o que é seguro para quinta como migração expand-only, e o que precisa de expand→migrate→contract em deploys futuros, deixado como plano, não como SQL pronto, porque depende de quem mais consome as colunas afetadas); correção do `tarifas_repo.ts` (transação + `set_config(..., true)` + projeção de colunas); resumo executável de 6 itens no fim.

## 4. O que não fiz (regras do prompt)

- Não editei nenhum arquivo de `work/` — só li. Toda correção proposta é conteúdo do relatório em `outputs/`, como pedido ("não mexe nos arquivos, só quero o diagnóstico com o que mudar e o SQL corrigido").
- Não rodei `git commit`/`push`/`checkout`/`stash`, `npm test`, `docker`, `ledger-ops.sh`, `liaison-ops.sh`, `gh` de escrita, `npm publish` nem qualquer deploy real. O único `git` executado foi o `git init` + `git commit` de dentro do `setup.sh` da fixture, sobre o repositório efêmero criado em `work/` — não sobre o worktree do harness.
- A tarefa não pediu spawn de subagente; não havia despacho a simular.
- Sem segredo literal em nenhum artefato produzido.
