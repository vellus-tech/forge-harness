using System.Net.Http.Json;

namespace Cashback.Infrastructure.Carteira;

public sealed record CreditoRequest(Guid PassageiroId, long ValorCentavos, string Origem);

/// <summary>Cliente tipado da API da carteira digital (serviço de outro time). Ver docs/integracoes/carteira-api.md.</summary>
public interface ICarteiraClient
{
    /// <summary>
    /// Credita <paramref name="request"/> na carteira do passageiro.
    /// <paramref name="idempotencyKey"/> é obrigatório: a API da carteira não é idempotente por padrão
    /// (duas chamadas com o mesmo corpo geram dois créditos) e só deduplica quando o header
    /// <c>Idempotency-Key</c> repete a mesma chave em até 72 h. Toda tentativa (inclusive as de retry)
    /// do mesmo crédito deve enviar a mesma chave — nunca gere uma chave nova por tentativa.
    /// </summary>
    Task CreditarAsync(CreditoRequest request, string idempotencyKey, CancellationToken cancellationToken);
}

public sealed class CarteiraClient(HttpClient httpClient) : ICarteiraClient
{
    public async Task CreditarAsync(CreditoRequest request, string idempotencyKey, CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(idempotencyKey);

        using var httpRequest = new HttpRequestMessage(HttpMethod.Post, "/v1/creditos")
        {
            Content = JsonContent.Create(request),
        };
        httpRequest.Headers.Add("Idempotency-Key", idempotencyKey);

        using var response = await httpClient.SendAsync(httpRequest, cancellationToken);
        response.EnsureSuccessStatusCode();
    }
}
