# Router Transaccional de Órdenes de Venta (HU-3.4)
# Expone el endpoint POST /api/v1/ordenes para consolidar ventas del Carrito Híbrido,
# registrar datos de Micro-CRM, gestionar despacho y asegurar la consistencia ACID del inventario.

import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db
from models import (
    Usuario, Cliente, Comuna, Orden_Venta, Detalle_Orden,
    Despacho, Activo_Inventariado, Estado_Activo
)
from schemas import OrdenCreateRequest, OrdenResponse
from core.security import get_current_user

router = APIRouter(
    prefix="/api/v1/ordenes",
    tags=["Órdenes de Venta"]
)


@router.post(
    "",
    response_model=OrdenResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear Orden de Venta Transaccional (ACID)",
    description="Procesa la orden de venta desde el carrito de compras. "
                "Registra cliente, cabecera de orden, despacho, detalle y "
                "reserva los repuestos inventariados en una transacción atómica."
)
@router.post(
    "/",
    response_model=OrdenResponse,
    status_code=status.HTTP_201_CREATED,
    include_in_schema=False
)
def crear_orden(
    orden_in: OrdenCreateRequest,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    """
    Motor Transaccional de Creación de Órdenes:
    1. Validaciones previas de negocio (Consentimiento, ítems, despacho, stock disponible).
    2. Transacción ACID:
       - Paso A.1: Upsert / Registro del Cliente (Micro-CRM).
       - Paso A.2: Inserción de la Cabecera de Orden_Venta (estado='Reservada').
       - Paso A.3: Inserción de Despacho (si requiere_despacho == True).
       - Paso B: Inserción de líneas en Detalle_Orden (con notas de preparación para bodega).
       - Paso C: Actualización atómica de Activo_Inventariado a estado 'Reservado'.
    3. Rollback inmediato ante cualquier fallo.
    """
    # ── 1. Validaciones Previas de Negocio ──────────────────────────────────
    if not orden_in.consentimiento_legal:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El consentimiento expreso para tratamiento de datos (Ley N° 21.719) es obligatorio."
        )

    if not orden_in.items or len(orden_in.items) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La orden debe contener al menos un ítem o repuesto."
        )

    if orden_in.requiere_despacho and not orden_in.despacho:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Debe proporcionar los datos de despacho si 'requiere_despacho' está activado."
        )

    # Calcular monto total
    total_calculado = sum(item.precio_final * item.cantidad for item in orden_in.items)
    if total_calculado <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El monto total de la orden debe ser mayor a $0."
        )

    # Validar disponibilidad de repuestos inventariados antes de iniciar escritura
    for item in orden_in.items:
        if item.id_activo:
            activo_db = (
                db.query(Activo_Inventariado, Estado_Activo)
                .join(Estado_Activo, Activo_Inventariado.id_estado == Estado_Activo.id_estado)
                .filter(Activo_Inventariado.id_activo == item.id_activo)
                .first()
            )
            if not activo_db:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"El repuesto inventariado con ID '{item.id_activo}' no existe en el sistema."
                )

            activo, estado = activo_db
            if activo.estado != "Activo" or estado.nombre_estado != "Disponible":
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"El repuesto '{activo.sku_qr_fisico}' no está disponible para venta. "
                           f"Estado actual: {estado.nombre_estado}."
                )

    # ── 2. Bloque Transaccional ACID ─────────────────────────────────────────
    try:
        # ── Paso A.1: Gestión de Cliente (Upsert / Find or Create) ───────────
        rut_limpio = orden_in.cliente.rut_cliente.strip()
        cliente = db.query(Cliente).filter(Cliente.rut_cliente == rut_limpio).first()

        id_comuna_cliente = None
        if orden_in.cliente.comuna:
            comuna_obj = (
                db.query(Comuna)
                .filter(Comuna.nombre_comuna.ilike(orden_in.cliente.comuna.strip()))
                .first()
            )
            if comuna_obj:
                id_comuna_cliente = comuna_obj.id_comuna

        if not cliente:
            cliente = Cliente(
                rut_cliente=rut_limpio,
                nombres=orden_in.cliente.nombres.strip(),
                apellidos=orden_in.cliente.apellidos.strip(),
                telefono=orden_in.cliente.telefono.strip() if orden_in.cliente.telefono else None,
                correo=orden_in.cliente.correo.strip() if orden_in.cliente.correo else None,
                id_comuna=id_comuna_cliente,
                consentimiento_legal=orden_in.consentimiento_legal,
                estado="Activo"
            )
            db.add(cliente)
            db.flush()
        else:
            # Actualizar datos de contacto más recientes
            cliente.nombres = orden_in.cliente.nombres.strip()
            cliente.apellidos = orden_in.cliente.apellidos.strip()
            if orden_in.cliente.telefono:
                cliente.telefono = orden_in.cliente.telefono.strip()
            if orden_in.cliente.correo:
                cliente.correo = orden_in.cliente.correo.strip()
            if id_comuna_cliente:
                cliente.id_comuna = id_comuna_cliente
            cliente.consentimiento_legal = orden_in.consentimiento_legal
            db.flush()

        # ── Paso A.2: Cabecera Orden_Venta ──────────────────────────────────
        id_sucursal_orden = orden_in.id_sucursal or getattr(current_user, 'id_sucursal', 1) or 1
        qr_salida = f"ORD-{uuid.uuid4().hex[:8].upper()}"

        nueva_orden = Orden_Venta(
            id_cliente=cliente.id_cliente,
            id_vendedor=current_user.id_usuario,
            id_sucursal=id_sucursal_orden,
            estado_orden="Reservada",
            qr_transaccional_salida=qr_salida,
            total_venta=total_calculado,
            monto_pendiente=total_calculado,
        )
        db.add(nueva_orden)
        db.flush()

        # ── Paso A.3: Despacho (si aplica) ───────────────────────────────────
        if orden_in.requiere_despacho and orden_in.despacho:
            id_comuna_dest = orden_in.despacho.id_comuna_destino
            if not id_comuna_dest and orden_in.despacho.comuna_destino:
                comuna_dest_obj = (
                    db.query(Comuna)
                    .filter(Comuna.nombre_comuna.ilike(orden_in.despacho.comuna_destino.strip()))
                    .first()
                )
                if comuna_dest_obj:
                    id_comuna_dest = comuna_dest_obj.id_comuna

            if not id_comuna_dest:
                # Default a la primera comuna disponible o 1
                comuna_fallback = db.query(Comuna).first()
                id_comuna_dest = comuna_fallback.id_comuna if comuna_fallback else 1

            despacho = Despacho(
                id_orden=nueva_orden.id_orden,
                id_comuna_destino=id_comuna_dest,
                direccion_envio=orden_in.despacho.direccion_envio.strip(),
                receptor_nombres=orden_in.despacho.receptor_nombres.strip(),
                receptor_rut=orden_in.despacho.receptor_rut.strip(),
                receptor_telefono=orden_in.despacho.receptor_telefono.strip(),
                empresa_transporte=orden_in.despacho.empresa_transporte,
                costo_envio=orden_in.despacho.costo_envio or 0,
                estado_despacho="Por Enviar",
                estado="Activo"
            )
            db.add(despacho)
            db.flush()

        # ── Paso B: Líneas en Detalle_Orden & Paso C: Update Activos ─────────
        estado_reservado = db.query(Estado_Activo).filter(Estado_Activo.nombre_estado == "Reservado").first()
        if not estado_reservado:
            estado_reservado = Estado_Activo(nombre_estado="Reservado")
            db.add(estado_reservado)
            db.flush()

        for item in orden_in.items:
            nota_final = item.notas_preparacion or orden_in.instrucciones_bodega

            detalle = Detalle_Orden(
                id_orden=nueva_orden.id_orden,
                id_activo=item.id_activo,
                descripcion_manual=item.descripcion_manual,
                notas_preparacion=nota_final,
                cantidad=item.cantidad,
                precio_unitario=item.precio_unitario or item.precio_final,
                precio_final=item.precio_final,
            )
            db.add(detalle)

            # Paso C: Bloquear y actualizar estado de repuesto inventariado
            if item.id_activo:
                activo = (
                    db.query(Activo_Inventariado)
                    .filter(Activo_Inventariado.id_activo == item.id_activo)
                    .first()
                )
                if activo:
                    activo.id_estado = estado_reservado.id_estado
                    activo.version_lock = (activo.version_lock or 1) + 1

        # ── 3. Commit Transaccional Atómico ─────────────────────────────────
        db.commit()
        db.refresh(nueva_orden)

        return OrdenResponse(
            id_orden=nueva_orden.id_orden,
            estado_orden=nueva_orden.estado_orden,
            total_venta=nueva_orden.total_venta,
            monto_pendiente=nueva_orden.monto_pendiente,
            qr_transaccional_salida=nueva_orden.qr_transaccional_salida,
            mensaje="Orden de venta generada exitosamente y derivada a caja.",
            fecha_creacion=nueva_orden.fecha_creacion.isoformat() if nueva_orden.fecha_creacion else None,
            total_items=len(orden_in.items),
        )

    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error en la transacción de creación de la orden: {str(e)}"
        )


@router.get(
    "/{id_orden}",
    summary="Obtener Detalle de Orden de Venta",
    description="Consulta la información de una orden específica por su UUID."
)
def obtener_orden(
    id_orden: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    orden = db.query(Orden_Venta).filter(Orden_Venta.id_orden == id_orden).first()
    if not orden:
        raise HTTPException(status_code=404, detail="Orden no encontrada")

    cliente = db.query(Cliente).filter(Cliente.id_cliente == orden.id_cliente).first()
    detalles = db.query(Detalle_Orden).filter(Detalle_Orden.id_orden == id_orden).all()
    despacho = db.query(Despacho).filter(Despacho.id_orden == id_orden).first()

    return {
        "id_orden": orden.id_orden,
        "estado_orden": orden.estado_orden,
        "total_venta": orden.total_venta,
        "monto_pendiente": orden.monto_pendiente,
        "qr_transaccional_salida": orden.qr_transaccional_salida,
        "fecha_creacion": orden.fecha_creacion.isoformat() if orden.fecha_creacion else None,
        "cliente": {
            "rut": cliente.rut_cliente if cliente else None,
            "nombres": cliente.nombres if cliente else None,
            "apellidos": cliente.apellidos if cliente else None,
            "telefono": cliente.telefono if cliente else None,
        } if cliente else None,
        "despacho": {
            "direccion_envio": despacho.direccion_envio,
            "receptor_nombres": despacho.receptor_nombres,
            "receptor_rut": despacho.receptor_rut,
            "receptor_telefono": despacho.receptor_telefono,
            "estado_despacho": despacho.estado_despacho,
        } if despacho else None,
        "detalles": [
            {
                "id_detalle": d.id_detalle,
                "id_activo": d.id_activo,
                "descripcion_manual": d.descripcion_manual,
                "notas_preparacion": d.notas_preparacion,
                "cantidad": d.cantidad,
                "precio_unitario": d.precio_unitario,
                "precio_final": d.precio_final,
            }
            for d in detalles
        ],
    }
