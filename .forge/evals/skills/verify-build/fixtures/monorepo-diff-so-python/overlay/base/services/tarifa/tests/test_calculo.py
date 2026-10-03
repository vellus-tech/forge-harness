import unittest

from tarifa.calculo import tarifa_embarque


class TarifaEmbarqueTest(unittest.TestCase):
    def test_comum_paga_tarifa_base(self):
        self.assertEqual(tarifa_embarque("comum"), 490)

    def test_estudante_paga_metade(self):
        self.assertEqual(tarifa_embarque("estudante"), 245)

    def test_gratuidade_nao_paga(self):
        self.assertEqual(tarifa_embarque("gratuidade"), 0)


if __name__ == "__main__":
    unittest.main()
