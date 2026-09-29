using Cashback.Infrastructure.Carteira;
using MassTransit;

var builder = Host.CreateApplicationBuilder(args);

builder.Services.AddHttpClient<CarteiraClient>(client =>
{
    client.BaseAddress = new Uri(builder.Configuration["Carteira:BaseUrl"]!);
    client.Timeout = TimeSpan.FromSeconds(5);
});

builder.Services.AddMassTransit(bus =>
{
    bus.AddConsumers(typeof(Program).Assembly);
    bus.UsingRabbitMq((context, cfg) =>
    {
        cfg.Host(builder.Configuration["RabbitMq:Host"]);
        cfg.ConfigureEndpoints(context);
    });
});

builder.Build().Run();
