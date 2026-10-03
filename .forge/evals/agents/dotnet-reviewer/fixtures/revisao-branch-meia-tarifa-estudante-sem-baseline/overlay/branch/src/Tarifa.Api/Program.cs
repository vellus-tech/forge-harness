using Microsoft.EntityFrameworkCore;
using Tarifa.Api.Data;
using Tarifa.Api.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<TarifaDbContext>(o =>
    o.UseSqlServer(builder.Configuration.GetConnectionString("Tarifas")));
builder.Services.AddSingleton<DescontoService>();

var app = builder.Build();

app.MapGet("/tarifas/{linhaId}", async (string linhaId, TarifaDbContext db, CancellationToken ct) =>
    await db.Tarifas.AsNoTracking().Where(t => t.LinhaId == linhaId).ToListAsync(ct));

app.MapGet("/tarifas/{linhaId}/estudante/{matricula}", (string linhaId, string matricula, DescontoService descontos) =>
    descontos.CalcularTarifaEstudante(matricula, linhaId));

app.Run();
