using Microsoft.EntityFrameworkCore;

namespace Tarifa.Api.Data;

public sealed class TarifaDbContext(DbContextOptions<TarifaDbContext> options) : DbContext(options)
{
    public DbSet<TarifaLinha> Tarifas => Set<TarifaLinha>();
}

public sealed record TarifaLinha(int Id, string LinhaId, decimal Valor);
