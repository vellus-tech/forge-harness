using Recarga.Domain;
using Xunit;

namespace Recarga.Tests;

public class RecargaPixTests
{
    [Fact]
    public void Estornar_RecargaConfirmada_MudaParaEstornada()
    {
        var recarga = new RecargaPix(Guid.NewGuid(), 5000);
        recarga.Confirmar();
        recarga.Estornar(5000);
        Assert.Equal(StatusRecarga.Estornada, recarga.Status);
    }

    [Fact]
    public void Estornar_RecargaPendente_LancaExcecao()
    {
        var recarga = new RecargaPix(Guid.NewGuid(), 5000);
        Assert.Throws<InvalidOperationException>(() => recarga.Estornar(5000));
    }

    [Fact]
    public void Estornar_RecargaJaEstornada_LancaExcecao()
    {
        var recarga = new RecargaPix(Guid.NewGuid(), 5000);
        recarga.Confirmar();
        recarga.Estornar(5000);
        Assert.Throws<InvalidOperationException>(() => recarga.Estornar(5000));
    }

    [Fact]
    public void Estornar_ValorZeroOuNegativo_LancaExcecao()
    {
        var recarga = new RecargaPix(Guid.NewGuid(), 5000);
        recarga.Confirmar();
        Assert.Throws<InvalidOperationException>(() => recarga.Estornar(0));
    }

    [Fact]
    public void Estornar_ValorMaiorQueOriginal_LancaExcecao()
    {
        var recarga = new RecargaPix(Guid.NewGuid(), 5000);
        recarga.Confirmar();
        Assert.Throws<InvalidOperationException>(() => recarga.Estornar(5001));
    }

    [Fact]
    public void Estornar_Parcial_MantemDiferencaComoSaldoDaCarteira()
    {
        var recarga = new RecargaPix(Guid.NewGuid(), 5000);
        recarga.Confirmar();
        recarga.Estornar(3000);
        Assert.Equal(StatusRecarga.Estornada, recarga.Status);
        Assert.Equal(2000, recarga.SaldoCarteiraEmCentavos);
    }
}
