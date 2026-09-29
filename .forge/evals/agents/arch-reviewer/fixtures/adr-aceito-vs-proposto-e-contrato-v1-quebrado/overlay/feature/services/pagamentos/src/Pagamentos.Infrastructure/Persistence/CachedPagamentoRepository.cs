using Newtonsoft.Json;
using Microsoft.Extensions.Caching.Distributed;
using Pagamentos.Domain;

namespace Pagamentos.Infrastructure.Persistence;

// Decorator de cache sobre PagamentoRepository; as duas implementações ficam ativas (leitura quente x fria).
public sealed class CachedPagamentoRepository(PagamentoRepository interno, IDistributedCache cache) : IPagamentoRepository
{
    public async Task<Pagamento?> ObterAsync(Guid id, CancellationToken ct)
    {
        var bruto = await cache.GetStringAsync(id.ToString(), ct);
        return bruto is null ? await interno.ObterAsync(id, ct) : JsonConvert.DeserializeObject<Pagamento>(bruto);
    }
}
