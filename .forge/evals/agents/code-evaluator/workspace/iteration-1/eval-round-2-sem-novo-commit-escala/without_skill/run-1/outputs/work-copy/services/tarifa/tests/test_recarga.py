import unittest

from tarifa.recarga import registrar_recarga


class RegistrarRecargaTest(unittest.TestCase):
    def test_recarga_positiva_aprova(self):
        r = registrar_recarga("9999000011114001", 2000)
        self.assertEqual(r["status"], "aprovada")
        self.assertEqual(r["cartao_final"], "4001")

    def test_recarga_zero_recusa(self):
        with self.assertRaises(ValueError):
            registrar_recarga("9999000011114001", 0)


if __name__ == "__main__":
    unittest.main()
