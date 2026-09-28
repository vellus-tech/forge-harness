namespace Pagamentos.Domain.ValueObjects;

public sealed class ValorMonetario
{
    public decimal Valor { get; set; }
    public string Moeda { get; set; } = "BRL";
}
