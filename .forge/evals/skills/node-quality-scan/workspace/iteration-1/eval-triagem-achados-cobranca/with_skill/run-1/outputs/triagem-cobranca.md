# Triagem dos achados do scan de qualidade — servico-cobranca

Nenhum código foi alterado nesta triagem, conforme pedido. Cada achado abaixo foi lido no arquivo:linha e julgado individualmente — o scanner localiza, não decide (ver `references/clean-code-rules.md` do `node-quality-scan`).

Antes dos cinco achados, um ponto de processo separado: `bash .forge/scripts/node-baseline.sh --root . --check` falhou porque não há `eslint.config.mjs` na raiz do serviço — as regras `forge-quality/*` (que pegam via AST coisas como `console.log` direto e acesso a banco fora da camada de dados) não estão cableadas aqui. Isso não é um dos cinco achados do enunciado, mas vale registrar para o tech lead: enquanto esse baseline não for aplicado, essa segunda camada de qualidade simplesmente não roda neste serviço.

## Veredito por achado

### 1. sql-interpolation `[BLOCKER]` — `src/infra/PgCobrancaRepository.ts:13` — DEFEITO REAL, corrigir antes do release

```ts
await this.pool.query(`UPDATE cobrancas SET status = 'paga', pago_em = now() WHERE id = '${id}'`);
```

`id` vem de `req.params.id` (rota `POST /cobrancas/:id/pagamento`), ou seja, é entrada externa concatenada direto na query — injeção de SQL clássica. Não há exceção legítima para valor vindo de entrada (a própria referência da skill é explícita nisso). O método vizinho `buscar()`, na mesma classe, já usa parâmetro posicional (`$1`) corretamente — a correção é replicar o mesmo padrão aqui: `UPDATE cobrancas SET status = 'paga', pago_em = now() WHERE id = $1`, com `[id]` como segundo argumento de `.query()`. É o único achado que exige mudança de código antes de sexta.

### 2. sync-fs-blocking `[BLOCKER]` — `src/boot.ts:9` — FALSO POSITIVO, deixar como está

```ts
// Carregado uma única vez, antes de o servidor aceitar conexões.
const cert = readFileSync(config.certPath, "utf8");
```

É exatamente a exceção documentada: leitura síncrona de arquivo no boot, antes do `app.listen(...)`, para carregar o certificado TLS uma única vez. Não bloqueia nenhum request concorrente porque ainda não há requests — o servidor só passa a aceitar conexão na linha seguinte. O comentário já registra a justificativa. Rótulo `BLOCKER` do scanner é sobre a regra em geral, não sobre este caso específico.

### 3. new-pg-client `[HIGH]` — `src/db/bootstrap.ts:5` — FALSO POSITIVO, deixar como está

```ts
// Único ponto de criação do pool de conexões do serviço. Importado por boot.ts uma vez.
export const pool = new Pool({ connectionString: config.databaseUrl, max: 10 });
```

Este é literalmente o módulo de bootstrap de conexão — o único lugar do serviço em que `new Pool()` deveria aparecer, exatamente a exceção legítima da regra. `boot.ts` importa esse `pool` já pronto e passa por injeção para `PgCobrancaRepository`; não há criação de pool espalhada em outros arquivos.

### 4. floating-promise `[HIGH]` — `src/jobs/lembrete.ts:4` — FALSO POSITIVO, deixar como está

```ts
repo.buscar(id).then((c) => {
    if (c?.status === "aberta") log(`lembrete enviado para ${c.id}`);
  })
  .catch((err) => log(`falha ao enviar lembrete de ${id}: ${String(err)}`));
```

O `.catch()` existe e trata a rejeição — só está em outra linha do encadeamento (`.then(...)` quebra em bloco, `.catch(...)` vem depois). O scanner é regex sobre texto de uma linha só; essa é exatamente a limitação documentada em `references/detection-commands.md` para esta regra. Não há promise sem tratamento aqui.

### 5. single-impl-interface `[MEDIUM]` — `CobrancaRepository` (`src/domain/CobrancaRepository.ts`) — FALSO POSITIVO, deixar como está

```ts
// Porta do domínio: o domínio declara, a infraestrutura implementa (ver PgCobrancaRepository).
// Nos testes, o domínio recebe um fake em memória (test/fakes.ts).
export interface Cobranca { ... }
export interface CobrancaRepository { ... }
```

É a exceção documentada por excelência: porta de arquitetura hexagonal deliberada. O domínio declara a interface, `PgCobrancaRepository` (infraestrutura) implementa em produção, e `test/fakes.ts` fornece a segunda "implementação" — o fake em memória usado nos testes (`repoEmMemoria`), que satisfaz a mesma forma sem implementar a interface via `class ... implements`. O comentário no arquivo já declara essa intenção. Não é abstração especulativa: existe consumidor real (`rotas.ts`) e propósito de teste real.

## Resumo para o tech lead

De cinco achados, um é defeito real e quatro são falsos positivos/exceções legítimas já documentadas na skill:

- **Corrigir antes do release:** #1 (`sql-interpolation` em `PgCobrancaRepository.marcarPaga`) — injeção de SQL a partir de `req.params.id`. É o único item que bloqueia sexta.
- **Deixar como está, sem mudança de código:** #2 (leitura síncrona no boot, antes do listen), #3 (o próprio módulo de bootstrap de pool), #4 (`.then()/.catch()` quebrado em linhas, mas tratado), #5 (porta hexagonal com domínio/infra/teste separados como projetado).

"FAIL" no relatório do scanner significa "achou candidatos a revisar", não "quatro bugs a corrigir" — tratar os cinco como defeito automático teria adicionado trabalho e indireção onde o desenho já está correto, e teria deixado a única injeção de SQL real competindo por atenção com falsos positivos.
