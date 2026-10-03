from fastapi import FastAPI

app = FastAPI(title="recarga-api")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
