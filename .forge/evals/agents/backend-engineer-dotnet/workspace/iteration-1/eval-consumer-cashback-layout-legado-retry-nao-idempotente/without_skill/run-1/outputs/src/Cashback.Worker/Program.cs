using Cashback.Infrastructure.Carteira;
using MassTransit;
using MassTransit.RabbitMqTransport;
using Polly;
using Polly.Extensions.Http;
using RabbitMQ.Client;

var builder = Host.CreateApplicationBuilder(args);

builder.Services.AddHttpClient<CarteiraClient>(client =>
{
    client.BaseAddress = new Uri(builder.Configuration["Carteira:BaseUrl"]!);
    client.Timeout = TimeSpan.FromSeconds(5);
})
    .AddPolicyHandler(GetCarteiraRetryPolicy());

builder.Services.AddMassTransit(bus =>
{
    bus.AddConsumer<Cashback.Worker.Consumers.ViagemValidadaConsumer>();
    bus.UsingRabbitMq((context, cfg) =>
    {
        cfg.Host(builder.Configuration["RabbitMq:Host"]);

        // A validadora publica ViagemValidada na exchange `bilhetagem.viagens`; vinculamos a fila
        // deste worker a ela explicitamente em vez de depender da topologia por convenção do MassTransit.
        cfg.ReceiveEndpoint("cashback-worker-viagem-validada", (IRabbitMqReceiveEndpointConfigurator endpoint) =>
        {
            endpoint.Bind("bilhetagem.viagens", binding => binding.ExchangeType = ExchangeType.Fanout);
            endpoint.ConfigureConsumer<Cashback.Worker.Consumers.ViagemValidadaConsumer>(context);
        });
    });
});

builder.Build().Run();

// 5 tentativas com backoff exponencial. Cobre timeout (TaskCanceledException) e erros 5xx —
// os cenários reais de instabilidade da API da carteira no horário de pico (ver
// docs/integracoes/carteira-api.md). A idempotência do lado do CarteiraClient (Idempotency-Key)
// é o que torna esse retry seguro: sem ela, retry aqui geraria crédito duplicado.
static IAsyncPolicy<HttpResponseMessage> GetCarteiraRetryPolicy() =>
    HttpPolicyExtensions
        .HandleTransientHttpError()
        .Or<TaskCanceledException>()
        .WaitAndRetryAsync(
            retryCount: 5,
            sleepDurationProvider: attempt => TimeSpan.FromMilliseconds(200 * Math.Pow(2, attempt)));
