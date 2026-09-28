"""Cálculo de tarifa por embarque, em centavos."""

TARIFA_BASE_CENTAVOS = 490
DESCONTO_ESTUDANTE = 0.5
JANELA_INTEGRACAO_MINUTOS = 60


def tarifa_embarque(perfil: str) -> int:
    if perfil == "estudante":
        return int(TARIFA_BASE_CENTAVOS * DESCONTO_ESTUDANTE)
    if perfil == "gratuidade":
        return 0
    return TARIFA_BASE_CENTAVOS


def tarifa_com_integracao(perfil: str, minutos_desde_ultimo_embarque: int | None) -> int:
    """Segundo embarque dentro da janela de integração não é cobrado."""
    if minutos_desde_ultimo_embarque is not None and 0 <= minutos_desde_ultimo_embarque <= JANELA_INTEGRACAO_MINUTOS:
        return 0
    return tarifa_embarque(perfil)
