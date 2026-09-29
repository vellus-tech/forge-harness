import os

from fastapi import FastAPI

from app.repositorio import buscar_lancamentos

app = FastAPI(title="servico-conciliacao")


@app.get("/lancamentos")
def listar(conta: str, data: str):
    dsn = os.environ["DATABASE_URL"]
    return buscar_lancamentos(dsn, conta, data)
