# backend/tests/test_gerencia_backorders.py
"""
Suite de Pruebas Automatizadas para HU-5.4:
Acoplamiento de Tasación de Vehículos para Desarme y Monitoreo Centralizado de Backorders.
"""

import uuid
from datetime import datetime, timezone
import pytest

from models import (
    Region,
    Comuna,
    Sucursal,
    Rol,
    Usuario,
    Categoria_Activo,
    Estado_Activo,
    Vehiculo_Origen,
    Activo_Inventariado,
    Cliente,
    Reservas_Backorder,
    Orden_Venta,
    Detalle_Orden,
    Transaccion_Pago,
)
from core.security import create_access_token
from conftest import TestingSessionLocal


@pytest.fixture(scope="module")
def db_backorders(setup_database):
    db = TestingSessionLocal()
    try:
        # Geografía y Sucursales
        r = Region(id_region=40, nombre_region="Metropolitana")
        db.add(r)
        c1 = Comuna(id_comuna=401, nombre_comuna="Santiago Centro", id_region=40)
        c2 = Comuna(id_comuna=402, nombre_comuna="San Bernardo", id_region=40)
        db.add_all([c1, c2])

        suc1 = Sucursal(id_sucursal=41, nombre_sucursal="Sucursal 10 de Julio", direccion="Av. 10 de Julio 1200", id_comuna=401)
        suc2 = Sucursal(id_sucursal=42, nombre_sucursal="Patio San Bernardo", direccion="Av. Portales 800", id_comuna=402)
        db.add_all([suc1, suc2])

        # Roles
        rol_vendedor = Rol(id_rol=2, nombre_rol="Vendedor")
        rol_gerente = Rol(id_rol=4, nombre_rol="Gerente")
        rol_admin = Rol(id_rol=5, nombre_rol="Administrador")
        db.add_all([rol_vendedor, rol_gerente, rol_admin])

        # Usuarios
        gerente_id = uuid.uuid4()
        admin_id = uuid.uuid4()
        vendedor_id = uuid.uuid4()

        gerente = Usuario(
            id_usuario=gerente_id,
            id_rol=4,
            id_sucursal=41,
            rut_usuario="14.333.444-5",
            nombres="Carlos",
            apellidos="Gerente Backorders",
            email="gerente.backorders@cresal.cl",
            password_hash="hash",
            pin_acceso="1234",
            estado="Activo",
        )
        admin = Usuario(
            id_usuario=admin_id,
            id_rol=5,
            id_sucursal=41,
            rut_usuario="15.444.555-6",
            nombres="Admin",
            apellidos="Backorders",
            email="admin.backorders@cresal.cl",
            password_hash="hash",
            pin_acceso="5555",
            estado="Activo",
        )
        vendedor = Usuario(
            id_usuario=vendedor_id,
            id_rol=2,
            id_sucursal=41,
            rut_usuario="16.555.666-7",
            nombres="Pedro",
            apellidos="Ventas",
            email="pedro.ventas@cresal.cl",
            password_hash="hash",
            pin_acceso="2222",
            estado="Activo",
        )
        db.add_all([gerente, admin, vendedor])

        # Clientes
        cli1_id = uuid.uuid4()
        cli1 = Cliente(
            id_cliente=cli1_id,
            rut_cliente="18.111.222-3",
            nombres="Juan",
            apellidos="Pérez",
            correo="juan.perez@email.com",
            telefono="+56 9 8765 4321",
            id_comuna=401,
            estado="Activo",
        )
        cli2_id = uuid.uuid4()
        cli2 = Cliente(
            id_cliente=cli2_id,
            rut_cliente="19.222.333-4",
            nombres="María",
            apellidos="González",
            correo="maria.gonzalez@email.com",
            telefono="+56 9 1234 5678",
            id_comuna=402,
            estado="Activo",
        )
        db.add_all([cli1, cli2])

        # Categorías y Estados
        cat_motor = Categoria_Activo(id_categoria=1, nombre_categoria="Motores")
        cat_caja = Categoria_Activo(id_categoria=2, nombre_categoria="Cajas de Cambio")
        db.add_all([cat_motor, cat_caja])

        est_disp = Estado_Activo(id_estado=1, nombre_estado="Disponible")
        db.add(est_disp)

        # Vehículo y Activo físico asignado a una reserva
        veh1 = Vehiculo_Origen(
            id_vehiculo=uuid.uuid4(),
            numero_ingreso="ING-601",
            marca="Nissan",
            modelo="Terrano",
            anio=2018,
            traccion="4x4",
        )
        db.add(veh1)

        act_asignado_id = uuid.uuid4()
        act_asignado = Activo_Inventariado(
            id_activo=act_asignado_id,
            sku_qr_fisico="MOT-6001-A1",
            id_categoria=1,
            id_estado=1,
            id_sucursal_actual=41,
            id_vehiculo=veh1.id_vehiculo,
            precio_referencia=950000,
            version_lock=1,
            estado="Activo",
        )
        db.add(act_asignado)

        # 4 Reservas Backorder para probar diversos escenarios:
        # Res 1: Sucursal 41, Pendiente, SIN pieza física asignada
        res1_id = uuid.uuid4()
        res1 = Reservas_Backorder(
            id_reserva=res1_id,
            id_cliente=cli1_id,
            id_vendedor=vendedor_id,
            id_sucursal_registro=41,
            id_categoria_requerida=1,
            marca_requerida="Toyota",
            modelo_requerido="Yaris",
            anio_requerido=2017,
            combustible_requerido="Bencina",
            transmision_requerida="Mecánica",
            precio_acordado=850000,
            monto_abonado=250000,
            id_activo_asignado=None,
            estado_reserva="Pendiente",
            fecha_creacion=datetime.now(timezone.utc),
        )

        # Res 2: Sucursal 41, Confirmada, CON pieza física asignada
        res2_id = uuid.uuid4()
        res2 = Reservas_Backorder(
            id_reserva=res2_id,
            id_cliente=cli2_id,
            id_vendedor=vendedor_id,
            id_sucursal_registro=41,
            id_categoria_requerida=1,
            marca_requerida="Nissan",
            modelo_requerido="Terrano",
            anio_requerido=2018,
            combustible_requerido="Diesel",
            transmision_requerida="Manual",
            precio_acordado=950000,
            monto_abonado=300000,
            id_activo_asignado=act_asignado_id,
            estado_reserva="Confirmada",
            fecha_creacion=datetime.now(timezone.utc),
        )

        # Res 3: Sucursal 42, Completada (ya liquidada), sin activo asignado actualmente
        res3_id = uuid.uuid4()
        res3 = Reservas_Backorder(
            id_reserva=res3_id,
            id_cliente=cli1_id,
            id_vendedor=vendedor_id,
            id_sucursal_registro=42,
            id_categoria_requerida=2,
            marca_requerida="Chevrolet",
            modelo_requerido="Sail",
            anio_requerido=2016,
            combustible_requerido="Bencina",
            transmision_requerida="Mecánica",
            precio_acordado=400000,
            monto_abonado=400000,
            id_activo_asignado=None,
            estado_reserva="Completada",
            fecha_creacion=datetime.now(timezone.utc),
        )

        # Res 4: Sucursal 42, Anulada
        res4_id = uuid.uuid4()
        res4 = Reservas_Backorder(
            id_reserva=res4_id,
            id_cliente=cli2_id,
            id_vendedor=vendedor_id,
            id_sucursal_registro=42,
            id_categoria_requerida=2,
            marca_requerida="Suzuki",
            modelo_requerido="Swift",
            anio_requerido=2020,
            combustible_requerido="Bencina",
            transmision_requerida="Automática",
            precio_acordado=600000,
            monto_abonado=100000,
            id_activo_asignado=None,
            estado_reserva="Anulada",
            fecha_creacion=datetime.now(timezone.utc),
        )

        db.add_all([res1, res2, res3, res4])
        db.commit()

        yield {
            "gerente_id": gerente_id,
            "admin_id": admin_id,
            "vendedor_id": vendedor_id,
            "cli1_id": cli1_id,
            "res1_id": res1_id,
            "res2_id": res2_id,
            "res3_id": res3_id,
            "res4_id": res4_id,
            "act_asignado_id": act_asignado_id,
        }
    finally:
        db.close()


@pytest.fixture
def auth_headers_gerente(db_backorders):
    token = create_access_token(data={"sub": str(db_backorders["gerente_id"])})
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def auth_headers_admin(db_backorders):
    token = create_access_token(data={"sub": str(db_backorders["admin_id"])})
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def auth_headers_vendedor(db_backorders):
    token = create_access_token(data={"sub": str(db_backorders["vendedor_id"])})
    return {"Authorization": f"Bearer {token}"}


# ─────────────────────────────────────────────────────────────────────────────
# PRUEBAS RBAC
# ─────────────────────────────────────────────────────────────────────────────

def test_backorders_acceso_permitido_gerente(client, auth_headers_gerente):
    """Verifica que Gerente (id_rol = 4) acceda exitosamente a la lista y KPIs."""
    res_list = client.get("/api/v1/gerencia/backorders", headers=auth_headers_gerente)
    assert res_list.status_code == 200
    data_list = res_list.json()
    assert "items" in data_list
    assert "total_count" in data_list
    assert "total_recaudado_senas" in data_list
    assert data_list["total_count"] >= 4

    res_kpis = client.get("/api/v1/gerencia/backorders/kpis", headers=auth_headers_gerente)
    assert res_kpis.status_code == 200
    data_kpis = res_kpis.json()
    assert "total_activos" in data_kpis
    assert "capital_retenido" in data_kpis
    assert "listos_para_liquidar" in data_kpis


def test_backorders_acceso_permitido_admin(client, auth_headers_admin):
    """Verifica que Administrador (id_rol = 5) tenga acceso."""
    res = client.get("/api/v1/gerencia/backorders", headers=auth_headers_admin)
    assert res.status_code == 200


def test_backorders_bloqueo_vendedor(client, auth_headers_vendedor):
    """Verifica que Vendedor (id_rol = 2) no tenga acceso (403 Forbidden)."""
    res = client.get("/api/v1/gerencia/backorders", headers=auth_headers_vendedor)
    assert res.status_code == 403


# ─────────────────────────────────────────────────────────────────────────────
# PRUEBAS DE KPIs Y BALANCES ECONÓMICOS
# ─────────────────────────────────────────────────────────────────────────────

def test_backorders_kpis_calculos_precisos(client, auth_headers_gerente, db_backorders):
    """
    Verifica que los KPIs de backorders calculen:
    - total_activos: Reservas en Pendiente o Confirmada (Res1 + Res2 = 2)
    - capital_retenido: Suma de monto_abonado de activas (250.000 + 300.000 = 550.000)
    - listos_para_liquidar: Activas con id_activo_asignado != null (Res2 = 1)
    """
    res = client.get("/api/v1/gerencia/backorders/kpis?id_sucursal=41", headers=auth_headers_gerente)
    assert res.status_code == 200
    kpis = res.json()
    assert kpis["total_activos"] == 2
    assert kpis["capital_retenido"] == 550000
    assert kpis["listos_para_liquidar"] == 1


# ─────────────────────────────────────────────────────────────────────────────
# PRUEBAS DE FILTROS Y BÚSQUEDA PREDICTIVA
# ─────────────────────────────────────────────────────────────────────────────

def test_backorders_filtro_sucursal_y_estado(client, auth_headers_gerente):
    """Verifica el filtrado por sucursal y por estado de reserva."""
    # Filtrar por Sucursal 42
    res_suc42 = client.get("/api/v1/gerencia/backorders?id_sucursal=42", headers=auth_headers_gerente)
    assert res_suc42.status_code == 200
    data_suc42 = res_suc42.json()
    assert data_suc42["total_count"] == 2
    for item in data_suc42["items"]:
        assert item["id_sucursal"] == 42

    # Filtrar por Estado Confirmada
    res_conf = client.get("/api/v1/gerencia/backorders?estado=Confirmada", headers=auth_headers_gerente)
    assert res_conf.status_code == 200
    data_conf = res_conf.json()
    assert all(item["estado_reserva"] == "Confirmada" for item in data_conf["items"])


def test_backorders_busqueda_predictiva(client, auth_headers_gerente):
    """Verifica la búsqueda por texto (q) en marca, modelo, cliente o vendedor."""
    # Búsqueda por modelo 'Terrano'
    res_terrano = client.get("/api/v1/gerencia/backorders?q=Terrano", headers=auth_headers_gerente)
    assert res_terrano.status_code == 200
    data = res_terrano.json()
    assert len(data["items"]) >= 1
    assert any("Terrano" in item["modelo_requerido"] for item in data["items"])

    # Búsqueda por cliente 'Pérez'
    res_perez = client.get("/api/v1/gerencia/backorders?q=Pérez", headers=auth_headers_gerente)
    assert res_perez.status_code == 200
    data_perez = res_perez.json()
    assert any("Pérez" in item["cliente_nombre"] for item in data_perez["items"])


# ─────────────────────────────────────────────────────────────────────────────
# PRUEBAS DE TRAZABILIDAD Y MATRICES DE ASIGNACIÓN FÍSICA
# ─────────────────────────────────────────────────────────────────────────────

def test_backorders_trazabilidad_activo_asignado(client, auth_headers_gerente, db_backorders):
    """
    Verifica que la reserva vinculada a una pieza física retorne activo_asignado_sku
    y que saldo_pendiente = max(0, precio_acordado - monto_abonado).
    """
    res = client.get("/api/v1/gerencia/backorders?estado=Confirmada", headers=auth_headers_gerente)
    assert res.status_code == 200
    items = res.json()["items"]
    res_confirmada = next((item for item in items if item["id_reserva"] == str(db_backorders["res2_id"])), None)
    assert res_confirmada is not None
    assert res_confirmada["activo_asignado_sku"] == "MOT-6001-A1"
    assert res_confirmada["precio_acordado"] == 950000
    assert res_confirmada["monto_abonado"] == 300000
    assert res_confirmada["saldo_pendiente"] == 650000
    assert res_confirmada["folio"].startswith("RES-")


# ─────────────────────────────────────────────────────────────────────────────
# AUDITORÍA DE ANULACIONES Y REGLA DE COMPLETITUD (CRITERIOS DE ACEPTACIÓN)
# ─────────────────────────────────────────────────────────────────────────────

def test_backorder_pagado_y_anulado_refleja_estado_anulada_en_gerencia(client, auth_headers_gerente, auth_headers_vendedor, db_backorders):
    """
    Criterios de Aceptación:
    - Al anular una orden de venta en verde con pago registrado, la tabla del tablero
      de Backorders en Gerencia muestra el estado 'Anulada' y deja de mostrarse como 'Completada'.
    - Coherencia con reversas financieras: Las anuladas no se cuentan en capital retenido ni en total_recaudado_senas.
    """
    db = TestingSessionLocal()
    try:
        id_orden = uuid.uuid4()
        id_reserva = uuid.uuid4()
        id_activo = uuid.uuid4()

        # 1. Crear Orden de Venta pagada
        orden = Orden_Venta(
            id_orden=id_orden,
            id_cliente=db_backorders["cli1_id"],
            id_vendedor=db_backorders["vendedor_id"],
            id_sucursal=41,
            estado_orden="Pagada",
            total_venta=500000,
            monto_pendiente=0,
            numero_orden=9988,
            qr_transaccional_salida=f"TX-QR-{uuid.uuid4()}",
        )
        # 2. Crear Repuesto asignado
        activo = Activo_Inventariado(
            id_activo=id_activo,
            sku_qr_fisico="MOT-BO-ANUL",
            id_categoria=1,
            id_estado=3,  # Vendido
            id_sucursal_actual=41,
            qr_impreso=True,
        )
        # 3. Crear Reserva Backorder vinculada
        reserva = Reservas_Backorder(
            id_reserva=id_reserva,
            id_cliente=db_backorders["cli1_id"],
            id_vendedor=db_backorders["vendedor_id"],
            id_orden=id_orden,
            id_sucursal_registro=41,
            id_categoria_requerida=1,
            marca_requerida="Ford",
            modelo_requerido="Ranger",
            precio_acordado=500000,
            monto_abonado=500000,
            id_activo_asignado=id_activo,
            estado_reserva="Confirmada",
            fecha_creacion=datetime.now(timezone.utc),
        )
        # 4. Detalle y Pago
        detalle = Detalle_Orden(
            id_detalle=uuid.uuid4(),
            id_orden=id_orden,
            id_activo=id_activo,
            descripcion_manual="[VENTA EN VERDE] Motor Ford Ranger",
            precio_final=500000,
            estado_preparacion="Listo",
        )
        pago = Transaccion_Pago(
            id_pago=uuid.uuid4(),
            id_orden=id_orden,
            monto=500000,
            metodo_pago="Transferencia",
            estado_pago="Procesado",
        )
        db.add_all([orden, activo, reserva, detalle, pago])
        db.commit()

        # 5. Ejecutar anulación de la orden pagada desde el endpoint de anulación
        payload_anulacion = {
            "motivo": "Arrepentimiento del cliente por incompatibilidad técnica",
            "observacion": "Cliente solicita reversa de fondos completa por cambio de proyecto automotriz."
        }
        res_anul = client.post(f"/api/v1/ordenes/{id_orden}/anular", json=payload_anulacion, headers=auth_headers_vendedor)
        assert res_anul.status_code == 200, f"Error al anular orden: {res_anul.text}"

        # 6. Consultar el listado en Gerencia: DEBE mostrar 'Anulada'
        res_gerencia = client.get(f"/api/v1/gerencia/backorders?q=Ranger", headers=auth_headers_gerente)
        assert res_gerencia.status_code == 200
        items = res_gerencia.json()["items"]
        item_anulado = next((it for it in items if it["id_reserva"] == str(id_reserva)), None)
        assert item_anulado is not None
        assert item_anulado["estado_reserva"] == "Anulada", "La tabla de Gerencia debe mostrar 'Anulada' tras anular la orden"
        assert item_anulado["estado_orden"] == "Anulada"
        assert item_anulado["orden_folio"] == "ORD-9988"
        assert item_anulado["saldo_pendiente"] == 0

        # 7. Verificar que el filtro por estado=Anulada la incluya
        res_filtro_anul = client.get("/api/v1/gerencia/backorders?estado=Anulada", headers=auth_headers_gerente)
        assert res_filtro_anul.status_code == 200
        ids_anuladas = [it["id_reserva"] for it in res_filtro_anul.json()["items"]]
        assert str(id_reserva) in ids_anuladas

        # 8. Verificar que el filtro por estado=Completada NO la incluya
        res_filtro_comp = client.get("/api/v1/gerencia/backorders?estado=Completada", headers=auth_headers_gerente)
        assert res_filtro_comp.status_code == 200
        ids_completadas = [it["id_reserva"] for it in res_filtro_comp.json()["items"]]
        assert str(id_reserva) not in ids_completadas, "En ningún caso una orden anulada debe figurar como Completada"
    finally:
        db.close()


def test_regla_completitud_backorder_solo_completada_tras_entrega_fisica(client, auth_headers_gerente, db_backorders):
    """
    Criterios de Aceptación:
    - Una orden de compra en verde solo alcanza el estado 'Completada' cuando la mercadería
      ha sido efectivamente marcada como entregada/despachada al cliente.
    - Mientras esté pagada y en bodega sin entrega, figura como 'Confirmada' en Gerencia.
    """
    db = TestingSessionLocal()
    try:
        id_orden = uuid.uuid4()
        id_reserva = uuid.uuid4()
        id_activo = uuid.uuid4()

        orden = Orden_Venta(
            id_orden=id_orden,
            id_cliente=db_backorders["cli1_id"],
            id_vendedor=db_backorders["vendedor_id"],
            id_sucursal=41,
            estado_orden="Pagada",  # Pagada pero en bodega (NO Completada)
            total_venta=700000,
            monto_pendiente=0,
            numero_orden=9989,
            qr_transaccional_salida=f"TX-QR-{uuid.uuid4()}",
        )
        activo = Activo_Inventariado(
            id_activo=id_activo,
            sku_qr_fisico="MOT-BO-COMP",
            id_categoria=1,
            id_estado=3,  # Vendido
            id_sucursal_actual=41,
            qr_impreso=True,
        )
        reserva = Reservas_Backorder(
            id_reserva=id_reserva,
            id_cliente=db_backorders["cli1_id"],
            id_vendedor=db_backorders["vendedor_id"],
            id_orden=id_orden,
            id_sucursal_registro=41,
            id_categoria_requerida=1,
            marca_requerida="Mazda",
            modelo_requerido="BT-50",
            precio_acordado=700000,
            monto_abonado=700000,
            id_activo_asignado=id_activo,
            estado_reserva="Confirmada",
            fecha_creacion=datetime.now(timezone.utc),
        )
        detalle = Detalle_Orden(
            id_detalle=uuid.uuid4(),
            id_orden=id_orden,
            id_activo=id_activo,
            descripcion_manual="[VENTA EN VERDE] Motor Mazda BT-50",
            precio_final=700000,
            estado_preparacion="Listo",
        )
        db.add_all([orden, activo, reserva, detalle])
        db.commit()

        # Antes de la entrega física en bodega: figura como Confirmada (NO Completada)
        res_antes = client.get("/api/v1/gerencia/backorders?q=BT-50", headers=auth_headers_gerente)
        assert res_antes.status_code == 200
        item_antes = res_antes.json()["items"][0]
        assert item_antes["estado_reserva"] == "Confirmada"
        assert item_antes["estado_orden"] == "Pagada"

        # Simular entrega física en barrera (orden pasa a Completada)
        orden_db = db.query(Orden_Venta).filter(Orden_Venta.id_orden == id_orden).first()
        reserva_db = db.query(Reservas_Backorder).filter(Reservas_Backorder.id_reserva == id_reserva).first()
        orden_db.estado_orden = "Completada"
        reserva_db.estado_reserva = "Completada"
        db.commit()

        # Tras la entrega formal: AHORA SÍ figura como Completada
        res_despues = client.get("/api/v1/gerencia/backorders?q=BT-50", headers=auth_headers_gerente)
        assert res_despues.status_code == 200
        item_despues = res_despues.json()["items"][0]
        assert item_despues["estado_reserva"] == "Completada"
        assert item_despues["estado_orden"] == "Completada"
    finally:
        db.close()


def test_auditoria_backorder_exitosa_timeline_y_cliente(client, auth_headers_gerente, db_backorders):
    """
    Verifica que el endpoint de auditoría /backorders/{id_reserva}/auditoria
    devuelve la ficha de cliente completa, desglose financiero, datos técnicos y
    la línea de tiempo de hitos cronológicos con fecha, hora y responsable.
    """
    id_reserva = db_backorders["res1_id"]
    response = client.get(
        f"/api/v1/gerencia/backorders/{id_reserva}/auditoria",
        headers=auth_headers_gerente,
    )
    assert response.status_code == 200
    data = response.json()

    # 1. Cabecera y Resumen
    assert data["id_reserva"] == str(id_reserva)
    assert data["folio"].startswith("RES-")
    assert data["marca_requerida"] == "Toyota"
    assert data["modelo_requerido"] == "Yaris"
    assert data["precio_acordado"] == 850000
    assert data["monto_abonado"] == 250000
    assert data["saldo_pendiente"] == 600000
    assert data["estado_reserva"] == "Pendiente"

    # 2. Ficha de Cliente
    assert data["cliente_nombre"] == "Juan Pérez"
    assert data["cliente_rut"] == "18.111.222-3"
    assert data["cliente_telefono"] == "+56 9 8765 4321"
    assert data["cliente_correo"] == "juan.perez@email.com"


    # 3. Responsables
    assert "Pedro Ventas" in data["vendedor_nombre"]
    assert "Sucursal 10 de Julio" in data["sucursal_nombre"]

    # 4. Línea de Tiempo (Timeline)
    movimientos = data["movimientos"]
    assert len(movimientos) >= 1
    # Hito de creación
    assert "Reserva de Venta en Verde emitida en Mesón" in movimientos[0]["evento"]
    assert "hrs" in movimientos[0]["hora"]


def test_auditoria_backorder_anulada_trazabilidad(client, auth_headers_gerente, db_backorders):
    """
    Verifica que una venta en verde anulada refleje el hito forense de anulación
    con fecha, hora, motivo, observaciones y operador responsable.
    """
    db = TestingSessionLocal()
    try:
        id_orden = uuid.uuid4()
        id_reserva = uuid.uuid4()

        orden = Orden_Venta(
            id_orden=id_orden,
            id_cliente=db_backorders["cli1_id"],
            id_vendedor=db_backorders["vendedor_id"],
            id_sucursal=41,
            estado_orden="Anulada",
            total_venta=500000,
            monto_pendiente=0,
            motivo_anulacion="Desistimiento de compra",
            observacion_anulacion="Cliente solicitó reembolso formal de seña",
            id_usuario_anulacion=db_backorders["gerente_id"],
            fecha_anulacion=datetime.now(timezone.utc),
            fecha_creacion=datetime.now(timezone.utc),
        )
        reserva = Reservas_Backorder(
            id_reserva=id_reserva,
            id_cliente=db_backorders["cli1_id"],
            id_vendedor=db_backorders["vendedor_id"],
            id_orden=id_orden,
            id_sucursal_registro=41,
            id_categoria_requerida=2,
            marca_requerida="Chevrolet",
            modelo_requerido="Sail",
            precio_acordado=500000,
            monto_abonado=100000,
            estado_reserva="Confirmada",
            fecha_creacion=datetime.now(timezone.utc),
        )
        db.add_all([orden, reserva])
        db.commit()

        response = client.get(
            f"/api/v1/gerencia/backorders/{id_reserva}/auditoria",
            headers=auth_headers_gerente,
        )
        assert response.status_code == 200
        data = response.json()

        assert data["estado_reserva"] == "Anulada"
        assert data["saldo_pendiente"] == 0
        assert data["orden_folio"] is not None

        # Verificar hito de anulación en la línea de tiempo
        movimientos = data["movimientos"]
        hitos_anulacion = [m for m in movimientos if "Operación anulada en el sistema" in m["evento"]]
        assert len(hitos_anulacion) == 1
        anul_mov = hitos_anulacion[0]
        assert "Desistimiento de compra" in anul_mov["evento"]
        assert "Cliente solicitó reembolso" in anul_mov["evento"]
        assert "Carlos Gerente" in anul_mov["evento"]
    finally:
        db.close()


def test_auditoria_backorder_no_encontrada(client, auth_headers_gerente):
    """Verifica respuesta 404 para un ID de reserva inexistente."""
    fake_id = str(uuid.uuid4())
    response = client.get(
        f"/api/v1/gerencia/backorders/{fake_id}/auditoria",
        headers=auth_headers_gerente,
    )
    assert response.status_code == 404
    assert "no encontrada" in response.json()["detail"]


def test_auditoria_backorder_seguridad_rol(client, auth_headers_vendedor, db_backorders):
    """Verifica que un usuario sin rol de Gerencia o Auditoría no tenga acceso (403 Forbidden)."""
    id_reserva = db_backorders["res1_id"]
    response = client.get(
        f"/api/v1/gerencia/backorders/{id_reserva}/auditoria",
        headers=auth_headers_vendedor,
    )
    assert response.status_code == 403

