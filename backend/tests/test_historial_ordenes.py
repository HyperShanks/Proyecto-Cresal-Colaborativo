# test_historial_ordenes.py
# Suite de pruebas automatizadas para HU-3.5: Historial de Órdenes, Anulación ACID y Edición de Instrucciones.

import uuid
import pytest
from datetime import datetime, timedelta, timezone

from models import (
    Region, Comuna, Sucursal, Rol, Usuario,
    Categoria_Activo, Estado_Activo, Vehiculo_Origen,
    Activo_Inventariado, Detalle_Motor, Orden_Venta,
    Detalle_Orden, Despacho, Cliente
)
from core.security import create_access_token
from conftest import TestingSessionLocal


@pytest.fixture(scope="module")
def db_session(setup_database):
    db = TestingSessionLocal()
    try:
        # Seed Base
        r = Region(id_region=1, nombre_region="Valparaíso")
        db.add(r)
        c = Comuna(id_comuna=1, nombre_comuna="Viña del Mar", id_region=1)
        db.add(c)

        suc1 = Sucursal(id_sucursal=1, nombre_sucursal="Casa Matriz - Viña", direccion="Av. Libertad 123", id_comuna=1)
        db.add(suc1)

        rol_vendedor = Rol(id_rol=1, nombre_rol="Vendedor")
        db.add(rol_vendedor)

        u1_id = uuid.uuid4()
        u2_id = uuid.uuid4()

        vendedor_1 = Usuario(
            id_usuario=u1_id,
            id_rol=1,
            id_sucursal=1,
            rut_usuario="11.111.111-1",
            nombres="Vendedor",
            apellidos="Principal",
            email="vendedor1@cresal.cl",
            password_hash="hash",
            pin_acceso="1234",
            estado="Activo"
        )
        vendedor_2 = Usuario(
            id_usuario=u2_id,
            id_rol=1,
            id_sucursal=1,
            rut_usuario="22.222.222-2",
            nombres="Vendedor",
            apellidos="Secundario",
            email="vendedor2@cresal.cl",
            password_hash="hash",
            pin_acceso="5678",
            estado="Activo"
        )
        db.add_all([vendedor_1, vendedor_2])

        cat_motor = Categoria_Activo(id_categoria=1, nombre_categoria="Motor")
        cat_caja = Categoria_Activo(id_categoria=2, nombre_categoria="Caja de Cambio")
        db.add_all([cat_motor, cat_caja])

        est_disp = Estado_Activo(id_estado=1, nombre_estado="Disponible")
        est_res = Estado_Activo(id_estado=2, nombre_estado="Reservado")
        est_vend = Estado_Activo(id_estado=3, nombre_estado="Vendido")
        db.add_all([est_disp, est_res, est_vend])

        # Vehículo
        v1 = Vehiculo_Origen(
            id_vehiculo=uuid.uuid4(),
            numero_ingreso="ING-2026-001",
            patente="ABCD12",
            marca="Toyota",
            modelo="Yaris",
            anio=2018,
            traccion="4x2",
            estado="Activo"
        )
        db.add(v1)

        # Activo Inventariado
        a1_id = uuid.uuid4()
        act1 = Activo_Inventariado(
            id_activo=a1_id,
            sku_qr_fisico="MOT-TOY-YAR-001",
            id_categoria=1,
            id_estado=2,  # Inicialmente Reservado por la orden
            id_sucursal_actual=1,
            id_vehiculo=v1.id_vehiculo,
            precio_referencia=520000,
            ubicacion_pasillo="P-01",
            ubicacion_pallet="PL-02",
            estado="Activo"
        )
        db.add(act1)

        # Cliente
        cliente_1 = Cliente(
            id_cliente=uuid.uuid4(),
            rut_cliente="18.765.432-1",
            nombres="Carlos",
            apellidos="González",
            telefono="+56912345678",
            correo="carlos@correo.cl",
            id_comuna=1,
            consentimiento_legal=True,
            estado="Activo"
        )
        db.add(cliente_1)

        # Orden 1 (Vendedor 1, Creada Hoy, Estado Reservada)
        orden_1 = Orden_Venta(
            id_orden=uuid.uuid4(),
            id_cliente=cliente_1.id_cliente,
            id_vendedor=u1_id,
            id_sucursal=1,
            estado_orden="Reservada",
            qr_transaccional_salida="ORD-TEST001",
            total_venta=520000,
            monto_pendiente=520000,
            fecha_creacion=datetime.now(timezone.utc).replace(tzinfo=None),
        )
        db.add(orden_1)

        detalle_1 = Detalle_Orden(
            id_detalle=uuid.uuid4(),
            id_orden=orden_1.id_orden,
            id_activo=a1_id,
            notas_preparacion="Entregar con poleas",
            cantidad=1,
            precio_unitario=520000,
            precio_final=520000,
        )
        db.add(detalle_1)

        despacho_1 = Despacho(
            id_despacho=uuid.uuid4(),
            id_orden=orden_1.id_orden,
            id_comuna_destino=1,
            direccion_envio="Av. Libertad 1234, Depto 402",
            receptor_nombres="Carlos González",
            receptor_rut="18.765.432-1",
            receptor_telefono="+56912345678",
            costo_envio=0,
            estado_despacho="Por Enviar",
            estado="Activo"
        )
        db.add(despacho_1)

        # Orden 2 (Vendedor 1, Creada Ayer, Estado Pagada)
        ayer = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=1)
        orden_2 = Orden_Venta(
            id_orden=uuid.uuid4(),
            id_cliente=cliente_1.id_cliente,
            id_vendedor=u1_id,
            id_sucursal=1,
            estado_orden="Pagada",
            qr_transaccional_salida="ORD-TEST002",
            total_venta=30000,
            monto_pendiente=0,
            fecha_creacion=ayer,
        )
        db.add(orden_2)

        detalle_2 = Detalle_Orden(
            id_detalle=uuid.uuid4(),
            id_orden=orden_2.id_orden,
            descripcion_manual="Pernos de culata especiales",
            notas_preparacion="Verificar hilo",
            cantidad=2,
            precio_unitario=15000,
            precio_final=15000,
        )
        db.add(detalle_2)

        # Orden 3 (Vendedor 2, Creada Hoy)
        orden_3 = Orden_Venta(
            id_orden=uuid.uuid4(),
            id_cliente=cliente_1.id_cliente,
            id_vendedor=u2_id,
            id_sucursal=1,
            estado_orden="Reservada",
            qr_transaccional_salida="ORD-TEST003",
            total_venta=50000,
            monto_pendiente=50000,
            fecha_creacion=datetime.now(timezone.utc).replace(tzinfo=None),
        )
        db.add(orden_3)

        db.commit()

        yield {
            "vendedor_1": vendedor_1,
            "vendedor_2": vendedor_2,
            "orden_1": orden_1,
            "orden_2": orden_2,
            "orden_3": orden_3,
            "activo_1": act1,
            "detalle_1": detalle_1,
            "detalle_2": detalle_2,
        }

    finally:
        db.close()


@pytest.fixture(scope="module")
def auth_headers_vendedor1(db_session):
    token = create_access_token(data={"sub": str(db_session["vendedor_1"].id_usuario)})
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture(scope="module")
def auth_headers_vendedor2(db_session):
    token = create_access_token(data={"sub": str(db_session["vendedor_2"].id_usuario)})
    return {"Authorization": f"Bearer {token}"}


# ── TEST 1: Obtener Mis Ventas Filtrado por Hoy por Defecto ─────────────────
def test_obtener_mis_ventas_filtrado_hoy(client, db_session, auth_headers_vendedor1):
    response = client.get("/api/v1/ordenes/mis-ventas", headers=auth_headers_vendedor1)
    assert response.status_code == 200

    data = response.json()
    assert isinstance(data, list)
    # Vendedor 1 tiene 1 orden de hoy (orden_1)
    assert len(data) == 1
    assert data[0]["id_orden"] == str(db_session["orden_1"].id_orden)
    assert data[0]["estado_orden"] == "Reservada"
    assert data[0]["total_venta"] == 520000
    assert data[0]["total_items"] == 1

    # Verificar relaciones anidadas
    assert data[0]["cliente"]["rut_cliente"] == "18.765.432-1"
    assert data[0]["despacho"]["direccion_envio"] == "Av. Libertad 1234, Depto 402"
    assert len(data[0]["detalles"]) == 1
    assert data[0]["detalles"][0]["sku_qr_fisico"] == "MOT-TOY-YAR-001"
    assert data[0]["detalles"][0]["notas_preparacion"] == "Entregar con poleas"
    assert data[0]["detalles"][0]["es_inventariado"] is True


# ── TEST 2: Obtener Mis Ventas con Parámetro 'todas=true' (Historial Completo)
def test_obtener_mis_ventas_parametro_todas(client, db_session, auth_headers_vendedor1):
    response = client.get("/api/v1/ordenes/mis-ventas?todas=true", headers=auth_headers_vendedor1)
    assert response.status_code == 200

    data = response.json()
    # Vendedor 1 tiene 2 órdenes en total (orden_1 y orden_2)
    assert len(data) == 2
    ids = [o["id_orden"] for o in data]
    assert str(db_session["orden_1"].id_orden) in ids
    assert str(db_session["orden_2"].id_orden) in ids


# ── TEST 3: Filtrar Mis Ventas por Estado ───────────────────────────────────
def test_obtener_mis_ventas_filtrado_por_estado(client, db_session, auth_headers_vendedor1):
    response = client.get("/api/v1/ordenes/mis-ventas?todas=true&estado=Pagada", headers=auth_headers_vendedor1)
    assert response.status_code == 200

    data = response.json()
    assert len(data) == 1
    assert data[0]["id_orden"] == str(db_session["orden_2"].id_orden)
    assert data[0]["estado_orden"] == "Pagada"


# ── TEST 4: Aislamiento por Vendedor ────────────────────────────────────────
def test_obtener_mis_ventas_aislamiento_vendedor2(client, db_session, auth_headers_vendedor2):
    response = client.get("/api/v1/ordenes/mis-ventas", headers=auth_headers_vendedor2)
    assert response.status_code == 200

    data = response.json()
    # Vendedor 2 solo ve su orden (orden_3)
    assert len(data) == 1
    assert data[0]["id_orden"] == str(db_session["orden_3"].id_orden)


# ── TEST 5: Actualizar Instrucciones / Notas Técnicas para Bodega ────────────
def test_actualizar_instrucciones_bodega_exitoso(client, db_session, auth_headers_vendedor1):
    id_orden = str(db_session["orden_1"].id_orden)
    payload = {
        "notas_preparacion": "URGENTE: Probar compresión antes de despachar"
    }

    response = client.patch(f"/api/v1/ordenes/{id_orden}/instrucciones", json=payload, headers=auth_headers_vendedor1)
    assert response.status_code == 200

    data = response.json()
    assert data["id_orden"] == id_orden
    assert "actualizadas exitosamente" in data["mensaje"]
    assert data["notas_preparacion"] == "URGENTE: Probar compresión antes de despachar"
    assert data["detalles_actualizados"] >= 1

    # Verificar en base de datos
    db = TestingSessionLocal()
    try:
        detalle = db.query(Detalle_Orden).filter(Detalle_Orden.id_orden == uuid.UUID(id_orden)).first()
        assert detalle.notas_preparacion == "URGENTE: Probar compresión antes de despachar"
    finally:
        db.close()


# ── TEST 6: Anular Orden Reservada y Liberar Stock a 'Disponible' (ACID) ────
def test_anular_orden_reservada_libera_stock_exitoso(client, db_session, auth_headers_vendedor1):
    id_orden = str(db_session["orden_1"].id_orden)
    id_activo = db_session["activo_1"].id_activo

    # 1. Ejecutar anulación
    response = client.patch(f"/api/v1/ordenes/{id_orden}/anular", headers=auth_headers_vendedor1)
    assert response.status_code == 200

    data = response.json()
    assert data["id_orden"] == id_orden
    assert data["estado_orden"] == "Anulada"
    assert data["activos_liberados"] == 1
    assert "devueltos al catálogo como disponibles" in data["mensaje"]

    # 2. Verificar consistencia ACID en la base de datos
    db = TestingSessionLocal()
    try:
        orden_db = db.query(Orden_Venta).filter(Orden_Venta.id_orden == uuid.UUID(id_orden)).first()
        assert orden_db.estado_orden == "Anulada"
        assert orden_db.monto_pendiente == 0

        activo_db = db.query(Activo_Inventariado).filter(Activo_Inventariado.id_activo == id_activo).first()
        estado_disp = db.query(Estado_Activo).filter(Estado_Activo.nombre_estado == "Disponible").first()
        assert activo_db.id_estado == estado_disp.id_estado
    finally:
        db.close()


# ── TEST 7: Anular Orden Rechaza si no está en estado 'Reservada' ────────────
def test_anular_orden_falla_si_no_esta_reservada(client, db_session, auth_headers_vendedor1):
    # Orden 2 está en estado 'Pagada'
    id_orden = str(db_session["orden_2"].id_orden)

    response = client.patch(f"/api/v1/ordenes/{id_orden}/anular", headers=auth_headers_vendedor1)
    assert response.status_code == 400

    data = response.json()
    assert "Solo se pueden anular órdenes en estado 'Reservada'" in data["detail"]
    assert "Pagada" in data["detail"]


# ── TEST 8: Actualizar Instrucciones Falla si la orden está 'Anulada' ────────
def test_actualizar_instrucciones_falla_si_esta_anulada(client, db_session, auth_headers_vendedor1):
    # Orden 1 ya fue anulada en el test 6
    id_orden = str(db_session["orden_1"].id_orden)
    payload = {"notas_preparacion": "Nuevo texto"}

    response = client.patch(f"/api/v1/ordenes/{id_orden}/instrucciones", json=payload, headers=auth_headers_vendedor1)
    assert response.status_code == 400

    data = response.json()
    assert "No se pueden modificar instrucciones en una orden con estado 'Anulada'" in data["detail"]


# ── TEST 9: Orden Creada en Horario Nocturno Local Chile (UTC-4) ────────────
def test_obtener_mis_ventas_orden_nocturna_chile(client, db_session, auth_headers_vendedor1):
    db = TestingSessionLocal()
    try:
        from zoneinfo import ZoneInfo
        from datetime import timezone
        tz_chile = ZoneInfo("America/Santiago")
        ahora_chile = datetime.now(tz_chile)
        # Simular orden creada a las 23:30 hrs de Chile de hoy (03:30 UTC del día siguiente)
        fecha_nocturna_chile = ahora_chile.replace(hour=23, minute=30, second=0, microsecond=0)
        fecha_nocturna_utc = fecha_nocturna_chile.astimezone(timezone.utc).replace(tzinfo=None)

        orden_nocturna = Orden_Venta(
            id_orden=uuid.uuid4(),
            id_cliente=db_session["orden_1"].id_cliente,
            id_vendedor=db_session["vendedor_1"].id_usuario,
            id_sucursal=1,
            estado_orden="Reservada",
            qr_transaccional_salida="ORD-NOCT001",
            total_venta=75000,
            monto_pendiente=75000,
            fecha_creacion=fecha_nocturna_utc,
        )
        db.add(orden_nocturna)
        db.commit()

        # Consultar mis ventas por defecto (filtro solo hoy)
        response = client.get("/api/v1/ordenes/mis-ventas", headers=auth_headers_vendedor1)
        assert response.status_code == 200
        data = response.json()
        ids = [item["id_orden"] for item in data]
        assert str(orden_nocturna.id_orden) in ids
    finally:
        db.close()


# ── TEST 10: Ordenamiento de Órdenes (Completadas al Final) ─────────────────
def test_obtener_mis_ventas_ordenamiento_completadas_al_final(client, db_session, auth_headers_vendedor1):
    db = TestingSessionLocal()
    try:
        ahora_utc = datetime.now(timezone.utc).replace(tzinfo=None)

        # Orden A: Reservada (hace 10 minutos)
        orden_reservada = Orden_Venta(
            id_orden=uuid.uuid4(),
            id_cliente=db_session["orden_1"].id_cliente,
            id_vendedor=db_session["vendedor_1"].id_usuario,
            id_sucursal=1,
            estado_orden="Reservada",
            qr_transaccional_salida="ORD-ORD-RES",
            total_venta=100000,
            monto_pendiente=100000,
            fecha_creacion=ahora_utc - timedelta(minutes=10),
        )
        # Orden B: Completada (creada recién hace 1 minuto - más nueva que la reservada)
        orden_completada = Orden_Venta(
            id_orden=uuid.uuid4(),
            id_cliente=db_session["orden_1"].id_cliente,
            id_vendedor=db_session["vendedor_1"].id_usuario,
            id_sucursal=1,
            estado_orden="Completada",
            qr_transaccional_salida="ORD-ORD-COMP",
            total_venta=200000,
            monto_pendiente=0,
            fecha_creacion=ahora_utc - timedelta(minutes=1),
        )
        db.add(orden_reservada)
        db.add(orden_completada)
        db.commit()

        response = client.get("/api/v1/ordenes/mis-ventas", headers=auth_headers_vendedor1)
        assert response.status_code == 200
        data = response.json()

        # En la lista: Activas (Reservada/Pagada) van primero, luego Completadas, y al final de todo las Anuladas.
        def _prioridad(estado: str) -> int:
            e = estado.lower()
            if e in ("anulada", "anulado", "cancelada", "cancelado"):
                return 2
            if e in ("completada", "completado", "entregada", "entregado"):
                return 1
            return 0

        prioridades = [_prioridad(item["estado_orden"]) for item in data]
        assert prioridades == sorted(prioridades), f"El orden de prioridades no es correcto: {prioridades} para estados {[item['estado_orden'] for item in data]}"

        estados = [item["estado_orden"] for item in data]
        assert "Completada" in estados
        assert "Anulada" in estados
        assert estados[-1] == "Anulada"
    finally:
        db.close()


