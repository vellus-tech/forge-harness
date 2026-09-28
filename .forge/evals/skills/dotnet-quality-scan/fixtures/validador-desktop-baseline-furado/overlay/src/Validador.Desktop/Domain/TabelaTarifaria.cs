namespace Validador.Desktop.Domain;

public class TabelaTarifaria
{
    public TabelaTarifaria(string versao, decimal tarifaBase, DateTime vigenteAte)
    {
        Versao = versao;
        TarifaBase = tarifaBase;
        VigenteAte = vigenteAte;
    }

    public string Versao { get; }
    public decimal TarifaBase { get; }
    public DateTime VigenteAte { get; }

    public bool EstaVigente() => DateTime.Now <= VigenteAte;
}
