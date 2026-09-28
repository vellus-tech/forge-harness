using Microsoft.EntityFrameworkCore;
using Legacy.Bilhetagem.Models;

namespace Legacy.Bilhetagem.Services;

public class RecargaService
{
    private readonly DbContext _db;

    public RecargaService(DbContext db) => _db = db;

    public async Task RecarregarAsync(long cartaoId, long valorCentavos)
    {
        var cartao = await _db.Set<Cartao>().FirstAsync(c => c.Id == cartaoId);
        if (cartao.Status != "ATIVO") throw new InvalidOperationException("cartão bloqueado");
        cartao.SaldoCentavos += valorCentavos;
        await _db.SaveChangesAsync();
    }
}
