# backend/routers/gerencia.py
"""
Router de Gerencia: Dashboard Ejecutivo y Analítica en Tiempo Real (HU-5.1).
Implemento los endpoints de consulta analítica de alto nivel para consolidar
el pulso financiero y la carga operativa de bodega.
"""

from datetime import datetime, time, timezone
from typing import Optional, List
import uuid
from zoneinfo import ZoneInfo
from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy import or_, and_, not_, func, cast, String
from sqlalchemy.orm import Session

from database import get_db
from models import (
    Usuario,
    Orden_Venta,
    Transaccion_Pago,
    Detalle_Orden,
    Activo_Inventariado,
    Estado_Activo,
    Despacho,
    Cliente,
    Sucursal,
    Categoria_Activo,
    Reservas_Backorder,
    Vehiculo_Origen,
    Auditoria_Barrera,
)
from core.security import (
    require_gerencia_role,
    require_gerencia_o_auditor_central,
    require_gerencia_jefe_ventas_o_auditor_central,
)
from schemas import (
    KpiFinancieroDTO,
    ResumenPagosDTO,
    DesglosePagoDTO,
    FlujoOperativoDTO,
    BackorderGerenciaItemDTO,
    BackorderGerenciaListResponse,
    BackorderGerenciaKpisDTO,
    SucursalGerenciaDTO,
    BackorderAuditoriaResponseDTO,
    BackorderPagoDetalleDTO,
    BackorderMovimientoDTO,
    PrediccionVentasStockResponseDTO,
)
from services.ml_prediction_service import generar_prediccion_ventas_y_stock

# Inicializo el router con el prefijo /api/v1/gerencia y tag para Swagger
router = APIRouter(
    prefix="/api/v1/gerencia",
    tags=["Gerencia - Dashboard Ejecutivo"],
)

tz_chile = ZoneInfo("America/Santiago")


def calcular_limites_temporales_chile():
    """
    Calculo los límites de inicio y fin de hoy, junto al primer día del mes
    (MTD) en hora local chilena (America/Santiago) y los convierto a UTC.
    """
    ahora_chile = datetime.now(tz_chile)

    # Ventas de hoy: desde 00:00:00 hasta 23:59:59.999999 de hoy en Chile
    inicio_hoy_local = datetime.combine(
        ahora_chile.date(), time.min, tzinfo=tz_chile
    )
    fin_hoy_local = datetime.combine(
        ahora_chile.date(), time.max, tzinfo=tz_chile
    )
    inicio_hoy_utc = (
        inicio_hoy_local.astimezone(timezone.utc).replace(tzinfo=None)
    )
    fin_hoy_utc = (
        fin_hoy_local.astimezone(timezone.utc).replace(tzinfo=None)
    )

    # Acumulado MTD: desde el primer día del mes actual a las 00:00:00
    primer_dia_mes = ahora_chile.date().replace(day=1)
    inicio_mes_local = datetime.combine(
        primer_dia_mes, time.min, tzinfo=tz_chile
    )
    inicio_mes_utc = (
        inicio_mes_local.astimezone(timezone.utc).replace(tzinfo=None)
    )

    return inicio_hoy_utc, fin_hoy_utc, inicio_mes_utc


@router.get(
    "/sucursales",
    response_model=List[SucursalGerenciaDTO],
    summary="Listado de Sucursales Activas para Gerencia",
    description="Retorna las sucursales existentes en el sistema para alternar el filtro multi-sucursal.",
)
def obtener_sucursales_gerencia(
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_gerencia_role),
):
    """
    Retorna el catálogo dinámico de sucursales activas en la BD, identificando Casa Matriz.
    """
    sucursales = (
        db.query(Sucursal)
        .filter(Sucursal.estado == "Activo")
        .order_by(Sucursal.id_sucursal)
        .all()
    )
    resultado = []
    for suc in sucursales:
        nombre = suc.nombre_sucursal or f"Sucursal {suc.id_sucursal}"
        # Identificar si es casa matriz por id_sucursal == 1 o por coincidencia en el nombre
        es_matriz = (suc.id_sucursal == 1) or ("matriz" in nombre.lower())
        resultado.append(
            SucursalGerenciaDTO(
                id_sucursal=suc.id_sucursal,
                nombre_sucursal=nombre,
                es_casa_matriz=es_matriz,
            )
        )
    return resultado


@router.get(
    "/dashboard/kpis",
    response_model=KpiFinancieroDTO,
    summary="Métricas Financieras Superiores del Dashboard",
    description="Retorna ventas hoy, transacciones, MTD y ticket promedio.",
)
def obtener_kpis_financieros(
    id_sucursal: Optional[int] = Query(
        None,
        description="ID de sucursal. Si se omite, consolida toda la cadena.",
    ),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_gerencia_o_auditor_central),
):
    """
    Calculo los KPIs financieros en tiempo real.
    Filtro transacciones con estado_pago = 'Procesado' y excluyo anuladas.
    """
    inicio_hoy_utc, fin_hoy_utc, inicio_mes_utc = (
        calcular_limites_temporales_chile()
    )

    # 1. Consulto los pagos procesados de hoy
    query_pagos_hoy = (
        db.query(Transaccion_Pago)
        .outerjoin(Orden_Venta, Transaccion_Pago.id_orden == Orden_Venta.id_orden)
        .outerjoin(Reservas_Backorder, Transaccion_Pago.id_reserva == Reservas_Backorder.id_reserva)
        .filter(
            Transaccion_Pago.estado_pago == "Procesado",
            Transaccion_Pago.fecha_pago.between(inicio_hoy_utc, fin_hoy_utc),
            or_(Orden_Venta.estado_orden.is_(None), Orden_Venta.estado_orden != "Anulada"),
            or_(Reservas_Backorder.estado_reserva.is_(None), Reservas_Backorder.estado_reserva != "Anulada"),
        )
    )
    if id_sucursal is not None:
        query_pagos_hoy = query_pagos_hoy.filter(
            or_(
                Orden_Venta.id_sucursal == id_sucursal,
                Reservas_Backorder.id_sucursal_registro == id_sucursal,
            )
        )

    pagos_hoy = query_pagos_hoy.all()
    ventas_del_dia = sum(p.monto for p in pagos_hoy)

    # Identifico las transacciones pagadas de hoy
    ordenes_hoy_ids = {
        p.id_orden or p.id_reserva for p in pagos_hoy if (p.id_orden is not None or p.id_reserva is not None)
    }
    transacciones_hoy = len(ordenes_hoy_ids)

    # Calculo el ticket promedio de las ventas de hoy
    ticket_promedio = (
        round(float(ventas_del_dia) / float(transacciones_hoy), 2)
        if transacciones_hoy > 0
        else 0.0
    )

    # 2. Consulto el acumulado mensual MTD
    query_mtd = (
        db.query(Transaccion_Pago)
        .outerjoin(Orden_Venta, Transaccion_Pago.id_orden == Orden_Venta.id_orden)
        .outerjoin(Reservas_Backorder, Transaccion_Pago.id_reserva == Reservas_Backorder.id_reserva)
        .filter(
            Transaccion_Pago.estado_pago == "Procesado",
            Transaccion_Pago.fecha_pago.between(inicio_mes_utc, fin_hoy_utc),
            or_(Orden_Venta.estado_orden.is_(None), Orden_Venta.estado_orden != "Anulada"),
            or_(Reservas_Backorder.estado_reserva.is_(None), Reservas_Backorder.estado_reserva != "Anulada"),
        )
    )
    if id_sucursal is not None:
        query_mtd = query_mtd.filter(
            or_(
                Orden_Venta.id_sucursal == id_sucursal,
                Reservas_Backorder.id_sucursal_registro == id_sucursal,
            )
        )

    pagos_mtd = query_mtd.all()
    acumulado_mensual_mtd = sum(p.monto for p in pagos_mtd)

    # 3. Salidas en Tiempo Real: Motores y Cajas Inventariadas de hoy
    ordenes_salidas_ids = {
        p.id_orden for p in pagos_hoy if p.id_orden is not None
    }
    query_ordenes_activas_hoy = (
        db.query(Orden_Venta.id_orden)
        .filter(
            Orden_Venta.estado_orden.in_(["Pagada", "Despachada", "Completada"]),
            func.coalesce(Orden_Venta.fecha_actualizacion, Orden_Venta.fecha_creacion).between(inicio_hoy_utc, fin_hoy_utc),
            Orden_Venta.estado_orden != "Anulada",
        )
    )
    if id_sucursal is not None:
        query_ordenes_activas_hoy = query_ordenes_activas_hoy.filter(
            Orden_Venta.id_sucursal == id_sucursal
        )
    for r in query_ordenes_activas_hoy.all():
        ordenes_salidas_ids.add(r[0])

    salidas_motores_hoy = 0
    salidas_cajas_hoy = 0

    if ordenes_salidas_ids:
        detalles_inventariados = (
            db.query(
                Detalle_Orden.cantidad,
                Activo_Inventariado.sku_qr_fisico,
                Categoria_Activo.nombre_categoria,
            )
            .join(Activo_Inventariado, Detalle_Orden.id_activo == Activo_Inventariado.id_activo)
            .outerjoin(Categoria_Activo, Activo_Inventariado.id_categoria == Categoria_Activo.id_categoria)
            .filter(Detalle_Orden.id_orden.in_(ordenes_salidas_ids))
            .all()
        )
        for cant, sku, nom_cat in detalles_inventariados:
            sku_upper = (sku or "").strip().upper()
            cat_upper = (nom_cat or "").strip().upper()
            c = cant if (cant and cant > 0) else 1
            if sku_upper.startswith("MOT-") or "MOTOR" in cat_upper:
                salidas_motores_hoy += c
            elif sku_upper.startswith("CAJ-") or "CAJA" in cat_upper or "TRANSMISI" in cat_upper:
                salidas_cajas_hoy += c

    reservas_pagadas_hoy_ids = {
        p.id_reserva for p in pagos_hoy if p.id_reserva is not None
    }
    if reservas_pagadas_hoy_ids:
        query_reservas_activos = (
            db.query(
                Activo_Inventariado.sku_qr_fisico,
                Categoria_Activo.nombre_categoria,
            )
            .join(Reservas_Backorder, Reservas_Backorder.id_activo_asignado == Activo_Inventariado.id_activo)
            .outerjoin(Categoria_Activo, Activo_Inventariado.id_categoria == Categoria_Activo.id_categoria)
            .filter(
                Reservas_Backorder.id_reserva.in_(reservas_pagadas_hoy_ids),
                Reservas_Backorder.estado_reserva != "Anulada",
                or_(
                    Reservas_Backorder.id_orden.is_(None),
                    not_(Reservas_Backorder.id_orden.in_(ordenes_salidas_ids)),
                ),
            )
            .all()
        )
        for sku, nom_cat in query_reservas_activos:
            sku_upper = (sku or "").strip().upper()
            cat_upper = (nom_cat or "").strip().upper()
            if sku_upper.startswith("MOT-") or "MOTOR" in cat_upper:
                salidas_motores_hoy += 1
            elif sku_upper.startswith("CAJ-") or "CAJA" in cat_upper or "TRANSMISI" in cat_upper:
                salidas_cajas_hoy += 1

    total_salidas_hoy = salidas_motores_hoy + salidas_cajas_hoy

    return KpiFinancieroDTO(
        ventas_del_dia=ventas_del_dia,
        transacciones_hoy=transacciones_hoy,
        acumulado_mensual_mtd=acumulado_mensual_mtd,
        ticket_promedio=ticket_promedio,
        margen_bruto=64.8,
        salidas_motores_hoy=salidas_motores_hoy,
        salidas_cajas_hoy=salidas_cajas_hoy,
        total_salidas_hoy=total_salidas_hoy,
    )


@router.get(
    "/dashboard/pagos",
    response_model=ResumenPagosDTO,
    summary="Desglose y Comparativa de Medios de Pago",
    description="Retorna distribución de recaudación de hoy por canal.",
)
def obtener_resumen_pagos(
    id_sucursal: Optional[int] = Query(
        None,
        description="ID de sucursal. Si se omite, consolida toda la cadena.",
    ),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_gerencia_o_auditor_central),
):
    """
    Agrupo los métodos de pago de hoy para generar el gráfico Donut.
    Clasifico en efectivo_fisico y canales_electronicos.
    """
    inicio_hoy_utc, fin_hoy_utc, _ = calcular_limites_temporales_chile()

    query_pagos = (
        db.query(Transaccion_Pago)
        .outerjoin(Orden_Venta, Transaccion_Pago.id_orden == Orden_Venta.id_orden)
        .outerjoin(Reservas_Backorder, Transaccion_Pago.id_reserva == Reservas_Backorder.id_reserva)
        .filter(
            Transaccion_Pago.estado_pago == "Procesado",
            Transaccion_Pago.fecha_pago.between(inicio_hoy_utc, fin_hoy_utc),
            or_(Orden_Venta.estado_orden.is_(None), Orden_Venta.estado_orden != "Anulada"),
            or_(Reservas_Backorder.estado_reserva.is_(None), Reservas_Backorder.estado_reserva != "Anulada"),
        )
    )
    if id_sucursal is not None:
        query_pagos = query_pagos.filter(
            or_(
                Orden_Venta.id_sucursal == id_sucursal,
                Reservas_Backorder.id_sucursal_registro == id_sucursal,
            )
        )

    pagos = query_pagos.all()

    metodos_montos = {}
    metodos_cantidades = {}
    efectivo_fisico = 0
    canales_electronicos = 0
    total_recaudado = 0
    total_transacciones = len(pagos)

    for p in pagos:
        metodo = (p.metodo_pago or "Otro").strip()
        metodos_montos[metodo] = metodos_montos.get(metodo, 0) + p.monto
        metodos_cantidades[metodo] = metodos_cantidades.get(metodo, 0) + 1
        total_recaudado += p.monto
        if "efectivo" in metodo.lower():
            efectivo_fisico += p.monto
        else:
            canales_electronicos += p.monto

    desglose = []
    items_ordenados = sorted(
        metodos_montos.items(), key=lambda x: x[1], reverse=True
    )
    for metodo, monto in items_ordenados:
        cant = metodos_cantidades.get(metodo, 1)
        porcentaje_monto = (
            round((monto / total_recaudado) * 100, 2)
            if total_recaudado > 0
            else 0.0
        )
        porcentaje_cant = (
            round((cant / total_transacciones) * 100, 2)
            if total_transacciones > 0
            else 0.0
        )
        desglose.append(
            DesglosePagoDTO(
                metodo_pago=metodo,
                monto_total=monto,
                porcentaje=porcentaje_monto,
                cantidad=cant,
                porcentaje_cantidad=porcentaje_cant,
            )
        )

    return ResumenPagosDTO(
        efectivo_fisico=efectivo_fisico,
        canales_electronicos=canales_electronicos,
        total_transacciones=total_transacciones,
        desglose=desglose,
    )


@router.get(
    "/dashboard/operativa",
    response_model=FlujoOperativoDTO,
    summary="Pulso Operativo de Bodega y Alertas",
    description="Retorna estado del pipeline de despacho y alertas.",
)
def obtener_flujo_operativo(
    id_sucursal: Optional[int] = Query(
        None,
        description="ID de sucursal. Si se omite, consolida toda la cadena.",
    ),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_gerencia_o_auditor_central),
):
    """
    Calculo el flujo logístico de bodega: ítems en preparación física,
    piezas listas en mostrador, envíos por courier, saldos y piezas sin precio.
    """
    # 1. En preparación (Ítems en preparación de órdenes activas)
    query_prep = (
        db.query(Detalle_Orden)
        .join(Orden_Venta, Detalle_Orden.id_orden == Orden_Venta.id_orden)
        .filter(
            Detalle_Orden.estado_preparacion != "Listo",
            Detalle_Orden.estado_preparacion != "Reingresado",
            Orden_Venta.estado_orden.in_(["Reservada", "Pagada"]),
        )
    )
    if id_sucursal is not None:
        query_prep = query_prep.filter(
            Orden_Venta.id_sucursal == id_sucursal
        )
    en_preparacion = query_prep.count()

    # 2. Listos mostrador (Ítems listos para retiro sin courier enviado)
    query_listos = (
        db.query(Detalle_Orden)
        .join(Orden_Venta, Detalle_Orden.id_orden == Orden_Venta.id_orden)
        .outerjoin(Despacho, Orden_Venta.id_orden == Despacho.id_orden)
        .filter(
            Detalle_Orden.estado_preparacion == "Listo",
            Orden_Venta.estado_orden.in_(["Reservada", "Pagada"]),
            or_(
                Despacho.id_despacho.is_(None),
                Despacho.estado_despacho != "Enviado",
            ),
        )
    )
    if id_sucursal is not None:
        query_listos = query_listos.filter(
            Orden_Venta.id_sucursal == id_sucursal
        )
    listos_mostrador = query_listos.count()

    # 3. Enviados Courier (Despachos en tránsito hacia su destino)
    query_courier = (
        db.query(Despacho)
        .join(Orden_Venta, Despacho.id_orden == Orden_Venta.id_orden)
        .filter(Despacho.estado_despacho == "Enviado")
    )
    if id_sucursal is not None:
        query_courier = query_courier.filter(
            Orden_Venta.id_sucursal == id_sucursal
        )
    enviados_courier = query_courier.count()

    # 4. Alertas de saldo pendiente (Órdenes activas con saldo retenido)
    query_saldos = (
        db.query(Orden_Venta)
        .filter(
            Orden_Venta.estado_orden != "Anulada",
            Orden_Venta.monto_pendiente > 0,
        )
    )
    if id_sucursal is not None:
        query_saldos = query_saldos.filter(
            Orden_Venta.id_sucursal == id_sucursal
        )
    alertas_saldo_pendiente = query_saldos.count()

    # 5. Cuellos de botella en tasación (Piezas paletizadas sin precio)
    query_cuellos = (
        db.query(Activo_Inventariado)
        .join(
            Estado_Activo,
            Activo_Inventariado.id_estado == Estado_Activo.id_estado,
        )
        .filter(
            Activo_Inventariado.estado == "Activo",
            or_(
                Activo_Inventariado.id_estado == 7,
                Estado_Activo.nombre_estado == "Paletizado",
            ),
        )
    )
    if id_sucursal is not None:
        query_cuellos = query_cuellos.filter(
            Activo_Inventariado.id_sucursal_actual == id_sucursal
        )
    cuellos_botella_paletizados = query_cuellos.count()

    return FlujoOperativoDTO(
        en_preparacion=en_preparacion,
        listos_mostrador=listos_mostrador,
        enviados_courier=enviados_courier,
        alertas_saldo_pendiente=alertas_saldo_pendiente,
        cuellos_botella_paletizados=cuellos_botella_paletizados,
    )


# ==========================================
# VISOR CENTRALIZADO DE BACKORDERS (HU-5.4)
# ==========================================

def format_relative_chile_date(dt: Optional[datetime]) -> str:
    """
    Formatea la fecha de creación en hora local de Chile a un formato amigable:
    - 'Hoy HH:MM'
    - 'Ayer HH:MM'
    - 'Hace N días'
    - 'DD/MM/YYYY HH:MM'
    """
    if not dt:
        return "Fecha desconocida"
    if dt.tzinfo is None:
        dt_utc = dt.replace(tzinfo=timezone.utc)
    else:
        dt_utc = dt.astimezone(timezone.utc)
    dt_local = dt_utc.astimezone(tz_chile)
    ahora_local = datetime.now(tz_chile)

    dias_diff = (ahora_local.date() - dt_local.date()).days
    hora_str = dt_local.strftime("%H:%M")

    if dias_diff == 0:
        return f"Hoy {hora_str}"
    elif dias_diff == 1:
        return f"Ayer {hora_str}"
    elif 2 <= dias_diff <= 7:
        return f"Hace {dias_diff} días"
    else:
        return dt_local.strftime("%d/%m/%Y %H:%M")


def format_clp(amount: int) -> str:
    """Formatea montos enteros a formato moneda chilena ($XX.XXX)."""
    return f"${amount:,}".replace(",", ".")



@router.get(
    "/backorders",
    response_model=BackorderGerenciaListResponse,
    summary="Listado Maestro de Backorders para Gerencia (HU-5.4)",
)
def obtener_backorders_gerencia(
    id_sucursal: Optional[int] = Query(None, description="Filtrar por ID de sucursal"),
    estado: Optional[str] = Query(None, description="Filtrar por estado de reserva (Pendiente, Confirmada, Completada, Anulada)"),
    q: Optional[str] = Query(None, description="Búsqueda predictiva (Folio, Cliente, Vendedor, Marca, Modelo)"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    current_user: Usuario = Depends(require_gerencia_o_auditor_central),
    db: Session = Depends(get_db),
):
    query = (
        db.query(
            Reservas_Backorder,
            Cliente,
            Usuario,
            Sucursal,
            Categoria_Activo,
            Activo_Inventariado,
            Orden_Venta,
        )
        .join(Cliente, Reservas_Backorder.id_cliente == Cliente.id_cliente)
        .join(Usuario, Reservas_Backorder.id_vendedor == Usuario.id_usuario)
        .join(Sucursal, Reservas_Backorder.id_sucursal_registro == Sucursal.id_sucursal)
        .outerjoin(Categoria_Activo, Reservas_Backorder.id_categoria_requerida == Categoria_Activo.id_categoria)
        .outerjoin(Activo_Inventariado, Reservas_Backorder.id_activo_asignado == Activo_Inventariado.id_activo)
        .outerjoin(Orden_Venta, Reservas_Backorder.id_orden == Orden_Venta.id_orden)
    )

    if id_sucursal is not None:
        query = query.filter(Reservas_Backorder.id_sucursal_registro == id_sucursal)

    if estado and estado.strip() and estado.lower() != "todos":
        est_val = estado.strip().capitalize()
        if est_val.lower() == "anulada":
            query = query.filter(
                or_(
                    Reservas_Backorder.estado_reserva == "Anulada",
                    Orden_Venta.estado_orden == "Anulada",
                )
            )
        elif est_val.lower() == "completada":
            query = query.filter(
                or_(
                    and_(
                        Reservas_Backorder.estado_reserva == "Completada",
                        or_(Orden_Venta.estado_orden.is_(None), Orden_Venta.estado_orden == "Completada"),
                    ),
                    Orden_Venta.estado_orden == "Completada",
                ),
                Reservas_Backorder.estado_reserva != "Anulada",
                or_(Orden_Venta.estado_orden.is_(None), Orden_Venta.estado_orden != "Anulada"),
                or_(Orden_Venta.estado_orden.is_(None), ~Orden_Venta.estado_orden.in_(["Reservada", "Pagada"])),
            )
        elif est_val.lower() == "confirmada":
            query = query.filter(
                or_(
                    Reservas_Backorder.estado_reserva == "Confirmada",
                    and_(
                        Reservas_Backorder.estado_reserva == "Completada",
                        Orden_Venta.estado_orden.in_(["Reservada", "Pagada"]),
                    ),
                ),
                Reservas_Backorder.estado_reserva != "Anulada",
                or_(Orden_Venta.estado_orden.is_(None), Orden_Venta.estado_orden != "Anulada"),
                or_(Orden_Venta.estado_orden.is_(None), Orden_Venta.estado_orden != "Completada"),
            )
        elif est_val.lower() == "pendiente":
            query = query.filter(
                Reservas_Backorder.estado_reserva == "Pendiente",
                or_(Orden_Venta.estado_orden.is_(None), Orden_Venta.estado_orden != "Anulada"),
            )
        else:
            query = query.filter(Reservas_Backorder.estado_reserva == est_val)

    if q and q.strip():
        term = f"%{q.strip().lower()}%"
        query = query.filter(
            or_(
                func.lower(Reservas_Backorder.marca_requerida).ilike(term),
                func.lower(Reservas_Backorder.modelo_requerido).ilike(term),
                func.lower(Cliente.nombres).ilike(term),
                func.lower(Cliente.apellidos).ilike(term),
                func.lower(Cliente.rut_cliente).ilike(term),
                func.lower(Usuario.nombres).ilike(term),
                func.lower(Usuario.apellidos).ilike(term),
                cast(Reservas_Backorder.id_reserva, String).ilike(term),
            )
        )

    total_count = query.count()

    # Coherencia con reversas financieras: excluir órdenes/reservas anuladas de la recaudación de señas
    query_senas = query.filter(
        Reservas_Backorder.estado_reserva != "Anulada",
        or_(Orden_Venta.estado_orden.is_(None), Orden_Venta.estado_orden != "Anulada"),
    )
    total_senas = (
        query_senas.with_entities(func.coalesce(func.sum(Reservas_Backorder.monto_abonado), 0)).scalar()
        if total_count > 0 else 0
    )

    query = query.order_by(Reservas_Backorder.fecha_creacion.desc())
    rows = query.offset(offset).limit(limit).all()

    items = []
    for res, cli, ven, suc, cat, act, ord_vinc in rows:
        folio_str = f"RES-{str(res.id_reserva).replace('-', '')[:4].upper()}"
        fecha_amigable = format_relative_chile_date(res.fecha_creacion)
        fecha_iso = res.fecha_creacion.isoformat() if res.fecha_creacion else ""
        cliente_nombre_completo = f"{cli.nombres or ''} {cli.apellidos or ''}".strip() or "Cliente no registrado"
        vendedor_nombre_completo = f"{ven.nombres or ''} {ven.apellidos or ''}".strip() or "Vendedor no registrado"
        cat_nombre = cat.nombre_categoria if cat else "Repuesto"
        sku_fisico = act.sku_qr_fisico if act else None

        # Sincronización y unificación de estado con la orden transaccional vinculada
        estado_auditoria = res.estado_reserva
        if ord_vinc:
            if ord_vinc.estado_orden == "Anulada":
                estado_auditoria = "Anulada"
            elif ord_vinc.estado_orden == "Completada":
                estado_auditoria = "Completada"
            elif ord_vinc.estado_orden in ["Reservada", "Pagada"] and res.estado_reserva == "Completada":
                # Regla de completitud validada: si aún no fue entregada formalmente en bodega, figura como Confirmada
                estado_auditoria = "Confirmada"

        desc_val = getattr(ord_vinc, "descuento", 0) or 0 if ord_vinc else 0
        if estado_auditoria == "Anulada":
            saldo_calc = 0
        elif ord_vinc and (ord_vinc.estado_orden == "Pagada" or ord_vinc.monto_pendiente == 0):
            saldo_calc = 0
        elif ord_vinc and ord_vinc.monto_pendiente is not None:
            saldo_calc = ord_vinc.monto_pendiente
        else:
            saldo_calc = max(0, res.precio_acordado - desc_val - (res.monto_abonado or 0))

        item_dto = BackorderGerenciaItemDTO(
            id_reserva=str(res.id_reserva),
            folio=folio_str,
            fecha_creacion=fecha_amigable,
            fecha_creacion_iso=fecha_iso,
            id_cliente=str(res.id_cliente),
            cliente_nombre=cliente_nombre_completo,
            cliente_telefono=getattr(cli, "telefono", None) or getattr(cli, "correo", None),
            cliente_rut=cli.rut_cliente,
            id_vendedor=str(res.id_vendedor),
            vendedor_nombre=vendedor_nombre_completo,
            id_sucursal=res.id_sucursal_registro,
            sucursal_nombre=suc.nombre_sucursal if suc else f"Sucursal {res.id_sucursal_registro}",
            id_categoria_requerida=res.id_categoria_requerida,
            categoria_nombre=cat_nombre,
            marca_requerida=res.marca_requerida,
            modelo_requerido=res.modelo_requerido,
            anio_requerido=res.anio_requerido,
            cilindrada_requerida=res.cilindrada_requerida,
            combustible_requerido=res.combustible_requerido,
            transmision_requerida=res.transmision_requerida,
            notas_preparacion=res.notas_preparacion,
            precio_acordado=res.precio_acordado,
            descuento=desc_val,
            monto_abonado=res.monto_abonado or 0,
            saldo_pendiente=saldo_calc,
            estado_reserva=estado_auditoria,
            id_activo_asignado=str(res.id_activo_asignado) if res.id_activo_asignado else None,
            activo_asignado_sku=sku_fisico,
            id_orden=str(res.id_orden) if res.id_orden else None,
            orden_folio=ord_vinc.folio if ord_vinc else None,
            estado_orden=ord_vinc.estado_orden if ord_vinc else None,
        )
        items.append(item_dto)

    return BackorderGerenciaListResponse(
        items=items,
        total_count=total_count,
        total_recaudado_senas=total_senas,
    )


@router.get(
    "/backorders/kpis",
    response_model=BackorderGerenciaKpisDTO,
    summary="Cabecera Analítica de KPIs de Backorders (HU-5.4)",
)
def obtener_kpis_backorders_gerencia(
    id_sucursal: Optional[int] = Query(None, description="Filtrar por sucursal"),
    current_user: Usuario = Depends(require_gerencia_o_auditor_central),
    db: Session = Depends(get_db),
):
    query = (
        db.query(Reservas_Backorder)
        .outerjoin(Orden_Venta, Reservas_Backorder.id_orden == Orden_Venta.id_orden)
    )
    if id_sucursal is not None:
        query = query.filter(Reservas_Backorder.id_sucursal_registro == id_sucursal)

    # Coherencia con reversas financieras: filtrar órdenes y reservas anuladas
    query_validas = query.filter(
        Reservas_Backorder.estado_reserva != "Anulada",
        or_(Orden_Venta.estado_orden.is_(None), Orden_Venta.estado_orden != "Anulada"),
    )

    # 1. Total Backorders Activos (Pendiente o Confirmada, o Pagada sin entrega formal)
    total_activos = query_validas.filter(
        or_(
            Reservas_Backorder.estado_reserva.in_(["Pendiente", "Confirmada"]),
            and_(
                Reservas_Backorder.estado_reserva == "Completada",
                Orden_Venta.estado_orden.in_(["Reservada", "Pagada"]),
            ),
        ),
        or_(Orden_Venta.estado_orden.is_(None), Orden_Venta.estado_orden != "Completada"),
    ).count()

    # 2. Capital Retenido en Abonos (Suma de señas de reservas activas)
    capital_retenido = (
        query_validas.filter(
            or_(
                Reservas_Backorder.estado_reserva.in_(["Pendiente", "Confirmada"]),
                and_(
                    Reservas_Backorder.estado_reserva == "Completada",
                    Orden_Venta.estado_orden.in_(["Reservada", "Pagada"]),
                ),
            ),
            or_(Orden_Venta.estado_orden.is_(None), Orden_Venta.estado_orden != "Completada"),
        )
        .with_entities(func.coalesce(func.sum(Reservas_Backorder.monto_abonado), 0))
        .scalar()
    ) or 0

    # 3. Listos para Liquidar (Activos con match físico asignado pero aún no completados)
    listos_para_liquidar = query_validas.filter(
        Reservas_Backorder.id_activo_asignado.isnot(None),
        or_(Orden_Venta.estado_orden.is_(None), Orden_Venta.estado_orden != "Completada"),
    ).count()

    # Totales globales
    total_registrados = query.count()
    total_recaudado_senas = (
        query_validas.with_entities(func.coalesce(func.sum(Reservas_Backorder.monto_abonado), 0))
        .scalar()
    ) or 0

    return BackorderGerenciaKpisDTO(
        total_activos=total_activos,
        capital_retenido=capital_retenido,
        listos_para_liquidar=listos_para_liquidar,
        total_registrados=total_registrados,
        total_recaudado_senas=total_recaudado_senas,
    )


@router.get(
    "/backorders/{id_reserva}/auditoria",
    response_model=BackorderAuditoriaResponseDTO,
    summary="Auditoría Forense Completa de una Venta en Verde (Backorder)",
)
def obtener_auditoria_backorder_gerencia(
    id_reserva: str,
    current_user: Usuario = Depends(require_gerencia_o_auditor_central),
    db: Session = Depends(get_db),
):
    try:
        reserva_uuid = uuid.UUID(id_reserva)
    except (ValueError, AttributeError):
        raise HTTPException(status_code=400, detail="ID de reserva inválido")

    reserva = (
        db.query(Reservas_Backorder)
        .filter(Reservas_Backorder.id_reserva == reserva_uuid)
        .first()
    )
    if not reserva:
        raise HTTPException(status_code=404, detail="Reserva de backorder no encontrada")

    cliente = db.query(Cliente).filter(Cliente.id_cliente == reserva.id_cliente).first()
    vendedor = db.query(Usuario).filter(Usuario.id_usuario == reserva.id_vendedor).first()
    sucursal = db.query(Sucursal).filter(Sucursal.id_sucursal == reserva.id_sucursal_registro).first()
    categoria = db.query(Categoria_Activo).filter(Categoria_Activo.id_categoria == reserva.id_categoria_requerida).first()

    orden = None
    cajera = None
    usuario_anulacion = None
    if reserva.id_orden:
        orden = db.query(Orden_Venta).filter(Orden_Venta.id_orden == reserva.id_orden).first()
        if orden:
            if orden.id_cajera:
                cajera = db.query(Usuario).filter(Usuario.id_usuario == orden.id_cajera).first()
            if orden.id_usuario_anulacion:
                usuario_anulacion = db.query(Usuario).filter(Usuario.id_usuario == orden.id_usuario_anulacion).first()

    activo = None
    vehiculo_donante = None
    if reserva.id_activo_asignado:
        activo = db.query(Activo_Inventariado).filter(Activo_Inventariado.id_activo == reserva.id_activo_asignado).first()
        if activo and activo.id_vehiculo:
            vehiculo_donante = db.query(Vehiculo_Origen).filter(Vehiculo_Origen.id_vehiculo == activo.id_vehiculo).first()

    # Transacciones de pago vinculadas a la reserva o a la orden final
    filtro_pagos = [Transaccion_Pago.id_reserva == reserva.id_reserva]
    if orden:
        filtro_pagos.append(Transaccion_Pago.id_orden == orden.id_orden)

    pagos = (
        db.query(Transaccion_Pago)
        .filter(
            or_(*filtro_pagos),
            Transaccion_Pago.estado_pago == "Procesado",
        )
        .order_by(Transaccion_Pago.fecha_pago.asc())
        .all()
    )

    # Auditoría de barrera de salida
    auditoria_barrera = None
    bodeguero_barrera = None
    if orden:
        auditoria_barrera = db.query(Auditoria_Barrera).filter(Auditoria_Barrera.id_orden == orden.id_orden).first()
        if auditoria_barrera and auditoria_barrera.id_bodeguero:
            bodeguero_barrera = db.query(Usuario).filter(Usuario.id_usuario == auditoria_barrera.id_bodeguero).first()

    # Fechas formateadas
    res_dt = (reserva.fecha_creacion.replace(tzinfo=timezone.utc) if reserva.fecha_creacion and reserva.fecha_creacion.tzinfo is None else reserva.fecha_creacion or datetime.now(timezone.utc)).astimezone(tz_chile)
    res_fecha_26 = res_dt.strftime("%d/%m/%y")
    res_hora = res_dt.strftime("%H:%M")
    fecha_creacion_formateada = f"{res_fecha_26} {res_hora} hrs"
    fecha_iso = reserva.fecha_creacion.isoformat() if reserva.fecha_creacion else ""

    folio_str = f"RES-{str(reserva.id_reserva).replace('-', '')[:4].upper()}"
    cliente_nombre = f"{cliente.nombres or ''} {cliente.apellidos or ''}".strip() if cliente else "Cliente no registrado"
    vendedor_nombre = f"{vendedor.nombres or ''} {vendedor.apellidos or ''}".strip() if vendedor else "Vendedor no asignado"
    cajera_nombre = f"{cajera.nombres or ''} {cajera.apellidos or ''}".strip() if cajera else None
    suc_nombre = sucursal.nombre_sucursal if sucursal else f"Sucursal {reserva.id_sucursal_registro}"
    cat_nombre = categoria.nombre_categoria if categoria else "Repuesto"

    # Sincronización y unificación de estado con la orden transaccional vinculada
    estado_auditoria = reserva.estado_reserva
    if orden:
        if orden.estado_orden == "Anulada":
            estado_auditoria = "Anulada"
        elif orden.estado_orden == "Completada":
            estado_auditoria = "Completada"
        elif orden.estado_orden in ["Reservada", "Pagada"] and reserva.estado_reserva == "Completada":
            estado_auditoria = "Confirmada"

    desc_val = getattr(orden, "descuento", 0) or 0 if orden else 0
    if estado_auditoria == "Anulada":
        saldo_calc = 0
    elif orden and (orden.estado_orden == "Pagada" or orden.monto_pendiente == 0):
        saldo_calc = 0
    elif orden and orden.monto_pendiente is not None:
        saldo_calc = orden.monto_pendiente
    else:
        saldo_calc = max(0, reserva.precio_acordado - desc_val - (reserva.monto_abonado or 0))

    # Construir desglose de pagos
    desglose_pagos_dto: List[BackorderPagoDetalleDTO] = []
    for p in pagos:
        p_dt = (p.fecha_pago.replace(tzinfo=timezone.utc) if p.fecha_pago and p.fecha_pago.tzinfo is None else p.fecha_pago or datetime.now(timezone.utc)).astimezone(tz_chile)
        desglose_pagos_dto.append(
            BackorderPagoDetalleDTO(
                id_transaccion=str(p.id_pago) if p.id_pago else None,
                metodo_pago=p.metodo_pago,
                monto=p.monto,
                fecha_pago=f"{p_dt.strftime('%d/%m/%y')} {p_dt.strftime('%H:%M')} hrs",
                cajero_nombre=cajera_nombre,
            )
        )

    # Construir línea de tiempo cronológica de hitos
    movimientos: List[BackorderMovimientoDTO] = [
        BackorderMovimientoDTO(
            hora=fecha_creacion_formateada,
            evento=f"Reserva de Venta en Verde emitida en Mesón por {vendedor_nombre} ({suc_nombre})",
        )
    ]

    # Hitos de pagos y abonos
    if pagos:
        for idx, p in enumerate(pagos):
            p_dt = (p.fecha_pago.replace(tzinfo=timezone.utc) if p.fecha_pago and p.fecha_pago.tzinfo is None else p.fecha_pago or datetime.now(timezone.utc)).astimezone(tz_chile)
            p_hora_str = f"{p_dt.strftime('%d/%m/%y')} {p_dt.strftime('%H:%M')} hrs"
            es_ultimo = (idx == len(pagos) - 1)
            caj_txt = f" por {cajera_nombre}" if cajera_nombre else ""
            if orden and orden.estado_orden in ["Pagada", "Completada"] and es_ultimo and saldo_calc == 0:
                evento_str = f"Liquidación final en ventanilla: {p.metodo_pago} ({format_clp(p.monto)}){caj_txt}"
            else:
                evento_str = f"Abono de seña registrado en ventanilla: {p.metodo_pago} ({format_clp(p.monto)}){caj_txt}"
            movimientos.append(BackorderMovimientoDTO(hora=p_hora_str, evento=evento_str))
    elif reserva.monto_abonado and reserva.monto_abonado > 0:
        movimientos.append(
            BackorderMovimientoDTO(
                hora=fecha_creacion_formateada,
                evento=f"Abono inicial de seña registrado en caja por {format_clp(reserva.monto_abonado)}",
            )
        )

    # Hito de Match físico asignado
    if activo:
        act_dt = (reserva.fecha_actualizacion or reserva.fecha_creacion or datetime.now(timezone.utc))
        act_dt = (act_dt.replace(tzinfo=timezone.utc) if act_dt.tzinfo is None else act_dt).astimezone(tz_chile)
        act_hora_str = f"{act_dt.strftime('%d/%m/%y')} {act_dt.strftime('%H:%M')} hrs"
        sku_str = activo.sku_qr_fisico
        if vehiculo_donante:
            v_desc = f"N° Ingreso {vehiculo_donante.numero_ingreso} [{vehiculo_donante.patente}] ({vehiculo_donante.marca} {vehiculo_donante.modelo})"
            evento_act = f"Pieza física asignada (SKU: {sku_str}) desde vehículo donante {v_desc}"
        else:
            evento_act = f"Pieza física asignada en inventario de desarme (SKU: {sku_str})"
        movimientos.append(BackorderMovimientoDTO(hora=act_hora_str, evento=evento_act))

    # Hito de orden de venta vinculada y emisión de QR transaccional
    if orden:
        ord_dt = (orden.fecha_creacion.replace(tzinfo=timezone.utc) if orden.fecha_creacion and orden.fecha_creacion.tzinfo is None else orden.fecha_creacion or datetime.now(timezone.utc)).astimezone(tz_chile)
        ord_hora_str = f"{ord_dt.strftime('%d/%m/%y')} {ord_dt.strftime('%H:%M')} hrs"
        movimientos.append(
            BackorderMovimientoDTO(
                hora=ord_hora_str,
                evento=f"Orden de venta vinculada {orden.folio} generada en mesón para liquidación",
            )
        )

        if orden.qr_transaccional_salida:
            qr_dt = (orden.fecha_actualizacion or orden.fecha_creacion or datetime.now(timezone.utc))
            qr_dt = (qr_dt.replace(tzinfo=timezone.utc) if qr_dt.tzinfo is None else qr_dt).astimezone(tz_chile)
            movimientos.append(
                BackorderMovimientoDTO(
                    hora=f"{qr_dt.strftime('%d/%m/%y')} {qr_dt.strftime('%H:%M')} hrs",
                    evento="QR Transaccional generado para retiro y escaneo en barrera de salida",
                )
            )

    # Hito de entrega y validación en barrera
    if auditoria_barrera:
        b_dt = (auditoria_barrera.fecha_escaneo.replace(tzinfo=timezone.utc) if auditoria_barrera.fecha_escaneo and auditoria_barrera.fecha_escaneo.tzinfo is None else auditoria_barrera.fecha_escaneo or datetime.now(timezone.utc)).astimezone(tz_chile)
        b_hora_str = f"{b_dt.strftime('%d/%m/%y')} {b_dt.strftime('%H:%M')} hrs"
        bod_nom = f"{bodeguero_barrera.nombres or ''} {bodeguero_barrera.apellidos or ''}".strip() if bodeguero_barrera else "Bodega"
        movimientos.append(
            BackorderMovimientoDTO(
                hora=b_hora_str,
                evento=f"Pieza retirada y validada en barrera de salida por {bod_nom}",
            )
        )

    # Hito de anulación con motivo y responsable
    if estado_auditoria == "Anulada":
        anul_dt_raw = (orden.fecha_anulacion if orden and orden.fecha_anulacion else (orden.fecha_actualizacion if orden and orden.fecha_actualizacion else (reserva.fecha_actualizacion or reserva.fecha_creacion)))
        anul_dt = (anul_dt_raw.replace(tzinfo=timezone.utc) if anul_dt_raw and anul_dt_raw.tzinfo is None else anul_dt_raw or datetime.now(timezone.utc)).astimezone(tz_chile)
        anul_hora_str = f"{anul_dt.strftime('%d/%m/%y')} {anul_dt.strftime('%H:%M')} hrs"
        usr_anul_nom = f"{usuario_anulacion.nombres or ''} {usuario_anulacion.apellidos or ''}".strip() if usuario_anulacion else "Operador"
        motivo_str = orden.motivo_anulacion if orden and orden.motivo_anulacion else "Anulación solicitada"
        obs_str = f" ({orden.observacion_anulacion})" if orden and orden.observacion_anulacion else ""
        movimientos.append(
            BackorderMovimientoDTO(
                hora=anul_hora_str,
                evento=f"Operación anulada en el sistema por {usr_anul_nom}. Motivo: {motivo_str}{obs_str}",
            )
        )

    donante_desc = None
    if vehiculo_donante:
        donante_desc = f"{vehiculo_donante.marca} {vehiculo_donante.modelo} ({vehiculo_donante.anio or 'S/A'})"

    return BackorderAuditoriaResponseDTO(
        id_reserva=str(reserva.id_reserva),
        folio=folio_str,
        fecha_creacion=fecha_creacion_formateada,
        fecha_creacion_iso=fecha_iso,
        estado_reserva=estado_auditoria,
        id_orden=str(orden.id_orden) if orden else None,
        orden_folio=orden.folio if orden else None,
        estado_orden=orden.estado_orden if orden else None,
        id_cliente=str(cliente.id_cliente) if cliente else str(reserva.id_cliente),
        cliente_nombre=cliente_nombre,
        cliente_rut=cliente.rut_cliente if cliente else None,
        cliente_telefono=cliente.telefono if cliente else None,
        cliente_correo=cliente.correo if cliente else None,
        id_vendedor=str(reserva.id_vendedor),
        vendedor_nombre=vendedor_nombre,
        id_sucursal=reserva.id_sucursal_registro,
        sucursal_nombre=suc_nombre,
        id_categoria_requerida=reserva.id_categoria_requerida,
        categoria_nombre=cat_nombre,
        marca_requerida=reserva.marca_requerida,
        modelo_requerido=reserva.modelo_requerido,
        anio_requerido=reserva.anio_requerido,
        cilindrada_requerida=reserva.cilindrada_requerida,
        combustible_requerido=reserva.combustible_requerido,
        transmision_requerida=reserva.transmision_requerida,
        notas_preparacion=reserva.notas_preparacion,
        precio_acordado=reserva.precio_acordado,
        descuento=desc_val,
        monto_abonado=reserva.monto_abonado or 0,
        saldo_pendiente=saldo_calc,
        id_activo_asignado=str(reserva.id_activo_asignado) if reserva.id_activo_asignado else None,
        activo_asignado_sku=activo.sku_qr_fisico if activo else None,
        vehiculo_donante_ingreso=vehiculo_donante.numero_ingreso if vehiculo_donante else None,
        vehiculo_donante_patente=vehiculo_donante.patente if vehiculo_donante else None,
        vehiculo_donante_descripcion=donante_desc,
        desglose_pagos=desglose_pagos_dto,
        movimientos=movimientos,
    )


# ==========================================
# PREDICCIÓN ML DE VENTAS Y COBERTURA (CRES-281)
# ==========================================

@router.get(
    "/dashboard/predicciones",
    response_model=PrediccionVentasStockResponseDTO,
    summary="Predicción ML de Ventas y Cobertura de Stock Crítico (CRES-281)",
    description=(
        "Ejecuta inferencia con modelos XGBoost multi-target y RobustScaler usando la "
        "ventana histórica semanal reciente de Supabase (con relleno Cold-Start si aplica) "
        "y contrasta la demanda proyectada contra el stock disponible y backorders activos."
    ),
)
@router.get(
    "/predicciones",
    response_model=PrediccionVentasStockResponseDTO,
    include_in_schema=False,
)
def obtener_predicciones_ventas_y_stock(
    id_sucursal: Optional[int] = Query(
        None,
        description="ID de sucursal (1=Viña del Mar, 2=Limache). Si se omite, consolida toda la cadena.",
    ),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_gerencia_jefe_ventas_o_auditor_central),
):
    """
    Endpoint síncrono para predicción semanal (t+1) y mensual recursiva (4 semanas)
    de unidades y montos CLP por categoría, mix porcentual y cobertura de stock crítico.
    """
    try:
        return generar_prediccion_ventas_y_stock(db=db, id_sucursal=id_sucursal)
    except RuntimeError as exc:
        raise HTTPException(
            status_code=503,
            detail=f"Servicio de inferencia ML temporalmente no disponible: {str(exc)}",
        )


