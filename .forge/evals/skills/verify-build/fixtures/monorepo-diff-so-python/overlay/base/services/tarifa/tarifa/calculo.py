"""Cálculo de tarifa por embarque, em centavos."""

TARIFA_BASE_CENTAVOS = 490
DESCONTO_ESTUDANTE = 0.5


def tarifa_embarque(perfil: str) -> int:
    if perfil == "estudante":
        return int(TARIFA_BASE_CENTAVOS * DESCONTO_ESTUDANTE)
    if perfil == "gratuidade":
        return 0
    return TARIFA_BASE_CENTAVOS
