using Carteira.Domain;
using Xunit;

namespace Carteira.Tests;

public class CarteiraPrePagaTests
{
    [Fact]
    public void Debitar_SaldoInsuficiente_LancaExcecao()
    {
        var carteira = new CarteiraPrePaga(Guid.NewGuid(), 1000);
        carteira.Debitar(440);
        Assert.Equal(560, carteira.SaldoEmCentavos);
    }

    [Fact]
    public void Formatar_SaldoEmCentavos_ExibeEmReais()
    {
        Assert.Equal("R$ 5,60", Carteira.Api.Apresentacao.SaldoFormatter.Formatar(560));
    }
}
