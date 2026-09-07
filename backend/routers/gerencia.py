# backend/routers/gerencia.py
"""
Router de Gerencia: Dashboard Ejecutivo y Analítica en Tiempo Real (HU-5.1).
Implemento los endpoints de consulta analítica de alto nivel para consolidar
el pulso financiero y la carga operativa de bodega.
"""

from datetime import datetime, time, timezone
from typing import Optional
from zoneinfo import ZoneInfo
from fastapi import APIRouter, Depends, Query
from sqlalchemy import or_
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
)
from core.security import require_gerencia_role
from schemas.gerencia_schemas import (
    KpiFinancieroDTO,
    ResumenPagosDTO,
    DesglosePagoDTO,
    FlujoOperativoDTO,
)

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
    current_user: Usuario = Depends(require_gerencia_role),
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
        .join(Orden_Venta, Transaccion_Pago.id_orden == Orden_Venta.id_orden)
        .filter(
            Transaccion_Pago.estado_pago == "Procesado",
            Transaccion_Pago.fecha_pago.between(inicio_hoy_utc, fin_hoy_utc),
            Orden_Venta.estado_orden != "Anulada",
        )
    )
    if id_sucursal is not None:
        query_pagos_hoy = query_pagos_hoy.filter(
            Orden_Venta.id_sucursal == id_sucursal
        )

    pagos_hoy = query_pagos_hoy.all()
    ventas_del_dia = sum(p.monto for p in pagos_hoy)

    # Identifico las órdenes pagadas de hoy para calcular transacciones
    ordenes_hoy_ids = {
        p.id_orden for p in pagos_hoy if p.id_orden is not None
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
        .join(Orden_Venta, Transaccion_Pago.id_orden == Orden_Venta.id_orden)
        .filter(
            Transaccion_Pago.estado_pago == "Procesado",
            Transaccion_Pago.fecha_pago.between(inicio_mes_utc, fin_hoy_utc),
            Orden_Venta.estado_orden != "Anulada",
        )
    )
    if id_sucursal is not None:
        query_mtd = query_mtd.filter(
            Orden_Venta.id_sucursal == id_sucursal
        )

    pagos_mtd = query_mtd.all()
    acumulado_mensual_mtd = sum(p.monto for p in pagos_mtd)

    return KpiFinancieroDTO(
        ventas_del_dia=ventas_del_dia,
        transacciones_hoy=transacciones_hoy,
        acumulado_mensual_mtd=acumulado_mensual_mtd,
        ticket_promedio=ticket_promedio,
        margen_bruto=64.8,
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
    current_user: Usuario = Depends(require_gerencia_role),
):
    """
    Agrupo los métodos de pago de hoy para generar el gráfico Donut.
    Clasifico en efectivo_fisico y canales_electronicos.
    """
    inicio_hoy_utc, fin_hoy_utc, _ = calcular_limites_temporales_chile()

    query_pagos = (
        db.query(Transaccion_Pago)
        .join(Orden_Venta, Transaccion_Pago.id_orden == Orden_Venta.id_orden)
        .filter(
            Transaccion_Pago.estado_pago == "Procesado",
            Transaccion_Pago.fecha_pago.between(inicio_hoy_utc, fin_hoy_utc),
            Orden_Venta.estado_orden != "Anulada",
        )
    )
    if id_sucursal is not None:
        query_pagos = query_pagos.filter(
            Orden_Venta.id_sucursal == id_sucursal
        )

    pagos = query_pagos.all()

    metodos_montos = {}
    efectivo_fisico = 0
    canales_electronicos = 0
    total_recaudado = 0

    for p in pagos:
        metodo = (p.metodo_pago or "Otro").strip()
        metodos_montos[metodo] = metodos_montos.get(metodo, 0) + p.monto
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
        porcentaje = (
            round((monto / total_recaudado) * 100, 2)
            if total_recaudado > 0
            else 0.0
        )
        desglose.append(
            DesglosePagoDTO(
                metodo_pago=metodo,
                monto_total=monto,
                porcentaje=porcentaje,
            )
        )

    return ResumenPagosDTO(
        efectivo_fisico=efectivo_fisico,
        canales_electronicos=canales_electronicos,
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
    current_user: Usuario = Depends(require_gerencia_role),
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
                Activo_Inventariado.precio_referencia.is_(None),
                Activo_Inventariado.precio_referencia == 0,
            ),
            Estado_Activo.nombre_estado == "Paletizado",
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
