from fastapi import FastAPI

from app.recargas.router import router as recargas_router

app = FastAPI(title="recarga-api")
app.include_router(recargas_router)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
