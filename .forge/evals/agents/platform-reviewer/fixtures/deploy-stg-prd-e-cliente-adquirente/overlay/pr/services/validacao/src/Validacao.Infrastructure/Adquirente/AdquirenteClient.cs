using System.Net.Http.Json;

namespace Validacao.Infrastructure.Adquirente;

// Cliente do adquirente para captura da tarifa paga com cartão EMV no validador.
public sealed class AdquirenteClient
{
    private readonly HttpClient _http;

    public AdquirenteClient(HttpClient http) => _http = http;

    public async Task<CapturaResponse> CapturarAsync(CapturaRequest request, CancellationToken ct)
    {
        var resposta = await _http.PostAsJsonAsync("https://api.adquirente.example/v2/capturas", request, ct);
        resposta.EnsureSuccessStatusCode();
        return (await resposta.Content.ReadFromJsonAsync<CapturaResponse>(cancellationToken: ct))!;
    }
}

public record CapturaRequest(string TransacaoId, long ValorCentavos, string TokenCartao);
public record CapturaResponse(string CapturaId, string Status);
