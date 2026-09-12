import os
from pydantic import BaseModel, Field, field_validator, ConfigDict
from typing import Optional, List
from uuid import UUID
from datetime import datetime
from enum import Enum
import re

# Configuro __path__ dinámico para permitir importar submódulos desde el directorio schemas/
__path__ = [os.path.join(os.path.dirname(__file__), "schemas")]

from core.utils.validators import validar_rut_modulo11


# ==========================================
# ESQUEMA BASE TRANSVERSAL PARA RUT (HU-12)
# ==========================================

class BaseRutSchema(BaseModel):
    """
    Esquema base que aplica validación matemática Módulo 11
    a cualquier campo de RUT estándar (rut_cliente, receptor_rut, rut_usuario).
    """
    model_config = ConfigDict(from_attributes=True)

    @field_validator(
        'rut_cliente', 'receptor_rut', 'rut_usuario',
        mode='before', check_fields=False
    )
    def normalizar_y_validar_rut(cls, v: str) -> str:
        if not v:
            return v
        es_valido, rut_limpio = validar_rut_modulo11(v)
        if not es_valido:
            raise ValueError(
                "El RUT ingresado no es matemáticamente válido "
                "(falla en dígito verificador)."
            )
        return rut_limpio


class ClienteCreateRequest(BaseRutSchema):
    """Payload para registro de nuevo cliente en Micro-CRM (HU-12)."""
    rut_cliente: str = Field(..., description="RUT chileno del cliente")
    nombres: str = Field(..., min_length=1, description="Nombres del cliente")
    apellidos: str = Field(
        ..., min_length=1, description="Apellidos del cliente"
    )
    telefono: Optional[str] = Field(None, description="Teléfono de contacto")
    correo: Optional[str] = Field(None, description="Correo electrónico")
    id_comuna: Optional[int] = Field(None, description="ID de la comuna")
    comuna: Optional[str] = Field(None, description="Nombre de la comuna")
    consentimiento_legal: bool = Field(
        True, description="Aceptación Ley N° 21.719"
    )


# ==========================================
# ESQUEMAS PARA VEHÍCULOS (HU-2.2 Ingesta)
# ==========================================

class VehiculoResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id_vehiculo: UUID
    numero_ingreso: str # Añadido: Vital para que el operario lo anote físicamente
    patente: Optional[str] = None # Opcional, según lo dicta tu DBML
    marca: str
    modelo: str
    anio: int
    traccion: Optional[str] = None

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
    correlativo_ingreso: Optional[str] = None
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
# ESQUEMAS PARA PALETIZADO / IMPRESIÓN (HU-2.4)
# ==========================================

class ActualizarQrImpresoRequest(BaseModel):
    """Payload para marcar un activo inventariado como impreso en la BD."""
    qr_impreso: bool = True

# ==========================================
# ESQUEMAS PARA AUTENTICACIÓN (HU-2.1 LOGIN-PIN & HU-01 CAJA)
# ==========================================

class LoginPINRequest(BaseModel):
    """Payload de entrada para el login por PIN de operario vinculado."""
    model_config = ConfigDict(from_attributes=True)

    pin_acceso: str
    id_usuario: str  # ID del usuario previamente enrolado en el terminal

    @property
    def pin_valor(self) -> str:
        return self.pin_acceso


LoginPinRequest = LoginPINRequest


class LoginEmailRequest(BaseModel):
    """Payload de entrada para el login por email y contraseña."""
    email: str
    password: str



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
    model_config = ConfigDict(from_attributes=True)

    id_rol: int
    nombre_rol: str


class SucursalData(BaseModel):
    """DTO para la información de una sucursal."""
    model_config = ConfigDict(from_attributes=True)

    id_sucursal: int
    nombre_sucursal: str


class UsuarioData(BaseModel):
    """DTO de salida con los datos públicos del usuario autenticado."""
    model_config = ConfigDict(from_attributes=True)

    id_usuario: UUID
    nombres: str
    apellidos: str
    rut_usuario: str
    email: Optional[str] = None
    id_rol: int
    nombre_rol: Optional[str] = None
    id_sucursal: int
    nombre_sucursal: Optional[str] = None
    rol: Optional[RolData] = None
    sucursal: Optional[SucursalData] = None


class AuthUserData(BaseModel):
    """DTO de claims y datos del usuario de sesión."""
    model_config = ConfigDict(from_attributes=True)

    id_usuario: UUID
    rut_usuario: str
    nombres: str
    apellidos: str
    email: Optional[str] = None
    id_rol: int
    nombre_rol: Optional[str] = None
    id_sucursal: int
    nombre_sucursal: Optional[str] = None


class TokenResponse(BaseModel):
    """Respuesta completa del endpoint de login exitoso."""
    model_config = ConfigDict(from_attributes=True)

    access_token: str
    token_type: str = "bearer"
    usuario: UsuarioData

LoginResponse = TokenResponse


class CajaVerificarAccesoResponse(BaseModel):
    """Respuesta de verificación RBAC para el módulo de caja."""
    autorizado: bool = True
    rol: str
    id_sucursal: int


# ==========================================
# ESQUEMAS PARA BANDEJA DE COBROS DE CAJA (SPEC-HU-4.2)
# ==========================================

class BackorderEspecificacionesDTO(BaseModel):
    marca: str
    modelo: str
    anio: Optional[int] = None
    categoria: str
    cilindrada: Optional[str] = None
    combustible: Optional[str] = None
    transito: Optional[str] = "En Tránsito Marítimo / Bodega"

    model_config = ConfigDict(from_attributes=True)


class ArticuloResumenDTO(BaseModel):
    cantidad: int
    tipo: str  # 'INVENTARIADO' | 'MISCELANEO' | 'DESARME' | 'RESERVA'
    descripcion: str
    sku: Optional[str] = None
    precio: int
    subtotal: int
    categoria: Optional[str] = None
    marca: Optional[str] = None
    modelo: Optional[str] = None
    anio: Optional[int] = None
    detalle_tecnico: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class CobroPendienteItemResponse(BaseModel):
    id_referencia: UUID = Field(description="id_orden o id_reserva según la entidad de origen")
    folio_documento: str = Field(description="Ej: ORD-9780 o RES-5401")
    tipo_operacion: str = Field(description="'VENTA' para Orden_Venta, 'BACKORDER' para Reservas_Backorder")
    estado_documento: str = Field(description="'Reservada', 'Pendiente', etc.")

    # Datos del Cliente
    cliente_nombre: str
    cliente_rut: str

    # Datos del Vendedor Originador
    vendedor_nombre: str

    # Temporalidad
    fecha_emision: datetime
    fecha_emision_formateada: str  # dd/MM/yyyy
    hora_emision_formateada: str   # HH:mm

    # Datos Financieros
    total_operacion: int = Field(description="Total venta o precio acordado de reserva")
    abono_previo: int = Field(default=0, description="Monto ya pagado previamente")
    monto_a_cobrar: int = Field(description="Saldo pendiente o abono fijado requerido")

    # Detalles complementarios
    articulos: List[ArticuloResumenDTO] = Field(default_factory=list)
    especificaciones_backorder: Optional[BackorderEspecificacionesDTO] = None

    model_config = ConfigDict(from_attributes=True)


class CobroPendienteListResponse(BaseModel):
    total: int
    sucursal_id: int
    items: List[CobroPendienteItemResponse]

    model_config = ConfigDict(from_attributes=True)


# ==========================================
# ESQUEMAS PARA REGISTRO DE COBROS Y SPLIT PAYMENT (SPEC-HU-03)
# ==========================================

class TipoOperacionEnum(str, Enum):
    ORDEN = "ORDEN"
    BACKORDER = "BACKORDER"


class ModalidadCobroEnum(str, Enum):
    LIQUIDACION = "LIQUIDACION"
    ABONO = "ABONO"


class MetodoPagoEnum(str, Enum):
    EFECTIVO = "Efectivo"
    DEBITO = "Debito"
    CREDITO = "Credito"
    TRANSFERENCIA = "Transferencia"
    CHEQUE = "Cheque"


class TransaccionPagoItemSchema(BaseModel):
    metodo: MetodoPagoEnum
    monto: int = Field(gt=0, description="El monto por método debe ser mayor a 0 y sin decimales")


class RegistrarCobroRequest(BaseModel):
    tipo_operacion: TipoOperacionEnum
    id_documento: UUID
    modalidad: ModalidadCobroEnum
    monto_declarado: int = Field(gt=0, description="Monto total acordado a pagar")
    pagos: List[TransaccionPagoItemSchema] = Field(min_length=1)


class RegistrarCobroResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    success: bool
    mensaje: str
    folio: str
    monto_cobrado: int
    nuevo_saldo_pendiente: int
    estado_actualizado: str
    transacciones_ids: List[UUID]
    qr_generado: Optional[str] = None



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
        min_length=5,
        max_length=150,
    )
    descripcion: str = Field(
        ...,
        description="Detalle completo del problema o solicitud",
        min_length=10,
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

    model_config = ConfigDict(from_attributes=True)


class VehiculoInventarioResponse(BaseModel):
    """Esquema de respuesta para buscar un vehículo por su folio (HU-2.3)"""
    model_config = ConfigDict(from_attributes=True)

    id_vehiculo: UUID
    numero_ingreso: str
    patente: Optional[str] = None
    marca: str
    modelo: str
    anio: int
    traccion: Optional[str] = None
    # Aquí podríamos agregar más campos técnicos (motor, caja) a medida que los necesitemos


# ==========================================
# ESQUEMAS PARA CATÁLOGO Y RADAR (HU-3.2)
# ==========================================

class CatalogoItemResponse(BaseModel):
    """DTO de salida para un elemento individual del catálogo de inventario."""
    model_config = ConfigDict(from_attributes=True)

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
    ubicacion_galpon: Optional[str] = None
    ubicacion_pallet: Optional[str] = None
    observacion_estado: Optional[str] = None
    numero_motor: Optional[str] = None
    id_estado: Optional[int] = None
    estado_activo: Optional[str] = None
    version_lock: int = 1
    reservado_por: Optional[UUID] = None
    qr_impreso: bool = False
    imagenes: List[str] = []


class PaginatedCatalogoResponse(BaseModel):
    """DTO de respuesta paginada para el catálogo de activos con Radar de Stock."""
    items: List[CatalogoItemResponse]
    total_count: int
    limit: int
    offset: int
    pendientes_tasacion_count: Optional[int] = 0


# ==========================================
# ESQUEMAS PARA RESERVA TEMPORAL DE CARRITO (SPEC-HU-TAREA-3)
# ==========================================

class ReservaCarritoRequest(BaseModel):
    """Solicitud de bloqueo / reserva temporal de un activo único en el carrito."""
    model_config = ConfigDict(from_attributes=True)
    id_activo: UUID
    version_lock_esperado: int


class ReservaCarritoResponse(BaseModel):
    """Respuesta exitosa de reserva temporal."""
    model_config = ConfigDict(from_attributes=True)
    id_activo: UUID
    version_lock: int
    reservado_por: UUID
    reserva_expira_en: datetime
    mensaje: str


class LiberarCarritoResponse(BaseModel):
    """Respuesta al liberar voluntariamente una reserva temporal."""
    id_activo: UUID
    version_lock: int
    mensaje: str


class HeartbeatCarritoResponse(BaseModel):
    """Respuesta al refrescar la caducidad de reservas por actividad (Heartbeat)."""
    mensaje: str
    activos_renovados: int
    nueva_expiracion: datetime


class MisReservasItemResponse(BaseModel):
    """Resumen de un ítem reservado actualmente por el usuario."""
    model_config = ConfigDict(from_attributes=True)
    id_activo: UUID
    sku_qr_fisico: str
    version_lock: int
    reserva_expira_en: datetime
    segundos_restantes: int


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
    """Datos de logística y receptor de envío a domicilio o traslado."""
    direccion_envio: str = Field(..., min_length=3, description="Dirección completa de entrega")
    comuna_destino: Optional[str] = Field(None, description="Nombre de la comuna de destino")
    id_comuna_destino: Optional[int] = Field(None, description="ID numérico de la comuna de destino")
    receptor_rut: str = Field(..., description="RUT de quien recibe")
    receptor_nombres: str = Field(..., min_length=1, description="Nombres y apellidos de quien recibe")
    receptor_telefono: str = Field(..., description="Teléfono del receptor")
    empresa_transporte: Optional[str] = Field(None, description="Empresa de transporte (Starken, Chilexpress, etc.)")
    costo_envio: Optional[int] = Field(0, description="Costo de envío asociado")
    tipo_entrega: Optional[str] = Field("Despacho", description="Tipo de entrega: 'Despacho', 'Traslado', 'Retiro'")
    id_sucursal_destino: Optional[int] = Field(None, description="ID de la sucursal de destino si es Traslado (1: Viña, 2: Limache)")


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
    tipo_entrega: Optional[str] = Field("Retiro", description="Tipo de entrega: 'Retiro', 'Despacho', 'Traslado'")
    id_sucursal_destino: Optional[int] = Field(None, description="ID de sucursal destino si aplica traslado (1: Viña, 2: Limache)")
    monto_abono: Optional[int] = Field(None, ge=0, description="Monto abonado al registrar la venta (opcional para abonos parciales)")
    id_vendedor_asignado: Optional[UUID] = Field(None, description="ID del vendedor asignado para entregar/despachar la orden (None = Mesón General)")


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
# ESQUEMAS PARA CONFIRMACIÓN DE PAGO Y HANDSHAKE QR (HU-3.6)
# ==========================================

class OrdenPagoRequest(BaseModel):
    """Payload para registrar la confirmación de pago de una orden en caja."""
    metodo_pago: str = Field("Efectivo", description="Método de pago: Efectivo, Débito, Crédito, Transferencia")
    monto: Optional[int] = Field(None, ge=1, description="Monto abonado (opcional, por defecto liquida el total pendiente)")
    observaciones: Optional[str] = Field(None, description="Notas de caja o número de comprobante/voucher")


class OrdenPagoResponse(BaseModel):
    """DTO de respuesta tras confirmar el pago de la orden y generar el QR transaccional de salida."""
    model_config = ConfigDict(from_attributes=True)

    id_orden: UUID
    id_pago: UUID
    estado_orden: str
    total_venta: int
    monto_pagado: int
    monto_pendiente: int
    metodo_pago: str
    qr_transaccional_salida: Optional[str] = None
    id_cajera: UUID
    mensaje: str
    fecha_pago: str


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
    preparacion_lista: Optional[bool] = False
    estado_preparacion: Optional[str] = "Pendiente"


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


class EntregaEnvioItemResponse(BaseModel):
    """DTO para la vista colaborativa de Entregas en Tienda y Despachos Externos."""
    model_config = ConfigDict(from_attributes=True)

    id_orden: UUID
    folio: str
    tipo_entrega: str
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
    vendedor_nombre: Optional[str] = None
    id_vendedor_asignado: Optional[UUID] = None
    vendedor_asignado_nombre: Optional[str] = None
    preparacion_lista: bool = False
    todos_preparados: bool = False


class VendedorResumenResponse(BaseModel):
    """DTO para listar vendedores de una sucursal para asignación de entrega."""
    model_config = ConfigDict(from_attributes=True)

    id_usuario: UUID
    nombre_completo: str
    rut: str
    id_sucursal: int
    correo: Optional[str] = None


class EntregaConfirmacionResponse(BaseModel):
    """DTO de respuesta tras confirmar la entrega de un pedido en tienda."""
    model_config = ConfigDict(from_attributes=True)

    id_orden: UUID
    folio: str
    estado_orden: str
    mensaje: str
    activos_finalizados: int
    fecha_entrega: str


class DespachoEnvioResponse(BaseModel):
    """DTO de respuesta tras marcar un despacho como enviado."""
    model_config = ConfigDict(from_attributes=True)

    id_despacho: UUID
    id_orden: UUID
    folio: str
    estado_despacho: str
    estado_orden: str
    mensaje: str
    activos_finalizados: int
    fecha_envio: str


class OrdenAnulacionResponse(BaseModel):
    """DTO de respuesta tras anular una orden y liberar stock / generar tareas de reingreso."""
    model_config = ConfigDict(from_attributes=True)

    id_orden: UUID
    estado_orden: str
    mensaje: str
    msg: Optional[str] = None
    activos_liberados: int = 0
    pagos_reversados: int = 0
    motivo_anulacion: Optional[str] = None


class AnularOrdenRequest(BaseModel):
    """Payload para anular una orden desde el mesón de ventas."""
    model_config = ConfigDict(from_attributes=True)
    motivo_anulacion: Optional[str] = None


class ConfirmarReingresoRequest(BaseModel):
    """Payload para confirmar reingreso y paletizado de pieza por PDA."""
    model_config = ConfigDict(from_attributes=True)
    sku_qr_fisico: str
    id_orden_anulada: UUID
    ubicacion_pallet: Optional[str] = None
    ubicacion_pasillo: Optional[str] = None


class TareaReingresoDTO(BaseModel):
    """DTO para listar tareas de reingreso / paletizado en PDA Bodega."""
    model_config = ConfigDict(from_attributes=True)
    id_orden: UUID
    id_activo: UUID
    sku_qr_fisico: str
    ubicacion_pallet: Optional[str] = None
    ubicacion_pasillo: Optional[str] = None
    descripcion_pieza: str
    folio_orden: Optional[str] = None
    motivo_anulacion: Optional[str] = None


class ConfirmarReingresoResponse(BaseModel):
    """Respuesta tras confirmar reingreso de activo inventariado."""
    model_config = ConfigDict(from_attributes=True)
    msg: str
    id_activo: Optional[UUID] = None
    sku_qr_fisico: Optional[str] = None
    nuevo_estado: Optional[str] = None
    ubicacion_pasillo: Optional[str] = None
    ubicacion_pallet: Optional[str] = None


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
    fotografias: List[str] = Field(default_factory=list, description="URLs de fotografías registradas del activo")


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


# ==========================================
# ESQUEMAS PARA EDICIÓN DE ACTIVOS EN BODEGA PDA (HU-11)
# ==========================================

class EditarActivoRequest(BaseModel):
    """Payload para editar ubicación técnica y notas de un activo en bodega PDA."""
    model_config = ConfigDict(from_attributes=True)

    ubicacion_pasillo: Optional[str] = None
    ubicacion_galpon: Optional[str] = None
    ubicacion_pallet: Optional[str] = None
    observacion_estado: Optional[str] = None
    numero_motor: Optional[str] = None
    cilindrada: Optional[str] = None
    version_lock_esperado: int


class EditarActivoResponse(BaseModel):
    """DTO de respuesta tras edición técnica exitosa con nuevo version_lock."""
    model_config = ConfigDict(from_attributes=True)

    id_activo: UUID
    sku_qr_fisico: str
    ubicacion_pasillo: Optional[str] = None
    ubicacion_galpon: Optional[str] = None
    ubicacion_pallet: Optional[str] = None
    observacion_estado: Optional[str] = None
    numero_motor: Optional[str] = None
    cilindrada: Optional[str] = None
    version_lock: int
    mensaje: str = "Activo actualizado exitosamente."


# ==========================================
# ESQUEMAS PARA BODEGA: HANDSHAKE DE SALIDA Y DUAL-SCAN (HU-3.6)
# ==========================================

class ItemSalidaInfo(BaseModel):
    """Información de cada ítem de la orden para verificación previa de salida."""
    model_config = ConfigDict(from_attributes=True)

    id_detalle: UUID
    id_activo: Optional[UUID] = None
    titulo: str
    sku_qr_fisico: Optional[str] = None
    es_inventariado: bool
    ubicacion: str
    notas_preparacion: Optional[str] = None
    cantidad: int
    precio_final: int


class VerificarQrSalidaRequest(BaseModel):
    """Payload para inspeccionar una orden mediante el QR Digital del Vendedor."""
    qr_transaccional_salida: str = Field(..., description="Token digital del vendedor (TX-QR-...)")


class VerificarQrSalidaResponse(BaseModel):
    """DTO con el detalle completo de la orden para guiar al bodeguero en el despacho."""
    model_config = ConfigDict(from_attributes=True)

    id_orden: UUID
    folio: str
    estado_orden: str
    total_venta: int
    monto_pendiente: int
    id_sucursal: int
    cliente_nombre: str
    cliente_rut: str
    cliente_telefono: Optional[str] = None
    items_requeridos: List[ItemSalidaInfo]
    total_items_fisicos: int
    qr_transaccional_salida: str


class EscanearSalidaRequest(BaseModel):
    """Payload para validar el Dual-Scan y completar la entrega en barrera."""
    qr_transaccional_salida: str = Field(..., description="Token digital del vendedor (TX-QR-...)")
    skus_escaneados: List[str] = Field(default_factory=list, description="Lista de SKUs escaneados de las piezas físicas")
    observaciones_entrega: Optional[str] = Field(None, description="Observaciones opcionales del bodeguero al entregar")


class EscanearSalidaResponse(BaseModel):
    """DTO de confirmación inmediata (Cero-Clics) tras la entrega en barrera."""
    model_config = ConfigDict(from_attributes=True)

    id_orden: UUID
    folio: str
    estado_orden: str
    id_bodeguero: UUID
    bodeguero_nombre: str
    fecha_entrega: str
    activos_entregados: List[str]
    total_entregados: int
    mensaje: str


# ==========================================
# ESQUEMAS PARA BODEGA Y PRE-ENTREGA (HU-BODEGA)
# ==========================================

class TareaAlertaResponse(BaseModel):
    """DTO para tareas operativas en el tablero de bodega."""
    id_tarea: str
    tipo_alerta: str
    orden_ref: Optional[str] = None
    titulo_pieza: str
    ubicacion: str
    nota_especial: Optional[str] = None
    estado_bloqueo: Optional[str] = None
    accion_requerida: str
    etiqueta_data: Optional[dict] = None
    id_detalle: Optional[UUID] = None
    id_activo: Optional[UUID] = None
    id_sucursal_origen: Optional[int] = None
    id_sucursal_destino: Optional[int] = None
    es_traslado: bool = False
    estado_preparacion: Optional[str] = "Pendiente"
    categoria: Optional[str] = None
    tipo_repuesto: Optional[str] = None
    id_orden: Optional[UUID] = None
    sku_qr_fisico: Optional[str] = None
    motivo_anulacion: Optional[str] = None
    ubicacion_pasillo: Optional[str] = None
    ubicacion_pallet: Optional[str] = None
    ubicacion_galpon: Optional[str] = None


class CompletarPreentregaResponse(BaseModel):
    """DTO de respuesta al marcar una pre-entrega como 'Listo'."""
    model_config = ConfigDict(from_attributes=True)

    id_detalle: UUID
    id_orden: UUID
    id_activo: Optional[UUID] = None
    preparacion_lista: bool
    estado_preparacion: str
    mensaje: str
    fecha_preparacion: Optional[str] = None


# ==========================================
# ESQUEMAS PARA HISTORIAL Y AUDITORÍA DE CAJA (SPEC-HU-4.5 / CRES-217)
# ==========================================

class HistorialPagoDetalleDTO(BaseModel):
    id_transaccion: Optional[UUID] = None
    metodo_pago: str = Field(description="Efectivo, Débito, Crédito, Transferencia o Cheque")
    monto: int = Field(description="Monto cubierto o ajustado por este método específico")
    fecha_pago: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class HistorialArticuloDTO(BaseModel):
    cantidad: int
    tipo: str = Field(description="'INVENTARIADO' o 'DESARME'")
    descripcion: str
    sku: Optional[str] = None
    precio: int
    subtotal: int
    categoria: Optional[str] = None
    marca: Optional[str] = None
    modelo: Optional[str] = None
    anio: Optional[int] = None
    detalle_tecnico: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class HistorialMovimientoDTO(BaseModel):
    hora: str = Field(description="Hora del evento (HH:mm)")
    evento: str = Field(description="Descripción del hito de auditoría")

    model_config = ConfigDict(from_attributes=True)


class ResumenCuadreCajaDTO(BaseModel):
    total_recaudado: int = Field(default=0, description="Suma total de pagos en el rango y filtros aplicados")
    total_ordenes_pagadas: int = Field(default=0, description="Cantidad total de órdenes en estado Pagada/Despachada")
    total_efectivo: int = Field(default=0, description="Arqueo físico de gaveta (Billetes y monedas)")
    total_pos: int = Field(default=0, description="Total tarjetas voucher Transbank (Débito + Crédito)")
    total_debito: int = Field(default=0)
    total_credito: int = Field(default=0)
    total_transferencia: int = Field(default=0)
    total_cheque: int = Field(default=0)

    model_config = ConfigDict(from_attributes=True)


class HistorialOrdenItemResponse(BaseModel):
    id_orden: UUID
    folio: str = Field(description="Ej: ORD-9778 o RES-5401")
    tipo_operacion: str = Field(description="'VENTA' o 'BACKORDER'")
    emite_qr: bool = Field(description="True si la orden liquida el 100% de la venta para barrera")
    fecha_iso: str = Field(description="YYYY-MM-DD en hora local America/Santiago")
    hora: str = Field(description="HH:mm en hora local")
    fecha_hora_formateada: str = Field(description="HH:mm - DD/MM/YYYY")

    # Datos de Cliente y Personal Responsable
    cliente_nombre: str
    cliente_rut: Optional[str] = None
    vendedor_nombre: str
    cajera_nombre: str
    sucursal_nombre: Optional[str] = Field(default=None, description="Nombre de la sucursal de emisión")
    id_sucursal: Optional[int] = Field(default=None, description="ID de la sucursal")

    # Estados y Pagos
    estado_orden: str = Field(description="'Pagada', 'Despachada', 'Reservada', 'Anulada'")
    modalidad_pago: str = Field(description="'unico' o 'split'")
    metodos_resumen: str = Field(description="Ej: Débito: $420.000 + Transferencia: $180.000")
    total_venta: int
    abono_previo: int = 0
    monto_pendiente: Optional[int] = Field(default=0, description="Saldo pendiente de pago")
    total_liquidado: int = Field(description="Monto total pagado en ventanilla")

    # Desgloses Detallados para Auditoría
    desglose_pagos: List[HistorialPagoDetalleDTO] = Field(default_factory=list)
    articulos: List[HistorialArticuloDTO] = Field(default_factory=list)
    historial_movimientos: List[HistorialMovimientoDTO] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)


class HistorialCajaResponse(BaseModel):
    total_registros: int
    pagina_actual: int
    limite_por_pagina: int
    total_paginas: int
    resumen_cuadre: Optional[ResumenCuadreCajaDTO] = None
    total_monto_consolidado: Optional[int] = Field(default=0, description="Suma total de ventas")
    items: List[HistorialOrdenItemResponse]

    model_config = ConfigDict(from_attributes=True)


HistorialOrdenesAuditoriaResponse = HistorialCajaResponse



# ==========================================
# ESQUEMAS PARA CHECKOUT WIZARD Y RESERVAS BACKORDER (SPEC-HU-05)
# ==========================================

class ReservaBackorderDTO(BaseModel):
    """DTO para capturar características técnicas y comerciales de una reserva backorder."""
    id_categoria_requerida: int
    marca_requerida: str
    modelo_requerido: str
    anio_requerido: Optional[int] = None
    cilindrada_requerida: Optional[str] = None
    combustible_requerido: Optional[str] = None
    transmision_requerida: Optional[str] = None
    notas_preparacion: Optional[str] = None
    precio_acordado: int
    monto_abonado: int = 0

    model_config = ConfigDict(from_attributes=True)


class DespachoDTO(BaseModel):
    """DTO para capturar datos de envío y receptor."""
    direccion_envio: str
    receptor_nombres: str
    receptor_rut: str
    receptor_telefono: str
    id_comuna_destino: Optional[int] = 1
    empresa_transporte: Optional[str] = "Chilexpress"
    tipo_entrega: Optional[str] = "Despacho"
    id_sucursal_destino: Optional[int] = None

    model_config = ConfigDict(from_attributes=True)


class ItemManualDTO(BaseModel):
    """DTO para ítems manuales o ventas rápidas de mostrador."""
    descripcion: str
    cantidad: int = 1
    precio_unitario: int
    notas_preparacion: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class CheckoutWizardRequest(BaseModel):
    """Payload integral para procesar el checkout por pasos (Wizard)."""
    id_cliente: Optional[UUID] = None
    cliente: Optional[ClienteOrdenInput] = None
    tipo_entrega: str = "Retiro"  # 'Retiro', 'Despacho Domicilio', 'Traslado'
    id_sucursal_destino: Optional[int] = None
    id_vendedor_asignado: Optional[UUID] = None
    total_venta: int
    monto_pendiente: int
    monto_abono: Optional[int] = 0
    instrucciones_bodega: Optional[str] = None
    items_inventariados: List[UUID] = Field(default_factory=list)
    items_manuales: List[dict] = Field(default_factory=list)
    reservas: Optional[List[ReservaBackorderDTO]] = None
    datos_despacho: Optional[DespachoDTO] = None

    model_config = ConfigDict(from_attributes=True)


class CheckoutWizardResponse(BaseModel):
    """Respuesta transaccional tras procesar el Checkout Wizard."""
    id_orden: UUID
    estado: str = "Reservada"
    estado_orden: str = "Reservada"
    total_venta: int
    monto_pendiente: int
    reservas_generadas: int = 0
    activos_reservados: int = 0
    despacho_generado: bool = False
    msg: str = "Orden generada exitosamente."
    mensaje: str = "Orden generada exitosamente."

    model_config = ConfigDict(from_attributes=True)


# ==========================================
# ESQUEMAS PARA ALERTAS Y RESUMEN OPERATIVO (SPEC-HU-06)
# ==========================================

class ResumenAlertasDTO(BaseModel):
    """Resumen consolidado de tareas operativas pendientes de Bodega (Badge de Alertas)."""
    total_tareas: int
    desglose_preparacion: int
    desglose_entregas: int
    desglose_reingresos: int

    model_config = ConfigDict(from_attributes=True)


# ==========================================
# ESQUEMAS PARA GERENCIA Y DASHBOARD EJECUTIVO (HU-5.1)
# ==========================================

from schemas.gerencia_schemas import (  # noqa: E402, F401
    KpiFinancieroDTO,
    DesglosePagoDTO,
    ResumenPagosDTO,
    FlujoOperativoDTO,
    BackorderGerenciaItemDTO,
    BackorderGerenciaListResponse,
    BackorderGerenciaKpisDTO,
)
