using Cashback.Infrastructure.Carteira;
using Cashback.Worker.Consumers;
using Cashback.Worker.Contracts;
using MassTransit;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Http.Resilience;
using RabbitMQ.Client;

var builder = Host.CreateApplicationBuilder(args);

// O retry de até 5 tentativas (com backoff exponencial + jitter) só é seguro porque
// CarteiraClient sempre envia o mesmo Idempotency-Key por crédito — ver CarteiraResiliencia.
builder.Services
    .AddHttpClient<ICarteiraClient, CarteiraClient>(client =>
    {
        client.BaseAddress = new Uri(builder.Configuration["Carteira:BaseUrl"]!);
        client.Timeout = TimeSpan.FromSeconds(5);
    })
    .AddResilienceHandler("carteira-creditos", static resilienceBuilder => CarteiraResiliencia.Configurar(resilienceBuilder));

builder.Services.AddMassTransit(bus =>
{
    bus.AddConsumer<ViagemValidadaConsumer>();
    bus.UsingRabbitMq((context, cfg) =>
    {
        cfg.Host(builder.Configuration["RabbitMq:Host"]);

        // cashback.creditado é publicado por nós — nome de exchange explícito para casar com contracts/asyncapi/cashback.yaml.
        cfg.Message<CashbackCreditado>(m => m.SetEntityName("cashback.creditado"));

        // bilhetagem.viagens é a exchange da validadora (contrato de outro serviço, convenção de
        // nomes diferente da nossa) — bind explícito em vez do topology automático por tipo.
        cfg.ReceiveEndpoint("cashback-worker-viagem-validada", e =>
        {
            e.ConfigureConsumeTopology = false;
            e.Bind("bilhetagem.viagens", s => s.ExchangeType = ExchangeType.Fanout);
            e.ConfigureConsumer<ViagemValidadaConsumer>(context);
        });
    });
});

builder.Build().Run();
