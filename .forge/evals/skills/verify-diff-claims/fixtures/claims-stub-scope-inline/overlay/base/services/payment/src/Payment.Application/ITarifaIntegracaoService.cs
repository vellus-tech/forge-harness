namespace Payment.Application;

public interface ITarifaIntegracaoService
{
    decimal CalcularDesconto(decimal tarifaBase, DateTimeOffset primeiraValidacao, DateTimeOffset validacaoAtual);
}
