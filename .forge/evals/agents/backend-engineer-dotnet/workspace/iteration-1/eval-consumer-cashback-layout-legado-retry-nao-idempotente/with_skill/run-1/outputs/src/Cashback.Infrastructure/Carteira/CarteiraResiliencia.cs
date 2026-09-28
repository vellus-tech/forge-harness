using Microsoft.Extensions.Http.Resilience;
using Polly;

namespace Cashback.Infrastructure.Carteira;

/// <summary>
/// Política de retry do POST de crédito na carteira (docs/integracoes/carteira-api.md: timeouts
/// comuns em pico, p99 ~4 s, e o crédito pode já ter sido efetivado quando o cliente recebe timeout).
/// O retry só é seguro aqui porque <see cref="CarteiraClient"/> sempre envia o mesmo
/// <c>Idempotency-Key</c> (a chave do evento de origem) em todas as tentativas — sem isso, repetir
/// o POST duplicaria o crédito, que é exatamente o cenário que a regra "nunca aplique retry cego em
/// operação não idempotente" existe para evitar.
/// </summary>
public static class CarteiraResiliencia
{
    public const int MaxTentativas = 5;
    public static readonly TimeSpan AtrasoBase = TimeSpan.FromMilliseconds(200);

    public static void Configurar(ResiliencePipelineBuilder<HttpResponseMessage> builder, TimeSpan? atrasoBase = null) =>
        builder.AddRetry(new HttpRetryStrategyOptions
        {
            MaxRetryAttempts = MaxTentativas,
            BackoffType = DelayBackoffType.Exponential,
            UseJitter = true,
            Delay = atrasoBase ?? AtrasoBase,
        });
}
