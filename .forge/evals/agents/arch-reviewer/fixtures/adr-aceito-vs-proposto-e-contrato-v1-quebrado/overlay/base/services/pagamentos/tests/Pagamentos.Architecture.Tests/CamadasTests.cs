using NetArchTest.Rules;
using Xunit;

namespace Pagamentos.Architecture.Tests;

public class CamadasTests
{
    [Fact]
    public void Domain_nao_depende_de_outras_camadas() =>
        Assert.True(Types.InAssembly(typeof(Pagamentos.Domain.Pagamento).Assembly)
            .ShouldNot().HaveDependencyOnAny("Pagamentos.Application", "Pagamentos.Infrastructure", "Pagamentos.Api")
            .GetResult().IsSuccessful);
}
