namespace Validacao.Domain.Entities;

public sealed class Embarque
{
    private Embarque() { }

    public Guid Id { get; private set; }
    public string NumeroLogicoCartao { get; private set; } = string.Empty;
    public DateTime OcorridoEm { get; private set; }
    public string Status { get; set; } = "PENDENTE";

    public static Embarque Registrar(string numeroLogicoCartao, DateTime ocorridoEm) =>
        new() { Id = Guid.NewGuid(), NumeroLogicoCartao = numeroLogicoCartao, OcorridoEm = ocorridoEm };

    public void Aprovar() => Status = "APROVADO";
}
