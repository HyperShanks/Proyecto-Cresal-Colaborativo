import uuid
from datetime import datetime, timezone, timedelta
import pytest

from models import (
    Region,
    Comuna,
    Sucursal,
    Rol,
    Usuario,
    Cliente,
    Categoria_Activo,
    Estado_Activo,
    Activo_Inventariado,
    Orden_Venta,
    Detalle_Orden,
    Reservas_Backorder,
    Transaccion_Pago,
    Auditoria_Edicion_Pago,
)
from core.security import create_access_token, hash_password
from conftest import TestingSessionLocal


@pytest.fixture(scope="module")
def setup_edicion_pagos_data(setup_database):
    db = TestingSessionLocal()
    try:
        r = Region(id_region=1, nombre_region="Valparaíso")
        c = Comuna(id_comuna=1, nombre_comuna="Viña del Mar", id_region=1)
        db.add_all([r, c])

        suc1 = Sucursal(id_sucursal=1, nombre_sucursal="Casa Matriz - Viña", direccion="Av. Libertad 123", id_comuna=1)
        db.add(suc1)

        rol_vendedor = Rol(id_rol=2, nombre_rol="Vendedor")
        rol_caja = Rol(id_rol=3, nombre_rol="Caja")
        rol_admin = Rol(id_rol=5, nombre_rol="Administrador")
        db.add_all([rol_vendedor, rol_caja, rol_admin])

        u_caja = Usuario(
            id_usuario=uuid.uuid4(),
            id_rol=3,
            id_sucursal=1,
            rut_usuario="12.345.678-9",
            nombres="Lorena",
            apellidos="Valenzuela",
            email="lorena.caja@cresal.cl",
            password_hash=hash_password("caja1234"),
            pin_acceso="3003",
            estado="Activo",
        )
        u_vendedor = Usuario(
            id_usuario=uuid.uuid4(),
            id_rol=2,
            id_sucursal=1,
            rut_usuario="16.789.012-3",
            nombres="Carlos",
            apellidos="Mendoza",
            email="carlos.vendedor@cresal.cl",
            password_hash=hash_password("vend1234"),
            pin_acceso="2002",
            estado="Activo",
        )
        u_admin = Usuario(
            id_usuario=uuid.uuid4(),
            id_rol=5,
            id_sucursal=1,
            rut_usuario="11.111.111-1",
            nombres="Admin",
            apellidos="Sistema",
            email="admin@cresal.cl",
            password_hash=hash_password("admin1234"),
            pin_acceso="5005",
            estado="Activo",
        )
        db.add_all([u_caja, u_vendedor, u_admin])

        cli = Cliente(
            id_cliente=uuid.uuid4(),
            rut_cliente="18.999.888-7",
            nombres="Roberto",
            apellidos="González",
            correo="roberto@gmail.com",
            telefono="+56912345678",
            id_comuna=1,
        )
        db.add(cli)

        # Orden 1: Reservada con abono de 60.000 (total 100.000, pendiente 40.000)
        ord_reservada = Orden_Venta(
            id_orden=uuid.uuid4(),
            numero_orden=1001,
            id_cliente=cli.id_cliente,
            id_vendedor=u_vendedor.id_usuario,
            id_sucursal=1,
            estado_orden="Reservada",
            total_venta=100000,
            monto_pendiente=40000,
            fecha_creacion=datetime.now(timezone.utc).replace(tzinfo=None),
        )
        pago_abono = Transaccion_Pago(
            id_pago=uuid.uuid4(),
            id_orden=ord_reservada.id_orden,
            monto=60000,
            metodo_pago="Efectivo",
            estado_pago="Procesado",
            fecha_pago=datetime.now(timezone.utc).replace(tzinfo=None),
        )
        db.add_all([ord_reservada, pago_abono])

        # Orden 2: Pagada total (total 200.000, liquidada completa con Efectivo)
        ord_pagada = Orden_Venta(
            id_orden=uuid.uuid4(),
            numero_orden=1002,
            id_cliente=cli.id_cliente,
            id_vendedor=u_vendedor.id_usuario,
            id_sucursal=1,
            estado_orden="Pagada",
            total_venta=200000,
            monto_pendiente=0,
            qr_transaccional_salida="TX-QR-1002-TEST",
            fecha_creacion=datetime.now(timezone.utc).replace(tzinfo=None),
        )
        pago_liquidado = Transaccion_Pago(
            id_pago=uuid.uuid4(),
            id_orden=ord_pagada.id_orden,
            monto=200000,
            metodo_pago="Efectivo",
            estado_pago="Procesado",
            fecha_pago=datetime.now(timezone.utc).replace(tzinfo=None),
        )
        db.add_all([ord_pagada, pago_liquidado])

        # Orden 3: Anulada
        ord_anulada = Orden_Venta(
            id_orden=uuid.uuid4(),
            numero_orden=1003,
            id_cliente=cli.id_cliente,
            id_vendedor=u_vendedor.id_usuario,
            id_sucursal=1,
            estado_orden="Anulada",
            total_venta=50000,
            monto_pendiente=50000,
            fecha_creacion=datetime.now(timezone.utc).replace(tzinfo=None),
        )
        pago_anulado = Transaccion_Pago(
            id_pago=uuid.uuid4(),
            id_orden=ord_anulada.id_orden,
            monto=50000,
            metodo_pago="Efectivo",
            estado_pago="Procesado",
            fecha_pago=datetime.now(timezone.utc).replace(tzinfo=None),
        )
        db.add_all([ord_anulada, pago_anulado])

        db.commit()

        yield {
            "u_caja": u_caja,
            "u_vendedor": u_vendedor,
            "u_admin": u_admin,
            "ord_reservada": ord_reservada,
            "pago_abono": pago_abono,
            "ord_pagada": ord_pagada,
            "pago_liquidado": pago_liquidado,
            "ord_anulada": ord_anulada,
            "pago_anulado": pago_anulado,
        }
    finally:
        db.close()


def get_token_header(user: Usuario):
    token = create_access_token(data={"sub": str(user.id_usuario), "id_usuario": str(user.id_usuario), "id_rol": user.id_rol})
    return {"Authorization": f"Bearer {token}"}


def test_editar_metodo_pago_exitoso(client, setup_edicion_pagos_data):
    """
    Verifica que la cajera pueda corregir el método de pago de 'Efectivo' a 'Transferencia'.
    Se registra el evento en Auditoria_Edicion_Pago.
    """
    u_caja = setup_edicion_pagos_data["u_caja"]
    pago_abono = setup_edicion_pagos_data["pago_abono"]
    headers = get_token_header(u_caja)

    payload = {
        "nuevo_metodo": "Transferencia",
        "motivo": "Cajero marcó Efectivo por error, cliente transfirió",
    }

    resp = client.patch(f"/api/v1/caja/pagos/{pago_abono.id_pago}", json=payload, headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["success"] is True
    assert data["metodo_anterior"] == "Efectivo"
    assert data["metodo_nuevo"] == "Transferencia"

    # Verificar en BD
    db = TestingSessionLocal()
    try:
        p_db = db.query(Transaccion_Pago).filter_by(id_pago=pago_abono.id_pago).first()
        assert p_db.metodo_pago == "Transferencia"

        aud = db.query(Auditoria_Edicion_Pago).filter_by(id_pago=pago_abono.id_pago, campo_modificado="metodo_pago").first()
        assert aud is not None
        assert aud.valor_anterior == "Efectivo"
        assert aud.valor_nuevo == "Transferencia"
        assert aud.id_usuario == u_caja.id_usuario
        assert "transfirió" in aud.motivo
    finally:
        db.close()


def test_editar_monto_abono_parcial_exitoso(client, setup_edicion_pagos_data):
    """
    Verifica que en una orden 'Reservada' se pueda corregir un abono de $60.000 a $50.000.
    El saldo pendiente se recalcula a $50.000 y el estado permanece 'Reservada'.
    """
    u_caja = setup_edicion_pagos_data["u_caja"]
    pago_abono = setup_edicion_pagos_data["pago_abono"]
    ord_reservada = setup_edicion_pagos_data["ord_reservada"]
    headers = get_token_header(u_caja)

    payload = {
        "nuevo_monto": 50000,
        "motivo": "Error de digitación en mesón, cliente entregó $50.000",
    }

    resp = client.patch(f"/api/v1/caja/pagos/{pago_abono.id_pago}", json=payload, headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["success"] is True
    assert data["monto_anterior"] == 60000
    assert data["monto_nuevo"] == 50000
    assert data["monto_pendiente_actualizado"] == 50000
    assert data["estado_orden_actualizado"] == "Reservada"

    # Verificar en BD
    db = TestingSessionLocal()
    try:
        ord_db = db.query(Orden_Venta).filter_by(id_orden=ord_reservada.id_orden).first()
        assert ord_db.monto_pendiente == 50000
        assert ord_db.estado_orden == "Reservada"

        aud = db.query(Auditoria_Edicion_Pago).filter_by(id_pago=pago_abono.id_pago, campo_modificado="monto").first()
        assert aud is not None
        assert aud.valor_anterior == "60000"
        assert aud.valor_nuevo == "50000"
    finally:
        db.close()


def test_editar_monto_abono_rechaza_si_liquida_total(client, setup_edicion_pagos_data):
    """
    Verifica que NO se permita elevar el monto al 100% de la venta para simular liquidación.
    Debe orientar a pagar el saldo pendiente por el flujo normal de cobro.
    """
    u_caja = setup_edicion_pagos_data["u_caja"]
    pago_abono = setup_edicion_pagos_data["pago_abono"]
    headers = get_token_header(u_caja)

    payload = {
        "nuevo_monto": 100000,  # Total de la orden es 100.000
        "motivo": "Intento de liquidar orden completa mediante edición de abono",
    }

    resp = client.patch(f"/api/v1/caja/pagos/{pago_abono.id_pago}", json=payload, headers=headers)
    assert resp.status_code == 400
    assert "liquidaría el total" in resp.json()["detail"]


def test_editar_monto_rechaza_en_orden_pagada(client, setup_edicion_pagos_data):
    """
    Verifica que en una orden en estado 'Pagada' se bloquee la reducción de monto.
    Debe exigir la anulación de la orden.
    """
    u_caja = setup_edicion_pagos_data["u_caja"]
    pago_liquidado = setup_edicion_pagos_data["pago_liquidado"]
    headers = get_token_header(u_caja)

    payload = {
        "nuevo_monto": 150000,
        "motivo": "Intento de reducir monto en orden pagada",
    }

    resp = client.patch(f"/api/v1/caja/pagos/{pago_liquidado.id_pago}", json=payload, headers=headers)
    assert resp.status_code == 400
    assert "No se puede modificar el monto en una orden Pagada" in resp.json()["detail"]


def test_editar_metodo_permitido_en_orden_pagada(client, setup_edicion_pagos_data):
    """
    Verifica que en una orden 'Pagada' SÍ se permita corregir el método de pago (de Efectivo a Débito)
    para cuadrar la conciliación bancaria.
    """
    u_caja = setup_edicion_pagos_data["u_caja"]
    pago_liquidado = setup_edicion_pagos_data["pago_liquidado"]
    headers = get_token_header(u_caja)

    payload = {
        "nuevo_metodo": "Debito",
        "motivo": "Corrección de medio de pago: cliente pagó con tarjeta de débito voucher 84920",
    }

    resp = client.patch(f"/api/v1/caja/pagos/{pago_liquidado.id_pago}", json=payload, headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["metodo_anterior"] == "Efectivo"
    assert data["metodo_nuevo"] == "Debito"


def test_editar_fecha_pago_exitoso_y_rechazo_futura(client, setup_edicion_pagos_data):
    """
    Verifica que se permita ajustar la fecha hacia el pasado (ej: pago fuera de horario)
    pero se rechace si la fecha es futura.
    """
    u_admin = setup_edicion_pagos_data["u_admin"]
    pago_abono = setup_edicion_pagos_data["pago_abono"]
    headers = get_token_header(u_admin)

    # 1. Fecha en el pasado (ayer)
    fecha_ayer = (datetime.now(timezone.utc) - timedelta(days=1)).isoformat()
    resp_ok = client.patch(
        f"/api/v1/caja/pagos/{pago_abono.id_pago}",
        json={"nueva_fecha_pago": fecha_ayer, "motivo": "Transferencia realizada ayer viernes fuera de horario"},
        headers=headers,
    )
    assert resp_ok.status_code == 200

    # 2. Fecha en el futuro (mañana)
    fecha_manana = (datetime.now(timezone.utc) + timedelta(days=2)).isoformat()
    resp_err = client.patch(
        f"/api/v1/caja/pagos/{pago_abono.id_pago}",
        json={"nueva_fecha_pago": fecha_manana, "motivo": "Intento de fijar fecha futura en el pago"},
        headers=headers,
    )
    assert resp_err.status_code == 400
    assert "no puede ser futura" in resp_err.json()["detail"]


def test_rechazo_motivo_muy_corto(client, setup_edicion_pagos_data):
    """
    Verifica que se exija un motivo explicativo de al menos 10 caracteres para auditoría.
    """
    u_caja = setup_edicion_pagos_data["u_caja"]
    pago_abono = setup_edicion_pagos_data["pago_abono"]
    headers = get_token_header(u_caja)

    resp = client.patch(
        f"/api/v1/caja/pagos/{pago_abono.id_pago}",
        json={"nuevo_metodo": "Debito", "motivo": "error"},
        headers=headers,
    )
    assert resp.status_code in [400, 422]


def test_rechazo_orden_anulada(client, setup_edicion_pagos_data):
    """
    Verifica que no se permita modificar pagos de una orden ya Anulada.
    """
    u_caja = setup_edicion_pagos_data["u_caja"]
    pago_anulado = setup_edicion_pagos_data["pago_anulado"]
    headers = get_token_header(u_caja)

    resp = client.patch(
        f"/api/v1/caja/pagos/{pago_anulado.id_pago}",
        json={"nuevo_metodo": "Debito", "motivo": "Intento de modificar orden anulada"},
        headers=headers,
    )
    assert resp.status_code == 400
    assert "Anulada" in resp.json()["detail"]


def test_rbac_vendedor_rechazado_403(client, setup_edicion_pagos_data):
    """
    Verifica que un vendedor común (id_rol == 2) no tenga permisos para editar pagos (403 Forbidden).
    """
    u_vendedor = setup_edicion_pagos_data["u_vendedor"]
    pago_abono = setup_edicion_pagos_data["pago_abono"]
    headers = get_token_header(u_vendedor)

    resp = client.patch(
        f"/api/v1/caja/pagos/{pago_abono.id_pago}",
        json={"nuevo_metodo": "Debito", "motivo": "Intento de vendedor de alterar pago"},
        headers=headers,
    )
    assert resp.status_code == 403
    assert "Acceso denegado" in resp.json()["detail"]


def test_linea_de_tiempo_muestra_edicion_auditada(client, setup_edicion_pagos_data):
    """
    Verifica que al consultar el historial de caja, la línea de tiempo (historial_movimientos)
    contenga el registro claro de la corrección realizada con usuario y motivo.
    """
    u_caja = setup_edicion_pagos_data["u_caja"]
    ord_reservada = setup_edicion_pagos_data["ord_reservada"]
    headers = get_token_header(u_caja)

    resp = client.get("/api/v1/caja/historial?sucursal_id=1&periodo=TODOS", headers=headers)
    assert resp.status_code == 200
    items = resp.json()["items"]
    orden_item = next((it for it in items if it["id_orden"] == str(ord_reservada.id_orden)), None)
    assert orden_item is not None

    movimientos = orden_item["historial_movimientos"]
    # Debe haber un movimiento de método corregido o monto modificado
    mov_edicion = next((m for m in movimientos if "corregido" in m["evento"].lower() or "modificado" in m["evento"].lower()), None)
    assert mov_edicion is not None
    assert "Lorena" in mov_edicion["evento"] or "Admin" in mov_edicion["evento"]
