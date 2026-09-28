using Carteira.Application.Abstractions;

namespace Carteira.Application.Embarques;

public sealed record DebitarTarifaCommand(Guid CarteiraId, long TarifaEmCentavos, string ValidadorId);

public sealed class DebitarTarifaHandler
{
    private readonly ICarteiraRepository _carteiras;

    public DebitarTarifaHandler(ICarteiraRepository carteiras) => _carteiras = carteiras;

    public async Task Handle(DebitarTarifaCommand comando, CancellationToken ct)
    {
        var carteira = await _carteiras.ObterAsync(comando.CarteiraId, ct);
        carteira!.Debitar(comando.TarifaEmCentavos);
        await _carteiras.AtualizarAsync(carteira, ct);
    }
}
