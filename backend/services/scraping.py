import requests
import time
import hmac
import hashlib
import json
import re
import urllib3
from bs4 import BeautifulSoup

# Deshabilitar advertencias de SSL no verificado en consola
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

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
    Realiza el scraping a patentechile.com generando los tokens nativamente.
    """
    patente_limpia = re.sub(r'[^A-Za-z0-9]', '', patente).upper()
    
    datos_vehiculo = {
        "patente": patente_limpia,
        "marca": "No encontrado",
        "modelo": "No encontrado",
        "cilindrada": "No encontrado",
        "anio": "No encontrado",
        "nro_motor": "No encontrado"
    }

    try:
        print(f"\n🚀 [SCRAPER 2.0] Iniciando consulta para la patente: {patente_limpia}")
        
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "application/json, text/plain, */*",
            "Accept-Language": "es-ES,es;q=0.9"
        }
        sesion = requests.Session()

        # Step 1: Obtener cookies
        print("🌐 [PASO 1] Conectando a patentechile.com para obtener cookies...")
        start_time = time.time()
        req_home = sesion.get("https://www.patentechile.com/", headers=headers, verify=False, timeout=8)
        print(f"   ↳ Respuesta recibida en {round(time.time() - start_time, 2)}s con Status: {req_home.status_code}")

        if req_home.status_code == 200:
            headers["Origin"] = "https://www.patentechile.com"
            headers["Referer"] = "https://www.patentechile.com/"
            headers["Content-Type"] = "application/json"
            
            # Step 2: Generar payload y solicitar JWT
            timestamp = str(int(time.time()))
            valor = f"vehiculo|{patente_limpia}|{timestamp}"
            valorcifrado = cifrarData(valor)
            
            payload = {
                "opt": "vehiculo",
                "valor": patente_limpia,
                "x": valor,
                "z": valorcifrado
            }

            print("🔑 [PASO 2] Solicitando token de acceso (POST /v3/token)...")
            start_time = time.time()
            req_token = sesion.post(
                "https://www.patentechile.com/v3/token", 
                data=json.dumps(payload), 
                headers=headers, 
                verify=False, 
                timeout=8
            )
            print(f"   ↳ Respuesta token recibida en {round(time.time() - start_time, 2)}s con Status: {req_token.status_code}")

            if req_token.status_code == 200:
                rpta = req_token.json()
                print(f"   ↳ JSON del Token: {rpta}")
                
                if rpta.get("status") and "jwt" in rpta:
                    token = rpta["jwt"]
                    headers["Content-Type"] = "application/x-www-form-urlencoded"
                    payload_token = f"q={token}"
                    
                    # Step 3: Obtener HTML de resultados
                    print("📄 [PASO 3] Solicitando HTML final (/resultados/)...")
                    start_time = time.time()
                    req_data = sesion.post(
                        "https://www.patentechile.com/resultados/", 
                        data=payload_token, 
                        headers=headers, 
                        verify=False, 
                        timeout=8
                    )
                    print(f"   ↳ HTML recibido en {round(time.time() - start_time, 2)}s con Status: {req_data.status_code}")

                    if req_data.status_code == 200:
                        soup = BeautifulSoup(req_data.text, 'html.parser')
                        filas = soup.find_all('tr')
                        print(f"📊 [PASO 4] Parseando {len(filas)} filas en la tabla...")
                        
                        for fila in filas:
                            celdas = fila.find_all(['th', 'td'])
                            if len(celdas) >= 2:
                                etiqueta = celdas[0].text.strip().lower()
                                valor_celda = celdas[1].text.strip()
                                
                                if 'marca' in etiqueta:
                                    datos_vehiculo['marca'] = valor_celda
                                elif 'modelo' in etiqueta:
                                    datos_vehiculo['modelo'] = valor_celda
                                    match_cilindrada = re.search(r'(\d\.\d)', valor_celda)
                                    if match_cilindrada:
                                        datos_vehiculo['cilindrada'] = match_cilindrada.group(1)
                                elif 'año' in etiqueta or 'ano' in etiqueta:
                                    datos_vehiculo['anio'] = valor_celda
                                elif 'motor' in etiqueta:
                                    datos_vehiculo['nro_motor'] = valor_celda
                        
                        print(f"✅ Extracción terminada: Marca={datos_vehiculo['marca']}, Modelo={datos_vehiculo['modelo']}")
                    else:
                        print("❌ Falló la consulta a /resultados/")
                else:
                    print("❌ El token devuelto por el servidor no fue válido o status es False.")
            else:
                print(f"❌ Error HTTP en solicitud de token: {req_token.status_code}")
        else:
            print(f"❌ Error conectando a la página principal: {req_home.status_code}")

    except requests.exceptions.Timeout:
        print("⏱️ [ERROR DE TIMEOUT] La página patentechile.com no respondió a tiempo (Timeout 8s).")
        return {"error": "El servicio de patentes no respondió a tiempo. Intenta nuevamente."}
    except Exception as e:
        print(f"🚨 [ERROR INESPERADO]: {str(e)}")
        return {"error": f"Error en scraping: {str(e)}"}

    return datos_vehiculo