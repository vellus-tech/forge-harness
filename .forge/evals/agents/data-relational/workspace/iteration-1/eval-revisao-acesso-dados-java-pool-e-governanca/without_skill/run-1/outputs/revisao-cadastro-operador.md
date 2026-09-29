# Revisão — acesso a dados de `services/cadastro-operador`

Veredito: **não seguir com o PR ainda**. Há um bug de correção (não é só estilo) na forma como o tenant é aplicado à conexão, um risco real de vazamento cross-tenant por `ThreadLocal` sem limpeza, e uma lacuna de governança sobre o CPF que a rule do próprio repositório marca como bloqueante.

## 1. `TenantConnectionInterceptor` — SET por concatenação de string (crítico)

```java
st.execute("SET app.tenant_id = '" + TenantContext.current() + "'");
```

Construir SQL por concatenação é proibido independentemente de `TenantContext.current()` ser hoje um `UUID` (o `toString()` de um UUID não contém aspas, então não há injeção clássica *hoje*, mas o padrão em si é frágil e é exatamente o tipo de código que vira injeção real na primeira refatoração que troque o tipo do tenant ou adicione um campo derivado do usuário). Trocar por `set_config` parametrizado:

```java
try (PreparedStatement ps = conn.prepareStatement("SELECT set_config('app.tenant_id', ?, false)")) {
    ps.setString(1, TenantContext.current().toString());
    ps.execute();
}
```

Além disso, se `TenantContext.current()` for `null` (contexto nunca setado antes da chamada), a concatenação produz `SET app.tenant_id = 'null'`. Isso só falha mais tarde, no cast `::uuid` da policy — fail-closed por acidente, não por desenho. Prefira falhar explicitamente (`Objects.requireNonNull`) antes de tocar na conexão, para que o erro aponte para a causa real (contexto de tenant não propagado) em vez de um erro de cast genérico do Postgres.

## 2. `TenantContext` — `ThreadLocal` sem `remove()`/limpeza (crítico)

```java
private static final ThreadLocal<UUID> ATUAL = new ThreadLocal<>();
public static void set(UUID tenant) { ATUAL.set(tenant); }
public static UUID current() { return ATUAL.get(); }
```

Não existe `clear()`/`remove()`. Em um servidor com pool de threads (Tomcat embutido do Spring Boot), a mesma thread atende requisições de tenants diferentes ao longo do tempo. Se o filtro/interceptor que chama `TenantContext.set(...)` no início da requisição (não está nos três arquivos revisados — precisa ser localizado e conferido) não limpar o valor num `finally` ao fim da requisição, uma falha de path (exceção antes do `set()` da próxima requisição, endpoint que esquece de setar o tenant, etc.) deixa a thread servindo a próxima requisição com o tenant anterior. Combinado com `FORCE ROW LEVEL SECURITY`, isso não é "sem isolamento" — é isolamento silenciosamente errado: a query roda, a RLS aplica, só que para o tenant errado. É o pior cenário de vazamento cross-tenant porque não há erro, não há log, e passa em qualquer teste que não force reuso de thread entre tenants.

Ação: localizar o filtro que popula `TenantContext` e confirmar `try { ... } finally { TenantContext.clear(); }`. Se esse filtro não existir ou não limpar, é bloqueante para o PR.

## 3. `DelegatingDataSource` — só um dos dois `getConnection()` é interceptado

`TenantConnectionInterceptor` sobrescreve `getConnection()` mas não `getConnection(String username, String password)`, herdado de `DelegatingDataSource`. Se algum caminho (ferramenta administrativa, Flyway, biblioteca de terceiros) usar a variante com credenciais, o `SET app.tenant_id` não roda. Com `FORCE ROW LEVEL SECURITY` e a policy usando `current_setting('app.tenant_id')` sem `missing_ok`, isso tende a falhar com erro de cast em vez de vazar dados — mas vale confirmar que nada no classpath chama essa sobrecarga, e por clareza/defesa em profundidade eu sobrescreveria as duas.

## 4. Isolamento multi-tenant — conflito de convenção não resolvido (reportar, não decidir sozinho)

`.forge/context.md` (defaults do time) diz: *"Multi-tenant isolation via `tenant_id` column (not schema, not RLS)"*. Já `.forge/rules/data/data-governance.md` e `.forge/rules/data/data-config-sql.md` (regra específica de PostgreSQL) exigem RLS obrigatória para tabela de domínio multi-tenant, com dispensa só por exceção formal documentada, e citam "EF Global Query Filter" como camada de aplicação — linguagem pensada para o stack .NET do time, que não tem equivalente aplicado aqui (Spring/Hibernate não tem um filtro global de tenant configurado; o único filtro de aplicação existe pontualmente em `listarPagina`, que já adiciona `WHERE tenant_id = :tenant` na query nativa — boa prática de defesa em profundidade, mas não é sistemático: `OperadorRepository.findById`/`save`, usados em `OperadorService.transferirFrota`, não filtram por tenant na aplicação e dependem 100% da RLS do banco).

A migração (`V001__operador.sql`) implementa RLS corretamente (`ENABLE` + `FORCE` + policy por `tenant_id`), então o código está alinhado com a rule de dados, não com o texto do `context.md`. Pela ordem de precedência da constitution do projeto (constitution > baseline > rules > context/defaults), a rule vence e a RLS implementada está certa — mas a própria constitution (item 12) trata esse tipo de divergência de fonte como **conflito bloqueante que para e escala para humano**, não algo que o agente resolve sozinho silenciosamente. Sinalizando aqui para decisão explícita: ou `context.md` está desatualizado e deve ser corrigido para refletir que Postgres usa RLS, ou há uma exceção formal faltando.

## 5. CPF — lacuna de governança (bloqueante pela própria rule do repositório)

`.forge/rules/architecture/pii-pci-classification.md` exige que todo campo PII tenha entrada em `data-classification.schema.json` com `classification: pii` e uma estratégia de `masking` declarada, e trata a ausência dessa entrada como **finding**, não como omissão neutra. No repositório só existe o schema-template (`.forge/schemas/data-classification.schema.json`); não há nenhum arquivo de instância (`data-classification.json` ou similar) classificando `Operador.cpf`. Tentei rodar o gate do próprio projeto (`bash .forge/scripts/check-data-governance.sh --path services/cadastro-operador`) e ele retornou `FAIL data-governance/universo-vazio` — o gate não teve um alvo reconhecível para examinar naquele path (provavelmente espera um `change-id` de spec, não um path de serviço arbitrário); não tirei conclusão de aprovação a partir disso, é um "não verificado", não um "verde".

Pontos concretos sobre o CPF nos três arquivos revisados:
- `Operador.cpf` é `String` mapeado para `text` sem `@Column` com tamanho/formato, sem máscara em nenhum ponto do código de acesso a dados revisado (não há log do objeto `Operador` nos três arquivos — não posso afirmar que vaza em log, só que não há tratamento declarado).
- Não há coluna/estratégia de tokenização ou hashing — CPF é armazenado em texto puro, o que pode ser aceitável a depender da classificação escolhida (`pii` com `masking` só na borda de exibição/log, não necessariamente no armazenamento), mas isso precisa estar **declarado**, não implícito.
- Nível de banco: não há `UNIQUE` em `(tenant_id, cpf)` na migration — não é um problema de segurança, mas é uma lacuna de integridade que vale mencionar já que se está revisando a tabela.

Antes do PR: adicionar a entrada do campo `cpf` (e revisar os demais campos de `Operador`) no mapa de classificação, com a estratégia de mascaramento definida, e confirmar que nenhum logger/serializer expõe o CPF bruto em log/trace — isso não foi possível confirmar só com os três arquivos indicados; recomendo grep por `log.*operador`/`toString` em todo o `cadastro-operador` antes de fechar o PR.

## 6. HikariCP — configuração mínima, sem tuning explícito

```yaml
hikari:
  maximum-pool-size: 20
```

Sem `connection-timeout`, `minimum-idle`, nem `leak-detection-threshold`. Não é bloqueante — o padrão do HikariCP é razoável — mas dado que o isolamento de tenant depende de rodar `SET`/`set_config` a cada checkout de conexão, uma conexão vazada (nunca devolvida ao pool) não causa vazamento cross-tenant (ela é resetada no próximo checkout de qualquer forma), mas esgota o pool silenciosamente. Vale habilitar `leak-detection-threshold` para detectar isso cedo, e dimensionar `maximum-pool-size` em função do `max_connections` do Postgres compartilhado entre as réplicas do serviço (não visível nos arquivos revisados).

## 7. `OperadorService.transferirFrota` — `SERIALIZABLE` sem retry

O próprio comentário do método admite concorrência ("dois despachantes podem fazer isso ao mesmo tempo"). `@Transactional(isolation = Isolation.SERIALIZABLE)` é a escolha certa para essa garantia, mas sob conflito o Postgres aborta uma das transações (`could not serialize access`) e isso não é tratado — nenhum `@Retryable`/retry manual em volta da chamada. Na prática, um dos dois despachantes recebe um erro 500 em vez de a operação simplesmente re-tentar. Se o requisito é "não perder a atualização", falta um retry; se `SERIALIZABLE` for overkill para um update de uma linha, uma alternativa mais barata é lock otimista (`@Version` na entidade) ou `SELECT ... FOR UPDATE`.

## Resumo do que falta antes de "pode seguir com o PR"

1. Trocar o `SET` concatenado por `set_config` parametrizado (crítico).
2. Confirmar que o filtro que popula `TenantContext` limpa o `ThreadLocal` em `finally`; se não existir/não limpar, corrigir (crítico — risco de vazamento cross-tenant).
3. Decidir e registrar (ADR ou exceção formal) a divergência entre `context.md` ("not RLS") e a rule de dados (RLS obrigatória) — não decidir silenciosamente.
4. Declarar `cpf` (e os demais campos de `Operador`) em um mapa de classificação de dados com estratégia de mascaramento, e confirmar que não há log do CPF em texto puro em nenhum ponto do serviço.
5. (Não bloqueante) Tuning do HikariCP e retry em `transferirFrota`.

Sem os itens 1, 2 e 4 resolvidos eu não daria sinal verde para o PR — os itens 1 e 2 são bugs de correção sobre isolamento multi-tenant, e o item 4 é uma exigência explícita e bloqueante da própria rule de governança do repositório.
