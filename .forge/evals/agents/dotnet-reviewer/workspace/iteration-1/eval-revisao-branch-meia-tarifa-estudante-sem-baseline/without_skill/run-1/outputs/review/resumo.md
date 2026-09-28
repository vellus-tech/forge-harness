# Revisão .NET — feature/meia-tarifa-estudante vs main

Escopo: `src/Tarifa.Api/Program.cs` e o novo `src/Tarifa.Api/Services/DescontoService.cs`, que consulta o SGE da secretaria de educação e aplica 50% de desconto na tarifa quando a matrícula está ativa.

## Achados críticos (bloqueiam o PR)

1. **Dependência cativa de ciclo de vida** — `DescontoService` é registrado como `Singleton` em `Program.cs` mas injeta `TarifaDbContext`, que é `Scoped` por padrão. Isso derruba a aplicação no start (se `ValidateOnBuild`/`ValidateScopes` estiver ativo) ou, em produção, faz todas as requisições concorrentes compartilharem a mesma instância de `DbContext`, que não é thread-safe — risco real de corrupção de estado sob carga.

## Achados de alta severidade

2. **Sync-over-async** — a chamada ao SGE usa `.Result` sobre uma `Task`, bloqueando uma thread do pool por request e escondendo exceções atrás de `AggregateException`.
3. **`new HttpClient()` por chamada** — sem `IHttpClientFactory`, sob volume gera esgotamento de portas/sockets.
4. **Sem tratamento de erro, timeout ou `CancellationToken`** na chamada ao serviço externo — indisponibilidade do SGE vira 500 sem diagnóstico e sem limite de tempo.
5. **`tarifas.First()` sem fallback** — linha sem tarifa cadastrada lança exceção e retorna 500, em vez de 404 (inconsistente com o outro endpoint da mesma API, que retorna lista vazia).

## Achados médios

6. **Checagem de "ativa" por substring** (`resposta.Contains("\"ativa\":true")`) em vez de desserializar o JSON — frágil a qualquer variação de formatação ou campo homônimo aninhado.
7. **Filtro em memória** — `_db.Tarifas.ToList().Where(...)` traz a tabela inteira antes de filtrar, ao contrário do padrão já usado no endpoint irmão (`Where` antes do `ToListAsync`).
8. **Exposição de dado pessoal sem controle de acesso aparente** — o endpoint permite inferir se uma matrícula está ativa a partir apenas do número da matrícula na URL, sem autenticação visível; é um vetor de enumeração de dado pessoal (LGPD).

## Achado de baixa severidade

9. **Inconsistência de padrão** — o novo endpoint não é assíncrono nem recebe `CancellationToken`, diferente do padrão já estabelecido no outro endpoint da API.

## Recomendação

Não abrir o PR para `develop` antes de corrigir pelo menos os itens 1 a 5. O item 1 sozinho já é motivo de bloqueio: é um bug de configuração de DI que tanto pode impedir o boot da aplicação quanto causar corrupção de dados silenciosa em produção, dependendo da configuração de validação de escopo do host.

Detalhamento completo, com trecho de código e cenário de falha por item, em `review/dotnet-review.json`.
