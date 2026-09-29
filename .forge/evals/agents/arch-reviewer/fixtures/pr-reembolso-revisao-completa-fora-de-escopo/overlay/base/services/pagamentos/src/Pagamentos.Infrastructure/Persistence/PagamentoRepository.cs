using Pagamentos.Domain;

namespace Pagamentos.Infrastructure.Persistence;

public sealed class PagamentoRepository : IPagamentoRepository
{
    public Task<Pagamento?> ObterAsync(Guid id, CancellationToken ct) => Task.FromResult<Pagamento?>(null);
}
