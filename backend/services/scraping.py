import requests
import time
import hmac
import hashlib
import json
import re
from bs4 import BeautifulSoup

def cifrarData(mensaje):
    """
    Replica el cifrado HMAC-SHA256 utilizando la clave secreta descubierta
    en el código de la web para generar el token válido[cite: 1, 2].
    """
    secret = "b708574124a2742b5eecab4993a7f3e91528b8a99d38e1a663b2fcbe92e38a8c"
    hmac_result = hmac.new(
        secret.encode("utf-8"), 
        mensaje.encode("utf-8"),
        hashlib.sha256
    ).hexdigest()
    return hmac_result

def obtener_datos_vehiculo(patente: str) -> dict:
    """
    Realiza el scraping a patentechile.com generando los tokens nativamente,
    sin necesidad de proxies externos ni herramientas de pago.
    """
    patente_limpia = re.sub(r'[^A-Za-z0-9]', '', patente).upper()
    
    # Estructura exacta que espera tu FastAPI
    datos_vehiculo = {
        "patente": patente_limpia,
        "marca": "No encontrado",
        "modelo": "No encontrado",
        "cilindrada": "No encontrado",
        "anio": "No encontrado",
        "nro_motor": "No encontrado"
    }

    try:
        print(f"🔄 [NUEVO SCRAPER] Iniciando búsqueda para: {patente_limpia}")
        
        header = {
            "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36"
        }
        sesion = requests.session()

        # 1. Visitar la portada para obtener y almacenar las cookies de sesión iniciales[cite: 1]
        req = sesion.get("https://www.patentechile.com/", headers=header, verify=False, timeout=15)

        if req.status_code == 200:
            header["origin"] = "https://www.patentechile.com"
            header["referer"] = "https://www.patentechile.com/"
            header["content-type"] = "application/json"
            
            # 2. Construir los parámetros (placa, fecha/hora y valor cifrado) para el JWT[cite: 1, 2]
            timestamp = str(int(time.time()))
            valor = f"vehiculo|{patente_limpia}|{timestamp}"
            valorcifrado = cifrarData(valor)
            
            payload = {
                "opt": "vehiculo",
                "valor": patente_limpia,
                "x": valor,
                "z": valorcifrado
            }

            print("🔑 [NUEVO SCRAPER] Solicitando token de acceso...")
            req = sesion.post("https://www.patentechile.com/v3/token", data=json.dumps(payload), headers=header, verify=False, timeout=15)

            if req.status_code == 200:
                rpta = req.json()
                
                if "status" in rpta and rpta["status"]:
                    token = rpta["jwt"]
                    header["content-type"] = "application/x-www-form-urlencoded"
                    payload_token = f"q={token}"
                    
                    print("📄 [NUEVO SCRAPER] Token obtenido. Solicitando HTML de resultados[cite: 1]...")
                    req_data = sesion.post("https://www.patentechile.com/resultados/", data=payload_token, headers=header, verify=False, timeout=15)

                    if req_data.status_code == 200:
                        # 3. Parsear el HTML con BeautifulSoup para extraer los datos de la tabla
                        soup = BeautifulSoup(req_data.text, 'html.parser')
                        filas = soup.find_all('tr')
                        
                        for fila in filas:
                            celdas = fila.find_all(['th', 'td'])
                            # Verificamos que la fila tenga al menos 2 columnas (Etiqueta y Valor)
                            if len(celdas) >= 2:
                                etiqueta = celdas[0].text.strip().lower()
                                valor_celda = celdas[1].text.strip()
                                
                                # Mapeo de datos basado en las etiquetas de la imagen
                                if 'marca' == etiqueta:
                                    datos_vehiculo['marca'] = valor_celda
                                elif 'modelo' == etiqueta:
                                    datos_vehiculo['modelo'] = valor_celda
                                    # Extraemos la cilindrada (ej: 1.6) del modelo si existe
                                    match_cilindrada = re.search(r'(\d\.\d)', valor_celda)
                                    if match_cilindrada:
                                        datos_vehiculo['cilindrada'] = match_cilindrada.group(1)
                                elif 'año' == etiqueta:
                                    datos_vehiculo['anio'] = valor_celda
                                elif 'nº motor' in etiqueta or 'motor' in etiqueta:
                                    datos_vehiculo['nro_motor'] = valor_celda
                        
                        print(f"✅ [NUEVO SCRAPER] Éxito: {datos_vehiculo['marca']} {datos_vehiculo['modelo']}")
                    else:
                        print("⚠️ [NUEVO SCRAPER] Falló la obtención de la tabla de resultados.")

    except Exception as e:
        print(f"🚨 Error interno procesando el scraping: {str(e)}")
        return {"error": f"Error procesando el scraping: {str(e)}"}

    return datos_vehiculo