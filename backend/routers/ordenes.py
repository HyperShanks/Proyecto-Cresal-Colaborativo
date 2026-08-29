# Router Transaccional de Órdenes de Venta (HU-3.4)
# Expone el endpoint POST /api/v1/ordenes para consolidar ventas del Carrito Híbrido,
# registrar datos de Micro-CRM, gestionar despacho y asegurar la consistencia ACID del inventario.

import uuid
from datetime import datetime, time as datetime_time, timezone, timedelta
from zoneinfo import ZoneInfo
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from database import get_db
from models import (
    Usuario, Cliente, Comuna, Orden_Venta, Detalle_Orden,
    Despacho, Activo_Inventariado, Estado_Activo,
    Vehiculo_Origen, Categoria_Activo, Transaccion_Pago,
    Tracking_Logistico, Sucursal
)
from schemas import (
    OrdenCreateRequest, OrdenResponse,
    ClienteOrdenResumen, DespachoOrdenResumen,
    DetalleOrdenItemResponse, OrdenHistorialItemResponse,
    OrdenAnulacionResponse, AnularOrdenRequest, InstruccionesUpdateRequest,
    InstruccionesUpdateResponse, OrdenPagoRequest,
    OrdenPagoResponse, EntregaEnvioItemResponse,
    EntregaConfirmacionResponse, DespachoEnvioResponse,
    VendedorResumenResponse
)
from core.security import get_current_user

router = APIRouter(
    prefix="/api/v1/ordenes",
    tags=["Órdenes de Venta"]
)


@router.post(
    "",
    response_model=OrdenResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear Orden de Venta Transaccional (ACID)",
    description="Procesa la orden de venta desde el carrito de compras. "
                "Registra cliente, cabecera de orden, despacho, detalle y "
                "reserva los repuestos inventariados en una transacción atómica."
)
@router.post(
    "/",
    response_model=OrdenResponse,
    status_code=status.HTTP_201_CREATED,
    include_in_schema=False
)
def crear_orden(
    orden_in: OrdenCreateRequest,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    """
    Motor Transaccional de Creación de Órdenes:
    1. Validaciones previas de negocio (Consentimiento, ítems, despacho, stock disponible).
    2. Transacción ACID:
       - Paso A.1: Upsert / Registro del Cliente (Micro-CRM).
       - Paso A.2: Inserción de la Cabecera de Orden_Venta (estado='Reservada').
       - Paso A.3: Inserción de Despacho (si requiere_despacho == True).
       - Paso B: Inserción de líneas en Detalle_Orden (con notas de preparación para bodega).
       - Paso C: Actualización atómica de Activo_Inventariado a estado 'Reservado'.
    3. Rollback inmediato ante cualquier fallo.
    """
    # ── 1. Validaciones Previas de Negocio ──────────────────────────────────
    if not orden_in.consentimiento_legal:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El consentimiento expreso para tratamiento de datos (Ley N° 21.719) es obligatorio."
        )

    if not orden_in.items or len(orden_in.items) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La orden debe contener al menos un ítem o repuesto."
        )

    if orden_in.requiere_despacho and not orden_in.despacho:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Debe proporcionar los datos de despacho si 'requiere_despacho' está activado."
        )

    # Determinar tipo de entrega y sucursales involucradas
    tipo_entrega_final = orden_in.tipo_entrega or "Retiro"
    if orden_in.despacho and orden_in.despacho.tipo_entrega:
        tipo_entrega_final = orden_in.despacho.tipo_entrega

    id_sucursal_orden = orden_in.id_sucursal or getattr(current_user, 'id_sucursal', 1) or 1
    id_sucursal_dest_traslado = orden_in.id_sucursal_destino or (orden_in.despacho.id_sucursal_destino if orden_in.despacho else None) or id_sucursal_orden

    # Validación de sucursales para traslados (1: Viña del Mar, 2: Limache)
    if tipo_entrega_final == "Traslado":
        if id_sucursal_dest_traslado not in [1, 2]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="La sucursal de destino no es válida para traslados inter-sucursal (permitidas: 1 Viña del Mar, 2 Limache)."
            )

    # Calcular monto total
    total_calculado = sum(item.precio_final * item.cantidad for item in orden_in.items)
    if total_calculado <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El monto total de la orden debe ser mayor a $0."
        )

    # Validar disponibilidad de repuestos inventariados antes de iniciar escritura
    for item in orden_in.items:
        if item.id_activo:
            activo_db = (
                db.query(Activo_Inventariado, Estado_Activo)
                .join(Estado_Activo, Activo_Inventariado.id_estado == Estado_Activo.id_estado)
                .filter(Activo_Inventariado.id_activo == item.id_activo)
                .first()
            )
            if not activo_db:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"El repuesto inventariado con ID '{item.id_activo}' no existe en el sistema."
                )

            activo, estado = activo_db
            if activo.estado != "Activo" or estado.nombre_estado != "Disponible":
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"El repuesto '{activo.sku_qr_fisico}' no está disponible para venta. "
                           f"Estado actual: {estado.nombre_estado}."
                )

            if tipo_entrega_final == "Traslado" and orden_in.id_sucursal_destino and activo.id_sucursal_actual == id_sucursal_dest_traslado:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="La sucursal de origen y destino no pueden ser iguales para un traslado."
                )

    # ── 2. Bloque Transaccional ACID ─────────────────────────────────────────
    try:
        # ── Paso A.1: Gestión de Cliente (Upsert / Find or Create) ───────────
        rut_limpio = orden_in.cliente.rut_cliente.strip()
        rut_normalizado = rut_limpio.replace(".", "").replace("-", "").upper()

        es_consumidor_final = rut_normalizado in ["66666666", "6666666"] or "CONSUMIDOR" in orden_in.cliente.nombres.upper()

        if es_consumidor_final:
            cliente = db.query(Cliente).filter(
                Cliente.rut_cliente.in_(["6.666.666-6", "66666666-6", "6666666-6"])
            ).first()
            if not cliente:
                cliente = Cliente(
                    rut_cliente="6.666.666-6",
                    nombres="Consumidor",
                    apellidos="Final",
                    consentimiento_legal=True,
                    estado="Activo",
                )
                db.add(cliente)
                db.flush()
        else:
            cliente = db.query(Cliente).filter(
                (Cliente.rut_cliente == rut_limpio) | (Cliente.rut_cliente == rut_limpio.replace(".", ""))
            ).first()

            id_comuna_cliente = None
            if orden_in.cliente.comuna:
                comuna_obj = (
                    db.query(Comuna)
                    .filter(Comuna.nombre_comuna.ilike(orden_in.cliente.comuna.strip()))
                    .first()
                )
                if comuna_obj:
                    id_comuna_cliente = comuna_obj.id_comuna

            if not cliente:
                cliente = Cliente(
                    rut_cliente=rut_limpio,
                    nombres=orden_in.cliente.nombres.strip(),
                    apellidos=orden_in.cliente.apellidos.strip(),
                    telefono=orden_in.cliente.telefono.strip() if orden_in.cliente.telefono else None,
                    correo=orden_in.cliente.correo.strip() if orden_in.cliente.correo else None,
                    id_comuna=id_comuna_cliente,
                    consentimiento_legal=orden_in.consentimiento_legal,
                    estado="Activo",
                )
                db.add(cliente)
                db.flush()
            else:
                # Actualizar datos de contacto más recientes
                cliente.nombres = orden_in.cliente.nombres.strip()
                cliente.apellidos = orden_in.cliente.apellidos.strip()
                if orden_in.cliente.telefono:
                    cliente.telefono = orden_in.cliente.telefono.strip()
                if orden_in.cliente.correo:
                    cliente.correo = orden_in.cliente.correo.strip()
                if id_comuna_cliente:
                    cliente.id_comuna = id_comuna_cliente
                cliente.consentimiento_legal = orden_in.consentimiento_legal
                db.flush()

        # ── Paso A.2: Cabecera Orden_Venta ──────────────────────────────────
        qr_salida = f"ORD-{uuid.uuid4().hex[:8].upper()}"

        monto_abono_val = orden_in.monto_abono if (orden_in.monto_abono is not None and orden_in.monto_abono > 0) else 0
        if monto_abono_val > total_calculado:
            monto_abono_val = total_calculado

        monto_pendiente_calc = total_calculado - monto_abono_val
        estado_inicial = "Pagada" if monto_pendiente_calc == 0 else "Reservada"

        nueva_orden = Orden_Venta(
            id_cliente=cliente.id_cliente,
            id_vendedor=current_user.id_usuario,
            id_vendedor_asignado=orden_in.id_vendedor_asignado,
            id_sucursal=id_sucursal_orden,
            estado_orden=estado_inicial,
            qr_transaccional_salida=qr_salida,
            total_venta=total_calculado,
            monto_pendiente=monto_pendiente_calc,
        )
        db.add(nueva_orden)
        db.flush()

        if monto_abono_val > 0:
            transaccion_abono = Transaccion_Pago(
                id_pago=uuid.uuid4(),
                id_orden=nueva_orden.id_orden,
                monto=monto_abono_val,
                metodo_pago="Abono Inicial",
                estado_pago="Procesado",
                fecha_pago=datetime.now(),
            )
            db.add(transaccion_abono)
            db.flush()

        # ── Paso A.3: Despacho (Exclusivo para envíos a clientes a domicilio/taller) ──
        if orden_in.requiere_despacho and orden_in.despacho:
            desp_obj = orden_in.despacho
            dir_envio = desp_obj.direccion_envio.strip()
            rec_nombres = desp_obj.receptor_nombres.strip() if desp_obj.receptor_nombres else f"{cliente.nombres} {cliente.apellidos}".strip()
            rec_rut = desp_obj.receptor_rut.strip() if desp_obj.receptor_rut else cliente.rut_cliente
            rec_tel = desp_obj.receptor_telefono.strip() if desp_obj.receptor_telefono else (cliente.telefono or "S/T")

            id_comuna_dest = desp_obj.id_comuna_destino
            if not id_comuna_dest and desp_obj.comuna_destino:
                comuna_dest_obj = (
                    db.query(Comuna)
                    .filter(Comuna.nombre_comuna.ilike(desp_obj.comuna_destino.strip()))
                    .first()
                )
                if comuna_dest_obj:
                    id_comuna_dest = comuna_dest_obj.id_comuna

            if not id_comuna_dest:
                comuna_fallback = db.query(Comuna).first()
                id_comuna_dest = comuna_fallback.id_comuna if comuna_fallback else 1

            despacho = Despacho(
                id_orden=nueva_orden.id_orden,
                id_comuna_destino=id_comuna_dest,
                direccion_envio=dir_envio,
                receptor_nombres=rec_nombres,
                receptor_rut=rec_rut,
                receptor_telefono=rec_tel,
                empresa_transporte=desp_obj.empresa_transporte,
                costo_envio=desp_obj.costo_envio or 0,
                estado_despacho="Por Enviar",
                estado="Activo"
            )
            db.add(despacho)
            db.flush()

        # ── Paso B: Líneas en Detalle_Orden & Paso C: Update Activos ─────────
        estado_reservado = db.query(Estado_Activo).filter(Estado_Activo.nombre_estado == "Reservado").first()
        if not estado_reservado:
            estado_reservado = Estado_Activo(id_estado=2, nombre_estado="Reservado")
            db.add(estado_reservado)
            db.flush()

        for item in orden_in.items:
            nota_final = item.notas_preparacion or orden_in.instrucciones_bodega
            activo = None

            # Si es inventariado, verificar si requiere traslado entre sucursales
            if item.id_activo:
                activo = (
                    db.query(Activo_Inventariado)
                    .filter(Activo_Inventariado.id_activo == item.id_activo)
                    .first()
                )
                if activo:
                    # Regla Traslado: Activo ubicado en Limache (2) vendido en Viña (1), o tipo_entrega='Traslado'
                    if (activo.id_sucursal_actual == 2 and id_sucursal_orden == 1) or tipo_entrega_final == "Traslado" or (activo.id_sucursal_actual != id_sucursal_orden):
                        dest_suc = (
                            id_sucursal_dest_traslado
                            if id_sucursal_dest_traslado != activo.id_sucursal_actual
                            else (1 if activo.id_sucursal_actual == 2 else 2)
                        )
                        tracking = Tracking_Logistico(
                            id_activo=activo.id_activo,
                            id_sucursal_origen=activo.id_sucursal_actual,
                            id_sucursal_destino=dest_suc,
                            id_usuario_gestor=current_user.id_usuario,
                            id_orden=nueva_orden.id_orden,
                            estado_traslado="Pendiente",
                        )
                        db.add(tracking)

                        nombre_origen = "Limache" if activo.id_sucursal_actual == 2 else "Viña del Mar"
                        nombre_dest = "Viña del Mar" if dest_suc == 1 else "Limache"
                        prefijo = f"[TRASLADO DESDE {nombre_origen.upper()} A {nombre_dest.upper()}] "
                        if nota_final:
                            if prefijo not in nota_final:
                                nota_final = f"{prefijo}{nota_final}"
                        else:
                            nota_final = f"{prefijo}Preparar repuesto para traslado inter-sucursal."

            detalle = Detalle_Orden(
                id_orden=nueva_orden.id_orden,
                id_activo=item.id_activo,
                descripcion_manual=item.descripcion_manual,
                notas_preparacion=nota_final,
                cantidad=item.cantidad,
                precio_unitario=item.precio_unitario or item.precio_final,
                precio_final=item.precio_final,
                estado_preparacion="Pendiente",
            )
            db.add(detalle)

            # Paso C: Bloquear y actualizar estado de repuesto inventariado
            if item.id_activo and activo:
                activo.id_estado = estado_reservado.id_estado
                activo.version_lock = (activo.version_lock or 1) + 1

        # ── 3. Commit Transaccional Atómico ─────────────────────────────────
        db.commit()
        db.refresh(nueva_orden)

        return OrdenResponse(
            id_orden=nueva_orden.id_orden,
            estado_orden=nueva_orden.estado_orden,
            total_venta=nueva_orden.total_venta,
            monto_pendiente=nueva_orden.monto_pendiente,
            qr_transaccional_salida=nueva_orden.qr_transaccional_salida,
            mensaje="Orden de venta generada exitosamente y derivada a caja.",
            fecha_creacion=nueva_orden.fecha_creacion.isoformat() if nueva_orden.fecha_creacion else None,
            total_items=len(orden_in.items),
        )

    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error en la transacción de creación de la orden: {str(e)}"
        )


@router.get(
    "/mis-ventas",
    response_model=List[OrdenHistorialItemResponse],
    summary="Historial y Monitoreo de Ventas del Vendedor (HU-3.5)",
    description="Consulta las órdenes generadas por el usuario actual. "
                "Por defecto filtra solo las ventas de la fecha actual (hoy). "
                "Incluye estado de la orden, datos del cliente, despacho y desglose de líneas."
)
def obtener_mis_ventas(
    fecha: Optional[str] = None,
    todas: bool = False,
    estado: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    query = db.query(Orden_Venta).filter(Orden_Venta.id_vendedor == current_user.id_usuario)

    # Filtro de Rendimiento: Por defecto solo órdenes de hoy
    if not todas:
        try:
            tz_chile = ZoneInfo("America/Santiago")
        except Exception:
            tz_chile = timezone(timedelta(hours=-4))

        if fecha and fecha.strip():
            try:
                target_date = datetime.strptime(fecha.strip(), "%Y-%m-%d").date()
                dt_start_chile = datetime.combine(target_date, datetime_time.min, tzinfo=tz_chile)
                dt_end_chile = datetime.combine(target_date, datetime_time.max, tzinfo=tz_chile)
                inicio_utc = dt_start_chile.astimezone(timezone.utc).replace(tzinfo=None)
                fin_utc = dt_end_chile.astimezone(timezone.utc).replace(tzinfo=None)
            except ValueError:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Formato de fecha no válido. Use 'YYYY-MM-DD'."
                )
        else:
            ahora_chile = datetime.now(tz_chile)
            inicio_dia_chile = datetime.combine(ahora_chile.date(), datetime_time.min, tzinfo=tz_chile)
            fin_dia_chile = datetime.combine(ahora_chile.date(), datetime_time.max, tzinfo=tz_chile)
            inicio_utc = inicio_dia_chile.astimezone(timezone.utc).replace(tzinfo=None)
            fin_utc = fin_dia_chile.astimezone(timezone.utc).replace(tzinfo=None)

        query = query.filter(
            Orden_Venta.fecha_creacion >= inicio_utc,
            Orden_Venta.fecha_creacion <= fin_utc
        )

    if estado and estado.strip():
        query = query.filter(Orden_Venta.estado_orden == estado.strip())

    ordenes = query.order_by(Orden_Venta.fecha_creacion.desc()).all()

    resultado = []
    for orden in ordenes:
        # Cliente
        cliente_db = db.query(Cliente).filter(Cliente.id_cliente == orden.id_cliente).first()
        cliente_resumen = None
        if cliente_db:
            comuna_nombre = None
            if cliente_db.id_comuna:
                c_obj = db.query(Comuna).filter(Comuna.id_comuna == cliente_db.id_comuna).first()
                if c_obj:
                    comuna_nombre = c_obj.nombre_comuna
            cliente_resumen = ClienteOrdenResumen(
                rut_cliente=cliente_db.rut_cliente,
                nombres=cliente_db.nombres,
                apellidos=cliente_db.apellidos,
                telefono=cliente_db.telefono,
                correo=cliente_db.correo,
                comuna=comuna_nombre,
            )

        # Despacho
        despacho_db = db.query(Despacho).filter(Despacho.id_orden == orden.id_orden).first()
        despacho_resumen = None
        if despacho_db:
            comuna_dest_nombre = None
            if despacho_db.id_comuna_destino:
                c_dest = db.query(Comuna).filter(Comuna.id_comuna == despacho_db.id_comuna_destino).first()
                if c_dest:
                    comuna_dest_nombre = c_dest.nombre_comuna
            despacho_resumen = DespachoOrdenResumen(
                id_despacho=despacho_db.id_despacho,
                direccion_envio=despacho_db.direccion_envio,
                receptor_nombres=despacho_db.receptor_nombres,
                receptor_rut=despacho_db.receptor_rut,
                receptor_telefono=despacho_db.receptor_telefono,
                empresa_transporte=despacho_db.empresa_transporte,
                costo_envio=despacho_db.costo_envio or 0,
                estado_despacho=despacho_db.estado_despacho,
                comuna_destino=comuna_dest_nombre,
            )

        # Detalle de líneas
        detalles_db = db.query(Detalle_Orden).filter(Detalle_Orden.id_orden == orden.id_orden).all()
        detalles_resumen = []
        for d in detalles_db:
            sku_fisico = None
            titulo_item = d.descripcion_manual or "Repuesto Misceláneo"
            es_inv = False

            if d.id_activo:
                es_inv = True
                activo_db = (
                    db.query(Activo_Inventariado, Vehiculo_Origen, Categoria_Activo)
                    .outerjoin(Vehiculo_Origen, Activo_Inventariado.id_vehiculo == Vehiculo_Origen.id_vehiculo)
                    .join(Categoria_Activo, Activo_Inventariado.id_categoria == Categoria_Activo.id_categoria)
                    .filter(Activo_Inventariado.id_activo == d.id_activo)
                    .first()
                )
                if activo_db:
                    act, veh, cat = activo_db
                    sku_fisico = act.sku_qr_fisico
                    nombre_cat = cat.nombre_categoria if cat else "Repuesto"
                    if veh:
                        titulo_item = f"{nombre_cat} - {veh.marca} {veh.modelo} {veh.anio or ''}".strip()
                    else:
                        titulo_item = f"{nombre_cat} ({sku_fisico})"

            detalles_resumen.append(
                DetalleOrdenItemResponse(
                    id_detalle=d.id_detalle,
                    id_activo=d.id_activo,
                    titulo=titulo_item,
                    sku_qr_fisico=sku_fisico,
                    descripcion_manual=d.descripcion_manual,
                    notas_preparacion=d.notas_preparacion,
                    cantidad=d.cantidad,
                    precio_unitario=d.precio_unitario,
                    precio_final=d.precio_final,
                    subtotal=d.precio_final * d.cantidad,
                    es_inventariado=es_inv,
                    preparacion_lista=d.preparacion_lista,
                    estado_preparacion=d.estado_preparacion,
                )
            )

        resultado.append(
            OrdenHistorialItemResponse(
                id_orden=orden.id_orden,
                estado_orden=orden.estado_orden,
                total_venta=orden.total_venta,
                monto_pendiente=orden.monto_pendiente,
                qr_transaccional_salida=orden.qr_transaccional_salida,
                fecha_creacion=orden.fecha_creacion.isoformat() if orden.fecha_creacion else None,
                fecha_actualizacion=orden.fecha_actualizacion.isoformat() if orden.fecha_actualizacion else None,
                total_items=len(detalles_resumen),
                cliente=cliente_resumen,
                despacho=despacho_resumen,
                detalles=detalles_resumen,
            )
        )

    return resultado


@router.get(
    "/vendedores",
    response_model=List[VendedorResumenResponse],
    summary="Listado de Vendedores Activos por Sucursal",
    description="Retorna los vendedores activos para la delegación de entregas o ventas online.",
)
def listar_vendedores_sucursal(
    sucursal_id: Optional[int] = Query(None, description="ID de la sucursal activa (opcional)"),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    query = db.query(Usuario).filter(Usuario.estado == "Activo")
    if sucursal_id is not None:
        query = query.filter(Usuario.id_sucursal == sucursal_id)
    usuarios = query.order_by(Usuario.nombres).all()
    return [
        VendedorResumenResponse(
            id_usuario=u.id_usuario,
            nombre_completo=f"{u.nombres} {u.apellidos or ''}".strip(),
            rut=u.rut_usuario,
            id_sucursal=u.id_sucursal,
            correo=u.email,
        )
        for u in usuarios
    ]


# ==========================================
# MÓDULO: ENTREGAS Y ENVÍOS (VENTAS PRESENCIALES Y ONLINE)
# ==========================================

@router.get(
    "/entregas-envios",
    response_model=List[EntregaEnvioItemResponse],
    summary="Listado Colaborativo de Entregas en Tienda y Despachos Externos",
    description="Consulta colaborativa de pedidos con filtros por cliente, vendedor, tipo y reglas de privacidad.",
)
def listar_entregas_envios(
    sucursal_id: int = Query(1, description="ID de la sucursal activa"),
    tipo: Optional[str] = Query(None, description="Filtro por tipo: 'retiro' o 'despacho'"),
    busqueda_cliente: Optional[str] = Query(None, description="Filtro por Nombre, RUT o Teléfono del cliente"),
    busqueda_vendedor: Optional[str] = Query(None, description="Filtro por Vendedor creador o asignado"),
    busqueda: Optional[str] = Query(None, description="Término general de búsqueda"),
    estado_pago: Optional[str] = Query(None, description="Filtro de pago: 'todos', 'pagados', 'pendientes'"),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    tipo_filtro = (tipo.strip().lower() if tipo else None)

    ordenes_resultado = []

    # A. Consulta de Retiros en Tienda (sin registro en Despacho)
    if tipo_filtro in [None, "retiro", "todos", ""]:
        q_retiros = (
            db.query(Orden_Venta)
            .outerjoin(Despacho, Orden_Venta.id_orden == Despacho.id_orden)
            .filter(
                Orden_Venta.id_sucursal == sucursal_id,
                Orden_Venta.estado_orden.in_(["Reservada", "Pagada"]),
                Despacho.id_despacho == None,
            )
        )
        ordenes_resultado.extend([("Retiro", o) for o in q_retiros.all()])

    # B. Consulta de Despachos Externos (con registro en Despacho y estado Por Enviar)
    if tipo_filtro in [None, "despacho", "todos", ""]:
        q_despachos = (
            db.query(Orden_Venta)
            .join(Despacho, Orden_Venta.id_orden == Despacho.id_orden)
            .filter(
                Orden_Venta.id_sucursal == sucursal_id,
                Orden_Venta.estado_orden.in_(["Reservada", "Pagada"]),
                Despacho.estado_despacho.in_(["Por Enviar", "En Preparacion"]),
            )
        )
        ordenes_resultado.extend([("Despacho", o) for o in q_despachos.all()])

    # Ordenar cronológicamente descendente
    ordenes_resultado.sort(key=lambda x: x[1].fecha_creacion, reverse=True)

    items_response = []
    term_busqueda = busqueda.strip().upper() if busqueda and busqueda.strip() else None
    es_admin_o_jefe = current_user.id_rol in [1, 5, 6]

    for tipo_entrega_item, orden in ordenes_resultado:
        # 1. Regla de Privacidad y Visibilidad:
        # - Admin/Jefe: ve todo.
        # - id_vendedor_asignado IS NULL (Mesón General / Presencial): visible para toda la sucursal.
        # - id_vendedor_asignado IS NOT NULL (Venta Online asignada): visible para el asignado o el creador.
        if not es_admin_o_jefe and orden.id_vendedor_asignado is not None:
            if orden.id_vendedor_asignado != current_user.id_usuario and orden.id_vendedor != current_user.id_usuario:
                continue

        # 2. Filtro por Estado de Pago
        if estado_pago:
            ep = estado_pago.strip().lower()
            if ep == "pagados" and orden.monto_pendiente > 0:
                continue
            elif ep in ["pendientes", "con saldo pendiente"] and orden.monto_pendiente == 0:
                continue

        # Cliente
        cliente_db = db.query(Cliente).filter(Cliente.id_cliente == orden.id_cliente).first()
        cliente_resumen = None
        if cliente_db:
            comuna_nombre = None
            if cliente_db.id_comuna:
                c_obj = db.query(Comuna).filter(Comuna.id_comuna == cliente_db.id_comuna).first()
                if c_obj:
                    comuna_nombre = c_obj.nombre_comuna
            cliente_resumen = ClienteOrdenResumen(
                rut_cliente=cliente_db.rut_cliente,
                nombres=cliente_db.nombres,
                apellidos=cliente_db.apellidos,
                telefono=cliente_db.telefono,
                correo=cliente_db.correo,
                comuna=comuna_nombre,
            )

        # Despacho
        despacho_db = db.query(Despacho).filter(Despacho.id_orden == orden.id_orden).first()
        despacho_resumen = None
        if despacho_db:
            comuna_dest_nombre = None
            if despacho_db.id_comuna_destino:
                c_dest = db.query(Comuna).filter(Comuna.id_comuna == despacho_db.id_comuna_destino).first()
                if c_dest:
                    comuna_dest_nombre = c_dest.nombre_comuna
            despacho_resumen = DespachoOrdenResumen(
                id_despacho=despacho_db.id_despacho,
                direccion_envio=despacho_db.direccion_envio,
                receptor_nombres=despacho_db.receptor_nombres,
                receptor_rut=despacho_db.receptor_rut,
                receptor_telefono=despacho_db.receptor_telefono,
                empresa_transporte=despacho_db.empresa_transporte,
                costo_envio=despacho_db.costo_envio or 0,
                estado_despacho=despacho_db.estado_despacho,
                comuna_destino=comuna_dest_nombre,
            )

        # Detalles (repuestos inventariados + misceláneos)
        detalles_db = db.query(Detalle_Orden).filter(Detalle_Orden.id_orden == orden.id_orden).all()
        detalles_resumen = []
        for d in detalles_db:
            sku_fisico = None
            titulo_item = d.descripcion_manual or "Repuesto Misceláneo"
            es_inv = False

            if d.id_activo:
                es_inv = True
                activo_db = (
                    db.query(Activo_Inventariado, Vehiculo_Origen, Categoria_Activo)
                    .outerjoin(Vehiculo_Origen, Activo_Inventariado.id_vehiculo == Vehiculo_Origen.id_vehiculo)
                    .join(Categoria_Activo, Activo_Inventariado.id_categoria == Categoria_Activo.id_categoria)
                    .filter(Activo_Inventariado.id_activo == d.id_activo)
                    .first()
                )
                if activo_db:
                    act, veh, cat = activo_db
                    sku_fisico = act.sku_qr_fisico
                    nombre_cat = cat.nombre_categoria if cat else "Repuesto"
                    if veh:
                        titulo_item = f"{nombre_cat} - {veh.marca} {veh.modelo} {veh.anio or ''}".strip()
                    else:
                        titulo_item = f"{nombre_cat} ({sku_fisico})"

            detalles_resumen.append(
                DetalleOrdenItemResponse(
                    id_detalle=d.id_detalle,
                    id_activo=d.id_activo,
                    titulo=titulo_item,
                    sku_qr_fisico=sku_fisico,
                    descripcion_manual=d.descripcion_manual,
                    notas_preparacion=d.notas_preparacion,
                    cantidad=d.cantidad,
                    precio_unitario=d.precio_unitario,
                    precio_final=d.precio_final,
                    subtotal=d.precio_final * d.cantidad,
                    es_inventariado=es_inv,
                    preparacion_lista=d.preparacion_lista,
                    estado_preparacion=d.estado_preparacion or "Pendiente",
                )
            )

        # Vendedor Responsable (Creador)
        vendedor_db = db.query(Usuario).filter(Usuario.id_usuario == orden.id_vendedor).first()
        vendedor_nombre = (
            f"{vendedor_db.nombres} {vendedor_db.apellidos or ''}".strip()
            if vendedor_db
            else "Vendedor Central"
        )

        # Vendedor Asignado
        vendedor_asignado_nombre = "Mesón General (Todos)"
        if orden.id_vendedor_asignado:
            v_asig_db = db.query(Usuario).filter(Usuario.id_usuario == orden.id_vendedor_asignado).first()
            if v_asig_db:
                vendedor_asignado_nombre = f"{v_asig_db.nombres} {v_asig_db.apellidos or ''}".strip()

        todos_listos = all(d.estado_preparacion == "Listo" for d in detalles_resumen) if detalles_resumen else True
        folio = orden.qr_transaccional_salida or f"ORD-{str(orden.id_orden)[:8].upper()}"

        # Filtro Específico: Cliente (Nombre, RUT, Teléfono)
        if busqueda_cliente and busqueda_cliente.strip():
            bc = busqueda_cliente.strip().upper()
            rut_c = (cliente_resumen.rut_cliente if cliente_resumen else "").upper()
            nom_c = f"{cliente_resumen.nombres if cliente_resumen else ''} {cliente_resumen.apellidos if cliente_resumen else ''}".upper()
            tel_c = (cliente_resumen.telefono if cliente_resumen else "").upper()
            rec_rut = (despacho_resumen.receptor_rut if despacho_resumen else "").upper()
            rec_nom = (despacho_resumen.receptor_nombres if despacho_resumen else "").upper()
            rec_tel = (despacho_resumen.receptor_telefono if despacho_resumen else "").upper()

            if not (bc in rut_c or bc in nom_c or bc in tel_c or bc in rec_rut or bc in rec_nom or bc in rec_tel):
                continue

        # Filtro Específico: Vendedor (Creador o Asignado)
        if busqueda_vendedor and busqueda_vendedor.strip():
            bv = busqueda_vendedor.strip().upper()
            vend_c = vendedor_nombre.upper()
            vend_a = (vendedor_asignado_nombre or "").upper()
            if not (bv in vend_c or bv in vend_a):
                continue

        # Filtro General (Compatibilidad)
        if term_busqueda:
            folio_upper = folio.upper()
            rut_upper = (cliente_resumen.rut_cliente if cliente_resumen else "").upper()
            nom_upper = f"{cliente_resumen.nombres if cliente_resumen else ''} {cliente_resumen.apellidos if cliente_resumen else ''}".upper()
            rec_rut_upper = (despacho_resumen.receptor_rut if despacho_resumen else "").upper()
            rec_nom_upper = (despacho_resumen.receptor_nombres if despacho_resumen else "").upper()
            vend_upper = vendedor_nombre.upper()
            vend_asig_upper = (vendedor_asignado_nombre or "").upper()

            matches = (
                term_busqueda in folio_upper
                or term_busqueda in rut_upper
                or term_busqueda in nom_upper
                or term_busqueda in rec_rut_upper
                or term_busqueda in rec_nom_upper
                or term_busqueda in vend_upper
                or term_busqueda in vend_asig_upper
                or any(term_busqueda in (d.titulo or "").upper() for d in detalles_resumen)
            )
            if not matches:
                continue

        items_response.append(
            EntregaEnvioItemResponse(
                id_orden=orden.id_orden,
                folio=folio,
                tipo_entrega=tipo_entrega_item,
                estado_orden=orden.estado_orden,
                total_venta=orden.total_venta,
                monto_pendiente=orden.monto_pendiente,
                qr_transaccional_salida=orden.qr_transaccional_salida,
                fecha_creacion=orden.fecha_creacion.isoformat() if orden.fecha_creacion else None,
                fecha_actualizacion=orden.fecha_actualizacion.isoformat() if orden.fecha_actualizacion else None,
                total_items=len(detalles_resumen),
                cliente=cliente_resumen,
                despacho=despacho_resumen,
                detalles=detalles_resumen,
                vendedor_nombre=vendedor_nombre,
                id_vendedor_asignado=orden.id_vendedor_asignado,
                vendedor_asignado_nombre=vendedor_asignado_nombre,
                preparacion_lista=todos_listos,
                todos_preparados=todos_listos,
            )
        )

    return items_response


@router.patch(
    "/{id_orden}/entregar",
    response_model=EntregaConfirmacionResponse,
    status_code=200,
    summary="Confirmar Entrega de Pedido en Tienda (Cierre de Ciclo)",
)
def confirmar_entrega_tienda(
    id_orden: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    orden = db.query(Orden_Venta).filter(Orden_Venta.id_orden == id_orden).first()
    if not orden:
        raise HTTPException(status_code=404, detail="Orden de venta no encontrada.")

    if orden.monto_pendiente > 0:
        raise HTTPException(
            status_code=400,
            detail=f"No se puede confirmar la entrega. La orden presenta un saldo pendiente de ${orden.monto_pendiente} que debe ser saldado en caja."
        )

    if orden.estado_orden in ["Despachada", "Completada"]:
        raise HTTPException(
            status_code=400,
            detail=f"La orden ya fue entregada anteriormente (Estado: {orden.estado_orden})."
        )

    try:
        # Actualizar Orden a 'Despachada'
        orden.estado_orden = "Despachada"
        orden.fecha_actualizacion = datetime.now()

        # Obtener o crear estado 'Entregado' / 'Finalizado'
        estado_final = db.query(Estado_Activo).filter(
            Estado_Activo.nombre_estado.in_(["Entregado", "Finalizado"])
        ).first()
        if not estado_final:
            estado_final = Estado_Activo(id_estado=6, nombre_estado="Entregado")
            db.add(estado_final)
            db.flush()

        detalles = db.query(Detalle_Orden).filter(Detalle_Orden.id_orden == orden.id_orden).all()
        activos_actualizados = 0

        for d in detalles:
            d.estado_preparacion = "Listo"
            d.fecha_preparacion = datetime.now()
            if d.id_activo:
                activo = db.query(Activo_Inventariado).filter(Activo_Inventariado.id_activo == d.id_activo).first()
                if activo:
                    activo.id_estado = estado_final.id_estado
                    activo.ubicacion_pasillo = None
                    activo.ubicacion_pallet = None
                    activo.ubicacion_galpon = None
                    activo.observacion_estado = f"Entregado en tienda por {current_user.nombres} {current_user.apellidos} - Orden #{str(orden.id_orden)[:8].upper()}"
                    activo.version_lock = (activo.version_lock or 1) + 1
                    activo.fecha_actualizacion = datetime.now()
                    activos_actualizados += 1

        db.commit()
        db.refresh(orden)

        folio = orden.qr_transaccional_salida or f"ORD-{str(orden.id_orden)[:8].upper()}"
        return EntregaConfirmacionResponse(
            id_orden=orden.id_orden,
            folio=folio,
            estado_orden=orden.estado_orden,
            mensaje="¡Entrega en tienda confirmada exitosamente! Orden actualizada a Despachada.",
            activos_finalizados=activos_actualizados,
            fecha_entrega=datetime.now().isoformat(),
        )
    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error transaccional al confirmar la entrega en tienda: {str(e)}"
        )


@router.patch(
    "/despachos/{id_despacho}/enviar",
    response_model=DespachoEnvioResponse,
    status_code=200,
    summary="Marcar Despacho como Enviado (Cierre de Ciclo)",
)
def marcar_despacho_enviado(
    id_despacho: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    despacho = db.query(Despacho).filter(Despacho.id_despacho == id_despacho).first()
    if not despacho:
        raise HTTPException(status_code=404, detail="Registro de despacho no encontrado.")

    orden = db.query(Orden_Venta).filter(Orden_Venta.id_orden == despacho.id_orden).first()
    if not orden:
        raise HTTPException(status_code=404, detail="Orden asociada al despacho no encontrada.")

    try:
        despacho.estado_despacho = "Enviado"
        despacho.fecha_actualizacion = datetime.now()

        orden.estado_orden = "Despachada"
        orden.fecha_actualizacion = datetime.now()

        estado_final = db.query(Estado_Activo).filter(
            Estado_Activo.nombre_estado.in_(["Entregado", "Finalizado"])
        ).first()
        if not estado_final:
            estado_final = Estado_Activo(id_estado=6, nombre_estado="Entregado")
            db.add(estado_final)
            db.flush()

        detalles = db.query(Detalle_Orden).filter(Detalle_Orden.id_orden == orden.id_orden).all()
        activos_actualizados = 0

        for d in detalles:
            d.estado_preparacion = "Listo"
            d.fecha_preparacion = datetime.now()
            if d.id_activo:
                activo = db.query(Activo_Inventariado).filter(Activo_Inventariado.id_activo == d.id_activo).first()
                if activo:
                    activo.id_estado = estado_final.id_estado
                    activo.ubicacion_pasillo = None
                    activo.ubicacion_pallet = None
                    activo.ubicacion_galpon = None
                    activo.observacion_estado = f"Despachado con transporte '{despacho.empresa_transporte or 'Externo'}' - Orden #{str(orden.id_orden)[:8].upper()}"
                    activo.version_lock = (activo.version_lock or 1) + 1
                    activo.fecha_actualizacion = datetime.now()
                    activos_actualizados += 1

        db.commit()
        db.refresh(despacho)
        db.refresh(orden)

        folio = orden.qr_transaccional_salida or f"ORD-{str(orden.id_orden)[:8].upper()}"
        return DespachoEnvioResponse(
            id_despacho=despacho.id_despacho,
            id_orden=orden.id_orden,
            folio=folio,
            estado_despacho=despacho.estado_despacho,
            estado_orden=orden.estado_orden,
            mensaje=f"¡Despacho #{str(despacho.id_despacho)[:8].upper()} marcado como Enviado exitosamente!",
            activos_finalizados=activos_actualizados,
            fecha_envio=datetime.now().isoformat(),
        )
    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error transaccional al marcar despacho como enviado: {str(e)}"
        )


@router.post(
    "/{id_orden}/pagar",
    response_model=OrdenPagoResponse,
    status_code=status.HTTP_200_OK,
    summary="Confirmar Pago de Orden y Generar QR Transaccional (HU-3.6)",
    description="Procesa la confirmación de pago por parte de la cajera. "
                "Crea el registro en Transaccion_Pago, liquida el monto pendiente, "
                "actualiza la orden a 'Pagada', asigna la cajera y genera el código "
                "QR transaccional único para el handshake con bodega."
)
@router.post(
    "/{id_orden}/pagar/",
    response_model=OrdenPagoResponse,
    status_code=status.HTTP_200_OK,
    include_in_schema=False
)
def pagar_orden(
    id_orden: uuid.UUID,
    pago_in: Optional[OrdenPagoRequest] = None,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    """
    Motor Transaccional de Pago y Generación de QR (ACID):
    1. Bloqueo y verificación de existencia de la orden.
    2. Validaciones de negocio:
       - No permite pagar órdenes en estado 'Pagada', 'Completada' o 'Anulada'.
       - Valida que la orden tenga saldo pendiente y que esté en estado 'Reservada'.
    3. Transacción atómica:
       - Generación del hash criptográfico único `qr_transaccional_salida`.
       - Registro de la transacción en la tabla `Transaccion_Pago`.
       - Actualización de `Orden_Venta`: estado_orden='Pagada', monto_pendiente=0, id_cajera, qr_transaccional_salida.
    4. Commit y emisión de respuesta para la App del Vendedor y habilitación en Bodega.
    """
    if pago_in is None:
        pago_in = OrdenPagoRequest()

    user_ident = f"{current_user.nombres} {current_user.apellidos or ''}".strip()
    print(f"\n💳 [PAGO] Iniciando procesamiento de pago para orden ID: {id_orden} por usuario: {user_ident} ({current_user.email})")

    orden = db.query(Orden_Venta).filter(Orden_Venta.id_orden == id_orden).first()
    if not orden:
        print(f"❌ [PAGO] Error: Orden con ID '{id_orden}' no encontrada.")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Orden con ID '{id_orden}' no encontrada."
        )

    # Validación de estados
    if orden.estado_orden in ["Pagada", "Completada"]:
        print(f"⚠️ [PAGO] Rechazo: La orden {id_orden} ya se encuentra en estado '{orden.estado_orden}'.")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"La orden ya se encuentra en estado '{orden.estado_orden}' y cuenta con pago confirmado."
        )

    if orden.estado_orden == "Anulada":
        print(f"⚠️ [PAGO] Rechazo: La orden {id_orden} está 'Anulada'.")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No se puede registrar un pago en una orden que ha sido 'Anulada'."
        )

    if orden.estado_orden != "Reservada":
        print(f"⚠️ [PAGO] Rechazo: Estado inválido '{orden.estado_orden}'.")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"No se puede pagar una orden en estado '{orden.estado_orden}'. Debe estar en estado 'Reservada'."
        )

    if orden.monto_pendiente <= 0:
        print(f"⚠️ [PAGO] Rechazo: La orden {id_orden} no tiene saldo pendiente (monto_pendiente={orden.monto_pendiente}).")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La orden no tiene saldo pendiente por pagar."
        )

    try:
        monto_a_pagar = pago_in.monto if pago_in.monto is not None else orden.monto_pendiente
        if monto_a_pagar <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="El monto a pagar debe ser mayor a 0."
            )

        # Generación de token único de alta entropía para el handshake QR
        # Formato: TX-QR-<ID_ORDEN_8>-<RANDOM_HEX_12>
        token_entropy = uuid.uuid4().hex[:12].upper()
        qr_token = f"TX-QR-{str(orden.id_orden)[:8].upper()}-{token_entropy}"
        print(f"🔑 [PAGO] QR Transaccional generado: {qr_token}")

        # 1. Registrar la transacción de pago en PostgreSQL
        nuevo_pago = Transaccion_Pago(
            id_pago=uuid.uuid4(),
            id_orden=orden.id_orden,
            monto=monto_a_pagar,
            metodo_pago=pago_in.metodo_pago or "Efectivo",
            estado_pago="Procesado",
            fecha_pago=datetime.now(),
        )
        db.add(nuevo_pago)
        print(f"📝 [PAGO] Registro de Transaccion_Pago creado: ID {nuevo_pago.id_pago} - Monto: ${monto_a_pagar} ({nuevo_pago.metodo_pago})")

        # 2. Actualizar la cabecera de la orden
        orden.estado_orden = "Pagada"
        orden.monto_pendiente = max(0, orden.monto_pendiente - monto_a_pagar)
        orden.id_cajera = current_user.id_usuario
        orden.qr_transaccional_salida = qr_token
        orden.fecha_actualizacion = datetime.now()

        # 3. Actualizar los repuestos físicos inventariados a estado 'Vendido' (ID 3)
        estado_vendido = db.query(Estado_Activo).filter(Estado_Activo.nombre_estado == "Vendido").first()
        if not estado_vendido:
            estado_vendido = Estado_Activo(id_estado=3, nombre_estado="Vendido")
            db.add(estado_vendido)
            db.flush()

        detalles = db.query(Detalle_Orden).filter(Detalle_Orden.id_orden == orden.id_orden).all()
        activos_vendidos = 0

        for d in detalles:
            if d.id_activo:
                activo = db.query(Activo_Inventariado).filter(Activo_Inventariado.id_activo == d.id_activo).first()
                if activo:
                    activo.id_estado = estado_vendido.id_estado
                    activo.version_lock = (activo.version_lock or 1) + 1
                    activo.fecha_actualizacion = datetime.now()
                    activos_vendidos += 1

        print(f"📦 [PAGO] {activos_vendidos} repuesto(s) físico(s) actualizados a estado 'Vendido' (ID {estado_vendido.id_estado}).")

        # 4. Confirmación atómica ACID
        db.commit()
        db.refresh(orden)
        db.refresh(nuevo_pago)

        print(f"✅ [PAGO] Pago procesado exitosamente para orden #{str(orden.id_orden)[:8].upper()}. "
              f"Estado: {orden.estado_orden}, Cajera: {user_ident}, Saldo pendiente: ${orden.monto_pendiente}")

        return OrdenPagoResponse(
            id_orden=orden.id_orden,
            id_pago=nuevo_pago.id_pago,
            estado_orden=orden.estado_orden,
            total_venta=orden.total_venta,
            monto_pagado=nuevo_pago.monto,
            monto_pendiente=orden.monto_pendiente,
            metodo_pago=nuevo_pago.metodo_pago,
            qr_transaccional_salida=orden.qr_transaccional_salida,
            id_cajera=orden.id_cajera,
            mensaje="Pago registrado exitosamente. Código QR transaccional emitido para entrega en bodega.",
            fecha_pago=nuevo_pago.fecha_pago.isoformat() if nuevo_pago.fecha_pago else datetime.now().isoformat(),
        )

    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        print(f"💥 [PAGO] Error crítico durante la transacción de pago: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error en la transacción de pago de la orden: {str(e)}"
        )


@router.post(
    "/{id_orden}/anular",
    response_model=OrdenAnulacionResponse,
    summary="Anular Orden, Reversar Pagos y Generar Logística Inversa (SPEC-HU-TAREA-4)",
    description="Anula una orden en el Mesón de Ventas, propaga la reversa de transacciones de pago "
                "y genera automáticamente tareas de reingreso (Logística Inversa) para PDA Bodega."
)
def anular_orden_post(
    id_orden: uuid.UUID,
    payload: Optional[AnularOrdenRequest] = None,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    rol_nombre = (current_user.nombre_rol or "").lower()
    es_vendedor_o_admin = current_user.id_rol in [2, 4, 5, 6, 7] or (
        "vendedor" in rol_nombre or "admin" in rol_nombre or "jefe" in rol_nombre or "gerente" in rol_nombre
    )
    if not es_vendedor_o_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permisos de ventas o administración para anular órdenes."
        )

    orden = db.query(Orden_Venta).filter(Orden_Venta.id_orden == id_orden).first()
    if not orden:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Orden con ID '{id_orden}' no encontrada."
        )

    if orden.estado_orden == "Anulada":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"La orden #{str(orden.id_orden)[:8].upper()} ya se encuentra anulada."
        )

    if orden.estado_orden == "Completada":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"No es posible anular la orden #{str(orden.id_orden)[:8].upper()} porque ya fue entregada/completada."
        )

    try:
        # Paso A: Cambiar estado de la orden a 'Anulada'
        orden.estado_orden = "Anulada"
        orden.monto_pendiente = 0
        orden.fecha_actualizacion = datetime.now(timezone.utc)

        # Paso B: Reversar pagos asociados
        pagos = db.query(Transaccion_Pago).filter(Transaccion_Pago.id_orden == id_orden).all()
        pagos_reversados = 0
        for pago in pagos:
            pago.estado_pago = "Anulado"
            pagos_reversados += 1

        # Paso C: Obtener activos físicos de la orden para cola de reingreso
        detalles = db.query(Detalle_Orden).filter(Detalle_Orden.id_orden == id_orden).all()
        activos_afectados = 0

        for d in detalles:
            if d.id_activo:
                activo = db.query(Activo_Inventariado).filter(Activo_Inventariado.id_activo == d.id_activo).first()
                if activo:
                    if activo.id_estado in [1, 7]:
                        activo.id_estado = 5  # Pendiente de paletizado / reingreso
                    activo.version_lock = (activo.version_lock or 1) + 1
                    activo.fecha_actualizacion = datetime.now(timezone.utc)
                    activos_afectados += 1

        db.commit()
        db.refresh(orden)

        mensaje = "Orden anulada, pagos reversados y tareas de reingreso generadas"
        return OrdenAnulacionResponse(
            id_orden=orden.id_orden,
            estado_orden=orden.estado_orden,
            mensaje=mensaje,
            msg=mensaje,
            activos_liberados=activos_afectados,
            pagos_reversados=pagos_reversados,
            motivo_anulacion=payload.motivo_anulacion if payload else None,
        )

    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error transaccional al anular la orden: {str(e)}"
        )


@router.patch(
    "/{id_orden}/anular",
    response_model=OrdenAnulacionResponse,
    summary="Anular Orden y Liberar Stock Directo (HU-3.5 Retrocompatibilidad)",
    description="Anula una orden en estado 'Reservada' y devuelve repuestos a 'Disponible'."
)
def anular_orden_patch(
    id_orden: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    rol_nombre = (current_user.nombre_rol or "").lower()
    es_vendedor_o_admin = current_user.id_rol in [2, 4, 5, 6, 7] or (
        "vendedor" in rol_nombre or "admin" in rol_nombre or "jefe" in rol_nombre or "gerente" in rol_nombre
    )
    if not es_vendedor_o_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permisos de ventas o administración para anular órdenes."
        )

    orden = db.query(Orden_Venta).filter(Orden_Venta.id_orden == id_orden).first()
    if not orden:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Orden con ID '{id_orden}' no encontrada."
        )

    if orden.estado_orden != "Reservada":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Solo se pueden anular órdenes en estado 'Reservada' (Pendientes de pago). "
                   f"La orden actual está en estado '{orden.estado_orden}'."
        )

    try:
        orden.estado_orden = "Anulada"
        orden.monto_pendiente = 0
        orden.fecha_actualizacion = datetime.now(timezone.utc)

        estado_disponible = db.query(Estado_Activo).filter(Estado_Activo.nombre_estado == "Disponible").first()
        if not estado_disponible:
            estado_disponible = Estado_Activo(id_estado=1, nombre_estado="Disponible")
            db.add(estado_disponible)
            db.flush()

        detalles = db.query(Detalle_Orden).filter(Detalle_Orden.id_orden == id_orden).all()
        activos_liberados = 0

        for d in detalles:
            if d.id_activo:
                activo = db.query(Activo_Inventariado).filter(Activo_Inventariado.id_activo == d.id_activo).first()
                if activo:
                    activo.id_estado = estado_disponible.id_estado
                    activo.version_lock = (activo.version_lock or 1) + 1
                    activos_liberados += 1

        db.commit()
        db.refresh(orden)

        mensaje = "Orden anulada exitosamente. Los repuestos inventariados han sido devueltos al catálogo como disponibles."
        return OrdenAnulacionResponse(
            id_orden=orden.id_orden,
            estado_orden=orden.estado_orden,
            mensaje=mensaje,
            msg=mensaje,
            activos_liberados=activos_liberados,
        )

    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error transaccional al anular la orden: {str(e)}"
        )


@router.patch(
    "/{id_orden}/instrucciones",
    response_model=InstruccionesUpdateResponse,
    summary="Actualizar Instrucciones Técnicas para Bodega",
    description="Modifica las notas de preparación técnica asociadas a los detalles de una orden."
)
def actualizar_instrucciones_bodega(
    id_orden: uuid.UUID,
    payload: InstruccionesUpdateRequest,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    orden = db.query(Orden_Venta).filter(Orden_Venta.id_orden == id_orden).first()
    if not orden:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Orden con ID '{id_orden}' no encontrada."
        )

    if orden.estado_orden in ["Anulada", "Completada"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"No se pueden modificar instrucciones en una orden con estado '{orden.estado_orden}'."
        )

    try:
        query_detalles = db.query(Detalle_Orden).filter(Detalle_Orden.id_orden == id_orden)

        if payload.id_detalle:
            query_detalles = query_detalles.filter(Detalle_Orden.id_detalle == payload.id_detalle)
            detalle = query_detalles.first()
            if not detalle:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Detalle con ID '{payload.id_detalle}' no encontrado en esta orden."
                )
            detalle.notas_preparacion = payload.notas_preparacion.strip()
            detalles_actualizados = 1
        else:
            detalles = query_detalles.all()
            if not detalles:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="La orden no contiene líneas de detalle para actualizar."
                )
            for d in detalles:
                d.notas_preparacion = payload.notas_preparacion.strip()
            detalles_actualizados = len(detalles)

        orden.fecha_actualizacion = datetime.now()
        db.commit()

        return InstruccionesUpdateResponse(
            id_orden=orden.id_orden,
            mensaje="Instrucciones técnicas de preparación actualizadas exitosamente.",
            notas_preparacion=payload.notas_preparacion.strip(),
            detalles_actualizados=detalles_actualizados,
        )
    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al actualizar las instrucciones de la orden: {str(e)}"
        )


@router.get(
    "/{id_orden}",
    summary="Obtener Detalle de Orden de Venta",
    description="Consulta la información de una orden específica por su UUID."
)
def obtener_orden(
    id_orden: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    orden = db.query(Orden_Venta).filter(Orden_Venta.id_orden == id_orden).first()
    if not orden:
        raise HTTPException(status_code=404, detail="Orden no encontrada")

    cliente = db.query(Cliente).filter(Cliente.id_cliente == orden.id_cliente).first()
    detalles = db.query(Detalle_Orden).filter(Detalle_Orden.id_orden == id_orden).all()
    despacho = db.query(Despacho).filter(Despacho.id_orden == id_orden).first()

    return {
        "id_orden": orden.id_orden,
        "estado_orden": orden.estado_orden,
        "total_venta": orden.total_venta,
        "monto_pendiente": orden.monto_pendiente,
        "qr_transaccional_salida": orden.qr_transaccional_salida,
        "fecha_creacion": orden.fecha_creacion.isoformat() if orden.fecha_creacion else None,
        "cliente": {
            "rut": cliente.rut_cliente if cliente else None,
            "nombres": cliente.nombres if cliente else None,
            "apellidos": cliente.apellidos if cliente else None,
            "telefono": cliente.telefono if cliente else None,
        } if cliente else None,
        "despacho": {
            "direccion_envio": despacho.direccion_envio,
            "receptor_nombres": despacho.receptor_nombres,
            "receptor_rut": despacho.receptor_rut,
            "receptor_telefono": despacho.receptor_telefono,
            "estado_despacho": despacho.estado_despacho,
            "empresa_transporte": despacho.empresa_transporte,
            "costo_envio": despacho.costo_envio,
        } if despacho else None,
        "detalles": [
            {
                "id_detalle": d.id_detalle,
                "id_activo": d.id_activo,
                "descripcion_manual": d.descripcion_manual,
                "notas_preparacion": d.notas_preparacion,
                "cantidad": d.cantidad,
                "precio_unitario": d.precio_unitario,
                "precio_final": d.precio_final,
                "preparacion_lista": d.preparacion_lista,
                "estado_preparacion": d.estado_preparacion,
            }
            for d in detalles
        ],
    }
