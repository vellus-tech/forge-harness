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


JANELA_INTEGRACAO_MINUTOS = 90


def calcular_integracao(tarifa_primeira: int, tarifa_segunda: int, minutos_desde_primeira: int) -> int:
    """Total cobrado em duas viagens; a segunda sai com 50% de desconto dentro da janela de integração."""
    if minutos_desde_primeira < 0:
        raise ValueError("intervalo negativo")
    if minutos_desde_primeira <= JANELA_INTEGRACAO_MINUTOS:
        return tarifa_primeira + tarifa_segunda // 2
    return tarifa_primeira + tarifa_segunda
