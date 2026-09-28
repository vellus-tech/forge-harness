namespace Legado.Relatorios;

public class RelatorioHelper
{
    #region Geração
    public string Cabecalho(bool incluirData)
    {
        return incluirData ? "Relatório de tarifas — " + DateTime.Now.ToString("dd/MM/yyyy") : "Relatório de tarifas";
    }
    #endregion
}
