# Este archivo es el punto de entrada de la API de Cresal-SaaS. Aquí se inicializa la aplicación FastAPI 
# y se crean las tablas en la base de datos PostgreSQL usando SQLAlchemy.

from fastapi import FastAPI
from database import engine, Base
from routers import vehiculos
import models
import os
from fastapi.middleware.cors import CORSMiddleware

# Le dice a SQLAlchemy que lea models.py y cree las tablas en pgAdmin
Base.metadata.create_all(bind=engine)

# Inicializamos la API de Cresal-SaaS
app = FastAPI(
    title="API Cresal-SaaS",
    description="Backend transaccional para gestión de inventario y barrera digital",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permite que cualquier frontend se conecte (ideal para desarrollo local)
    allow_credentials=True,
    allow_methods=["*"],  # Permite GET, POST, PUT, DELETE, etc.
    allow_headers=["*"],
)

# ==========================================
# CONFIGURACIÓN DE IA (Google Cloud Vision)
# ==========================================
# Le indicamos a Python la ruta exacta de tu llave criptográfica
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "vision-key.json"

# Un endpoint de prueba para saber que el servidor funciona
@app.get("/")
def read_root():
    return {"mensaje": "¡API de Cresal-SaaS en línea y Base de Datos conectada!"}

# Registrar las rutas de la aplicación
app.include_router(vehiculos.router)

