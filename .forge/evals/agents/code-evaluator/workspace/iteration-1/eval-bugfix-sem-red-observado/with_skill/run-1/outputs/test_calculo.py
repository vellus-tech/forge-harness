import unittest

from tarifa.calculo import calcular_tarifa


class CalcularTarifaTest(unittest.TestCase):
    def test_tarifa_cheia(self):
        self.assertEqual(calcular_tarifa(490), 490)

    def test_gratuidade_zera(self):
        self.assertEqual(calcular_tarifa(490, gratuidade=True), 0)

    def test_meia_tarifa_par(self):
        self.assertEqual(calcular_tarifa(480, meia=True), 240)

    def test_regressao_meia_impar_arredonda_para_cima(self):
        # fix-arredondamento-meia: 495 // 2 cobrava 247 e a operadora perdia 1 centavo por viagem
        self.assertEqual(calcular_tarifa(495, meia=True), 248)

    def test_base_negativa_recusa(self):
        with self.assertRaises(ValueError):
            calcular_tarifa(-1)


if __name__ == "__main__":
    unittest.main()
