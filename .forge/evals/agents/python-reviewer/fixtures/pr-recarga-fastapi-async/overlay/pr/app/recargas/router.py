import logging
from typing import Any

import requests
from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import usuario_atual
from app.config import settings
from app.db import get_session

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/recargas")


@router.post("")
async def criar_recarga(
    payload: dict[str, Any],
    usuario_id: int = Depends(usuario_atual),
    session: AsyncSession = Depends(get_session),
):
    logger.info("cobrando no gateway %s key=%s", settings.gateway_url, settings.gateway_api_key)
    resposta = requests.post(f"{settings.gateway_url}/cobrancas", json=payload, timeout=10)
    await session.execute(
        text("INSERT INTO recargas (usuario_id, cartao_id, valor_centavos, status) VALUES (:u, :c, :v, :s)"),
        {"u": usuario_id, "c": payload["cartao_id"], "v": payload["valor_centavos"], "s": resposta.json()["status"]},
    )
    await session.commit()
    return {"status": resposta.json()["status"]}


@router.get("/{recarga_id}")
async def obter_recarga(
    recarga_id: int,
    usuario_id: int = Depends(usuario_atual),
    session: AsyncSession = Depends(get_session),
):
    result = await session.execute(text("SELECT * FROM recargas WHERE id = :id"), {"id": recarga_id})
    return result.mappings().first()
