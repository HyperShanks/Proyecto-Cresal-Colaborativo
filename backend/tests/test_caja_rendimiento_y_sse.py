"""
Tests de rendimiento (eliminación de N+1), precisión de métricas SQL
y bus SSE en tiempo real para el Módulo de Caja.
"""

import asyncio
import uuid
from datetime import datetime, timedelta, timezone, time
from zoneinfo import ZoneInfo

import pytest
from sqlalchemy import event

from conftest import TestingSessionLocal, engine
from core.security import create_access_token, hash_password
from models import (
    Activo_Inventariado,
    Auditoria_Barrera,
    Auditoria_Edicion_Pago,
    Categoria_Activo,
    Cliente,
    Comuna,
    Detalle_Orden,
    Estado_Activo,
    Orden_Venta,
    Region,
    Reservas_Backorder,
    Rol,
    Sucursal,
    Transaccion_Pago,
    Usuario,
    Vehiculo_Origen,
)
from services.caja_events import CajaEventBus

tz_chile = ZoneInfo("America/Santiago")


@pytest.fixture(scope="module")
def perf_data(setup_database):
    db = TestingSessionLocal()
    try:
        r = Region(id_region=1, nombre_region="Valparaíso")
        c = Comuna(id_comuna=1, nombre_comuna="Viña del Mar", id_region=1)
        suc1 = Sucursal(id_sucursal=1, nombre_sucursal="Viña del Mar", direccion="Av. 1", id_comuna=1)
        db.add_all([r, c, suc1])

        db.add_all([
            Rol(id_rol=1, nombre_rol="Bodeguero"),
            Rol(id_rol=2, nombre_rol="Vendedor"),
            Rol(id_rol=3, nombre_rol="Caja"),
            Rol(id_rol=5, nombre_rol="Administrador"),
        ])

        u_caja = Usuario(
            id_usuario=uuid.uuid4(),
            id_rol=3,
            id_sucursal=1,
            rut_usuario="12.111.222-3",
            nombres="Lorena",
            apellidos="Valenzuela",
            email="lorena.perf@cresal.cl",
            password_hash=hash_password("1234"),
            pin_acceso="3131",
            estado="Activo",
        )
        u_vend = Usuario(
            id_usuario=uuid.uuid4(),
            id_rol=2,
            id_sucursal=1,
            rut_usuario="13.111.222-4",
            nombres="Andrés",
            apellidos="Morales",
            email="andres.perf@cresal.cl",
            password_hash=hash_password("1234"),
            pin_acceso="2121",
            estado="Activo",
        )
        u_bod = Usuario(
            id_usuario=uuid.uuid4(),
            id_rol=1,
            id_sucursal=1,
            rut_usuario="14.111.222-5",
            nombres="Pedro",
            apellidos="Bodega",
            email="pedro.perf@cresal.cl",
            password_hash=hash_password("1234"),
            pin_acceso="1212",
            estado="Activo",
        )
        db.add_all([u_caja, u_vend, u_bod])

        cli = Cliente(
            id_cliente=uuid.uuid4(),
            rut_cliente="77.999.888-1",
            nombres="Taller",
            apellidos="Rendimiento SpA",
            consentimiento_legal=True,
            estado="Activo",
        )
        cat = Categoria_Activo(id_categoria=1, nombre_categoria="Motor")
        est = Estado_Activo(id_estado=1, nombre_estado="Disponible")
        veh = Vehiculo_Origen(
            id_vehiculo=uuid.uuid4(),
            numero_ingreso="ING-PERF-01",
            marca="Toyota",
            modelo="Hilux",
            anio=2022,
            estado="Activo",
        )
        db.add_all([cli, cat, est, veh])
        db.flush()

        ahora_chile = datetime.combine(datetime.now(tz_chile).date(), time(12, 0), tzinfo=tz_chile)
        base_utc = ahora_chile.astimezone(timezone.utc).replace(tzinfo=None)

        # 50 órdenes históricas (40 pagadas/completadas + 10 anuladas)
        metodos = ["Efectivo", "Débito", "Crédito", "Transferencia", "Cheque"]
        expected_totals = {m: 0 for m in metodos}
        for i in range(50):
            es_anulada = i >= 40
            estado = "Anulada" if es_anulada else ("Pagada" if i % 2 == 0 else "Completada")
            monto = 100000 + (i * 1000)
            orden = Orden_Venta(
                id_orden=uuid.uuid4(),
                id_cliente=cli.id_cliente,
                id_vendedor=u_vend.id_usuario,
                id_cajera=u_caja.id_usuario,
                id_sucursal=1,
                estado_orden=estado,
                qr_transaccional_salida=f"ORD-HIST-{i:03d}",
                total_venta=monto,
                monto_pendiente=monto if es_anulada else 0,
                fecha_creacion=base_utc - timedelta(minutes=i),
                fecha_actualizacion=base_utc - timedelta(minutes=i),
            )
            db.add(orden)
            db.add(
                Detalle_Orden(
                    id_detalle=uuid.uuid4(),
                    id_orden=orden.id_orden,
                    id_activo=None,
                    descripcion_manual=f"Repuesto Histórico #{i}",
                    cantidad=1,
                    precio_unitario=monto,
                    precio_final=monto,
                )
            )
            if not es_anulada:
                metodo = metodos[i % len(metodos)]
                expected_totals[metodo] += monto
                pago = Transaccion_Pago(
                    id_pago=uuid.uuid4(),
                    id_orden=orden.id_orden,
                    monto=monto,
                    metodo_pago=metodo,
                    estado_pago="Procesado",
                    fecha_pago=base_utc - timedelta(minutes=i),
                )
                db.add(pago)
                if i % 5 == 0:
                    db.add(
                        Auditoria_Barrera(
                            id_auditoria=uuid.uuid4(),
                            id_orden=orden.id_orden,
                            id_bodeguero=u_bod.id_usuario,
                            match_exitoso=True,
                            fecha_escaneo=base_utc - timedelta(minutes=i),
                        )
                    )
                    db.add(
                        Auditoria_Edicion_Pago(
                            id_auditoria=uuid.uuid4(),
                            id_pago=pago.id_pago,
                            id_orden=orden.id_orden,
                            id_usuario=u_caja.id_usuario,
                            fecha_edicion=base_utc - timedelta(minutes=i),
                            campo_modificado="metodo_pago",
                            valor_anterior="Efectivo",
                            valor_nuevo=metodo,
                            motivo="Corrección de prueba rendimiento",
                        )
                    )

        # 30 órdenes pendientes (15 nuevas + 15 abonadas) + 5 backorders
        for j in range(30):
            es_abonada = j >= 15
            orden_p = Orden_Venta(
                id_orden=uuid.uuid4(),
                id_cliente=cli.id_cliente,
                id_vendedor=u_vend.id_usuario,
                id_sucursal=1,
                estado_orden="Reservada",
                qr_transaccional_salida=f"ORD-PEND-{j:03d}",
                total_venta=200000,
                monto_pendiente=120000 if es_abonada else 200000,
                abono_requerido=80000 if not es_abonada else 0,
                fecha_creacion=base_utc - timedelta(minutes=j),
            )
            db.add(orden_p)
            db.add(
                Detalle_Orden(
                    id_detalle=uuid.uuid4(),
                    id_orden=orden_p.id_orden,
                    id_activo=None,
                    descripcion_manual=f"Repuesto Pendiente #{j}",
                    cantidad=1,
                    precio_unitario=200000,
                    precio_final=200000,
                )
            )
            if es_abonada:
                db.add(
                    Transaccion_Pago(
                        id_pago=uuid.uuid4(),
                        id_orden=orden_p.id_orden,
                        monto=80000,
                        metodo_pago="Efectivo",
                        estado_pago="Procesado",
                        fecha_pago=base_utc - timedelta(minutes=j),
                    )
                )

        for k in range(5):
            res = Reservas_Backorder(
                id_reserva=uuid.uuid4(),
                id_cliente=cli.id_cliente,
                id_vendedor=u_vend.id_usuario,
                id_sucursal_registro=1,
                id_categoria_requerida=1,
                marca_requerida="Toyota",
                modelo_requerido="Hilux",
                anio_requerido=2022,
                precio_acordado=500000,
                monto_abonado=100000 if k % 2 == 0 else 0,
                estado_reserva="Confirmada" if k % 2 == 0 else "Pendiente",
                fecha_creacion=base_utc - timedelta(minutes=k),
            )
            db.add(res)

        db.commit()
        yield {
            "caja_token": create_access_token({"sub": str(u_caja.id_usuario)}),
            "vend_token": create_access_token({"sub": str(u_vend.id_usuario)}),
            "expected_totals": expected_totals,
        }
    finally:
        db.close()


def _count_queries(fn):
    queries = []

    def before_cursor_execute(conn, cursor, statement, parameters, context, executemany):
        queries.append(statement)

    event.listen(engine, "before_cursor_execute", before_cursor_execute)
    try:
        res = fn()
    finally:
        event.remove(engine, "before_cursor_execute", before_cursor_execute)
    return res, len(queries)


def test_historial_caja_sin_n_mas_1_con_50_ordenes(client, perf_data):
    """
    Con 50 órdenes históricas (65 con las 15 reservadas abonadas), el endpoint /historial
    debe ejecutar un número constante O(1) de consultas SQL (<= 10) en vez de >200.
    """
    headers = {"Authorization": f"Bearer {perf_data['caja_token']}"}

    resp, query_count = _count_queries(
        lambda: client.get(
            "/api/v1/caja/historial?sucursal_id=1&periodo=TODOS&pagina=1&limite=20",
            headers=headers,
        )
    )

    assert resp.status_code == 200
    data = resp.json()

    # 50 históricas + 15 reservadas con abono = 65 elegibles en historial
    assert data["total_registros"] == 65
    assert data["total_paginas"] == 4
    assert len(data["items"]) == 20
    assert query_count <= 10, f"Se esperaba <= 10 queries SQL, se ejecutaron {query_count}"

    # Verificar precisión matemática del resumen_cuadre (40 pagadas + 15 abonos de $80.000)
    cuadre = data["resumen_cuadre"]
    exp = perf_data["expected_totals"]
    assert cuadre["total_ordenes_pagadas"] == 40
    assert cuadre["total_efectivo"] == exp["Efectivo"] + (15 * 80000)
    assert cuadre["total_debito"] == exp["Débito"]
    assert cuadre["total_credito"] == exp["Crédito"]
    assert cuadre["total_pos"] == exp["Débito"] + exp["Crédito"]
    assert cuadre["total_transferencia"] == exp["Transferencia"]
    assert cuadre["total_cheque"] == exp["Cheque"]
    assert cuadre["total_recaudado"] == (
        cuadre["total_efectivo"]
        + cuadre["total_pos"]
        + cuadre["total_transferencia"]
        + cuadre["total_cheque"]
    )


def test_pendientes_caja_sin_n_mas_1_con_35_operaciones(client, perf_data):
    """
    Con 30 ventas pendientes (nuevas + abonadas) y 5 backorders, /pendientes
    debe ejecutar <= 8 consultas SQL en total en vez de >70.
    """
    headers = {"Authorization": f"Bearer {perf_data['caja_token']}"}

    resp, query_count = _count_queries(
        lambda: client.get(
            "/api/v1/caja/pendientes?sucursal_id=1&tipo_operacion=TODOS",
            headers=headers,
        )
    )

    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 35
    assert len(data["items"]) == 35
    assert query_count <= 8, f"Se esperaba <= 8 queries SQL, se ejecutaron {query_count}"

    # Verificar que los ítems mantienen sus artículos e historial de abonos intactos
    ventas_abonadas = [it for it in data["items"] if it["tipo_operacion"] == "VENTA" and it["abono_previo"] > 0]
    assert len(ventas_abonadas) == 15
    assert all(len(it["articulos"]) == 1 and len(it["historial_abonos"]) == 1 for it in ventas_abonadas)


def test_sse_bus_aislamiento_por_sucursal():
    """Valida publicación, aislamiento por sucursal y desuscripción limpia en CajaEventBus."""
    async def _run():
        bus = CajaEventBus()
        q1, sub1 = bus.subscribe(1)
        q2, sub2 = bus.subscribe(2)

        assert bus.subscriber_count(1) == 1
        assert bus.subscriber_count(2) == 1

        bus.publish(1, "pendientes_changed", {"folio": "ORD-0001"})
        msg = await asyncio.wait_for(q1.get(), timeout=1.0)
        assert "event: pendientes_changed" in msg
        assert "ORD-0001" in msg
        assert q2.empty()

        bus.unsubscribe(1, sub1)
        bus.unsubscribe(2, sub2)
        assert bus.subscriber_count() == 0

    asyncio.run(_run())


def test_stream_sse_rbac_rechaza_sin_token_y_vendedor(client, perf_data):
    """Valida que /api/v1/caja/stream exige autenticación y rol de Caja/Admin."""
    r_unauth = client.get("/api/v1/caja/stream?sucursal_id=1")
    assert r_unauth.status_code in (401, 403)

    r_vend = client.get(
        "/api/v1/caja/stream?sucursal_id=1",
        headers={"Authorization": f"Bearer {perf_data['vend_token']}"},
    )
    assert r_vend.status_code == 403
