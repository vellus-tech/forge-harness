"""Recarga de crédito no cartão de transporte."""
import logging

logger = logging.getLogger("tarifa.recarga")


def registrar_recarga(numero_cartao: str, valor_centavos: int) -> dict:
    if valor_centavos <= 0:
        raise ValueError("valor de recarga deve ser positivo")
    logger.info("recarga aprovada cartao=%s valor=%d", numero_cartao, valor_centavos)
    return {"cartao_final": numero_cartao[-4:], "valor_centavos": valor_centavos, "status": "aprovada"}
