using System.Net.Http.Json;

namespace Cashback.Infrastructure.Carteira;

public sealed record CreditoRequest(Guid PassageiroId, long ValorCentavos, string Origem);

/// <summary>Cliente tipado da API da carteira digital (serviço de outro time). Ver docs/integracoes/carteira-api.md.</summary>
public sealed class CarteiraClient(HttpClient httpClient)
{
    /// <summary>
    /// Credita um valor na carteira do passageiro. A API não é idempotente por padrão — o chamador
    /// DEVE fornecer um <paramref name="idempotencyKey"/> estável (até 64 caracteres) por operação
    /// de negócio (ex.: derivado do id do evento de origem), para que retries e redeliveries da fila
    /// não gerem crédito duplicado. Ver docs/integracoes/carteira-api.md.
    /// </summary>
    public async Task CreditarAsync(CreditoRequest request, string idempotencyKey, CancellationToken cancellationToken)
    {
        using var httpRequest = new HttpRequestMessage(HttpMethod.Post, "/v1/creditos")
        {
            Content = JsonContent.Create(request),
        };
        httpRequest.Headers.Add("Idempotency-Key", idempotencyKey);

        using var response = await httpClient.SendAsync(httpRequest, cancellationToken);
        response.EnsureSuccessStatusCode();
    }
}
