import requests
from bs4 import BeautifulSoup
import re
import time  # <--- NUEVA LIBRERÍA IMPORTADA

def obtener_datos_vehiculo(patente: str) -> dict:
    """
    Realiza scraping a una web pública chilena para obtener los datos de un vehículo.
    Limpia los datos, extrae la cilindrada mediante Regex, captura el número de motor
    y cuenta con manejo de errores, timeout de 5 segundos y pausa ética.
    """
    # Limpieza estricta de la patente de entrada (elimina guiones y espacios)
    patente_limpia = re.sub(r'[^A-Za-z0-9]', '', patente).upper()
    
    url = "https://www.volanteomaleta.com/patente"
    
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Referer': 'https://www.volanteomaleta.com/'
    }

    payload = {'term': patente_limpia} 

    try:
        # Pausa ética de 1 segundo para no saturar el servidor destino
        time.sleep(1)
        
        # Petición principal POST con timeout estricto de 5 segundos
        response = requests.post(url, headers=headers, data=payload, timeout=5)
        
        # Plan B por si falla el método POST en algún momento
        if response.status_code != 200:
             url_get = f"https://www.volanteomaleta.com/vehiculo/{patente_limpia}"
             response = requests.get(url_get, headers=headers, timeout=5)
             
        response.raise_for_status()
        
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Diccionario optimizado para el flujo del negocio (sin campo color)
        datos_vehiculo = {
            "patente": patente_limpia,
            "marca": "No encontrado",
            "modelo": "No encontrado",
            "cilindrada": "No encontrado",
            "anio": "No encontrado",
            "nro_motor": "No encontrado"
        }

        tabla_datos = soup.find('table')

        if tabla_datos:
            filas = tabla_datos.find_all('tr')
            
            if len(filas) >= 2:
                titulos = [celda.text.strip().lower() for celda in filas[0].find_all(['th', 'td'])]
                datos = [celda.text.strip() for celda in filas[1].find_all('td')]

                for i, etiqueta in enumerate(titulos):
                    if i < len(datos):
                        # Limpieza de espacios en blanco múltiples o saltos de línea
                        valor_limpio = " ".join(datos[i].split())

                        if 'marca' in etiqueta:
                            datos_vehiculo['marca'] = valor_limpio
                        elif 'modelo' in etiqueta:
                            datos_vehiculo['modelo'] = valor_limpio
                            
                            # Aislamiento de cilindrada mediante Expresión Regular (ej: 1.6, 2.0, 4.0)
                            match_cilindrada = re.search(r'(\d\.\d)', valor_limpio)
                            if match_cilindrada:
                                datos_vehiculo['cilindrada'] = match_cilindrada.group(1)
                                
                        elif 'año' in etiqueta or 'ano' in etiqueta:
                            datos_vehiculo['anio'] = valor_limpio
                        elif 'motor' in etiqueta:
                            datos_vehiculo['nro_motor'] = valor_limpio

        return datos_vehiculo

    except requests.exceptions.Timeout:
        return {"error": "Timeout: La fuente externa tardó más de 5 segundos en responder."}
    except requests.exceptions.RequestException:
        return {"error": f"Error de conexión: HTTP {response.status_code if 'response' in locals() else 'Desconocido'}"}
    except Exception as e:
         return {"error": f"Error inesperado procesando el HTML: {str(e)}"}

# Bloque de ejecución local para pruebas rápidas de desarrollo
if __name__ == "__main__":
    print("Probando motor de scraping final de producción...")
    resultado = obtener_datos_vehiculo("BBCL12")
    print(resultado)