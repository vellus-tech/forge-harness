namespace Pagamentos.Domain;

public interface IPagamentoRepository
{
    Task<Pagamento?> ObterAsync(Guid id, CancellationToken ct);
}
