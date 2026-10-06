# SPEC-HU-TAREA-22: Módulo Móvil de Recepción Vehicular (Patio), Poka-Yoke OCR con Plumón y Segregación RBAC

## 1. Contexto y Archivos Afectados
- **Objetivo**: 
  1. Crear un rol exclusivo (`Recepción`, `id_rol = 9`, cuenta `gloria@cresal.cl`) para el operario de patio encargado del ingreso de vehículos donantes, aislando su experiencia de las funciones internas de bodega y WMS (eliminando acceso a pallets, picking y despachos).
  2. Implementar el **Menú de Hamburguesa Corporativo (Drawer lateral)** en la pantalla principal de patio (`RecepcionHomeScreen`), siguiendo el estándar visual y funcional de la aplicación (avatar, usuario, sucursal, rol, acceso a Tickets, Configuración, Actualizaciones y botón inferior de Cerrar Sesión con modal de confirmación).
  3. Replicar de forma idéntica la experiencia continua de ingreso vehicular ya existente en bodega (`RecepcionVehiculoScreen`), conservando su **Aduana Poka-Yoke Industrial con plumón Posca y OCR al final**: el operario escribe el número correlativo asignado (ej. `1003`) físicamente en el vehículo, y al presionar "GUARDAR / REGISTRAR INGRESO", la cámara captura la foto y Google Cloud Vision verifica que el número físico coincida.
  4. Ampliar el formulario continuo con los nuevos campos de la **Matriz Central de Los Pinos (13 Columnas A-M)** en `Vehiculo_Origen` (S/PPU, Factura, Fecha de Ingreso, Origen/Proveedor, Color, Destino, Grúa y Observaciones).
  5. Proveer herramientas de matriz (copiado TSV y exportación) para sincronización con la planilla histórica.

- **Archivos a modificar / crear**:
  - **Backend**:
    - `backend/models.py`: Modelo `Vehiculo_Origen` ampliado con las 13 columnas de la matriz.
    - `backend/schemas.py`: Esquemas `VehiculoCreate` y `VehiculoRecepcionCreate` actualizados para aceptar los campos nuevos.
    - `backend/routers/vehiculos.py`: Endpoints `POST /` (multipart con foto Poka-Yoke y 13 columnas), `POST /registro-manual` (contingencia), `GET /recepcion/siguiente-ingreso` y `GET /recepcion/recientes`.
    - `backend/core/security.py`: Permisos RBAC para Rol 9 (`require_recepcion_or_admin`).
  - **Frontend**:
    - `frontend/lib/features/recepcion/presentation/screens/recepcion_home_screen.dart`: Home con AppBar de hamburguesa, Drawer corporativo, banner de folio, botón ingresar, herramientas matriz y recientes.
    - `frontend/lib/features/recepcion/presentation/screens/recepcion_vehiculo_screen.dart`: Formulario continuo oficial enriquecido con los nuevos campos de `Vehiculo_Origen`, scraping nativo de patente, selectores técnicos y flujo atómico de guardado con foto OCR Poka-Yoke y modales de contingencia manual.
    - `frontend/lib/features/recepcion/services/vehiculo_service.dart` / `recepcion_service.dart`: Clientes HTTP alineados con `ApiConstants.vehiculosEndpoint`.
    - `frontend/lib/routes/app_routes.dart`: Rutas `/recepcion` y `/recepcion/registro`.

---

## 2. Contratos de Datos y Esquema BD (`Vehiculo_Origen`)

### 2.1 Mapeo de Columnas (Matriz Central vs Base de Datos)

| Columna Matriz (Excel) | Campo en BD (`Vehiculo_Origen`) | Tipo de Dato | Nullable | Regla de Negocio / Valor por Defecto |
| :--- | :--- | :--- | :--- | :--- |
| **A: N° Ingreso** | `numero_ingreso` | `VARCHAR(10)` | `NOT NULL` | Correlativo único autoincremental (ej. 1003) |
| **B: Patente** | `patente` | `VARCHAR(20)` | `NOT NULL` | Mayúsculas sin espacios/guiones. Si no tiene: `SPPU-{numero_ingreso}` |
| **C: Factura** | `factura` | `VARCHAR(50)` | `NULL` | N° Factura de compra, póliza o remate |
| **D: Fecha ingreso** | `fecha_ingreso` | `DATE` | `NOT NULL` | Fecha de entrada física al patio (defecto: `CURRENT_DATE`) |
| **E: Origen** | `origen` | `VARCHAR(100)` | `NULL` | Proveedor / remate de procedencia |
| **F: Marca** | `marca` | `VARCHAR(100)` | `NOT NULL` | Marca comercial en mayúsculas (ej. TOYOTA, CHEVROLET) |
| **G: Modelo** | `modelo` | `VARCHAR(100)` | `NOT NULL` | Modelo y versión (ej. NEW RUSH XLI 1.5) |
| **H: Año** | `anio` | `INTEGER` | `NULL` | Año de fabricación (1950 - 2030) |
| **I: Color** | `color` | `VARCHAR(50)` | `NULL` | Color predominante de la carrocería |
| **J: N° Motor** | `numero_motor` | `VARCHAR(100)` | `NULL` | Número de serie estampado en el bloque |
| **K: Destino** | `destino` | `VARCHAR(50)` | `NOT NULL` | Defecto: `'DESARME'` (opciones: VENTA, REPARACIÓN, CHATARRA) |
| **L: GRUA** | `grua` | `VARCHAR(100)` | `NULL` | Operador / transportista de grúa |
| **M: OBSERVACIONES** | `observaciones` | `TEXT` | `NULL` | Estado de llaves, papeles, choques, faltantes |

---

## 3. Experiencia de Usuario & Reglas de Negocio en la App

### 3.1 Pantalla Principal: `RecepcionHomeScreen`
1. **Menú de Hamburguesa Corporativo (Drawer Lateral)**:
   - Ubicado arriba a la izquierda (`Icons.menu`).
   - Muestra el perfil activo: Nombre completo, correo, rol (`RECEPCIÓN DE PATIO`) y sucursal.
   - Enlaces rápidos estandarizados:
     - `TICKET` (Navega a `/tickets` para soporte de patio).
     - `CONFIGURACIÓN`.
     - `BUSCAR ACTUALIZACIONES` (Verificación OTA con `AppUpdateChecker`).
   - Botón rojo inferior `CERRAR SESIÓN` con diálogo de confirmación y limpieza de token vía `AuthService.clearToken()`.
2. **Indicador de Correlativo en Vivo:** Banner superior destacando `Siguiente Ingreso: N° [XXXX]` con botón de refresco.
3. **Botón Principal:** `[ + INGRESAR VEHÍCULO A PATIO ]` con altura optimizada (60px) y escalado de texto seguro (`FittedBox`).
4. **Buscador Rápido y Bandeja de Últimos 5 Ingresos:**
   - Buscador rápido por patente, folio, marca o chofer. Al limpiar la búsqueda se reestablece automáticamente a los últimos 5 ingresos registrados.
   - Presenta predeterminadamente los **últimos 5 ingresos** de patio.
   - **Copiado Rápido de Registro (TXT al Portapapeles)**: Al presionar cualquier tarjeta o el botón `[ Copiar TXT ]`, se copian de inmediato al portapapeles todos los campos del vehículo con sus valores formateados (Folio, Patente, Factura, Fecha, Origen, Marca, Modelo, Año, Color, Motor, Destino, Grúa y Observaciones).
   - Acceso alternativo a la ficha completa mediante el botón de información `(i)` o la acción del SnackBar.

### 3.2 Formulario Continuo con Poka-Yoke OCR: `RecepcionVehiculoScreen`
1. **Folio Asignado en Vivo**:
   - Cabecera destacada con el folio (ej. `N° 1003`). Este número es el que el operario raya físicamente con plumón Posca en el vehículo (parabrisas o puerta).
2. **Casilla "Sin Patente (S/PPU)"**:
   - Switch / Checkbox para vehículos sin placa física. Al activarse, inhabilita la búsqueda y asigna automáticamente `SPPU-{numeroIngreso}`.
3. **Identificación y Scraping Nativo**:
   - Campo Patente con botón de búsqueda que consulta datos vehiculares nativamente.
4. **Campos Técnicos y Nuevas Columnas**:
   - Marca, Modelo, Año, Color, N° de Motor, Cilindrada.
   - Selectores desplegables: Tracción, Transmisión y Combustible (con campo libre si se elige "Otro").
   - Nuevos campos: Factura, Fecha de Ingreso, Origen/Proveedor, Destino, Grúa y Observaciones.
5. **Validación Poka-Yoke Obligatoria (Cámara + OCR al Guardar)**:
   - Banner instructivo de validación obligatoria.
   - Botón `[ 📷 GUARDAR / REGISTRAR INGRESO ]` (`btn_guardar_ingreso_ocr`):
     - Dispara la cámara para capturar la fotografía del número rayado con plumón en el auto.
     - Envía los datos + la imagen en Multipart al backend.
     - Google Cloud Vision lee el texto de la foto y verifica que el folio asignado esté presente.
     - Si coincide: Guarda el vehículo y crea los registros base en bodega (Motor y Caja).
     - Si falla: Incrementa contador de intentos.
     - Al 3er intento fallido: Se activa automáticamente el **Modal de Contingencia Manual OCR** permitiendo registrar el vehículo con justificación operativa.

---

## 4. Control de Acceso y Seguridad (RBAC)

1. **Rol Recepción (`id_rol = 9`)**:
   - Credenciales maestras: `gloria@cresal.cl`, Contraseña: `RecepcionApp2026-16`, PIN: `4598`.
2. **Segregación Estricta**:
   - Bloqueado de endpoints de bodega (`/api/v1/bodega/*` devuelve `403 Forbidden`).
   - Permiso exclusivo para operar el módulo de patio y emitir tickets de soporte.

