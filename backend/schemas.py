#Este archivo contiene los esquemas de Pydantic para la validación de datos de entrada y salida en la API, específicamente para el manejo de vehículos.

from pydantic import BaseModel, Field, field_validator
from typing import Optional
from uuid import UUID
import re

# ==========================================
# ESQUEMAS PARA VEHÍCULOS 
# ==========================================

class VehiculoResponse(BaseModel):
    id_vehiculo: UUID
    patente: str
    marca: str
    modelo: str
    anio: int
    
    class Config:
        from_attributes = True # Permite que Pydantic lea directamente desde el modelo de SQLAlchemy

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


# ==========================================
# ESQUEMAS PARA AUTENTICACIÓN 
# ==========================================

class LoginPINRequest(BaseModel):
    """Payload de entrada para el login por PIN de operario."""
    pin: str


class UsuarioData(BaseModel):
    """DTO de salida con los datos públicos del usuario autenticado."""
    id_usuario: UUID
    nombres: str
    apellidos: str
    rut_usuario: str
    id_rol: int
    id_sucursal: int

    class Config:
        from_attributes = True  # Permite lectura directa desde el modelo SQLAlchemy


class TokenResponse(BaseModel):
    """Respuesta completa del endpoint de login exitoso."""
    access_token: str
    token_type: str = "bearer"
    usuario: UsuarioData