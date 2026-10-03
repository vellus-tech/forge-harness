from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str
    gateway_url: str
    gateway_api_key: str


settings = Settings()
