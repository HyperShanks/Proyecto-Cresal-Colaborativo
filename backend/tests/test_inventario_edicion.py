# test_inventario_edicion.py
# Suite de pruebas automatizadas para HU-11: Edición Directa de Activos Inventariados en Bodega PDA.

import uuid
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
    Detalle_Motor,
)
from core.security import create_access_token
from conftest import TestingSessionLocal


@pytest.fixture(scope="module")
def db_session(setup_database):
    db = TestingSessionLocal()
    try:
        # Seed Geografía y Sucursal
        r = Region(id_region=1, nombre_region="Valparaíso")
        db.add(r)
        c = Comuna(id_comuna=1, nombre_comuna="Viña del Mar", id_region=1)
        db.add(c)

        suc = Sucursal(
            id_sucursal=1,
            nombre_sucursal="Casa Matriz - Viña",
            direccion="Av Libertad 123",
            id_comuna=1,
        )
        db.add(suc)

        # Seed Roles: Bodeguero (1), Vendedor (2), Administrador (5)
        rol_bodega = Rol(id_rol=1, nombre_rol="Bodeguero")
        rol_vendedor = Rol(id_rol=2, nombre_rol="Vendedor")
        rol_admin = Rol(id_rol=5, nombre_rol="Administrador")
        db.add_all([rol_bodega, rol_vendedor, rol_admin])

        # Usuarios
        u_bodega_id = uuid.uuid4()
        u_vendedor_id = uuid.uuid4()
        u_admin_id = uuid.uuid4()

        user_bodega = Usuario(
            id_usuario=u_bodega_id,
            id_rol=1,
            id_sucursal=1,
            rut_usuario="11.111.111-1",
            nombres="Juan",
            apellidos="Bodega",
            email="juan.bodega@cresal.cl",
            password_hash="hash1",
            pin_acceso="1111",
            estado="Activo",
        )
        user_vendedor = Usuario(
            id_usuario=u_vendedor_id,
            id_rol=2,
            id_sucursal=1,
            rut_usuario="22.222.222-2",
            nombres="Pedro",
            apellidos="Ventas",
            email="pedro.ventas@cresal.cl",
            password_hash="hash2",
            pin_acceso="2222",
            estado="Activo",
        )
        user_admin = Usuario(
            id_usuario=u_admin_id,
            id_rol=5,
            id_sucursal=1,
            rut_usuario="55.555.555-5",
            nombres="Admin",
            apellidos="General",
            email="admin@cresal.cl",
            password_hash="hash5",
            pin_acceso="5555",
            estado="Activo",
        )
        db.add_all([user_bodega, user_vendedor, user_admin])

        # Categorías
        cat_motor = Categoria_Activo(id_categoria=1, nombre_categoria="Motor")
        cat_caja = Categoria_Activo(id_categoria=2, nombre_categoria="Caja de Cambio")
        db.add_all([cat_motor, cat_caja])

        # Estados de Activo
        est_disp = Estado_Activo(id_estado=1, nombre_estado="Disponible")
        est_res = Estado_Activo(id_estado=2, nombre_estado="Reservado")
        est_vend = Estado_Activo(id_estado=3, nombre_estado="Vendido")
        est_entr = Estado_Activo(id_estado=6, nombre_estado="Entregado")
        est_palet = Estado_Activo(id_estado=7, nombre_estado="Paletizado")
        db.add_all([est_disp, est_res, est_vend, est_entr, est_palet])

        # Vehículo de origen
        vehiculo = Vehiculo_Origen(
            id_vehiculo=uuid.uuid4(),
            numero_ingreso="ING-2026-001",
            patente="ABCD12",
            marca="Toyota",
            modelo="Corolla",
            anio=2021,
            traccion="FWD",
            estado="Activo",
        )
        db.add(vehiculo)

        # Activo 1: Disponible, editable (versión lock 1)
        activo_1 = Activo_Inventariado(
            id_activo=uuid.uuid4(),
            sku_qr_fisico="MOT-TOY-COR-001",
            id_categoria=1,
            id_estado=1,  # Disponible
            id_sucursal_actual=1,
            id_vehiculo=vehiculo.id_vehiculo,
            ubicacion_pasillo="P-01",
            ubicacion_galpon="G-A",
            ubicacion_pallet="PL-10",
            observacion_estado="Buen estado inicial",
            precio_referencia=500000,
            version_lock=1,
            estado="Activo",
        )
        db.add(activo_1)

        motor_1 = Detalle_Motor(
            id_activo=activo_1.id_activo,
            numero_motor="1NZ-FE-123456",
            cilindrada="1.5L",
            combustible="Gasolina",
            transmision_tipo="Manual",
        )
        db.add(motor_1)

        # Activo 2: Vendido (id_estado = 3)
        activo_vendido = Activo_Inventariado(
            id_activo=uuid.uuid4(),
            sku_qr_fisico="MOT-TOY-COR-002",
            id_categoria=1,
            id_estado=3,  # Vendido
            id_sucursal_actual=1,
            id_vehiculo=vehiculo.id_vehiculo,
            ubicacion_pasillo="P-02",
            ubicacion_pallet="PL-20",
            version_lock=1,
            estado="Activo",
        )
        db.add(activo_vendido)

        # Activo 3: Entregado (id_estado = 6)
        activo_entregado = Activo_Inventariado(
            id_activo=uuid.uuid4(),
            sku_qr_fisico="MOT-TOY-COR-003",
            id_categoria=1,
            id_estado=6,  # Entregado
            id_sucursal_actual=1,
            id_vehiculo=vehiculo.id_vehiculo,
            ubicacion_pasillo="P-03",
            ubicacion_pallet="PL-30",
            version_lock=1,
            estado="Activo",
        )
        db.add(activo_entregado)

        # Activo 4: Paletizado (id_estado = 7, editable)
        activo_paletizado = Activo_Inventariado(
            id_activo=uuid.uuid4(),
            sku_qr_fisico="MOT-TOY-COR-004",
            id_categoria=1,
            id_estado=7,  # Paletizado
            id_sucursal_actual=1,
            id_vehiculo=vehiculo.id_vehiculo,
            ubicacion_pasillo="P-04",
            ubicacion_pallet="PL-40",
            version_lock=1,
            estado="Activo",
        )
        db.add(activo_paletizado)

        # Activo 5: Reservado (id_estado = 2, no editable)
        activo_reservado = Activo_Inventariado(
            id_activo=uuid.uuid4(),
            sku_qr_fisico="MOT-TOY-COR-005",
            id_categoria=1,
            id_estado=2,  # Reservado
            id_sucursal_actual=1,
            id_vehiculo=vehiculo.id_vehiculo,
            ubicacion_pasillo="P-05",
            ubicacion_pallet="PL-50",
            version_lock=1,
            estado="Activo",
        )
        db.add(activo_reservado)

        db.commit()

        yield {
            "db": db,
            "user_bodega": user_bodega,
            "user_vendedor": user_vendedor,
            "user_admin": user_admin,
            "activo_1": activo_1,
            "activo_vendido": activo_vendido,
            "activo_entregado": activo_entregado,
            "activo_paletizado": activo_paletizado,
            "activo_reservado": activo_reservado,
        }
    finally:
        db.close()


def test_editar_activo_exitoso_bodeguero(client, db_session):
    """
    Camino feliz: Un usuario con rol Bodeguero (id_rol=1) actualiza la ubicación y notas.
    El endpoint debe responder 200 OK y version_lock debe incrementarse a 2.
    """
    user_bodega = db_session["user_bodega"]
    activo_1 = db_session["activo_1"]

    token = create_access_token(data={"sub": str(user_bodega.id_usuario)})
    headers = {"Authorization": f"Bearer {token}"}

    payload = {
        "ubicacion_pasillo": "P-05",
        "ubicacion_galpon": "G-B",
        "ubicacion_pallet": "PL-99",
        "version_lock_esperado": 1,
    }

    response = client.patch(
        f"/api/v1/inventario/{activo_1.id_activo}",
        json=payload,
        headers=headers,
    )

    assert response.status_code == 200
    data = response.json()
    assert data["id_activo"] == str(activo_1.id_activo)
    assert data["ubicacion_pasillo"] == "P-05"
    assert data["ubicacion_galpon"] == "G-B"
    assert data["ubicacion_pallet"] == "PL-99"
    assert data["version_lock"] == 2
    assert "actualizado exitosamente" in data["mensaje"].lower()

    # Verificar persistencia en base de datos
    db = db_session["db"]
    db.refresh(activo_1)
    assert activo_1.ubicacion_pasillo == "P-05"
    assert activo_1.version_lock == 2


def test_editar_activo_actualiza_ubicacion_pallet_y_galpon(client, db_session):
    """
    Edición de ubicación: Admin (id_rol=5) actualiza ubicacion_pallet y ubicacion_galpon.
    """
    user_admin = db_session["user_admin"]
    activo_1 = db_session["activo_1"]

    token = create_access_token(data={"sub": str(user_admin.id_usuario)})
    headers = {"Authorization": f"Bearer {token}"}

    payload = {
        "ubicacion_pallet": "PL-55",
        "ubicacion_galpon": "G-C",
        "version_lock_esperado": 2,  # Ahora es 2 tras la prueba anterior
    }

    response = client.patch(
        f"/api/v1/inventario/{activo_1.id_activo}",
        json=payload,
        headers=headers,
    )

    assert response.status_code == 200
    data = response.json()
    assert data["ubicacion_pallet"] == "PL-55"
    assert data["ubicacion_galpon"] == "G-C"
    assert data["version_lock"] == 3

    # Verificar en BD
    db = db_session["db"]
    db.refresh(activo_1)
    assert activo_1.ubicacion_pallet == "PL-55"
    assert activo_1.ubicacion_galpon == "G-C"


def test_editar_activo_exitoso_en_estado_paletizado(client, db_session):
    """
    Regla de Negocio: Activos en estado 'Paletizado' (id_estado=7) pueden editar su ubicación.
    """
    user_bodega = db_session["user_bodega"]
    activo_paletizado = db_session["activo_paletizado"]

    token = create_access_token(data={"sub": str(user_bodega.id_usuario)})
    headers = {"Authorization": f"Bearer {token}"}

    payload = {
        "ubicacion_pasillo": "P-99",
        "ubicacion_pallet": "PL-99",
        "version_lock_esperado": 1,
    }

    response = client.patch(
        f"/api/v1/inventario/{activo_paletizado.id_activo}",
        json=payload,
        headers=headers,
    )

    assert response.status_code == 200
    data = response.json()
    assert data["ubicacion_pasillo"] == "P-99"
    assert data["ubicacion_pallet"] == "PL-99"
    assert data["version_lock"] == 2


def test_editar_activo_rechazo_pieza_reservada_400(client, db_session):
    """
    Regla de Negocio: Activos en estado 'Reservado' (id_estado=2) NO pueden ser editados.
    """
    user_bodega = db_session["user_bodega"]
    activo_reservado = db_session["activo_reservado"]

    token = create_access_token(data={"sub": str(user_bodega.id_usuario)})
    headers = {"Authorization": f"Bearer {token}"}

    payload = {
        "ubicacion_pasillo": "P-99",
        "version_lock_esperado": 1,
    }

    response = client.patch(
        f"/api/v1/inventario/{activo_reservado.id_activo}",
        json=payload,
        headers=headers,
    )

    assert response.status_code == 400
    data = response.json()
    detail = data.get("detail", "")
    assert "Solo es posible modificar la ubicación de repuestos en estado 'Disponible' o 'Paletizado'" in detail


def test_editar_activo_colision_concurrencia_optimista_409(client, db_session):
    """
    Condición de carrera: El cliente envía un version_lock_esperado que ya no coincide
    (por ejemplo, envía 1 o 2 cuando la BD ya está en versión 3).
    Debe responder 409 Conflict con el mensaje estandarizado al usuario.
    """
    user_bodega = db_session["user_bodega"]
    activo_1 = db_session["activo_1"]

    token = create_access_token(data={"sub": str(user_bodega.id_usuario)})
    headers = {"Authorization": f"Bearer {token}"}

    payload = {
        "ubicacion_pasillo": "P-99",
        "version_lock_esperado": 1,  # Desactualizado, la versión actual es 3
    }

    response = client.patch(
        f"/api/v1/inventario/{activo_1.id_activo}",
        json=payload,
        headers=headers,
    )

    assert response.status_code == 409
    data = response.json()
    mensaje_esperado = (
        "La información de este repuesto fue modificada por otro usuario recientemente. "
        "Los datos se actualizarán ahora para que revises los cambios antes de volver a editar."
    )
    detail = data.get("detail", "")
    assert mensaje_esperado in detail


def test_editar_activo_rechazo_pieza_vendida_400(client, db_session):
    """
    Intento de editar un repuesto en estado 'Vendido' (id_estado=3).
    Debe responder 400 Bad Request indicando que solo se permite en Disponible o Paletizado.
    """
    user_bodega = db_session["user_bodega"]
    activo_vendido = db_session["activo_vendido"]

    token = create_access_token(data={"sub": str(user_bodega.id_usuario)})
    headers = {"Authorization": f"Bearer {token}"}

    payload = {
        "ubicacion_pasillo": "P-99",
        "version_lock_esperado": 1,
    }

    response = client.patch(
        f"/api/v1/inventario/{activo_vendido.id_activo}",
        json=payload,
        headers=headers,
    )

    assert response.status_code == 400
    data = response.json()
    detail = data.get("detail", "")
    assert "Solo es posible modificar la ubicación de repuestos en estado 'Disponible' o 'Paletizado'" in detail


def test_editar_activo_rechazo_pieza_entregada_400(client, db_session):
    """
    Intento de editar un repuesto en estado 'Entregado' (id_estado=6).
    Debe responder 400 Bad Request indicando que solo se permite en Disponible o Paletizado.
    """
    user_admin = db_session["user_admin"]
    activo_entregado = db_session["activo_entregado"]

    token = create_access_token(data={"sub": str(user_admin.id_usuario)})
    headers = {"Authorization": f"Bearer {token}"}

    payload = {
        "ubicacion_pallet": "PL-88",
        "version_lock_esperado": 1,
    }

    response = client.patch(
        f"/api/v1/inventario/{activo_entregado.id_activo}",
        json=payload,
        headers=headers,
    )

    assert response.status_code == 400
    data = response.json()
    detail = data.get("detail", "")
    assert "Solo es posible modificar la ubicación de repuestos en estado 'Disponible' o 'Paletizado'" in detail


def test_editar_activo_rechazo_rol_no_autorizado_403(client, db_session):
    """
    Seguridad RBAC: Un usuario con rol Vendedor (id_rol=2) intenta editar un activo.
    Debe ser rechazado con 403 Forbidden.
    """
    user_vendedor = db_session["user_vendedor"]
    activo_1 = db_session["activo_1"]

    token = create_access_token(data={"sub": str(user_vendedor.id_usuario)})
    headers = {"Authorization": f"Bearer {token}"}

    payload = {
        "ubicacion_pasillo": "P-09",
        "version_lock_esperado": 3,
    }

    response = client.patch(
        f"/api/v1/inventario/{activo_1.id_activo}",
        json=payload,
        headers=headers,
    )

    assert response.status_code == 403
    data = response.json()
    detail = data.get("detail", "")
    assert "Acceso restringido" in detail


def test_editar_activo_no_encontrado_retorna_404(client, db_session):
    """
    Activo inexistente: Probar con un UUID inexistente devuelve 404 Not Found.
    """
    user_bodega = db_session["user_bodega"]
    random_uuid = uuid.uuid4()

    token = create_access_token(data={"sub": str(user_bodega.id_usuario)})
    headers = {"Authorization": f"Bearer {token}"}

    payload = {
        "ubicacion_pasillo": "P-01",
        "version_lock_esperado": 1,
    }

    response = client.patch(
        f"/api/v1/inventario/{random_uuid}",
        json=payload,
        headers=headers,
    )

    assert response.status_code == 404
    data = response.json()
    assert "no encontrado" in data.get("detail", "").lower()


def test_campos_inmutables_blindados(client, db_session):
    """
    Blindaje de campos: El esquema y endpoint deben asegurar que sku_qr_fisico,
    id_estado, id_sucursal_actual y precio_referencia permanezcan intactos tras la edición.
    """
    user_bodega = db_session["user_bodega"]
    activo_1 = db_session["activo_1"]

    db = db_session["db"]
    db.refresh(activo_1)

    sku_original = activo_1.sku_qr_fisico
    estado_original = activo_1.id_estado
    sucursal_original = activo_1.id_sucursal_actual
    precio_original = activo_1.precio_referencia
    version_actual = activo_1.version_lock

    token = create_access_token(data={"sub": str(user_bodega.id_usuario)})
    headers = {"Authorization": f"Bearer {token}"}

    # Intentamos pasar campos prohibidos (Pydantic los ignorará ya que no están en EditarActivoRequest)
    payload = {
        "ubicacion_pasillo": "P-100",
        "sku_qr_fisico": "HACKED-SKU",
        "id_estado": 99,
        "precio_referencia": 99999999,
        "version_lock_esperado": version_actual,
    }

    response = client.patch(
        f"/api/v1/inventario/{activo_1.id_activo}",
        json=payload,
        headers=headers,
    )

    assert response.status_code == 200

    db.refresh(activo_1)
    assert activo_1.sku_qr_fisico == sku_original
    assert activo_1.id_estado == estado_original
    assert activo_1.id_sucursal_actual == sucursal_original
    assert activo_1.precio_referencia == precio_original
    assert activo_1.ubicacion_pasillo == "P-100"
