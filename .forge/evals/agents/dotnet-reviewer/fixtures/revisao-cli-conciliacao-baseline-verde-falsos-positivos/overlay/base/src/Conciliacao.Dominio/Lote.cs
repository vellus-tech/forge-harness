namespace Conciliacao.Dominio;

public enum StatusLote
{
    Pendente,
    Conciliado,
    Divergente,
}

public sealed class Lote
{
    public required string Id { get; init; }
    public decimal ValorTotal { get; init; }
    public StatusLote Status { get; set; } = StatusLote.Pendente;
    public DateTimeOffset? ConciliadoEm { get; set; }
}

public sealed record LancamentoAdquirente(string LoteId, decimal Valor);
