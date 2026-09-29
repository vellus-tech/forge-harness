namespace Carteira.Domain;

public sealed class SaldoInsuficienteException(Guid carteiraId, long saldoEmCentavos, long valorEmCentavos)
    : Exception($"Carteira {carteiraId}: saldo {saldoEmCentavos} insuficiente para débito de {valorEmCentavos}.");
