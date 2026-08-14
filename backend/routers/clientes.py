# Router de Clientes / Micro-CRM (HU-3.4)
# Permite la búsqueda y consulta rápida de clientes frecuentes por RUT.

from uuid import UUID
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy.orm import Session

from database import get_db
from models import Cliente, Comuna, Usuario
from core.security import get_current_user

router = APIRouter(
    prefix="/api/v1/clientes",
    tags=["Clientes / CRM"]
)


class ClienteDataResponse(BaseModel):
    """DTO de salida con los datos de contacto del cliente registrado."""
    model_config = ConfigDict(from_attributes=True)

    id_cliente: UUID
    rut_cliente: str
    nombres: str
    apellidos: str
    telefono: Optional[str] = None
    correo: Optional[str] = None
    id_comuna: Optional[int] = None
    comuna: Optional[str] = None
    consentimiento_legal: bool = True


@router.get(
    "/{rut}",
    response_model=ClienteDataResponse,
    summary="Buscar Cliente por RUT",
    description="Consulta un cliente por su RUT para autocompletar formularios en caja y ventas."
)
def buscar_cliente_por_rut(
    rut: str,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    """
    Búsqueda de cliente por RUT:
    1. Limpia el RUT de espacios.
    2. Realiza búsqueda exacta y normalizada (con/sin puntos).
    3. Si no existe, retorna 404 (manejado de forma silenciosa por el frontend).
    4. Si existe, retorna los datos de contacto y el nombre de su comuna.
    """
    rut_limpio = rut.strip()
    cliente = db.query(Cliente).filter(Cliente.rut_cliente == rut_limpio).first()

    if not cliente:
        # Probar sin puntos
        rut_sin_puntos = rut_limpio.replace(".", "")
        cliente = db.query(Cliente).filter(Cliente.rut_cliente == rut_sin_puntos).first()

    if not cliente:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Cliente con RUT '{rut}' no encontrado."
        )

    nombre_comuna = None
    if cliente.id_comuna:
        comuna_obj = db.query(Comuna).filter(Comuna.id_comuna == cliente.id_comuna).first()
        if comuna_obj:
            nombre_comuna = comuna_obj.nombre_comuna

    return ClienteDataResponse(
        id_cliente=cliente.id_cliente,
        rut_cliente=cliente.rut_cliente,
        nombres=cliente.nombres,
        apellidos=cliente.apellidos,
        telefono=cliente.telefono,
        correo=cliente.correo,
        id_comuna=cliente.id_comuna,
        comuna=nombre_comuna,
        consentimiento_legal=cliente.consentimiento_legal,
    )
