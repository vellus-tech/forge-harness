using System.Net.Http.Json;

namespace Cashback.Infrastructure.Carteira;

public sealed record CreditoRequest(Guid PassageiroId, long ValorCentavos, string Origem);

/// <summary>Cliente tipado da API da carteira digital (serviço de outro time). Ver docs/integracoes/carteira-api.md.</summary>
public sealed class CarteiraClient(HttpClient httpClient)
{
    public async Task CreditarAsync(CreditoRequest request, CancellationToken cancellationToken)
    {
        using var response = await httpClient.PostAsJsonAsync("/v1/creditos", request, cancellationToken);
        response.EnsureSuccessStatusCode();
    }
}
