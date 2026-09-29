namespace Pagamentos.Domain;

public sealed class Pagamento
{
    public Guid Id { get; private set; }
    public decimal Valor { get; private set; }

    private Pagamento() { }

    public static Pagamento Create(decimal valor) => new() { Id = Guid.NewGuid(), Valor = valor };

    public static Pagamento Reconstitute(Guid id, decimal valor) => new() { Id = id, Valor = valor };
}
