from sqlalchemy import text

from app.db import Session


def saldo_em_centavos(usuario_id: int) -> int:
    with Session() as session:
        row = session.execute(text("SELECT saldo_centavos FROM carteiras WHERE usuario_id = :u"), {"u": usuario_id}).first()
        return row[0] if row else 0
