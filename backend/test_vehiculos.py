import uuid
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

        # 3. Usuario
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
