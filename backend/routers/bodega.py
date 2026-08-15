from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
import uuid

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
)
from schemas import (
    VerificarQrSalidaRequest,
    VerificarQrSalidaResponse,
    ItemSalidaInfo,
    EscanearSalidaRequest,
    EscanearSalidaResponse,
)
from core.security import get_current_user

router = APIRouter(prefix="/api/v1/bodega", tags=["Tablero Operativo"])


class TareaAlerta(BaseModel):
    id_tarea: str
    tipo_alerta: str
    orden_ref: Optional[str] = None
    titulo_pieza: str
    ubicacion: str
    nota_especial: Optional[str] = None
    estado_bloqueo: Optional[str] = None
    accion_requerida: str
    etiqueta_data: Optional[dict] = None


@router.get("/tareas-pendientes", response_model=List[TareaAlerta])
def obtener_tareas_pendientes(
    # Recibimos la sucursal como parámetro (por defecto 1 para pruebas)
    sucursal_id: int = Query(1, description="ID de la sucursal del bodeguero"),
    db: Session = Depends(get_db),
    usuario_logeado: Usuario = Depends(get_current_user)
):
    alertas = []

    # ---------------------------------------------------------
    # REGLA 1: Pendiente de Impresión (FILTRADO POR SUCURSAL)
    # ---------------------------------------------------------
    activos_sin_qr = db.query(
        Activo_Inventariado, Vehiculo_Origen, Detalle_Motor, Detalle_Caja_Cambio
    ).join(
        Vehiculo_Origen, Activo_Inventariado.id_vehiculo == Vehiculo_Origen.id_vehiculo
    ).outerjoin(
        Detalle_Motor, Activo_Inventariado.id_activo == Detalle_Motor.id_activo
    ).outerjoin(
        Detalle_Caja_Cambio, Activo_Inventariado.id_activo == Detalle_Caja_Cambio.id_activo
    ).filter(
        Activo_Inventariado.qr_impreso == False,
        Activo_Inventariado.estado == 'Activo',
        Activo_Inventariado.id_sucursal_actual == sucursal_id
    ).all()

    for activo, vehiculo, motor, caja in activos_sin_qr:
        if activo.id_categoria == 2 and caja:
            transmision_val = caja.transmision_tipo
        elif motor:
            transmision_val = motor.transmision_tipo
        else:
            transmision_val = None

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

        alertas.append({
            "id_tarea": f"IMP-{str(activo.id_activo)[:8]}",
            "tipo_alerta": "IMPRESION",
            "titulo_pieza": f"Repuesto de {vehiculo.marca} {vehiculo.modelo}",
            "ubicacion": f"{activo.ubicacion_pasillo or 'S/P'} - {activo.ubicacion_pallet or 'S/P'}",
            "nota_especial": "GENERAR Y PEGAR ETIQUETA QR",
            "accion_requerida": "GENERAR QR AHORA",
            "etiqueta_data": etiqueta_data
        })

    # ---------------------------------------------------------
    # REGLAS 2 Y 3: Preparación y Liberación (FILTRADO POR SUCURSAL)
    # ---------------------------------------------------------
    detalles_orden = db.query(Detalle_Orden, Orden_Venta, Activo_Inventariado, Vehiculo_Origen).join(
        Orden_Venta, Detalle_Orden.id_orden == Orden_Venta.id_orden
    ).join(
        Activo_Inventariado, Detalle_Orden.id_activo == Activo_Inventariado.id_activo
    ).join(
        Vehiculo_Origen, Activo_Inventariado.id_vehiculo == Vehiculo_Origen.id_vehiculo
    ).filter(
        Orden_Venta.estado_orden.in_(["Reservada", "Pagada"]),
        Activo_Inventariado.id_sucursal_actual == sucursal_id
    ).all()

    for detalle, orden, activo, vehiculo in detalles_orden:
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


# ==============================================================================
# ENDPOINTS PARA HANDSHAKE TRANSACCIONAL Y DUAL-SCAN EN SALIDA (HU-3.6)
# ==============================================================================

@router.post(
    "/verificar-qr-salida",
    response_model=VerificarQrSalidaResponse,
    summary="Verificar Ticket Digital QR para Salida de Bodega",
    description="Permite al bodeguero escanear el QR del vendedor para consultar la orden, cliente y repuestos requeridos para despacho."
)
def verificar_qr_salida(
    payload: VerificarQrSalidaRequest,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    token = payload.qr_transaccional_salida.strip()
    user_ident = f"{current_user.nombres} {current_user.apellidos} ({current_user.email})".strip()
    print(f"🚪 [BARRERA] Verificando token QR de salida: '{token}' por: {user_ident}")

    orden = db.query(Orden_Venta).filter(Orden_Venta.qr_transaccional_salida == token).first()
    if not orden:
        print(f"⚠️ [BARRERA] Token QR '{token}' no encontrado en la base de datos.")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Código QR transaccional no encontrado o inválido."
        )

    # Validar sucursal
    if current_user.id_sucursal and orden.id_sucursal != current_user.id_sucursal:
        print(f"⚠️ [BARRERA] Sucursal incorrecta: Bodeguero sucursal {current_user.id_sucursal}, Orden sucursal {orden.id_sucursal}")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"La orden #{str(orden.id_orden)[:8].upper()} pertenece a la sucursal {orden.id_sucursal}, no a su sucursal asignada ({current_user.id_sucursal})."
        )

    # Validaciones Poka-Yoke de estado
    if orden.estado_orden == "Anulada":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No se puede procesar la salida. Esta orden fue 'Anulada' y sus repuestos liberados."
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
            detail=f"La orden #{str(orden.id_orden)[:8].upper()} ya fue entregada y completada anteriormente."
        )

    if orden.estado_orden != "Pagada" or orden.monto_pendiente > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"No se puede entregar. La orden #{str(orden.id_orden)[:8].upper()} no ha sido pagada en caja (Saldo pendiente: ${orden.monto_pendiente})."
        )

    # 1. Obtener detalles y filtrar piezas físicas inventariadas (Regla Cero-Clics: ignora ítems misceláneos/venta libre)
    detalles = db.query(Detalle_Orden).filter(Detalle_Orden.id_orden == orden.id_orden).all()
    activos_requeridos = []
    mapa_skus_esperados = {}

    for d in detalles:
        if d.id_activo:
            act = db.query(Activo_Inventariado).filter(Activo_Inventariado.id_activo == d.id_activo).first()
            if act:
                activos_requeridos.append(act)
                mapa_skus_esperados[act.sku_qr_fisico.strip().upper()] = act

    # 2. Validación de Doble Llave (Dual-Scan Match)
    skus_ingresados = {s.strip().upper() for s in payload.skus_escaneados if s and s.strip()}
    skus_esperados = set(mapa_skus_esperados.keys())

    if skus_esperados:
        # Poka-Yoke A: Validar si se escaneó un SKU que no corresponde a la orden
        skus_invalidos = skus_ingresados - skus_esperados
        if skus_invalidos:
            sku_err = list(skus_invalidos)[0]
            print(f"❌ [DUAL-SCAN] Error: SKU ajeno '{sku_err}' escaneado para orden #{str(orden.id_orden)[:8].upper()}.")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"El repuesto con SKU '{sku_err}' no pertenece a esta orden. Verifique la pieza física."
            )

        # Poka-Yoke B: Validar si faltan piezas físicas por escanear
        skus_faltantes = skus_esperados - skus_ingresados
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