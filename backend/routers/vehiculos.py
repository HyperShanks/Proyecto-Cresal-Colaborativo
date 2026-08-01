from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session
from database import SessionLocal, get_db
import schemas
from services.vehiculo_service import procesar_patente_y_guardar
from sqlalchemy import func, cast, Integer
from models import Vehiculo_Origen, Activo_Inventariado, Detalle_Motor, Detalle_Caja_Cambio
from google.cloud import vision
import json # <-- Importante para traducir el texto a JSON
from services.scraping import obtener_datos_vehiculo

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
async def registrar_ingreso_vehiculo(
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
    # 2. ADUANA POKA-YOKE (GOOGLE CLOUD VISION REAL)
    # ==========================================
    print("\n" + "="*40)
    print("🛂 INICIANDO VALIDACIÓN POKA-YOKE CON INTELIGENCIA ARTIFICIAL")
    print("="*40)
    
    numero_esperado = datos_dict.get("correlativo_ingreso")
    print(f"📸 Foto recibida: {foto.filename}")
    print(f"🔍 Buscando el folio {numero_esperado} en la imagen...")

    # A. Leer los bytes físicos de la imagen que envió Flutter
    contenido_imagen = await foto.read()

    # B. Inicializar el cliente de Google y empaquetar la foto
    cliente_vision = vision.ImageAnnotatorClient()
    imagen_vision = vision.Image(content=contenido_imagen)

    # C. Llamar a la nube de Google para extraer los textos
    respuesta = cliente_vision.text_detection(image=imagen_vision)
    textos_detectados = respuesta.text_annotations

    # D. Validar que Google no haya devuelto un error de servidor
    if respuesta.error.message:
        raise HTTPException(status_code=500, detail=f"Error en Google Vision: {respuesta.error.message}")

    # E. Comprobar si Google encontró letras o números
    if not textos_detectados:
        print("❌ ERROR: La IA no detectó ningún texto en la foto.")
        raise HTTPException(status_code=400, detail="No se detectó texto en la imagen. Escribe más claro.")

    # F. Extraer el texto crudo leído por la IA
    texto_completo = textos_detectados[0].description
    print(f"🧠 Texto crudo detectado por la IA:\n{texto_completo}")

    # G. Validación Industrial: ¿El número del sistema está escrito en la foto?
    if str(numero_esperado) not in texto_completo:
        print(f"❌ ERROR: El folio {numero_esperado} no está escrito en la foto.")
        raise HTTPException(status_code=400, detail="Validación Poka-Yoke fallida: La foto no corresponde al vehículo.")

    print("✅ Poka-Yoke superado. IA confirma que la foto es legítima.")
    print("="*40 + "\n")

    # H. REBOBINAR LA FOTO (Paso crítico)
    # Como leímos la foto para la IA, el cursor de memoria quedó al final.
    # Debemos regresarlo a cero para que el código de base de datos pueda guardarla después.
    await foto.seek(0)

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

@router.get("/scraping/{patente}")
async def scraping_patente(patente: str):
    print("\n" + "="*40)
    print(f"🕵️ BÚSQUEDA SCRAPING INICIADA")
    print(f"Patente solicitada: {patente}")
    print("="*40)
    
    # 1. Llamamos a TU archivo scraping.py real
    datos = obtener_datos_vehiculo(patente)
    
    # 2. Manejo de errores basado en cómo armaste tu diccionario en scraping.py
    if "error" in datos:
        raise HTTPException(status_code=404, detail=datos["error"])
        
    if datos.get("marca") == "No encontrado":
        raise HTTPException(status_code=404, detail="Vehículo no encontrado en registros.")
        
    print(f"✅ Scraping exitoso: {datos.get('marca')} {datos.get('modelo')}")
    
    # 3. Mapeamos los datos (Tu script usa 'nro_motor', pero Flutter espera 'numero_motor')
    return {
        "marca": datos.get("marca", ""),
        "modelo": datos.get("modelo", ""),
        "anio": datos.get("anio", ""),
        "cilindrada": datos.get("cilindrada", ""),
        "numero_motor": datos.get("nro_motor", "") 
    }