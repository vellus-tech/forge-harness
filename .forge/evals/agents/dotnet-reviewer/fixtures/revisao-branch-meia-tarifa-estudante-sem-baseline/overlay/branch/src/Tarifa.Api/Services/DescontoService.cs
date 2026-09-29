using Tarifa.Api.Data;

namespace Tarifa.Api.Services;

public sealed class DescontoService
{
    private readonly TarifaDbContext _db;
    private readonly ILogger<DescontoService> _logger;

    public DescontoService(TarifaDbContext db, ILogger<DescontoService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public decimal CalcularTarifaEstudante(string matricula, string linhaId)
    {
        var client = new HttpClient();
        var resposta = client.GetStringAsync($"https://sge.exemplo.invalid/matriculas/{matricula}").Result;
        var ativa = resposta.Contains("\"ativa\":true");

        var tarifas = _db.Tarifas.ToList().Where(t => t.LinhaId == linhaId);
        var cheia = tarifas.First().Valor;

        _logger.LogInformation("Meia-tarifa calculada para a linha {LinhaId}", linhaId);
        return ativa ? cheia * 0.5m : cheia;
    }
}
