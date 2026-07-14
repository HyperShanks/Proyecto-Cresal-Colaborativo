from sqlalchemy.orm import Session
from fastapi import HTTPException
from services.scraping import obtener_datos_vehiculo
import models
import uuid

def procesar_patente_y_guardar(db: Session, patente_limpia: str):
    """
    Orquesta la lógica de negocio para obtener datos de un vehículo.
    Busca en base de datos primero, aplica web scraping como contingencia y guarda el registro.
    """
    # 1. Consulta inicial a PostgreSQL
    vehiculo_db = db.query(models.Vehiculo_Origen).filter(models.Vehiculo_Origen.patente == patente_limpia).first()
    
    if vehiculo_db:
        return vehiculo_db 
        
    # 2. Ejecución del Scraper externo
    datos_scraper = obtener_datos_vehiculo(patente_limpia)
    
    # Manejo de fallos del scraper (Timeout, caídas o no encontrado)
    if "error" in datos_scraper:
         raise HTTPException(status_code=503, detail="Servicio externo no disponible o error de conexión temporal.")
    
    if datos_scraper.get("marca") == "No encontrado":
         raise HTTPException(status_code=404, detail=f"La patente {patente_limpia} no arrojó resultados válidos.")

    # 3. Mapeo y Persistencia en Supabase
    nuevo_ingreso = f"ING-{str(uuid.uuid4())[:6].upper()}"

    # Convertimos el año a entero, manejando posibles errores si el scraper trae texto corrupto
    try:
        anio_int = int(datos_scraper["anio"])
    except ValueError:
        anio_int = 0

    nuevo_vehiculo = models.Vehiculo_Origen(
        numero_ingreso=nuevo_ingreso,
        patente=patente_limpia,
        vin=None, # El scraper actual no extrae VIN
        marca=datos_scraper["marca"],
        modelo=datos_scraper["modelo"],
        anio=anio_int
    )
    
    db.add(nuevo_vehiculo)
    db.commit()
    db.refresh(nuevo_vehiculo)
    
    return nuevo_vehiculo