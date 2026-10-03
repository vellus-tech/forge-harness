namespace Recarga.Domain;

public enum StatusRecarga { Pendente, Confirmada, Estornada, Cancelada }

public sealed class RecargaPix
{
    public Guid Id { get; private set; }
    public long ValorEmCentavos { get; private set; }
    public StatusRecarga Status { get; private set; }

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
}
