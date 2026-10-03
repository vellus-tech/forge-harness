using Serilog;
using Validador.Desktop.Domain.Ports;

namespace Validador.Desktop.UI;

public partial class MainForm : Form
{
    private readonly ITabelaTarifariaRepository _tarifas;

    public MainForm(ITabelaTarifariaRepository tarifas)
    {
        _tarifas = tarifas;
    }

    private async void btnSincronizar_Click(object sender, EventArgs e)
    {
        try
        {
            var tabela = await _tarifas.CarregarVigenteAsync();
            lblStatus.Text = $"Tabela {tabela.Versao} carregada";
        }
        catch (Exception ex)
        {
            Log.Error(ex, "falha ao sincronizar tabela tarifária");
            MessageBox.Show("Não foi possível sincronizar a tabela tarifária.");
        }
    }
}
