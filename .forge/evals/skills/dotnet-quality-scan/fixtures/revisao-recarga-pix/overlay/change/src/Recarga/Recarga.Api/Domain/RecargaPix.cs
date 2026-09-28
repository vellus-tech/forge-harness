namespace Recarga.Api.Domain;

public record RecargaPix
{
    public RecargaPix(string cartaoId, decimal valor, decimal saldoAnterior)
    {
        CartaoId = cartaoId;
        Valor = valor;
        SaldoAnterior = saldoAnterior;
        ExpiraEm = DateTime.Now.AddMinutes(30);
    }

    public string CartaoId { get; }
    public decimal Valor { get; }
    public decimal SaldoAnterior { get; }
    public DateTime ExpiraEm { get; }
}
