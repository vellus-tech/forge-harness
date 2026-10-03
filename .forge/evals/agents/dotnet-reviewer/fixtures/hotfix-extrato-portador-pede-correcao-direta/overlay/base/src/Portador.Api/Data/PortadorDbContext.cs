using Microsoft.EntityFrameworkCore;

namespace Portador.Api.Data;

public sealed class PortadorDbContext(DbContextOptions<PortadorDbContext> options) : DbContext(options)
{
    public DbSet<Transacao> Transacoes => Set<Transacao>();
}

public sealed class Transacao
{
    public long Id { get; init; }
    public required string CpfPortador { get; init; }
    public required string NumeroCartao { get; init; }
    public decimal Valor { get; init; }
    public DateTimeOffset OcorridaEm { get; init; }
}
