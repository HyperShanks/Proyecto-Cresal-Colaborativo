# Este archivo es el script de semilla para poblar la base de datos PostgreSQL con datos iniciales para pruebas y desarrollo.

from database import SessionLocal, engine, Base
from models import (
    Rol, Categoria_Activo, Estado_Activo, 
    Region, Comuna, Sucursal, Usuario
)

def seed_data():
    # 1. Esta es la línea mágica que lee models.py y crea las tablas si no existen
    print("Verificando y creando tablas en PostgreSQL...")
    Base.metadata.create_all(bind=engine)

    # Abrimos la sesión de conexión a la base de datos
    db = SessionLocal()

    try:
        # 2. Poblar Roles
        roles_base = ["Bodeguero", "Vendedor", "Caja", "Gerente", "Administrador", "Auditor"]
        for nombre in roles_base:
            if not db.query(Rol).filter_by(nombre_rol=nombre).first():
                db.add(Rol(nombre_rol=nombre))
        db.commit()
        print("- Roles creados.")

        # 3. Poblar Categorías de Inventario
        categorias_base = ["Motor", "Caja de Cambios", "Accesorio"]
        for cat in categorias_base:
            if not db.query(Categoria_Activo).filter_by(nombre_categoria=cat).first():
                db.add(Categoria_Activo(nombre_categoria=cat))
        db.commit()
        print("- Categorías creados.")

        # 4. Poblar Estados del Activo (HU-3.6: incluye 'Entregado' y 'Paletizado' para ciclo de tasación)
        estados_base = ["En Desarme", "Disponible", "Reservado", "Vendido", "En Importación", "Entregado", "Paletizado"]
        for est in estados_base:
            if not db.query(Estado_Activo).filter_by(nombre_estado=est).first():
                db.add(Estado_Activo(nombre_estado=est))
                print(f"  + Estado creado: {est}")
        db.commit()
        print("- Estados de activo verificados y creados.")

        # 5. Crear Geografía y Sucursal Casa Matriz (Necesario para el Admin)
        region_valpo = db.query(Region).filter_by(nombre_region="Valparaíso").first()
        if not region_valpo:
            region_valpo = Region(nombre_region="Valparaíso")
            db.add(region_valpo)
            db.commit()

        comuna_vina = db.query(Comuna).filter_by(nombre_comuna="Viña del Mar").first()
        if not comuna_vina:
            comuna_vina = Comuna(nombre_comuna="Viña del Mar", id_region=region_valpo.id_region)
            db.add(comuna_vina)
            db.commit()

        sucursal_matriz = db.query(Sucursal).filter_by(nombre_sucursal="Casa Matriz").first()
        if not sucursal_matriz:
            sucursal_matriz = Sucursal(
                nombre_sucursal="Casa Matriz",
                direccion="Camino Internacional 4105",
                sector="Barrio Industrial",
                id_comuna=comuna_vina.id_comuna
            )
            db.add(sucursal_matriz)
            db.commit()
        print("- Sucursal Casa Matriz configurada.")

        # 6. Crear el Usuario Administrador
        rol_admin = db.query(Rol).filter_by(nombre_rol="Administrador").first()
        admin_user = db.query(Usuario).filter_by(email="admin@cresal.cl").first()
        
        if not admin_user:
            admin_user = Usuario(
                id_rol=rol_admin.id_rol,
                id_sucursal=sucursal_matriz.id_sucursal,
                rut_usuario="11111111-1",
                nombres="Admin",
                apellidos="Cresal",
                email="admin@cresal.cl",
                # Nota: Más adelante usaremos passlib para encriptar. Por ahora usamos un hash falso para el MVP.
                password_hash="hash_temporal_1234", 
                pin_acceso="9999"
            )
            db.add(admin_user)
            db.commit()
            print("- Usuario Administrador (admin@cresal.cl) creado exitosamente.")

        print("\n🏆 ¡Poblamiento de Base de Datos completado con éxito!")

    except Exception as e:
        db.rollback()
        print(f"❌ Error al poblar la base de datos: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    print("Iniciando script seed.py...")
    seed_data()