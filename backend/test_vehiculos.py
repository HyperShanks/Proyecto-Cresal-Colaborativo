# Importamos patch de unittest.mock para aislar dependencias externas y evitar salidas a internet
from unittest.mock import patch

# Importamos el esquema para asegurar que la respuesta cumpla con el contrato de la API
from schemas import VehiculoResponse

# Parcheamos la función de scraping exactamente en la ruta donde es importada y utilizada
# dentro del código (en este caso, en el módulo vehiculo_service).
# Al usar @patch, la función decorada recibe el objeto "mock" como primer argumento.
@patch('services.vehiculo_service.obtener_datos_vehiculo')
def test_obtener_vehiculo_camino_feliz(mock_obtener_datos, client):
    """
    Caso de prueba 'Camino Feliz' (Happy Path) para la obtención de un vehículo.
    Verifica que al consultar una patente, el sistema responda con un HTTP 200
    y los datos correctos, interceptando el scraper con datos simulados.
    """
    # 1. Arrange (Preparación)
    patente_prueba = "BBCL12"
    url = f"/api/v1/vehiculos/{patente_prueba}"
    
    # Configuramos el mock para que devuelva un diccionario estático
    # simulando una respuesta exitosa y rápida del scraper
    mock_obtener_datos.return_value = {
        "patente": patente_prueba,
        "marca": "Toyota",
        "modelo": "Yaris",
        "anio": 2015
    }
    
    # 2. Act (Acción)
    # Realizamos la petición con nuestro TestClient. La lógica interna de la API 
    # llamará a la función mockeada en vez de hacer scraping real.
    response = client.get(url)
    
    # 3. Assert (Verificación)
    # Validamos que la petición fue exitosa
    assert response.status_code == 200, f"Se esperaba un status 200, pero se obtuvo {response.status_code}"
    
    # Extraemos el payload JSON de la respuesta
    data = response.json()
    
    # Validamos la estructura del JSON contra nuestro contrato (esquema Pydantic).
    # Si la estructura no es válida, levantará un ValidationError.
    vehiculo_validado = VehiculoResponse(**data)
    
    # Validamos que los datos devueltos por el endpoint coinciden con los que inyectamos en el mock
    assert vehiculo_validado.patente == patente_prueba
    assert vehiculo_validado.marca == "Toyota"
    assert vehiculo_validado.modelo == "Yaris"
    assert vehiculo_validado.anio == 2015
    
    # Verificamos que 'id_vehiculo' exista en la respuesta (generado por la BD en memoria)
    assert "id_vehiculo" in data
    
    # Buena práctica QA: Confirmamos que el sistema realmente invocó a la función mockeada,
    # y que lo hizo usando la patente correcta que enviamos por la URL.
    mock_obtener_datos.assert_called_once_with(patente_prueba)
