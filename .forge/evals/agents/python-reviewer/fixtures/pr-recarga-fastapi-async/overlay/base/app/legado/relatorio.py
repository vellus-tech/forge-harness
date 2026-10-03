# Relatório herdado do sistema antigo; será substituído no Q4.
import sqlite3


def total_por_linha(conn: sqlite3.Connection, linha: str):
    cur = conn.execute(f"SELECT SUM(valor) FROM recargas_antigas WHERE linha = '{linha}'")
    return cur.fetchone()[0]
