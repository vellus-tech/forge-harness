using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Split.Infrastructure.Persistence;

/// <summary>
/// Fábrica usada apenas em design time (`dotnet ef migrations add`) para gerar migrations
/// sem depender de um host/API real. A connection string aqui não conecta a nenhum banco —
/// a ferramenta só precisa do provider para gerar o SQL da migration (DD-003).
/// </summary>
public sealed class SplitDbContextDesignTimeFactory : IDesignTimeDbContextFactory<SplitDbContext>
{
    public SplitDbContext CreateDbContext(string[] args)
    {
        var optionsBuilder = new DbContextOptionsBuilder<SplitDbContext>();
        optionsBuilder.UseNpgsql("Host=localhost;Database=split_design_time;Username=design_time;Password=design_time");
        return new SplitDbContext(optionsBuilder.Options);
    }
}
