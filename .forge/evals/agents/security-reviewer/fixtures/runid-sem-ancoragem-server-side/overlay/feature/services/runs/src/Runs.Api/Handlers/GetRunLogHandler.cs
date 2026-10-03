using Microsoft.Extensions.Logging;
using Runs.Infrastructure;

namespace Runs.Api.Handlers;

public sealed record GetRunLogQuery(string RunId, string TenantIdClaim);

public sealed class GetRunLogHandler
{
    private readonly ILogger<GetRunLogHandler> _logger;
    private readonly RunLogRepository _repo;

    public GetRunLogHandler(ILogger<GetRunLogHandler> logger, RunLogRepository repo)
    {
        _logger = logger;
        _repo = repo;
    }

    public async Task<IReadOnlyList<LogEntry>> Handle(GetRunLogQuery query, CancellationToken ct)
    {
        _logger.LogInformation("Consultando log da execução runId={RunId}", query.RunId);
        return await _repo.ListByRunIdAsync(query.RunId, ct);
    }
}
