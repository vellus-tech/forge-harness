using Microsoft.EntityFrameworkCore;
using Recarga.Domain.Entities;

namespace Recarga.Domain.Repositories;

public interface IRecargaRepository
{
    DbSet<RecargaCartao> Recargas { get; }
    IQueryable<RecargaCartao> Filtrar(IQueryable<RecargaCartao> consulta);
}
