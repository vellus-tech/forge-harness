# Regras verificadas — o porquê e a exceção legítima

Cada regra abaixo existe porque o compilador não a cobre. Cada uma tem uma exceção real: um relatório que trata todo achado como defeito treina o time a ignorar o relatório.

## async-void `[HIGH]`

Exceção lançada dentro de `async void` não tem para onde subir — não há `Task` que o chamador possa aguardar, então ela escapa para o `SynchronizationContext` e derruba o processo. O método assíncrono devolve `Task` ou `Task<T>`.

**Exceção legítima:** event handler de framework cuja assinatura é `void` (WinForms, WPF, alguns handlers de biblioteca). Nesse caso o corpo inteiro precisa de `try/catch` — a exceção não pode vazar.

## blocking-wait `[BLOCKER]`

`.Result`, `.Wait()` e `.GetAwaiter().GetResult()` bloqueiam a thread até a `Task` completar. Em contexto com `SynchronizationContext` (ASP.NET clássico, UI) isso é deadlock determinístico; em ASP.NET Core é esgotamento do pool sob carga — o sintoma aparece em produção, nunca no teste local.

**Exceção legítima:** `Main` síncrono de ferramenta de console, construtor que não pode ser assíncrono (e mesmo aí, a saída melhor é uma factory assíncrona), e código de teste que já roda em thread dedicada.

## new-httpclient `[HIGH]`

`new HttpClient()` por requisição esgota sockets (cada instância descartada deixa a conexão em `TIME_WAIT` por até quatro minutos) e um `HttpClient` estático de longa vida nunca observa mudança de DNS. `IHttpClientFactory` resolve os dois — pooling de handler com rotação.

**Exceção legítima:** teste que injeta um `HttpMessageHandler` falso.

## region `[MEDIUM]`

`#region` não tem efeito sobre o programa; só sobre o que se enxerga. Ele é usado para dobrar o que ficou grande demais — e o problema não é a leitura, é o tamanho. A classe que precisa de dobra é a classe que precisa de divisão.

**Exceção legítima:** código gerado. Se for gerado, não deveria estar sendo revisado à mão.

## generic-name `[MEDIUM]`

`Manager`, `Helper`, `Utils` e `Utility` não nomeiam responsabilidade — sinalizam que ninguém decidiu qual é. O efeito prático é o ímã: tudo que não tem lugar óbvio acaba ali, e a classe cresce sem que nenhuma revisão consiga apontar o que exatamente não pertence a ela.

**Exceção legítima:** nome consagrado de framework já presente na base (`HostApplicationLifetime`, tipos de biblioteca externa). Renomear tipo público é mudança de contrato — vale a nota, não a exigência.

## bool-param `[MEDIUM]`

Parâmetro booleano de modo indica que a função faz duas coisas e escolhe qual na chamada. No call site, `Process(order, true)` é ilegível sem abrir a assinatura. Duas funções com nome (`Process` e `ProcessRefund`) documentam-se sozinhas.

**Exceção legítima:** o booleano é **dado**, não modo (`new Feature(enabled: true)`), ou a chamada usa argumento nomeado e o domínio já fala nesses termos.

## empty-catch `[HIGH]`

`catch { }` (ou o que só loga e segue) apaga a evidência do erro. Ele some do log e reaparece depois como corrupção de dado, longe da causa. Capturou e não pode tratar: relance preservando a causa ou propague.

**Exceção legítima:** rara e sempre comentada — cleanup em `finally` que não pode falhar, ou uma falha genuinamente irrelevante (fechar socket já fechado). Sem o comentário explicando, não é exceção.

## datetime-now `[MEDIUM]`

`DateTime.Now` amarra o domínio ao fuso da máquina e ao relógio real. O teste vira dependente do ambiente e o sistema quebra no horário de verão de um servidor. Use `DateTime.UtcNow` na borda e uma abstração de tempo (`TimeProvider` a partir do .NET 8) onde a lógica precisa de "agora".

**Exceção legítima:** formatação para exibição na borda de UI, com fuso explícito.

## sql-interpolation `[BLOCKER]`

String interpolada dentro de `FromSqlRaw`, `ExecuteSqlRaw`, `CommandText` ou `new SqlCommand` é injeção de SQL. O EF Core oferece `FromSql`/`ExecuteSql` (variantes interpoladas) que parametrizam automaticamente — a diferença é uma letra no nome do método e um incidente de segurança.

**Exceção legítima:** nenhuma para valor vindo de entrada. Identificador de tabela/coluna dinâmico (que não pode ser parametrizado) exige allowlist explícita, nunca concatenação direta.

## mutable-static `[HIGH]`

Campo ou propriedade `public static` sem `readonly`/`const` é estado global: dois testes em paralelo interferem um no outro, e em servidor concorrente vira corrida de dados. Injeção de dependência com ciclo de vida explícito resolve.

**Exceção legítima:** cache com sincronização explícita e documentada, ou `static readonly` (que o scanner já ignora).

## single-impl-interface `[MEDIUM]`

Interface com uma única implementação e nenhum outro consumidor costuma ser abstração especulativa — criada "para poder trocar depois" ou "para poder mockar". O custo é indireção permanente por um benefício hipotético.

**Exceção legítima:** porta de arquitetura hexagonal deliberada (o domínio declara a interface, a infraestrutura implementa — a segunda implementação é o teste), ou fronteira de módulo onde a interface é o contrato publicado. Essa distinção é de julgamento; o scanner só aponta.

## O que fica de fora do scanner

Herança profunda, tipo de retorno permissivo (`IEnumerable<T>` devolvido sobre coleção já materializada, que permite ao chamador enumerar duas vezes e disparar a query de novo), nome que mente sobre o que a função faz, invariante de domínio ausente e teste sem asserção. Nenhum grep decide isso com precisão aceitável — é leitura do diff, e é por isso que a skill não substitui o reviewer.
