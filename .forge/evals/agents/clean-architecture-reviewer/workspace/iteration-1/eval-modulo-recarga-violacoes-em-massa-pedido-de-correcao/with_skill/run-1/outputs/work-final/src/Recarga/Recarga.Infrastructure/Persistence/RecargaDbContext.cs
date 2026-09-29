using Microsoft.EntityFrameworkCore;

namespace Recarga.Infrastructure.Persistence;

public sealed class RecargaDbContext : DbContext
{
    public RecargaDbContext(DbContextOptions<RecargaDbContext> options) : base(options) { }
}
