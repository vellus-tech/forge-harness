namespace Conciliacao.Dominio;

// Porta do domínio: o relógio é infraestrutura; o domínio só declara o que precisa dele.
public interface IRelogio
{
    DateTimeOffset AgoraUtc { get; }
}
