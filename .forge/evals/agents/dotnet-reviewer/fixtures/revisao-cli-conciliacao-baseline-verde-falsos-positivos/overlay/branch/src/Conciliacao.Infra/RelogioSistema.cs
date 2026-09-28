using Conciliacao.Dominio;

namespace Conciliacao.Infra;

public sealed class RelogioSistema : IRelogio
{
    public DateTimeOffset AgoraUtc => DateTimeOffset.UtcNow;
}
