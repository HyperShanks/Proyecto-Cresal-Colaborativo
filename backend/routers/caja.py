import uuid
import math
from typing import Optional, List
from datetime import datetime, timezone, time, timedelta, date
from uuid import UUID
from zoneinfo import ZoneInfo
from fastapi import APIRouter, Depends, Query, HTTPException, status
from sqlalchemy.orm import Session, aliased

from database import get_db
from models import (
    Usuario,
    Cliente,
    Orden_Venta,
    Detalle_Orden,
    Reservas_Backorder,
    Activo_Inventariado,
    Vehiculo_Origen,
    Categoria_Activo,
    Transaccion_Pago,
    Auditoria_Barrera,
)
from schemas import (
    CajaVerificarAccesoResponse,
    CobroPendienteItemResponse,
    CobroPendienteListResponse,
    ArticuloResumenDTO,
    BackorderEspecificacionesDTO,
    TipoOperacionEnum,
    ModalidadCobroEnum,
    RegistrarCobroRequest,
    RegistrarCobroResponse,
    HistorialPagoDetalleDTO,
    HistorialArticuloDTO,
    HistorialMovimientoDTO,
    ResumenCuadreCajaDTO,
    HistorialOrdenItemResponse,
    HistorialCajaResponse,
)
from core.security import require_caja_role

router = APIRouter(
    prefix="/api/v1/caja",
    tags=["Caja"]
)

tz_chile = ZoneInfo("America/Santiago")


def format_chile_datetime(dt: Optional[datetime]) -> tuple[str, str, datetime]:
    if not dt:
        now_utc = datetime.now(timezone.utc)
        dt_chile = now_utc.astimezone(tz_chile)
        return dt_chile.strftime("%d/%m/%Y"), dt_chile.strftime("%H:%M"), now_utc
    if dt.tzinfo is None:
        dt_utc = dt.replace(tzinfo=timezone.utc)
    else:
        dt_utc = dt.astimezone(timezone.utc)
    dt_chile = dt_utc.astimezone(tz_chile)
    return dt_chile.strftime("%d/%m/%Y"), dt_chile.strftime("%H:%M"), dt_utc


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


@router.get(
    "/pendientes",
    response_model=CobroPendienteListResponse,
    summary="Listado de Cobros Pendientes (Ventas y Backorders)",
    description="Retorna la bandeja consolidada de órdenes de venta con saldo pendiente "
                "y reservas backorder para la sucursal física activa del operario de caja."
)
def obtener_cobros_pendientes(
    sucursal_id: int = Query(..., description="ID de la sucursal activa"),
    busqueda: Optional[str] = Query(None, description="Término de búsqueda multicriterio (Folio, RUT, Cliente, Vendedor)"),
    tipo_operacion: Optional[str] = Query("TODOS", description="Filtro de tipo: 'TODOS', 'VENTA', 'BACKORDER'"),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_caja_role),
):
    tipo_filtro = (tipo_operacion or "TODOS").strip().upper()
    items_resultado: List[CobroPendienteItemResponse] = []

    # ─────────────────────────────────────────────────────────────────────────
    # 1. CONSULTAR ÓRDENES DE VENTA PENDIENTES DE PAGO
    # ─────────────────────────────────────────────────────────────────────────
    if tipo_filtro in ["TODOS", "VENTA"]:
        ordenes_query = (
            db.query(Orden_Venta, Cliente, Usuario)
            .join(Cliente, Orden_Venta.id_cliente == Cliente.id_cliente)
            .join(Usuario, Orden_Venta.id_vendedor == Usuario.id_usuario)
            .filter(Orden_Venta.id_sucursal == sucursal_id)
            .filter(Orden_Venta.estado_orden.in_(["Reservada", "Pendiente"]))
            .filter(Orden_Venta.monto_pendiente > 0)
        ).all()

        for orden, cliente, vendedor in ordenes_query:
            # Obtener detalles de la orden
            detalles_raw = (
                db.query(Detalle_Orden, Activo_Inventariado, Vehiculo_Origen, Categoria_Activo)
                .outerjoin(Activo_Inventariado, Detalle_Orden.id_activo == Activo_Inventariado.id_activo)
                .outerjoin(Vehiculo_Origen, Activo_Inventariado.id_vehiculo == Vehiculo_Origen.id_vehiculo)
                .outerjoin(Categoria_Activo, Activo_Inventariado.id_categoria == Categoria_Activo.id_categoria)
                .filter(Detalle_Orden.id_orden == orden.id_orden)
            ).all()

            articulos_dto: List[ArticuloResumenDTO] = []
            for det, activo, vehiculo, categoria in detalles_raw:
                if activo:
                    tipo_art = "INVENTARIADO"
                    sku_art = activo.sku_qr_fisico
                    if det.descripcion_manual:
                        desc_art = det.descripcion_manual
                    else:
                        cat_str = categoria.nombre_categoria if categoria else "Repuesto"
                        veh_str = f"{vehiculo.marca} {vehiculo.modelo}" if vehiculo else ""
                        desc_art = f"{cat_str} {veh_str}".strip() or "Repuesto Inventariado"
                else:
                    tipo_art = "DESARME"
                    sku_art = None
                    desc_art = det.descripcion_manual or "Pieza en Desarme"

                precio_unit = det.precio_unitario if det.precio_unitario is not None else det.precio_final
                articulos_dto.append(
                    ArticuloResumenDTO(
                        cantidad=det.cantidad,
                        tipo=tipo_art,
                        descripcion=desc_art,
                        sku=sku_art,
                        precio=precio_unit,
                        subtotal=det.precio_final,
                    )
                )

            # Folio representativo
            if orden.qr_transaccional_salida and orden.qr_transaccional_salida.startswith("ORD-"):
                folio_doc = orden.qr_transaccional_salida
            else:
                folio_doc = f"ORD-{str(orden.id_orden).replace('-', '')[:4].upper()}"

            total_op = orden.total_venta
            monto_cobrar = orden.monto_pendiente
            abono_prev = max(0, total_op - monto_cobrar)

            fecha_fmt, hora_fmt, dt_utc = format_chile_datetime(orden.fecha_creacion)
            cliente_nombre = f"{cliente.nombres} {cliente.apellidos}".strip()
            vendedor_nombre = f"{vendedor.nombres} {vendedor.apellidos}".strip()

            item_dto = CobroPendienteItemResponse(
                id_referencia=orden.id_orden,
                folio_documento=folio_doc,
                tipo_operacion="VENTA",
                estado_documento=orden.estado_orden,
                cliente_nombre=cliente_nombre,
                cliente_rut=cliente.rut_cliente,
                vendedor_nombre=vendedor_nombre,
                fecha_emision=dt_utc,
                fecha_emision_formateada=fecha_fmt,
                hora_emision_formateada=hora_fmt,
                total_operacion=total_op,
                abono_previo=abono_prev,
                monto_a_cobrar=monto_cobrar,
                articulos=articulos_dto,
                especificaciones_backorder=None,
            )
            items_resultado.append(item_dto)

    # ─────────────────────────────────────────────────────────────────────────
    # 2. CONSULTAR RESERVAS BACKORDER PENDIENTES DE ABONO / CONFIRMACIÓN
    # ─────────────────────────────────────────────────────────────────────────
    if tipo_filtro in ["TODOS", "BACKORDER"]:
        reservas_query = (
            db.query(Reservas_Backorder, Cliente, Usuario, Categoria_Activo)
            .join(Cliente, Reservas_Backorder.id_cliente == Cliente.id_cliente)
            .join(Usuario, Reservas_Backorder.id_vendedor == Usuario.id_usuario)
            .outerjoin(Categoria_Activo, Reservas_Backorder.id_categoria_requerida == Categoria_Activo.id_categoria)
            .filter(Reservas_Backorder.id_sucursal_registro == sucursal_id)
            .filter(Reservas_Backorder.estado_reserva.in_(["Pendiente", "Reservada"]))
            .filter((Reservas_Backorder.precio_acordado - Reservas_Backorder.monto_abonado) > 0)
        ).all()

        for res, cliente, vendedor, categoria in reservas_query:
            folio_doc = f"RES-{str(res.id_reserva).replace('-', '')[:4].upper()}"
            total_op = res.precio_acordado
            abono_prev = res.monto_abonado
            monto_cobrar = res.precio_acordado - res.monto_abonado

            cat_nombre = categoria.nombre_categoria if categoria else "Repuesto Solicitado"
            transito_str = res.notas_preparacion or "En Tránsito Marítimo (Arribo est.: 10 días)"

            specs_dto = BackorderEspecificacionesDTO(
                marca=res.marca_requerida,
                modelo=res.modelo_requerido,
                anio=res.anio_requerido,
                categoria=cat_nombre,
                cilindrada=res.cilindrada_requerida,
                combustible=res.combustible_requerido,
                transito=transito_str,
            )

            fecha_fmt, hora_fmt, dt_utc = format_chile_datetime(res.fecha_creacion)
            cliente_nombre = f"{cliente.nombres} {cliente.apellidos}".strip()
            vendedor_nombre = f"{vendedor.nombres} {vendedor.apellidos}".strip()

            item_dto = CobroPendienteItemResponse(
                id_referencia=res.id_reserva,
                folio_documento=folio_doc,
                tipo_operacion="BACKORDER",
                estado_documento=res.estado_reserva,
                cliente_nombre=cliente_nombre,
                cliente_rut=cliente.rut_cliente,
                vendedor_nombre=vendedor_nombre,
                fecha_emision=dt_utc,
                fecha_emision_formateada=fecha_fmt,
                hora_emision_formateada=hora_fmt,
                total_operacion=total_op,
                abono_previo=abono_prev,
                monto_a_cobrar=monto_cobrar,
                articulos=[],
                especificaciones_backorder=specs_dto,
            )
            items_resultado.append(item_dto)

    # ─────────────────────────────────────────────────────────────────────────
    # 3. FILTRADO REACTIVO POR BÚSQUEDA MULTICRITERIO
    # ─────────────────────────────────────────────────────────────────────────
    if busqueda and busqueda.strip():
        q = busqueda.strip().lower()
        q_rut = q.replace(".", "").replace("-", "")

        def coincide(it: CobroPendienteItemResponse) -> bool:
            if q in it.folio_documento.lower():
                return True
            if q in it.cliente_nombre.lower():
                return True
            rut_clean = it.cliente_rut.lower().replace(".", "").replace("-", "")
            if q in it.cliente_rut.lower() or (q_rut and q_rut in rut_clean):
                return True
            if q in it.vendedor_nombre.lower():
                return True
            for art in it.articulos:
                if q in art.descripcion.lower():
                    return True
                if art.sku and q in art.sku.lower():
                    return True
            if it.especificaciones_backorder:
                bo = it.especificaciones_backorder
                if q in bo.marca.lower() or q in bo.modelo.lower() or q in bo.categoria.lower():
                    return True
            return False

        items_resultado = [it for it in items_resultado if coincide(it)]

    # Ordenar de más reciente a más antiguo
    items_resultado.sort(key=lambda x: x.fecha_emision, reverse=True)

    return CobroPendienteListResponse(
        total=len(items_resultado),
        sucursal_id=sucursal_id,
        items=items_resultado,
    )


@router.post(
    "/cobros/registrar",
    response_model=RegistrarCobroResponse,
    status_code=status.HTTP_200_OK,
    summary="Registrar Cobro Único o Dividido",
    description="Procesa y persiste el pago de una orden de venta o reserva backorder "
                "validando la cuadratura matemática, rol de caja y atomicidad ACID."
)
def registrar_cobro(
    payload: RegistrarCobroRequest,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_caja_role),
):
    """
    Endpoint transaccional para registro de cobros en caja (SPEC-HU-03).
    Soporta pago único o dividido (split payment) sobre Orden_Venta y Reservas_Backorder.
    """
    # 1. Validación de Cuadratura Matemática (CA-05)
    total_pagos = sum(p.monto for p in payload.pagos)
    if total_pagos != payload.monto_declarado:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Descuadre financiero: La suma de los métodos de pago (${total_pagos:,}) "
                   f"no coincide con el monto declarado a cobrar (${payload.monto_declarado:,})."
        )

    # 2. Validación de montos individuales > 0 (CA-06)
    for p in payload.pagos:
        if p.monto <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Todos los métodos de pago deben registrar un monto estrictamente mayor a $0."
            )

    transacciones_creadas_ids: List[uuid.UUID] = []
    now_utc = datetime.now(timezone.utc).replace(tzinfo=None)

    # 3. Bloque Transaccional ACID Obligatorio (RULES.md)
    try:
        if payload.tipo_operacion == TipoOperacionEnum.ORDEN:
            orden = db.query(Orden_Venta).filter(
                Orden_Venta.id_orden == payload.id_documento
            ).first()

            if not orden:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"No se encontró la Orden de Venta con ID {payload.id_documento}."
                )

            # Validación Anti-Sobrepago (CA-06)
            if payload.monto_declarado > orden.monto_pendiente:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Sobrepago rechazado: El monto a cobrar (${payload.monto_declarado:,}) "
                           f"supera el saldo pendiente de la orden (${orden.monto_pendiente:,})."
                )

            nuevo_saldo = orden.monto_pendiente - payload.monto_declarado
            qr_hash: Optional[str] = None

            # Transiciones de Estado y Hash QR (SPEC-HU-04 Sec 3.2 / Tarea 2)
            if nuevo_saldo == 0:
                orden.estado_orden = "Pagada"
                tiene_activos_inventariados = db.query(Detalle_Orden).filter(
                    Detalle_Orden.id_orden == orden.id_orden,
                    Detalle_Orden.id_activo.isnot(None)
                ).first() is not None

                if tiene_activos_inventariados:
                    qr_hash = f"TX-QR-{uuid.uuid4()}"
                    orden.qr_transaccional_salida = qr_hash
                else:
                    qr_hash = None
                    orden.qr_transaccional_salida = None
            else:
                orden.estado_orden = "Reservada"
                orden.qr_transaccional_salida = None

            orden.monto_pendiente = nuevo_saldo
            orden.id_cajera = current_user.id_usuario
            orden.fecha_actualizacion = now_utc

            folio_doc = f"ORD-{str(orden.id_orden).replace('-', '')[:4].upper()}"
            estado_resultado = orden.estado_orden

            # Registrar cada método en Transaccion_Pago
            for pago_item in payload.pagos:
                id_transaccion = uuid.uuid4()
                transaccion = Transaccion_Pago(
                    id_pago=id_transaccion,
                    id_orden=orden.id_orden,
                    id_reserva=None,
                    monto=pago_item.monto,
                    metodo_pago=pago_item.metodo.value,
                    estado_pago="Procesado",
                    fecha_pago=now_utc,
                )
                db.add(transaccion)
                transacciones_creadas_ids.append(id_transaccion)

        elif payload.tipo_operacion == TipoOperacionEnum.BACKORDER:
            reserva = db.query(Reservas_Backorder).filter(
                Reservas_Backorder.id_reserva == payload.id_documento
            ).first()

            if not reserva:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"No se encontró la Reserva Backorder con ID {payload.id_documento}."
                )

            saldo_pendiente_backorder = reserva.precio_acordado - reserva.monto_abonado
            if payload.monto_declarado > saldo_pendiente_backorder:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Sobrepago rechazado: El monto declarado (${payload.monto_declarado:,}) "
                           f"supera el saldo pendiente de la reserva (${saldo_pendiente_backorder:,})."
                )

            reserva.monto_abonado += payload.monto_declarado
            reserva.estado_reserva = "Confirmada"
            reserva.fecha_actualizacion = now_utc
            nuevo_saldo = reserva.precio_acordado - reserva.monto_abonado
            qr_hash = None

            folio_doc = f"RES-{str(reserva.id_reserva).replace('-', '')[:4].upper()}"
            estado_resultado = reserva.estado_reserva

            # Registrar cada método en Transaccion_Pago
            for pago_item in payload.pagos:
                id_transaccion = uuid.uuid4()
                transaccion = Transaccion_Pago(
                    id_pago=id_transaccion,
                    id_orden=None,
                    id_reserva=reserva.id_reserva,
                    monto=pago_item.monto,
                    metodo_pago=pago_item.metodo.value,
                    estado_pago="Procesado",
                    fecha_pago=now_utc,
                )
                db.add(transaccion)
                transacciones_creadas_ids.append(id_transaccion)

        db.commit()

    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error transaccional al registrar el cobro: {str(e)}"
        )

    return RegistrarCobroResponse(
        success=True,
        mensaje=f"Cobro registrado exitosamente para el documento {folio_doc}.",
        folio=folio_doc,
        monto_cobrado=payload.monto_declarado,
        nuevo_saldo_pendiente=nuevo_saldo,
        estado_actualizado=estado_resultado,
        transacciones_ids=transacciones_creadas_ids,
        qr_generado=qr_hash,
    )


def format_clp(amount: int) -> str:
    """Formatea enteros a moneda CLP (ej: 420000 -> $420.000)."""
    return f"${amount:,}".replace(",", ".")


def parse_periodo_chile(
    periodo: Optional[str],
    fecha_desde: Optional[str] = None,
    fecha_hasta: Optional[str] = None,
) -> tuple[Optional[datetime], Optional[datetime]]:
    """
    Calcula los límites temporales en UTC correspondientes al huso horario de Chile (America/Santiago).
    """
    p = (periodo or "HOY").strip().upper()
    ahora_chile = datetime.now(tz_chile)

    if p == "HOY":
        start_local = datetime.combine(ahora_chile.date(), time.min, tzinfo=tz_chile)
        end_local = datetime.combine(ahora_chile.date(), time.max, tzinfo=tz_chile)
    elif p == "ESTA_SEMANA":
        lunes = ahora_chile.date() - timedelta(days=ahora_chile.weekday())
        domingo = lunes + timedelta(days=6)
        start_local = datetime.combine(lunes, time.min, tzinfo=tz_chile)
        end_local = datetime.combine(domingo, time.max, tzinfo=tz_chile)
    elif p == "ESTE_MES":
        primer_dia = ahora_chile.date().replace(day=1)
        if primer_dia.month == 12:
            prox_mes = primer_dia.replace(year=primer_dia.year + 1, month=1)
        else:
            prox_mes = primer_dia.replace(month=primer_dia.month + 1)
        ultimo_dia = prox_mes - timedelta(days=1)
        start_local = datetime.combine(primer_dia, time.min, tzinfo=tz_chile)
        end_local = datetime.combine(ultimo_dia, time.max, tzinfo=tz_chile)
    elif p == "RANGO":
        if not fecha_desde or not fecha_hasta:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="fecha_desde y fecha_hasta son obligatorias para el período RANGO.",
            )
        try:
            d_desde = datetime.strptime(str(fecha_desde).strip(), "%Y-%m-%d").date()
            d_hasta = datetime.strptime(str(fecha_hasta).strip(), "%Y-%m-%d").date()
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Formato de fecha inválido. Debe ser YYYY-MM-DD.",
            )
        if d_desde > d_hasta:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="fecha_desde no puede ser posterior a fecha_hasta.",
            )
        start_local = datetime.combine(d_desde, time.min, tzinfo=tz_chile)
        end_local = datetime.combine(d_hasta, time.max, tzinfo=tz_chile)
    elif p == "TODOS":
        return None, None
    else:
        start_local = datetime.combine(ahora_chile.date(), time.min, tzinfo=tz_chile)
        end_local = datetime.combine(ahora_chile.date(), time.max, tzinfo=tz_chile)

    start_utc = start_local.astimezone(timezone.utc).replace(tzinfo=None)
    end_utc = end_local.astimezone(timezone.utc).replace(tzinfo=None)
    return start_utc, end_utc


@router.get(
    "/historial",
    response_model=HistorialCajaResponse,
    summary="Historial de Órdenes y Auditoría de Cobros",
    description="Retorna el historial paginado de órdenes y transacciones de caja, con filtros multicriterio, "
                "métricas agregadas de cuadre/arqueo y trazabilidad detallada de pagos e ítems."
)
def obtener_historial_caja(
    sucursal_id: int = Query(..., description="ID de la sucursal activa"),
    periodo: Optional[str] = Query("HOY", description="Atajo de período: 'HOY', 'ESTA_SEMANA', 'ESTE_MES', 'RANGO', 'TODOS'"),
    fecha_desde: Optional[str] = Query(None, description="Fecha de inicio YYYY-MM-DD (para período RANGO)"),
    fecha_hasta: Optional[str] = Query(None, description="Fecha de término YYYY-MM-DD (para período RANGO)"),
    estado_orden: Optional[str] = Query("TODOS", description="Filtro de estado: 'TODOS', 'Pagada', 'Despachada', 'Anulada'"),
    metodo_pago: Optional[str] = Query("TODOS", description="Filtro de método: 'TODOS', 'Efectivo', 'Débito', 'Crédito', 'Transferencia', 'Cheque'"),
    busqueda: Optional[str] = Query(None, description="Búsqueda por Folio, RUT, Cliente, Vendedor o Cajera"),
    monto_min: Optional[int] = Query(None, description="Monto mínimo de venta"),
    monto_max: Optional[int] = Query(None, description="Monto máximo de venta"),
    id_cajera: Optional[UUID] = Query(None, description="ID del usuario cajera"),
    id_vendedor: Optional[UUID] = Query(None, description="ID del usuario vendedor"),
    pagina: int = Query(1, ge=1, description="Número de página"),
    limite: int = Query(20, ge=1, le=100, description="Registros por página"),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_caja_role),
):
    start_utc, end_utc = parse_periodo_chile(periodo, fecha_desde, fecha_hasta)

    UsuarioVendedor = aliased(Usuario, name="vendedor")
    UsuarioCajera = aliased(Usuario, name="cajera")

    query = (
        db.query(Orden_Venta, Cliente, UsuarioVendedor, UsuarioCajera)
        .join(Cliente, Orden_Venta.id_cliente == Cliente.id_cliente)
        .join(UsuarioVendedor, Orden_Venta.id_vendedor == UsuarioVendedor.id_usuario)
        .outerjoin(UsuarioCajera, Orden_Venta.id_cajera == UsuarioCajera.id_usuario)
        .filter(Orden_Venta.id_sucursal == sucursal_id)
        .filter(Orden_Venta.estado_orden != "Reservada")
    )

    if start_utc is not None and end_utc is not None:
        query = query.filter(Orden_Venta.fecha_creacion.between(start_utc, end_utc))

    if estado_orden and estado_orden.strip().upper() != "TODOS":
        query = query.filter(Orden_Venta.estado_orden == estado_orden.strip())

    if id_cajera:
        query = query.filter(Orden_Venta.id_cajera == id_cajera)

    if id_vendedor:
        query = query.filter(Orden_Venta.id_vendedor == id_vendedor)

    if monto_min is not None:
        query = query.filter(Orden_Venta.total_venta >= monto_min)

    if monto_max is not None:
        query = query.filter(Orden_Venta.total_venta <= monto_max)

    resultados_raw = query.order_by(Orden_Venta.fecha_creacion.desc()).all()

    items_filtrados: List[HistorialOrdenItemResponse] = []

    for orden, cliente, vendedor, cajera in resultados_raw:
        # Obtener pagos
        pagos_db = (
            db.query(Transaccion_Pago)
            .filter(Transaccion_Pago.id_orden == orden.id_orden)
            .order_by(Transaccion_Pago.fecha_pago.asc())
            .all()
        )

        desglose_pagos = [
            HistorialPagoDetalleDTO(
                id_transaccion=p.id_pago,
                metodo_pago=p.metodo_pago,
                monto=p.monto,
                fecha_pago=p.fecha_pago,
            )
            for p in pagos_db
        ]

        # Filtro por método de pago
        if metodo_pago and metodo_pago.strip().upper() != "TODOS":
            mp_filtro = metodo_pago.strip().lower()
            encontrado = any(mp_filtro in (p.metodo_pago or "").lower() for p in pagos_db)
            if not encontrado:
                continue

        # Obtener detalles de repuestos/artículos
        detalles_raw = (
            db.query(Detalle_Orden, Activo_Inventariado, Vehiculo_Origen, Categoria_Activo)
            .outerjoin(Activo_Inventariado, Detalle_Orden.id_activo == Activo_Inventariado.id_activo)
            .outerjoin(Vehiculo_Origen, Activo_Inventariado.id_vehiculo == Vehiculo_Origen.id_vehiculo)
            .outerjoin(Categoria_Activo, Activo_Inventariado.id_categoria == Categoria_Activo.id_categoria)
            .filter(Detalle_Orden.id_orden == orden.id_orden)
        ).all()

        articulos_dto: List[HistorialArticuloDTO] = []
        for det, activo, vehiculo, categoria in detalles_raw:
            if activo:
                tipo_art = "INVENTARIADO"
                sku_art = activo.sku_qr_fisico
                if det.descripcion_manual:
                    desc_art = det.descripcion_manual
                else:
                    cat_str = categoria.nombre_categoria if categoria else "Repuesto"
                    veh_str = f"{vehiculo.marca} {vehiculo.modelo}" if vehiculo else ""
                    desc_art = f"{cat_str} {veh_str}".strip() or "Repuesto Inventariado"
            else:
                tipo_art = "DESARME"
                sku_art = None
                desc_art = det.descripcion_manual or "Pieza en Desarme"

            precio_unit = det.precio_unitario if det.precio_unitario is not None else det.precio_final
            articulos_dto.append(
                HistorialArticuloDTO(
                    cantidad=det.cantidad,
                    tipo=tipo_art,
                    descripcion=desc_art,
                    sku=sku_art,
                    precio=precio_unit,
                    subtotal=det.precio_final,
                )
            )

        # Folio
        if orden.qr_transaccional_salida and orden.qr_transaccional_salida.startswith("ORD-"):
            folio_doc = orden.qr_transaccional_salida
        else:
            folio_doc = f"ORD-{str(orden.id_orden).replace('-', '')[:4].upper()}"

        fecha_fmt, hora_fmt, dt_utc = format_chile_datetime(orden.fecha_creacion)
        dt_chile = dt_utc.astimezone(tz_chile)
        fecha_iso = dt_chile.strftime("%Y-%m-%d")
        fecha_hora_fmt = f"{hora_fmt} - {fecha_fmt}"

        cliente_nombre = f"{cliente.nombres} {cliente.apellidos}".strip()
        vendedor_nombre = f"{vendedor.nombres} {vendedor.apellidos}".strip()
        cajera_nombre = f"{cajera.nombres} {cajera.apellidos}".strip() if cajera else "Caja 01"

        # Métodos Resumen String
        if desglose_pagos:
            metodos_resumen = " + ".join([f"{p.metodo_pago}: {format_clp(p.monto)}" for p in desglose_pagos])
            modalidad = "split" if len(desglose_pagos) > 1 else "unico"
            total_liquidado = sum(p.monto for p in desglose_pagos)
        else:
            metodos_resumen = "Sin pagos registrados" if orden.estado_orden != "Anulada" else "Anulada"
            modalidad = "unico"
            total_liquidado = max(0, orden.total_venta - orden.monto_pendiente)

        abono_prev = max(0, orden.total_venta - orden.monto_pendiente - total_liquidado)

        # Historial de movimientos (auditoría cronológica)
        movimientos: List[HistorialMovimientoDTO] = [
            HistorialMovimientoDTO(
                hora=hora_fmt,
                evento=f"Orden emitida en Mesón por {vendedor_nombre}",
            )
        ]

        if desglose_pagos:
            pago_hora_fmt = hora_fmt
            if desglose_pagos[0].fecha_pago:
                _, p_hora, _ = format_chile_datetime(desglose_pagos[0].fecha_pago)
                pago_hora_fmt = p_hora
            movimientos.append(
                HistorialMovimientoDTO(
                    hora=pago_hora_fmt,
                    evento=f"Pago liquidado en ventanilla ({metodos_resumen}) por {cajera_nombre}",
                )
            )

        if orden.qr_transaccional_salida:
            movimientos.append(
                HistorialMovimientoDTO(
                    hora=hora_fmt,
                    evento="QR Transaccional generado para barrera de salida",
                )
            )

        auditoria_barrera = (
            db.query(Auditoria_Barrera)
            .filter(Auditoria_Barrera.id_orden == orden.id_orden)
            .first()
        )
        if auditoria_barrera:
            _, b_hora, _ = format_chile_datetime(auditoria_barrera.fecha_escaneo)
            movimientos.append(
                HistorialMovimientoDTO(
                    hora=b_hora,
                    evento="Pieza entregada en mesón y validada en barrera de salida",
                )
            )

        item = HistorialOrdenItemResponse(
            id_orden=orden.id_orden,
            folio=folio_doc,
            tipo_operacion="VENTA",
            emite_qr=bool(orden.qr_transaccional_salida),
            fecha_iso=fecha_iso,
            hora=hora_fmt,
            fecha_hora_formateada=fecha_hora_fmt,
            cliente_nombre=cliente_nombre,
            cliente_rut=cliente.rut_cliente,
            vendedor_nombre=vendedor_nombre,
            cajera_nombre=cajera_nombre,
            estado_orden=orden.estado_orden,
            modalidad_pago=modalidad,
            metodos_resumen=metodos_resumen,
            total_venta=orden.total_venta,
            abono_previo=abono_prev,
            total_liquidado=total_liquidado,
            desglose_pagos=desglose_pagos,
            articulos=articulos_dto,
            historial_movimientos=movimientos,
        )

        items_filtrados.append(item)

    # Filtro reactivo de búsqueda multicriterio
    if busqueda and busqueda.strip():
        def strip_accents(s: str) -> str:
            import unicodedata
            return "".join(c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn").lower()

        q_raw = busqueda.strip().lower()
        q = strip_accents(q_raw)
        q_rut = q.replace(".", "").replace("-", "")

        def match_search(it: HistorialOrdenItemResponse) -> bool:
            if q in strip_accents(it.folio):
                return True
            if q in strip_accents(it.cliente_nombre):
                return True
            rut_clean = (it.cliente_rut or "").lower().replace(".", "").replace("-", "")
            if (it.cliente_rut and q in it.cliente_rut.lower()) or (q_rut and q_rut in rut_clean):
                return True
            if q in strip_accents(it.vendedor_nombre) or q in strip_accents(it.cajera_nombre):
                return True
            for art in it.articulos:
                if q in strip_accents(art.descripcion) or (art.sku and q in strip_accents(art.sku)):
                    return True
            return False

        items_filtrados = [it for it in items_filtrados if match_search(it)]

    # Cálculo exacto de resumen_cuadre (excluyendo órdenes en estado 'Anulada')
    tot_recaudado = 0
    tot_ordenes_pag = 0
    tot_efectivo = 0
    tot_debito = 0
    tot_credito = 0
    tot_transferencia = 0
    tot_cheque = 0

    for it in items_filtrados:
        if it.estado_orden == "Anulada":
            continue

        if it.estado_orden in ["Pagada", "Despachada"]:
            tot_ordenes_pag += 1

        for p in it.desglose_pagos:
            mp = (p.metodo_pago or "").lower()
            if "efectivo" in mp:
                tot_efectivo += p.monto
            elif "débito" in mp or "debito" in mp:
                tot_debito += p.monto
            elif "crédito" in mp or "credito" in mp:
                tot_credito += p.monto
            elif "transferencia" in mp:
                tot_transferencia += p.monto
            elif "cheque" in mp:
                tot_cheque += p.monto
            else:
                tot_efectivo += p.monto

    tot_pos = tot_debito + tot_credito
    tot_recaudado = tot_efectivo + tot_pos + tot_transferencia + tot_cheque

    resumen = ResumenCuadreCajaDTO(
        total_recaudado=tot_recaudado,
        total_ordenes_pagadas=tot_ordenes_pag,
        total_efectivo=tot_efectivo,
        total_pos=tot_pos,
        total_debito=tot_debito,
        total_credito=tot_credito,
        total_transferencia=tot_transferencia,
        total_cheque=tot_cheque,
    )

    # Paginación
    total_registros = len(items_filtrados)
    total_paginas = max(1, math.ceil(total_registros / limite))
    offset = (pagina - 1) * limite
    paginated_items = items_filtrados[offset: offset + limite]

    return HistorialCajaResponse(
        total_registros=total_registros,
        pagina_actual=pagina,
        limite_por_pagina=limite,
        total_paginas=total_paginas,
        resumen_cuadre=resumen,
        items=paginated_items,
    )
