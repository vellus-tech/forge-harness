namespace Recarga.Domain.Entities;

public class RecargaCartao
{
    public Guid Id { get; set; }
    public string NumeroLogicoCartao { get; set; } = string.Empty;
    public long ValorCentavos { get; set; }
    public string Status { get; private set; } = "PENDENTE";

    public void Confirmar()
    {
        Status = "CONFIRMADA";
    }
}
