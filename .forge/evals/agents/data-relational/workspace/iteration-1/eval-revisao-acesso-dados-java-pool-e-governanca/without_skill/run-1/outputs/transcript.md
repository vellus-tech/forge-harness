# Transcript — eval-revisao-acesso-dados-java-pool-e-governanca / without_skill / run-1

Condição: `without_skill` — nenhuma leitura de `.forge/skills`, `.forge/agents` do template nem do `plugin`/`.forge/evals` do harness; revisão feita só com conhecimento próprio sobre Spring Boot/HikariCP/PostgreSQL RLS e leitura do próprio projeto-fixture (`work/`).

## Passos

1. `date +%s > .t0` — instante inicial gravado.
2. `mkdir -p work` e `bash .../fixtures/revisao-acesso-dados-java-pool-e-governanca/setup.sh work` — materializa o projeto fixture dentro de `run-1/work`.
3. `find work/services -type f` — mapeei o serviço `cadastro-operador`: `TenantConnectionInterceptor.java`, `TenantContext.java`, `Operador.java`, `OperadorRepository.java`, `OperadorService.java`, `application.yml`, `V001__operador.sql`.
4. Li os cinco arquivos Java + `application.yml` + a migration SQL na íntegra (`cat` de cada um).
5. Como a tarefa pede para confirmar aderência à "governança de dados", chequei se o projeto-fixture declara alguma governança própria: li `work/AGENTS.md`, `work/.forge/constitution.md`, `work/.forge/context.md`.
6. `grep` por `cpf|pii|lgpd|dado pessoal|governan` dentro de `work/` para achar as rules relevantes sem ler o repositório inteiro. Encontrei e li:
   - `.forge/rules/architecture/pii-pci-classification.md` (classificação de campos PII, mascaramento, gate `check-data-governance`).
   - `.forge/rules/data/data-governance.md` (matriz de isolamento multi-tenant por store — RLS obrigatória p/ Postgres).
   - `.forge/rules/data/data-config-sql.md` (regra específica de Postgres: RLS + EF Global Query Filter, RLS só dispensável por exceção formal).
   - `.forge/rules/domain/audit-immutability.md` (não se aplica diretamente a `operador`, que não é tabela de auditoria/ledger — descartado do escopo).
   - `.forge/rules/conventions/database-naming.md` (convenção `snake_case`/`tenant_id` — a migration está aderente).
7. Busquei uma instância de `data-classification.schema.json` preenchida no projeto (`find -iname "*classification*"`) — só existe o schema-template em `.forge/schemas/`, nenhuma instância classificando `cpf`. Esse é o achado de governança central.
8. Tentei rodar o gate determinístico do próprio repositório para checar o CPF/tenant de forma objetiva: `bash .forge/scripts/check-data-governance.sh --path services/cadastro-operador`. Resultado: `FAIL data-governance/universo-vazio` (o gate não reconheceu um path de serviço solto como alvo, parece esperar um `change-id` de spec ativa). Não usei isso como veredito — registrei como "não verificado", não como aprovação nem reprovação.
9. Analisei os três arquivos-alvo com atenção a três eixos: (a) correção do mecanismo de tenant/RLS, (b) HikariCP/pool, (c) tratamento do CPF.
   - `TenantConnectionInterceptor.getConnection()` monta `SET app.tenant_id = '...'` por concatenação de string em vez de `set_config` parametrizado — flag crítico, apesar de o tipo hoje ser `UUID` (baixo risco de injeção clássica agora, mas padrão perigoso).
   - `TenantContext` é um `ThreadLocal<UUID>` com `set`/`current` mas sem `remove()`/`clear()` em lugar nenhum do código revisado — risco de vazamento cross-tenant por reuso de thread em pool de servlet, se o filtro que popula o contexto (fora do escopo dos 3 arquivos) não limpar em `finally`.
   - `DelegatingDataSource` tem duas sobrecargas de `getConnection()`; só a sem-argumentos foi interceptada — a outra pula o `SET` do tenant.
   - Conflito entre `.forge/context.md` ("tenant_id column, not RLS") e as rules de dados (RLS obrigatória para Postgres) — o código implementado (RLS na migration) segue a rule, não o context.md; sinalizei como conflito não resolvido que a constitution do próprio projeto (item 12) manda escalar para humano, não decidir sozinho.
   - CPF: sem entrada de classificação (`pii`/`masking`) em nenhum arquivo do repo — achado bloqueante pela própria rule `pii-pci-classification.md`. Não encontrei log do CPF nos três arquivos revisados, mas não pude descartar exposição em outras partes do serviço (fora do escopo desta revisão).
   - `OperadorService.transferirFrota` usa `Isolation.SERIALIZABLE` sem retry, apesar do comentário do método já admitir concorrência real — falha de conflito de serialização vira erro não tratado.
   - `application.yml`: `hikari.maximum-pool-size: 20` sem `connection-timeout`/`leak-detection-threshold` — não bloqueante, mas vale ajuste.
10. Escrevi o veredito consolidado em `outputs/revisao-cadastro-operador.md`, com uma lista final do que precisa ser resolvido antes de dizer "pode seguir com o PR" — a resposta ao usuário é **não** dar sinal verde ainda, por dois bugs de correção no isolamento de tenant e uma lacuna bloqueante de governança sobre o CPF.
11. Registrei `.t0`/`timing.json` conforme instruído pelo runner do eval.

## Decisões e por que

- Não assumi que "está tudo certo" só porque a migration implementa RLS corretamente — a pergunta do usuário pedia para confirmar CPF *e* o acesso a dados como um todo; a rule do próprio repo trata ausência de classificação como finding, não como omissão neutra, então não dava para responder "pode seguir" sem violar a rule que o próprio projeto define.
- Tratei o conflito `context.md` vs. `data-governance.md`/`data-config-sql.md` como algo a **reportar**, não a resolver por conta própria — a constitution do projeto (item 12) é explícita sobre isso.
- Não rodei testes, build Java/Maven nem qualquer comando de escrita (git, npm, docker, gh) — fora do mandato desta run. O gate `check-data-governance.sh` foi a única execução de script, é leitura/verificação, não escrita, e o resultado (universo vazio) foi reportado como "não verificado", não usado para inflar confiança.
