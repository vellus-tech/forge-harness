using Validacao.Domain.Entities;
using Validacao.Domain.Repositories;

namespace Validacao.Application.Handlers;

public sealed class RegistrarEmbarqueHandler
{
    private readonly IEmbarqueRepository _repositorio;

    public RegistrarEmbarqueHandler(IEmbarqueRepository repositorio) => _repositorio = repositorio;

    public async Task<Guid> HandleAsync(string numeroLogicoCartao, CancellationToken ct)
    {
        var embarque = Embarque.Registrar(numeroLogicoCartao, DateTime.UtcNow);
        embarque.Aprovar();
        await _repositorio.SalvarAsync(embarque, ct);
        return embarque.Id;
    }
}
