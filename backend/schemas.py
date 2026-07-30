# Este archivo contiene los esquemas de Pydantic para la validación de datos de entrada y salida en la API.

from pydantic import BaseModel, Field, field_validator
from typing import Optional
from uuid import UUID
import re

# ==========================================
# ESQUEMAS PARA VEHÍCULOS (HU-2.2 Ingesta)
# ==========================================

class VehiculoResponse(BaseModel):
    id_vehiculo: UUID
    numero_ingreso: str # Añadido: Vital para que el operario lo anote físicamente
    patente: Optional[str] = None # Opcional, según lo dicta tu DBML
    marca: str
    modelo: str
    anio: int
    traccion: Optional[str] = None
    
    class Config:
        from_attributes = True


class PatenteInput(BaseModel):
    patente: str = Field(..., description="Patente del vehículo chileno (6 caracteres alfanuméricos)")

    @field_validator('patente')
    def validar_formato_patente(cls, v):
        # Limpiar espacios y pasar a mayúsculas por si el usuario lo escribe mal
        patente_limpia = v.strip().upper()

        # Validar que tenga exactamente 6 caracteres y sea alfanumérica
        if len(patente_limpia) != 6:
            raise ValueError("La patente debe tener exactamente 6 caracteres")
        if not re.match(r"^[A-Z0-9]{6}$", patente_limpia):
            raise ValueError("La patente solo debe contener letras mayúsculas y números")
        
        return patente_limpia


class VehiculoCreate(BaseModel):
    # Datos del Vehículo (Autocompletados por scraper o copiados del padrón)
    patente: str = Field(..., description="Patente validada del vehículo")
    marca: str 
    modelo: str
    anio: int
    traccion: str = Field(..., description="Ej: 4x2, 4x4")
    
    # Datos que FastAPI usará para crear el Detalle_Motor internamente
    cilindrada: str = Field(..., description="Ej: 1.4")
    numero_motor: str = Field(..., description="Número de serie del motor (ej: 10FDCG0803508)")
    combustible: str = Field(..., description="Ej: diesel, gasolina")
    
    # Datos que FastAPI usará para crear el Detalle_Caja_Cambio internamente
    transmision: str = Field(..., description="Ej: mec, at")