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
        # 1. Region y Comuna
        reg = db.query(models.Region).filter(models.Region.id_region == 1).first()
        if not reg:
            reg = models.Region(id_region=1, nombre_region="Valparaíso")
            db.add(reg)
            db.commit()

        com = db.query(models.Comuna).filter(models.Comuna.id_comuna == 1).first()
        if not com:
            com = models.Comuna(id_comuna=1, nombre_comuna="Viña del Mar", id_region=1)
            db.add(com)
            db.commit()

        # 2. Sucursal y Rol
        sucursal = db.query(models.Sucursal).filter(models.Sucursal.id_sucursal == 1).first()
        if not sucursal:
            sucursal = models.Sucursal(
                id_sucursal=1,
                nombre_sucursal="Casa Matriz - Viña",
                direccion="Calle 1",
                id_comuna=1,
            )
            db.add(sucursal)

        rol = db.query(models.Rol).filter(models.Rol.id_rol == 1).first()
        if not rol:
            rol = models.Rol(id_rol=1, nombre_rol="Bodeguero")
            db.add(rol)
        db.commit()

        # 3. Categorías y Estados
        for cat_id, cat_nom in [(1, "Motor"), (2, "Caja de Cambios")]:
            c = db.query(models.Categoria_Activo).filter_by(id_categoria=cat_id).first()
            if not c:
                db.add(models.Categoria_Activo(id_categoria=cat_id, nombre_categoria=cat_nom))

        for est_id, est_nom in [(1, "Disponible"), (2, "Reservado"), (3, "Vendido"), (5, "En Desarme")]:
            e = db.query(models.Estado_Activo).filter_by(id_estado=est_id).first()
            if not e:
                db.add(models.Estado_Activo(id_estado=est_id, nombre_estado=est_nom))
        db.commit()

        # 4. Usuario
        usuario = db.query(models.Usuario).filter(models.Usuario.rut_usuario == "11.111.111-1").first()
        if not usuario:
            usuario = models.Usuario(
                id_usuario=uuid.uuid4(),
                rut_usuario="11.111.111-1",
                nombres="Test",
                apellidos="Bodeguero",
                email="bodeguero@cresal.cl",
                password_hash="fakehash",
                pin_acceso="1234",
                id_rol=1,
                id_sucursal=1,
                estado="Activo",
            )
            db.add(usuario)
            db.commit()
            db.refresh(usuario)

        token = create_access_token(data={"sub": str(usuario.id_usuario), "id_rol": usuario.id_rol, "id_sucursal": usuario.id_sucursal})
        return {"Authorization": f"Bearer {token}"}
    finally:
        db.close()


def test_obtener_vehiculo_existente(client, auth_headers):
    """
    Verifica que al consultar una patente existente en BD, el sistema
    responda con HTTP 200 y los datos correctos.
    """
    db = TestingSessionLocal()
    patente_prueba = "BBCL12"
    try:
        vehiculo = db.query(models.Vehiculo_Origen).filter(models.Vehiculo_Origen.patente == patente_prueba).first()
        if not vehiculo:
            vehiculo = models.Vehiculo_Origen(
                numero_ingreso="ING-2026-TEST",
                patente=patente_prueba,
                marca="Toyota",
                modelo="Yaris",
                anio=2015,
                estado="Activo",
            )
            db.add(vehiculo)
            db.commit()
    finally:
        db.close()

    response = client.get(f"/api/v1/vehiculos/{patente_prueba}", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["patente"] == patente_prueba
    assert data["marca"] == "Toyota"
    assert data["modelo"] == "Yaris"
    assert data["anio"] == 2015


def test_obtener_vehiculo_no_existente_retorna_404(client, auth_headers):
    """
    Verifica que al consultar una patente no registrada, retorne 404 para que la PDA
    haga scraping nativo.
    """
    response = client.get("/api/v1/vehiculos/ZZZZ99", headers=auth_headers)
    assert response.status_code == 404


def test_registro_ingreso_vehiculo_manual_fallback(client, auth_headers):
    """
    Verifica el flujo de contingencia manual (POST /api/v1/vehiculos/registro-manual)
    cuando Google Cloud Vision u OCR falla.
    """
    patente_test = f"FB{uuid.uuid4().hex[:4].upper()}"
    payload = {
        "correlativo_ingreso": "9999",
        "patente": patente_test,
        "marca": "Chevrolet",
        "modelo": "Sail",
        "anio": 2017,
        "traccion": "Delantera",
        "transmision": "Manual",
        "combustible": "Bencina",
        "numero_motor": "CHEV-9999",
        "cilindrada": "1.5L",
    }

    res = client.post("/api/v1/vehiculos/registro-manual", json=payload, headers=auth_headers)
    assert res.status_code == 201, res.text
    data = res.json()
    assert data["patente"] == patente_test
    assert data["marca"] == "Chevrolet"
    assert data["numero_ingreso"] == "9999"


def test_obtener_pendientes_paletizado_flexibilizado(client, auth_headers):
    """
    Verifica que GET /api/v1/vehiculos/pendientes-paletizado retorne activos
    de la sucursal activa con id_estado == 5 o ubicacion_pasillo nula / 'S/P'.
    """
    db = TestingSessionLocal()
    try:
        veh = models.Vehiculo_Origen(
            id_vehiculo=uuid.uuid4(),
            numero_ingreso=f"ING-PEND-{uuid.uuid4().hex[:4].upper()}",
            patente=f"PD{uuid.uuid4().hex[:4].upper()}",
            marca="Hyundai",
            modelo="Tucson",
            anio=2019,
        )
        db.add(veh)
        db.flush()

        act_desarme = models.Activo_Inventariado(
            id_activo=uuid.uuid4(),
            sku_qr_fisico=f"MOT-PD1-{uuid.uuid4().hex[:4].upper()}",
            id_categoria=1,
            id_estado=5,  # En Desarme
            id_sucursal_actual=1,
            id_vehiculo=veh.id_vehiculo,
            estado="Activo",
            ubicacion_pasillo=None,
            ubicacion_pallet=None,
            fecha_creacion=datetime.now(),
        )

        act_sp = models.Activo_Inventariado(
            id_activo=uuid.uuid4(),
            sku_qr_fisico=f"CAJ-PD2-{uuid.uuid4().hex[:4].upper()}",
            id_categoria=2,
            id_estado=1,  # Estado 1 pero sin ubicación ("S/P")
            id_sucursal_actual=1,
            id_vehiculo=veh.id_vehiculo,
            estado="Activo",
            ubicacion_pasillo="S/P",
            ubicacion_pallet="S/P",
            fecha_creacion=datetime.now(),
        )

        db.add_all([act_desarme, act_sp])
        db.commit()

        # Consultar endpoint en vehiculos
        res_veh = client.get("/api/v1/vehiculos/pendientes-paletizado?sucursal_id=1", headers=auth_headers)
        assert res_veh.status_code == 200
        items_veh = res_veh.json()
        ids_veh = [item["id_activo"] for item in items_veh]
        assert str(act_desarme.id_activo) in ids_veh
        assert str(act_sp.id_activo) in ids_veh

        # Consultar endpoint en bodega
        res_bod = client.get("/api/v1/bodega/pendientes-paletizado?sucursal_id=1", headers=auth_headers)
        assert res_bod.status_code == 200
        items_bod = res_bod.json()
        ids_bod = [item["id_activo"] for item in items_bod]
        assert str(act_desarme.id_activo) in ids_bod
        assert str(act_sp.id_activo) in ids_bod
    finally:
        db.close()


