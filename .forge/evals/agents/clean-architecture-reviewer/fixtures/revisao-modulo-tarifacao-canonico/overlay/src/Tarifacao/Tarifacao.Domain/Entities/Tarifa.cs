using Amazon.DynamoDBv2.DataModel;

namespace Tarifacao.Domain.Entities;

[DynamoDBTable("tarifas")]
public sealed class Tarifa
{
    private Tarifa() { }

    public Guid Id { get; private set; }
    public string Linha { get; private set; } = string.Empty;
    public string Modal { get; private set; } = string.Empty;
    public long ValorCentavos { get; private set; }

    public static Tarifa Criar(string linha, string modal, long valorCentavos)
    {
        if (valorCentavos <= 0) throw new ArgumentOutOfRangeException(nameof(valorCentavos));
        return new Tarifa { Id = Guid.NewGuid(), Linha = linha, Modal = modal, ValorCentavos = valorCentavos };
    }
}
