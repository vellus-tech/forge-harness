import unittest

from tarifa.calculo import tarifa_com_integracao


class TarifaIntegracaoTest(unittest.TestCase):
    def test_primeiro_embarque_paga_tarifa_do_perfil(self):
        self.assertEqual(tarifa_com_integracao("comum", None), 490)

    def test_dentro_da_janela_nao_cobra(self):
        self.assertEqual(tarifa_com_integracao("estudante", 45), 0)

    def test_limite_da_janela_nao_cobra(self):
        self.assertEqual(tarifa_com_integracao("comum", 60), 0)

    def test_fora_da_janela_cobra_de_novo(self):
        self.assertEqual(tarifa_com_integracao("comum", 61), 490)


if __name__ == "__main__":
    unittest.main()
