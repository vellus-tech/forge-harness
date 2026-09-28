using System.Globalization;

namespace Carteira.Api.Apresentacao;

// Camada de apresentação: converte centavos para exibição no app do passageiro.
public static class SaldoFormatter
{
    private static readonly CultureInfo PtBr = new("pt-BR");

    public static string Formatar(long saldoEmCentavos) => (saldoEmCentavos / 100m).ToString("C", PtBr);
}
