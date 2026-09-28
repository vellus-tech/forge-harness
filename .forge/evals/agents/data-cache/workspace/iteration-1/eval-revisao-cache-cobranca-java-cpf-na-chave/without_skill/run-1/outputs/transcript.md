# Transcript — eval-revisao-cache-cobranca-java-cpf-na-chave / without_skill / run-1

1. Recebi a tarefa: revisar `services/cobranca` (Java/Spring, 12 réplicas, contexto em `docs/servicos/cobranca.md`) em busca de problema de LGPD ou de consistência no `CobrancaCache`, antes de subir. Só recomendação, sem alterar arquivo.
2. Preparei o workspace com a fixture: `bash fixtures/revisao-cache-cobranca-java-cpf-na-chave/setup.sh <dir>/work` (sem ler `.forge/skills`, `.forge/agents`, `plugin` nem `.forge/evals` — baseline sem o artefato do skill-creator/agentes, conforme instrução do caso `without_skill`).
3. Levantei os dois arquivos relevantes indicados no contexto:
   - `docs/servicos/cobranca.md` — confirma stack (Java 21, Spring Boot 3), multi-tenant, PostgreSQL como fonte da verdade, Redis e Caffeine como cache de leitura, 12 réplicas em Kubernetes.
   - `services/cobranca/src/main/java/br/com/exemplo/cobranca/CobrancaCache.java` — única classe do serviço no fixture; contém `guardarTitular` e `lerTitular`.
4. Li o código linha a linha e apliquei conhecimento próprio de LGPD (minimização de dados, necessidade, direito de exclusão) e de arquitetura de cache distribuído (cache local por processo vs. cache compartilhado, invalidação, TTL) — sem consultar nenhum artefato do harness.
5. Identifiquei quatro achados:
   - CPF em claro compõe a chave do Redis, não só o valor — exposição de dado pessoal no keyspace/backup/monitoramento (LGPD).
   - Nenhum TTL/expiração em Redis nem em Caffeine — retenção indefinida (LGPD, princípio da necessidade).
   - Nenhum método de invalidação/remoção — sem via para atender exclusão/anonimização do titular, e é também a causa raiz do problema de consistência.
   - Cache Caffeine é local por réplica; com 12 réplicas e sem invalidação cross-instância, uma escrita numa réplica não se propaga para as outras — leituras divergentes do mesmo titular dependendo do pod.
6. Registrei duas observações secundárias não bloqueantes: falta de visibilidade sobre `Titular.toJson()/fromJson()` (possível dado sensível sem cifra adicional no valor) e ausência de tratamento de erro/timeout no caminho de leitura do Redis.
7. Conclusão entregue: não recomendo subir como está; achados 1–3 são bloqueantes por LGPD, achado 4 é bug de consistência real dado o desenho de 12 réplicas; correção é localizada (hash da chave, TTL nos dois níveis, método de invalidação), sem exigir rearquitetura.
8. Escrevi o entregável em `outputs/revisao-cobranca-cache.md` e este transcript. Nenhum arquivo do projeto `work/` foi alterado (revisão somente leitura, conforme pedido). Nenhum comando de escrita externa (git commit/push, tests, docker, ledger/liaison, gh, npm publish) foi executado — não havia necessidade para esta tarefa de revisão.
