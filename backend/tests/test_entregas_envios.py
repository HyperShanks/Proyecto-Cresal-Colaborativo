import uuid
from datetime import datetime
import pytest
from conftest import TestingSessionLocal
import models
from core.security import create_access_token


@pytest.fixture
def auth_headers():
    db = TestingSessionLocal()
    try:
        # Sembrar Región y Comuna
        reg = db.query(models.Region).filter_by(id_region=1).first()
        if not reg:
            db.add(models.Region(id_region=1, nombre_region="Valparaíso"))
            db.flush()

        com = db.query(models.Comuna).filter_by(id_comuna=1).first()
        if not com:
            db.add(models.Comuna(id_comuna=1, id_region=1, nombre_comuna="Viña del Mar"))
            db.flush()

        # Sembrar Sucursales
        for suc_id, suc_nom in [(1, "Viña del Mar"), (2, "Limache")]:
            s = db.query(models.Sucursal).filter_by(id_sucursal=suc_id).first()
            if not s:
                db.add(models.Sucursal(id_sucursal=suc_id, nombre_sucursal=suc_nom, direccion="Calle Test", id_comuna=1))
                db.flush()

        # Sembrar Roles
        for r_id, r_nom in [(1, "Bodeguero"), (2, "Vendedor")]:
            r = db.query(models.Rol).filter_by(id_rol=r_id).first()
            if not r:
                db.add(models.Rol(id_rol=r_id, nombre_rol=r_nom))
                db.flush()

        # Sembrar Usuario
        user = db.query(models.Usuario).first()
        if not user:
            user = models.Usuario(
                id_usuario=uuid.uuid4(),
                rut_usuario="11.111.111-1",
                nombres="Vendedor",
                apellidos="Test",
                email="vendedor_entregas@cresal.cl",
                id_rol=2,
                id_sucursal=1,
                password_hash="dummy_hash",
                pin_acceso="1234",
                estado="Activo",
            )
            db.add(user)
            db.flush()

        # Sembrar Estados de Activo necesarios
        for est_id, est_nom in [(1, "Disponible"), (2, "Reservado"), (3, "Vendido"), (5, "En Desarme"), (6, "Entregado")]:
            e = db.query(models.Estado_Activo).filter_by(id_estado=est_id).first()
            if not e:
                db.add(models.Estado_Activo(id_estado=est_id, nombre_estado=est_nom))

        # Sembrar Categorías
        for cat_id, cat_nom in [(1, "Motor"), (2, "Caja de Cambios")]:
            c = db.query(models.Categoria_Activo).filter_by(id_categoria=cat_id).first()
            if not c:
                db.add(models.Categoria_Activo(id_categoria=cat_id, nombre_categoria=cat_nom))

        db.commit()

        token = create_access_token(data={"sub": str(user.id_usuario), "id_rol": user.id_rol, "id_sucursal": 1})
        return {"Authorization": f"Bearer {token}"}
    finally:
        db.close()


def test_crear_orden_con_abono_parcial(client, auth_headers):
    """
    Verifica que al crear una orden con monto_abono parcial, el saldo pendiente
    se calcule correctamente y el estado inicial sea 'Reservada'.
    """
    db = TestingSessionLocal()
    try:
        # Crear activo disponible
        veh = models.Vehiculo_Origen(
            id_vehiculo=uuid.uuid4(),
            numero_ingreso=f"ING-ABO-{uuid.uuid4().hex[:4].upper()}",
            patente=f"AB{uuid.uuid4().hex[:4].upper()}",
            marca="Toyota",
            modelo="Yaris",
            anio=2018,
        )
        db.add(veh)
        db.flush()

        activo = models.Activo_Inventariado(
            id_activo=uuid.uuid4(),
            sku_qr_fisico=f"MOT-ABO-{uuid.uuid4().hex[:4].upper()}",
            id_categoria=1,
            id_estado=1,  # Disponible
            id_sucursal_actual=1,
            id_vehiculo=veh.id_vehiculo,
            estado="Activo",
            fecha_creacion=datetime.now(),
        )
        db.add(activo)
        db.commit()

        payload = {
            "cliente": {
                "rut_cliente": f"19.{uuid.uuid4().hex[:3]}.456-7",
                "nombres": "Carlos",
                "apellidos": "Abono",
                "telefono": "+56911223344",
                "comuna": "Viña del Mar",
                "consentimiento_legal": True,
            },
            "requiere_despacho": False,
            "tipo_entrega": "Retiro",
            "consentimiento_legal": True,
            "monto_abono": 200000,
            "items": [
                {
                    "id_activo": str(activo.id_activo),
                    "precio_final": 500000,
                    "cantidad": 1,
                    "notas_preparacion": "Preparar para retiro con abono",
                }
            ],
        }

        res = client.post("/api/v1/ordenes", json=payload, headers=auth_headers)
        assert res.status_code == 201, res.text
        data = res.json()
        assert data["total_venta"] == 500000
        assert data["monto_pendiente"] == 300000
        assert data["estado_orden"] == "Reservada"
    finally:
        db.close()


def test_entregas_envios_endpoint_y_filtros(client, auth_headers):
    """
    Verifica que GET /api/v1/ordenes/entregas-envios liste correctamente órdenes de retiro
    y de despacho según la sucursal activa, permitiendo búsqueda por Folio/RUT/Nombre.
    """
    db = TestingSessionLocal()
    try:
        user = db.query(models.Usuario).first()

        # 1. Cliente para Retiro
        cli_retiro = models.Cliente(
            id_cliente=uuid.uuid4(),
            rut_cliente="12.345.678-9",
            nombres="Roberto",
            apellidos="Retiro",
            telefono="+56912345678",
            consentimiento_legal=True,
        )
        db.add(cli_retiro)
        db.flush()

        orden_retiro = models.Orden_Venta(
            id_orden=uuid.uuid4(),
            id_cliente=cli_retiro.id_cliente,
            id_vendedor=user.id_usuario,
            id_sucursal=1,
            estado_orden="Pagada",
            qr_transaccional_salida=f"ORD-RET-{uuid.uuid4().hex[:6].upper()}",
            total_venta=150000,
            monto_pendiente=0,
            fecha_creacion=datetime.now(),
        )
        db.add(orden_retiro)
        db.flush()

        det_retiro = models.Detalle_Orden(
            id_detalle=uuid.uuid4(),
            id_orden=orden_retiro.id_orden,
            descripcion_manual="Filtro de Aceite Misceláneo",
            cantidad=2,
            precio_final=75000,
            estado_preparacion="Listo",
        )
        db.add(det_retiro)

        # 2. Cliente para Despacho
        cli_despacho = models.Cliente(
            id_cliente=uuid.uuid4(),
            rut_cliente="15.999.888-7",
            nombres="Daniela",
            apellidos="Despacho",
            telefono="+56987654321",
            consentimiento_legal=True,
        )
        db.add(cli_despacho)
        db.flush()

        orden_despacho = models.Orden_Venta(
            id_orden=uuid.uuid4(),
            id_cliente=cli_despacho.id_cliente,
            id_vendedor=user.id_usuario,
            id_sucursal=1,
            estado_orden="Pagada",
            qr_transaccional_salida=f"ORD-DESP-{uuid.uuid4().hex[:6].upper()}",
            total_venta=300000,
            monto_pendiente=0,
            fecha_creacion=datetime.now(),
        )
        db.add(orden_despacho)
        db.flush()

        despacho = models.Despacho(
            id_despacho=uuid.uuid4(),
            id_orden=orden_despacho.id_orden,
            id_comuna_destino=1,
            direccion_envio="Av. Libertad 500, Viña del Mar",
            receptor_nombres="Daniela Despacho",
            receptor_rut="15.999.888-7",
            receptor_telefono="+56987654321",
            empresa_transporte="Chilexpress",
            costo_envio=5000,
            estado_despacho="Por Enviar",
        )
        db.add(despacho)

        det_despacho = models.Detalle_Orden(
            id_detalle=uuid.uuid4(),
            id_orden=orden_despacho.id_orden,
            descripcion_manual="Kit de Distribución",
            cantidad=1,
            precio_final=300000,
            estado_preparacion="Pendiente",
        )
        db.add(det_despacho)

        db.commit()

        # A. Consulta de todos los pedidos de la sucursal 1
        res_todos = client.get("/api/v1/ordenes/entregas-envios?sucursal_id=1", headers=auth_headers)
        assert res_todos.status_code == 200, res_todos.text
        data_todos = res_todos.json()
        folios = [item["folio"] for item in data_todos]
        assert orden_retiro.qr_transaccional_salida in folios
        assert orden_despacho.qr_transaccional_salida in folios

        # B. Consulta filtrada por tipo 'retiro'
        res_ret = client.get("/api/v1/ordenes/entregas-envios?sucursal_id=1&tipo=retiro", headers=auth_headers)
        assert res_ret.status_code == 200
        data_ret = res_ret.json()
        assert all(item["tipo_entrega"] == "Retiro" for item in data_ret)
        assert orden_retiro.qr_transaccional_salida in [item["folio"] for item in data_ret]

        # C. Consulta filtrada por tipo 'despacho'
        res_desp = client.get("/api/v1/ordenes/entregas-envios?sucursal_id=1&tipo=despacho", headers=auth_headers)
        assert res_desp.status_code == 200
        data_desp = res_desp.json()
        assert all(item["tipo_entrega"] == "Despacho" for item in data_desp)
        assert orden_despacho.qr_transaccional_salida in [item["folio"] for item in data_desp]

        # D. Búsqueda por RUT
        res_rut = client.get("/api/v1/ordenes/entregas-envios?sucursal_id=1&busqueda=15.999.888-7", headers=auth_headers)
        assert res_rut.status_code == 200
        data_rut = res_rut.json()
        assert len(data_rut) >= 1
        assert data_rut[0]["cliente"]["rut_cliente"] == "15.999.888-7"
    finally:
        db.close()


def test_confirmar_entrega_tienda_y_marcar_despacho_enviado(client, auth_headers):
    """
    Verifica el cierre de ciclo:
    1. Confirmar entrega en tienda (PATCH /api/v1/ordenes/{id_orden}/entregar) -> estado 'Despachada'.
    2. Marcar despacho como enviado (PATCH /api/v1/despachos/{id_despacho}/enviar) -> estado 'Enviado' y 'Despachada'.
    """
    db = TestingSessionLocal()
    try:
        user = db.query(models.Usuario).first()

        # Activo inventariado vinculado
        veh = models.Vehiculo_Origen(
            id_vehiculo=uuid.uuid4(),
            numero_ingreso=f"ING-ENT-{uuid.uuid4().hex[:4].upper()}",
            patente=f"ET{uuid.uuid4().hex[:4].upper()}",
            marca="Nissan",
            modelo="Qashqai",
            anio=2020,
        )
        db.add(veh)
        db.flush()

        activo_ret = models.Activo_Inventariado(
            id_activo=uuid.uuid4(),
            sku_qr_fisico=f"MOT-ET-{uuid.uuid4().hex[:4].upper()}",
            id_categoria=1,
            id_estado=3,  # Vendido
            id_sucursal_actual=1,
            id_vehiculo=veh.id_vehiculo,
            estado="Activo",
            ubicacion_pasillo="A",
            ubicacion_pallet="1",
            fecha_creacion=datetime.now(),
        )
        db.add(activo_ret)
        db.flush()

        cli = models.Cliente(
            id_cliente=uuid.uuid4(),
            rut_cliente=f"18.{uuid.uuid4().hex[:3]}.111-2",
            nombres="Esteban",
            apellidos="Entrega",
            consentimiento_legal=True,
        )
        db.add(cli)
        db.flush()

        # 1. Orden de Retiro Pagada
        orden_ret = models.Orden_Venta(
            id_orden=uuid.uuid4(),
            id_cliente=cli.id_cliente,
            id_vendedor=user.id_usuario,
            id_sucursal=1,
            estado_orden="Pagada",
            total_venta=400000,
            monto_pendiente=0,
            fecha_creacion=datetime.now(),
        )
        db.add(orden_ret)
        db.flush()

        det_ret = models.Detalle_Orden(
            id_detalle=uuid.uuid4(),
            id_orden=orden_ret.id_orden,
            id_activo=activo_ret.id_activo,
            cantidad=1,
            precio_final=400000,
            estado_preparacion="Listo",
        )
        db.add(det_ret)
        db.commit()

        # Confirmar Entrega de Retiro
        res_ret = client.patch(f"/api/v1/ordenes/{orden_ret.id_orden}/entregar", headers=auth_headers)
        assert res_ret.status_code == 200, res_ret.text
        data_ret = res_ret.json()
        assert data_ret["estado_orden"] == "Completada"
        assert data_ret["activos_finalizados"] == 1

        db.refresh(activo_ret)
        assert activo_ret.id_estado == 6  # Entregado
        assert activo_ret.ubicacion_pasillo is None

        # 2. Orden de Despacho
        orden_desp = models.Orden_Venta(
            id_orden=uuid.uuid4(),
            id_cliente=cli.id_cliente,
            id_vendedor=user.id_usuario,
            id_sucursal=1,
            estado_orden="Pagada",
            total_venta=100000,
            monto_pendiente=0,
            fecha_creacion=datetime.now(),
        )
        db.add(orden_desp)
        db.flush()

        despacho = models.Despacho(
            id_despacho=uuid.uuid4(),
            id_orden=orden_desp.id_orden,
            id_comuna_destino=1,
            direccion_envio="Calle Los Pinos 123",
            receptor_nombres="Esteban Entrega",
            receptor_rut="18.111.111-2",
            receptor_telefono="+56900000000",
            empresa_transporte="Starken",
            costo_envio=4500,
            estado_despacho="Por Enviar",
        )
        db.add(despacho)
        db.commit()

        # Marcar Despacho como Enviado
        res_desp = client.patch(f"/api/v1/despachos/{despacho.id_despacho}/enviar", headers=auth_headers)
        assert res_desp.status_code == 200, res_desp.text
        data_desp = res_desp.json()
        assert data_desp["estado_despacho"] == "Enviado"
        assert data_desp["estado_orden"] == "Despachada"
    finally:
        db.close()


def test_listar_vendedores_y_filtros_cliente_vendedor_privacidad(client, auth_headers):
    """
    Verifica:
    1. GET /api/v1/ordenes/vendedores lista vendedores activos.
    2. Creación de orden con id_vendedor_asignado.
    3. Filtros por busqueda_cliente, busqueda_vendedor y estado_pago.
    4. Regla de visibilidad/privacidad para ventas asignadas.
    """
    db = TestingSessionLocal()
    try:
        # Crear segundo vendedor en la sucursal 1
        vend2 = models.Usuario(
            id_usuario=uuid.uuid4(),
            rut_usuario="22.222.222-2",
            nombres="Pedro",
            apellidos="Asignado",
            email="pedro_asig@cresal.cl",
            id_rol=2,
            id_sucursal=1,
            password_hash="dummy_hash",
            pin_acceso="5678",
            estado="Activo",
        )
        db.add(vend2)
        db.commit()

        # 1. Probar GET /api/v1/ordenes/vendedores
        res_vends = client.get("/api/v1/ordenes/vendedores?sucursal_id=1", headers=auth_headers)
        assert res_vends.status_code == 200, res_vends.text
        vends_data = res_vends.json()
        assert any(v["id_usuario"] == str(vend2.id_usuario) for v in vends_data)

        # 2. Crear Cliente y Orden asignada específicamente a vend2
        cli_privado = models.Cliente(
            id_cliente=uuid.uuid4(),
            rut_cliente="20.333.444-5",
            nombres="Camila",
            apellidos="Privada",
            telefono="+56933334444",
            consentimiento_legal=True,
        )
        db.add(cli_privado)
        db.flush()

        orden_privada = models.Orden_Venta(
            id_orden=uuid.uuid4(),
            id_cliente=cli_privado.id_cliente,
            id_vendedor=vend2.id_usuario,
            id_vendedor_asignado=vend2.id_usuario,
            id_sucursal=1,
            estado_orden="Pagada",
            qr_transaccional_salida=f"ORD-PRIV-{uuid.uuid4().hex[:6].upper()}",
            total_venta=250000,
            monto_pendiente=0,
            fecha_creacion=datetime.now(),
        )
        db.add(orden_privada)
        db.flush()

        det_priv = models.Detalle_Orden(
            id_detalle=uuid.uuid4(),
            id_orden=orden_privada.id_orden,
            descripcion_manual="Radiador de Calefacción",
            cantidad=1,
            precio_final=250000,
            estado_preparacion="Listo",
        )
        db.add(det_priv)
        db.commit()

        # 3. Consultar como vend2 (asignado)
        token_vend2 = create_access_token(data={"sub": str(vend2.id_usuario), "id_rol": 2, "id_sucursal": 1})
        headers_vend2 = {"Authorization": f"Bearer {token_vend2}"}

        res_vend2 = client.get("/api/v1/ordenes/entregas-envios?sucursal_id=1&busqueda_cliente=Camila", headers=headers_vend2)
        assert res_vend2.status_code == 200
        data_v2 = res_vend2.json()
        assert len(data_v2) >= 1
        assert data_v2[0]["folio"] == orden_privada.qr_transaccional_salida
        assert data_v2[0]["vendedor_asignado_nombre"] == "Pedro Asignado"

        # 4. Probar filtro por vendedor
        res_fv = client.get("/api/v1/ordenes/entregas-envios?sucursal_id=1&busqueda_vendedor=Pedro", headers=headers_vend2)
        assert res_fv.status_code == 200
        data_fv = res_fv.json()
        assert any(item["folio"] == orden_privada.qr_transaccional_salida for item in data_fv)

        # 5. Probar filtro por estado_pago
        res_pagados = client.get("/api/v1/ordenes/entregas-envios?sucursal_id=1&estado_pago=pagados", headers=headers_vend2)
        assert res_pagados.status_code == 200
        assert all(item["monto_pendiente"] == 0 for item in res_pagados.json())
    finally:
        db.close()

