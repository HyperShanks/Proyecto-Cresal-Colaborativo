# Este archivo contiene los esquemas de Pydantic para la validación de datos de entrada y salida en la API.

from pydantic import BaseModel, Field, field_validator, ConfigDict
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

class RegisterUserRequest(BaseModel):
    """Payload de entrada para el registro de nuevos usuarios."""
    rut_usuario: str = Field(..., min_length=3, max_length=12, description="RUT chileno del usuario (ej: 12.345.678-9)")
    nombres: str = Field(..., min_length=1, max_length=100, description="Nombres del usuario")
    apellidos: str = Field(..., min_length=1, max_length=100, description="Apellidos del usuario")
    email: str = Field(..., description="Correo electrónico corporativo único")
    password: str = Field(..., min_length=4, description="Contraseña en texto plano a ser encriptada con bcrypt")
    id_rol: int = Field(..., description="ID del rol a asignar")
    id_sucursal: Optional[int] = Field(1, description="ID de la sucursal del usuario (default: 1)")
    pin_acceso: Optional[str] = Field(None, min_length=4, max_length=4, description="PIN numérico de 4 dígitos (opcional, auto-generado si no se provee)")

class RegisterUserResponse(BaseModel):
    """DTO de respuesta tras registrar exitosamente un usuario."""
    model_config = ConfigDict(from_attributes=True)

    id_usuario: UUID
    rut_usuario: str
    nombres: str
    apellidos: str
    email: str
    id_rol: int
    nombre_rol: Optional[str] = None
    id_sucursal: int
    pin_acceso: str
    estado: str
    mensaje: str

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


# ==========================================
# ESQUEMAS PARA ÓRDENES Y CHECKOUT (HU-3.4)
# ==========================================

class ClienteOrdenInput(BaseModel):
    """Datos de contacto y post-venta del cliente (Micro-CRM)."""
    rut_cliente: str = Field(..., description="RUT del cliente (ej. 12.345.678-9 o 12345678-9)")
    nombres: str = Field(..., min_length=1, description="Nombres del cliente")
    apellidos: str = Field(..., min_length=1, description="Apellidos del cliente")
    telefono: Optional[str] = Field(None, description="Teléfono de contacto")
    correo: Optional[str] = Field(None, description="Correo electrónico del cliente")
    comuna: Optional[str] = Field(None, description="Nombre de la comuna del cliente")
    consentimiento_legal: bool = Field(True, description="Aceptación de la Ley N° 21.719 de datos personales")


class DespachoInput(BaseModel):
    """Datos de logística y receptor de envío a domicilio."""
    direccion_envio: str = Field(..., min_length=3, description="Dirección completa de entrega")
    comuna_destino: Optional[str] = Field(None, description="Nombre de la comuna de destino")
    id_comuna_destino: Optional[int] = Field(None, description="ID numérico de la comuna de destino")
    receptor_rut: str = Field(..., description="RUT de quien recibe")
    receptor_nombres: str = Field(..., min_length=1, description="Nombres y apellidos de quien recibe")
    receptor_telefono: str = Field(..., description="Teléfono del receptor")
    empresa_transporte: Optional[str] = Field(None, description="Empresa de transporte (Starken, Chilexpress, etc.)")
    costo_envio: Optional[int] = Field(0, description="Costo de envío asociado")


class ItemOrdenInput(BaseModel):
    """Línea de producto en la orden (inventariado o misceláneo/venta libre)."""
    id_activo: Optional[UUID] = Field(None, description="UUID del repuesto inventariado (si aplica)")
    descripcion_manual: Optional[str] = Field(None, description="Descripción para ítems de venta libre/no inventariados")
    notas_preparacion: Optional[str] = Field(None, description="Notas técnicas de preparación dirigidas a bodega")
    cantidad: int = Field(1, ge=1, description="Cantidad de unidades")
    precio_unitario: Optional[int] = Field(None, description="Precio unitario de referencia")
    precio_final: int = Field(..., ge=0, description="Precio final acordado / a cobrar")


class OrdenCreateRequest(BaseModel):
    """Payload de creación de orden transaccional derivable a caja."""
    cliente: ClienteOrdenInput
    requiere_despacho: bool = Field(False, description="Indica si la orden requiere despacho a domicilio")
    despacho: Optional[DespachoInput] = Field(None, description="Datos de envío (obligatorio si requiere_despacho es True)")
    consentimiento_legal: bool = Field(True, description="Consentimiento expreso Ley 21.719")
    instrucciones_bodega: Optional[str] = Field(None, description="Instrucciones generales para bodega")
    items: List[ItemOrdenInput] = Field(..., min_length=1, description="Lista de ítems de la orden")
    id_sucursal: Optional[int] = Field(None, description="ID de la sucursal donde se genera la venta")


class OrdenResponse(BaseModel):
    """DTO de respuesta tras la creación exitosa de la orden."""
    model_config = ConfigDict(from_attributes=True)

    id_orden: UUID
    estado_orden: str
    total_venta: int
    monto_pendiente: int
    qr_transaccional_salida: Optional[str] = None
    mensaje: str
    fecha_creacion: Optional[str] = None
    total_items: int


# ==========================================
# ESQUEMAS PARA HISTORIAL Y MONITOREO DE ÓRDENES (HU-3.5)
# ==========================================

class ClienteOrdenResumen(BaseModel):
    """Resumen de datos del cliente para el historial de ventas."""
    model_config = ConfigDict(from_attributes=True)

    rut_cliente: str
    nombres: str
    apellidos: str
    telefono: Optional[str] = None
    correo: Optional[str] = None
    comuna: Optional[str] = None


class DespachoOrdenResumen(BaseModel):
    """Resumen de datos de despacho para el historial de ventas."""
    model_config = ConfigDict(from_attributes=True)

    id_despacho: UUID
    direccion_envio: str
    receptor_nombres: str
    receptor_rut: str
    receptor_telefono: str
    empresa_transporte: Optional[str] = None
    costo_envio: Optional[int] = 0
    estado_despacho: str
    comuna_destino: Optional[str] = None


class DetalleOrdenItemResponse(BaseModel):
    """DTO de detalle de línea de producto en el historial de órdenes."""
    model_config = ConfigDict(from_attributes=True)

    id_detalle: UUID
    id_activo: Optional[UUID] = None
    titulo: str
    sku_qr_fisico: Optional[str] = None
    descripcion_manual: Optional[str] = None
    notas_preparacion: Optional[str] = None
    cantidad: int
    precio_unitario: Optional[int] = None
    precio_final: int
    subtotal: int
    es_inventariado: bool


class OrdenHistorialItemResponse(BaseModel):
    """DTO completo de orden de venta para el historial y monitoreo del vendedor."""
    model_config = ConfigDict(from_attributes=True)

    id_orden: UUID
    estado_orden: str
    total_venta: int
    monto_pendiente: int
    qr_transaccional_salida: Optional[str] = None
    fecha_creacion: Optional[str] = None
    fecha_actualizacion: Optional[str] = None
    total_items: int
    cliente: Optional[ClienteOrdenResumen] = None
    despacho: Optional[DespachoOrdenResumen] = None
    detalles: List[DetalleOrdenItemResponse] = []


class OrdenAnulacionResponse(BaseModel):
    """DTO de respuesta tras anular una orden y liberar stock."""
    model_config = ConfigDict(from_attributes=True)

    id_orden: UUID
    estado_orden: str
    mensaje: str
    activos_liberados: int


class InstruccionesUpdateRequest(BaseModel):
    """Payload para actualizar notas técnicas o instrucciones a bodega."""
    notas_preparacion: str = Field(..., min_length=1, description="Texto de notas técnicas de preparación para bodega")
    id_detalle: Optional[UUID] = Field(None, description="ID del detalle específico si solo se actualiza una línea")


class InstruccionesUpdateResponse(BaseModel):
    """DTO de respuesta tras actualizar instrucciones de preparación."""
    model_config = ConfigDict(from_attributes=True)

    id_orden: UUID
    mensaje: str
    notas_preparacion: str
    detalles_actualizados: int


# ==========================================
# ESQUEMAS PARA JEFE DE VENTAS Y ASIGNACIÓN DE PRECIOS (HU-3.8)
# ==========================================

class ActivoPendientePrecioResponse(BaseModel):
    """DTO para la bandeja de entrada de activos sin precio asignado."""
    model_config = ConfigDict(from_attributes=True)

    id_activo: UUID
    sku_qr_fisico: str
    id_categoria: int
    nombre_categoria: str
    id_sucursal_actual: int
    nombre_sucursal: str
    ubicacion_pasillo: Optional[str] = None
    ubicacion_pallet: Optional[str] = None
    id_vehiculo: Optional[UUID] = None
    numero_ingreso: Optional[str] = None
    marca: Optional[str] = None
    modelo: Optional[str] = None
    anio: Optional[int] = None
    traccion: Optional[str] = None
    cilindrada: Optional[str] = None
    combustible: Optional[str] = None
    transmision_tipo: Optional[str] = None
    titulo_repuesto: str
    estado_activo: str
    fecha_creacion: Optional[str] = None


class AsignarPrecioRequest(BaseModel):
    """Payload para fijar o actualizar el precio de referencia de un activo."""
    precio_referencia: int = Field(..., gt=0, description="Precio de referencia en pesos chilenos (debe ser mayor a 0)")


class AsignarPrecioResponse(BaseModel):
    """DTO de respuesta tras asignar exitosamente el precio."""
    model_config = ConfigDict(from_attributes=True)

    id_activo: UUID
    sku_qr_fisico: str
    precio_referencia: int
    estado_activo: str
    mensaje: str





