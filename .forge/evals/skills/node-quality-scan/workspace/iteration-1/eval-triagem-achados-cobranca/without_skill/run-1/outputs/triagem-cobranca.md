# Triagem dos achados do scan — servico-cobranca

Revisei o código apontado pelos cinco achados do scan de qualidade. Nenhum arquivo foi alterado — esta é só a triagem, achado a achado, com o veredito e o porquê. Resumo: quatro dos cinco achados são falsos positivos ou padrões intencionais e podem ficar como estão; um é um defeito real de segurança (injeção de SQL) e precisa ser corrigido antes do release de sexta.

## 1. Pool do `pg` (`src/db/bootstrap.ts`) — deixar como está

O pool é criado uma única vez, num módulo dedicado (`bootstrap.ts`), e importado como singleton por `boot.ts`, que o injeta em `PgCobrancaRepository`. Não há criação de pool por requisição nem vazamento de conexões. É o padrão correto para o driver `pg`. O scanner provavelmente sinaliza qualquer ocorrência de `new Pool(...)` sem verificar se é singleton — aqui é. Sugestão não bloqueante para depois do release: explicitar `idleTimeoutMillis` e `connectionTimeoutMillis` no construtor, hoje implícitos nos defaults da lib.

## 2. `readFileSync` (`src/boot.ts`) — deixar como está

A leitura síncrona do certificado TLS acontece uma única vez, no bootstrap do processo, antes de `app.listen`, fora de qualquer caminho de requisição. Não bloqueia requisições em produção — bloqueia só a inicialização, que já é sequencial por natureza (o servidor não pode aceitar conexões antes de ter o certificado carregado). Trocar por `readFile` assíncrono aqui não traria ganho real e adicionaria complexidade (mais um `await` de top-level). O comentário no código já deixa essa intenção explícita.

## 3. Interface com uma implementação só (`CobrancaRepository`) — deixar como está

`CobrancaRepository` tem duas implementações, não uma: `PgCobrancaRepository` (`src/infra/`), usada em produção, e `repoEmMemoria` (`test/fakes.ts`), usada nos testes como fake em memória. O comentário no próprio arquivo do domínio já documenta a intenção: "o domínio declara, a infraestrutura implementa; nos testes, o domínio recebe um fake em memória". É o padrão ports-and-adapters (hexagonal) aplicado deliberadamente para testabilidade — não é abstração prematura. O scanner provavelmente só contou implementações dentro de `src/` e não enxergou `test/fakes.ts`.

## 4. `.then`/`.catch` em vez de `async`/`await` (`src/jobs/lembrete.ts`) — deixar como está, com ressalva de estilo

`agendarLembrete` é uma função fire-and-forget por desenho: não é `async`, não retorna uma Promise para quem chama, e existe justamente para disparar um lembrete sem bloquear o chamador. O `.catch` está presente e trata o erro (loga a falha), então não há risco de unhandled rejection — o achado não aponta um defeito funcional. É só uma escolha de estilo diferente de `async/await` (que exigiria um wrapper `async` interno ou uma IIFE, já que a função em si não pode ser `async` se não deve retornar Promise). Dá para padronizar para `async/await` por consistência de estilo do time, mas isso é preferência de código, não correção obrigatória antes do release.

## 5. A query (`src/infra/PgCobrancaRepository.ts`, método `marcarPaga`) — CORRIGIR ANTES DO RELEASE

```ts
await this.pool.query(`UPDATE cobrancas SET status = 'paga', pago_em = now() WHERE id = '${id}'`);
```

Este é o único achado que é um defeito real, e é grave: o `id` é interpolado diretamente na string SQL, sem parametrização — injeção de SQL clássica. O método `buscar`, na mesma classe, faz a coisa certa (`WHERE id = $1` com `[id]` como parâmetro), o que torna a inconsistência ainda mais visível. O `id` chega de `req.params.id` em `rotas.ts` (rota `POST /cobrancas/:id/pagamento`), ou seja, vem direto do usuário, sem sanitização. Um valor como `id' OR '1'='1` no path da requisição marcaria todas as cobranças como pagas.

**Correção recomendada:**

```ts
await this.pool.query("UPDATE cobrancas SET status = 'paga', pago_em = now() WHERE id = $1", [id]);
```

Mesmo padrão já usado em `buscar` — troca mecânica, sem risco de regressão de comportamento. Recomendo tratar como bloqueante para o release de sexta: é o único achado dos cinco com exploração prática e impacto direto em integridade de dados financeiros.

## Resumo para o tech lead

| # | Achado | Veredito | Ação |
|---|---|---|---|
| 1 | Pool do `pg` | Falso positivo — singleton correto | Nenhuma (opcional: explicitar timeouts) |
| 2 | `readFileSync` | Falso positivo — só roda no boot | Nenhuma |
| 3 | Interface com 1 implementação | Falso positivo — 2 implementações (prod + fake de teste) | Nenhuma |
| 4 | `.then`/`.catch` | Estilo, não defeito — fire-and-forget com erro tratado | Opcional (padronizar estilo depois) |
| 5 | A query | **Defeito real — SQL injection** | **Corrigir antes do release** |
