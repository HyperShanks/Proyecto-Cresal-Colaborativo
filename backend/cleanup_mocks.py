# backend/cleanup_mocks.py
"""
Script para eliminar los datos mock (QR-MOCK-*) de la base de datos PostgreSQL,
dejando únicamente los repuestos e inventario real para el Catálogo de Ventas.
"""

from sqlalchemy.orm import Session
from database import SessionLocal
from models import (
    Activo_Inventariado, Detalle_Orden, Detalle_Motor, Detalle_Caja_Cambio, Multimedia_Activo
)

def limpiar_datos_mock():
    db: Session = SessionLocal()
    try:
        print("Iniciando limpieza de datos mock (QR-MOCK-*)...")

        # 1. Buscar activos con SKU que contenga MOCK o QR-MOCK
        activos_mock = db.query(Activo_Inventariado).filter(
            Activo_Inventariado.sku_qr_fisico.ilike("%MOCK%")
        ).all()

        print(f"Se encontraron {len(activos_mock)} activos mock para eliminar.")

        for activo in activos_mock:
            # Eliminar referencias en Detalle_Orden
            db.query(Detalle_Orden).filter(Detalle_Orden.id_activo == activo.id_activo).delete(synchronize_session=False)
            
            # Eliminar referencias en Detalle_Motor
            db.query(Detalle_Motor).filter(Detalle_Motor.id_activo == activo.id_activo).delete(synchronize_session=False)

            # Eliminar referencias en Detalle_Caja_Cambio
            db.query(Detalle_Caja_Cambio).filter(Detalle_Caja_Cambio.id_activo == activo.id_activo).delete(synchronize_session=False)

            # Eliminar referencias en Multimedia_Activo
            db.query(Multimedia_Activo).filter(Multimedia_Activo.id_activo == activo.id_activo).delete(synchronize_session=False)

            # Eliminar el activo inventariado
            db.delete(activo)

        db.commit()
        print("[OK] Datos mock eliminados exitosamente de la base de datos.")

    except Exception as e:
        db.rollback()
        print(f"[ERROR] Error al limpiar datos mock: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    limpiar_datos_mock()
