using MassTransit;
using Pagamentos.Domain.Events;
using Pagamentos.Domain.ValueObjects;

namespace Pagamentos.Domain.Aggregates;

public sealed class Estorno
{
    public Guid Id { get; }
    public Guid PagamentoId { get; }
    public ValorMonetario Valor { get; }

    public Estorno(Guid pagamentoId, ValorMonetario valor)
    {
        Id = NewId.NextGuid();
        PagamentoId = pagamentoId;
        Valor = valor;
    }

    public EstornarPagamento Registrar() => new(PagamentoId, Valor.Valor, DateTimeOffset.UtcNow);
}
