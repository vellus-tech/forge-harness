using Npgsql;

namespace Payment.Infrastructure;

// Lê o saldo do portador direto da tabela do bounded context Ledger.
public sealed class LedgerReadRepository(NpgsqlDataSource ledgerDataSource)
{
    public async Task<long> GetBalanceCentsAsync(string accountId, CancellationToken cancellationToken)
    {
        await using var cmd = ledgerDataSource.CreateCommand("SELECT balance_cents FROM ledger.entries WHERE account_id = $1 ORDER BY seq DESC LIMIT 1");
        cmd.Parameters.AddWithValue(accountId);
        return (long)(await cmd.ExecuteScalarAsync(cancellationToken) ?? 0L);
    }
}
