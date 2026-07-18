# Usamos este archivo por un principio fundamental de la ingeniería de software llamado Separación de Responsabilidades (Separation of Concerns).
# No queremos mezclar las contraseñas y la lógica de conexión con las tablas o con las rutas de la API.

import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from dotenv import load_dotenv

# Carga las variables de tu archivo .env
load_dotenv()

# Obtiene la URL de conexión segura
SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL")

# Crea el motor de base de datos
engine = create_engine(SQLALCHEMY_DATABASE_URL)

# Fábrica de sesiones para las consultas a la BD
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Clase base de la que heredarán todas tus tablas
Base = declarative_base()

# Dependencia para obtener la sesión de la base de datos
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()