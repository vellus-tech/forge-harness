using Tarifacao.Domain.Repasse;
using Xunit;

namespace Tarifacao.Tests;

public class RepasseTarifaTests
{
    [Fact]
    public void Dividir_TresOperadoras_DivideIgualmente()
    {
        var partes = RepasseTarifa.Dividir(3.00m, 3);
        Assert.All(partes, p => Assert.Equal(1.00m, p));
    }
}
