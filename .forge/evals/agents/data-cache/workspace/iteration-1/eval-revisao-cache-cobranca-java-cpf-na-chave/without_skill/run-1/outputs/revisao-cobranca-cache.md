# Revisão — CobrancaCache (services/cobranca)

Escopo: `services/cobranca/src/main/java/br/com/exemplo/cobranca/CobrancaCache.java`, à luz do contexto em `docs/servicos/cobranca.md` (Java 21 / Spring Boot 3, multi-tenant, PostgreSQL como fonte da verdade, Redis + Caffeine como cache de leitura, 12 réplicas em Kubernetes). Revisão somente leitura — nenhum arquivo foi alterado.

## Achados críticos (LGPD)

1. **CPF em texto claro na chave do cache, não só no valor.** A chave `"tenant:" + tenant + ":titular:" + cpf` grava o CPF diretamente no *keyspace* do Redis. Diferente do valor (que ao menos passa por `toJson()`), a chave fica visível em qualquer superfície que liste ou inspecione chaves — `redis-cli KEYS/SCAN`, ferramentas de monitoramento/APM que logam comandos, dumps RDB/AOF, réplicas e backups. Isso é dado pessoal (CPF é identificador direto sob a LGPD) exposto fora do controle normal de acesso à aplicação, inclusive para quem só tem acesso operacional à infraestrutura de cache, não ao banco. Recomendação: derivar a chave de um hash (SHA-256, por exemplo) do CPF, nunca do CPF em claro — mantém unicidade e lookup determinístico sem propagar o dado sensível para o keyspace.

2. **Sem TTL/expiração — nem no Redis, nem no Caffeine.** `redis.opsForValue().set(chave, ...)` é gravado sem expiração, e o `Caffeine.newBuilder()` só define `maximumSize(50_000)`, sem `expireAfterWrite`/`expireAfterAccess`. Isso fere o princípio de necessidade/minimização (LGPD art. 6º, III e IX): dado pessoal replicado num cache deveria ter vida útil limitada e alinhada ao propósito (leitura de cadastro), não persistir indefinidamente.

3. **Nenhum caminho de invalidação/exclusão.** A classe não tem método para remover ou invalidar uma entrada (nem em Redis, nem em Caffeine). Se o titular exercer direito de exclusão/anonimização (LGPD art. 18) e o registro for apagado no Postgres (fonte da verdade), a cópia em cache — sem TTL e sem invalidação explícita — pode continuar sendo servida indefinidamente. Isso é ao mesmo tempo uma falha de conformidade e uma fonte de inconsistência (ver abaixo).

## Achado de consistência (arquitetura multi-réplica)

4. **Cache local (Caffeine) desincronizado entre as 12 réplicas.** Caffeine é in-memory por processo. Quando uma réplica executa `guardarTitular`, ela atualiza o Redis (compartilhado) e o próprio `Caffeine` local — mas as outras 11 réplicas não são notificadas. Combinado com a ausência de TTL (achado 2), o resultado é que uma escrita em uma réplica pode ficar invisível para as demais por tempo indefinido (só sai por pressão de `maximumSize`), gerando leituras divergentes do mesmo titular dependendo de qual pod atende a requisição. Isso é agravado se o dado também puder ser atualizado por outro caminho que não passe por `guardarTitular` (ex.: escrita direta no Postgres) — nesse caso nenhuma réplica é invalidada. Recomendação: TTL curto no Caffeine como rede de segurança mínima, e — se a consistência entre réplicas for requisito — invalidação via pub/sub do Redis (`Redis Keyspace Notifications` ou canal dedicado) para propagar invalidação do cache local em todas as réplicas.

## Observações secundárias

5. **`Titular.toJson()`/`fromJson()` não estão no arquivo revisado** — não foi possível confirmar se o payload é armazenado em claro no Redis ou se há algum mascaramento/criptografia de campos sensíveis (nome, CPF, endereço, dados de pagamento). Se o Redis persiste em disco (RDB/AOF) sem criptografia at-rest, isso amplia o achado 1: não seria só a chave, mas o valor inteiro contendo dado pessoal sem proteção adicional além do controle de acesso de rede. Recomendo confirmar criptografia at-rest no Redis gerenciado e considerar cifrar campos sensíveis no payload antes de serializar.

6. **Ausência de tratamento de erro/observabilidade no caminho de leitura do Redis** — `lerTitular` não trata falha de conexão com Redis (deixaria propagar exceção do client), o que é aceitável para MVP, mas vale registrar como ponto de atenção operacional antes de subir para 12 réplicas em produção (timeout/circuit breaker no client Redis).

## Resumo — pode subir?

Não recomendo subir como está. Os achados 1–3 são bloqueantes sob a ótica de LGPD (dado pessoal identificador em claro no keyspace, sem TTL, sem via de exclusão), e o achado 4 é um bug de consistência real dado o desenho de 12 réplicas com cache local não sincronizado. Nenhum exige rearquitetura: hash da chave, TTL nos dois níveis de cache, e um método de invalidação (mesmo que só local antes de evoluir para pub/sub) resolvem os pontos 1–4 com mudança pequena e localizada nesta classe.
