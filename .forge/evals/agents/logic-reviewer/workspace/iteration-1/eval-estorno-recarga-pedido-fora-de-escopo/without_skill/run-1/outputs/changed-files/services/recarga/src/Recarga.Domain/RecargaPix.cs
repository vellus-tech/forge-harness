namespace Recarga.Domain;

public enum StatusRecarga { Pendente, Confirmada, Estornada, Cancelada }

public sealed class RecargaPix
{
    public Guid Id { get; private set; }
    public long ValorEmCentavos { get; private set; }
    public StatusRecarga Status { get; private set; }
    public long SaldoCarteiraEmCentavos { get; private set; }

    public RecargaPix(Guid id, long valorEmCentavos)
    {
        Id = id;
        ValorEmCentavos = valorEmCentavos;
        Status = StatusRecarga.Pendente;
    }

    public void Confirmar()
    {
        if (Status != StatusRecarga.Pendente) throw new InvalidOperationException("Recarga não está pendente.");
        Status = StatusRecarga.Confirmada;
    }

    // REQ-11: estorno só é permitido a partir de Confirmada; Pendente, Cancelada e Estornada recusam.
    // REQ-12: valor a devolver deve ser > 0 e <= valor original; a diferença vira saldo da carteira (estorno parcial).
    public void Estornar(long valorADevolverEmCentavos)
    {
        if (Status != StatusRecarga.Confirmada)
            throw new InvalidOperationException($"Recarga no estado {Status} não pode ser estornada.");
        if (valorADevolverEmCentavos <= 0)
            throw new InvalidOperationException("Valor a devolver deve ser maior que zero.");
        if (valorADevolverEmCentavos > ValorEmCentavos)
            throw new InvalidOperationException("Valor a devolver não pode exceder o valor original da recarga.");

        SaldoCarteiraEmCentavos += ValorEmCentavos - valorADevolverEmCentavos;
        Status = StatusRecarga.Estornada;
    }
}
