# Revisão — V031__tarifa_por_linha.sql

Contexto que muda a revisão: a migração roda em produção com a versão **anterior** da aplicação ainda atendendo tráfego (deploy contínuo, sem janela de manutenção), e a tabela `viagem` tem ~60 milhões de linhas. Isso torna dois dos achados abaixo bloqueantes por si só, independentemente de estilo.

## Achados, por severidade

### 1. Bloqueante — `CREATE INDEX` sem `CONCURRENTLY` em `viagem` (60M linhas)

```sql
CREATE INDEX idx_viagem_validador_id ON viagem (validador_id);
```

`CREATE INDEX` comum toma um lock `SHARE` na tabela e o mantém até o índice terminar de ser construído. Isso bloqueia todo `INSERT`/`UPDATE`/`DELETE` em `viagem` — não apenas leituras — pela duração inteira da construção. Em 60 milhões de linhas isso é da ordem de minutos a dezenas de minutos, e o serviço é de validação/bilhetagem em tempo real (validadores inserindo `viagem` continuamente). O resultado prático é uma parada de escrita em produção disfarçada de migração de rotina.

Correção: `CREATE INDEX CONCURRENTLY`. Trade-off: não pode rodar dentro de uma transação, e o Flyway (community) envolve cada script `.sql` numa transação por padrão — então este índice precisa sair para um arquivo próprio com a transação desabilitada para esse script (ver `V032__idx_viagem_validador_id.sql` nesta pasta). `CONCURRENTLY` também pode deixar um índice `INVALID` se for interrompido; documentei o runbook de retomada no próprio arquivo.

### 2. Bloqueante — `RENAME COLUMN` quebra a versão da app ainda no ar

```sql
ALTER TABLE linha RENAME COLUMN codigo TO codigo_linha;
```

Tecnicamente o `RENAME COLUMN` em si é barato (só metadata; `linha` tem poucos milhares de linhas, não é questão de lock/tamanho). O problema é de compatibilidade: a versão anterior do serviço, que continua recebendo tráfego durante o rollout, referencia a coluna pelo nome antigo `codigo`. No instante em que esta migração roda, qualquer `SELECT codigo`, `INSERT INTO linha (codigo, ...)` ou mapeamento ORM da versão antiga passa a falhar com "column does not exist" — em produção, sem deploy de código nenhum, só por causa da migration.

Isso é exatamente o cenário que o padrão expand/contract existe para evitar: renomear é uma mudança "contract" e só pode acontecer depois que todos os produtores/consumidores já migraram. Correção aplicada em `V031__tarifa_parametro.sql`: fase "expand" — adiciona `codigo_linha` como coluna nova, faz backfill (`UPDATE` em lote único, seguro dado o volume de `linha`), e mantém as duas colunas sincronizadas com um trigger `BEFORE INSERT OR UPDATE`, para que tanto a versão antiga (que só conhece `codigo`) quanto a nova (que passa a usar `codigo_linha`) funcionem durante a janela de rollout. A remoção de `codigo` fica para uma migração futura (V033, não escrita aqui — quem decide o timing é quem observa a implantação da nova versão), depois que a versão antiga não estiver mais em circulação.

### 3. Alto — tabela nova sem RLS quebra o isolamento multi-tenant do serviço

```sql
CREATE TABLE tarifa_parametro (
  ...
  tenant_id uuid NOT NULL,
  ...
);
```

`linha` e `viagem` (V030) têm `tenant_id` **e** `ENABLE ROW LEVEL SECURITY` + `FORCE ROW LEVEL SECURITY` + policy por `tenant_id`. `tarifa_parametro` tem a coluna `tenant_id` mas nenhuma RLS — ou seja, uma query sem filtro explícito de tenant (bug de aplicação, engano de `WHERE`, relatório administrativo mal escrito) vazaria parâmetros de tarifa entre operadoras de transporte concorrentes. Isso é regressão em relação ao padrão já estabelecido no mesmo schema duas migrações antes, não uma omissão neutra — cada tabela multi-tenant de domínio em PostgreSQL precisa do mesmo mecanismo de isolamento, sem exceção não documentada.

Correção: `ENABLE ROW LEVEL SECURITY` + `FORCE ROW LEVEL SECURITY` + `CREATE POLICY ... USING (tenant_id = current_setting('app.tenant_id')::uuid)`, replicando literalmente o padrão de `linha`/`viagem`.

### 4. Médio — valor monetário como `NUMERIC(10,2)` em vez de inteiro em centavos

```sql
valor_tarifa NUMERIC(10,2) NOT NULL,
```

O restante do domínio representa dinheiro como `bigint` em centavos (`valor_cobrado_em_centavos` em `viagem`). `NUMERIC(10,2)` para "valor_tarifa" introduz uma segunda representação de dinheiro no mesmo serviço — ambígua quanto à unidade (reais? centavos com 2 casas erradas?) e fora do padrão que evita erro de arredondamento em cálculo financeiro encadeado (tarifa × viagens, por exemplo). Também é limite de precisão desnecessário (`NUMERIC(10,2)` cobre até R$ 99.999.999,99, plausível hoje, mas é um teto arbitrário que `bigint` em centavos não tem).

Correção: `valor_tarifa_em_centavos bigint NOT NULL`, com o sufixo `_em_centavos` explícito, no padrão de `viagem.valor_cobrado_em_centavos`.

### 5. Médio — `id serial` em vez de `bigint GENERATED ALWAYS AS IDENTITY`

```sql
id serial PRIMARY KEY,
```

`linha` e `viagem` usam `bigint GENERATED ALWAYS AS IDENTITY`. `serial` cria uma sequência `int4` (32 bits, teto ~2,1 bilhões) e é a forma mais antiga/desencorajada desde que identity columns existem em Postgres (10+). Numa tabela de parâmetros de tarifa o volume provavelmente nunca chega perto do teto — mas é uma inconsistência de convenção sem motivo, e o tipo primário divergente (int4 vs bigint) complica qualquer FK futura para esta tabela.

Correção: `id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY`, igual às demais tabelas do serviço.

### 6. Médio — `vigente_desde timestamp` sem timezone

```sql
vigente_desde timestamp NOT NULL
```

Todo o restante do schema usa `timestamptz` (`criado_em`, `ocorrida_em`). `timestamp` sem timezone armazena um valor "ingênuo" — a interpretação de fuso fica implícita na sessão/aplicação que escreveu, o que é uma fonte clássica de bug silencioso quando há mais de um fuso envolvido (operadoras de transporte diferentes, servidores em regiões diferentes, ou só um `date` mal configurado na sessão do banco). Para "vigente desde" de uma tarifa — um instante que decide qual valor cobrar numa viagem específica — a ambiguidade de fuso é diretamente um risco de cobrança errada.

Correção: `vigente_desde timestamptz NOT NULL`.

### 7. Baixo — falta `lock_timeout` nesta migration

A V030 abre com `SET lock_timeout = '5s';`; a V031 original não repete isso. Sem um `lock_timeout` baixo, se esta migração encontrar contenção (por exemplo, uma transação longa segurando lock em `linha` ou `viagem` no momento do deploy), ela pode ficar bloqueada por um tempo indefinido segurando, por sua vez, locks que enfileiram outras queries atrás dela — o efeito clássico de "fila de lock" que trava o banco inteiro, não só a migration. Reaplicado no topo de `V031__tarifa_parametro.sql` corrigido.

### 8. Sugestão (não bloqueante) — índice de apoio em `tarifa_parametro`

Não estava na migration original, mas vale registrar: a consulta natural sobre esta tabela é "qual a tarifa vigente para esta linha, neste tenant, nesta data" — um índice `(tenant_id, linha_id, vigente_desde DESC)` atende tanto o isolamento por tenant quanto a busca da tarifa mais recente sem scan. Incluí esse índice na versão corrigida (`V031__tarifa_parametro.sql`); como a tabela nasce vazia, criá-lo sem `CONCURRENTLY` não é um problema de lock — diferente do índice em `viagem`.

## Versão corrigida

Divido em dois arquivos porque o achado #1 exige rodar fora de transação, e o Flyway (community) envolve cada `.sql` numa transação por padrão — misturar as duas coisas no mesmo script não funciona:

- `V031__tarifa_parametro.sql` — tabela nova (com RLS e tipos corretos) + fase "expand" do rename de `linha.codigo`.
- `V032__idx_viagem_validador_id.sql` — o índice em `viagem`, com `CONCURRENTLY`, fora de transação, com runbook de retomada em caso de índice `INVALID`.

Um terceiro passo (V033, não escrito aqui) fica para depois que a nova versão do serviço estiver 100% implantada: remover a coluna `codigo` e o trigger de sincronismo. Não é possível determinar o timing certo dessa remoção sem visibilidade do rollout real — decisão de quem aplica/observa o deploy, não desta revisão.

## O que confirma esses achados no próprio repositório

- `.forge/rules/data/schema-evolution.md` — exige classificar toda alteração como compatível/expandida/excepcional e formaliza o fluxo expand → migrate/backfill → contract; um rename direto pula essa sequência.
- `.forge/rules/data/data-governance.md` — trata "RLS ausente em tabela multi-tenant de domínio em PostgreSQL" como anti-padrão bloqueante.
- `.forge/rules/domain/money-as-cents.md` — proíbe `DECIMAL`/`NUMERIC`/`FLOAT` para valores monetários; exige `BIGINT` com sufixo `_em_centavos`/`InCents`.
- `services/tarifacao/README.md` — declara explicitamente o deploy contínuo sem janela (app anterior ainda atendendo) e o volume de `viagem` (~60M linhas), que são a origem dos achados #1 e #2.

## O que NÃO mudei

- Não toquei na FK `linha_id bigint NOT NULL REFERENCES linha(id)` — está correta e consistente com o restante do schema.
- Não decidi o momento de aplicar V033 (drop de `codigo`) — depende de observação do rollout real em produção, fora do escopo desta revisão de código.
- Não apliquei nada — apenas revisei e escrevi a versão corrigida; quem aplica é o task-coder, conforme pedido.
