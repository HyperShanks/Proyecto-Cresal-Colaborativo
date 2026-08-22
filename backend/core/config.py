# Variables de entorno (URLs, credenciales de BD)
from pydantic_settings import BaseSettings
from pydantic import ConfigDict


class Settings(BaseSettings):
    model_config = ConfigDict(env_file=".env", extra="ignore")

    # Variables obligatorias que deben estar en tu archivo .env
    DATABASE_URL: str
    JWT_SECRET_KEY: str
    TOKEN_EXPIRE_MINUTES: int = 30
    ALGORITHM: str = "HS256"
    SUPABASE_URL: str
    SUPABASE_KEY: str


# Instanciamos la clase para poder importarla en otros archivos
settings = Settings()