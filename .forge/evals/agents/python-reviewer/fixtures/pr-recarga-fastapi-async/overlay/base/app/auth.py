from fastapi import Header, HTTPException


async def usuario_atual(authorization: str = Header(...)) -> int:
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401)
    return int(authorization.removeprefix("Bearer ").split(".")[0])
