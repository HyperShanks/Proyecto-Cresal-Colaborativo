from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Optional

# Asegúrate de importar tus modelos y la función de la base de datos correctamente
from database import get_db
from models import Activo_Inventariado, Orden_Venta, Detalle_Orden, Vehiculo_Origen

router = APIRouter(prefix="/api/v1/bodega", tags=["Tablero Operativo"])

# ==========================================
# 1. ESQUEMAS DE RESPUESTA (PYDANTIC)
# ==========================================
class TareaAlerta(BaseModel):
    id_tarea: str
    tipo_alerta: str
    orden_ref: Optional[str] = None
    titulo_pieza: str
    ubicacion: str
    nota_especial: Optional[str] = None
    estado_bloqueo: Optional[str] = None
    accion_requerida: str


#==========================================
#2. ENDPOINT Y MOTOR DE REGLAS
#==========================================
@router.get("/tareas-pendientes", response_model=List[TareaAlerta])
def obtener_tareas_pendientes(db: Session = Depends(get_db)):
    alertas = []

    # ---------------------------------------------------------
    # REGLA 1: Pendiente de Impresión
    # Condición: Activo está disponible pero qr_impreso es False
    # ---------------------------------------------------------
    activos_sin_qr = db.query(Activo_Inventariado, Vehiculo_Origen).join(
        Vehiculo_Origen, Activo_Inventariado.id_vehiculo == Vehiculo_Origen.id_vehiculo
    ).filter(
        Activo_Inventariado.qr_impreso == False,
        Activo_Inventariado.estado == 'Activo'
    ).all()

    for activo, vehiculo in activos_sin_qr:
        alertas.append({
            "id_tarea": f"IMP-{str(activo.id_activo)[:8]}",
            "tipo_alerta": "IMPRESION",
            "titulo_pieza": f"Repuesto de {vehiculo.marca} {vehiculo.modelo}",
            "ubicacion": f"{activo.ubicacion_pasillo or 'S/P'} - {activo.ubicacion_pallet or 'S/P'}",
            "nota_especial": "GENERAR Y PEGAR ETIQUETA QR",
            "accion_requerida": "GENERAR QR AHORA"
        })

    # ---------------------------------------------------------
    # REGLAS 2 Y 3: Preparación de Pedido y Liberación de Salida
    # Condición: Cruzar Orden_Venta + Detalle_Orden + Activo
    # ---------------------------------------------------------
    detalles_orden = db.query(Detalle_Orden, Orden_Venta, Activo_Inventariado, Vehiculo_Origen).join(
        Orden_Venta, Detalle_Orden.id_orden == Orden_Venta.id_orden
    ).join(
        Activo_Inventariado, Detalle_Orden.id_activo == Activo_Inventariado.id_activo
    ).join(
        Vehiculo_Origen, Activo_Inventariado.id_vehiculo == Vehiculo_Origen.id_vehiculo
    ).filter(
        Orden_Venta.estado_orden.in_(["Reservada", "Pagada"])
    ).all()

    for detalle, orden, activo, vehiculo in detalles_orden:
        # Motor de Reglas Logístico
        if orden.monto_pendiente > 0:
            tipo = "PREPARACION"
            bloqueo = "ESPERANDO PAGO EN CAJA"
            accion = "EN ESPERA"
        else:
            tipo = "LIBERADA"
            bloqueo = None
            accion = "ESCANEAR EN BARRERA"

        alertas.append({
            "id_tarea": f"ORD-{str(detalle.id_detalle)[:8]}",
            "tipo_alerta": tipo,
            "orden_ref": f"ORDEN #{str(orden.id_orden)[:8].upper()}",
            "titulo_pieza": f"Repuesto de {vehiculo.marca} {vehiculo.modelo}",
            "ubicacion": f"{activo.ubicacion_pasillo or 'S/P'} - {activo.ubicacion_pallet or 'S/P'}",
            "nota_especial": detalle.notas_preparacion,
            "estado_bloqueo": bloqueo,
            "accion_requerida": accion
         })

    return alertas
