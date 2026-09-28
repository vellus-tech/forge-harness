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
}
