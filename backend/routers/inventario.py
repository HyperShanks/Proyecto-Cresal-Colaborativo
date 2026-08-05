from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import Dict, List, Optional

from database import get_db
from models import Activo_Inventariado, Vehiculo_Origen, Detalle_Motor, Multimedia_Activo, Detalle_Caja_Cambio, Categoria_Activo, Estado_Activo

router = APIRouter(prefix="/api/v1/inventario", tags=["Buscador Inventario"])

@router.get("/opciones-filtros", response_model=Dict[str, List[str]])
def obtener_opciones_filtros(db: Session = Depends(get_db)):
    # 1. Extraer marcas y modelos únicos
    marcas = db.query(func.upper(Vehiculo_Origen.marca)).distinct().all()
    modelos = db.query(func.upper(Vehiculo_Origen.modelo)).distinct().all()
    
    # 2. Extraer datos técnicos
    cilindradas = db.query(func.upper(Detalle_Motor.cilindrada)).distinct().all()
    combustibles = db.query(func.upper(Detalle_Motor.combustible)).distinct().all()
    transmisiones = db.query(func.upper(Detalle_Motor.transmision_tipo)).distinct().all()

    # 3. Extraer ubicaciones físicas
    pasillos = db.query(func.upper(Activo_Inventariado.ubicacion_pasillo)).distinct().all()
    pallets = db.query(func.upper(Activo_Inventariado.ubicacion_pallet)).distinct().all()

    def limpiar_lista(query_result):
        return sorted([item[0] for item in query_result if item[0] is not None and str(item[0]).strip() != ""])

    return {
        "marcas": limpiar_lista(marcas),
        "modelos": limpiar_lista(modelos),
        "cilindradas": limpiar_lista(cilindradas),
        "combustibles": limpiar_lista(combustibles),
        "transmisiones": limpiar_lista(transmisiones),
        "pasillos": limpiar_lista(pasillos),
        "pallets": limpiar_lista(pallets),
    }

# Asegúrate de tener estas importaciones arriba:
# from models import Activo_Inventariado, Vehiculo_Origen, Detalle_Motor, Detalle_Caja_Cambio, Categoria_Activo, Estado_Activo, Multimedia_Activo

@router.get("/buscar")
def buscar_inventario(
    categoria: Optional[str] = None,
    pasillo: Optional[str] = None,
    pallet: Optional[str] = None,
    marca: Optional[str] = None,
    modelo: Optional[str] = None,
    cilindrada: Optional[str] = None,
    combustible: Optional[str] = None,
    transmision: Optional[str] = None,
    db: Session = Depends(get_db)
):
    # Unimos todas las tablas necesarias, incluyendo cajas, categorías y estados
    query = db.query(
        Activo_Inventariado, 
        Vehiculo_Origen, 
        Detalle_Motor, 
        Detalle_Caja_Cambio,
        Categoria_Activo,
        Estado_Activo
    ).outerjoin(
        Vehiculo_Origen, Activo_Inventariado.id_vehiculo == Vehiculo_Origen.id_vehiculo
    ).outerjoin(
        Detalle_Motor, Activo_Inventariado.id_activo == Detalle_Motor.id_activo
    ).outerjoin(
        Detalle_Caja_Cambio, Activo_Inventariado.id_activo == Detalle_Caja_Cambio.id_activo
    ).join(
        Categoria_Activo, Activo_Inventariado.id_categoria == Categoria_Activo.id_categoria
    ).join(
        Estado_Activo, Activo_Inventariado.id_estado == Estado_Activo.id_estado
    )

    # ⚠️ REGLA DE NEGOCIO: Excluir Vendidos (3) y En Desarme (5)
    query = query.filter(Activo_Inventariado.id_estado.notin_([3, 5]))

    # Filtro de Categoría (Mapeamos el plural del frontend al ID real de la BD)
    if categoria:
        cat_upper = categoria.upper()
        if cat_upper == "MOTORES":
            query = query.filter(Activo_Inventariado.id_categoria == 1)
        elif cat_upper == "CAJAS DE CAMBIO":
            query = query.filter(Activo_Inventariado.id_categoria == 2)
        elif cat_upper == "ACCESORIOS":
            query = query.filter(Activo_Inventariado.id_categoria == 3)

    # Resto de filtros dinámicos
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
        # El filtro de transmisión debe buscar tanto en motor como en caja
        query = query.filter(
            (func.upper(Detalle_Motor.transmision_tipo) == transmision.upper()) | 
            (func.upper(Detalle_Caja_Cambio.transmision_tipo) == transmision.upper())
        )

    resultados_db = query.all()

    respuesta = []
    for activo, vehiculo, motor, caja, cat, est in resultados_db:
        fotos_db = db.query(Multimedia_Activo.url_storage).filter(Multimedia_Activo.id_activo == activo.id_activo).all()
        lista_fotos = [foto[0] for foto in fotos_db] if fotos_db else []

        # Determinar de dónde sacar la transmisión según la categoría
        if cat.id_categoria == 2 and caja:
            transmision_val = caja.transmision_tipo
        elif motor:
            transmision_val = motor.transmision_tipo
        else:
            transmision_val = "N/A"

        respuesta.append({
            "sku": activo.sku_qr_fisico,
            "numero_ingreso": vehiculo.numero_ingreso if vehiculo else "N/A",
            "marca": vehiculo.marca if vehiculo else "Desconocida",
            "modelo": vehiculo.modelo if vehiculo else "Desconocido",
            "ubicacion": f"{activo.ubicacion_pasillo or 'S/P'} - {activo.ubicacion_pallet or 'S/P'}",
            
            # ⚠️ Extraemos la Categoría y el Estado reales
            "estado": est.nombre_estado, 
            "categoria": cat.nombre_categoria, 
            
            "cilindrada": motor.cilindrada if motor else "N/A",
            "combustible": motor.combustible if motor else "N/A",
            "transmision": transmision_val or "N/A",
            "observacion": getattr(activo, 'observacion_estado', 'Sin observaciones registradas.'),
            "imagenes": lista_fotos
        })

    return respuesta