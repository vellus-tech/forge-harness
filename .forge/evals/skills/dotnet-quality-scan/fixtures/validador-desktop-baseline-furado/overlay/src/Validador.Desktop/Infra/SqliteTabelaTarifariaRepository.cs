using Validador.Desktop.Domain;
using Validador.Desktop.Domain.Ports;

namespace Validador.Desktop.Infra;

public class SqliteTabelaTarifariaRepository : ITabelaTarifariaRepository
{
    public Task<TabelaTarifaria> CarregarVigenteAsync()
        => Task.FromResult(new TabelaTarifaria("2026.09", 4.40m, new DateTime(2026, 12, 31)));
}
