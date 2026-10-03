namespace Conciliacao.Dominio;

public interface ILoteRepositorio
{
    Task SalvarAsync(Lote lote, CancellationToken ct);
}
