# Revisão — feature/conciliacao-cli vs main

## Camadas determinísticas

O baseline de build está verde (`dotnet-baseline.sh --check`: `Directory.Build.props`, `.editorconfig`, Central Package Management e os três analisadores de terceiros todos no lugar), então nulidade, acessibilidade, `using` não usado e formatação já são erro de compilação e não entram nesta revisão manual — o compilador já reprovou isso.

O scan de clean code (`dotnet-quality-scan`) achou duas ocorrências, e nenhuma das duas é finding: `blocking-wait` em `Program.cs:30` (`.GetAwaiter().GetResult()`) está dentro do `Main` síncrono de uma ferramenta de console — é exatamente a exceção legítima documentada da regra, não deadlock nem esgotamento de pool. `single-impl-interface` em `IRelogio` é porta de arquitetura hexagonal deliberada (o próprio arquivo comenta que é a fronteira entre domínio e infraestrutura), não abstração especulativa. As outras nove regras do scan (async-void, new-httpclient, region, generic-name, bool-param, empty-catch, datetime-now, sql-interpolation, mutable-static) não encontraram ocorrência.

## O que a revisão manual encontrou

O achado central desta revisão é que **o CI está verde porque o teste não testa nada, não porque a lógica de conciliação esteja correta**. `ConciliadorTests.ValidarLote_ComExtratoIgualAoLote_Concilia` chama `ValidarLoteAsync` e só afirma `Assert.NotNull(lote)` — uma verificação tautológica sobre uma variável local que nunca poderia ser nula. Não confere o `Status` resultante, não confere o retorno do método, não confere a persistência. Essa é a ferramenta que o cron roda às 3h para decidir se sobrou lote divergente; hoje ela sobe para produção sem nenhuma verificação real do próprio caminho que a PR descreve como objetivo (BLOCKER).

Dois achados secundários, de menor severidade: o campo `ConciliadoEm` é preenchido mesmo quando o lote fica `Divergente`, o que é um nome que mente sobre o que aconteceu (MEDIUM); e o parsing dos dois CSVs no CLI indexa campos sem validar o formato da linha, então uma linha malformada num dos arquivos da noite derruba o processo com stack trace genérico em vez de apontar o CSV e a linha com problema (LOW).

## Não bloqueado, mas fora do escopo desta review

Ausência de tratamento para lançamentos do extrato do adquirente sem lote correspondente (dinheiro entrando sem lote que bata) é uma lacuna de requisito, não um defeito de código deste diff — vale nota para quem decide o escopo do domínio, não escalada aqui.

## Detalhe completo

`review/dotnet-review.json`
