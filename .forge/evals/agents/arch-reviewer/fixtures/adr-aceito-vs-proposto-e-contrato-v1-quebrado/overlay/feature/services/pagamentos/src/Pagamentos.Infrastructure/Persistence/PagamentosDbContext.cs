using Microsoft.EntityFrameworkCore;
using Pagamentos.Domain;

namespace Pagamentos.Infrastructure.Persistence;

public sealed class PagamentosDbContext(DbContextOptions<PagamentosDbContext> options) : DbContext(options)
{
    public DbSet<Pagamento> Pagamentos => Set<Pagamento>();
}
