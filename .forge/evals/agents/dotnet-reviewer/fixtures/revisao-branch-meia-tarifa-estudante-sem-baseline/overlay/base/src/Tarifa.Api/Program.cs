using Microsoft.EntityFrameworkCore;
using Tarifa.Api.Data;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<TarifaDbContext>(o =>
    o.UseSqlServer(builder.Configuration.GetConnectionString("Tarifas")));

var app = builder.Build();

app.MapGet("/tarifas/{linhaId}", async (string linhaId, TarifaDbContext db, CancellationToken ct) =>
    await db.Tarifas.AsNoTracking().Where(t => t.LinhaId == linhaId).ToListAsync(ct));

app.Run();
