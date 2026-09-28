using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Legacy.Bilhetagem.Models;

[Table("cartoes")]
public class Cartao
{
    [Key]
    public long Id { get; set; }
    public string NumeroLogico { get; set; } = string.Empty;
    public long SaldoCentavos { get; set; }
    public string Status { get; set; } = "ATIVO";
}
