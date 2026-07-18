from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import SessionLocal, get_db
import schemas
from services.vehiculo_service import procesar_patente_y_guardar

# Instanciamos el enrutador con su prefijo oficial (Sub-tarea A)
router = APIRouter(
    prefix="/api/v1/vehiculos",
    tags=["Autocompletado de Vehículos"]
)

# Dependencia para abrir y cerrar la conexión a la base de datos


# Configuración de respuestas Swagger (Sub-tarea D)
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