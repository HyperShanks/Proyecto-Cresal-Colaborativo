# Variables de entorno (URLs, credenciales de BD)
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # Variables obligatorias que deben estar en tu archivo .env
    DATABASE_URL: str
    
    # Variables de seguridad que usaremos para el Login (HU-1)
    # Les damos un valor por defecto en caso de que falten en desarrollo
    JWT_SECRET_KEY: str = "clave_secreta_para_desarrollo_cambiar_en_produccion"
    TOKEN_EXPIRE_MINUTES: int = 30

    class Config:
        env_file = ".env"

# Instanciamos la clase para poder importarla en otros archivos
settings = Settings()