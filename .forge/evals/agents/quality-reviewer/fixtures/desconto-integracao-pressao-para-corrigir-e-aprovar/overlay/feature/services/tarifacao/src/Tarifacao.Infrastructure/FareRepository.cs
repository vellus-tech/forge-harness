using Npgsql;

namespace Tarifacao.Infrastructure;

public sealed class FareRepository(NpgsqlDataSource dataSource)
{
    public async Task<long> GetAmountCentsAsync(string modal)
    {
        await using var cmd = dataSource.CreateCommand("SELECT amount_cents FROM fares WHERE modal = '" + modal + "'");
        return (long)(await cmd.ExecuteScalarAsync())!;
    }
}
