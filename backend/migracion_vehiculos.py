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

def procesar_numero_ingreso(num_raw, idx, ingresos_registrados):
    """Garantiza unicidad en numero_ingreso evitando colisiones UNIQUE."""
    if pd.notnull(num_raw):
        try:
            base = str(int(float(num_raw))).strip()
        except (ValueError, TypeError):
            base = str(num_raw).strip()
    else:
        base = str(idx + 1)

    if base in ingresos_registrados:
        conteo = ingresos_registrados[base]
        ingresos_registrados[base] += 1
        resultado = f"{base}-D{conteo}"
        return resultado[:10]
    else:
        ingresos_registrados[base] = 1
        return base[:10]

def procesar_anio(valor_raw):
    try:
        if pd.isna(valor_raw):
            return 2000
        val = int(float(valor_raw))
        return val if 1950 <= val <= 2030 else 2000
    except (ValueError, TypeError):
        return 2000

def ejecutar_migracion():
    if not os.path.exists(EXCEL_FILE):
        print(f"[!] Error: No se encontró el archivo {EXCEL_FILE}")
        return

    print(f"[+] Leyendo {EXCEL_FILE}...")
    df = pd.read_excel(EXCEL_FILE)

    col_indice = df.columns[0]
    col_anio = None
    col_motor = None

    for c in df.columns:
        c_str = str(c).lower()
        if "2017" in c_str or "año" in c_str or "anio" in c_str:
            col_anio = c
        if "motor" in c_str and "n" in c_str: 
            col_motor = c

    patentes_registradas = {}
    ingresos_registrados = {}

    print("[+] Conectando a la base de datos PostgreSQL mediante SQLAlchemy...")
    db = SessionLocal()
    
    try:
        print("[+] Cargando estado actual de la base de datos...")
        vehiculos_db = db.query(Vehiculo_Origen.numero_ingreso, Vehiculo_Origen.id_vehiculo).all()
        vehiculos_existentes = {v.numero_ingreso: v.id_vehiculo for v in vehiculos_db}
        
        activos_db = db.query(Activo_Inventariado.id_vehiculo, Activo_Inventariado.id_categoria).all()
        activos_existentes = {(a.id_vehiculo, a.id_categoria) for a in activos_db}
        
        print(f"[+] {len(vehiculos_existentes)} vehículos ya registrados en BD.")

        total = len(df)
        print(f"[+] {total} filas encontradas en el Excel.")
        
        BATCH_SIZE = 500
        vehiculos_creados = 0
        activos_creados = 0
        
        vehiculos_batch = []
        activos_batch = []
        detalles_motor_batch = []
        detalles_caja_batch = []
        
        for idx, row in df.iterrows():
            patente_final = limpiar_patente(row.get("Patente"), patentes_registradas)
            num_ingreso_final = procesar_numero_ingreso(row.get(col_indice), idx, ingresos_registrados)

            marca_raw = str(row.get("Marca")).strip() if pd.notnull(row.get("Marca")) else "DESCONOCIDA"
            modelo_raw = str(row.get("Modelo")).strip() if pd.notnull(row.get("Modelo")) else "DESCONOCIDO"
            anio_final = procesar_anio(row.get(col_anio)) if col_anio else 2000
            
            numero_motor_raw = str(row.get(col_motor)).strip() if col_motor and pd.notnull(row.get(col_motor)) else "S/A"
            if numero_motor_raw.lower() in ["nan", "none"]:
                numero_motor_raw = "S/A"

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
                    marca=marca_raw[:100],
                    modelo=modelo_raw[:100],
                    anio=anio_final,
                    traccion="S/A",
                    estado="Activo",
                    fecha_creacion=datetime.now()
                )
                vehiculos_batch.append(nuevo_vehiculo)
                vehiculos_existentes[num_ingreso_final] = id_vehiculo
                vehiculos_creados += 1

            # 2. MOTOR (Categoría 1)
            if (id_vehiculo, 1) not in activos_existentes:
                id_motor = uuid.uuid4()
                activo_motor = Activo_Inventariado(
                    id_activo=id_motor,
                    sku_qr_fisico=f"MOT-{num_ingreso_final}-{id_motor.hex[:4].upper()}",
                    id_categoria=1,
                    id_estado=5, 
                    id_sucursal_actual=1,
                    id_vehiculo=id_vehiculo,
                    estado="Activo",
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

            # 3. CAJA DE CAMBIOS (Categoría 2)
            if (id_vehiculo, 2) not in activos_existentes:
                id_caja = uuid.uuid4()
                activo_caja = Activo_Inventariado(
                    id_activo=id_caja,
                    sku_qr_fisico=f"CAJ-{num_ingreso_final}-{id_caja.hex[:4].upper()}",
                    id_categoria=2,
                    id_estado=5,
                    id_sucursal_actual=1,
                    id_vehiculo=id_vehiculo,
                    estado="Activo",
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
            if len(vehiculos_batch) >= BATCH_SIZE or idx == total - 1:
                if vehiculos_batch:
                    db.bulk_save_objects(vehiculos_batch)
                if activos_batch:
                    db.bulk_save_objects(activos_batch)
                if detalles_motor_batch:
                    db.bulk_save_objects(detalles_motor_batch)
                if detalles_caja_batch:
                    db.bulk_save_objects(detalles_caja_batch)
                    
                db.commit()
                print(f"    -> Progreso: {idx + 1} / {total} procesados (Modo Bulk de alta velocidad)...")
                
                vehiculos_batch.clear()
                activos_batch.clear()
                detalles_motor_batch.clear()
                detalles_caja_batch.clear()

        print(f"[OK] Migración exitosa. Nuevos Vehículos: {vehiculos_creados} | Nuevos Repuestos (Motor/Caja): {activos_creados}")

    except Exception as err:
        db.rollback()
        print(f"[!] Error crítico durante la migración en la fila {idx}: {err}")
        print("Abortando y revirtiendo la transacción para prevenir inconsistencias.")
    finally:
        db.close()

if __name__ == "__main__":
    ejecutar_migracion()