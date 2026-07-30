from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import SessionLocal, get_db
import schemas
from services.vehiculo_service import procesar_patente_y_guardar
from sqlalchemy import func, cast, Integer
from models import Vehiculo_Origen, Activo_Inventariado, Detalle_Motor, Detalle_Caja_Cambio

# Instanciamos el enrutador con su prefijo oficial (Sub-tarea A)
router = APIRouter(
    prefix="/api/v1/vehiculos",
    tags=["Autocompletado de Vehículos"]
)

# ==========================================
# 1. RUTAS ESTÁTICAS (Van primero)
# ==========================================

@router.get("/siguiente-ingreso", status_code=200)
def obtener_siguiente_ingreso(db: Session = Depends(get_db)):
    """
    Calcula y retorna el siguiente número correlativo para el ingreso de un vehículo.
    """
    # Buscamos el valor máximo, forzando a SQL a tratar el varchar como un Integer
    resultado = db.query(func.max(cast(Vehiculo_Origen.numero_ingreso, Integer))).scalar()
    
    # Regla de Negocio: Si la tabla está vacía (Día 1 de operaciones)
    if resultado is None:
        siguiente_numero = 1
    else:
        # Sumamos 1 al número más alto encontrado
        siguiente_numero = resultado + 1
        
    return {"siguiente_ingreso": str(siguiente_numero)}

@router.post("/", response_model=schemas.VehiculoResponse, status_code=201)
def registrar_ingreso_vehiculo(vehiculo_in: schemas.VehiculoCreate, db: Session = Depends(get_db)):
    """
    Registra un vehículo y sus componentes principales (Motor y Caja) en una sola transacción.
    """
    try:
        # 1. Calcular el correlativo definitivo y bloquearlo
        max_ingreso = db.query(func.max(cast(Vehiculo_Origen.numero_ingreso, Integer))).scalar()
        nuevo_numero_ingreso = str(1000) if max_ingreso is None else str(max_ingreso + 1)

        # 2. Crear la "Cabecera" (El Vehículo)
        nuevo_vehiculo = Vehiculo_Origen(
            numero_ingreso=nuevo_numero_ingreso,
            patente=vehiculo_in.patente,
            marca=vehiculo_in.marca,
            modelo=vehiculo_in.modelo,
            anio=vehiculo_in.anio,
            traccion=vehiculo_in.traccion
        )
        db.add(nuevo_vehiculo)
        
        # IMPORTANTE: Hacemos flush en vez de commit. 
        # Esto guarda el auto en memoria temporal para que PostgreSQL nos entregue su ID autogenerado.
        db.flush() 

        # =========================================================
        # 3. CREACIÓN DE COMPONENTES HIJOS (Activos Inventariados)
        # Nota: Los IDs de categoría, estado y sucursal son estáticos 
        # asumiendo tus catálogos. (1=Motor, 2=Caja, 1=Disponible, 1=Casa Matriz)
        # =========================================================

        # --- A. MOTOR ---
        activo_motor = Activo_Inventariado(
            sku_qr_fisico=f"MOT-{nuevo_numero_ingreso}", # Generamos un SKU temporal
            id_categoria=1, 
            id_estado=5,    
            id_sucursal_actual=1, 
            id_vehiculo=nuevo_vehiculo.id_vehiculo # Conectamos con el ID del auto recién creado
        )
        db.add(activo_motor)
        db.flush() # Guardamos temporalmente para obtener el id_activo del motor

        detalle_motor = Detalle_Motor(
            id_activo=activo_motor.id_activo, # Relación 1 a 1 exacta
            numero_motor=vehiculo_in.numero_motor,
            cilindrada=vehiculo_in.cilindrada,
            combustible=vehiculo_in.combustible
        )
        db.add(detalle_motor)

        # --- B. CAJA DE CAMBIOS ---
        activo_caja = Activo_Inventariado(
            sku_qr_fisico=f"CAJ-{nuevo_numero_ingreso}",
            id_categoria=2, 
            id_estado=5,
            id_sucursal_actual=1,
            id_vehiculo=nuevo_vehiculo.id_vehiculo
        )
        db.add(activo_caja)
        db.flush()

        detalle_caja = Detalle_Caja_Cambio(
            id_activo=activo_caja.id_activo,
            transmision_tipo=vehiculo_in.transmision
        )
        db.add(detalle_caja)

        # 4. Confirmar la Transacción Completa (ACID)
        db.commit()
        db.refresh(nuevo_vehiculo) # Actualizamos el objeto con los datos finales de la base de datos

        # 5. Devolvemos el auto al frontend usando VehiculoResponse
        return nuevo_vehiculo

    except Exception as e:
        # Si CUALQUIER paso de arriba falla, PostgreSQL deshace todo inmediatamente.
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error crítico en la transacción: {str(e)}")

# ==========================================
# 2. RUTAS DINÁMICAS (Van al final)
# ==========================================

# Configuración de respuestas Swagger 
@router.get("/{patente}", response_model=schemas.VehiculoResponse, status_code=200)
def obtener_vehiculo(patente: str, db: Session = Depends(get_db)):
    """
    Busca un vehículo por su patente en PostgreSQL. Si no existe, acciona el motor de Scraping 
    para registrarlo automáticamente.
    """
    
    # 1. Validación de seguridad con Pydantic
    try:
        # Pydantic verificará que sean 6 caracteres alfanuméricos y limpiará espacios
        patente_validada = schemas.PatenteInput(patente=patente).patente
    except ValueError as e:
        # Si el usuario mandó "123" o "$%&", devolvemos HTTP 400 Bad Request
        raise HTTPException(status_code=400, detail=str(e))
        
    # 2. Orquestación del Servicio (Capa de lógica)
    # Las excepciones 404 y 503 ya están manejadas dentro del servicio y subirán automáticamente
    vehiculo = procesar_patente_y_guardar(db=db, patente_limpia=patente_validada)
    
    # 3. FastAPI mapea automáticamente el objeto 'vehiculo' al esquema 'VehiculoResponse'
    return vehiculo