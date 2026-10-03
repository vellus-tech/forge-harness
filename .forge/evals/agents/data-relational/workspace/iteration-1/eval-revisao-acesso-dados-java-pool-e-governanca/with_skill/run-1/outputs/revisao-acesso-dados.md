# Revisão de acesso a dados — services/cadastro-operador

Agente: `data-relational` (protocolo `.forge/agents/data/data-relational.md` + skill `data-relational-practices`).
Escopo revisado: `TenantConnectionInterceptor`, `OperadorRepository`, `OperadorService`, `Operador` (entidade), `application.yml`, `V001__operador.sql`.

## Veredito

Ainda **não** pode seguir para o PR. Há um achado bloqueante de isolamento multi-tenant (defesa em profundidade quebrada no ponto onde ela mais importa: pool de conexões + RLS) e uma lacuna de governança sobre o CPF (campo PII sem classificação declarada). Os outros três são não bloqueantes, mas valem corrigir na mesma leva por serem baratos.

## Achados

### 1. BLOQUEANTE — GUC de tenant em escopo de sessão sobre pool HikariCP (catálogo R-12)

`TenantConnectionInterceptor.java:20`
```java
st.execute("SET app.tenant_id = '" + TenantContext.current() + "'");
```

- **Por quê é um problema real, não só estilo:** `SET` (sem `LOCAL`) é estado de **sessão**, não de transação. Conferi no HikariCP (context7, `/brettwooldridge/hikaricp`, wiki *Pool Analysis*) que ao devolver a conexão ao pool o Hikari executa `rollback()` e reseta apenas auto-commit, isolation level, catalog e read-only — **GUCs de aplicação como `app.tenant_id` não são tocados**. O valor permanece gravado na conexão física até alguém rodar outro `SET`/`RESET`.
- Hoje o `getConnection()` deste wrapper roda o `SET` a cada *borrow*, então, **enquanto este for o único ponto de acesso ao pool**, o valor é reescrito antes de cada uso — mas isso é uma garantia frágil, não estrutural: qualquer caminho que pegue uma conexão do mesmo `HikariDataSource` sem passar por este `DelegatingDataSource` (segundo bean de `DataSource` injetado por engano em outro lugar — ex.: Flyway costuma pedir o próprio `DataSource` do contexto e é fácil apontar para o Hikari cru —, um `unwrap`, uma rotina batch, um teste de conexão custom) herda o `app.tenant_id` do tenant anterior, e a policy de RLS (`operador_por_tenant`, `V001__operador.sql`) filtra pelo tenant errado. É exatamente o cenário descrito no catálogo da skill (R-12): "tenant de uma requisição aparecendo na seguinte, lido pela policy de RLS" — e a doc marca isso como defeito com **qualquer pool que reaproveita conexão**, não só PgBouncer em modo transaction.
- Isso também esvazia a defesa em profundidade que `data-governance.md`/`data-config-sql.md` exigem: RLS existe justamente para conter uma falha da camada de aplicação; se o próprio mecanismo de setar o tenant depende de disciplina de "sempre passar por este método", a segunda camada não é independente da primeira.
- **Correção recomendada:**
  ```java
  @Override
  public Connection getConnection() throws SQLException {
      Connection conn = super.getConnection();
      try (PreparedStatement ps = conn.prepareStatement("SELECT set_config('app.tenant_id', ?, true)")) {
          ps.setString(1, TenantContext.current().toString());
          ps.execute();
      }
      return conn;
  }
  ```
  `set_config(..., true)` com o terceiro argumento `true` é `SET LOCAL`: vale só até o fim da transação corrente, some sozinho no commit/rollback e some mesmo se o código nunca mais tocar essa conexão — não depende de ninguém "lembrar" de resetar. Ainda assim, isso protege a *transação atual*; para fechar de vez a superfície, vale um `RESET ALL`/`DISCARD ALL` (ou `connectionInitSql`/listener de `evictConnection` do Hikari) como cinto e suspensório para qualquer conexão que escape deste wrapper.
- Bônus da mesma correção: elimina o segundo problema abaixo.

### 2. Concatenação de string em comando SQL (`TenantConnectionInterceptor.java:20`)

`TenantContext.current()` é `UUID` — hoje não há vetor de injeção prático porque `UUID.toString()` só produz hex e hífen. Mesmo assim, montar SQL por concatenação é o padrão que quebra na primeira vez que alguém trocar o tipo do tenant por `String` ou aceitar um tenant vindo de header sem validação. A correção do item 1 (`PreparedStatement` com bind) resolve isso também — trate como o mesmo fix, não como dois.

Nota lateral, não bloqueante: se `TenantContext.current()` for `null` (thread sem tenant setado — job assíncrono, health check, warm-up do pool antes de qualquer request), o `SET`/`set_config` grava a string `"null"`, e o `::uuid` da policy (`current_setting('app.tenant_id')::uuid`) falha o cast — a query estoura em erro, não vaza dado (fail-closed), mas o erro que chega ao chamador é um `SQLException` cru do driver, não um erro de aplicação tratado. Vale um `Objects.requireNonNull` explícito no interceptor para trocar isso por uma falha legível.

### 3. Não bloqueante — `OFFSET` profundo em paginação (catálogo R-06, achado pelo `scan.sh`)

`OperadorRepository.java:10`
```java
@Query(value = "SELECT * FROM operador WHERE tenant_id = :tenant ORDER BY id LIMIT 50 OFFSET :offset", nativeQuery = true)
List<Operador> listarPagina(@Param("tenant") java.util.UUID tenant, @Param("offset") int offset);
```
Página funda computa e descarta todas as linhas anteriores ao offset, e a janela se move com inserção concorrente de operador (item repetido ou pulado). Já existe o índice certo para resolver por keyset (`idx_operador_tenant_id_id` em `V001__operador.sql`, sobre `(tenant_id, id)`): trocar por `WHERE tenant_id = :tenant AND id > :ultimoId ORDER BY id LIMIT 50`. Baixo risco hoje (tabela de cadastro, não deve crescer para milhões de linhas por tenant), mas o custo de trocar agora é baixo e evita reabrir a página depois.

### 4. Não bloqueante — `SELECT *` na mesma query (catálogo R-14, achado pelo `scan.sh`)

Mesma linha do item 3. Acopla o código ao schema inteiro (qualquer coluna nova quebra silenciosamente o mapeamento da entidade) e, combinado com o item 6 abaixo, faz o `cpf` sair da query sem que quem lê a query veja explicitamente que está projetando um campo PII. Listar as colunas explicitamente — ao menos nesta query, que já é nativa e teria a projeção "de graça".

### 5. Não bloqueante — isolamento `SERIALIZABLE` sem retry (catálogo R-11, achado por revisão manual — o `scan.sh` não varre isso, é detecção só por leitura)

`OperadorService.java`
```java
/** Move o operador de frota; dois despachantes podem fazer isso ao mesmo tempo. */
@Transactional(isolation = Isolation.SERIALIZABLE)
public void transferirFrota(long operadorId, long novaFrotaId) {
    Operador op = repo.findById(operadorId).orElseThrow();
    op.setFrotaId(novaFrotaId);
    repo.save(op);
}
```
O próprio comentário do método documenta a concorrência que `SERIALIZABLE` existe para proteger — e é exatamente essa concorrência que faz o PostgreSQL abortar uma das duas transações com `40001` quando dois despachantes movem o mesmo operador ao mesmo tempo. Sem retry, esse `40001` sobe como exceção não tratada até o chamador (500 sob carga normal esperada, não uma condição rara). Faltando: captura de `SQLState 40001`/`40P01` com retry com backoff da transação inteira (`@Retryable` do Spring Retry, ou um wrapper manual) — catálogo R-11.

### 6. BLOQUEANTE (governança) — `cpf` sem classificação declarada

`Operador.java:15`
```java
private String cpf;
```
O projeto tem a rule `architecture/pii-pci-classification.md` (opt-in, presente neste repositório) e o schema `data-classification.schema.json`, mas **não existe nenhum arquivo `data-classification.json` no projeto** — nenhum campo está classificado, incluindo `cpf`, que a própria rule cita como exemplo canônico de `pii`. A rule trata campo sensível sem entrada no mapa como *finding* do gate (REQ-12b), não como omissão neutra.
- Rodei `check-data-governance.sh --path services/cadastro-operador`: retornou `FAIL data-governance/universo-vazio` — o verificador automático só lê `.go/.kt/.ts/.rego/.py/.md`, então em projeto Java isso é esperado e **não conta como aprovação**; PAN/PII aqui não foi verificado por ele, fica por conta desta revisão manual.
- Não achei log, trace ou serialização expondo `cpf` neste recorte (não há controller/DTO no material revisado) — então não afirmo vazamento em log hoje, só a ausência de classificação, que é o que a rule exige como pré-condição antes do dado circular.
- **Recomendação:** criar `data-classification.json` na raiz do projeto (ou onde a rule/gate esperar) com pelo menos:
  ```json
  {
    "Operador.cpf": {
      "classification": "pii",
      "masking": "mask_document",
      "tokenization_boundary": false
    }
  }
  ```
  e, quando o controller/DTO que expõe `Operador` for revisado, confirmar que `cpf` é mascarado em qualquer log/trace/decision-log antes de emitir (a rule trata isso como invariante sempre em `enforce`, independente do modo geral do repositório).

## O que não pude verificar neste recorte

- **Papel de aplicação vs. dono da tabela (`NOBYPASSRLS`):** a migration (`V001__operador.sql`) não tem `CREATE ROLE`/`GRANT`, então não dá para confirmar se `cadastro_app` (o usuário do `application.yml`) é diferente do role que roda a migration, nem se tem `BYPASSRLS`. Como a tabela tem `FORCE ROW LEVEL SECURITY`, mesmo que `cadastro_app` seja o dono, a RLS se aplica a ele (FORCE cobre o dono) — mas a separação de papéis, se existir, provavelmente vive em infra/Terraform fora deste recorte. Vale confirmar antes do PR, não bloqueante para esta revisão porque está fora do material que recebi.
- Configuração do Hikari (`maximum-pool-size: 20`, sem `minimum-idle`/`leak-detection-threshold` explícitos) — não é falha, só fora do escopo pedido (acesso a dados/CPF).

## Antipatterns citados (catálogo `data-relational-practices/references/antipatterns.md`)

| id | achado por | arquivo:linha |
|---|---|---|
| R-12 | `scan.sh` + leitura | `TenantConnectionInterceptor.java:20` |
| R-06 | `scan.sh` + leitura | `OperadorRepository.java:10` |
| R-14 | `scan.sh` + leitura | `OperadorRepository.java:10` |
| R-11 | revisão manual (não coberto por `scan.sh`) | `OperadorService.java` (método `transferirFrota`) |

## Evidência

- `scan.sh --root services/cadastro-operador`: 7 arquivos varridos, achados R-06/R-12/R-14 acima (saída completa em `outputs/scan-output.txt`).
- `check-data-governance.sh --path services/cadastro-operador`: `FAIL data-governance/universo-vazio` — não verificado automaticamente (projeto Java), não conta como aprovação (saída completa em `outputs/check-data-governance-output.txt`).
- HikariCP (context7, `/brettwooldridge/hikaricp`, *Pool Analysis*): confirma que `rollback()`/reset ao devolver conexão ao pool cobre auto-commit/isolation/catalog/read-only, não GUCs de aplicação — base do achado do item 1. Marca de evidência: [1F] (documentação oficial do produto).
- Demais recomendações (R-06, R-11, R-12, R-14) citam a marca de evidência já registrada no catálogo da skill (`antipatterns.md`): R-06 [2F], R-11 [J]/[1F], R-12 [J]/[1F]/[Interp.] quanto ao vazamento por pool, R-14 [1F].

## Próximo passo

Corrigir os itens 1/2 (mesmo fix) e 6 antes do PR — são os dois que tocam isolamento multi-tenant e dado pessoal, as duas categorias que `conflict-handling.md` trata como decisão estrutural durável. Os itens 3, 4 e 5 podem ir no mesmo PR ou num seguinte, a seu critério — não bloqueiam.
