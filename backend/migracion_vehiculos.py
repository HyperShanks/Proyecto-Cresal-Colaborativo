import os
import re
import sys
import uuid
from datetime import datetime
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import text

# Importamos SQLAlchemy Session y los Modelos
from database import SessionLocal
from models import (
    Vehiculo_Origen, Activo_Inventariado, Detalle_Motor, Detalle_Caja_Cambio
)

load_dotenv()

EXCEL_FILE = "MatrizLosPinos.xlsx"

PATENTES_GENERICAS = {
    "SPATENTE", "SINPATENTE", "SINPPU", "SPPU", "ERROR", 
    "MOTOR", "SN", "NAN", "NONE", "S/PATENTE", "S/PPU", 
    "SP", "SPP", ""
}

# ==============================================================================
# FUNCIONES DE EXTRACCIÓN INTELIGENTE (ESTANDARIZADAS CON EL FRONTEND)
# ==============================================================================

def limpiar_patente(valor_raw, patentes_registradas):
    if pd.isna(valor_raw):
        return None

    limpio = re.sub(r'[^A-Z0-9]', '', str(valor_raw).upper().strip())

    if limpio in PATENTES_GENERICAS or any(tag in limpio for tag in ["SPATENTE", "SINPPU", "ERROR"]):
        return None

    if limpio in patentes_registradas:
        conteo = patentes_registradas[limpio]
        patentes_registradas[limpio] += 1
        patente_ajustada = f"{limpio}-D{conteo}"
        return patente_ajustada[:10]
    else:
        patentes_registradas[limpio] = 1
        return limpio[:10]


def procesar_anio(valor_raw):
    try:
        if pd.isna(valor_raw):
            return 2000
        val = int(float(valor_raw))
        return val if 1950 <= val <= 2030 else 2000
    except (ValueError, TypeError):
        return 2000


def extraer_cilindrada(modelo_raw, obs_raw=""):
    """
    Extrae la cilindrada del vehículo analizando el modelo y observaciones
    mediante expresiones regulares.
    Ejemplos: 'SORENTO 2,4' -> '2.4', 'RIO 4 EX 1.4 AUT' -> '1.4', 'GOL 1.6I' -> '1.6', '1600cc' -> '1.6'
    """
    texto = f"{modelo_raw or ''} {obs_raw or ''}".strip()
    if not texto:
        return "S/A"

    # 1. Patrón decimal estándar con punto o coma (ej: 1.4, 2,4, 1.6L, 1.6I, 2.0i, 3.8 AUT)
    m_dec = re.search(r'\b([0-9][.,][0-9])(?:[a-zA-Z\s])?\b', texto)
    if m_dec:
        return m_dec.group(1).replace(',', '.')

    # 2. Formato centímetros cúbicos (ej: 1600cc, 2000 cc, 2400)
    m_cc = re.search(r'\b(1[0-9]{3}|2[0-9]{3}|3[0-9]{3})\s*(?:cc)?\b', texto, re.IGNORECASE)
    if m_cc:
        cc_val = int(m_cc.group(1))
        return str(round(cc_val / 1000, 1))

    return "S/A"


def extraer_transmision(modelo_raw, obs_raw=""):
    """
    Determina si la transmisión es 'Automática' o 'Mecánica'.
    Estandarizado según OpcionesTransmision del frontend.
    """
    texto = f"{modelo_raw or ''} {obs_raw or ''}".upper()
    if re.search(r'\b(AUT|AUTOMATICA|AUTOMATICO|AT|A/T|CVT|TIPTRONIC|DSG)\b', texto):
        return "Automática"
    return "Mecánica"


def extraer_combustible(modelo_raw, obs_raw=""):
    """
    Determina el combustible: 'Gasolina', 'Diésel' o 'Híbrido'.
    Estandarizado según OpcionesCombustible del frontend.
    """
    texto = f"{modelo_raw or ''} {obs_raw or ''}".upper()
    
    # 1. Detección de Híbridos
    if re.search(r'\b(HIBRIDO|HYBRID|PRIUS|HEV|PHEV)\b', texto):
        return "Híbrido"

    # 2. Nomenclaturas técnicas directas de motores Diésel
    if re.search(r'\b(DIESEL|PETROLEO|PETROLERO|HDI|CRDI|TDI|D-4D|TD|TURBO DIESEL|CDI|DCI|TDCI|D4HA|4D56|YD25)\b', texto):
        return "Diésel"
    
    # 3. Camionetas / Utilitarios de trabajo en Chile que son históricamente diésel
    if any(k in texto for k in [
        'DMAX', 'D-MAX', 'HILUX', 'ACTYON', 'L200', 'L-200', 'NAVARA', 
        'NP300', 'AMAROK', 'RANGER', 'BT-50', 'BT50', 'TERRANO', 
        'BOXER', 'DUCATO', 'PORTER', 'CANTER'
    ]):
        return "Diésel"

    # 4. Automóviles de pasajeros convencionales
    return "Gasolina"


def extraer_traccion(marca_raw, modelo_raw, obs_raw=""):
    """
    Determina la tracción estandarizada según OpcionesTraccion del frontend:
    - '4x4 Permanente (AWD)'
    - '4x4 Conectable (4WD)'
    - '4x2 Trasera'
    - '4x2 Delantera'
    - 'Otro...'
    """
    m_up = str(marca_raw or '').upper()
    texto = f"{modelo_raw or ''} {obs_raw or ''}".upper()

    # 1. 4x4 Permanente (AWD) - Toda la gama Subaru tradicional o siglas AWD/4Motion/Quattro/4Matic
    if 'SUBARU' in m_up or re.search(r'\b(AWD|4MOTION|ALL GRIP|QUATTRO|4MATIC|PERMANENTE)\b', texto):
        return "4x4 Permanente (AWD)"

    # 2. 4x4 Conectable (4WD) - Camionetas y todoterrenos con caja reductora/transferencia
    if re.search(r'\b(4X4|4WD|CONECTABLE)\b', texto):
        return "4x4 Conectable (4WD)"

    # 3. 4x2 Trasera - Pickups 4x2, camiones medianos, furgones pesados (H1, Porter, Canter) o BMW/Mercedes sedan
    if any(k in texto for k in [
        'DMAX', 'D-MAX', 'HILUX', 'L200', 'L-200', 'NAVARA', 'NP300', 'AMAROK', 
        'RANGER', 'BT-50', 'TERRANO', 'PORTER', 'H-1', 'H1', 'CANTER', 'NPR', 
        'NKR', 'D100', 'C-10', 'SILVERADO', 'F150', 'F-150'
    ]):
        return "4x2 Trasera"
    if any(k in m_up for k in ['BMW', 'MERCEDES']) and not any(k in texto for k in ['A-CLASS', 'CLASE A', 'B-CLASS', 'CLASE B']):
        return "4x2 Trasera"

    # 4. 4x2 Delantera - Automóviles comunes de tracción delantera (FWD)
    return "4x2 Delantera"


def limpiar_numero_motor(motor_raw, obs_raw=""):
    """
    Sanitiza el número de motor extrayendo datos válidos.
    """
    if pd.notnull(motor_raw):
        s = str(motor_raw).strip()
        if s and s.upper() not in ["NAN", "NONE", "SN", "S/N", "S/A", "SIN NUMERO", "SIN DATO", "0"]:
            return s[:100]

    # Buscar en observaciones si dice "MOTOR: XXX"
    if pd.notnull(obs_raw):
        m = re.search(r'MOTOR\s*[:#]?\s*([A-Z0-9\-]+)', str(obs_raw).upper())
        if m:
            candidato = m.group(1).strip()
            if candidato not in ["SN", "S/N", "S/A"]:
                return candidato[:100]

    return "S/A"


def limpiar_marca(marca_raw):
    """Corrige errores ortográficos y normaliza marcas automotrices comunes."""
    if not marca_raw or pd.isna(marca_raw):
        return "DESCONOCIDA"
    
    m = str(marca_raw).strip().upper()
    correcciones = {
        "VOLSKWAGEN": "VOLKSWAGEN",
        "SSANYONG": "SSANGYONG",
        "SSANG YONG": "SSANGYONG",
        "CHEVROLET ": "CHEVROLET",
        "MERCEDEZ": "MERCEDES-BENZ",
        "MERCEDES BENZ": "MERCEDES-BENZ",
        "GREATWALL": "GREAT WALL",
    }
    return correcciones.get(m, m[:100])


# ==============================================================================
# AUDITORÍA Y SECUENCIACIÓN DE NÚMEROS DE INGRESO
# ==============================================================================

def sanitizar_secuencia_ingresos(df, col_indice):
    total_filas = len(df)
    
    def parse_int_seguro(v):
        if pd.isna(v):
            return None
        s = str(v).strip()
        if not s:
            return None
        try:
            n = int(float(s))
            return n if n > 0 else None
        except (ValueError, TypeError):
            return None

    raw_vals = [df.iloc[i][col_indice] for i in range(total_filas)]
    parsed_vals = [parse_int_seguro(v) for v in raw_vals]

    conteo_numeros = {}
    for v in parsed_vals:
        if v is not None:
            conteo_numeros[v] = conteo_numeros.get(v, 0) + 1

    candidatos = [None] * total_filas
    vistos = set()
    ultimo_valido = 0

    for i in range(total_filas):
        v = parsed_vals[i]
        if v is None:
            candidatos[i] = None
        else:
            if v in vistos:
                candidatos[i] = None
            elif v <= ultimo_valido and conteo_numeros[v] > 1:
                candidatos[i] = None
            elif v <= ultimo_valido:
                candidatos[i] = None
            else:
                candidatos[i] = v
                vistos.add(v)
                ultimo_valido = v

    resolucion = [None] * total_filas
    acciones = {}

    i = 0
    while i < total_filas:
        if candidatos[i] is not None:
            resolucion[i] = candidatos[i]
            acciones[i] = ("CONSERVADO", f"Valor original {candidatos[i]}")
            i += 1
        else:
            i_start = i
            while i < total_filas and candidatos[i] is None:
                i += 1
            i_end = i - 1
            k = i_end - i_start + 1

            i_prev = i_start - 1
            i_next = i_end + 1

            A = resolucion[i_prev] if i_prev >= 0 else None
            B = candidatos[i_next] if i_next < total_filas else None

            interpolable = False
            if A is not None and B is not None and B > A and (B - A == k + 1):
                interpolable = True
                for j in range(i_start, i_end + 1):
                    val_interp = A + (j - i_start + 1)
                    resolucion[j] = val_interp
                    raw_str = str(raw_vals[j])
                    acciones[j] = ("REPARADO", f"Original '{raw_str}' interpolado a {val_interp}")
            elif A is None and B is not None and (B - k >= 1):
                interpolable = True
                for j in range(i_start, i_end + 1):
                    val_interp = B - (i_end - j + 1)
                    resolucion[j] = val_interp
                    raw_str = str(raw_vals[j])
                    acciones[j] = ("REPARADO", f"Original '{raw_str}' interpolado a {val_interp}")
            
            if not interpolable:
                for j in range(i_start, i_end + 1):
                    raw_str = str(raw_vals[j])
                    resolucion[j] = None
                    if parsed_vals[j] is None:
                        acciones[j] = ("IGNORADO", f"No numérico '{raw_str}' descartado.")
                    else:
                        acciones[j] = ("IGNORADO", f"Número '{raw_str}' descartado sin correlatividad libre.")

    filas_validas = []
    reporte = {
        "total_original": total_filas,
        "conservados": 0,
        "reparados": 0,
        "descartados": 0,
        "detalles_reparados": [],
        "detalles_descartados": [],
    }

    ingresos_asignados = set()

    for idx in range(total_filas):
        val_res = resolucion[idx]
        tipo_acc, detalle = acciones[idx]
        fila_excel = idx + 2
        
        if val_res is not None and val_res not in ingresos_asignados:
            ingresos_asignados.add(val_res)
            row_dict = df.iloc[idx].to_dict()
            row_dict["_numero_ingreso_limpio"] = str(val_res)
            row_dict["_fila_original_excel"] = fila_excel
            filas_validas.append(row_dict)
            
            if tipo_acc == "REPARADO":
                reporte["reparados"] += 1
                reporte["detalles_reparados"].append((fila_excel, detalle))
            else:
                reporte["conservados"] += 1
        else:
            reporte["descartados"] += 1
            reporte["detalles_descartados"].append((fila_excel, detalle))

    df_limpio = pd.DataFrame(filas_validas)
    return df_limpio, reporte


def limpiar_base_datos(db):
    """
    Elimina la ingesta anterior de vehículos de origen y sus repuestos asociados.
    Respeta estrictamente el orden de dependencias de claves foráneas.
    """
    print("\n" + "=" * 76)
    print(" LIMPIEZA DE INGESTA PREVIA EN BASE DE DATOS")
    print("=" * 76)
    try:
        # 1. Detalle Motor y Caja
        res_mot = db.execute(text('DELETE FROM "Detalle_Motor";'))
        res_caj = db.execute(text('DELETE FROM "Detalle_Caja_Cambio";'))
        print(f"[*] Registros eliminados de Detalle_Motor: {res_mot.rowcount}")
        print(f"[*] Registros eliminados de Detalle_Caja_Cambio: {res_caj.rowcount}")

        # 2. Activo Inventariado vinculado a vehículos
        res_act = db.execute(text('DELETE FROM "Activo_Inventariado" WHERE id_vehiculo IS NOT NULL;'))
        print(f"[*] Registros eliminados de Activo_Inventariado (Motores y Cajas): {res_act.rowcount}")

        # 3. Vehiculos de Origen
        res_veh = db.execute(text('DELETE FROM "Vehiculo_Origen";'))
        print(f"[*] Registros eliminados de Vehiculo_Origen: {res_veh.rowcount}")

        db.commit()
        print("✅ Limpieza completada con éxito. Base de datos lista para nueva ingesta.\n")
    except Exception as e:
        db.rollback()
        print(f"❌ Error al limpiar base de datos: {e}")
        raise e


# ==============================================================================
# EJECUCIÓN PRINCIPAL DE LA MIGRACIÓN
# ==============================================================================

def ejecutar_migracion():
    if not os.path.exists(EXCEL_FILE):
        print(f"[!] Error: No se encontró el archivo de matriz '{EXCEL_FILE}'.")
        print("    Asegúrate de colocar el archivo Excel en esta carpeta antes de ejecutar.")
        return

    print(f"[+] Leyendo archivo matriz '{EXCEL_FILE}'...")
    df = pd.read_excel(EXCEL_FILE)
    df = df.dropna(how='all').reset_index(drop=True)

    col_indice = df.columns[0]
    col_anio = None
    col_motor = None
    col_obs = None

    for i, c in enumerate(df.columns):
        c_str = str(c).lower()
        if "2017" in c_str or "año" in c_str or "anio" in c_str or (isinstance(c, int) and 1990 <= c <= 2030):
            col_anio = c
        if "motor" in c_str:
            col_motor = c
        if "observ" in c_str:
            col_obs = c

    # Fallbacks por posición de columnas si no hicieron match por nombre
    if col_anio is None and len(df.columns) > 7:
        col_anio = df.columns[7]
    if col_motor is None and len(df.columns) > 9:
        col_motor = df.columns[9]
    if col_obs is None and len(df.columns) > 12:
        col_obs = df.columns[12]

    print(f"[*] Columnas detectadas: N° Ingreso='{col_indice}', Año='{col_anio}', Motor='{col_motor}', Obs='{col_obs}'")

    print("\n" + "=" * 76)
    print(" AUDITORÍA Y DEPURACIÓN DE NÚMEROS DE INGRESO (COLUMNA A)")
    print("=" * 76)
    df_limpio, reporte = sanitizar_secuencia_ingresos(df, col_indice)

    print(f"[*] Total de filas originales en Excel : {reporte['total_original']}")
    print(f"[*] Registros numéricos conservados   : {reporte['conservados']}")
    print(f"[*] Registros reparados (huecos 'x')   : {reporte['reparados']}")
    print(f"[*] Registros descartados / eliminados : {reporte['descartados']}")
    print("=" * 76 + "\n")

    patentes_registradas = {}

    print("[+] Conectando a la base de datos PostgreSQL mediante SQLAlchemy...")
    db = SessionLocal()
    
    try:
        # Si se especificó el parámetro --limpiar, vaciar ingesta previa automáticamente
        if "--limpiar" in sys.argv or "--reset" in sys.argv:
            limpiar_base_datos(db)

        print("[+] Cargando estado actual de la base de datos...")
        vehiculos_db = db.query(Vehiculo_Origen.numero_ingreso, Vehiculo_Origen.id_vehiculo).all()
        vehiculos_existentes = {v.numero_ingreso: v.id_vehiculo for v in vehiculos_db}
        
        activos_db = db.query(Activo_Inventariado.id_vehiculo, Activo_Inventariado.id_categoria).all()
        activos_existentes = {(a.id_vehiculo, a.id_categoria) for a in activos_db}
        
        print(f"[+] {len(vehiculos_existentes)} vehículos ya registrados en BD.")

        total_a_procesar = len(df_limpio)
        print(f"[+] Procesando {total_a_procesar} vehículos con extracción estandarizada...")
        
        BATCH_SIZE = 500
        vehiculos_creados = 0
        vehiculos_inactivos = 0
        activos_creados = 0

        # Contadores forenses de extracción
        conteo_cilindradas = 0
        conteo_motores_reales = 0
        conteo_automaticas = 0
        conteo_mecanicas = 0
        conteo_diesel = 0
        conteo_gasolina = 0
        conteo_hibrido = 0
        conteo_4x2_delantera = 0
        conteo_4x2_trasera = 0
        conteo_4x4_conectable = 0
        conteo_4x4_permanente = 0
        
        vehiculos_batch = []
        activos_batch = []
        detalles_motor_batch = []
        detalles_caja_batch = []
        
        for idx, row in df_limpio.iterrows():
            patente_final = limpiar_patente(row.get("Patente"), patentes_registradas)
            num_ingreso_final = str(row["_numero_ingreso_limpio"])

            marca_val = str(row.get("Marca")).strip() if pd.notnull(row.get("Marca")) else ""
            modelo_val = str(row.get("Modelo")).strip() if pd.notnull(row.get("Modelo")) else ""
            obs_val = str(row.get(col_obs)).strip() if col_obs and pd.notnull(row.get(col_obs)) else ""
            anio_final = procesar_anio(row.get(col_anio)) if col_anio else 2000
            
            # ------------------------------------------------------------------
            # EXTRACCIÓN AVANZADA ESTANDARIZADA
            # ------------------------------------------------------------------
            cilindrada_final = extraer_cilindrada(modelo_val, obs_val)
            transmision_final = extraer_transmision(modelo_val, obs_val)
            combustible_final = extraer_combustible(modelo_val, obs_val)
            traccion_final = extraer_traccion(marca_val, modelo_val, obs_val)
            numero_motor_final = limpiar_numero_motor(row.get(col_motor) if col_motor else None, obs_val)

            # Estadísticas
            if cilindrada_final != "S/A":
                conteo_cilindradas += 1
            if numero_motor_final != "S/A":
                conteo_motores_reales += 1
            if transmision_final == "Automática":
                conteo_automaticas += 1
            else:
                conteo_mecanicas += 1

            if combustible_final == "Diésel":
                conteo_diesel += 1
            elif combustible_final == "Híbrido":
                conteo_hibrido += 1
            else:
                conteo_gasolina += 1

            if traccion_final == "4x4 Permanente (AWD)":
                conteo_4x4_permanente += 1
            elif traccion_final == "4x4 Conectable (4WD)":
                conteo_4x4_conectable += 1
            elif traccion_final == "4x2 Trasera":
                conteo_4x2_trasera += 1
            else:
                conteo_4x2_delantera += 1

            # Detección de filas sin datos vehiculares mínimos (ej. registros históricos vacíos)
            tiene_marca = bool(marca_val) and marca_val.upper() not in ["NAN", "NONE", "DESCONOCIDA", "S/I", "S/A", "SIN DATOS"]
            tiene_modelo = bool(modelo_val) and modelo_val.upper() not in ["NAN", "NONE", "DESCONOCIDO", "S/I", "S/A", "SIN DATOS"]
            tiene_patente = patente_final is not None and patente_final != ""
            tiene_motor = numero_motor_final != "S/A"

            es_sin_datos = not (tiene_marca or tiene_modelo or tiene_patente or tiene_motor)

            if es_sin_datos:
                estado_vehiculo = "Inactivo"
                marca_final = "SIN INFORMACION (HISTORICO)"
                modelo_final = "S/I"
                estado_activo = "Inactivo"
                id_estado_activo = 4  # De Baja / Inactivo
            else:
                estado_vehiculo = "Activo"
                marca_final = limpiar_marca(marca_val) if tiene_marca else "DESCONOCIDA"
                modelo_final = modelo_val[:100] if tiene_modelo else "DESCONOCIDO"
                estado_activo = "Activo"
                id_estado_activo = 5  # Pendiente de Paletizado / Desarmado

            # 1. Vehículo Base (Vehiculo_Origen)
            if num_ingreso_final in vehiculos_existentes:
                id_vehiculo = vehiculos_existentes[num_ingreso_final]
            else:
                id_vehiculo = uuid.uuid4()
                nuevo_vehiculo = Vehiculo_Origen(
                    id_vehiculo=id_vehiculo,
                    numero_ingreso=num_ingreso_final,
                    patente=patente_final,
                    vin=None,
                    marca=marca_final,
                    modelo=modelo_final,
                    anio=anio_final,
                    traccion=traccion_final,
                    estado=estado_vehiculo,
                    fecha_creacion=datetime.now()
                )
                vehiculos_batch.append(nuevo_vehiculo)
                vehiculos_existentes[num_ingreso_final] = id_vehiculo
                vehiculos_creados += 1
                if es_sin_datos:
                    vehiculos_inactivos += 1

            # 2. MOTOR (Categoría 1) -> Nomenclatura SKU: MOT-{num_ingreso_final}
            if (id_vehiculo, 1) not in activos_existentes:
                id_motor = uuid.uuid4()
                activo_motor = Activo_Inventariado(
                    id_activo=id_motor,
                    sku_qr_fisico=f"MOT-{num_ingreso_final}",
                    id_categoria=1,
                    id_estado=id_estado_activo, 
                    id_sucursal_actual=1,
                    id_vehiculo=id_vehiculo,
                    estado=estado_activo,
                    fecha_creacion=datetime.now(),
                    qr_impreso=False,
                    version_lock=1
                )
                activos_batch.append(activo_motor)

                detalle_motor = Detalle_Motor(
                    id_activo=id_motor,
                    numero_motor=numero_motor_final,
                    cilindrada=cilindrada_final,
                    combustible=combustible_final,
                    transmision_tipo=transmision_final,
                )
                detalles_motor_batch.append(detalle_motor)
                activos_existentes.add((id_vehiculo, 1))
                activos_creados += 1

            # 3. CAJA DE CAMBIOS (Categoría 2) -> Nomenclatura SKU: CAJ-{num_ingreso_final}
            if (id_vehiculo, 2) not in activos_existentes:
                id_caja = uuid.uuid4()
                activo_caja = Activo_Inventariado(
                    id_activo=id_caja,
                    sku_qr_fisico=f"CAJ-{num_ingreso_final}",
                    id_categoria=2,
                    id_estado=id_estado_activo, 
                    id_sucursal_actual=1,
                    id_vehiculo=id_vehiculo,
                    estado=estado_activo,
                    fecha_creacion=datetime.now(),
                    qr_impreso=False,
                    version_lock=1
                )
                activos_batch.append(activo_caja)

                detalle_caja = Detalle_Caja_Cambio(
                    id_activo=id_caja,
                    transmision_tipo=transmision_final,
                )
                detalles_caja_batch.append(detalle_caja)
                activos_existentes.add((id_vehiculo, 2))
                activos_creados += 1

            # Commit en lotes optimizados
            if len(vehiculos_batch) >= BATCH_SIZE or idx == total_a_procesar - 1:
                if vehiculos_batch:
                    db.bulk_save_objects(vehiculos_batch)
                if activos_batch:
                    db.bulk_save_objects(activos_batch)
                if detalles_motor_batch:
                    db.bulk_save_objects(detalles_motor_batch)
                if detalles_caja_batch:
                    db.bulk_save_objects(detalles_caja_batch)
                    
                db.commit()
                print(f"    -> Progreso: {idx + 1} / {total_a_procesar} procesados...")
                
                vehiculos_batch.clear()
                activos_batch.clear()
                detalles_motor_batch.clear()
                detalles_caja_batch.clear()

        print("\n" + "=" * 76)
        print(" MIGRACIÓN COMPLETADA EXITOSAMENTE")
        print("=" * 76)
        print(f"[*] Nuevos Vehículos registrados       : {vehiculos_creados} (Activos: {vehiculos_creados - vehiculos_inactivos}, Inactivos: {vehiculos_inactivos})")
        print(f"[*] Nuevos Repuestos (Motor/Caja)      : {activos_creados}")
        print(f"[*] Cilindradas extraídas              : {conteo_cilindradas}")
        print(f"[*] N° Motor reales extraídos          : {conteo_motores_reales}")
        print(f"[*] Transmisión: Mecánica: {conteo_mecanicas} | Automática: {conteo_automaticas}")
        print(f"[*] Combustible: Gasolina: {conteo_gasolina} | Diésel: {conteo_diesel} | Híbrido: {conteo_hibrido}")
        print(f"[*] Tracción: 4x2 Delantera: {conteo_4x2_delantera} | 4x2 Trasera: {conteo_4x2_trasera} | 4x4 Conectable (4WD): {conteo_4x4_conectable} | 4x4 Permanente (AWD): {conteo_4x4_permanente}")
        print("=" * 76)

    except Exception as err:
        db.rollback()
        print(f"[!] Error crítico durante la migración: {err}")
        print("    Abortando y revirtiendo la transacción para prevenir inconsistencias.")
        raise err
    finally:
        db.close()


if __name__ == "__main__":
    ejecutar_migracion()