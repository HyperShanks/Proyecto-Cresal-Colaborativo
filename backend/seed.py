# Este archivo es el script de semilla para poblar la base de datos PostgreSQL con datos iniciales para pruebas y desarrollo.

import uuid
from database import SessionLocal, engine, Base
import models

def poblar_datos_semilla():
    # Creamos una sesión local con la base de datos
    db = SessionLocal()
    try:
        print("Iniciando el poblado de datos semilla...")

        # 1. Insertar Región (Valparaíso)
        region_v = db.query(models.Region).filter_by(nombre_region="Valparaíso").first()
        if not region_v:
            region_v = models.Region(nombre_region="Valparaíso")
            db.add(region_v)
            db.commit()
            db.refresh(region_v)
            print("✓ Región Valparaíso insertada.")

        # 2. Insertar Comunas (Viña del Mar y Limache)
        comunas = ["Viña del Mar", "Limache"]
        comunas_db = {}
        for c in comunas:
            comuna_obj = db.query(models.Comuna).filter_by(nombre_comuna=c).first()
            if not comuna_obj:
                comuna_obj = models.Comuna(nombre_comuna=c, id_region=region_v.id_region)
                db.add(comuna_obj)
                db.commit()
                db.refresh(comuna_obj)
                print(f"✓ Comuna {c} insertada.")
            comunas_db[c] = comuna_obj

        # 3. Insertar Sucursales de Cresal
        sucursal_vina = db.query(models.Sucursal).filter_by(nombre_sucursal="Sucursal Viña del Mar").first()
        if not sucursal_vina:
            sucursal_vina = models.Sucursal(
                nombre_sucursal="Sucursal Viña del Mar",
                direccion="Camino Internacional 4105",
                sector="Barrio Industrial",
                id_comuna=comunas_db["Viña del Mar"].id_comuna
            )
            db.add(sucursal_vina)
            print("✓ Sucursal Viña del Mar insertada.")

        sucursal_limache = db.query(models.Sucursal).filter_by(nombre_sucursal="Sucursal Limache").first()
        if not sucursal_limache:
            sucursal_limache = models.Sucursal(
                nombre_sucursal="Sucursal Limache",
                direccion="Agua Santa esq. Palmira Romano",
                sector=None,
                id_comuna=comunas_db["Limache"].id_comuna
            )
            db.add(sucursal_limache)
            print("✓ Sucursal Limache insertada.")
        db.commit()

        # 4. Insertar Categorías de Activos (Motores y Cajas)
        categorias = ["Motor", "Caja de Cambios", "Accesorio"]
        for cat in categorias:
            if not db.query(models.CategoriaActivo).filter_by(nombre_categoria=cat).first():
                db.add(models.CategoriaActivo(nombre_categoria=cat))
                print(f"✓ Categoría {cat} insertada.")

        # 5. Insertar Estados del Ciclo de Vida del Repuesto
        estados = ["Disponible", "Reservado", "En Tránsito", "Entregado"]
        for est in estados:
            if not db.query(models.EstadoActivo).filter_by(nombre_estado=est).first():
                db.add(models.EstadoActivo(nombre_estado=est))
                print(f"✓ Estado {est} insertada.")
        db.commit()

        # 6. Insertar Roles Strict de Usuario (RBAC)
        roles = ["Bodeguero", "Vendedor", "Caja", "Gerente"]
        roles_db = {}
        for r in roles:
            rol_obj = db.query(models.Rol).filter_by(nombre_rol=r).first()
            if not rol_obj:
                rol_obj = models.Rol(nombre_rol=r)
                db.add(rol_obj)
                db.commit()
                db.refresh(rol_obj)
                print(f"✓ Rol {r} insertado.")
            roles_db[r] = rol_obj

        # 7. Insertar Usuario Gerente Base (Martín Crovetto de prueba)
        # Sincronizamos la sucursal de Viña para el usuario administrador
        suc_vina = db.query(models.Sucursal).filter_by(nombre_sucursal="Sucursal Viña del Mar").first()
        
        admin_user = db.query(models.Usuario).filter_by(email="martin.crovetto@cresal.cl").first()
        if not admin_user:
            admin_user = models.Usuario(
                id_usuario=uuid.uuid4(),
                id_rol=roles_db["Gerente"].id_rol,
                id_sucursal=suc_vina.id_sucursal,
                nombres="Martín",
                apellidos="Crovetto",
                email="martin.crovetto@cresal.cl",
                password_hash="pbkdf2:sha256:250000$mock_hash_for_testing", # Hash temporal para desarrollo
                pin_acceso="0000",
                telegram_chat_id=None
            )
            db.add(admin_user)
            print("✓ Usuario Gerente (Martín Crovetto) de prueba creado.")
        db.commit()

        print("\n¡Poblado de datos semilla finalizado con éxito de forma íntegra!")

    except Exception as e:
        db.rollback()
        print(f"Error ejecutando el script semilla: {str(e)}")
    finally:
        db.close()

if __name__ == "__main__":
    poblar_datos_semilla()