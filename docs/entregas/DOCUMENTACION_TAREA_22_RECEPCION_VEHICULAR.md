# DOCUMENTACIÓN TÉCNICA — TAREA 22
## Módulo Móvil de Recepción Vehicular (Patio), Matriz Central Los Pinos (Columnas A-M), Poka-Yoke OCR con Plumón y Segregación RBAC (Gloria)

---

### 1. Resumen Ejecutivo y Necesidad Operativa

La **Tarea 22** implementó el módulo integral de patio para la recepción e ingreso físico de vehículos donantes a la desarmaduría, diseñado a la medida de la operaria de patio **Gloria** (`gloria@cresal.cl`).

#### Problemas que resuelve:
1. **Riesgo Operativo por Falta de Segregación RBAC**: Anteriormente, el operario de patio requería cuentas con privilegios de bodega completa (`Rol 1`), dándole acceso indebido al sistema WMS (pallets, picking, alertas internas y despachos). Se creó el **Rol 9: "Recepción"**, aislando a Gloria para que opere exclusivamente en patio y mesa de ayuda.
2. **Desalineación con la Matriz Central de Los Pinos**: La base de datos solo almacenaba campos genéricos del auto. Se sincronizó el modelo `Vehiculo_Origen` con las **13 columnas oficiales (A-M)** de la planilla matriz histórica de recepción.
3. **Ingreso Ciego de Vehículos (Anti-Equivocación Poka-Yoke)**: Implementación de la aduana industrial con plumón Posca y Google Cloud Vision OCR, asegurando que el correlativo asignado sea escrito físicamente en el parabrisas/chasis y verificado mediante visión artificial antes de guardar.
4. **Exportación e Interoperabilidad**: Incorporación de utilitarios de copiado rápido TSV/Texto en un toque para mantener alimentada la planilla Excel histórica sin fricciones de digitación manual.

---

### 2. Cambios en Base de Datos (PostgreSQL / Supabase)

#### 2.1 Sentencia SQL Ejecutada (Migración DDL & DML)

```sql
-- ============================================================================
-- 1. Crear el nuevo Rol "Recepción" (id_rol = 9)
-- ============================================================================
INSERT INTO "Rol" (id_rol, nombre_rol, estado)
VALUES (9, 'Recepción', 'Activo')
ON CONFLICT (id_rol) DO UPDATE
SET nombre_rol = 'Recepción', estado = 'Activo';

-- ============================================================================
-- 2. Agregar las nuevas columnas a Vehiculo_Origen (sin alterar datos existentes)
-- ============================================================================
ALTER TABLE "Vehiculo_Origen"
  ADD COLUMN IF NOT EXISTS factura VARCHAR(50),
  ADD COLUMN IF NOT EXISTS fecha_ingreso DATE DEFAULT CURRENT_DATE,
  ADD COLUMN IF NOT EXISTS origen VARCHAR(100),
  ADD COLUMN IF NOT EXISTS color VARCHAR(50),
  ADD COLUMN IF NOT EXISTS numero_motor VARCHAR(100),
  ADD COLUMN IF NOT EXISTS destino VARCHAR(50) DEFAULT 'DESARME',
  ADD COLUMN IF NOT EXISTS grua VARCHAR(100),
  ADD COLUMN IF NOT EXISTS observaciones TEXT;

-- ============================================================================
-- 3. Sanitizar registros antiguos con patente nula o vacía antes de aplicar NOT NULL
-- ============================================================================
UPDATE "Vehiculo_Origen"
SET patente = CONCAT('SPPU-', numero_ingreso)
WHERE patente IS NULL OR TRIM(patente) = '' OR patente ILIKE '%SPPU%' OR patente ILIKE '%SINPAT%';

-- ============================================================================
-- 4. Establecer la patente como NOT NULL
-- ============================================================================
ALTER TABLE "Vehiculo_Origen" 
  ALTER COLUMN patente SET NOT NULL;
```

#### 2.2 Mapeo de las 13 Columnas: Matriz Central Los Pinos vs Base de Datos

| Columna Matriz (Excel) | Campo en BD (`Vehiculo_Origen`) | Tipo de Dato | Nullable | Regla de Negocio / Valor por Defecto |
| :--- | :--- | :--- | :---: | :--- |
| **A: N° Ingreso** | `numero_ingreso` | `VARCHAR(10)` | `NOT NULL` | Correlativo único autoincremental de patio (ej. `1003`, `1004`). |
| **B: Patente** | `patente` | `VARCHAR(20)` | `NOT NULL` | Placa en mayúsculas sin guiones. Si no tiene física: `SPPU-{numero_ingreso}`. |
| **C: Factura** | `factura` | `VARCHAR(50)` | `NULL` | N° Factura de compra, póliza de seguro o remate. |
| **D: Fecha ingreso** | `fecha_ingreso` | `DATE` | `NOT NULL` | Fecha de entrada al patio (defecto: `CURRENT_DATE`). |
| **E: Origen** | `origen` | `VARCHAR(100)` | `NULL` | Proveedor, remate o particular de procedencia. |
| **F: Marca** | `marca` | `VARCHAR(100)` | `NOT NULL` | Marca comercial en mayúsculas (ej. `TOYOTA`, `CHEVROLET`). |
| **G: Modelo** | `modelo` | `VARCHAR(100)` | `NOT NULL` | Modelo y versión (ej. `NEW RUSH XLI 1.5`). |
| **H: Año** | `anio` | `INTEGER` | `NULL` | Año de fabricación (rango 1950 - 2030). |
| **I: Color** | `color` | `VARCHAR(50)` | `NULL` | Color predominante de la carrocería. |
| **J: N° Motor** | `numero_motor` | `VARCHAR(100)` | `NULL` | Número de serie estampado en el bloque del motor. |
| **K: Destino** | `destino` | `VARCHAR(50)` | `NOT NULL` | Defecto: `'DESARME'` (opciones: DESARME, VENTA, REPARACIÓN, CHATARRA). |
| **L: GRUA** | `grua` | `VARCHAR(100)` | `NULL` | Operador / transportista de grúa que trasladó el vehículo. |
| **M: OBSERVACIONES** | `observaciones` | `TEXT` | `NULL` | Estado de llaves, papeles, daños estructurales y choques. |

---

### 3. Matriz de Seguridad y Segregación de Roles (RBAC)

#### Perfil Operativo de Gloria:
- **Rol ID**: `9` (`Recepción`)
- **Usuario**: `gloria@cresal.cl`
- **Contraseña**: `RecepcionApp2026-16`
- **PIN de Desbloqueo Rápido**: `4598`
- **RUT**: `20.999.888-7`
- **UUID (`id_usuario`)**: `07e2069f-da72-4e88-b673-d1f97104bf32`
- **Sucursal**: Viña del Mar (1)
- **Tema Visual**: Modo Oscuro industrial (`ThemeMode.dark`) para visibilidad en patio.
- **Ruta Principal**: `/recepcion`

#### Política de Seguridad Zero Trust:
1. **Aislamiento de Bodega Interna**:
   - Bloqueo en backend: los endpoints de `/api/v1/bodega/*` rechazan solicitudes de Rol 9 con `HTTP 403 Forbidden`.
   - Gloria no puede ver pallets, listas de empaque, traslados ni órdenes de venta.
2. **Acceso Concedido**:
   - `/recepcion`: Dashboard de patio con correlativo en vivo, bandeja de últimos 5 vehículos y exportación.
   - `/recepcion/registro`: Formulario continuo de ingreso vehicular con aduana Poka-Yoke OCR.
   - `/tickets`: Sistema interno de tickets y soporte técnico.

---

### 4. Arquitectura de Backend (FastAPI / Python)

```
                            ┌──────────────────────────────────────────┐
                            │      POST /api/v1/vehiculos/             │
                            │   (Multipart Form: Datos + Foto Posca)   │
                            └────────────────────┬─────────────────────┘
                                                 │
                                                 ▼
                            ┌──────────────────────────────────────────┐
                            │         Google Cloud Vision OCR          │
                            │   ¿Texto en foto contiene correlativo?   │
                            └────────────┬─────────────────────────────┘
                                         │
                        ┌────────────────┴────────────────┐
                        │ COINCIDE                        │ NO COINCIDE
                        ▼                                 ▼
         ┌───────────────────────────────┐  ┌───────────────────────────────┐
         │     INSERT Vehiculo_Origen    │  │  HTTP 422: Intento fallido    │
         │   (13 Columnas A-M Matriz)    │  │  (Al 3er fallo habilita modal │
         ├───────────────────────────────┤  │  de contingencia manual)      │
         │          db.flush()           │  └───────────────────────────────┘
         ├───────────────────────────────┤
         │ INSERT Activo: Motor y Caja   │
         │ (Enlace id_vehiculo seguro)   │
         ├───────────────────────────────┤
         │          db.commit()          │
         └───────────────────────────────┘
```

#### 4.1 Endpoints Implementados / Actualizados (`backend/routers/vehiculos.py`):
1. **`POST /api/v1/vehiculos/`**:
   - Recepción multipart con los 13 campos técnicos + archivo de imagen del número rayado.
   - Verificación Poka-Yoke con Google Cloud Vision.
   - Transacción atómica: Inserta el vehículo donante y crea automáticamente los activos base en inventario (`Detalle_Motor` y `Detalle_Caja_Cambio`).
2. **`POST /api/v1/vehiculos/registro-manual`**:
   - Endpoint de contingencia operacional. Permite registrar el ingreso sin OCR tras 3 fallos consecutivos, exigiendo justificación obligatoria.
3. **`GET /api/v1/vehiculos/recepcion/siguiente-ingreso`**:
   - Retorna en tiempo real el siguiente número de folio correlativo (ej. `{"siguiente_numero_ingreso": 1004}`).
4. **`GET /api/v1/vehiculos/recepcion/recientes`**:
   - Retorna la bandeja de los últimos 5 vehículos ingresados con todas sus columnas de matriz para consulta y copiado inmediato.

#### 4.2 Script de Ingesta y Migración Masiva (`backend/migracion_vehiculos.py`):
- Se unificó el script con soporte UPSERT (`--dry-run` y ejecución real).
- **Corrección de integridad referencial**: Se implementó `db.flush()` explícito tras insertar `Vehiculo_Origen` antes de vincular `Activo_Inventariado`, erradicando el error `ForeignKeyViolation: Activo_Inventariado_id_vehiculo_fkey`.

---

### 5. Arquitectura de Frontend (Flutter)

#### 5.1 Pantalla Principal de Patio: `RecepcionHomeScreen`
- **Menú de Hamburguesa Corporativo (Drawer Lateral)**:
  - Ubicado en el AppBar (`Icons.menu`).
  - Cabecera con datos de la sesión: Avatar, Gloria, Rol `RECEPCIÓN DE PATIO`, sucursal.
  - Enlaces rápidos estandarizados: `TICKETS`, `CONFIGURACIÓN`, `BUSCAR ACTUALIZACIONES` (OTA).
  - Botón rojo inferior `CERRAR SESIÓN` con diálogo de confirmación y limpieza de token en `AuthService`.
- **Banner de Folio en Vivo**:
  - Indicador destacado: `Siguiente Ingreso: N° [XXXX]`.
  - Envuelto en `FittedBox` responsivo, **solucionando el desborde de 14px en pantallas compactas**.
- **Botón de Ingreso Ergonómico**:
  - `[ INGRESAR VEHÍCULO A PATIO ]` con altura optimizada (60px). Se eliminó el icono `+` redundante que aparecía duplicado junto al título.
- **Bandeja de Últimos 5 Ingresos & Herramienta de Matriz**:
  - Presenta las tarjetas de los últimos 5 ingresos registrados.
  - Botón `[ Copiar TXT ]`: Copia instantáneamente al portapapeles todos los campos del vehículo en formato tabulado (TSV) listo para pegar en Excel sin desconfigurar columnas.
  - Buscador reactivo por patente, folio, marca o chofer con auto-restauración al limpiar.

#### 5.2 Formulario Continuo con Poka-Yoke: `RecepcionVehiculoScreen`
- **Cabecera Folio Asignado**: Muestra en grande el número correlativo que Gloria debe rayar físicamente con plumón Posca en el vehículo.
- **Switch "Sin Patente (S/PPU)"**: Inhabilita la búsqueda y asigna automáticamente `SPPU-{numeroIngreso}`.
- **Scraping Nativo**: Consulta automática por patente chilena para autocompletar marca, modelo, año, motor y cilindrada.
- **Wrap Responsivo en Datos Técnicos**: La fila con el título y el badge *"Autocompletado activo"* fue migrada de `Row` a `Wrap`, **eliminando el error de desborde de 51px** en Windows y móviles.
- **Aduana Poka-Yoke con Cámara**:
  - Botón `[ 📷 GUARDAR / REGISTRAR INGRESO ]`.
  - Dispara la cámara para fotografiar el número rayado.
  - Validación OCR en backend: si el número coincide, se confirma el guardado; si falla 3 veces, se abre el modal de contingencia manual.

---

### 6. Archivos Creados y Modificados en el Repositorio

| Capa | Archivo | Modificación Realizada |
| :--- | :--- | :--- |
| **BD** | `backend/models.py` | Ampliación de `Vehiculo_Origen` con las 13 columnas A-M. |
| **Backend** | `backend/schemas.py` | DTOs `VehiculoCreate` y `VehiculoRecepcionCreate` actualizados. |
| **Backend** | `backend/routers/vehiculos.py` | Endpoints de multipart OCR, contingencia, correlativo y recientes. |
| **Backend** | `backend/core/security.py` | Permisos RBAC para Rol 9 (`require_recepcion_or_admin`). |
| **Backend** | `backend/scripts/seed_usuario_gloria.py` | Script generador de usuario y credenciales para Gloria. |
| **Backend** | `backend/migracion_vehiculos.py` | Fix transaccional `db.flush()` en inserción masiva. |
| **Frontend** | `frontend/lib/features/recepcion/.../recepcion_home_screen.dart` | Drawer hamburguesa, banner FittedBox, copiado TXT y últimos 5. |
| **Frontend** | `frontend/lib/features/recepcion/.../recepcion_vehiculo_screen.dart` | Formulario continuo, Poka-Yoke OCR, Wrap anti-overflow 51px. |
| **Frontend** | `frontend/lib/features/recepcion/services/recepcion_service.dart` | Cliente HTTP conectado a `ApiConstants.vehiculosEndpoint`. |
| **Frontend** | `frontend/lib/routes/app_routes.dart` | Rutas `/recepcion` y `/recepcion/registro`. |
| **Documentación** | `USUARIOS_ROLES.md` | Tabla y permisos del Rol 9 `Recepción (Patio)`. |

---

### 7. Verificación de Calidad y Tests

- **Flutter Analyze**: 0 errores en `lib/features/recepcion`.
- **Flutter Unit Tests**: 15/15 tests ejecutados exitosamente en `frontend/test/features/`.
- **Ajustes de UI**: Cero desbordes de píxeles (*RenderFlex overflow*) en resoluciones de escritorio Windows y terminales móviles Android.
