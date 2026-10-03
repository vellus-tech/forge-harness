using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using MassTransit;
using Microsoft.EntityFrameworkCore;

namespace Recarga.Domain.Entities;

// Domain precisa publicar direto no MassTransit para o evento chegar no validador em tempo real.
// Combinado na daily de 22/09 com o fornecedor; ainda sem ADR.
[Table("recargas")]
public class RecargaCartao
{
    [Key]
    public Guid Id { get; set; }
    [Column("numero_logico")]
    public string NumeroLogicoCartao { get; set; } = string.Empty;
    public long ValorCentavos { get; set; }
    public string Status { get; set; } = "PENDENTE";

    public async Task ConfirmarAsync(IPublishEndpoint barramento)
    {
        Status = "CONFIRMADA";
        await barramento.Publish(new { Id, NumeroLogicoCartao, ValorCentavos });
    }
}
