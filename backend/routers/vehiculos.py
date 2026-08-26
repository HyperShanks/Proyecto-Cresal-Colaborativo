import uuid
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from sqlalchemy.orm import Session
from database import SessionLocal, get_db
import schemas
from services.vehiculo_service import procesar_patente_y_guardar
from sqlalchemy import func, cast, Integer
from models import Vehiculo_Origen, Activo_Inventariado, Detalle_Motor, Detalle_Caja_Cambio
from google.cloud import vision
import json # <-- Importante para traducir el texto a JSON
import models
from dotenv import load_dotenv # Para cargar el .env
from typing import List, Optional # Para definir la lista de imágenes en FastAPI
from supabase import create_client, Client # El cliente de Supabase
import os
from dotenv import load_dotenv
from core.security import get_current_user
# Cargar variables del .env
load_dotenv()

# Configuración de Supabase (Paso A)
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")

# Inicializamos el cliente. Usamos "try" por si acaso las llaves están mal.
try:
    if not SUPABASE_URL or not SUPABASE_KEY:
        print("⚠️ ADVERTENCIA: No se encontraron SUPABASE_URL o SUPABASE_KEY en el .env. El Storage no funcionará.")
        supabase: Client = None
    else:
        # Aquí está la magia que conecta FastAPI con Supabase
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
        print(f"✅ Conexión exitosa a Supabase en {SUPABASE_URL}. Cliente de Storage listo.")
except Exception as e:
    print(f"❌ ERROR al conectar con Supabase: {str(e)}")
    supabase = None

# Instanciamos el enrutador con su prefijo oficial (Sub-tarea A)
router = APIRouter(
    prefix="/api/v1/vehiculos",
    tags=["Autocompletado de Vehículos"]
)

# ==========================================
# 1. RUTAS ESTÁTICAS (Van primero)
# ==========================================

@router.get("/siguiente-ingreso", status_code=200)
def obtener_siguiente_ingreso(db: Session = Depends(get_db), usuario_logeado: models.Usuario = Depends(get_current_user)):
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
    db: Session = Depends(get_db),
    usuario_logeado: models.Usuario = Depends(get_current_user)
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
    # 1.5 NORMALIZACIÓN Y PRE-VALIDACIÓN (HU-2.2)
    # ==========================================
    # Limpiamos espacios y forzamos mayúsculas
    patente_normalizada = vehiculo_in.patente.strip().upper() if vehiculo_in.patente else None

    # Verificamos si la patente ya existe para devolver un error amigable antes de subir la foto
    if patente_normalizada:
        vehiculo_existente = db.query(models.Vehiculo_Origen).filter(
            models.Vehiculo_Origen.patente == patente_normalizada
        ).first()
        
        if vehiculo_existente:
            raise HTTPException(
                status_code=400, 
                detail=f"La patente {patente_normalizada} ya se encuentra registrada en el sistema."
            )

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
    # 3. GUARDAR EN LA BASE DE DATOS
    # ==========================================
    try:
        # 3.1 Calcular el correlativo definitivo y bloquearlo
        max_ingreso = db.query(func.max(cast(models.Vehiculo_Origen.numero_ingreso, Integer))).scalar()
        nuevo_numero_ingreso = str(1000) if max_ingreso is None else str(max_ingreso + 1)

        # 3.2 Crear la "Cabecera" (El Vehículo)
        nuevo_vehiculo = models.Vehiculo_Origen(
            numero_ingreso=nuevo_numero_ingreso,
            patente=patente_normalizada, # <-- Usamos la patente normalizada
            marca=vehiculo_in.marca,
            modelo=vehiculo_in.modelo,
            anio=vehiculo_in.anio,
            traccion=vehiculo_in.traccion
        )
        db.add(nuevo_vehiculo)
        db.flush() 

        # --- A. MOTOR ---
        activo_motor = models.Activo_Inventariado(
            sku_qr_fisico=f"MOT-{nuevo_numero_ingreso}", 
            id_categoria=1, 
            id_estado=5,    
            id_sucursal_actual=1, 
            id_vehiculo=nuevo_vehiculo.id_vehiculo 
        )
        db.add(activo_motor)
        db.flush() 

        detalle_motor = models.Detalle_Motor(
            id_activo=activo_motor.id_activo, 
            numero_motor=vehiculo_in.numero_motor,
            cilindrada=vehiculo_in.cilindrada,
            combustible=vehiculo_in.combustible,
            transmision_tipo=vehiculo_in.transmision
        )
        db.add(detalle_motor)

        # --- B. CAJA DE CAMBIOS ---
        activo_caja = models.Activo_Inventariado(
            sku_qr_fisico=f"CAJ-{nuevo_numero_ingreso}",
            id_categoria=2, 
            id_estado=5,
            id_sucursal_actual=1,
            id_vehiculo=nuevo_vehiculo.id_vehiculo
        )
        db.add(activo_caja)
        db.flush()

        detalle_caja = models.Detalle_Caja_Cambio(
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


@router.post("/registro-manual", response_model=schemas.VehiculoResponse, status_code=201)
def registrar_ingreso_vehiculo_manual(
    vehiculo_in: schemas.VehiculoCreate,
    db: Session = Depends(get_db),
    usuario_logeado: models.Usuario = Depends(get_current_user),
):
    """
    [Fallback Contingencia] Permite el registro manual de un vehículo
    tras confirmación explícita del operario ante fallas de Google Vision u OCR.
    """
    patente_normalizada = vehiculo_in.patente.strip().upper() if vehiculo_in.patente else None

    if patente_normalizada:
        vehiculo_existente = db.query(models.Vehiculo_Origen).filter(
            models.Vehiculo_Origen.patente == patente_normalizada
        ).first()
        if vehiculo_existente:
            raise HTTPException(
                status_code=400,
                detail=f"La patente {patente_normalizada} ya se encuentra registrada en el sistema.",
            )

    try:
        max_ingreso = db.query(func.max(cast(models.Vehiculo_Origen.numero_ingreso, Integer))).scalar()
        nuevo_numero_ingreso = str(1000) if max_ingreso is None else str(max_ingreso + 1)
        if vehiculo_in.correlativo_ingreso and vehiculo_in.correlativo_ingreso != "Cargando...":
            nuevo_numero_ingreso = vehiculo_in.correlativo_ingreso.strip()

        nuevo_vehiculo_id = uuid.uuid4()
        nuevo_vehiculo = models.Vehiculo_Origen(
            id_vehiculo=nuevo_vehiculo_id,
            numero_ingreso=nuevo_numero_ingreso,
            patente=patente_normalizada,
            marca=vehiculo_in.marca,
            modelo=vehiculo_in.modelo,
            anio=vehiculo_in.anio,
            traccion=vehiculo_in.traccion,
        )
        db.add(nuevo_vehiculo)
        db.flush()

        id_motor = uuid.uuid4()
        activo_motor = models.Activo_Inventariado(
            id_activo=id_motor,
            sku_qr_fisico=f"MOT-{nuevo_numero_ingreso}-{uuid.uuid4().hex[:4].upper()}",
            id_categoria=1,
            id_estado=5,
            id_sucursal_actual=getattr(usuario_logeado, "id_sucursal", 1) or 1,
            id_vehiculo=nuevo_vehiculo_id,
            estado="Activo",
            fecha_creacion=datetime.now(),
            qr_impreso=False,
        )
        db.add(activo_motor)
        db.flush()

        detalle_motor = models.Detalle_Motor(
            id_activo=id_motor,
            numero_motor=vehiculo_in.numero_motor,
            cilindrada=vehiculo_in.cilindrada,
            combustible=vehiculo_in.combustible,
            transmision_tipo=vehiculo_in.transmision,
        )
        db.add(detalle_motor)

        id_caja = uuid.uuid4()
        activo_caja = models.Activo_Inventariado(
            id_activo=id_caja,
            sku_qr_fisico=f"CAJ-{nuevo_numero_ingreso}-{uuid.uuid4().hex[:4].upper()}",
            id_categoria=2,
            id_estado=5,
            id_sucursal_actual=getattr(usuario_logeado, "id_sucursal", 1) or 1,
            id_vehiculo=nuevo_vehiculo_id,
            estado="Activo",
            fecha_creacion=datetime.now(),
            qr_impreso=False,
        )
        db.add(activo_caja)
        db.flush()

        detalle_caja = models.Detalle_Caja_Cambio(
            id_activo=id_caja,
            transmision_tipo=vehiculo_in.transmision,
        )
        db.add(detalle_caja)

        db.commit()
        db.refresh(nuevo_vehiculo)
        return nuevo_vehiculo
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error crítico en la transacción: {str(e)}")


# ==========================================
# 2. RUTAS DE INVENTARIO Y PALETIZADO
# ==========================================

@router.get("/pendientes-paletizado", status_code=200)
def obtener_pendientes_paletizado(
    sucursal_id: Optional[int] = None,
    db: Session = Depends(get_db),
    usuario_logeado: models.Usuario = Depends(get_current_user),
):
    """
    Lista todos los activos de inventario pendientes de paletizado de la sucursal activa
    (ubicacion_pasillo IS NULL, ubicacion_pasillo == 'S/P', o id_estado == 5).
    """
    from sqlalchemy import or_

    suc_target = sucursal_id or getattr(usuario_logeado, "id_sucursal", 1) or 1

    query = (
        db.query(
            models.Activo_Inventariado,
            models.Vehiculo_Origen,
            models.Categoria_Activo,
            models.Estado_Activo,
        )
        .outerjoin(models.Vehiculo_Origen, models.Activo_Inventariado.id_vehiculo == models.Vehiculo_Origen.id_vehiculo)
        .join(models.Categoria_Activo, models.Activo_Inventariado.id_categoria == models.Categoria_Activo.id_categoria)
        .join(models.Estado_Activo, models.Activo_Inventariado.id_estado == models.Estado_Activo.id_estado)
        .filter(
            models.Activo_Inventariado.estado == "Activo",
            models.Activo_Inventariado.id_sucursal_actual == suc_target,
            or_(
                models.Activo_Inventariado.id_estado == 5,
                models.Activo_Inventariado.ubicacion_pasillo == None,
                models.Activo_Inventariado.ubicacion_pasillo == "",
                models.Activo_Inventariado.ubicacion_pasillo == "S/P",
                models.Activo_Inventariado.ubicacion_pallet == None,
                models.Activo_Inventariado.ubicacion_pallet == "",
                models.Activo_Inventariado.ubicacion_pallet == "S/P",
            ),
        )
        .order_by(models.Activo_Inventariado.fecha_creacion.desc())
    )

    resultados = query.all()

    respuesta = []
    for activo, vehiculo, cat, est in resultados:
        respuesta.append({
            "id_activo": str(activo.id_activo),
            "sku_qr_fisico": activo.sku_qr_fisico,
            "id_categoria": cat.id_categoria,
            "tipo_repuesto": cat.nombre_categoria,
            "numero_ingreso": vehiculo.numero_ingreso if vehiculo else "N/A",
            "marca": vehiculo.marca if vehiculo else "Desconocida",
            "modelo": vehiculo.modelo if vehiculo else "Desconocido",
            "anio": vehiculo.anio if vehiculo else 0,
            "patente": vehiculo.patente if vehiculo else None,
            "estado": est.nombre_estado,
            "fecha_creacion": activo.fecha_creacion.isoformat() if activo.fecha_creacion else None,
        })

    return respuesta

@router.get("/buscar/{numero_ingreso}")
def buscar_vehiculo_por_ingreso(numero_ingreso: str, db: Session = Depends(get_db), usuario_logeado: models.Usuario = Depends(get_current_user)):
    """
    Busca los datos de un vehículo por su número de ingreso (Folio).
    Retorna los datos del vehículo y los detalles técnicos de sus repuestos (Motor y Caja).
    """
    print(f"\n🔍 Buscando inventario para el folio: {numero_ingreso}")
    
    # 1. Buscar el vehículo base
    vehiculo = db.query(models.Vehiculo_Origen).filter(models.Vehiculo_Origen.numero_ingreso == numero_ingreso).first()
    
    if not vehiculo:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No se encontró un vehículo registrado con el folio '{numero_ingreso}'"
        )

    # 2. Buscar el activo MOTOR (Categoría 1) y sus detalles
    activo_motor = db.query(models.Activo_Inventariado).filter(
        models.Activo_Inventariado.id_vehiculo == vehiculo.id_vehiculo,
        models.Activo_Inventariado.id_categoria == 1 # Asumiendo que 1 es Motor
    ).first()

    detalle_motor = None
    if activo_motor:
        detalle_motor = db.query(models.Detalle_Motor).filter(
            models.Detalle_Motor.id_activo == activo_motor.id_activo
        ).first()

    # 3. Buscar el activo CAJA DE CAMBIOS (Categoría 2) y sus detalles
    activo_caja = db.query(models.Activo_Inventariado).filter(
        models.Activo_Inventariado.id_vehiculo == vehiculo.id_vehiculo,
        models.Activo_Inventariado.id_categoria == 2 # Asumiendo que 2 es Caja
    ).first()

    detalle_caja = None
    if activo_caja:
        detalle_caja = db.query(models.Detalle_Caja_Cambio).filter(
            models.Detalle_Caja_Cambio.id_activo == activo_caja.id_activo
        ).first()

    # 4. Empaquetar todo en un JSON amigable para Flutter
    return {
        "vehiculo": {
            "marca": vehiculo.marca,
            "modelo": vehiculo.modelo,
            "anio": vehiculo.anio,
        },
        "motor": {
            "id_activo": str(activo_motor.id_activo) if activo_motor else None,
            "id_estado": activo_motor.id_estado if activo_motor else None, # ⚠️ NUEVO
            "numero_motor": detalle_motor.numero_motor if detalle_motor else "S/A",
            "cilindrada": detalle_motor.cilindrada if detalle_motor else "S/A",
            "combustible": detalle_motor.combustible if detalle_motor else "S/A",
            "transmision_tipo": detalle_motor.transmision_tipo if detalle_motor else "S/A",
        },
        "caja_cambios": {
            "id_activo": str(activo_caja.id_activo) if activo_caja else None,
            "id_estado": activo_caja.id_estado if activo_caja else None, # ⚠️ NUEVO
            "transmision_tipo": detalle_caja.transmision_tipo if detalle_caja else "S/A",
        }
    }

@router.post("/validar-ocr-pieza")
async def validar_ocr_pieza(
    numero_ingreso: str = Form(...),
    imagen_posca: UploadFile = File(...),
    usuario_logeado: models.Usuario = Depends(get_current_user)
):
    """
    [Poka-Yoke Digital] - HU-2.3
    Recibe la fotografía de la pieza con el número escrito en Posca.
    Utiliza Google Cloud Vision OCR para verificar que el número físico 
    coincida con el folio en el sistema.
    """
    print("\n" + "="*40)
    print("🛂 INICIANDO VALIDACIÓN POKA-YOKE DE PIEZA (OCR)")
    print("="*40)
    
    print(f"📸 Foto recibida: {imagen_posca.filename}")
    print(f"🔍 Buscando el folio '{numero_ingreso}' en la pieza...")

    try:
        # 1. Leemos los bytes de la imagen enviada desde Flutter
        contenido_imagen = await imagen_posca.read()
        
        # 2. Preparamos el cliente de Google Vision
        client = vision.ImageAnnotatorClient()
        image = vision.Image(content=contenido_imagen)
        
        # 3. Solicitamos la detección de texto (OCR)
        response = client.text_detection(image=image)
        texts = response.text_annotations
        
        # Si Google no detecta ningún texto en la foto, rechazamos de inmediato
        if not texts:
            print("❌ ERROR: La IA no detectó ningún texto en la fotografía.")
            print("="*40 + "\n")
            return {
                "match": False,
                "mensaje": "No se detectó ningún texto en la fotografía.",
                "texto_detectado": ""
            }
            
        # 4. Extraemos el texto completo detectado y lo limpiamos
        texto_completo = texts[0].description
        print(f"🧠 Texto crudo detectado por la IA:\n{texto_completo}")
        
        # Limpiamos saltos de línea y espacios extras para una búsqueda exacta
        texto_limpio = texto_completo.replace('\n', '').replace(' ', '').strip()
        print(f"🧹 Texto procesado (sin espacios/saltos): '{texto_limpio}'")
        
        # 5. La magia del Poka-Yoke: ¿El folio está escrito en el metal?
        match_exitoso = numero_ingreso in texto_limpio
        
        if match_exitoso:
            print(f"✅ Poka-Yoke superado. Se encontró el folio '{numero_ingreso}' en la pieza.")
        else:
            print(f"❌ ERROR: El folio '{numero_ingreso}' no coincide con lo escrito en la pieza.")
            
        print("="*40 + "\n")
        
        return {
            "match": match_exitoso,
            "mensaje": "Match exitoso" if match_exitoso else f"El número {numero_ingreso} no coincide con lo escrito en la pieza.",
            "texto_detectado": texto_limpio # Útil para depurar en el frontend
        }
        
    except Exception as e:
        print(f"⚠️ ERROR CRÍTICO EN OCR: {str(e)}")
        print("="*40 + "\n")
        # Si Google Cloud falla (ej. sin internet), manejamos el error elegantemente
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al procesar el OCR con Google Vision: {str(e)}"
        )

@router.post("/guardar-paletizado", status_code=201)
async def guardar_paletizado(
    # --- Datos de Texto ---
    numero_ingreso: str = Form(...),
    tipo_repuesto: str = Form(...), # 'Motor' o 'Caja de Cambios'
    galpon: str = Form(...),
    pasillo: str = Form(...),
    pallet: str = Form(...),
    observaciones: str = Form(None), # Opcional
    
    # --- Lista de hasta 10 fotos comerciales ---
    fotos_comerciales: List[UploadFile] = File(...),
    
    db: Session = Depends(get_db),
    usuario_logeado: models.Usuario = Depends(get_current_user)
):
    """
    [Jefe Final] - HU-2.3 & HU-2.4
    1. Sube las fotos comerciales a Supabase Storage.
    2. Actualiza la ubicación física en PostgreSQL (Activo_Inventariado).
    3. Registra las URLs de las fotos en PostgreSQL (Multimedia_Activo).
    4. Retorna payload enriquecido para generar la etiqueta térmica (HU-2.4).
    """
    
    print("\n" + "="*40)
    print(f"💾 INICIANDO GUARDADO LOGÍSTICO PARA FOLIO {numero_ingreso}")
    print("="*40)

    # 1. Validación de seguridad: ¿Está configurado Supabase?
    if not supabase:
        raise HTTPException(
            status_code=500,
            detail="El servicio de almacenamiento de Supabase no está configurado en el servidor."
        )

    if len(fotos_comerciales) > 10:
        raise HTTPException(status_code=400, detail="Máximo 10 fotografías comerciales permitidas.")

    # ========================================================
    # PASO A. SUBIR IMÁGENES A SUPABASE STORAGE
    # ========================================================
    urls_fotos_publicas = []
    
    BUCKET_NAME = "multimedia-activos"
    
    try:
        supabase.storage.create_bucket(BUCKET_NAME, options={"public": True})
        print(f"✅ Bucket '{BUCKET_NAME}' creado (o ya existía).")
    except Exception as e:
        print(f"ℹ️ Info sobre Bucket: {str(e)}")
        pass

    for i, foto in enumerate(fotos_comerciales):
        try:
            prefijo = "moto" if tipo_repuesto == "Motor" else "caja"
            nombre_archivo_nube = f"{numero_ingreso}/{prefijo}_{numero_ingreso}_comercial_{i+1}.jpg"
            contenido_imagen = await foto.read()
            
            supabase.storage.from_(BUCKET_NAME).upload(
                path=nombre_archivo_nube, 
                file=contenido_imagen,
                file_options={"cache-control": "3600", "content-type": "image/jpeg"}
            )
            
            url_publica = supabase.storage.from_(BUCKET_NAME).get_public_url(nombre_archivo_nube)
            urls_fotos_publicas.append(url_publica)
            
            print(f"📸 Foto {i+1} subida exitosamente: {nombre_archivo_nube}")
            
        except Exception as e:
            print(f"❌ ERROR al subir foto {i+1}: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Fallo al subir la fotografía comercial {i+1} a la nube. El guardado ha sido abortado."
            )

    # ========================================================
    # PASO B. GUARDAR EN POSTGRESQL CON TRANSACCIÓN (SQLAlchemy)
    # ========================================================
    try:
        # 1. Buscar el activo específico (Motor o Caja) usando el Folio
        query_activo = db.query(models.Activo_Inventariado).join(models.Vehiculo_Origen).filter(
            models.Vehiculo_Origen.numero_ingreso == numero_ingreso
        )
        
        id_categoria = 1 if tipo_repuesto == "Motor" else 2
        query_activo = query_activo.filter(models.Activo_Inventariado.id_categoria == id_categoria)
        
        activo = query_activo.first()
        
        if not activo:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No se encontró el activo '{tipo_repuesto}' asociado al folio {numero_ingreso}."
            )

        # 2. Actualizar la Ubicación Física y Observaciones (PERSISTENCIA LOGÍSTICA)
        activo.ubicacion_galpon = galpon
        activo.ubicacion_pasillo = pasillo
        activo.ubicacion_pallet = pallet
        
        if hasattr(activo, 'observacion_estado') and observaciones:
            activo.observacion_estado = observaciones
            
        estado_paletizado = db.query(models.Estado_Activo).filter(models.Estado_Activo.nombre_estado == "Paletizado").first()
        if not estado_paletizado:
            estado_paletizado = models.Estado_Activo(nombre_estado="Paletizado")
            db.add(estado_paletizado)
            db.flush()
            
        activo.id_estado = estado_paletizado.id_estado
        
        db.flush()
        
        # 3. Guardar las URLs de las fotos en Multimedia_Activo (PERSISTENCIA COMERCIAL)
        for url in urls_fotos_publicas:
            nueva_multimedia = models.Multimedia_Activo(
                id_activo=activo.id_activo,
                url_storage=url,
                tipo_archivo="imagen"
            )
            db.add(nueva_multimedia)
            
        # 4. Confirmar la transacción completa (ACID)
        db.commit()
        db.refresh(activo)
        
        print(f"✅ Paletizado guardado exitosamente en base de datos para Folio {numero_ingreso}.")
        
        # ========================================================
        # PASO C. EXTRACCIÓN DE DATOS PARA LA ETIQUETA TÉRMICA (HU-2.4)
        # ========================================================
        print("🔍 Extrayendo datos enriquecidos para la previsualización de la etiqueta...")
        
        vehiculo = db.query(models.Vehiculo_Origen).filter(
            models.Vehiculo_Origen.numero_ingreso == numero_ingreso
        ).first()
        
        cilindrada = None
        combustible = None
        transmision = None
        numero_motor = None
        
        if tipo_repuesto == "Motor":
            detalle_motor = db.query(models.Detalle_Motor).filter(
                models.Detalle_Motor.id_activo == activo.id_activo
            ).first()
            if detalle_motor:
                cilindrada = detalle_motor.cilindrada
                combustible = detalle_motor.combustible
                numero_motor = detalle_motor.numero_motor
                transmision = detalle_motor.transmision_tipo
        else:
            detalle_caja = db.query(models.Detalle_Caja_Cambio).filter(
                models.Detalle_Caja_Cambio.id_activo == activo.id_activo
            ).first()
            if detalle_caja:
                transmision = detalle_caja.transmision_tipo
                
        print(f"🏷️ SKU Generado y enviado a la UI: {activo.sku_qr_fisico}")
        print("="*40 + "\n")
        
        return {
            "status": "success",
            "mensaje": f"Se ha guardado exitosamente el paletizado del '{tipo_repuesto}' (Folio {numero_ingreso}).",
            "urls_fotos": urls_fotos_publicas,
            "id_activo": str(activo.id_activo),
            "sku_qr_fisico": activo.sku_qr_fisico,
            "qr_impreso": activo.qr_impreso if activo.qr_impreso is not None else False,
            "numero_ingreso": numero_ingreso,
            "marca": vehiculo.marca if vehiculo else "S/A",
            "modelo": vehiculo.modelo if vehiculo else "S/A",
            "anio": vehiculo.anio if vehiculo else 0,
            "galpon": galpon,
            "pasillo": pasillo,
            "pallet": pallet,
            "cilindrada": cilindrada,
            "combustible": combustible,
            "transmision": transmision,
            "numero_motor": numero_motor
        }

    except Exception as e:
        print(f"⚠️ ERROR CRÍTICO EN BASE DE DATOS: {str(e)}. Iniciando Rollback de Storage.")
        db.rollback()

        for url in urls_fotos_publicas:
            try:
                parts = url.split(f"{BUCKET_NAME}/")
                if len(parts) == 2:
                    nombre_archivo = parts[1]
                    supabase.storage.from_(BUCKET_NAME).remove([nombre_archivo])
                    print(f"🧹 Archivo revertido de la nube: {nombre_archivo}")
            except Exception as se:
                print(f"⚠️ No se pudo revertir el archivo de la nube: {str(se)}")
                
        raise HTTPException(
            status_code=500,
            detail=f"Error crítico al guardar en PostgreSQL: {str(e)}. Los datos y archivos se han revertido para mantener la integridad."
        )

# ==========================================
# PATCH: Confirmar Impresión de Etiqueta QR (HU-2.4 Fase 4)
# ==========================================

@router.patch("/inventario/{id_activo}/impreso", status_code=200)
def marcar_qr_impreso(
    id_activo: str,
    payload: schemas.ActualizarQrImpresoRequest,
    db: Session = Depends(get_db),
    usuario_logeado: models.Usuario = Depends(get_current_user)
):
    """
    Marca el campo qr_impreso de un Activo_Inventariado como True (o False).
    Llamado automáticamente desde la PDA Sunmi L3 tras una impresión física exitosa.
    """
    print(f"📌 [INVENTARIO] 🖨️ PATCH qr_impreso={payload.qr_impreso} para id_activo: {id_activo}")

    activo = db.query(models.Activo_Inventariado).filter(
        models.Activo_Inventariado.id_activo == id_activo
    ).first()

    if not activo:
        raise HTTPException(
            status_code=404,
            detail=f"Activo inventariado con ID '{id_activo}' no encontrado."
        )

    activo.qr_impreso = payload.qr_impreso
    db.commit()
    db.refresh(activo)

    print(f"📌 [INVENTARIO] ✅ qr_impreso={activo.qr_impreso} guardado exitosamente en BD.")

    return {
        "status": "success",
        "mensaje": "Estado de etiqueta QR actualizado exitosamente.",
        "id_activo": str(activo.id_activo),
        "qr_impreso": activo.qr_impreso
    }


# ==========================================
# 3. RUTAS DINÁMICAS (Al final del archivo)
# ==========================================

@router.get("/{patente}", response_model=schemas.VehiculoResponse, status_code=200)
def obtener_vehiculo(
    patente: str,
    db: Session = Depends(get_db),
    usuario_logeado: models.Usuario = Depends(get_current_user),
):
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