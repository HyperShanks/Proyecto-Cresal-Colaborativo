from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from sqlalchemy.orm import Session
from database import SessionLocal, get_db
import schemas
from services.vehiculo_service import procesar_patente_y_guardar
from sqlalchemy import func, cast, Integer
from models import Vehiculo_Origen, Activo_Inventariado, Detalle_Motor, Detalle_Caja_Cambio
from google.cloud import vision
import json # <-- Importante para traducir el texto a JSON
from services.scraping import obtener_datos_vehiculo
from services.sku_service import generar_sku  # HU-2.4: Generación de identidad digital
import models
from dotenv import load_dotenv # Para cargar el .env
from typing import List # Para definir la lista de imágenes en FastAPI
from supabase import create_client, Client # El cliente de Supabase
import os
from dotenv import load_dotenv

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
        # HU-2.4: Primero persistimos sin SKU para obtener el UUID generado por PostgreSQL,
        # luego usamos ese UUID para construir el SKU con el servicio dedicado.
        activo_motor = models.Activo_Inventariado(
            sku_qr_fisico="PENDIENTE",  # Placeholder temporal, se actualiza justo debajo
            id_categoria=1, 
            id_estado=5,    
            id_sucursal_actual=1, 
            id_vehiculo=nuevo_vehiculo.id_vehiculo,
            qr_impreso=False  # HU-2.4: False por defecto hasta que el operario imprima
        )
        db.add(activo_motor)
        db.flush()  # Flush para que PostgreSQL asigne el UUID

        # HU-2.4: Generamos el SKU real usando el UUID ya asignado
        activo_motor.sku_qr_fisico = generar_sku(
            nombre_categoria="Motor",
            id_activo_str=str(activo_motor.id_activo)
        )
        db.flush()

        detalle_motor = models.Detalle_Motor(
            id_activo=activo_motor.id_activo, 
            numero_motor=vehiculo_in.numero_motor,
            cilindrada=vehiculo_in.cilindrada,
            combustible=vehiculo_in.combustible
        )
        db.add(detalle_motor)

        # --- B. CAJA DE CAMBIOS ---
        activo_caja = models.Activo_Inventariado(
            sku_qr_fisico="PENDIENTE",  # Placeholder temporal
            id_categoria=2, 
            id_estado=5,
            id_sucursal_actual=1,
            id_vehiculo=nuevo_vehiculo.id_vehiculo,
            qr_impreso=False  # HU-2.4: False por defecto
        )
        db.add(activo_caja)
        db.flush()  # Flush para obtener UUID

        # HU-2.4: Generamos el SKU real para la caja
        activo_caja.sku_qr_fisico = generar_sku(
            nombre_categoria="Caja de Cambio",
            id_activo_str=str(activo_caja.id_activo)
        )
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


@router.get("/buscar/{numero_ingreso}")
def buscar_vehiculo_por_ingreso(numero_ingreso: str, db: Session = Depends(get_db)):
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
            "numero_motor": detalle_motor.numero_motor if detalle_motor else "S/A",
            "cilindrada": detalle_motor.cilindrada if detalle_motor else "S/A",
            "combustible": detalle_motor.combustible if detalle_motor else "S/A",
            "transmision_tipo": detalle_motor.transmision_tipo if detalle_motor else "S/A",
        },
        "caja_cambios": {
            "id_activo": str(activo_caja.id_activo) if activo_caja else None,
            "transmision_tipo": detalle_caja.transmision_tipo if detalle_caja else "S/A",
        }
    }

@router.post("/validar-ocr-pieza")
async def validar_ocr_pieza(
    numero_ingreso: str = Form(...),
    imagen_posca: UploadFile = File(...)
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

@router.post("/guardar-paletizado", response_model=schemas.PaletizadoResponse, status_code=201)
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
    
    db: Session = Depends(get_db)
):
    """
    [Jefe Final] - HU-2.3
    1. Sube las fotos comerciales a Supabase Storage.
    2. Actualiza la ubicación física en PostgreSQL (Activo_Inventariado).
    3. Registra las URLs de las fotos en PostgreSQL (Multimedia_Activo).
    """
    
    print("\n" + "="*40)
    print(f"💾 INICIANDO GUARDADO LOGÍSTICO PARA FOLIO {numero_ingreso}")
    print(f"DEBUG TIPO_REPUESTO: {repr(tipo_repuesto)}")
    print("="*40)

    # 0. Normalización tolerante de categoría
    tipo_clean = tipo_repuesto.strip().lower() if tipo_repuesto else ""
    if "motor" in tipo_clean:
        id_categoria_objetivo = 1
    elif "caja" in tipo_clean or "transmision" in tipo_clean:
        id_categoria_objetivo = 2
    else:
        id_categoria_objetivo = 1 if tipo_repuesto == "Motor" else 2

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
    
    # Nombre del "bucket" o contenedor principal en Supabase
    BUCKET_NAME = "multimedia-activos"
    
    # Intentamos crear el bucket si no existe (con Service Role Key podemos hacerlo)
    try:
        supabase.storage.create_bucket(BUCKET_NAME, options={"public": True}) # public=True para tener URLs directas
        print(f"✅ Bucket '{BUCKET_NAME}' creado (o ya existía).")
    except Exception as e:
        # Si ya existe, nos dará error, pero está bien. Solo imprimimos para saber.
        print(f"ℹ️ Info sobre Bucket: {str(e)}")
        pass

    # Iteramos sobre cada foto comercial que envió Flutter
    for i, foto in enumerate(fotos_comerciales):
        try:
            # Creamos un nombre de archivo único para la nube.
            # Ejemplo: paletizado/1008/moto_1008_comercial_1.jpg
            prefijo = "moto" if id_categoria_objetivo == 1 else "caja"
            nombre_archivo_nube = f"{numero_ingreso}/{prefijo}_{numero_ingreso}_comercial_{i+1}.jpg"
            
            # Leemos los bytes físicos de la imagen (que ya viene comprimida desde Flutter)
            contenido_imagen = await foto.read()
            
            # Hacemos la subida física a Supabase Storage
            # path= es la ruta dentro del bucket, file= es el contenido
            supabase.storage.from_(BUCKET_NAME).upload(
                path=nombre_archivo_nube, 
                file=contenido_imagen,
                file_options={"cache-control": "3600", "content-type": "image/jpeg"} # Ayuda al navegador
            )
            
            # Obtenemos la URL pública para guardarla después en PostgreSQL
            url_publica = supabase.storage.from_(BUCKET_NAME).get_public_url(nombre_archivo_nube)
            urls_fotos_publicas.append(url_publica)
            
            print(f"📸 Foto {i+1} subida exitosamente: {nombre_archivo_nube}")
            
        except Exception as e:
            # Si una foto falla, queremos abortar todo y avisar
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
        # Usamos join para ir de Vehiculo_Origen -> Activo_Inventariado
        query_activo = db.query(models.Activo_Inventariado).join(models.Vehiculo_Origen).filter(
            models.Vehiculo_Origen.numero_ingreso == numero_ingreso
        )
        
        # Filtramos por categoría usando la normalización tolerante
        query_activo = query_activo.filter(models.Activo_Inventariado.id_categoria == id_categoria_objetivo)
        
        activo = query_activo.first()
        
        if not activo:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No se encontró el activo '{tipo_repuesto}' (categoría {id_categoria_objetivo}) asociado al folio {numero_ingreso}."
            )

        # 2. Actualizar la Ubicación Física y Observaciones (PERSISTENCIA LOGÍSTICA)
        activo.ubicacion_galpon = galpon
        activo.ubicacion_pasillo = pasillo
        activo.ubicacion_pallet = pallet
        
        # Guardar observación
        if hasattr(activo, 'observacion_estado') and observaciones:
            activo.observacion_estado = observaciones
            
        activo.id_estado = 1
        
        db.flush() # Empujamos los cambios a la base de datos pero sin hacer commit aún
        
        # 3. Guardar las URLs de las fotos en Multimedia_Activo (PERSISTENCIA COMERCIAL)
        for url in urls_fotos_publicas:
            nueva_multimedia = models.Multimedia_Activo(
                id_activo=activo.id_activo,
                url_storage=url,
                tipo_archivo="imagen" # <-- Usamos la columna que realmente existe en tu modelo
            )
            db.add(nueva_multimedia)
            
        # 4. Confirmar la transacción completa (ACID)
        db.commit() # Si llegamos aquí, todo salió perfecto (subida y base de datos)
        db.refresh(activo)  # HU-2.4: Refrescar para obtener el SKU definitivo y ubicación desde la BD
        
        print(f"✅ Paletizado guardado exitosamente en base de datos para Folio {numero_ingreso}.")
        print(f"🏷️  SKU asignado: {activo.sku_qr_fisico}")
        print(f"📍 Ubicación persistida: Galpón {activo.ubicacion_galpon}, Pasillo {activo.ubicacion_pasillo}, Pallet {activo.ubicacion_pallet}")
        print("="*40 + "\n")

        # ── HU-2.4: Recopilar datos técnicos para la etiqueta térmica ──────────
        detalle_motor_resp = None
        detalle_caja_resp = None

        if activo.id_categoria == 1:
            detalle_motor_resp = db.query(models.Detalle_Motor).filter(
                models.Detalle_Motor.id_activo == activo.id_activo
            ).first()
        elif activo.id_categoria == 2:
            detalle_caja_resp = db.query(models.Detalle_Caja_Cambio).filter(
                models.Detalle_Caja_Cambio.id_activo == activo.id_activo
            ).first()

        # Obtenemos los datos del vehículo origen para la etiqueta
        vehiculo_origen = db.query(models.Vehiculo_Origen).filter(
            models.Vehiculo_Origen.id_vehiculo == activo.id_vehiculo
        ).first()

        # Determinamos la transmisión adecuada (motor o caja)
        transmision_val = None
        if detalle_motor_resp and detalle_motor_resp.transmision_tipo:
            transmision_val = detalle_motor_resp.transmision_tipo
        elif detalle_caja_resp and detalle_caja_resp.transmision_tipo:
            transmision_val = detalle_caja_resp.transmision_tipo

        # ── HU-2.4: Respuesta enriquecida con PaletizadoResponse ────────────────
        return schemas.PaletizadoResponse(
            # Identidad digital
            sku_qr_fisico=activo.sku_qr_fisico,
            qr_impreso=activo.qr_impreso,
            # Datos del vehículo origen
            numero_ingreso=vehiculo_origen.numero_ingreso if vehiculo_origen else numero_ingreso,
            marca=vehiculo_origen.marca if vehiculo_origen else "",
            modelo=vehiculo_origen.modelo if vehiculo_origen else "",
            anio=vehiculo_origen.anio if vehiculo_origen else 0,
            # Detalles técnicos (None si no aplica → Flutter muestra "N/A")
            cilindrada=detalle_motor_resp.cilindrada if detalle_motor_resp else None,
            combustible=detalle_motor_resp.combustible if detalle_motor_resp else None,
            transmision=transmision_val,
            numero_motor=detalle_motor_resp.numero_motor if detalle_motor_resp else None,
            # Ubicación física confirmada desde la instancia de BD
            galpon=activo.ubicacion_galpon or galpon,
            pasillo=activo.ubicacion_pasillo or pasillo,
            pallet=activo.ubicacion_pallet or pallet,
            # Compatibilidad
            status="success",
            mensaje=f"Paletizado del '{tipo_repuesto}' (Folio {numero_ingreso}) guardado con {len(urls_fotos_publicas)} fotos.",
            urls_fotos=urls_fotos_publicas,
        )
        
    except Exception as e:
        # ¡IMPORTANTE! Si la base de datos falla, debemos revertir la subida de fotos a Supabase (Rolback)
        print(f"⚠️ ERROR CRÍTICO EN BASE DE DATOS: {str(e)}. Iniciando Rollback de Storage.")
        db.rollback()
        
        # Intento de borrado de archivos subidos en Supabase Storage
        for url in urls_fotos_publicas:
            try:
                # Extraemos el nombre del archivo de la URL
                # Ejemplo URL: .../object/public/multimedia-activos/1008/moto_1008_comercial_1.jpg
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