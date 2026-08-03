import requests
from bs4 import BeautifulSoup
import re
import traceback
import time

# Llave de ScraperAPI obtenida del dashboard
API_KEY = "13ec1970f5b4a842d75057d4a8136915" 

def obtener_datos_vehiculo(patente: str) -> dict:
    """
    Realiza scraping a través de un proxy residencial para evadir el Error 403.
    """
    patente_limpia = re.sub(r'[^A-Za-z0-9]', '', patente).upper()
    
    # URL base del servicio de Proxy
    proxy_url = "http://api.scraperapi.com/"
    target_post_url = "https://www.volanteomaleta.com/patente"
    
    payload = {'term': patente_limpia} 

    try:
        print(f"🔄 [PROXY] Iniciando conexión enrutada para la patente: {patente_limpia}")
        
        # Parámetros que le dicen al proxy a dónde ir
        params = {
            'api_key': API_KEY,
            'url': target_post_url,
            'keep_headers': 'true' # Ayuda a simular peticiones reales
        }
        
        # Subimos el timeout a 20s porque viajar por un proxy toma un par de segundos extra
        print("🌐 [PROXY] Ejecutando petición POST a través de ScraperAPI...")
        response = requests.post(proxy_url, params=params, data=payload, timeout=20)
        print(f"✅ [PROXY] Respuesta POST recibida. Status code: {response.status_code}")
        
        # Plan B por si falla el método POST
        if response.status_code != 200:
             print("⚠️ [PROXY] POST falló. Intentando petición GET alternativa...")
             target_get_url = f"https://www.volanteomaleta.com/vehiculo/{patente_limpia}"
             params['url'] = target_get_url
             response = requests.get(proxy_url, params=params, timeout=20)
             print(f"✅ [PROXY] Respuesta GET recibida. Status code: {response.status_code}")
             
        response.raise_for_status()
        
        print("📄 [PROXY] Conexión exitosa. Parseando el HTML con BeautifulSoup...")
        soup = BeautifulSoup(response.text, 'html.parser')
        
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
            print("📊 [PROXY] Tabla de datos encontrada. Extrayendo información...")
            filas = tabla_datos.find_all('tr')
            
            if len(filas) >= 2:
                titulos = [celda.text.strip().lower() for celda in filas[0].find_all(['th', 'td'])]
                datos = [celda.text.strip() for celda in filas[1].find_all('td')]

                for i, etiqueta in enumerate(titulos):
                    if i < len(datos):
                        valor_limpio = " ".join(datos[i].split())

                        if 'marca' in etiqueta:
                            datos_vehiculo['marca'] = valor_limpio
                        elif 'modelo' in etiqueta:
                            datos_vehiculo['modelo'] = valor_limpio
                            match_cilindrada = re.search(r'(\d\.\d)', valor_limpio)
                            if match_cilindrada:
                                datos_vehiculo['cilindrada'] = match_cilindrada.group(1)
                        elif 'año' in etiqueta or 'ano' in etiqueta:
                            datos_vehiculo['anio'] = valor_limpio
                        elif 'motor' in etiqueta:
                            datos_vehiculo['nro_motor'] = valor_limpio
            
            print(f"🎯 [PROXY] Extracción finalizada. Datos: Marca={datos_vehiculo['marca']}, Modelo={datos_vehiculo['modelo']}")
        else:
            print("❌ [PROXY] ATENCIÓN: No se encontró la etiqueta <table> en el HTML.")

        return datos_vehiculo

    except Exception as e:
         print("\n🚨🚨🚨 ERROR CRÍTICO EN SCRAPING 🚨🚨🚨")
         print(f"Tipo de error: {type(e).__name__}")
         print(f"Mensaje: {str(e)}")
         print("Traza de ejecución:")
         print(traceback.format_exc())
         print("🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨\n")
         
         return {"error": f"Error procesando el scraping: {str(e)}"}