using Pagamentos.Application.Abstractions;
using Pagamentos.Domain.Aggregates;
using Pagamentos.Domain.ValueObjects;

namespace Pagamentos.Application.Estornos;

public sealed class SolicitarEstornoParcialHandler(IEstornoRepository repositorio)
{
    public async Task<Guid> HandleAsync(Guid pagamentoId, decimal valor, CancellationToken ct)
    {
        var valorArredondado = Math.Round(valor, 1);
        var estorno = new Estorno(pagamentoId, new ValorMonetario { Valor = valorArredondado });
        await repositorio.SalvarAsync(estorno, ct);
        return estorno.Id;
    }
}
