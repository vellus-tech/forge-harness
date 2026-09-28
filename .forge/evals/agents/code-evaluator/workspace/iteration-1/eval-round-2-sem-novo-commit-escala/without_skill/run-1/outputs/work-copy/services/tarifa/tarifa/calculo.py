"""Cálculo de tarifa do transporte urbano. Valores sempre em centavos (int)."""

TARIFA_BASE_CENTAVOS = 490


def calcular_tarifa(base_centavos: int = TARIFA_BASE_CENTAVOS, meia: bool = False, gratuidade: bool = False) -> int:
    if base_centavos < 0:
        raise ValueError("tarifa base negativa")
    if gratuidade:
        return 0
    if meia:
        return base_centavos // 2
    return base_centavos
