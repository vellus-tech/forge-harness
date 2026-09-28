namespace Legacy.Relatorios;

public class RelatorioManager
{
    public static int UltimoLote;

    #region Geracao
    public string Gerar(int lote, bool detalhado)
    {
        UltimoLote = lote;
        return detalhado ? $"lote {lote} (detalhado)" : $"lote {lote}";
    }
    #endregion
}

public static class PedidoHelper
{
    public static string Formatar(int id) => $"P-{id:D6}";
}
