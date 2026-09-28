using Cashback.Domain;
using Cashback.Infrastructure.Carteira;
using MassTransit;

namespace Cashback.Worker.Consumers;

/// <summary>Consome `ViagemValidada` (exchange `bilhetagem.viagens`) e credita 2% de cashback na carteira do passageiro.</summary>
public sealed class ViagemValidadaConsumer(CarteiraClient carteiraClient) : IConsumer<ViagemValidada>
{
    public async Task Consume(ConsumeContext<ViagemValidada> context)
    {
        var evento = context.Message;

        var valorCashbackCentavos = RegraCashback.CalcularCentavos(evento.TarifaCentavos);
        if (valorCashbackCentavos <= 0)
        {
            return;
        }

        // Chave de idempotência derivada do eventoId (único por viagem): garante que retries do
        // HttpClient e redeliveries da fila não creditem a mesma viagem duas vezes.
        var idempotencyKey = $"cashback-viagem-{evento.EventoId}";

        var request = new CreditoRequest(evento.PassageiroId, valorCashbackCentavos, "cashback-viagem-validada");
        await carteiraClient.CreditarAsync(request, idempotencyKey, context.CancellationToken);
    }
}
