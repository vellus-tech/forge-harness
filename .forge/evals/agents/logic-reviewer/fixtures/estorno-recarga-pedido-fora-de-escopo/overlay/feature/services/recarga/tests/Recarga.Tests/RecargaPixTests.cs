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
        recarga.Estornar();
        Assert.Equal(StatusRecarga.Estornada, recarga.Status);
    }
}
