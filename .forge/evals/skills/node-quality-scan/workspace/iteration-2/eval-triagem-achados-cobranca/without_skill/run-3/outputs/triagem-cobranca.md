# Triagem dos achados do scan de qualidade: servico-cobranca

## Sumário executivo

Dos cinco achados do scan, um é defeito de verdade e bloqueia o release: a query de `marcarPaga` interpola o `id` na SQL, o que é SQL injection em rota sem autenticação. Os outros quatro não são defeito de execução, mas três deles trazem ressalvas que valem ajuste pequeno. Além dos achados do scan, encontrei um defeito de contrato real que o scan não pegou: `buscar` devolve `valor_centavos` enquanto o tipo declara `valorCentavos`. Recomendo corrigir a SQL e o contrato antes de sexta. O restante pode ficar como está, com as ressalvas registradas abaixo.

Esta triagem é de leitura do código. Não rodei typecheck nem testes, porque o projeto não tem `node_modules` instalado e a execução desta rodada não permite baixar dependências. Os achados de comportamento de banco e de TLS precisam ser confirmados em ambiente com dependências e com o banco de desenvolvimento.

## Achado 1: pool do pg (`src/db/bootstrap.ts`)

Veredito: não é defeito. Deixar como está.

O pool é criado uma única vez no nível do módulo, com `max: 10`, e é importado por `boot.ts` uma vez. Esse é o padrão correto para o pg, porque evita um pool por requisição. Há duas ressalvas de hardening que não justificam mudança agora: não existe listener `pool.on("error", ...)`, e um erro em cliente ocioso sem listener derruba o processo; e não há encerramento gracioso com `pool.end()`. Se o arquivo for tocado por outro motivo, vale adicionar o listener de erro.

## Achado 2: readFileSync (`src/boot.ts`)

Veredito: o achado em si não é defeito. Deixar como está, com dois ajustes ao redor.

A leitura síncrona acontece uma vez, no boot, antes de `app.listen`. Se o certificado não existir, o processo falha cedo, que é o comportamento desejado. Bloqueio de event loop nesse ponto não tem impacto em requisições.

Dois pontos ao lado merecem atenção. O primeiro é `key: cert`: o mesmo arquivo é passado como certificado e como chave. Isso funciona se o PEM contiver as duas partes, mas é frágil e precisa ser conferido com o arquivo real de produção. O segundo é o `as never`, que silencia o checador de tipos justamente nessa linha; o certo é tipar as opções do Fastify corretamente, não esconder o erro.

O terceiro ponto é o fallback em `src/config.ts`: `TLS_CERT_PATH` cai para `./certs/dev.pem` quando não está definido. Em produção, o serviço sobe com um certificado de desenvolvimento se a variável faltar. Isso é defeito de configuração de severidade média. Recomendo tornar `TLS_CERT_PATH` obrigatória fora de desenvolvimento, usando o mesmo helper `obrigatoria`.

## Achado 3: interface com uma implementação só (`src/domain/CobrancaRepository.ts`)

Veredito: não é defeito. Deixar como está.

A interface `CobrancaRepository` é a porta do domínio, prevista pelo desenho (o próprio comentário do arquivo explica a separação entre domínio e infraestrutura). Ela tem duas implementações: `PgCobrancaRepository` em produção e o fake em memória em `test/fakes.ts`. Contar só implementações de produção leva a um falso positivo.

Ressalva: nenhum teste importa `test/fakes.ts` hoje, então o fake existe mas não está em uso. Isso é dívida de cobertura de teste, não de interface. Remover a porta para satisfazer o scan enfraqueceria a separação que o projeto declara ter.

## Achado 4: `.then` em `src/jobs/lembrete.ts`

Veredito: não é defeito de execução. Deixar como está no código, com uma correção de nome e de log.

O disparo sem `await` é intencional, porque a função retorna `void`. O `.catch` no fim cobre tanto a falha da busca quanto eventuais erros do próprio callback, então não há rejeição não tratada. Reescrever com `async/await` seria uma preferência de estilo, não correção.

O problema real é semântico. A função se chama `agendarLembrete`, mas executa a busca imediatamente, não agenda nada. E a mensagem `lembrete enviado para ...` é registrada sem que nenhum envio aconteça: o log afirma uma ação que não existe. Além disso, não encontrei nenhum chamador de `agendarLembrete` no repositório, então a função pode ser código morto. Confirmar com o time antes de mexer. Se ela for usada, o nome e o log devem refletir o que de fato acontece.

## Achado 5: query (`src/infra/PgCobrancaRepository.ts`, método `marcarPaga`)

Veredito: defeito de verdade, crítico. Corrigir antes do release.

A linha `UPDATE cobrancas SET status = 'paga', pago_em = now() WHERE id = '${id}'` interpola o parâmetro diretamente na string SQL, sem `$1` e sem array de valores. O `id` vem de `req.params.id` na rota `POST /cobrancas/:id/pagamento`, que não tem autenticação no código atual. Isso é SQL injection explorável por qualquer cliente que alcance o serviço. Como a chamada não passa valores, o pg usa o protocolo de consulta simples, que aceita múltiplas instruções; isso amplia o alcance do ataque além de um simples `OR 1=1`. O método `buscar`, na mesma classe, usa `$1` corretamente, o que mostra que o padrão correto já existe no próprio arquivo.

Correção: `WHERE id = $1` com `[id]`. É uma mudança de uma linha, com risco de regressão baixo.

Junto com a correção, há dois defeitos de regra no mesmo método, que não são de segurança e precisam de decisão de domínio. O primeiro é que não se verifica se a linha foi de fato atualizada: `rowCount` zero ainda resulta em 204, então pagar um id inexistente parece sucesso. O segundo é que não se checa o status anterior, então uma cobrança `cancelada` pode ser marcada como paga. Recomendo tratar os dois junto com a correção de injeção, usando `rowCount` e uma condição `status = 'aberta'` na própria query.

## Defeito adicional, fora do scan: contrato de `buscar`

Veredito: defeito real de severidade média. Corrigir antes do release.

`buscar` faz `SELECT id, valor_centavos, status` e devolve `r.rows[0]` como está. O pg mantém o nome da coluna, então o objeto chega com `valor_centavos`, mas o tipo `Cobranca` declara `valorCentavos`. O TypeScript não detecta isso, porque o retorno do `query` é tipado como `any`. Na prática, `GET /cobrancas/:id` devolve um JSON com nome diferente do contrato declarado, e qualquer código que use o tipo recebe `undefined`.

Correção: usar alias na consulta, `valor_centavos AS "valorCentavos"`, ou mapear o registro explicitamente. A segunda opção é mais robusta, porque tipa o retorno.

## Resumo de decisões

| Achado | Veredito | Ação |
|---|---|---|
| 1. Pool do pg | Não é defeito | Deixar; listener de erro se o arquivo for tocado |
| 2. readFileSync | Não é defeito no achado | Deixar; revisar `key: cert`, `as never` e fallback de TLS (médio) |
| 3. Interface única | Não é defeito | Deixar; fake sem uso é dívida de teste |
| 4. `.then` | Não é defeito de execução | Deixar; revisar nome `agendarLembrete` e log enganoso; confirmar se há uso |
| 5. Query | Defeito crítico (SQL injection) | Corrigir com `$1` antes do release; tratar rowCount e status |
| Extra: contrato de `buscar` | Defeito médio | Corrigir com alias ou mapeamento |

## Limitações

Esta triagem não foi validada por execução. Não há `node_modules`, e a rodada não permite rede. Não rodei `tsc`, `vitest` nem teste de integração contra PostgreSQL. A confirmação da injeção e do contrato de `buscar` deve ser feita com um teste de regressão que falhe antes da correção, conforme a regra de red-first do projeto.
