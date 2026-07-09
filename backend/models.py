# El archivo models.py utiliza un ORM (Object-Relational Mapping).
# En lugar de escribir comandos SQL crudos como SELECT * FROM Vehiculo_Origen WHERE patente = 'XX', escribes código Python orientado a objetos.
# ¿Por qué? Porque previene inyecciones SQL (ataques de seguridad), hace que el código sea infinitamente más fácil de mantener y permite que FastAPI 
# autogenere la documentación Swagger.

import uuid
from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Boolean
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from database import Base

# ==========================================
# CONFIGURACIÓN, SUCURSALES, ROLES Y USUARIOS
# ==========================================

class Region(Base):
    __tablename__ = "region"
    id_region = Column(Integer, primary_key=True, index=True, autoincrement=True)
    nombre_region = Column(String(100), nullable=False)

class Comuna(Base):
    __tablename__ = "comuna"
    id_comuna = Column(Integer, primary_key=True, index=True, autoincrement=True)
    nombre_comuna = Column(String(100), nullable=False)
    id_region = Column(Integer, ForeignKey("region.id_region"), nullable=False)

class Sucursal(Base):
    __tablename__ = "sucursal"
    id_sucursal = Column(Integer, primary_key=True, index=True, autoincrement=True)
    nombre_sucursal = Column(String(100), nullable=False)
    direccion = Column(String(255), nullable=False)
    sector = Column(String(100), nullable=True)
    id_comuna = Column(Integer, ForeignKey("comuna.id_comuna"), nullable=False)
    estado = Column(String(20), nullable=False, default="Activo")
    fecha_creacion = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    fecha_actualizacion = Column(DateTime(timezone=True), nullable=True, onupdate=func.now())

class Rol(Base):
    __tablename__ = "rol"
    id_rol = Column(Integer, primary_key=True, index=True, autoincrement=True)
    nombre_rol = Column(String(50), nullable=False, unique=True)
    estado = Column(String(20), nullable=False, default="Activo")
    fecha_creacion = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    fecha_actualizacion = Column(DateTime(timezone=True), nullable=True, onupdate=func.now())

class Usuario(Base):
    __tablename__ = "usuario"
    id_usuario = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    id_rol = Column(Integer, ForeignKey("rol.id_rol"), nullable=False)
    id_sucursal = Column(Integer, ForeignKey("sucursal.id_sucursal"), nullable=False)
    nombres = Column(String(100), nullable=False)
    apellidos = Column(String(100), nullable=False)
    email = Column(String(150), nullable=False, unique=True)
    password_hash = Column(String(255), nullable=False)
    pin_acceso = Column(String(4), nullable=True)
    telegram_chat_id = Column(String(100), nullable=True)
    estado = Column(String(20), nullable=False, default="Activo")
    fecha_creacion = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    fecha_actualizacion = Column(DateTime(timezone=True), nullable=True, onupdate=func.now())

# ==========================================
# INVENTARIO Y EXTRACCIÓN (WEB SCRAPING)
# ==========================================

class VehiculoOrigen(Base):
    __tablename__ = "vehiculo_origen"
    id_vehiculo = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    numero_ingreso = Column(String(10), nullable=False, unique=True)
    patente = Column(String(10), nullable=True, unique=True)
    vin = Column(String(17), nullable=True, unique=True)
    marca = Column(String(100), nullable=False)
    modelo = Column(String(100), nullable=False)
    anio = Column(Integer, nullable=False)
    fecha_creacion = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    fecha_actualizacion = Column(DateTime(timezone=True), nullable=True, onupdate=func.now())

class CategoriaActivo(Base):
    __tablename__ = "categoria_activo"
    id_categoria = Column(Integer, primary_key=True, index=True, autoincrement=True)
    nombre_categoria = Column(String(50), nullable=False, unique=True)

class EstadoActivo(Base):
    __tablename__ = "estado_activo"
    id_estado = Column(Integer, primary_key=True, index=True, autoincrement=True)
    nombre_estado = Column(String(50), nullable=False, unique=True)

class ActivoInventariado(Base):
    __tablename__ = "activo_inventariado"
    id_activo = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    sku_qr_fisico = Column(String(100), nullable=False, unique=True)
    id_categoria = Column(Integer, ForeignKey("categoria_activo.id_categoria"), nullable=False)
    id_estado = Column(Integer, ForeignKey("estado_activo.id_estado"), nullable=False)
    id_sucursal_actual = Column(Integer, ForeignKey("sucursal.id_sucursal"), nullable=False)
    id_vehiculo = Column(UUID(as_uuid=True), ForeignKey("vehiculo_origen.id_vehiculo"), nullable=True)
    
    ubicacion_pasillo = Column(String(50), nullable=True)
    ubicacion_pallet = Column(String(50), nullable=True)
    precio_referencia = Column(Integer, nullable=False)
    observacion_estado = Column(String(255), nullable=True)
    
    version_lock = Column(Integer, nullable=False, default=1)
    estado = Column(String(20), nullable=False, default="Activo")
    fecha_creacion = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    fecha_actualizacion = Column(DateTime(timezone=True), nullable=True, onupdate=func.now())

class DetalleMotor(Base):
    __tablename__ = "detalle_motor"
    id_activo = Column(UUID(as_uuid=True), ForeignKey("activo_inventariado.id_activo"), primary_key=True)
    numero_motor = Column(String(100), nullable=True)
    cilindrada = Column(String(20), nullable=True)
    combustible = Column(String(50), nullable=True)
    transmision_tipo = Column(String(50), nullable=True)

class DetalleCajaCambio(Base):
    __tablename__ = "detalle_caja_cambio"
    id_activo = Column(UUID(as_uuid=True), ForeignKey("activo_inventariado.id_activo"), primary_key=True)
    transmision_tipo = Column(String(50), nullable=True)

class ImagenActivo(Base):
    __tablename__ = "imagen_activo"
    id_imagen = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    id_activo = Column(UUID(as_uuid=True), ForeignKey("activo_inventariado.id_activo"), nullable=False)
    url_storage = Column(String(255), nullable=False)

class ReservasBackorder(Base):
    __tablename__ = "reservas_backorder"
    id_reserva = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    id_cliente = Column(UUID(as_uuid=True), ForeignKey("cliente.id_cliente"), nullable=False)
    id_orden = Column(UUID(as_uuid=True), ForeignKey("orden_venta.id_orden"), nullable=False)
    id_sucursal_registro = Column(Integer, ForeignKey("sucursal.id_sucursal"), nullable=False)
    id_categoria_requerida = Column(Integer, ForeignKey("categoria_activo.id_categoria"), nullable=False)
    
    marca_requerida = Column(String(100), nullable=False)
    modelo_requerido = Column(String(100), nullable=False)
    anio_requerido = Column(Integer, nullable=True)
    cilindrada_requerida = Column(String(20), nullable=True)
    combustible_requerido = Column(String(50), nullable=True)
    transmision_requerida = Column(String(50), nullable=True)
    
    monto_abonado = Column(Integer, nullable=False, default=0)
    id_activo_asignado = Column(UUID(as_uuid=True), ForeignKey("activo_inventariado.id_activo"), nullable=True)
    estado_reserva = Column(String(30), nullable=False, default="Pendiente")
    fecha_creacion = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    fecha_actualizacion = Column(DateTime(timezone=True), nullable=True, onupdate=func.now())

# ==========================================
# MICRO-CRM, VENTAS Y PAGOS
# ==========================================

class Cliente(Base):
    __tablename__ = "cliente"
    id_cliente = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    rut_cliente = Column(String(12), nullable=False, unique=True)
    nombres = Column(String(100), nullable=False)
    apellidos = Column(String(100), nullable=False)
    correo = Column(String(150), nullable=True)
    telefono = Column(String(20), nullable=True)
    id_comuna = Column(Integer, ForeignKey("comuna.id_comuna"), nullable=True)
    consentimiento_legal = Column(Boolean, nullable=False, default=True)
    estado = Column(String(20), nullable=False, default="Activo")
    fecha_creacion = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    fecha_actualizacion = Column(DateTime(timezone=True), nullable=True, onupdate=func.now())

class OrdenVenta(Base):
    __tablename__ = "orden_venta"
    id_orden = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    id_cliente = Column(UUID(as_uuid=True), ForeignKey("cliente.id_cliente"), nullable=False)
    id_vendedor = Column(UUID(as_uuid=True), ForeignKey("usuario.id_usuario"), nullable=False)
    id_cajera = Column(UUID(as_uuid=True), ForeignKey("usuario.id_usuario"), nullable=True)
    id_sucursal = Column(Integer, ForeignKey("sucursal.id_sucursal"), nullable=False)
    
    estado_orden = Column(String(30), nullable=False, default="Reservada")
    qr_transaccional_salida = Column(String(255), nullable=True, unique=True)
    total_venta = Column(Integer, nullable=False, default=0)
    monto_pendiente = Column(Integer, nullable=False, default=0)
    
    fecha_creacion = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    fecha_actualizacion = Column(DateTime(timezone=True), nullable=True, onupdate=func.now())

class DetalleOrden(Base):
    __tablename__ = "detalle_orden"
    id_detalle = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    id_orden = Column(UUID(as_uuid=True), ForeignKey("orden_venta.id_orden"), nullable=False)
    id_activo = Column(UUID(as_uuid=True), ForeignKey("activo_inventariado.id_activo"), nullable=True)
    descripcion_manual = Column(String(255), nullable=True)
    cantidad = Column(Integer, nullable=False, default=1)
    precio_unitario = Column(Integer, nullable=True)
    precio_final = Column(Integer, nullable=False)

class TransaccionPago(Base):
    __tablename__ = "transaccion_pago"
    id_pago = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    id_orden = Column(UUID(as_uuid=True), ForeignKey("orden_venta.id_orden"), nullable=False)
    monto = Column(Integer, nullable=False)
    metodo_pago = Column(String(50), nullable=False)
    estado_pago = Column(String(20), nullable=False, default="Procesado")
    fecha_pago = Column(DateTime(timezone=True), nullable=False, server_default=func.now())

# ==========================================
# BARRERA DIGITAL Y LOGÍSTICA
# ==========================================

class AuditoriaBarrera(Base):
    __tablename__ = "auditoria_barrera"
    id_auditoria = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    id_orden = Column(UUID(as_uuid=True), ForeignKey("orden_venta.id_orden"), nullable=False)
    id_bodeguero = Column(UUID(as_uuid=True), ForeignKey("usuario.id_usuario"), nullable=False)
    fecha_escaneo = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    match_exitoso = Column(Boolean, nullable=False)

class TrackingLogistico(Base):
    __tablename__ = "tracking_logistico"
    id_tracking = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    id_activo = Column(UUID(as_uuid=True), ForeignKey("activo_inventariado.id_activo"), nullable=False)
    id_sucursal_origen = Column(Integer, ForeignKey("sucursal.id_sucursal"), nullable=False)
    id_sucursal_destino = Column(Integer, ForeignKey("sucursal.id_sucursal"), nullable=False)
    id_usuario_gestor = Column(UUID(as_uuid=True), ForeignKey("usuario.id_usuario"), nullable=False)
    fecha_movimiento = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    estado_traslado = Column(String(30), nullable=False)