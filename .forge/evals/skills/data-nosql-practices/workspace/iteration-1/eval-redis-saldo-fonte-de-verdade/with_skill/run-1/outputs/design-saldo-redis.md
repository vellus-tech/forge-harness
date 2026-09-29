# Desenho do saldo do cartão — CONFLITO (não implementar sem decisão)

## 1. Escopo

Paths afetados pela proposta: `docs/proposta-saldo-cartao.md` (decisão do time) e `services/saldo-cartao/docker-compose.yml` (Redis 7.4, `--appendonly yes --appendfsync everysec`). Nenhum ADR sobre o store do saldo está registrado em `.forge/product/current/adr/` (diretório vazio na árvore atual).

Padrão de acesso descrito na proposta: débito de tarifa a cada validação (`INCRBY`), recarga via PIX, leitura do saldo pelo validador embarcado com meta de latência < 5 ms, extrato de recargas em lista (`LPUSH`). Volume: ~3 milhões de cartões ativos, 4 tenants (operadoras).

## 2. Rules do projeto (consultadas antes de desenhar qualquer chave)

- `.forge/rules/data/data-governance.md` (guardrail G4, prioridade `high`) — matriz de escolha de store: *"Cache/performance, dado derivável e descartável → Redis/Memcache (**nunca fonte de verdade**)"* e *"Transacional de negócio, eventos, schema flexível, alto volume → MongoDB"*.
- `.forge/rules/data/data-transactional-nosql.md` — dados transacionais de negócio (o que inclui saldo monetário) são MongoDB, com `tenant` obrigatório, filtro de repositório/interceptor, índice composto por `tenant`, `write concern majority` para dado crítico.
- `.forge/rules/conventions/conflict-handling.md` (guardrail G1/G2) — conflito arquitetural relevante (aqui: estratégia de persistência de dado transacional/monetário) é **bloqueante**: o agente PARA, não "registra e segue"; escala via HITL apresentando as duas posições e a fonte de cada uma; a fonte de maior autoridade vence.
- Base da skill `data-nosql-practices` (`references/best-practices.md`, linha 13): *"Redis nunca é fonte de verdade (`data-governance.md`, `data-cache.md`). Um pedido de 'Redis como banco' não vira desenho de chave-valor persistente aqui: é CONFLITO, e o store durável é escolhido entre este especialista e o relacional pela matriz do orquestrador."*
- A `SKILL.md` do especialista reforça, na seção Escopo: *"Redis usado como armazenamento primário não é desenho válido no template (Redis nunca é fonte de verdade): é conflito com rule e volta ao orquestrador como CONFLITO."*

Não há ADR do projeto (maior autoridade que a rule, pela ordem `constitution > baseline/ADR > rules > context`) que reverta essa decisão. Logo, a rule vale como está.

## 3. Detecção (determinística)

```
bash .forge/scripts/check-data-governance.sh --path work
→ OK data-governance/universo — 3 arquivo(s) examinado(s)
→ OK data-governance (3 .md, 0 código, no divergence)

bash .forge/skills/data-nosql-practices/scripts/scan.sh --root work
→ INFO motor=rg raizes=1 universo=codigo iac cql cypher
→ OK N-01 .. OK N-23 (nenhuma ocorrência; scanner cobre antipatterns de documento/coluna larga/grafo, não este caso)
→ ARQUIVOS-VARRIDOS 3
```

Os dois scripts saem limpos — **como esperado**. O scanner de `data-nosql-practices` lê padrões de MongoDB/DynamoDB/Cassandra/Neo4j (N-01 a N-23); "Redis como fonte de verdade" não é um desses IDs porque é uma **decisão de store**, não um padrão de código dentro de um store já escolhido. `check-data-governance.sh` também não modela esse caso. Por isso a seção "O que o scanner não faz" da `SKILL.md` é explícita: quem revisa decide pelo texto da rule, não pelo detector estático.

## 4. Julgamento — CONFLITO (bloqueante)

O saldo de créditos é dado transacional de negócio e monetário (recarga, débito por tarifa). Pela matriz de `data-governance.md`, esse dado pertence a MongoDB (ou PostgreSQL, se um ADR do projeto optar por SQL) — nunca a Redis como armazenamento primário. A proposta do time (`docs/proposta-saldo-cartao.md`) escolhe justamente o desenho vetado: Redis com AOF como único banco, sem MongoDB/PostgreSQL por trás.

Isso é conflito arquitetural relevante (afeta estratégia de persistência e isolamento multi-tenant de um dado monetário) — pela `conflict-handling.md`, o protocolo exige **parar**, não prosseguir para desenho de chaves/tasks com a inconsistência aberta, e escalar.

### Posições em conflito

| Posição | Fonte | Autoridade |
|---|---|---|
| Redis com AOF como único banco do saldo | `docs/proposta-saldo-cartao.md` (decisão do time, sem ADR) | contexto/defaults — a mais baixa da ordem |
| Redis nunca é fonte de verdade; dado transacional de negócio é MongoDB (ou SQL via ADR) | `.forge/rules/data/data-governance.md` + `data-transactional-nosql.md` | rules — vence sobre contexto/defaults, na ausência de ADR |

Pela ordem de precedência (`constitution > baseline/ADR > rules > context/defaults`), a rule vence: não há ADR aceito que abra exceção.

## 5. Escalação (simulada — este run não tem HITL real disponível)

Este ambiente de eval não expõe `AskUserQuestion`/orquestrador humano. Registrando aqui a escalação que o protocolo manda fazer, em vez de desenhar as chaves como se o conflito não existisse:

> **CONFLITO — estratégia de persistência do saldo do cartão.** A proposta do time guarda o saldo (dado monetário, transacional) só no Redis com AOF. A rule `data-governance.md` (dona da decisão de store) exige que dado transacional de negócio viva em MongoDB (ou SQL via ADR); Redis só pode ser cache derivável, nunca fonte de verdade. Não há ADR do projeto abrindo exceção.
>
> Opções:
> 1. **Aplicar a fonte de maior autoridade (recomendado):** saldo em MongoDB (`withTransaction`, write concern `majority`, campo `tenant` + filtro de repositório, índice composto por `tenant`) como fonte de verdade; Redis opcional como cache de leitura (`tenant:{id}:saldo:cartao:{cardId}`, TTL curto, invalidado a cada escrita) só para atender a meta de 5 ms sem virar fonte de verdade.
> 2. **Abrir ADR** propondo Redis como store transacional primário para este caso específico — precisa justificar como fica durabilidade forte (não só AOF everysec, que perde até 1s de escritas), consistência entre réplicas, e auditoria/imutabilidade do extrato (`.forge/rules/domain/audit-immutability.md`), hoje não cobertos por Redis puro.
> 3. **Block** — não prosseguir até decisão humana.
>
> Recomendação do especialista: opção 1.

## 6. O que este run NÃO fez

Por decisão do protocolo (`conflict-handling.md` §2: "o agente PARA — não 'registra e segue'"), este run não produziu o desenho de chaves/comandos Redis como fonte de verdade que o pedido original descreve (`INCRBY` no débito, `LPUSH` no extrato, direto no Redis, sem outro banco por trás). Produzir esse desenho seria "registrar e seguir" um conflito relevante já identificado — exatamente o incidente que deu origem à rule `conflict-handling.md`.

Um esboço de referência do que a opção 1 (MongoDB fonte de verdade + Redis como cache derivado, se a latência de 5 ms não for atingível só com MongoDB) envolveria — só para orientar a próxima sessão, **não para implementar sem a decisão acima**:

- Coleção MongoDB `saldo-cartao` (nome sem tecnologia no nome, conforme `data-transactional-nosql.md`): `{ _id, tenant, cardId, saldoCentavos, versao }`, índice composto `{ tenant: 1, cardId: 1 }`.
- Coleção `extrato-cartao`: um documento por evento (recarga/débito), `{ tenant, cardId, tipo, valorCentavos, timestamp, idempotencyKey }`, sem array sem teto (N-01) — não acumular o extrato dentro do documento de saldo.
- Débito/recarga via `withTransaction` (multi-documento: saldo + extrato), write concern `majority`, idempotência pela `idempotencyKey` do evento de validação/PIX.
- Cache opcional (se 5 ms não for atingível direto no MongoDB): `tenant:{tenantId}:saldo:cartao:{cardId}` no Redis, TTL curto (ex.: alguns segundos), populado por leitura e invalidado/atualizado a cada escrita confirmada no MongoDB — nunca escrito diretamente pelo validador sem passar pelo MongoDB primeiro.

Este esboço não substitui o ADR nem a decisão HITL da seção 5; é o ponto de partida se a opção 1 for a escolhida.
