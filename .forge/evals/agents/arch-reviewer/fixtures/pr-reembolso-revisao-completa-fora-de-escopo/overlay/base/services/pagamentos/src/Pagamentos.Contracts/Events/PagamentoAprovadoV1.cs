namespace Pagamentos.Contracts.Events.V1;

// Evento publicado no tópico "pagamentos.pagamento-aprovado.v1"; consumido por Bilhetagem e Conciliação.
public sealed record PagamentoAprovadoV1(Guid PagamentoId, decimal Valor, DateTimeOffset AprovadoEm);
