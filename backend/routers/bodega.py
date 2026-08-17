import uuid
from datetime import datetime
from uuid import UUID
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from pydantic import BaseModel

from database import get_db
from models import (
    Activo_Inventariado,
    Orden_Venta,
    Detalle_Orden,
    Vehiculo_Origen,
    Usuario,
    Detalle_Motor,
    Detalle_Caja_Cambio,
    Tracking_Logistico,
    Despacho,
)
from schemas import TareaAlertaResponse, CompletarPreentregaResponse
from core.security import get_current_user

router = APIRouter(prefix="/api/v1/bodega", tags=["Tablero Operativo"])

# Alias retrocompatible
TareaAlerta = TareaAlertaResponse


@router.get("/tareas-pendientes", response_model=List[TareaAlertaResponse])
def obtener_tareas_pendientes(
    sucursal_id: int = Query(1, description="ID de la sucursal del bodeguero"),
    db: Session = Depends(get_db),
    usuario_logeado: Usuario = Depends(get_current_user),
):
    """
    Lista las tareas operativas pendientes para la bodega de la sucursal indicada:
    1. Tareas de Impresión QR (activos sin etiqueta física impresa).
    2. Tareas de Pre-Entrega / Preparación / Traslado:
       - Retención: se listan activos en estado 'Reservado' (id_estado = 2) o 'Vendido' (id_estado = 3).
       - No desaparecen al pagar en caja (cambio de 2 a 3).
       - Desaparecen una vez que el bodeguero marca 'Listo' (preparacion_lista == True).
       - Filtradas por sucursal de origen / ubicación física actual del activo.
    """
    alertas = []

    # ---------------------------------------------------------
    # REGLA 1: Pendiente de Impresión (FILTRADO POR SUCURSAL)
    # ---------------------------------------------------------
    activos_sin_qr = (
        db.query(Activo_Inventariado, Vehiculo_Origen, Detalle_Motor, Detalle_Caja_Cambio)
        .join(Vehiculo_Origen, Activo_Inventariado.id_vehiculo == Vehiculo_Origen.id_vehiculo)
        .outerjoin(Detalle_Motor, Activo_Inventariado.id_activo == Detalle_Motor.id_activo)
        .outerjoin(Detalle_Caja_Cambio, Activo_Inventariado.id_activo == Detalle_Caja_Cambio.id_activo)
        .filter(
            Activo_Inventariado.qr_impreso == False,
            Activo_Inventariado.estado == "Activo",
            Activo_Inventariado.id_sucursal_actual == sucursal_id,
        )
        .all()
    )

    for activo, vehiculo, motor, caja in activos_sin_qr:
        if activo.id_categoria == 2 and caja:
            transmision_val = caja.transmision_tipo
        elif motor:
            transmision_val = motor.transmision_tipo
        else:
            transmision_val = None

        cat_nombre = "Motor" if activo.id_categoria == 1 else ("Caja de Cambios" if activo.id_categoria == 2 else "Repuesto")
        titulo = f"{cat_nombre} - {vehiculo.marca} {vehiculo.modelo}" if vehiculo else cat_nombre

        etiqueta_data = {
            "id_activo": str(activo.id_activo),
            "numero_ingreso": vehiculo.numero_ingreso if vehiculo else "N/A",
            "marca": vehiculo.marca if vehiculo else "Desconocida",
            "modelo": vehiculo.modelo if vehiculo else "Desconocido",
            "anio": vehiculo.anio if vehiculo else 0,
            "cilindrada": motor.cilindrada if motor else None,
            "combustible": motor.combustible if motor else None,
            "transmision": transmision_val,
            "numero_motor": motor.numero_motor if motor else None,
            "galpon": activo.ubicacion_galpon or "",
            "pasillo": activo.ubicacion_pasillo or "",
            "pallet": activo.ubicacion_pallet or "",
            "sku_qr_fisico": activo.sku_qr_fisico,
        }

        alertas.append(
            TareaAlertaResponse(
                id_tarea=f"IMP-{str(activo.id_activo)[:8]}",
                tipo_alerta="IMPRESION",
                titulo_pieza=titulo,
                categoria=cat_nombre,
                tipo_repuesto=cat_nombre,
                ubicacion=f"{activo.ubicacion_pasillo or 'S/P'} - {activo.ubicacion_pallet or 'S/P'}",
                nota_especial="GENERAR Y PEGAR ETIQUETA QR",
                accion_requerida="GENERAR QR AHORA",
                etiqueta_data=etiqueta_data,
                id_activo=activo.id_activo,
                id_sucursal_origen=activo.id_sucursal_actual,
                es_traslado=False,
                estado_preparacion="Pendiente",
            )
        )

    # ---------------------------------------------------------
    # REGLAS 2 Y 3: Preparación, Traslado y Liberación (FILTRADO POR SUCURSAL)
    # ---------------------------------------------------------
    detalles_orden = (
        db.query(Detalle_Orden, Orden_Venta, Activo_Inventariado, Vehiculo_Origen)
        .join(Orden_Venta, Detalle_Orden.id_orden == Orden_Venta.id_orden)
        .join(Activo_Inventariado, Detalle_Orden.id_activo == Activo_Inventariado.id_activo)
        .join(Vehiculo_Origen, Activo_Inventariado.id_vehiculo == Vehiculo_Origen.id_vehiculo)
        .filter(
            Detalle_Orden.preparacion_lista == False,
            Activo_Inventariado.id_estado.in_([2, 3]),  # 2: Reservado, 3: Vendido
            Activo_Inventariado.id_sucursal_actual == sucursal_id,
            Orden_Venta.estado_orden.in_(["Reservada", "Pagada"]),
        )
        .all()
    )

    for detalle, orden, activo, vehiculo in detalles_orden:
        # Detectar si requiere traslado entre sucursales
        es_traslado = (orden.id_sucursal != activo.id_sucursal_actual)
        tracking = db.query(Tracking_Logistico).filter(
            Tracking_Logistico.id_activo == activo.id_activo,
            Tracking_Logistico.id_sucursal_origen == sucursal_id,
        ).first()

        despacho = db.query(Despacho).filter(Despacho.id_orden == orden.id_orden).first()
        if despacho and despacho.tipo_despacho == "Traslado":
            es_traslado = True

        sucursal_dest_id = despacho.id_sucursal_destino if despacho and despacho.id_sucursal_destino else orden.id_sucursal

        if es_traslado:
            tipo = "TRASLADO"
            if orden.monto_pendiente > 0:
                bloqueo = "ESPERANDO PAGO EN CAJA"
                accion = "EN ESPERA"
            else:
                bloqueo = None
                accion = "PREPARAR Y TRASLADAR"
        else:
            if orden.monto_pendiente > 0:
                tipo = "PREPARACION"
                bloqueo = "ESPERANDO PAGO EN CAJA"
                accion = "EN ESPERA"
            else:
                tipo = "LIBERADA"
                bloqueo = None
                accion = "ESCANEAR EN BARRERA"

        cat_nombre = "Motor" if activo.id_categoria == 1 else ("Caja de Cambios" if activo.id_categoria == 2 else "Repuesto")
        titulo = f"{cat_nombre} - {vehiculo.marca} {vehiculo.modelo}" if vehiculo else cat_nombre

        alertas.append(
            TareaAlertaResponse(
                id_tarea=f"ORD-{str(detalle.id_detalle)[:8]}",
                tipo_alerta=tipo,
                orden_ref=f"ORDEN #{str(orden.id_orden)[:8].upper()}",
                titulo_pieza=titulo,
                categoria=cat_nombre,
                tipo_repuesto=cat_nombre,
                ubicacion=f"{activo.ubicacion_pasillo or 'S/P'} - {activo.ubicacion_pallet or 'S/P'}",
                nota_especial=detalle.notas_preparacion,
                estado_bloqueo=bloqueo,
                accion_requerida=accion,
                id_detalle=detalle.id_detalle,
                id_activo=activo.id_activo,
                id_sucursal_origen=activo.id_sucursal_actual,
                id_sucursal_destino=sucursal_dest_id,
                es_traslado=es_traslado,
                estado_preparacion=detalle.estado_preparacion or "Pendiente",
            )
        )

    return alertas


@router.patch(
    "/tareas/{id_detalle}/completar-preentrega",
    response_model=CompletarPreentregaResponse,
    summary="Marcar Preparación de Pre-Entrega como 'Listo'",
    description="Permite al bodeguero marcar como completada ('Listo') la preparación de una pieza. "
                "Persiste el estado para que la tarea desaparezca del panel de pendientes.",
)
def completar_preentrega(
    id_detalle: UUID,
    db: Session = Depends(get_db),
    usuario_logeado: Usuario = Depends(get_current_user),
):
    detalle = db.query(Detalle_Orden).filter(Detalle_Orden.id_detalle == id_detalle).first()
    if not detalle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Línea de detalle con ID '{id_detalle}' no encontrada.",
        )

    detalle.preparacion_lista = True
    detalle.estado_preparacion = "Listo"
    detalle.fecha_preparacion = datetime.now()

    # Si hay un tracking logístico pendiente asociado, actualizar a listo para traslado
    if detalle.id_activo:
        tracking = db.query(Tracking_Logistico).filter(
            Tracking_Logistico.id_activo == detalle.id_activo,
            Tracking_Logistico.estado_traslado == "Pendiente",
        ).first()
        if tracking:
            tracking.estado_traslado = "Listo para Traslado"

    db.commit()
    db.refresh(detalle)

    return CompletarPreentregaResponse(
        id_detalle=detalle.id_detalle,
        id_orden=detalle.id_orden,
        id_activo=detalle.id_activo,
        preparacion_lista=detalle.preparacion_lista,
        estado_preparacion=detalle.estado_preparacion,
        mensaje="Preparación de pre-entrega marcada como 'Listo' exitosamente.",
        fecha_preparacion=detalle.fecha_preparacion.isoformat() if detalle.fecha_preparacion else None,
    )