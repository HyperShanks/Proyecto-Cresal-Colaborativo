# test_inventario_busqueda.py
# Suite de pruebas automatizadas para SPEC-HU-TAREA-14: Búsqueda directa por N° de Ingreso

import uuid
import pytest
from datetime import datetime, timezone
from models import (
    Region, Comuna, Sucursal, Rol, Usuario,
    Categoria_Activo, Estado_Activo, Vehiculo_Origen,
    Activo_Inventariado, Detalle_Motor, Detalle_Caja_Cambio
)
from core.security import create_access_token
from conftest import TestingSessionLocal


@pytest.fixture(scope="module")
def setup_inventario_test(setup_database):
    db = TestingSessionLocal()
    try:
        # 1. Región y Comuna
        reg = db.query(Region).filter_by(id_region=1).first()
        if not reg:
            reg = Region(id_region=1, nombre_region="Valparaíso")
            db.add(reg)
            db.flush()

        com1 = db.query(Comuna).filter_by(id_comuna=1).first()
        if not com1:
            com1 = Comuna(id_comuna=1, nombre_comuna="Viña del Mar", id_region=1)
            db.add(com1)
            db.flush()

        # 2. Sucursal
        suc = db.query(Sucursal).filter_by(id_sucursal=1).first()
        if not suc:
            suc = Sucursal(id_sucursal=1, nombre_sucursal="Casa Matriz - Viña", direccion="Camino Internacional 4105", id_comuna=1)
            db.add(suc)
            db.flush()

        # 3. Roles
        rol_bodega = db.query(Rol).filter_by(id_rol=1).first()
        if not rol_bodega:
            rol_bodega = Rol(id_rol=1, nombre_rol="Bodeguero")
            db.add(rol_bodega)
            db.flush()

        # 4. Estados Activo
        estados_data = [
            (1, "Disponible"),
            (5, "Pendiente de Paletizado"),
            (7, "Paletizado"),
        ]
        for e_id, e_nom in estados_data:
            e = db.query(Estado_Activo).filter_by(id_estado=e_id).first()
            if not e:
                db.add(Estado_Activo(id_estado=e_id, nombre_estado=e_nom))
        db.flush()

        # 5. Categorías
        cat_motor = db.query(Categoria_Activo).filter_by(id_categoria=1).first()
        if not cat_motor:
            cat_motor = Categoria_Activo(id_categoria=1, nombre_categoria="Motor")
            db.add(cat_motor)
            db.flush()

        cat_caja = db.query(Categoria_Activo).filter_by(id_categoria=2).first()
        if not cat_caja:
            cat_caja = Categoria_Activo(id_categoria=2, nombre_categoria="Caja de Cambios")
            db.add(cat_caja)
            db.flush()

        # 6. Usuario Bodeguero
        user_bodega = db.query(Usuario).filter_by(rut_usuario="18888888-8").first()
        if not user_bodega:
            user_bodega = Usuario(
                id_usuario=uuid.uuid4(),
                rut_usuario="18888888-8",
                nombres="Pedro",
                apellidos="Bodeguero",
                email="pedro.bodega@cresal.cl",
                password_hash="mock_hash",
                id_rol=1,
                id_sucursal=1,
                pin_acceso="1234",
                estado="Activo",
            )
            db.add(user_bodega)
            db.flush()

        # 7. Vehículo 1: Pendiente de Paletizado (Folio 7001)
        veh_pendiente = db.query(Vehiculo_Origen).filter_by(numero_ingreso="7001").first()
        if not veh_pendiente:
            veh_pendiente = Vehiculo_Origen(
                id_vehiculo=uuid.uuid4(),
                numero_ingreso="7001",
                marca="Toyota",
                modelo="Corolla",
                anio=2021,
                patente="ABCD12",
                estado="Recepcionado",
            )
            db.add(veh_pendiente)
            db.flush()

            # Activo Motor pendiente de paletizado (id_estado=5, sin pasillo ni pallet)
            activo_motor = Activo_Inventariado(
                id_activo=uuid.uuid4(),
                sku_qr_fisico="QR-MOTO-7001",
                id_categoria=1,
                id_estado=5,
                id_sucursal_actual=1,
                id_vehiculo=veh_pendiente.id_vehiculo,
                ubicacion_pasillo=None,
                ubicacion_pallet=None,
                estado="Activo",
            )
            db.add(activo_motor)
            db.flush()

            det_motor = Detalle_Motor(
                id_activo=activo_motor.id_activo,
                numero_motor="1ZR-FE-9988",
                cilindrada="1.8L",
                combustible="Bencina",
                transmision_tipo="Manual",
            )
            db.add(det_motor)

        # 8. Vehículo 2: Ya Paletizado / Procesado (Folio 7002)
        veh_paletizado = db.query(Vehiculo_Origen).filter_by(numero_ingreso="7002").first()
        if not veh_paletizado:
            veh_paletizado = Vehiculo_Origen(
                id_vehiculo=uuid.uuid4(),
                numero_ingreso="7002",
                marca="Nissan",
                modelo="Sentra",
                anio=2020,
                patente="XYZW99",
                estado="Completado",
            )
            db.add(veh_paletizado)
            db.flush()

            # Activo Motor ya paletizado (id_estado=1, con pasillo y pallet asignados)
            activo_motor_listo = Activo_Inventariado(
                id_activo=uuid.uuid4(),
                sku_qr_fisico="QR-MOTO-7002",
                id_categoria=1,
                id_estado=1,
                id_sucursal_actual=1,
                id_vehiculo=veh_paletizado.id_vehiculo,
                ubicacion_pasillo="P-02",
                ubicacion_pallet="PAL-05",
                ubicacion_galpon="G-1",
                estado="Activo",
            )
            db.add(activo_motor_listo)
            db.flush()

            det_motor_listo = Detalle_Motor(
                id_activo=activo_motor_listo.id_activo,
                numero_motor="1ZR-FE-9988",
                cilindrada="1.8L",
                combustible="Bencina",
                transmision_tipo="Manual",
            )
            db.add(det_motor_listo)

        db.commit()

        token = create_access_token(data={"sub": str(user_bodega.id_usuario), "id_rol": 1, "id_sucursal": 1})
        headers = {"Authorization": f"Bearer {token}"}
        yield headers

    finally:
        db.close()


def test_busqueda_ingreso_exitoso_pendiente(client, setup_inventario_test):
    """
    Debe retornar 200 con los datos del vehículo y repuestos cuando
    el número de ingreso existe y tiene activos pendientes de paletizar.
    """
    headers = setup_inventario_test
    response = client.get("/api/v1/inventario/ingreso/7001", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["numero_ingreso"] == "7001"
    assert data["pendiente_paletizado"] is True
    assert data["vehiculo"]["marca"] == "Toyota"
    assert data["vehiculo"]["modelo"] == "Corolla"
    assert data["motor"]["numero_motor"] == "1ZR-FE-9988"
    assert data["motor"]["pendiente"] is True
    assert data["total_pendientes"] == 1


def test_busqueda_ingreso_no_encontrado_404(client, setup_inventario_test):
    """
    Debe retornar 404 con el mensaje exacto cuando el folio no existe en BD.
    """
    headers = setup_inventario_test
    response = client.get("/api/v1/inventario/ingreso/999999", headers=headers)
    assert response.status_code == 404
    data = response.json()
    assert data["detail"] == "Número de ingreso no encontrado en la base de datos."


def test_busqueda_ingreso_ya_paletizado_400(client, setup_inventario_test):
    """
    Debe retornar 400 con el mensaje exacto cuando el vehículo ya fue paletizado.
    """
    headers = setup_inventario_test
    response = client.get("/api/v1/inventario/ingreso/7002", headers=headers)
    assert response.status_code == 400
    data = response.json()
    assert data["detail"] == "El activo asociado a este número ya fue paletizado previamente o no requiere este flujo."


def test_busqueda_bodeguero_por_siglas_numero_motor(client, setup_inventario_test):
    """
    Verifica que el bodeguero en su inventario (/buscar) pueda buscar por el
    número de motor o sus siglas (ej. '1ZR', '1ZR-FE', '1zrfe') y obtener resultados.
    """
    headers = setup_inventario_test

    # 1. Búsqueda por sigla del motor '1ZR'
    res1 = client.get("/api/v1/inventario/buscar?q=1ZR&estado=Todos", headers=headers)
    assert res1.status_code == 200
    items1 = res1.json()
    skus1 = [it["sku"] for it in items1]
    assert "QR-MOTO-7002" in skus1
    # Verificar que el número de motor se incluya en el response
    motor_item = next(it for it in items1 if it["sku"] == "QR-MOTO-7002")
    assert motor_item["numero_motor"] == "1ZR-FE-9988"

    # 2. Búsqueda sin guiones '1zrfe' (tolerancia de siglas)
    res2 = client.get("/api/v1/inventario/buscar?q=1zrfe&estado=Todos", headers=headers)
    assert res2.status_code == 200
    skus2 = [it["sku"] for it in res2.json()]
    assert "QR-MOTO-7002" in skus2

    # 3. Búsqueda por subcadena numérica '9988'
    res3 = client.get("/api/v1/inventario/buscar?q=9988&estado=Todos", headers=headers)
    assert res3.status_code == 200
    skus3 = [it["sku"] for it in res3.json()]
    assert "QR-MOTO-7002" in skus3


def test_busqueda_catalogo_y_gerencia_por_siglas_numero_motor(client, setup_database):
    """
    Verifica que los vendedores en catálogo (/catalogo) y gerencia en inventario (/maestro)
    puedan buscar por las siglas del número de motor (ej. '2ZR', '2ZR-FE', '2zrfe') y encontrar los repuestos.
    """
    db = TestingSessionLocal()
    try:
        user_gerente = Usuario(
            id_usuario=uuid.uuid4(),
            rut_usuario="99.888.777-6",
            nombres="Gloria",
            apellidos="Gerente",
            email="gloria_test_motor@cresal.cl",
            password_hash="mock_hash",
            id_rol=5,  # Gerente
            id_sucursal=1,
            pin_acceso="5555",
            estado="Activo",
        )
        db.add(user_gerente)

        user_vendedor = Usuario(
            id_usuario=uuid.uuid4(),
            rut_usuario="99.777.666-5",
            nombres="Victor",
            apellidos="Vendedor",
            email="victor_test_motor@cresal.cl",
            password_hash="mock_hash",
            id_rol=2,  # Vendedor
            id_sucursal=1,
            pin_acceso="2222",
            estado="Activo",
        )
        db.add(user_vendedor)
        db.flush()

        veh = Vehiculo_Origen(
            id_vehiculo=uuid.uuid4(),
            numero_ingreso="8801",
            marca="Toyota",
            modelo="Auris",
            anio=2022,
            patente="AURI22",
            estado="Completado",
            numero_motor="2ZR-FXE-12345",
        )
        db.add(veh)
        db.flush()

        activo_motor = Activo_Inventariado(
            id_activo=uuid.uuid4(),
            sku_qr_fisico="MOT-TOY-8801",
            id_categoria=1,
            id_estado=1,  # Disponible
            id_sucursal_actual=1,
            id_vehiculo=veh.id_vehiculo,
            ubicacion_pasillo="A-1",
            ubicacion_pallet="PAL-10",
            ubicacion_galpon="G-2",
            precio_referencia=1200000,
            precio_minimo=1000000,
            precio_maximo=1400000,
            estado="Activo",
        )
        db.add(activo_motor)
        db.flush()

        det_motor = Detalle_Motor(
            id_activo=activo_motor.id_activo,
            numero_motor="2ZR-FXE-12345",
            cilindrada="1.8L",
            combustible="Híbrido",
            transmision_tipo="Automática",
        )
        db.add(det_motor)
        db.commit()

        token_gerente = create_access_token(data={"sub": str(user_gerente.id_usuario), "id_rol": 5, "id_sucursal": 1})
        headers_gerente = {"Authorization": f"Bearer {token_gerente}"}

        token_vendedor = create_access_token(data={"sub": str(user_vendedor.id_usuario), "id_rol": 2, "id_sucursal": 1})
        headers_vendedor = {"Authorization": f"Bearer {token_vendedor}"}

        # A. Catálogo (Vendedores) con sigla '2ZR'
        res_cat = client.get("/api/v1/inventario/catalogo?q=2ZR", headers=headers_vendedor)
        assert res_cat.status_code == 200
        items_cat = res_cat.json()["items"]
        skus_cat = [it["sku_qr_fisico"] for it in items_cat]
        assert "MOT-TOY-8801" in skus_cat
        assert items_cat[0]["numero_motor"] == "2ZR-FXE-12345"

        # B. Catálogo con subcadena sin guión '2zrfxe'
        res_cat_clean = client.get("/api/v1/inventario/catalogo?q=2zrfxe", headers=headers_vendedor)
        assert res_cat_clean.status_code == 200
        skus_cat_clean = [it["sku_qr_fisico"] for it in res_cat_clean.json()["items"]]
        assert "MOT-TOY-8801" in skus_cat_clean

        # C. Gerencia Maestro con sigla '2ZR'
        res_ger = client.get("/api/v1/inventario/maestro?q=2ZR", headers=headers_gerente)
        assert res_ger.status_code == 200
        items_ger = res_ger.json()["items"]
        skus_ger = [it["sku_qr_fisico"] for it in items_ger]
        assert "MOT-TOY-8801" in skus_ger
        assert items_ger[0]["numero_motor"] == "2ZR-FXE-12345"

        # D. Gerencia Maestro con subcadena numérica '12345'
        res_ger_num = client.get("/api/v1/inventario/maestro?q=12345", headers=headers_gerente)
        assert res_ger_num.status_code == 200
        skus_ger_num = [it["sku_qr_fisico"] for it in res_ger_num.json()["items"]]
        assert "MOT-TOY-8801" in skus_ger_num

    finally:
        db.close()
