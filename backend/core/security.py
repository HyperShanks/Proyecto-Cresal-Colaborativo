from datetime import datetime, timedelta, timezone
from typing import Optional

import bcrypt
from jose import jwt, JWTError
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from uuid import UUID

from core.config import settings
from database import get_db
from models import Usuario


def hash_password(password: str) -> str:
    """Genera el hash seguro de la contraseña usando bcrypt."""
    pwd_bytes = password.encode('utf-8')
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(pwd_bytes, salt).decode('utf-8')


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verifica si la contraseña en texto plano coincide con el hash guardado."""
    try:
        return bcrypt.checkpw(
            plain_password.encode('utf-8'),
            hashed_password.encode('utf-8')
        )
    except Exception:
        return False


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


# ─────────────────────────────────────────────────────────────────────────────
# Esquema de seguridad HTTP Bearer (extrae el token del header Authorization)
# ─────────────────────────────────────────────────────────────────────────────
_bearer_scheme = HTTPBearer()


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer_scheme),
    db: Session = Depends(get_db),
) -> Usuario:
    """
    Dependencia reutilizable de FastAPI que:
    1. Extrae el token del header 'Authorization: Bearer <token>'.
    2. Lo decodifica y valida contra la clave secreta del proyecto.
    3. Recupera el usuario de la BD usando el 'sub' del payload.
    4. Lanza 401 si el token es inválido, expirado o el usuario no existe.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token inválido o expirado",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(
            credentials.credentials,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    usuario = db.query(Usuario).filter(
        Usuario.id_usuario == UUID(user_id)
    ).first()

    if usuario is None or usuario.estado != "Activo":
        raise credentials_exception

    return usuario


def verificar_rol_jefe_ventas(
    current_user: Usuario = Depends(get_current_user)
) -> Usuario:
    """
    Valida que el usuario autenticado posea el rol de Jefe de Ventas (id_rol == 6).
    Lanza 403 Forbidden si el rol no coincide.
    """
    if current_user.id_rol != 6:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acceso restringido: Se requiere rol de Jefe de Ventas para esta operación."
        )
    return current_user
