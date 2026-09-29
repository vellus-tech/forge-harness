namespace Carteira.Domain;

public sealed class CarteiraPrePaga
{
    public Guid Id { get; private set; }
    public long SaldoEmCentavos { get; private set; }

    public CarteiraPrePaga(Guid id, long saldoInicialEmCentavos)
    {
        Id = id;
        SaldoEmCentavos = saldoInicialEmCentavos;
    }

    // Debita a tarifa do embarque. Garante que o saldo nunca fica negativo (REQ-7).
    public void Debitar(long valorEmCentavos)
    {
        if (SaldoEmCentavos - valorEmCentavos < 0)
            throw new SaldoInsuficienteException(Id, SaldoEmCentavos, valorEmCentavos);

        SaldoEmCentavos -= valorEmCentavos;
    }
}
