using Cashback.Domain;
using Cashback.Infrastructure.Carteira;
using Cashback.Worker.Contracts;
using MassTransit;
using Microsoft.Extensions.Logging;

namespace Cashback.Worker.Consumers;

/// <summary>
/// Consome <see cref="ViagemValidada"/> (exchange <c>bilhetagem.viagens</c>, publicada pela
/// validadora) e credita os 2% de cashback na carteira do passageiro (TASK-07, REQ-011).
/// </summary>
/// <remarks>
/// A entrega é at-least-once (a validadora republica após reconexão) e o POST de crédito não é
/// idempotente por padrão — ver docs/integracoes/carteira-api.md. A mesma viagem nunca deve gerar
/// dois créditos, então <see cref="ICarteiraClient.CreditarAsync"/> sempre recebe
/// <c>evento.EventoId</c> como <c>Idempotency-Key</c>: reprocessar a mesma mensagem (redelivery)
/// ou reenviar a mesma tentativa (retry de rede) usa a mesma chave, e a carteira deduplica.
/// </remarks>
public sealed class ViagemValidadaConsumer(ICarteiraClient carteiraClient, ILogger<ViagemValidadaConsumer> logger)
    : IConsumer<ViagemValidada>
{
    public async Task Consume(ConsumeContext<ViagemValidada> context)
    {
        var evento = context.Message;
        var valorCentavos = RegraCashback.CalcularCentavos(evento.TarifaCentavos);

        if (valorCentavos <= 0)
        {
            logger.LogWarning(
                "Tarifa nao positiva ({TarifaCentavos}) para eventoId {EventoId}; nenhum credito gerado.",
                evento.TarifaCentavos,
                evento.EventoId);
            return;
        }

        var request = new CreditoRequest(evento.PassageiroId, valorCentavos, Origem: "cashback");
        await carteiraClient.CreditarAsync(request, idempotencyKey: evento.EventoId.ToString(), context.CancellationToken);

        await context.Publish(new CashbackCreditado(evento.PassageiroId, valorCentavos, evento.CorrelationId));
    }
}
