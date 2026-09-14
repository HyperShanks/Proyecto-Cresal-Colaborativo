import os
import re
import uuid
from datetime import datetime
import pandas as pd
from dotenv import load_dotenv

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

def sanitizar_secuencia_ingresos(df, col_indice):
    """
    Procesa, audita y blinda la columna de N° de Ingreso (Columna A) del Excel.
    
    Reglas estrictas de negocio:
    1. Solo deben existir números de ingreso autoincrementables/enteros positivos y estrictamente ÚNICOS.
    2. Si un valor no es numérico (ej. 'x', NaN, vacío) o es un duplicado/anomalía, pero se encuentra
       en un hueco correlativo resoluble (ej. 1, 2, 3, x, 5 -> x pasa a 4):
       Se INTERPOLA y se reemplaza por el correlativo exacto.
    3. Si un valor no es numérico (ej. 'con con', 'con con') y no puede interpolarse sin colisionar
       (ej. 1, 2, 3, con con, con con, 4, 5 donde ya viene el 4):
       Se ELIMINA / IGNORA la fila (no se sube a la base de datos).
    4. Si un número está repetido (ej. 834 repetido, o texto repetido) y no existe un hueco correlativo
       libre donde reubicarlo:
       Se ELIMINA / IGNORA la fila duplicada.
    """
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

    # Conteo de ocurrencias de cada número para detectar duplicados globales
    conteo_numeros = {}
    for v in parsed_vals:
        if v is not None:
            conteo_numeros[v] = conteo_numeros.get(v, 0) + 1

    # Identificación de anclas confiables:
    # Si un número aparece repetido, sólo el que esté en orden secuencial se toma como ancla.
    candidatos = [None] * total_filas
    vistos = set()
    ultimo_valido = 0

    for i in range(total_filas):
        v = parsed_vals[i]
        if v is None:
            candidatos[i] = None
        else:
            if v in vistos:
                # Duplicado: debe ser evaluado para posible interpolación o descarte
                candidatos[i] = None
            elif v <= ultimo_valido and conteo_numeros[v] > 1:
                # Duplicado anómalo retrógrado (ej. 1085 en fila 1810 cuando veníamos en 1809)
                candidatos[i] = None
            elif v <= ultimo_valido:
                # Retorno de secuencia no explicado
                candidatos[i] = None
            else:
                candidatos[i] = v
                vistos.add(v)
                ultimo_valido = v

    # Resolución de bloques problemáticos mediante interpolación acotada o descarte
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

            # Condición de hueco exacto: B - A == k + 1
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
                        acciones[j] = ("IGNORADO", f"No numérico '{raw_str}' descartado por no encajar en correlatividad.")
                    else:
                        acciones[j] = ("IGNORADO", f"Número '{raw_str}' repetido/fuera de secuencia descartado sin correlatividad libre.")

    # Construcción de DataFrame depurado y reporte forense
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
        fila_excel = idx + 2 # Fila considerando encabezado en Fila 1
        
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

    for c in df.columns:
        c_str = str(c).lower()
        if "2017" in c_str or "año" in c_str or "anio" in c_str:
            col_anio = c
        if "motor" in c_str and "n" in c_str: 
            col_motor = c

    print("\n" + "=" * 76)
    print(" AUDITORÍA Y DEPURACIÓN DE NÚMEROS DE INGRESO (COLUMNA A)")
    print("=" * 76)
    df_limpio, reporte = sanitizar_secuencia_ingresos(df, col_indice)

    print(f"[*] Total de filas originales en Excel : {reporte['total_original']}")
    print(f"[*] Registros numéricos conservados   : {reporte['conservados']}")
    print(f"[*] Registros reparados (huecos 'x')   : {reporte['reparados']}")
    print(f"[*] Registros descartados / eliminados : {reporte['descartados']}")
    print("=" * 76)

    if reporte["detalles_reparados"]:
        print(f"\n[i] Detalle de registros reparados por correlatividad ({len(reporte['detalles_reparados'])}):")
        for fila, detalle in reporte["detalles_reparados"][:15]:
            print(f"    - Fila {fila}: {detalle}")
        if len(reporte["detalles_reparados"]) > 15:
            print(f"    ... y {len(reporte['detalles_reparados']) - 15} correcciones adicionales.")

    if reporte["detalles_descartados"]:
        print(f"\n[!] Detalle de registros ignorados / eliminados ({len(reporte['detalles_descartados'])}):")
        for fila, detalle in reporte["detalles_descartados"][:15]:
            print(f"    - Fila {fila}: {detalle}")
        if len(reporte["detalles_descartados"]) > 15:
            print(f"    ... y {len(reporte['detalles_descartados']) - 15} descartes adicionales.")

    print("=" * 76 + "\n")

    patentes_registradas = {}

    print("[+] Conectando a la base de datos PostgreSQL mediante SQLAlchemy...")
    db = SessionLocal()
    
    try:
        print("[+] Cargando estado actual de la base de datos...")
        vehiculos_db = db.query(Vehiculo_Origen.numero_ingreso, Vehiculo_Origen.id_vehiculo).all()
        vehiculos_existentes = {v.numero_ingreso: v.id_vehiculo for v in vehiculos_db}
        
        activos_db = db.query(Activo_Inventariado.id_vehiculo, Activo_Inventariado.id_categoria).all()
        activos_existentes = {(a.id_vehiculo, a.id_categoria) for a in activos_db}
        
        print(f"[+] {len(vehiculos_existentes)} vehículos ya registrados en BD.")

        total_a_procesar = len(df_limpio)
        print(f"[+] Procesando {total_a_procesar} vehículos 100% limpios y validados...")
        
        BATCH_SIZE = 500
        vehiculos_creados = 0
        vehiculos_inactivos = 0
        activos_creados = 0
        
        vehiculos_batch = []
        activos_batch = []
        detalles_motor_batch = []
        detalles_caja_batch = []
        
        for idx, row in df_limpio.iterrows():
            patente_final = limpiar_patente(row.get("Patente"), patentes_registradas)
            num_ingreso_final = str(row["_numero_ingreso_limpio"])

            marca_val = str(row.get("Marca")).strip() if pd.notnull(row.get("Marca")) else ""
            modelo_val = str(row.get("Modelo")).strip() if pd.notnull(row.get("Modelo")) else ""
            anio_final = procesar_anio(row.get(col_anio)) if col_anio else 2000
            
            numero_motor_raw = str(row.get(col_motor)).strip() if col_motor and pd.notnull(row.get(col_motor)) else "S/A"
            if numero_motor_raw.lower() in ["nan", "none"]:
                numero_motor_raw = "S/A"

            # Detección de filas sin datos vehiculares mínimos (ej. caso 2170 antiguo)
            tiene_marca = bool(marca_val) and marca_val.upper() not in ["NAN", "NONE", "DESCONOCIDA", "S/I", "S/A", "SIN DATOS"]
            tiene_modelo = bool(modelo_val) and modelo_val.upper() not in ["NAN", "NONE", "DESCONOCIDO", "S/I", "S/A", "SIN DATOS"]
            tiene_patente = patente_final is not None and patente_final != ""
            tiene_motor = bool(numero_motor_raw) and numero_motor_raw.upper() not in ["S/A", "NAN", "NONE", "S/N", "SIN NUMERO"]

            es_sin_datos = not (tiene_marca or tiene_modelo or tiene_patente or tiene_motor)

            if es_sin_datos:
                estado_vehiculo = "Inactivo"
                marca_final = "SIN INFORMACION (HISTORICO)"
                modelo_final = "S/I"
                estado_activo = "Inactivo"
                id_estado_activo = 4  # De Baja / Inactivo
            else:
                estado_vehiculo = "Activo"
                marca_final = marca_val[:100] if tiene_marca else "DESCONOCIDA"
                modelo_final = modelo_val[:100] if tiene_modelo else "DESCONOCIDO"
                estado_activo = "Activo"
                id_estado_activo = 5  # Pendiente de Paletizado / Desarmado

            # 1. Vehículo Base
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
                    traccion="S/A",
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
                    numero_motor=numero_motor_raw,
                    cilindrada="S/A",
                    combustible="S/A",
                    transmision_tipo="S/A",
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
                    transmision_tipo="S/A",
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
                print(f"    -> Progreso: {idx + 1} / {total_a_procesar} procesados (Modo Bulk de alta velocidad)...")
                
                vehiculos_batch.clear()
                activos_batch.clear()
                detalles_motor_batch.clear()
                detalles_caja_batch.clear()

        print(f"\n[OK] Migración completada exitosamente.")
        print(f"     Nuevos Vehículos registrados  : {vehiculos_creados} (Activos: {vehiculos_creados - vehiculos_inactivos}, Inactivos/Sin datos: {vehiculos_inactivos})")
        print(f"     Nuevos Repuestos (Motor/Caja) : {activos_creados}")

    except Exception as err:
        db.rollback()
        print(f"[!] Error crítico durante la migración: {err}")
        print("    Abortando y revirtiendo la transacción para prevenir inconsistencias.")
    finally:
        db.close()

if __name__ == "__main__":
    ejecutar_migracion()