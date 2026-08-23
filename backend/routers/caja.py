from fastapi import APIRouter, Depends
from models import Usuario
from schemas import CajaVerificarAccesoResponse
from core.security import require_caja_role

router = APIRouter(
    prefix="/api/v1/caja",
    tags=["Caja"]
)


@router.get(
    "/verificar-acceso",
    response_model=CajaVerificarAccesoResponse,
    summary="Verificar Acceso de Caja",
    description="Valida que el token JWT pertenezca a un usuario con rol de Caja (id_rol == 3) o Administrador (id_rol == 5)."
)
def verificar_acceso_caja(
    current_user: Usuario = Depends(require_caja_role)
):
    """
    Endpoint de sondeo y verificación de permisos para el módulo de caja.
    """
    rol_nombre = "Caja"
    if current_user.rol and current_user.rol.nombre_rol:
        rol_nombre = current_user.rol.nombre_rol
    elif current_user.id_rol == 5:
        rol_nombre = "Administrador"

    return CajaVerificarAccesoResponse(
        autorizado=True,
        rol=rol_nombre,
        id_sucursal=current_user.id_sucursal
    )
