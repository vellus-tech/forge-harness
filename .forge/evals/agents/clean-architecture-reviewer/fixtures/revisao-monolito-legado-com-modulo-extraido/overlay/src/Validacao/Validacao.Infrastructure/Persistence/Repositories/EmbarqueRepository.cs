using Microsoft.EntityFrameworkCore;
using Validacao.Domain.Entities;
using Validacao.Domain.Repositories;

namespace Validacao.Infrastructure.Persistence.Repositories;

public sealed class EmbarqueRepository : IEmbarqueRepository
{
    private readonly DbContext _db;

    public EmbarqueRepository(DbContext db) => _db = db;

    public async Task SalvarAsync(Embarque embarque, CancellationToken ct)
    {
        _db.Add(embarque);
        await _db.SaveChangesAsync(ct);
    }
}
