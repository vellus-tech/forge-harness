import unittest

from tarifa.calculo import calcular_tarifa


class CalcularTarifaTest(unittest.TestCase):
    def test_tarifa_cheia(self):
        self.assertEqual(calcular_tarifa(490), 490)

    def test_gratuidade_zera(self):
        self.assertEqual(calcular_tarifa(490, gratuidade=True), 0)

    def test_meia_tarifa_par(self):
        self.assertEqual(calcular_tarifa(480, meia=True), 240)

    def test_base_negativa_recusa(self):
        with self.assertRaises(ValueError):
            calcular_tarifa(-1)


if __name__ == "__main__":
    unittest.main()
