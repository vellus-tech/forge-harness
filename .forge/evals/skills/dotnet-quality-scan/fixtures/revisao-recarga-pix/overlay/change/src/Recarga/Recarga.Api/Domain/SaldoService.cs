namespace Recarga.Api.Domain;

public interface ISaldoService
{
    Task<decimal> ConsultarAsync(string cartaoId);
}

public class SaldoService : ISaldoService
{
    public Task<decimal> ConsultarAsync(string cartaoId) => Task.FromResult(0m);
}
