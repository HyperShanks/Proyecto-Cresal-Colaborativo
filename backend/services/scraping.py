import cloudscraper # <--- NUEVA LIBRERÍA DE CAMUFLAJE
from bs4 import BeautifulSoup
import re
import time 

def obtener_datos_vehiculo(patente: str) -> dict:
    """
    Realiza scraping a una web pública chilena evadiendo bloqueos de Cloudflare.
    Limpia los datos, extrae la cilindrada mediante Regex, captura el número de motor
    y cuenta con manejo de errores, timeout de 10 segundos y pausa ética.
    """
    patente_limpia = re.sub(r'[^A-Za-z0-9]', '', patente).upper()
    url = "https://www.volanteomaleta.com/patente"
    
    # INICIALIZAR EL NAVEGADOR CAMUFLADO
    scraper = cloudscraper.create_scraper() 
    
    payload = {'term': patente_limpia} 

    try:
        print(f"🔄 [SCRAPER] Iniciando conexión para la patente: {patente_limpia}")
        
        # Pausa ética
        time.sleep(1)
        
        # Petición principal POST
        print(f"🌐 [SCRAPER] Ejecutando petición POST a {url} ...")
        response = scraper.post(url, data=payload, timeout=10)
        print(f"✅ [SCRAPER] Respuesta POST recibida. Status code: {response.status_code}")
        
        # Plan B por si falla el método POST
        if response.status_code != 200:
             print("⚠️ [SCRAPER] POST falló. Intentando petición GET alternativa...")
             url_get = f"https://www.volanteomaleta.com/vehiculo/{patente_limpia}"
             response = scraper.get(url_get, timeout=10)
             print(f"✅ [SCRAPER] Respuesta GET recibida. Status code: {response.status_code}")
             
        response.raise_for_status()
        
        print("📄 [SCRAPER] Conexión exitosa. Parseando el HTML con BeautifulSoup...")
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
            print("📊 [SCRAPER] Tabla de datos encontrada. Extrayendo información...")
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
            
            print(f"🎯 [SCRAPER] Extracción finalizada. Datos preliminares: Marca={datos_vehiculo['marca']}, Modelo={datos_vehiculo['modelo']}")
        else:
            print("❌ [SCRAPER] ATENCIÓN: No se encontró la etiqueta <table> en el HTML.")
            print("🔍 [SCRAPER] Imprimiendo los primeros 500 caracteres de la página devuelta para diagnóstico:")
            print(response.text[:500])

        return datos_vehiculo

    except Exception as e:
         # Esto imprimirá la línea exacta y el motivo real del fallo en Render
         import traceback
         print("\n🚨🚨🚨 ERROR CRÍTICO EN SCRAPING 🚨🚨🚨")
         print(f"Tipo de error: {type(e).__name__}")
         print(f"Mensaje: {str(e)}")
         print("Traza de ejecución:")
         print(traceback.format_exc())
         print("🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨\n")
         
         return {"error": f"Error procesando el scraping: {str(e)}"}