# Este archivo es el punto de entrada de la API de Cresal-SaaS. Aquí se inicializa la aplicación FastAPI 
# y se crean las tablas en la base de datos PostgreSQL usando SQLAlchemy.

from fastapi import FastAPI
from database import engine, Base
import models

# Le dice a SQLAlchemy que lea models.py y cree las tablas en pgAdmin
Base.metadata.create_all(bind=engine)

# Inicializamos la API de Cresal-SaaS
app = FastAPI(
    title="API Cresal-SaaS",
    description="Backend transaccional para gestión de inventario y barrera digital",
    version="1.0.0"
)

# Un endpoint de prueba para saber que el servidor funciona
@app.get("/")
def read_root():
    return {"mensaje": "¡API de Cresal-SaaS en línea y Base de Datos conectada!"}