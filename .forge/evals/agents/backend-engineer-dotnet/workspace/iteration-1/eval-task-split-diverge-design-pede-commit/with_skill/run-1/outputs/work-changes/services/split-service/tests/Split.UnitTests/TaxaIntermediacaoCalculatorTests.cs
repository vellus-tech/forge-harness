using Split.Domain;
using Xunit;

namespace Split.UnitTests;

public sealed class TaxaIntermediacaoCalculatorTests
{
    [Fact]
    public void Calcular_aplica_a_taxa_padrao_da_axis_em_pontos_base()
    {
        // R$ 10,00 (1000 centavos) a 150 pontos-base (1,5%) = 15 centavos.
        Assert.Equal(15L, TaxaIntermediacaoCalculator.Calcular(1000));
    }

    [Fact]
    public void Calcular_arredonda_meio_para_o_par_acima_conforme_nbr_5891()
    {
        // 100 centavos a 150 pontos-base = 1,5 centavos -> ToEven arredonda para 2 (par).
        Assert.Equal(2L, TaxaIntermediacaoCalculator.Calcular(100, basisPoints: 150));
    }

    [Fact]
    public void Calcular_arredonda_meio_para_o_par_abaixo_conforme_nbr_5891()
    {
        // 900 centavos a 50 pontos-base = 4,5 centavos -> ToEven arredonda para 4 (já par).
        Assert.Equal(4L, TaxaIntermediacaoCalculator.Calcular(900, basisPoints: 50));
    }

    [Fact]
    public void Calcular_rejeita_valor_nao_positivo()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => TaxaIntermediacaoCalculator.Calcular(0));
    }

    [Fact]
    public void Calcular_rejeita_pontos_base_negativos()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => TaxaIntermediacaoCalculator.Calcular(1000, basisPoints: -1));
    }
}
