from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session
from database import SessionLocal, get_db
import schemas
from services.vehiculo_service import procesar_patente_y_guardar
from sqlalchemy import func, cast, Integer
from models import Vehiculo_Origen, Activo_Inventariado, Detalle_Motor, Detalle_Caja_Cambio
import json # <-- Importante para traducir el texto a JSON

# Instanciamos el enrutador con su prefijo oficial (Sub-tarea A)
router = APIRouter(
    prefix="/api/v1/vehiculos",
    tags=["Autocompletado de Vehículos"]
)

# ==========================================
# 1. RUTAS ESTÁTICAS (Van primero)
# ==========================================

@router.get("/siguiente-ingreso", status_code=200)
def obtener_siguiente_ingreso(db: Session = Depends(get_db)):
    """
    Calcula y retorna el siguiente número correlativo para el ingreso de un vehículo.
    """
    # Buscamos el valor máximo, forzando a SQL a tratar el varchar como un Integer
    resultado = db.query(func.max(cast(Vehiculo_Origen.numero_ingreso, Integer))).scalar()
    
    # Regla de Negocio: Si la tabla está vacía (Día 1 de operaciones)
    if resultado is None:
        siguiente_numero = 1
    else:
        # Sumamos 1 al número más alto encontrado
        siguiente_numero = resultado + 1
        
    return {"siguiente_ingreso": str(siguiente_numero)}

@router.post("/", response_model=schemas.VehiculoResponse, status_code=201)
def registrar_ingreso_vehiculo(
    # --- NUEVO: Recibimos los datos y la foto por separado (Multipart) ---
    datos: str = Form(...),
    foto: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Registra un vehículo y sus componentes principales (Motor y Caja) previa validación Poka-Yoke.
    """
    # 1. DESEMPACAR EL JSON QUE VIENE DESDE FLUTTER
    try:
        datos_dict = json.loads(datos)
        vehiculo_in = schemas.VehiculoCreate(**datos_dict) 
    except Exception as e:
        raise HTTPException(status_code=422, detail="Error al leer los datos del vehículo")

    # ==========================================
    # 2. SIMULADOR DE OCR (El Poka-Yoke temporal)
    # ==========================================
    print("\n" + "="*40)
    print("🛂 INICIANDO VALIDACIÓN POKA-YOKE (ADUANA)")
    print("="*40)
    print(f"📸 Archivo recibido: {foto.filename}")
    
    # AQUI ESTÁ EL CAMBIO: Usamos datos_dict en lugar de vehiculo_in
    numero_esperado = datos_dict.get("correlativo_ingreso") 
    
    print(f"🔍 Motor OCR Simulado: Analizando imagen en busca del número {numero_esperado}...")
    
    # Aquí simulamos que el OCR leyó exitosamente el número correcto
    numero_leido_por_ocr = numero_esperado 
    
    if str(numero_leido_por_ocr) != str(numero_esperado):
        print("❌ ERROR: La foto no corresponde al vehículo.")
        raise HTTPException(status_code=400, detail="El número en la foto no coincide.")
        
    print("✅ Poka-Yoke superado. Autorizando registro en Base de Datos.")
    print("="*40 + "\n")


    # ==========================================
    # 3. GUARDAR EN LA BASE DE DATOS (Tu lógica intacta)
    # ==========================================
    try:
        # 3.1 Calcular el correlativo definitivo y bloquearlo
        max_ingreso = db.query(func.max(cast(Vehiculo_Origen.numero_ingreso, Integer))).scalar()
        nuevo_numero_ingreso = str(1000) if max_ingreso is None else str(max_ingreso + 1)

        # 3.2 Crear la "Cabecera" (El Vehículo)
        nuevo_vehiculo = Vehiculo_Origen(
            numero_ingreso=nuevo_numero_ingreso,
            patente=vehiculo_in.patente,
            marca=vehiculo_in.marca,
            modelo=vehiculo_in.modelo,
            anio=vehiculo_in.anio,
            traccion=vehiculo_in.traccion
        )
        db.add(nuevo_vehiculo)
        db.flush() 

        # --- A. MOTOR ---
        activo_motor = Activo_Inventariado(
            sku_qr_fisico=f"MOT-{nuevo_numero_ingreso}", 
            id_categoria=1, 
            id_estado=5,    
            id_sucursal_actual=1, 
            id_vehiculo=nuevo_vehiculo.id_vehiculo 
        )
        db.add(activo_motor)
        db.flush() 

        detalle_motor = Detalle_Motor(
            id_activo=activo_motor.id_activo, 
            numero_motor=vehiculo_in.numero_motor,
            cilindrada=vehiculo_in.cilindrada,
            combustible=vehiculo_in.combustible
        )
        db.add(detalle_motor)

        # --- B. CAJA DE CAMBIOS ---
        activo_caja = Activo_Inventariado(
            sku_qr_fisico=f"CAJ-{nuevo_numero_ingreso}",
            id_categoria=2, 
            id_estado=5,
            id_sucursal_actual=1,
            id_vehiculo=nuevo_vehiculo.id_vehiculo
        )
        db.add(activo_caja)
        db.flush()

        detalle_caja = Detalle_Caja_Cambio(
            id_activo=activo_caja.id_activo,
            transmision_tipo=vehiculo_in.transmision
        )
        db.add(detalle_caja)

        # 3.3 Confirmar la Transacción Completa (ACID)
        db.commit()
        db.refresh(nuevo_vehiculo) 

        # Devolvemos el auto al frontend
        return nuevo_vehiculo

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error crítico en la transacción: {str(e)}")

# ==========================================
# 2. RUTAS DINÁMICAS (Van al final)
# ==========================================

@router.get("/{patente}", response_model=schemas.VehiculoResponse, status_code=200)
def obtener_vehiculo(patente: str, db: Session = Depends(get_db)):
    """
    Busca un vehículo por su patente en PostgreSQL. Si no existe, acciona el motor de Scraping 
    para registrarlo automáticamente.
    """
    try:
        patente_validada = schemas.PatenteInput(patente=patente).patente
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
        
    vehiculo = procesar_patente_y_guardar(db=db, patente_limpia=patente_validada)
    return vehiculo