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
    Categoria_Activo,
    Estado_Activo,
    Cliente,
    Auditoria_Barrera,
    Tracking_Logistico,
    Despacho,
)
from schemas import (
    TareaAlertaResponse,
    CompletarPreentregaResponse,
    VerificarQrSalidaRequest,
    VerificarQrSalidaResponse,
    ItemSalidaInfo,
    EscanearSalidaRequest,
    EscanearSalidaResponse,
)
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


@router.post(
    "/verificar-qr-salida",
    response_model=VerificarQrSalidaResponse,
    summary="Verificar Ticket Digital QR para Salida de Bodega",
    description="Permite al bodeguero inspeccionar previamente el contenido de una orden pagada escaneando el QR Digital emitido al vendedor."
)
def verificar_qr_salida(
    payload: VerificarQrSalidaRequest,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    token = payload.qr_transaccional_salida.strip()
    print(f"🔍 [BARRERA] Inspeccionando token QR: '{token}'")

    orden = db.query(Orden_Venta).filter(Orden_Venta.qr_transaccional_salida == token).first()
    if not orden:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Código QR transaccional no encontrado o inválido."
        )

    # Validar que pertenezca a la sucursal del bodeguero si aplica
    if current_user.id_sucursal and orden.id_sucursal != current_user.id_sucursal:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"La orden pertenece a la sucursal {orden.id_sucursal}. No está autorizado para despachar órdenes de otra sucursal."
        )

    # Validaciones Poka-Yoke de estado
    if orden.estado_orden == "Anulada":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Esta orden fue 'Anulada' y no puede ser entregada."
        )

    if orden.estado_orden == "Completada":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"La orden #{str(orden.id_orden)[:8].upper()} ya fue entregada y completada anteriormente."
        )

    if orden.estado_orden != "Pagada" or orden.monto_pendiente > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"La orden #{str(orden.id_orden)[:8].upper()} no se encuentra pagada en caja (Saldo pendiente: ${orden.monto_pendiente})."
        )

    # Datos del cliente
    cliente = db.query(Cliente).filter(Cliente.id_cliente == orden.id_cliente).first()
    cliente_nombre = f"{cliente.nombres} {cliente.apellidos}".strip() if cliente else "Cliente General"
    cliente_rut = cliente.rut_cliente if cliente else "N/A"
    cliente_tel = cliente.telefono if cliente else None

    # Detalles de repuestos
    detalles = db.query(Detalle_Orden).filter(Detalle_Orden.id_orden == orden.id_orden).all()
    items_info = []
    total_fisicos = 0

    for d in detalles:
        if d.id_activo:
            activo = db.query(Activo_Inventariado).filter(Activo_Inventariado.id_activo == d.id_activo).first()
            if activo:
                vehiculo = db.query(Vehiculo_Origen).filter(Vehiculo_Origen.id_vehiculo == activo.id_vehiculo).first() if activo.id_vehiculo else None
                cat = db.query(Categoria_Activo).filter(Categoria_Activo.id_categoria == activo.id_categoria).first()
                nombre_cat = cat.nombre_categoria if cat else "Repuesto"
                titulo = f"{nombre_cat} - {vehiculo.marca} {vehiculo.modelo} ({vehiculo.anio})" if vehiculo else (d.descripcion_manual or nombre_cat)
                ubicacion = f"{activo.ubicacion_pasillo or 'S/P'} - {activo.ubicacion_pallet or 'S/P'}"
                sku = activo.sku_qr_fisico
                es_inv = True
                total_fisicos += 1
            else:
                titulo = d.descripcion_manual or "Repuesto Desconocido"
                ubicacion = "N/A"
                sku = None
                es_inv = False
        else:
            titulo = d.descripcion_manual or "Venta Libre / Servicio"
            ubicacion = "Venta Libre"
            sku = None
            es_inv = False

        items_info.append(ItemSalidaInfo(
            id_detalle=d.id_detalle,
            id_activo=d.id_activo,
            titulo=titulo,
            sku_qr_fisico=sku,
            es_inventariado=es_inv,
            ubicacion=ubicacion,
            notas_preparacion=d.notas_preparacion,
            cantidad=d.cantidad,
            precio_final=d.precio_final,
        ))

    folio = f"ORD-{str(orden.id_orden)[:8].upper()}"
    print(f"✅ [BARRERA] Inspección de orden {folio} exitosa: {len(items_info)} ítems ({total_fisicos} físicos requeridos).")

    return VerificarQrSalidaResponse(
        id_orden=orden.id_orden,
        folio=folio,
        estado_orden=orden.estado_orden,
        total_venta=orden.total_venta,
        monto_pendiente=orden.monto_pendiente,
        id_sucursal=orden.id_sucursal,
        cliente_nombre=cliente_nombre,
        cliente_rut=cliente_rut,
        cliente_telefono=cliente_tel,
        items_requeridos=items_info,
        total_items_fisicos=total_fisicos,
        qr_transaccional_salida=orden.qr_transaccional_salida,
    )


@router.post(
    "/escanear-salida",
    response_model=EscanearSalidaResponse,
    summary="Confirmar Handshake y Salida en Barrera (Dual-Scan Match)",
    description="Valida la coincidencia del token digital del vendedor con los SKUs físicos escaneados de las piezas. Al coincidir, actualiza atómicamente la orden a 'Completada', los activos a 'Entregado' (ID 6) y libera el rack físico."
)
def escanear_salida(
    payload: EscanearSalidaRequest,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    token = payload.qr_transaccional_salida.strip()
    user_ident = f"{current_user.nombres} {current_user.apellidos} ({current_user.email})".strip()
    print(f"🚪 [BARRERA] Iniciando confirmación de entrega para token: '{token}' por: {user_ident}")

    orden = db.query(Orden_Venta).filter(Orden_Venta.qr_transaccional_salida == token).first()
    if not orden:
        print(f"⚠️ [BARRERA] Token QR '{token}' no encontrado.")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Código QR transaccional no encontrado o inválido."
        )

    # Validar sucursal
    if current_user.id_sucursal and orden.id_sucursal != current_user.id_sucursal:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"La orden pertenece a la sucursal {orden.id_sucursal}. No está autorizado para liberar órdenes de otra sucursal."
        )

    # Validaciones Poka-Yoke de estado
    if orden.estado_orden == "Anulada":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No se puede procesar la entrega. Esta orden fue 'Anulada'."
        )

    if orden.estado_orden == "Completada":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"La orden #{str(orden.id_orden)[:8].upper()} ya fue entregada anteriormente."
        )

    if orden.estado_orden != "Pagada" or orden.monto_pendiente > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"La orden #{str(orden.id_orden)[:8].upper()} no ha sido pagada en su totalidad (Saldo pendiente: ${orden.monto_pendiente})."
        )

    # 1. Obtener los activos físicos requeridos por la orden (ignorando ítems misceláneos/venta libre sin activo)
    detalles = db.query(Detalle_Orden).filter(Detalle_Orden.id_orden == orden.id_orden).all()
    activos_requeridos = []
    skus_requeridos_set = set()

    for d in detalles:
        if d.id_activo:
            act = db.query(Activo_Inventariado).filter(Activo_Inventariado.id_activo == d.id_activo).first()
            if act:
                activos_requeridos.append(act)
                skus_requeridos_set.add(act.sku_qr_fisico.strip().upper())

    # 2. Validación Poka-Yoke Dual-Scan Match
    # Si la orden tiene activos inventariados, todos sus SKUs deben haber sido escaneados
    skus_escaneados_normalizados = {sku.strip().upper() for sku in payload.skus_escaneados if sku and sku.strip()}

    if skus_requeridos_set:
        # A. Validar que no se hayan escaneado piezas que no pertenecen a esta orden
        skus_invalidos = skus_escaneados_normalizados - skus_requeridos_set
        if skus_invalidos:
            print(f"❌ [DUAL-SCAN] Error: Piezas no pertenecientes a la orden escaneadas: {skus_invalidos}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Las siguientes piezas escaneadas NO pertenecen a esta orden: {', '.join(skus_invalidos)}."
            )

        # B. Validar que todos los SKUs físicos requeridos estén presentes
        skus_faltantes = skus_requeridos_set - skus_escaneados_normalizados
        if skus_faltantes:
            print(f"❌ [DUAL-SCAN] Error: Faltan {len(skus_faltantes)} SKU(s) por escanear: {skus_faltantes}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Falta escanear el QR físico de {len(skus_faltantes)} pieza(s) para autorizar la salida: {', '.join(skus_faltantes)}."
            )

    try:
        # 3. Transacción ACID: Cierre de Orden y Ciclo de Inventario
        estado_entregado = db.query(Estado_Activo).filter(Estado_Activo.nombre_estado == "Entregado").first()
        if not estado_entregado:
            estado_entregado = Estado_Activo(id_estado=6, nombre_estado="Entregado")
            db.add(estado_entregado)
            db.flush()

        # A. Actualizar Orden_Venta a 'Completada'
        orden.estado_orden = "Completada"
        orden.fecha_actualizacion = datetime.now()

        # B. Actualizar cada Activo_Inventariado a 'Entregado' (ID 6) y liberar rack
        skus_entregados_nombres = []
        for act in activos_requeridos:
            act.id_estado = estado_entregado.id_estado
            act.ubicacion_pasillo = None
            act.ubicacion_pallet = None
            act.ubicacion_galpon = None
            act.observacion_estado = f"Entregado en barrera por {current_user.nombres} {current_user.apellidos} - Orden #{str(orden.id_orden)[:8].upper()}"
            act.version_lock = (act.version_lock or 1) + 1
            act.fecha_actualizacion = datetime.now()
            skus_entregados_nombres.append(act.sku_qr_fisico)
            print(f"📦 [ENTREGA] Activo '{act.sku_qr_fisico}' actualizado a 'Entregado' (ID {estado_entregado.id_estado}). Ubicación en rack liberada.")

        # C. Registrar trazabilidad forense en Auditoria_Barrera
        registro_auditoria = Auditoria_Barrera(
            id_auditoria=uuid.uuid4(),
            id_orden=orden.id_orden,
            id_bodeguero=current_user.id_usuario,
            fecha_escaneo=datetime.now(),
            match_exitoso=True,
        )
        db.add(registro_auditoria)

        # D. Confirmación atómica
        db.commit()
        db.refresh(orden)

        folio = f"ORD-{str(orden.id_orden)[:8].upper()}"
        print(f"✅ [BARRERA] Orden {folio} completada exitosamente. Total piezas entregadas: {len(skus_entregados_nombres)}.")

        return EscanearSalidaResponse(
            id_orden=orden.id_orden,
            folio=folio,
            estado_orden=orden.estado_orden,
            id_bodeguero=current_user.id_usuario,
            bodeguero_nombre=f"{current_user.nombres} {current_user.apellidos}".strip(),
            fecha_entrega=datetime.now().isoformat(),
            activos_entregados=skus_entregados_nombres,
            total_entregados=len(skus_entregados_nombres),
            mensaje="¡Entrega en barrera autorizada exitosamente! Orden completada y repuestos liberados del inventario.",
        )

    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error transaccional al procesar la salida en barrera: {str(e)}"
        )
