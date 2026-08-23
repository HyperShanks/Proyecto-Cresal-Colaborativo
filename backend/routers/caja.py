from typing import Optional, List
from datetime import datetime, timezone
from zoneinfo import ZoneInfo
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

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
)
from schemas import (
    CajaVerificarAccesoResponse,
    CobroPendienteItemResponse,
    CobroPendienteListResponse,
    ArticuloResumenDTO,
    BackorderEspecificacionesDTO,
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
