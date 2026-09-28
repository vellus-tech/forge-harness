using Microsoft.EntityFrameworkCore;
using Recarga.Domain.Entities;

namespace Recarga.Infrastructure.Persistence;

public sealed class RecargaDbContext : DbContext
{
    public RecargaDbContext(DbContextOptions<RecargaDbContext> options) : base(options) { }

    public DbSet<RecargaCartao> Recargas => Set<RecargaCartao>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<RecargaCartao>(entidade =>
        {
            entidade.ToTable("recargas");
            entidade.HasKey(r => r.Id);
            entidade.Property(r => r.NumeroLogicoCartao).HasColumnName("numero_logico");
        });
    }
}
