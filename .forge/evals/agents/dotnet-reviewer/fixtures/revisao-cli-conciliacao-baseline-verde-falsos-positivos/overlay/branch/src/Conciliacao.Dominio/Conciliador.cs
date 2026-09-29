using System.Text;

namespace Conciliacao.Dominio;

public sealed class Conciliador(IRelogio relogio, ILoteRepositorio lotes)
{
    public async Task<bool> ValidarLoteAsync(Lote lote, IReadOnlyList<LancamentoAdquirente> extrato, CancellationToken ct)
    {
        var totalExtrato = extrato.Where(l => l.LoteId == lote.Id).Sum(l => l.Valor);
        var confere = totalExtrato == lote.ValorTotal;

        lote.Status = confere ? StatusLote.Conciliado : StatusLote.Divergente;
        lote.ConciliadoEm = relogio.AgoraUtc;
        await lotes.SalvarAsync(lote, ct);

        return confere;
    }
}
