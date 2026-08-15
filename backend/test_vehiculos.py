import uuid
from unittest.mock import patch, MagicMock
from schemas import VehiculoResponse
from core.security import create_access_token
from models import Usuario, Rol, Sucursal, Region, Comuna
from conftest import TestingSessionLocal


@patch('routers.vehiculos.procesar_patente_y_guardar')
def test_obtener_vehiculo_camino_feliz(mock_procesar, client, setup_database):
    """
    Caso de prueba 'Camino Feliz' (Happy Path) para la obtención de un vehículo.
    Verifica que al consultar una patente existente, el sistema responda con un HTTP 200
    y los datos correctos del vehículo.
    """
    # 1. Crear usuario de prueba para autenticación
    db = TestingSessionLocal()
    u_id = uuid.uuid4()
    v_id = uuid.uuid4()
    try:
        r = db.query(Region).filter_by(id_region=1).first()
        if not r:
            r = Region(id_region=1, nombre_region="Valparaíso")
            db.add(r)
        c = db.query(Comuna).filter_by(id_comuna=1).first()
        if not c:
            c = Comuna(id_comuna=1, nombre_comuna="Viña del Mar", id_region=1)
            db.add(c)
        suc = db.query(Sucursal).filter_by(id_sucursal=1).first()
        if not suc:
            suc = Sucursal(id_sucursal=1, nombre_sucursal="Casa Matriz", direccion="Dir", id_comuna=1)
            db.add(suc)
        rol = db.query(Rol).filter_by(id_rol=1).first()
        if not rol:
            rol = Rol(id_rol=1, nombre_rol="Bodeguero")
            db.add(rol)

        user = Usuario(
            id_usuario=u_id,
            id_rol=1,
            id_sucursal=1,
            rut_usuario="11.222.333-4",
            nombres="Tester",
            apellidos="Vehiculo",
            email="tester_veh@cresal.cl",
            password_hash="hash",
            pin_acceso="1234",
            estado="Activo"
        )
        db.add(user)
        db.commit()
    finally:
        db.close()

    token = create_access_token(data={"sub": str(u_id)})
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Configurar mock del servicio
    patente_prueba = "BBCL12"
    mock_vehiculo = MagicMock()
    mock_vehiculo.id_vehiculo = v_id
    mock_vehiculo.patente = patente_prueba
    mock_vehiculo.marca = "Toyota"
    mock_vehiculo.modelo = "Yaris"
    mock_vehiculo.anio = 2015
    mock_vehiculo.traccion = "4x2"
    mock_vehiculo.numero_ingreso = "ING-001"
    mock_vehiculo.estado = "Activo"
    mock_vehiculo.fecha_ingreso = None
    mock_procesar.return_value = mock_vehiculo

    # 3. Act
    url = f"/api/v1/vehiculos/{patente_prueba}"
    response = client.get(url, headers=headers)

    # 4. Assert
    assert response.status_code == 200, f"Error: {response.text}"
    data = response.json()
    assert data["patente"] == patente_prueba
    assert data["marca"] == "Toyota"
    assert data["modelo"] == "Yaris"
    assert data["anio"] == 2015
    assert "id_vehiculo" in data
    mock_procesar.assert_called_once()
