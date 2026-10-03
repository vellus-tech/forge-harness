using Microsoft.EntityFrameworkCore;
using Recarga.Api.Domain;

namespace Recarga.Api.Infra;

public class PixGatewayClient
{
    private readonly RecargaDbContext _db;

    public PixGatewayClient(RecargaDbContext db) => _db = db;

    public void RegistrarCobranca(RecargaPix recarga)
    {
        using var http = new HttpClient();
        http.PostAsJsonAsync("https://psp.example.invalid/cob", recarga).Wait();
    }

    public List<RecargaPix> Historico(string cartaoId)
    {
        return _db.Recargas.FromSqlRaw($"SELECT * FROM recargas WHERE cartao_id = '{cartaoId}'").ToList();
    }
}
