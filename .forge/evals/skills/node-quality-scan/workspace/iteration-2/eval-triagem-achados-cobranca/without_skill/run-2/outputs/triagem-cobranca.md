# Triagem dos achados do scan de qualidade: servico-cobranca 2.3.1

## Sumário executivo

Dos cinco achados do scan, apenas um é defeito de verdade e precisa entrar antes da sexta: a query de `marcarPaga` monta SQL por interpolação de string com o `id` vindo da URL, o que é injeção de SQL. Os outros quatro são falsos positivos ou dívidas de baixo risco que podem ficar como estão. Um deles, o uso do mesmo PEM como chave e certificado, merece verificação, mas não é o que o scan apontou. Nenhum código foi alterado nesta triagem.

## Achado 1: pool do pg (src/db/bootstrap.ts)

Veredito: não é defeito. Deixar como está.

O pool é criado uma vez, no nível do módulo, com `max: 10`, e o comentário do arquivo declara que ele é o único ponto de criação. O construtor do `pg.Pool` não abre conexão, então importar o módulo em testes é inofensivo. Um ponto real, mas menor: o serviço não encerra o pool de forma graciosa (`pool.end()` não é chamado e `boot.ts` não trata sinais de término). Isso vira ticket de robustez, não bloqueia o release.

## Achado 2: readFileSync (src/boot.ts, linha 9)

Veredito: não é defeito. Deixar como está.

A leitura síncrona acontece uma única vez, antes de `app.listen`, então o custo é irrelevante e a escolha é intencional, como diz o comentário. O problema vizinho, este sim a verificar, está na mesma linha de configuração TLS: `cert` é passado como `cert` e como `key` (`{ cert, key: cert } as never`). Isso só funciona se o PEM já contiver chave privada e certificado juntos. O cast `as never` esconde essa suposição do compilador. Também vale notar que o padrão de `TLS_CERT_PATH` aponta para `./certs/dev.pem` e o host é `0.0.0.0`, ou seja, defaults de desenvolvimento que podem chegar a produção sem que ninguém perceba. Recomendação: separar `certPath` e `keyPath`, remover o cast e exigir as variáveis em produção. Isso é item próprio, não é o que o scan pediu.

## Achado 3: interface com uma implementação só (src/domain/CobrancaRepository.ts)

Veredito: falso positivo. Deixar como está.

Há duas implementações reais da porta: `PgCobrancaRepository` em produção e `repoEmMemoria` em `test/fakes.ts`, usada pelos testes do domínio. O domínio declara a porta e a infraestrutura implementa, como o comentário do próprio arquivo registra. Remover a interface acoplaria as rotas ao `pg` e tornaria os testes dependentes de banco. Se a contagem do scan considera só implementações de produção, o achado é artefato da contagem.

## Achado 4: .then em src/jobs/lembrete.ts

Veredito: não é defeito funcional. Deixar como está, com duas ressalvas para o tech lead.

O `.then` tem `.catch` e os erros são registrados pelo `log`, então nenhuma rejeição escapa. Ressalva um: `agendarLembrete` não retorna a promise, então quem chama não consegue aguardar a conclusão nem testar o resultado de forma determinística. Ressalva dois: pela leitura do código, nenhum arquivo de `src` importa `agendarLembrete`, o que sugere código morto. Confirmar com o time antes de decidir. Se o job for usado no release, a troca natural é `async/await` com retorno da promise, o que também corrige a indentação torta do encadeamento. Isso é estilo e testabilidade, não bloqueio.

## Achado 5: query em PgCobrancaRepository.marcarPaga (src/infra/PgCobrancaRepository.ts, linha 13)

Veredito: defeito real, crítico. Corrigir antes da sexta.

A linha `UPDATE cobrancas SET status = 'paga', pago_em = now() WHERE id = '${id}'` interpola o parâmetro diretamente na string SQL. O `id` vem de `req.params.id` em `src/rotas.ts` (linha 7) sem nenhuma validação. Um cliente que chame `POST /cobrancas/x' OR '1'='1/pagamento` marca todas as cobranças como pagas. Payloads com `;` podem executar outras instruções, dependendo de como o driver e o servidor tratam múltiplas instruções. O método `buscar`, no mesmo arquivo, já usa `$1` com array de parâmetros, o que mostra que a interpolação foi um erro isolado e não um padrão do projeto.

A correção é trocar para `WHERE id = $1` com `[id]`, exatamente como em `buscar`. Como a regra de correção de defeito do projeto exige red-first, o teste deve primeiro reproduzir a injeção, com um id malicioso, e falhar por comportamento (efeito colateral indevido), não por erro de compilação ou fixture, e só depois aplicar a correção.

Há também duas questões adjacentes, que não vieram do scan e não devem ser resolvidas sem decisão do negócio. O método não verifica se a cobrança existe nem o status atual, então uma cobrança `cancelada` pode virar `paga`. A rota responde 204 mesmo quando nenhuma linha é afetada. A regra de transição de status precisa ser definida pelo time antes de codificar; recomenda-se tratar isso no mesmo PR, mas só depois dessa definição.

## Recomendação para a sexta

Corrigir o achado 5 com teste red-first e parametrização. Definir com o time a regra de transição de status de `marcarPaga` e, se aprovada, incluir no mesmo PR. Abrir ticket para separar `certPath`/`keyPath` e remover o cast `as never`. Abrir ticket de graceful shutdown do pool. Os achados 1, 3 e 4 ficam como estão; o 4 tem o código morto a confirmar.

## Limitações desta triagem

Não rodei os testes: o projeto não tem `node_modules` e instalar dependências exige rede, que esta execução não permite. A análise é de leitura do código e dos arquivos de regras do `.forge/rules/`. Nenhum arquivo do projeto foi alterado.
