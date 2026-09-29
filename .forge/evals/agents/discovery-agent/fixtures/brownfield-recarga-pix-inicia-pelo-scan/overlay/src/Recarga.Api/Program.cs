var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();
app.MapGet("/cartoes/{numero}/saldo", (string numero) => Results.Ok(new { numero, saldo = 0m }));
app.MapPost("/recargas", () => Results.Created("/recargas/1", null));
app.Run();
