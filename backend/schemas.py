# Este archivo contiene los esquemas de Pydantic para la validación de datos de entrada y salida en la API.

from pydantic import BaseModel, Field, field_validator
from typing import Optional, List
from uuid import UUID
import re

# ==========================================
# ESQUEMAS PARA VEHÍCULOS (HU-2.2 Ingesta)
# ==========================================

class VehiculoResponse(BaseModel):
    id_vehiculo: UUID
    numero_ingreso: str # Añadido: Vital para que el operario lo anote físicamente
    patente: Optional[str] = None # Opcional, según lo dicta tu DBML
    marca: str
    modelo: str
    anio: int
    traccion: Optional[str] = None

    class Config:
        from_attributes = True

class PatenteInput(BaseModel):
    patente: str = Field(..., description="Patente del vehículo chileno (6 caracteres alfanuméricos)")

    @field_validator('patente')
    def validar_formato_patente(cls, v):
        # Limpiar espacios y pasar a mayúsculas por si el usuario lo escribe mal
        patente_limpia = v.strip().upper()

        # Validar que tenga exactamente 6 caracteres y sea alfanumérica
        if len(patente_limpia) != 6:
            raise ValueError("La patente debe tener exactamente 6 caracteres")
        if not re.match(r"^[A-Z0-9]{6}$", patente_limpia):
            raise ValueError("La patente solo debe contener letras mayúsculas y números")

        return patente_limpia

class VehiculoCreate(BaseModel):
    # Datos del Vehículo (Autocompletados por scraper o copiados del padrón)
    patente: str = Field(..., description="Patente validada del vehículo")
    marca: str
    modelo: str
    anio: int
    traccion: str = Field(..., description="Ej: 4x2, 4x4")

    # Datos que FastAPI usará para crear el Detalle_Motor internamente
    cilindrada: str = Field(..., description="Ej: 1.4")
    numero_motor: str = Field(..., description="Número de serie del motor (ej: 10FDCG0803508)")
    combustible: str = Field(..., description="Ej: diesel, gasolina")

    # Datos que FastAPI usará para crear el Detalle_Caja_Cambio internamente
    transmision: str = Field(..., description="Ej: mec, at")

# ==========================================
# ESQUEMAS PARA AUTENTICACIÓN (HU-2.1 LOGIN-PIN)
# ==========================================

class LoginPINRequest(BaseModel):
    """Payload de entrada para el login por PIN de operario."""
    pin: str

class RolData(BaseModel):
    """DTO para la información de un rol."""
    id_rol: int
    nombre_rol: str

    class Config:
        from_attributes = True

class UsuarioData(BaseModel):
    """DTO de salida con los datos públicos del usuario autenticado."""
    id_usuario: UUID
    nombres: str
    apellidos: str
    rut_usuario: str
    id_rol: int
    nombre_rol: Optional[str] = None
    id_sucursal: int
    rol: Optional[RolData] = None

    class Config:
        from_attributes = True  # Permite lectura directa desde el modelo SQLAlchemy

class TokenResponse(BaseModel):
    """Respuesta completa del endpoint de login exitoso."""
    access_token: str
    token_type: str = "bearer"
    usuario: UsuarioData

# ==========================================
# ESQUEMAS PARA TICKETS DE SOPORTE (HU-2.7)
# ==========================================

class TicketCreate(BaseModel):
    """
    Payload de entrada para crear un ticket de soporte.
    El id_usuario_creador NO se incluye aquí: se inyecta automáticamente
    desde el JWT del operario autenticado en el endpoint.
    """
    tipo_ticket: str = Field(
        ...,
        description="Categoría del ticket: 'Bug', 'Consulta', 'Incidencia', etc.",
        max_length=50,
    )
    prioridad: str = Field(
        "Media",
        description="Nivel de urgencia: 'Baja', 'Media', 'Alta', 'Crítica'",
        max_length=20,
    )
    asunto: str = Field(
        ...,
        description="Título corto y descriptivo del problema",
        max_length=150,
    )
    descripcion: str = Field(
        ...,
        description="Detalle completo del problema o solicitud",
        max_length=1000,
    )
    tabla_referencia: Optional[str] = Field(
        None,
        description="Nombre de la tabla relacionada (ej: 'Vehiculo_Origen')",
        max_length=50,
    )
    id_referencia: Optional[UUID] = Field(
        None,
        description="UUID del registro relacionado en tabla_referencia",
    )


class TicketResponse(BaseModel):
    """
    DTO de salida con todos los campos del ticket.
    Refleja 1:1 la tabla Ticket_Soporte de la base de datos.
    """
    id_ticket: UUID
    tipo_ticket: str
    prioridad: str
    asunto: str
    descripcion: str
    id_usuario_creador: UUID
    id_usuario_resolutor: Optional[UUID] = None
    tabla_referencia: Optional[str] = None
    id_referencia: Optional[UUID] = None
    estado_ticket: str
    observacion_cierre: Optional[str] = None
    fecha_creacion: Optional[str] = None  # Serializado como ISO string para compatibilidad Flutter
    fecha_cierre: Optional[str] = None

    class Config:
        from_attributes = True  # Permite lectura directa desde el modelo SQLAlchemy
class VehiculoInventarioResponse(BaseModel):
    """Esquema de respuesta para buscar un vehículo por su folio (HU-2.3)"""
    id_vehiculo: UUID
    numero_ingreso: str
    patente: Optional[str] = None
    marca: str
    modelo: str
    anio: int
    traccion: Optional[str] = None
    # Aquí podríamos agregar más campos técnicos (motor, caja) a medida que los necesitemos
    
    class Config:
        from_attributes = True


# ==========================================
# ESQUEMAS PARA CATÁLOGO Y RADAR (HU-3.2)
# ==========================================

class CatalogoItemResponse(BaseModel):
    """DTO de salida para un elemento individual del catálogo de inventario."""
    id_activo: UUID
    sku_qr_fisico: str
    precio_referencia: Optional[int] = None
    
    # Categoría y Sucursal
    id_categoria: int
    nombre_categoria: str
    id_sucursal_actual: int
    nombre_sucursal: str
    
    # Datos del Vehículo de Origen (opcional si es repuesto sin vehículo directo)
    id_vehiculo: Optional[UUID] = None
    marca: Optional[str] = None
    modelo: Optional[str] = None
    anio: Optional[int] = None
    traccion: Optional[str] = None
    
    # Especificaciones Técnicas (Motor / Caja)
    cilindrada: Optional[str] = None
    combustible: Optional[str] = None
    transmision_tipo: Optional[str] = None
    
    # Ubicación y estado
    ubicacion_pasillo: Optional[str] = None
    ubicacion_pallet: Optional[str] = None
    estado_activo: Optional[str] = None

    class Config:
        from_attributes = True


class PaginatedCatalogoResponse(BaseModel):
    """DTO de respuesta paginada para el catálogo de activos con Radar de Stock."""
    items: List[CatalogoItemResponse]
    total_count: int
    limit: int
    offset: int

