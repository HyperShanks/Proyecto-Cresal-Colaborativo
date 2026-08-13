# Router de Autenticación por PIN 
# Expone el endpoint POST /api/auth/login-pin para que los operarios
# inicien sesión desde la app Flutter usando su PIN de 4 dígitos.

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, joinedload

from database import get_db
from models import Usuario
from schemas import LoginPINRequest, TokenResponse, UsuarioData
from core.security import verify_pin, create_access_token

router = APIRouter(
    prefix="/api/auth",
    tags=["Autenticación"]
)


@router.post(
    "/login-pin",
    response_model=TokenResponse,
    summary="Login por PIN de Operario",
    description="Autentica a un operario usando su PIN de 4 dígitos asignado. "
                "Retorna un JWT Bearer Token y los datos públicos del usuario."
)
def login_por_pin(request: LoginPINRequest, db: Session = Depends(get_db)):
    """
    Flujo de autenticación por PIN:

    1. Busca en la tabla Usuario el registro cuyo pin_acceso coincide con el ingresado.
    2. Camino Triste: Si no existe o está inactivo → 401 Unauthorized.
    3. Camino Feliz: Si es válido y activo → Genera JWT y retorna TokenResponse.
    """
    # Consulta: buscar usuario por PIN (cargando relación con Rol)
    usuario = db.query(Usuario).options(joinedload(Usuario.rol)).filter(
        Usuario.pin_acceso == request.pin
    ).first()

    # Camino Triste: PIN no encontrado
    if not usuario:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="PIN inválido o usuario inactivo"
        )

    # Camino Triste: Usuario encontrado pero inactivo
    if usuario.estado != "Activo":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="PIN inválido o usuario inactivo"
        )

    # Verificación adicional de PIN (comparación explícita)
    if not verify_pin(request.pin, usuario.pin_acceso):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="PIN inválido o usuario inactivo"
        )

    # Camino Feliz: Generar JWT con sub = id_usuario como string
    access_token = create_access_token(
        data={"sub": str(usuario.id_usuario)}
    )

    usuario_data = UsuarioData.model_validate(usuario)
    if usuario.rol and not usuario_data.nombre_rol:
        usuario_data.nombre_rol = usuario.rol.nombre_rol

    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        usuario=usuario_data
    )
