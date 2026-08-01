# Este archivo es el punto de entrada de la API de Cresal-SaaS. Aquí se inicializa la aplicación FastAPI 
# y se crean las tablas en la base de datos PostgreSQL usando SQLAlchemy.

from fastapi import FastAPI
from database import engine, Base
from routers import vehiculos, auth
from fastapi.middleware.cors import CORSMiddleware
import models

# Le dice a SQLAlchemy que lea models.py y cree las tablas en pgAdmin
Base.metadata.create_all(bind=engine)

# Inicializamos la API de Cresal-SaaS
app = FastAPI(
    title="API Cresal-SaaS",
    description="Backend transaccional para gestión de inventario y barrera digital",
    version="1.0.0"
)

# Configuración de CORS para permitir peticiones desde Flutter Web u otros orígenes
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

# Un endpoint de prueba para saber que el servidor funciona
@app.get("/")
def read_root():
    return {"mensaje": "¡API de Cresal-SaaS en línea y Base de Datos conectada!"}

# Registrar las rutas de la aplicación
app.include_router(vehiculos.router)
app.include_router(auth.router)