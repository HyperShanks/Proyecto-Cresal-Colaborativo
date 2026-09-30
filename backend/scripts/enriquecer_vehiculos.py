"""
backend/scripts/enriquecer_vehiculos.py
Script de enriquecimiento e ingesta histórica idempotente (SPEC-22).
Lee MatrizLosPinos.xlsx y realiza UPDATE sobre Vehiculo_Origen cruzando por numero_ingreso (Columna A).
Puebla los campos: factura, fecha_ingreso, origen, color, numero_motor, destino, grua, observaciones.
No altera inventario existente ni duplica registros.
"""

import os
import sys
from datetime import datetime
import pandas as pd
from dotenv import load_dotenv

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import SessionLocal
from models import Vehiculo_Origen

load_dotenv()

EXCEL_FILE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "MatrizLosPinos.xlsx")

def procesar_fecha(valor):
    if pd.isna(valor):
        return None
    if isinstance(valor, (datetime, pd.Timestamp)):
        return valor.date()
    try:
        dt = pd.to_datetime(valor, errors='coerce')
        if pd.notnull(dt):
            return dt.date()
    except Exception:
        pass
    return None

def enriquecer_vehiculos():
    if not os.path.exists(EXCEL_FILE):
        print(f"[!] Error: No se encontro el archivo '{EXCEL_FILE}'")
        return

    print(f"[+] Leyendo matriz '{EXCEL_FILE}'...")
    df = pd.read_excel(EXCEL_FILE)
    df = df.dropna(how='all').reset_index(drop=True)

    col_indice = df.columns[0]
    print(f"[+] Total filas leidas: {len(df)}")

    db = SessionLocal()
    try:
        vehiculos_db = db.query(Vehiculo_Origen).all()
        vehiculos_map = {v.numero_ingreso: v for v in vehiculos_db}
        print(f"[+] Vehiculos existentes en BD: {len(vehiculos_map)}")

        actualizados = 0
        sin_cambios = 0
        no_encontrados = 0

        for idx, row in df.iterrows():
            val_ingreso = row.get(col_indice)
            if pd.isna(val_ingreso):
                continue
            
            try:
                num_ingreso = str(int(float(val_ingreso)))
            except (ValueError, TypeError):
                num_ingreso = str(val_ingreso).strip()

            if num_ingreso not in vehiculos_map:
                no_encontrados += 1
                continue

            vehiculo = vehiculos_map[num_ingreso]
            cambio = False

            # 1. Factura
            factura_raw = row.get("Factura")
            if pd.notnull(factura_raw) and str(factura_raw).strip().upper() not in ["NAN", "NONE", ""]:
                f_val = str(factura_raw).strip()[:50]
                if vehiculo.factura != f_val:
                    vehiculo.factura = f_val
                    cambio = True

            # 2. Fecha ingreso
            f_ing = procesar_fecha(row.get("Fecha ingreso"))
            if f_ing and vehiculo.fecha_ingreso != f_ing:
                vehiculo.fecha_ingreso = f_ing
                cambio = True

            # 3. Origen
            orig_raw = row.get("Origen")
            if pd.notnull(orig_raw) and str(orig_raw).strip().upper() not in ["NAN", "NONE", ""]:
                orig_val = str(orig_raw).strip().upper()[:100]
                if vehiculo.origen != orig_val:
                    vehiculo.origen = orig_val
                    cambio = True

            # 4. Color
            color_raw = row.get("Color")
            if pd.notnull(color_raw) and str(color_raw).strip().upper() not in ["NAN", "NONE", ""]:
                col_val = str(color_raw).strip().upper()[:50]
                if vehiculo.color != col_val:
                    vehiculo.color = col_val
                    cambio = True

            # 5. Numero Motor
            motor_raw = row.get("N° Motor") if "N° Motor" in df.columns else None
            if pd.notnull(motor_raw) and str(motor_raw).strip().upper() not in ["NAN", "NONE", "SN", "S/N", "S/A", "0", ""]:
                mot_val = str(motor_raw).strip().upper()[:100]
                if vehiculo.numero_motor != mot_val:
                    vehiculo.numero_motor = mot_val
                    cambio = True

            # 6. Destino
            dest_raw = row.get("Destino")
            dest_val = str(dest_raw).strip().upper()[:50] if pd.notnull(dest_raw) and str(dest_raw).strip().upper() not in ["NAN", "NONE", ""] else "DESARME"
            if vehiculo.destino != dest_val:
                vehiculo.destino = dest_val
                cambio = True

            # 7. Grua
            grua_raw = row.get("GRUA")
            if pd.notnull(grua_raw) and str(grua_raw).strip().upper() not in ["NAN", "NONE", ""]:
                grua_val = str(grua_raw).strip().upper()[:100]
                if vehiculo.grua != grua_val:
                    vehiculo.grua = grua_val
                    cambio = True

            # 8. Observaciones
            obs_raw = row.get("OBSERVACIONES")
            if pd.notnull(obs_raw) and str(obs_raw).strip().upper() not in ["NAN", "NONE", ""]:
                obs_val = str(obs_raw).strip()
                if vehiculo.observaciones != obs_val:
                    vehiculo.observaciones = obs_val
                    cambio = True

            if cambio:
                actualizados += 1
            else:
                sin_cambios += 1

            if actualizados % 500 == 0 and actualizados > 0:
                db.commit()

        db.commit()
        print("\n=== RESUMEN ENRIQUECIMIENTO HISTORICO ===")
        print(f"[*] Registros actualizados con exito : {actualizados}")
        print(f"[*] Registros sin modificaciones    : {sin_cambios}")
        print(f"[*] Registros en Excel no en BD     : {no_encontrados}")
        print("=========================================\n")

    except Exception as e:
        db.rollback()
        print(f"[!] Error durante enriquecimiento: {e}")
        raise e
    finally:
        db.close()

if __name__ == "__main__":
    enriquecer_vehiculos()
