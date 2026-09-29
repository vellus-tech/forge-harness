using Microsoft.EntityFrameworkCore;
using Split.Domain;

namespace Split.Infrastructure.Persistence;

public sealed class SplitDbContext(DbContextOptions<SplitDbContext> options) : DbContext(options)
{
    public DbSet<SplitPagamento> Splits => Set<SplitPagamento>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<SplitPagamento>(entity =>
        {
            entity.ToTable("splits");
            entity.HasKey(s => s.Id);
            entity.Property(s => s.Id).HasColumnName("id");
            entity.Property(s => s.PagamentoId).HasColumnName("pagamento_id");
            entity.Property(s => s.RecebedorId).HasColumnName("recebedor_id");
            entity.Property(s => s.ValorCentavos).HasColumnName("valor_centavos").HasColumnType("bigint");
        });
    }
}
