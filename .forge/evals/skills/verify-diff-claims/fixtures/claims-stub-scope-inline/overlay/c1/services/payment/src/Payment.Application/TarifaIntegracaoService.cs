namespace Payment.Application;

public sealed class TarifaIntegracaoService : ITarifaIntegracaoService
{
    public static readonly TimeSpan JanelaIntegracao = TimeSpan.FromMinutes(120);
    public const decimal PercentualDesconto = 0.25m;

    public decimal CalcularDesconto(decimal tarifaBase, DateTimeOffset primeiraValidacao, DateTimeOffset validacaoAtual) => throw new NotImplementedException();
}
