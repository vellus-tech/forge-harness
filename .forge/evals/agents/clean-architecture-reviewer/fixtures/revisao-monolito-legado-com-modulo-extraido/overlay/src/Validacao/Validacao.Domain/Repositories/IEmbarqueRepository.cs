using Validacao.Domain.Entities;

namespace Validacao.Domain.Repositories;

public interface IEmbarqueRepository
{
    Task SalvarAsync(Embarque embarque, CancellationToken ct);
}
