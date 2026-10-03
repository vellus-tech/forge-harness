using Conciliacao.Dominio;
using Npgsql;

namespace Conciliacao.Infra;

public sealed class LoteRepositorioSql(NpgsqlDataSource fonte) : ILoteRepositorio
{
    public async Task SalvarAsync(Lote lote, CancellationToken ct)
    {
        await using var cmd = fonte.CreateCommand("UPDATE lotes SET status = @status, conciliado_em = @em WHERE id = @id");
        cmd.Parameters.AddWithValue("status", lote.Status.ToString());
        cmd.Parameters.AddWithValue("em", (object?)lote.ConciliadoEm ?? DBNull.Value);
        cmd.Parameters.AddWithValue("id", lote.Id);
        await cmd.ExecuteNonQueryAsync(ct);
    }
}
