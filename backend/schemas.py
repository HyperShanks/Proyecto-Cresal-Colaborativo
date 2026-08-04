# Este archivo contiene los esquemas de Pydantic para la validación de datos de entrada y salida en la API.

from pydantic import BaseModel, Field, field_validator
from typing import Optional
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

class UsuarioData(BaseModel):
    """DTO de salida con los datos públicos del usuario autenticado."""
    id_usuario: UUID
    nombres: str
    apellidos: str
    rut_usuario: str
    id_rol: int
    id_sucursal: int

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
# ESQUEMAS PARA PALETIZADO Y QR (HU-2.4)
# ==========================================

class PaletizadoResponse(BaseModel):
    """
    DTO de respuesta enriquecido del endpoint POST /guardar-paletizado.

    Incluye el SKU/QR del activo recién guardado y todos los datos necesarios
    para que Flutter renderice el widget EtiquetaTermicaWidget sin requerir
    una segunda llamada a la API.

    Campos del vehículo origen
    --------------------------
    numero_ingreso : N° correlativo del vehículo (se imprime en grande en la etiqueta).
    marca, modelo, anio : Datos básicos del vehículo origen.

    Campos técnicos (pueden ser None si el activo no tiene Detalle_Motor)
    ----------------------------------------------------------------------
    cilindrada, combustible, transmision, numero_motor : Detalles técnicos.
    Se serializan como None y Flutter los muestra como "N/A".

    Campos de identidad digital
    ---------------------------
    sku_qr_fisico : El código SKU generado (ej. "MOT-8A2F"). Es el contenido del QR.
    qr_impreso    : Siempre False al momento del guardado inicial.

    Campos de ubicación
    -------------------
    galpon, pasillo, pallet : Ubicación física del activo en el almacén.

    Campos de respaldo (igual que la respuesta anterior para no romper integraciones)
    ----------------------------------------------------------------------------------
    status, mensaje, urls_fotos : Compatibilidad con la respuesta anterior.
    """
    # ── Identidad digital (HU-2.4) ──────────────────────────────────────────
    sku_qr_fisico: str
    qr_impreso: bool = False

    # ── Datos del vehículo origen ────────────────────────────────────────────
    numero_ingreso: str
    marca: str
    modelo: str
    anio: int

    # ── Detalles técnicos del activo (opcionales, None → "N/A" en Flutter) ──
    cilindrada: Optional[str] = None
    combustible: Optional[str] = None
    transmision: Optional[str] = None
    numero_motor: Optional[str] = None

    # ── Ubicación física en el almacén ───────────────────────────────────────
    galpon: str
    pasillo: str
    pallet: str

    # ── Compatibilidad con respuesta anterior (no rompe integraciones) ────────
    status: str = "success"
    mensaje: str = ""
    urls_fotos: list = []
