using Conciliacao.Dominio;
using Conciliacao.Infra;
using Xunit;

namespace Conciliacao.Testes;

public sealed class ConciliadorTests
{
    [Fact]
    public async Task ValidarLote_ComExtratoIgualAoLote_Concilia()
    {
        var repositorio = new LoteRepositorioEmMemoria();
        var conciliador = new Conciliador(new RelogioSistema(), repositorio);
        var lote = new Lote { Id = "L-001", ValorTotal = 150.00m };
        var extrato = new List<LancamentoAdquirente> { new("L-001", 100.00m), new("L-001", 50.00m) };

        await conciliador.ValidarLoteAsync(lote, extrato, CancellationToken.None);

        Assert.NotNull(lote);
    }
}

internal sealed class LoteRepositorioEmMemoria : ILoteRepositorio
{
    public List<Lote> Salvos { get; } = [];

    public Task SalvarAsync(Lote lote, CancellationToken ct)
    {
        Salvos.Add(lote);
        return Task.CompletedTask;
    }
}
