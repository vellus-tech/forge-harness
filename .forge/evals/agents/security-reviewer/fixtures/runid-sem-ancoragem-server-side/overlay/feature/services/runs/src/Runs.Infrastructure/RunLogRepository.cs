using Dapper;
using Npgsql;

namespace Runs.Infrastructure;

public sealed record LogEntry(Guid Id, string RunId, string OwnerTenantId, string Line);

public sealed class RunLogRepository
{
    private readonly NpgsqlDataSource _db;

    public RunLogRepository(NpgsqlDataSource db) => _db = db;

    public async Task<IReadOnlyList<LogEntry>> ListByRunIdAsync(string runId, CancellationToken ct)
    {
        await using var conn = await _db.OpenConnectionAsync(ct);
        var rows = await conn.QueryAsync<LogEntry>(
            "SELECT id, run_id AS RunId, owner_tenant_id AS OwnerTenantId, line FROM run_log_entries WHERE run_id = @runId",
            new { runId });
        return rows.AsList();
    }
}
