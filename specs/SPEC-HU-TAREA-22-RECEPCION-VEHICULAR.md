# SPEC-HU-TAREA-22: Módulo Móvil de Recepción Vehicular (Patio) & Segregación RBAC

## 1. Contexto y Archivos Afectados
- **Objetivo**: 
  1. Crear un rol exclusivo (`Recepción`, `id_rol = 9`) para el operario de patio encargado del ingreso de vehículos donantes, aislando su experiencia de las funciones de bodega y WMS (eliminando acceso a pallets, picking y despachos).
  2. Alinear el modelo `Vehiculo_Origen` exactamente con las 13 columnas de la **Matriz Central de Los Pinos** (+2.700 vehículos).
  3. Reemplazar la necesidad de fotos obligatorias o validaciones bloqueantes por un flujo ágil asistido por **Chips Sugeridos Inteligentes** (basados en la estadística real de la empresa), campo libre para nuevos valores, casilla rápida **Sin Patente (S/PPU)** y un **OCR de Padrón opcional** (sin bloqueo).
  4. Proveer capacidad de exportación / copiado rápido en el formato idéntico de columnas A a M para mantener sincronizada la matriz Excel histórica.
- **Archivos a modificar / crear**:
  - **Backend**:
    - `backend/models.py` (ampliar `Vehiculo_Origen` con nuevos campos).
    - `backend/schemas.py` (esquemas de creación, respuesta y exportación de recepción).
    - `backend/routers/vehiculos.py` (nuevo endpoint `/recepcion/registro`, `/recepcion/siguiente-ingreso`, `/recepcion/recientes`, `/recepcion/exportar-excel`).
    - `backend/security.py` / middlewares de autorización (verificación RBAC `id_rol = 9`).
    - `backend/scripts/enriquecer_vehiculos.py` (script de migración/update desde el Excel maestro).
  - **Frontend**:
    - `frontend/lib/core/services/auth_service.dart` (soporte para rol `esRecepcion => idRol == 9`).
    - `frontend/lib/core/constants/app_routes.dart` (enrutamiento condicional post-login).
    - `frontend/lib/features/recepcion/presentation/screens/recepcion_home_screen.dart` (home con folios, buscador, bandeja reciente y exportación).
    - `frontend/lib/features/recepcion/presentation/screens/registro_vehiculo_screen.dart` (formulario rápido con chips sugeridos, OCR opcional y switch S/PPU).
    - `frontend/lib/features/recepcion/services/recepcion_service.dart` (cliente HTTP para la API de recepción).
    - `frontend/lib/features/recepcion/models/vehiculo_recepcion_model.dart` (modelo de datos).

---

## 2. Contratos de Datos y Esquema BD (`Vehiculo_Origen`)

### 2.1 Mapeo de Columnas (Matriz Central vs Base de Datos)

| Columna Matriz (Excel) | Campo en BD (`Vehiculo_Origen`) | Tipo de Dato | Nullable | Regla de Negocio / Valor por Defecto |
| :--- | :--- | :--- | :--- | :--- |
| **A: N° Ingreso** | `numero_ingreso` | `VARCHAR(10)` | `NOT NULL` | Correlativo único autoincremental (ej. 2695) |
| **B: Patente** | `patente` | `VARCHAR(20)` | `NOT NULL` | Mayúsculas sin espacios/guiones. Si no tiene: `SPPU-{numero_ingreso}` |
| **C: Factura** | `factura` | `VARCHAR(50)` | `NULL` | N° Factura de compra, póliza o remate |
| **D: Fecha ingreso** | `fecha_ingreso` | `DATE` | `NOT NULL` | Fecha de entrada física al patio (defecto: `CURRENT_DATE`) |
| **E: Origen** | `origen` | `VARCHAR(100)` | `NULL` | Proveedor / remate de procedencia |
| **F: Marca** | `marca` | `VARCHAR(100)` | `NOT NULL` | Marca comercial en mayúsculas (ej. TOYOTA, CHEVROLET) |
| **G: Modelo** | `modelo` | `VARCHAR(100)` | `NOT NULL` | Modelo y versión (ej. ACCENT RB GL 1.4) |
| **H: Año** | `anio` | `INTEGER` | `NULL` | Año de fabricación (1950 - 2030) |
| **I: Color** | `color` | `VARCHAR(50)` | `NULL` | Color predominante de la carrocería |
| **J: N° Motor** | `numero_motor` | `VARCHAR(100)` | `NULL` | Número de serie estampado en el bloque |
| **K: Destino** | `destino` | `VARCHAR(50)` | `NOT NULL` | Defecto: `'DESARME'` (95% de los casos). Opciones: VENTA, REPARACION, CHATARRA |
| **L: GRUA** | `grua` | `VARCHAR(100)` | `NULL` | Operador / transportista de grúa que lo dejó en patio |
| **M: OBSERVACIONES** | `observaciones` | `TEXT` | `NULL` | Estado de llaves, papeles, choques, faltantes |

---

## 3. Catálogo de Chips Sugeridos (Basado en Estadística Real de Matriz)

Para optimizar la digitación móvil en el patio sin encasillar al operario, los campos de selección contarán con **Chips de Toque Rápido** superiores combinados con un **Campo de Texto Libre**:

### 3.1 Origen (Top 10 Frecuencias)
- **Chips Rápidos Visibles**:
  `[ PARTICULAR ]`, `[ OVALLE ]`, `[ REYCO ]`, `[ MONTERO ]`, `[ ZÁRATE ]`, `[ VEDISA ]`, `[ MARAMBIO ]`, `[ RECSIN ]`, `[ VIERA ]`, `[ BUIN ]`.
- **Comportamiento**: Tocar un chip rellena el campo instantáneamente. El operario puede escribir cualquier origen nuevo directamente con el teclado del móvil.

### 3.2 Destino
- **Selector Segmentado / Chips**:
  - `[ DESARME ]` (Seleccionado por defecto al abrir el formulario).
  - `[ VENTA ]`
  - `[ REPARACIÓN ]`
  - `[ CHATARRA ]`

### 3.3 Grúa (Top Frecuencias)
- **Chips Rápidos Visibles**:
  `[ F. FANO ]` (234 casos - ~55%), `[ A. NÚÑEZ ]`, `[ C. CAZAM ]`, `[ O. VARELA ]`, `[ M. BURGOS ]`, `[ PARTICULAR ]`.
- **Comportamiento**: Un toque autocompleta el nombre del chofer habitual. Permite entrada libre para choferes ocasionales.

### 3.4 Observaciones Rápidas (Chips de Composición)
- Chips de un toque que agregan texto al campo de observaciones:
  - Llaves: `[+ Con Llave]` / `[+ Sin Llave]`
  - Documentos: `[+ Con Documentos]` / `[+ Sin Documentos]`
  - Factura: `[+ Factura adjunta]` / `[+ Pendiente Factura]`

---

## 4. Experiencia de Usuario & Reglas de Negocio en la App

### 4.1 Pantalla Principal: `RecepcionHomeScreen`
1. **Indicador de Correlativo en Vivo:** Banner superior destacando `Siguiente Ingreso: N° [XXXX]`.
2. **Botón Principal:** `[ + Ingresar Vehículo a Patio ]` (alta visibilidad y tamaño adecuado para uso con una sola mano).
3. **Bandeja de Entradas Recientes:**
   - Visualización de los últimos ingresos de la jornada.
   - Buscador rápido por patente o folio de ingreso para evitar ingresos dobles antes de bajar el vehículo de la grúa.
4. **Herramienta Matriz Excel:**
   - Botón `[ 📋 Copiar Formato Matriz ]`: Copia las filas registradas al portapapeles del dispositivo en formato TSV (Tab-Separated Values) compatible con pegado directo en Excel o Google Sheets.
   - Botón `[ 📥 Exportar CSV/Excel ]`: Descarga o comparte el reporte estructurado con las columnas exactas A a M.

### 4.2 Formulario de Registro: `RegistroVehiculoScreen`
1. **Casilla "Sin Patente (S/PPU)":**
   - Switch / Checkbox `[ ] Vehículo sin Patente (S/PPU)`.
   - Al activarse, bloquea la edición de la patente y asigna el valor seguro `SPPU-{siguiente_numero_ingreso}`.
2. **Asistencia OCR de Padrón (Opcional & Prescindible):**
   - Botón `[ 📷 Escanear Padrón ]`.
   - Si se utiliza, extrae mediante Google ML Kit o Vision los campos: Patente, Marca, Modelo, Año y N° Motor.
   - Si no se utiliza o falla, el formulario opera de manera 100% manual sin interrupciones.
3. **Sin Captura Fotográfica Obligatoria:** No se requiere tomar fotografías del vehículo para completar el ingreso, garantizando velocidad y bajo consumo de datos en el patio.

---

## 5. Control de Acceso y Seguridad (RBAC)

1. **Nuevo Rol:** `id_rol = 9`, `nombre_rol = "Recepción"`.
2. **Enrutamiento Frontend:**
   - Si `usuario.id_rol == 9`, la aplicación redirige exclusivamente a `RecepcionHomeScreen`.
   - Las pestañas de Catálogo, Caja, Bodega/WMS y Administración quedan completamente ocultas y no instanciadas.
3. **Protección Backend:**
   - Rutas `/api/v1/bodega/*` rechazan solicitudes de usuarios con rol 9 (`HTTP 403 Forbidden`).
   - Rutas `/api/v1/vehiculos/recepcion/*` permiten acceso a roles 9 (Recepción), 1 (Administrador) y 2 (Gerencia).

---

## 6. Script de Enriquecimiento Histórico (`enriquecer_vehiculos.py`)
- Lee la planilla Excel matriz (`.xlsx`).
- Realiza `UPDATE` sobre `Vehiculo_Origen` cruzando por `numero_ingreso` (Columna A).
- Puebla los nuevos campos (`factura`, `fecha_ingreso`, `origen`, `color`, `numero_motor`, `destino`, `grua`, `observaciones`).
- Valida idempotencia: no crea registros duplicados ni sobreescribe datos si no han cambiado.
