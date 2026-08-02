# Lógica de JWT, encriptación y validación del PIN

from datetime import datetime, timedelta, timezone
from typing import Optional

from jose import jwt
from core.config import settings


def verify_pin(plain_pin: str, stored_pin: str) -> bool:
    """
    Compara el PIN ingresado por el operario contra el PIN almacenado en BD.
    Los PINs se guardan en texto plano (asignados por administrador),
    por lo que la validación es una comparación directa de cadenas.
    """
    return plain_pin == stored_pin


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """
    Genera un Token JWT firmado con la clave secreta y el algoritmo configurados.
    
    Args:
        data: Payload base del token (debe incluir 'sub' con el id_usuario).
        expires_delta: Tiempo de vida personalizado. Si no se proporciona,
                       usa TOKEN_EXPIRE_MINUTES de la configuración.

    Returns:
        Token JWT como string codificado.
    """
    to_encode = data.copy()

    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=settings.TOKEN_EXPIRE_MINUTES)

    to_encode.update({"exp": expire})

    encoded_jwt = jwt.encode(
        to_encode,
        settings.JWT_SECRET_KEY,
        algorithm=settings.ALGORITHM
    )

    return encoded_jwt