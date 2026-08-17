from datetime import datetime
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from sqlalchemy import func, or_, case
from typing import Dict, List, Optional

from database import get_db
from models import (
    Activo_Inventariado,
    Vehiculo_Origen,
    Detalle_Motor,
    Multimedia_Activo,
    Detalle_Caja_Cambio,
    Categoria_Activo,
    Estado_Activo,
    Sucursal,
    Usuario,
)
from core.security import get_current_user, verificar_rol_jefe_ventas
from schemas import (
    CatalogoItemResponse,
    PaginatedCatalogoResponse,
    ActivoPendientePrecioResponse,
    AsignarPrecioRequest,
    AsignarPrecioResponse,
)

router = APIRouter(prefix="/api/v1/inventario", tags=["Buscador Inventario"])


@router.get("/opciones-filtros", response_model=Dict[str, List[str]])
def obtener_opciones_filtros(
    categoria: Optional[str] = None,
    pasillo: Optional[str] = None,
    pallet: Optional[str] = None,
    marca: Optional[str] = None,
    modelo: Optional[str] = None,
    cilindrada: Optional[str] = None,
    combustible: Optional[str] = None,
    transmision: Optional[str] = None,
    db: Session = Depends(get_db),
    usuario_logeado: Usuario = Depends(get_current_user),
):
    # 1. Base idéntica a la del buscador (incluyendo joins y exclusión de estados)
    query = (
        db.query(Activo_Inventariado, Vehiculo_Origen, Detalle_Motor, Detalle_Caja_Cambio)
        .outerjoin(Vehiculo_Origen, Activo_Inventariado.id_vehiculo == Vehiculo_Origen.id_vehiculo)
        .outerjoin(Detalle_Motor, Activo_Inventariado.id_activo == Detalle_Motor.id_activo)
        .outerjoin(Detalle_Caja_Cambio, Activo_Inventariado.id_activo == Detalle_Caja_Cambio.id_activo)
    )

    # ⚠️ REGLA DE NEGOCIO: Filtrar únicamente repuestos físicamente en bodega (1: Disponible, 2: Reservado)
    query = query.filter(
        Activo_Inventariado.id_estado.in_([1, 2]),
        Activo_Inventariado.estado == "Activo",
    )

    # 2. Aplicamos los filtros actuales que el usuario ya seleccionó
    if categoria:
        cat_upper = categoria.upper()
        if cat_upper == "MOTORES":
            query = query.filter(Activo_Inventariado.id_categoria == 1)
        elif cat_upper == "CAJAS DE CAMBIO":
            query = query.filter(Activo_Inventariado.id_categoria == 2)
        elif cat_upper == "ACCESORIOS":
            query = query.filter(Activo_Inventariado.id_categoria == 3)

    if pasillo:
        query = query.filter(func.upper(Activo_Inventariado.ubicacion_pasillo) == pasillo.upper())
    if pallet:
        query = query.filter(func.upper(Activo_Inventariado.ubicacion_pallet) == pallet.upper())
    if marca:
        query = query.filter(func.upper(Vehiculo_Origen.marca) == marca.upper())
    if modelo:
        query = query.filter(func.upper(Vehiculo_Origen.modelo) == modelo.upper())
    if cilindrada:
        query = query.filter(func.upper(Detalle_Motor.cilindrada) == cilindrada.upper())
    if combustible:
        query = query.filter(func.upper(Detalle_Motor.combustible) == combustible.upper())
    if transmision:
        query = query.filter(
            (func.upper(Detalle_Motor.transmision_tipo) == transmision.upper())
            | (func.upper(Detalle_Caja_Cambio.transmision_tipo) == transmision.upper())
        )

    # 3. Extraemos las opciones ÚNICAS de lo que quedó después de filtrar
    marcas = query.with_entities(func.upper(Vehiculo_Origen.marca)).distinct().all()
    modelos = query.with_entities(func.upper(Vehiculo_Origen.modelo)).distinct().all()
    cilindradas = query.with_entities(func.upper(Detalle_Motor.cilindrada)).distinct().all()
    combustibles = query.with_entities(func.upper(Detalle_Motor.combustible)).distinct().all()
    pasillos = query.with_entities(func.upper(Activo_Inventariado.ubicacion_pasillo)).distinct().all()
    pallets = query.with_entities(func.upper(Activo_Inventariado.ubicacion_pallet)).distinct().all()

    trans_motor = query.with_entities(func.upper(Detalle_Motor.transmision_tipo)).distinct().all()
    trans_caja = query.with_entities(func.upper(Detalle_Caja_Cambio.transmision_tipo)).distinct().all()
    transmisiones = list(set(trans_motor + trans_caja))

    def limpiar_lista(query_result):
        return sorted(
            list(
                set([item[0] for item in query_result if item[0] is not None and str(item[0]).strip() != ""])
            )
        )

    return {
        "marcas": limpiar_lista(marcas),
        "modelos": limpiar_lista(modelos),
        "cilindradas": limpiar_lista(cilindradas),
        "combustibles": limpiar_lista(combustibles),
        "transmisiones": limpiar_lista(transmisiones),
        "pasillos": limpiar_lista(pasillos),
        "pallets": limpiar_lista(pallets),
    }


@router.get("/buscar")
def buscar_inventario(
    q: Optional[str] = Query(None, description="Texto libre para buscar por marca, modelo, SKU o N° Ingreso"),
    categoria: Optional[str] = None,
    pasillo: Optional[str] = None,
    pallet: Optional[str] = None,
    marca: Optional[str] = None,
    modelo: Optional[str] = None,
    cilindrada: Optional[str] = None,
    combustible: Optional[str] = None,
    transmision: Optional[str] = None,
    limit: Optional[int] = Query(None, ge=1, le=100, description="Límite de elementos por página"),
    offset: int = Query(0, ge=0, description="Desplazamiento para paginación"),
    db: Session = Depends(get_db),
    usuario_logeado: Usuario = Depends(get_current_user),
):
    query = (
        db.query(
            Activo_Inventariado,
            Vehiculo_Origen,
            Detalle_Motor,
            Detalle_Caja_Cambio,
            Categoria_Activo,
            Estado_Activo,
        )
        .outerjoin(Vehiculo_Origen, Activo_Inventariado.id_vehiculo == Vehiculo_Origen.id_vehiculo)
        .outerjoin(Detalle_Motor, Activo_Inventariado.id_activo == Detalle_Motor.id_activo)
        .outerjoin(Detalle_Caja_Cambio, Activo_Inventariado.id_activo == Detalle_Caja_Cambio.id_activo)
        .join(Categoria_Activo, Activo_Inventariado.id_categoria == Categoria_Activo.id_categoria)
        .join(Estado_Activo, Activo_Inventariado.id_estado == Estado_Activo.id_estado)
    )

    # ⚠️ REGLA DE NEGOCIO: Filtrar únicamente repuestos físicamente en bodega (1: Disponible, 2: Reservado)
    # Excluye explícitamente Entregado (4), Vendido (3) y De Baja / En Desarme (5)
    query = query.filter(
        Activo_Inventariado.id_estado.in_([1, 2]),
        Activo_Inventariado.estado == "Activo",
    )

    # Búsqueda por Texto Libre
    if q and q.strip():
        q_term = f"%{q.strip().upper()}%"
        query = query.filter(
            or_(
                func.upper(Activo_Inventariado.sku_qr_fisico).like(q_term),
                func.upper(Vehiculo_Origen.marca).like(q_term),
                func.upper(Vehiculo_Origen.modelo).like(q_term),
                func.upper(Vehiculo_Origen.numero_ingreso).like(q_term),
            )
        )

    # Filtro de Categoría
    if categoria:
        cat_upper = categoria.upper()
        if cat_upper == "MOTORES":
            query = query.filter(Activo_Inventariado.id_categoria == 1)
        elif cat_upper == "CAJAS DE CAMBIO":
            query = query.filter(Activo_Inventariado.id_categoria == 2)
        elif cat_upper == "ACCESORIOS":
            query = query.filter(Activo_Inventariado.id_categoria == 3)

    if pasillo:
        query = query.filter(func.upper(Activo_Inventariado.ubicacion_pasillo) == pasillo.upper())
    if pallet:
        query = query.filter(func.upper(Activo_Inventariado.ubicacion_pallet) == pallet.upper())
    if marca:
        query = query.filter(func.upper(Vehiculo_Origen.marca) == marca.upper())
    if modelo:
        query = query.filter(func.upper(Vehiculo_Origen.modelo) == modelo.upper())
    if cilindrada:
        query = query.filter(func.upper(Detalle_Motor.cilindrada) == cilindrada.upper())
    if combustible:
        query = query.filter(func.upper(Detalle_Motor.combustible) == combustible.upper())
    if transmision:
        query = query.filter(
            (func.upper(Detalle_Motor.transmision_tipo) == transmision.upper())
            | (func.upper(Detalle_Caja_Cambio.transmision_tipo) == transmision.upper())
        )

    query = query.order_by(Activo_Inventariado.fecha_creacion.desc())

    if limit is not None:
        query = query.offset(offset).limit(limit)

    resultados_db = query.all()

    # Obtener imágenes eficientemente en lote
    activo_ids = [activo.id_activo for activo, *_ in resultados_db]
    fotos_db = (
        db.query(Multimedia_Activo.id_activo, Multimedia_Activo.url_storage)
        .filter(Multimedia_Activo.id_activo.in_(activo_ids))
        .all()
    ) if activo_ids else []
    fotos_map: Dict[UUID, List[str]] = {}
    for act_id, url in fotos_db:
        fotos_map.setdefault(act_id, []).append(url)

    respuesta = []
    for activo, vehiculo, motor, caja, cat, est in resultados_db:
        lista_fotos = fotos_map.get(activo.id_activo, [])

        if cat.id_categoria == 2 and caja:
            transmision_val = caja.transmision_tipo
        elif motor:
            transmision_val = motor.transmision_tipo
        else:
            transmision_val = "N/A"

        respuesta.append(
            {
                "id_activo": str(activo.id_activo),
                "sku": activo.sku_qr_fisico,
                "qr_impreso": activo.qr_impreso if activo.qr_impreso is not None else False,
                "numero_ingreso": vehiculo.numero_ingreso if vehiculo else "N/A",
                "marca": vehiculo.marca if vehiculo else "Desconocida",
                "modelo": vehiculo.modelo if vehiculo else "Desconocido",
                "anio": vehiculo.anio if vehiculo else 0,
                "ubicacion": f"{activo.ubicacion_pasillo or 'S/P'} - {activo.ubicacion_pallet or 'S/P'}",
                "pasillo": activo.ubicacion_pasillo or "",
                "pallet": activo.ubicacion_pallet or "",
                "galpon": getattr(activo, "ubicacion_galpon", "") or "",
                "estado": est.nombre_estado,
                "categoria": cat.nombre_categoria,
                "cilindrada": motor.cilindrada if motor else "N/A",
                "combustible": motor.combustible if motor else "N/A",
                "transmision": transmision_val or "N/A",
                "numero_motor": motor.numero_motor if motor else None,
                "observacion": getattr(activo, "observacion_estado", "Sin observaciones registradas."),
                "imagenes": lista_fotos,
            }
        )

    return respuesta


@router.get("/catalogo", response_model=PaginatedCatalogoResponse)
def obtener_catalogo(
    q: Optional[str] = Query(None, description="Texto libre para buscar por marca, modelo o SKU"),
    id_categoria: Optional[int] = Query(None, description="Filtro por ID de categoría"),
    id_sucursal: Optional[int] = Query(None, description="Filtro explícito por ID de sucursal"),
    marca: Optional[str] = Query(None, description="Filtro por marca"),
    anio: Optional[int] = Query(None, description="Filtro por año"),
    cilindrada: Optional[str] = Query(None, description="Filtro por cilindrada"),
    transmision: Optional[str] = Query(None, description="Filtro por tipo de transmisión"),
    limit: int = Query(15, ge=1, le=100, description="Límite de elementos por página"),
    offset: int = Query(0, ge=0, description="Desplazamiento para paginación"),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    query = (
        db.query(
            Activo_Inventariado,
            Vehiculo_Origen,
            Categoria_Activo,
            Estado_Activo,
            Sucursal,
            Detalle_Motor,
            Detalle_Caja_Cambio,
        )
        .outerjoin(Vehiculo_Origen, Activo_Inventariado.id_vehiculo == Vehiculo_Origen.id_vehiculo)
        .join(Categoria_Activo, Activo_Inventariado.id_categoria == Categoria_Activo.id_categoria)
        .join(Estado_Activo, Activo_Inventariado.id_estado == Estado_Activo.id_estado)
        .join(Sucursal, Activo_Inventariado.id_sucursal_actual == Sucursal.id_sucursal)
        .outerjoin(Detalle_Motor, Activo_Inventariado.id_activo == Detalle_Motor.id_activo)
        .outerjoin(Detalle_Caja_Cambio, Activo_Inventariado.id_activo == Detalle_Caja_Cambio.id_activo)
    )

    # Filtros Base de catálogo
    query = query.filter(
        Activo_Inventariado.estado == "Activo",
        Activo_Inventariado.id_estado == 1,
        Estado_Activo.nombre_estado == "Disponible",
        Activo_Inventariado.precio_referencia.isnot(None),
        Activo_Inventariado.precio_referencia > 0,
    )

    if id_categoria is not None:
        query = query.filter(Activo_Inventariado.id_categoria == id_categoria)

    if id_sucursal is not None:
        query = query.filter(Activo_Inventariado.id_sucursal_actual == id_sucursal)

    if marca and marca.strip():
        query = query.filter(func.upper(Vehiculo_Origen.marca) == marca.strip().upper())

    if anio is not None:
        query = query.filter(Vehiculo_Origen.anio == anio)

    if cilindrada and cilindrada.strip():
        cil_clean = cilindrada.strip().upper().replace("L", "").strip()
        query = query.filter(func.upper(Detalle_Motor.cilindrada).like(f"%{cil_clean}%"))

    if transmision and transmision.strip():
        trans_clean = transmision.strip().upper()
        if "MEC" in trans_clean or "MAN" in trans_clean:
            query = query.filter(
                or_(
                    func.upper(Detalle_Motor.transmision_tipo).like("%MAN%"),
                    func.upper(Detalle_Motor.transmision_tipo).like("%MEC%"),
                    func.upper(Detalle_Caja_Cambio.transmision_tipo).like("%MAN%"),
                    func.upper(Detalle_Caja_Cambio.transmision_tipo).like("%MEC%"),
                )
            )
        elif "AUT" in trans_clean:
            query = query.filter(
                or_(
                    func.upper(Detalle_Motor.transmision_tipo).like("%AUT%"),
                    func.upper(Detalle_Caja_Cambio.transmision_tipo).like("%AUT%"),
                )
            )
        else:
            trans_term = f"%{trans_clean}%"
            query = query.filter(
                or_(
                    func.upper(Detalle_Motor.transmision_tipo).like(trans_term),
                    func.upper(Detalle_Caja_Cambio.transmision_tipo).like(trans_term),
                )
            )

    if q and q.strip():
        q_term = f"%{q.strip().upper()}%"
        query = query.filter(
            or_(
                func.upper(Activo_Inventariado.sku_qr_fisico).like(q_term),
                func.upper(Vehiculo_Origen.marca).like(q_term),
                func.upper(Vehiculo_Origen.modelo).like(q_term),
            )
        )

    total_count = query.count()

    if id_sucursal is None and getattr(current_user, "id_sucursal", None) is not None:
        radar_order = case(
            (Activo_Inventariado.id_sucursal_actual == current_user.id_sucursal, 1),
            else_=0,
        ).desc()
        query = query.order_by(radar_order, Activo_Inventariado.fecha_creacion.desc())
    else:
        query = query.order_by(Activo_Inventariado.fecha_creacion.desc())

    resultados = query.offset(offset).limit(limit).all()

    activo_ids = [activo.id_activo for activo, *_ in resultados]
    fotos_db = (
        db.query(Multimedia_Activo.id_activo, Multimedia_Activo.url_storage)
        .filter(Multimedia_Activo.id_activo.in_(activo_ids))
        .all()
    ) if activo_ids else []
    fotos_map: Dict[UUID, List[str]] = {}
    for act_id, url in fotos_db:
        fotos_map.setdefault(act_id, []).append(url)

    items: List[CatalogoItemResponse] = []
    for activo, vehiculo, cat, est, suc, motor, caja in resultados:
        cilindrada_val = None
        combustible_val = None
        transmision_val = None

        if cat.id_categoria == 1 and motor:
            cilindrada_val = motor.cilindrada
            combustible_val = motor.combustible
            transmision_val = motor.transmision_tipo
        elif cat.id_categoria == 2 and caja:
            transmision_val = caja.transmision_tipo
        else:
            if motor:
                cilindrada_val = motor.cilindrada
                combustible_val = motor.combustible
                transmision_val = motor.transmision_tipo
            elif caja:
                transmision_val = caja.transmision_tipo

        item = CatalogoItemResponse(
            id_activo=activo.id_activo,
            sku_qr_fisico=activo.sku_qr_fisico,
            precio_referencia=activo.precio_referencia,
            id_categoria=cat.id_categoria,
            nombre_categoria=cat.nombre_categoria,
            id_sucursal_actual=suc.id_sucursal,
            nombre_sucursal=suc.nombre_sucursal,
            id_vehiculo=vehiculo.id_vehiculo if vehiculo else None,
            marca=vehiculo.marca if vehiculo else None,
            modelo=vehiculo.modelo if vehiculo else None,
            anio=vehiculo.anio if vehiculo else None,
            traccion=vehiculo.traccion if vehiculo else None,
            cilindrada=cilindrada_val,
            combustible=combustible_val,
            transmision_tipo=transmision_val,
            ubicacion_pasillo=activo.ubicacion_pasillo,
            ubicacion_pallet=activo.ubicacion_pallet,
            estado_activo=est.nombre_estado,
            qr_impreso=activo.qr_impreso if activo.qr_impreso is not None else False,
            imagenes=fotos_map.get(activo.id_activo, []),
        )
        items.append(item)

    return PaginatedCatalogoResponse(
        items=items,
        total_count=total_count,
        limit=limit,
        offset=offset,
    )


# =============================================================================
# ENDPOINTS PARA JEFE DE VENTAS: ASIGNACIÓN DE PRECIOS (HU-3.8)
# =============================================================================

@router.get(
    "/pendientes-precio",
    response_model=List[ActivoPendientePrecioResponse],
    summary="Bandeja de Entrada de Activos Pendientes de Precio (HU-3.8)",
    description="Consulta todos los activos inventariados/paletizados por bodega que tienen "
                "precio_referencia nulo o igual a 0. Requiere rol de Jefe de Ventas (id_rol == 6).",
)
def obtener_pendientes_precio(
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(verificar_rol_jefe_ventas),
):
    query = (
        db.query(
            Activo_Inventariado,
            Vehiculo_Origen,
            Categoria_Activo,
            Estado_Activo,
            Sucursal,
            Detalle_Motor,
            Detalle_Caja_Cambio,
        )
        .outerjoin(Vehiculo_Origen, Activo_Inventariado.id_vehiculo == Vehiculo_Origen.id_vehiculo)
        .join(Categoria_Activo, Activo_Inventariado.id_categoria == Categoria_Activo.id_categoria)
        .join(Estado_Activo, Activo_Inventariado.id_estado == Estado_Activo.id_estado)
        .join(Sucursal, Activo_Inventariado.id_sucursal_actual == Sucursal.id_sucursal)
        .outerjoin(Detalle_Motor, Activo_Inventariado.id_activo == Detalle_Motor.id_activo)
        .outerjoin(Detalle_Caja_Cambio, Activo_Inventariado.id_activo == Detalle_Caja_Cambio.id_activo)
        .filter(
            Activo_Inventariado.estado == "Activo",
            or_(
                Activo_Inventariado.precio_referencia == None,
                Activo_Inventariado.precio_referencia == 0,
            ),
            Activo_Inventariado.ubicacion_pasillo.isnot(None),
            Activo_Inventariado.ubicacion_pasillo != "",
            Activo_Inventariado.ubicacion_pallet.isnot(None),
            Activo_Inventariado.ubicacion_pallet != "",
            Activo_Inventariado.id_estado.notin_([1, 3, 4, 5]),
            Estado_Activo.nombre_estado.notin_(["Disponible", "Vendido", "En Importación", "En Desarme"]),
        )
        .order_by(Activo_Inventariado.fecha_creacion.desc())
    )

    resultados = query.all()

    respuesta: List[ActivoPendientePrecioResponse] = []
    for activo, vehiculo, cat, est, suc, motor, caja in resultados:
        cilindrada_val = None
        combustible_val = None
        transmision_val = None

        if cat.id_categoria == 1 and motor:
            cilindrada_val = motor.cilindrada
            combustible_val = motor.combustible
            transmision_val = motor.transmision_tipo
        elif cat.id_categoria == 2 and caja:
            transmision_val = caja.transmision_tipo
        else:
            if motor:
                cilindrada_val = motor.cilindrada
                combustible_val = motor.combustible
                transmision_val = motor.transmision_tipo
            elif caja:
                transmision_val = caja.transmision_tipo

        nombre_cat = cat.nombre_categoria if cat else "Repuesto"
        if vehiculo:
            titulo = f"{nombre_cat} - {vehiculo.marca} {vehiculo.modelo} {vehiculo.anio or ''}".strip()
        else:
            titulo = f"{nombre_cat} ({activo.sku_qr_fisico})"

        item = ActivoPendientePrecioResponse(
            id_activo=activo.id_activo,
            sku_qr_fisico=activo.sku_qr_fisico,
            id_categoria=cat.id_categoria,
            nombre_categoria=cat.nombre_categoria,
            id_sucursal_actual=suc.id_sucursal,
            nombre_sucursal=suc.nombre_sucursal,
            ubicacion_pasillo=activo.ubicacion_pasillo,
            ubicacion_pallet=activo.ubicacion_pallet,
            id_vehiculo=vehiculo.id_vehiculo if vehiculo else None,
            numero_ingreso=vehiculo.numero_ingreso if vehiculo else None,
            marca=vehiculo.marca if vehiculo else None,
            modelo=vehiculo.modelo if vehiculo else None,
            anio=vehiculo.anio if vehiculo else None,
            traccion=vehiculo.traccion if vehiculo else None,
            cilindrada=cilindrada_val,
            combustible=combustible_val,
            transmision_tipo=transmision_val,
            titulo_repuesto=titulo,
            estado_activo=est.nombre_estado,
            fecha_creacion=activo.fecha_creacion.isoformat() if activo.fecha_creacion else None,
        )
        respuesta.append(item)

    return respuesta


@router.patch(
    "/{id_activo}/precio",
    response_model=AsignarPrecioResponse,
    summary="Asignar Precio de Referencia a Repuesto (HU-3.8)",
    description="Fija el precio_referencia de un repuesto y actualiza su estado automáticamente "
                "a 'Disponible' para habilitar su venta en el catálogo. Requiere rol Jefe de Ventas.",
)
def asignar_precio_repuesto(
    id_activo: UUID,
    payload: AsignarPrecioRequest,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(verificar_rol_jefe_ventas),
):
    activo = db.query(Activo_Inventariado).filter(Activo_Inventariado.id_activo == id_activo).first()
    if not activo:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Repuesto inventariado con ID '{id_activo}' no encontrado.",
        )

    activo.precio_referencia = payload.precio_referencia
    activo.fecha_actualizacion = datetime.now()

    estado_disponible = db.query(Estado_Activo).filter(Estado_Activo.nombre_estado == "Disponible").first()
    if not estado_disponible:
        estado_disponible = Estado_Activo(id_estado=1, nombre_estado="Disponible")
        db.add(estado_disponible)
        db.flush()

    activo.id_estado = estado_disponible.id_estado
    activo.version_lock = (activo.version_lock or 1) + 1

    db.commit()
    db.refresh(activo)

    return AsignarPrecioResponse(
        id_activo=activo.id_activo,
        sku_qr_fisico=activo.sku_qr_fisico,
        precio_referencia=activo.precio_referencia,
        estado_activo="Disponible",
        mensaje="Precio asignado exitosamente. El repuesto ahora está disponible en el catálogo de ventas.",
    )


@router.get(
    "/{id_activo}",
    response_model=CatalogoItemResponse,
    summary="Detalle Completo de Activo con Imágenes",
)
def obtener_detalle_activo(
    id_activo: UUID,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    resultado = (
        db.query(
            Activo_Inventariado,
            Vehiculo_Origen,
            Categoria_Activo,
            Estado_Activo,
            Sucursal,
            Detalle_Motor,
            Detalle_Caja_Cambio,
        )
        .outerjoin(Vehiculo_Origen, Activo_Inventariado.id_vehiculo == Vehiculo_Origen.id_vehiculo)
        .join(Categoria_Activo, Activo_Inventariado.id_categoria == Categoria_Activo.id_categoria)
        .join(Estado_Activo, Activo_Inventariado.id_estado == Estado_Activo.id_estado)
        .join(Sucursal, Activo_Inventariado.id_sucursal_actual == Sucursal.id_sucursal)
        .outerjoin(Detalle_Motor, Activo_Inventariado.id_activo == Detalle_Motor.id_activo)
        .outerjoin(Detalle_Caja_Cambio, Activo_Inventariado.id_activo == Detalle_Caja_Cambio.id_activo)
        .filter(Activo_Inventariado.id_activo == id_activo)
        .first()
    )

    if not resultado:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Activo inventariado con ID '{id_activo}' no encontrado.",
        )

    activo, vehiculo, cat, est, suc, motor, caja = resultado

    cilindrada_val = None
    combustible_val = None
    transmision_val = None

    if cat.id_categoria == 1 and motor:
        cilindrada_val = motor.cilindrada
        combustible_val = motor.combustible
        transmision_val = motor.transmision_tipo
    elif cat.id_categoria == 2 and caja:
        transmision_val = caja.transmision_tipo
    else:
        if motor:
            cilindrada_val = motor.cilindrada
            combustible_val = motor.combustible
            transmision_val = motor.transmision_tipo
        elif caja:
            transmision_val = caja.transmision_tipo

    fotos_db = (
        db.query(Multimedia_Activo.url_storage)
        .filter(Multimedia_Activo.id_activo == activo.id_activo)
        .all()
    )
    lista_fotos = [f[0] for f in fotos_db] if fotos_db else []

    return CatalogoItemResponse(
        id_activo=activo.id_activo,
        sku_qr_fisico=activo.sku_qr_fisico,
        precio_referencia=activo.precio_referencia,
        id_categoria=cat.id_categoria,
        nombre_categoria=cat.nombre_categoria,
        id_sucursal_actual=suc.id_sucursal,
        nombre_sucursal=suc.nombre_sucursal,
        id_vehiculo=vehiculo.id_vehiculo if vehiculo else None,
        marca=vehiculo.marca if vehiculo else None,
        modelo=vehiculo.modelo if vehiculo else None,
        anio=vehiculo.anio if vehiculo else None,
        traccion=vehiculo.traccion if vehiculo else None,
        cilindrada=cilindrada_val,
        combustible=combustible_val,
        transmision_tipo=transmision_val,
        ubicacion_pasillo=activo.ubicacion_pasillo,
        ubicacion_pallet=activo.ubicacion_pallet,
        estado_activo=est.nombre_estado,
        qr_impreso=activo.qr_impreso if activo.qr_impreso is not None else False,
        imagenes=lista_fotos,
    )