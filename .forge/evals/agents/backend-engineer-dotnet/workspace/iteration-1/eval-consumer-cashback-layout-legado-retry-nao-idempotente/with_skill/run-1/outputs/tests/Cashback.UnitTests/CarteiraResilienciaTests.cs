using Cashback.Infrastructure.Carteira;
using Polly;
using Xunit;

namespace Cashback.UnitTests;

public sealed class CarteiraResilienciaTests
{
    [Fact]
    public async Task Pipeline_tenta_cinco_vezes_antes_de_desistir()
    {
        var tentativas = 0;
        var builder = new ResiliencePipelineBuilder<HttpResponseMessage>();
        CarteiraResiliencia.Configurar(builder, atrasoBase: TimeSpan.FromMilliseconds(1));
        var pipeline = builder.Build();

        await Assert.ThrowsAsync<HttpRequestException>(() => pipeline.ExecuteAsync<HttpResponseMessage>(_ =>
        {
            tentativas++;
            throw new HttpRequestException("timeout simulado");
        }).AsTask());

        Assert.Equal(CarteiraResiliencia.MaxTentativas + 1, tentativas);
    }
}
