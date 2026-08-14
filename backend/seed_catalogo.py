# backend/seed_catalogo.py
"""
Script para poblar la base de datos con repuestos reales para el Catálogo de Ventas (HU-3.2).
Crea vehículos reales (Toyota, Hyundai, Chevrolet, Nissan, Peugeot), activos inventariados
con SKUs de producción y detalles técnicos (Detalle_Motor y Detalle_Caja_Cambio).
"""

import uuid
from sqlalchemy.orm import Session
from database import SessionLocal, Base, engine
from models import (
    Vehiculo_Origen, Activo_Inventariado, Detalle_Motor, Detalle_Caja_Cambio,
    Categoria_Activo, Estado_Activo, Sucursal, Region, Comuna
)

def poblar_catalogo_real():
    Base.metadata.create_all(bind=engine)
    db: Session = SessionLocal()

    try:
        print("Iniciando insercion de inventario real para el Catalogo de Ventas...")

        # 1. Región y Comuna
        region = db.query(Region).filter_by(nombre_region="Valparaíso").first()
        if not region:
            region = Region(nombre_region="Valparaíso")
            db.add(region)
            db.commit()

        comuna_vina = db.query(Comuna).filter_by(nombre_comuna="Viña del Mar").first()
        if not comuna_vina:
            comuna_vina = Comuna(nombre_comuna="Viña del Mar", id_region=region.id_region)
            db.add(comuna_vina)
            db.commit()

        comuna_limache = db.query(Comuna).filter_by(nombre_comuna="Limache").first()
        if not comuna_limache:
            comuna_limache = Comuna(nombre_comuna="Limache", id_region=region.id_region)
            db.add(comuna_limache)
            db.commit()

        # 2. Sucursales (Viña del Mar = 1, Limache = 2)
        suc_vina = db.query(Sucursal).filter_by(nombre_sucursal="Viña del Mar").first()
        if not suc_vina:
            suc_vina = Sucursal(
                nombre_sucursal="Viña del Mar",
                direccion="Camino Internacional 4105",
                sector="Barrio Industrial",
                id_comuna=comuna_vina.id_comuna
            )
            db.add(suc_vina)
            db.commit()

        suc_limache = db.query(Sucursal).filter_by(nombre_sucursal="Limache").first()
        if not suc_limache:
            suc_limache = Sucursal(
                nombre_sucursal="Limache",
                direccion="Avenida Palmira Romano Sur 1200",
                sector="Sector Industrial Limache",
                id_comuna=comuna_limache.id_comuna
            )
            db.add(suc_limache)
            db.commit()

        # 3. Categorías
        cat_motor = db.query(Categoria_Activo).filter_by(nombre_categoria="Motor").first()
        if not cat_motor:
            cat_motor = Categoria_Activo(nombre_categoria="Motor")
            db.add(cat_motor)
            db.commit()

        cat_caja = db.query(Categoria_Activo).filter_by(nombre_categoria="Caja de Cambios").first()
        if not cat_caja:
            cat_caja = Categoria_Activo(nombre_categoria="Caja de Cambios")
            db.add(cat_caja)
            db.commit()

        # 4. Estados
        estado_disp = db.query(Estado_Activo).filter_by(nombre_estado="Disponible").first()
        if not estado_disp:
            estado_disp = Estado_Activo(nombre_estado="Disponible")
            db.add(estado_disp)
            db.commit()

        # 5. Lista de Repuestos Reales
        repuestos_data = [
            {
                "vehiculo": {
                    "numero_ingreso": "ING-2401",
                    "patente": "KXYZ12",
                    "marca": "Toyota",
                    "modelo": "Yaris Sport",
                    "anio": 2019,
                    "traccion": "4x2"
                },
                "activo": {
                    "sku": "MOT-TOY-YAR-2019-01",
                    "id_categoria": cat_motor.id_categoria,
                    "id_sucursal": suc_vina.id_sucursal,
                    "precio": 520000,
                    "pasillo": "P-02",
                    "pallet": "PL-14"
                },
                "motor": {
                    "numero_motor": "1NZ-FE-889123",
                    "cilindrada": "1.5L",
                    "combustible": "Gasolina",
                    "transmision_tipo": "Manual"
                }
            },
            {
                "vehiculo": {
                    "numero_ingreso": "ING-2402",
                    "patente": "LPRT45",
                    "marca": "Hyundai",
                    "modelo": "Tucson",
                    "anio": 2021,
                    "traccion": "4x4"
                },
                "activo": {
                    "sku": "MOT-HYU-TUC-2021-02",
                    "id_categoria": cat_motor.id_categoria,
                    "id_sucursal": suc_vina.id_sucursal,
                    "precio": 980000,
                    "pasillo": "P-01",
                    "pallet": "PL-05"
                },
                "motor": {
                    "numero_motor": "D4HA-778210",
                    "cilindrada": "2.0L CRDi",
                    "combustible": "Diesel",
                    "transmision_tipo": "Automatica"
                }
            },
            {
                "vehiculo": {
                    "numero_ingreso": "ING-2403",
                    "patente": "GHJK88",
                    "marca": "Hyundai",
                    "modelo": "Accent",
                    "anio": 2018,
                    "traccion": "4x2"
                },
                "activo": {
                    "sku": "CAJ-HYU-ACC-2018-03",
                    "id_categoria": cat_caja.id_categoria,
                    "id_sucursal": suc_limache.id_sucursal,
                    "precio": 380000,
                    "pasillo": "P-04",
                    "pallet": "PL-22"
                },
                "caja": {
                    "transmision_tipo": "Manual 6 Vel"
                }
            },
            {
                "vehiculo": {
                    "numero_ingreso": "ING-2404",
                    "patente": "PJLK99",
                    "marca": "Chevrolet",
                    "modelo": "Sail",
                    "anio": 2020,
                    "traccion": "4x2"
                },
                "activo": {
                    "sku": "MOT-CHEV-SAI-2020-04",
                    "id_categoria": cat_motor.id_categoria,
                    "id_sucursal": suc_limache.id_sucursal,
                    "precio": 450000,
                    "pasillo": "P-03",
                    "pallet": "PL-09"
                },
                "motor": {
                    "numero_motor": "LCU-149021",
                    "cilindrada": "1.5L",
                    "combustible": "Gasolina",
                    "transmision_tipo": "Manual"
                }
            },
            {
                "vehiculo": {
                    "numero_ingreso": "ING-2405",
                    "patente": "DFGH34",
                    "marca": "Nissan",
                    "modelo": "Qashqai",
                    "anio": 2022,
                    "traccion": "4x2"
                },
                "activo": {
                    "sku": "CAJ-NIS-QAS-2022-05",
                    "id_categoria": cat_caja.id_categoria,
                    "id_sucursal": suc_vina.id_sucursal,
                    "precio": 650000,
                    "pasillo": "P-02",
                    "pallet": "PL-18"
                },
                "caja": {
                    "transmision_tipo": "CVT Xtronic"
                }
            },
            {
                "vehiculo": {
                    "numero_ingreso": "ING-2406",
                    "patente": "RSTV66",
                    "marca": "Peugeot",
                    "modelo": "208",
                    "anio": 2021,
                    "traccion": "4x2"
                },
                "activo": {
                    "sku": "MOT-PEU-208-2021-06",
                    "id_categoria": cat_motor.id_categoria,
                    "id_sucursal": suc_vina.id_sucursal,
                    "precio": 720000,
                    "pasillo": "P-05",
                    "pallet": "PL-03"
                },
                "motor": {
                    "numero_motor": "HN05-PureTech",
                    "cilindrada": "1.2L PureTech Turbo",
                    "combustible": "Gasolina",
                    "transmision_tipo": "Manual"
                }
            }
        ]

        for item_data in repuestos_data:
            v_data = item_data["vehiculo"]
            v_obj = db.query(Vehiculo_Origen).filter_by(numero_ingreso=v_data["numero_ingreso"]).first()
            if not v_obj:
                v_obj = Vehiculo_Origen(
                    id_vehiculo=uuid.uuid4(),
                    numero_ingreso=v_data["numero_ingreso"],
                    patente=v_data["patente"],
                    marca=v_data["marca"],
                    modelo=v_data["modelo"],
                    anio=v_data["anio"],
                    traccion=v_data["traccion"],
                    estado="Activo"
                )
                db.add(v_obj)
                db.commit()

            a_data = item_data["activo"]
            a_obj = db.query(Activo_Inventariado).filter_by(sku_qr_fisico=a_data["sku"]).first()
            if not a_obj:
                a_obj = Activo_Inventariado(
                    id_activo=uuid.uuid4(),
                    sku_qr_fisico=a_data["sku"],
                    id_categoria=a_data["id_categoria"],
                    id_estado=estado_disp.id_estado,
                    id_sucursal_actual=a_data["id_sucursal"],
                    id_vehiculo=v_obj.id_vehiculo,
                    ubicacion_pasillo=a_data["pasillo"],
                    ubicacion_pallet=a_data["pallet"],
                    precio_referencia=a_data["precio"],
                    estado="Activo",
                    qr_impreso=True
                )
                db.add(a_obj)
                db.commit()

                if "motor" in item_data:
                    m_data = item_data["motor"]
                    m_obj = Detalle_Motor(
                        id_activo=a_obj.id_activo,
                        numero_motor=m_data["numero_motor"],
                        cilindrada=m_data["cilindrada"],
                        combustible=m_data["combustible"],
                        transmision_tipo=m_data["transmision_tipo"]
                    )
                    db.add(m_obj)
                    db.commit()

                if "caja" in item_data:
                    c_data = item_data["caja"]
                    c_obj = Detalle_Caja_Cambio(
                        id_activo=a_obj.id_activo,
                        transmision_tipo=c_data["transmision_tipo"]
                    )
                    db.add(c_obj)
                    db.commit()

        print("[OK] Inventario real de repuestos insertado con exito!")

    except Exception as e:
        db.rollback()
        print(f"[ERROR] Error al poblar catalogo real: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    poblar_catalogo_real()
