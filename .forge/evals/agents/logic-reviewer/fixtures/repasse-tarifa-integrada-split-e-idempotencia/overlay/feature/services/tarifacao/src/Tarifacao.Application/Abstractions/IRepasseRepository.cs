namespace Tarifacao.Application.Abstractions;

public interface IRepasseRepository
{
    Task<Guid?> ObterPorChaveAsync(string chaveIdempotencia, CancellationToken ct);
    Task SalvarAsync(Guid repasseId, string chaveIdempotencia, string viagemId, string[] operadoras, decimal[] partes, CancellationToken ct);
}
