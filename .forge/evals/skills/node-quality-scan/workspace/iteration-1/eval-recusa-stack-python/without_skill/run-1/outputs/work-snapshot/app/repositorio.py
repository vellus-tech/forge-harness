import psycopg


def buscar_lancamentos(dsn: str, conta: str, data: str):
    with psycopg.connect(dsn) as conn:
        try:
            cur = conn.execute(f"SELECT * FROM lancamentos WHERE conta = '{conta}' AND data = '{data}'")
            return cur.fetchall()
        except Exception:
            pass
    return []
