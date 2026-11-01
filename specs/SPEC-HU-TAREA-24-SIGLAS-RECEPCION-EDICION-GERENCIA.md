# SPEC-HU-TAREA-24: Siglas de Motor en Corchetes, Desactivación de Llenado Rápido de Modelo en Recepción y Edición Integral de Piezas en Gerencia

## 1. Contexto y Objetivos

Actualmente, el flujo de ingreso vehicular y de piezas a la plataforma parte desde la aplicación de **Recepción Vehicular**:
1. Al recepcionar un vehículo, se registran sus datos (patente o S/PPU, marca, modelo, año, número de motor, transmisión, combustible, tracción, etc.).
2. Paralelamente, se instancian sus dos activos base iniciales:
   - **Motor** (`id_categoria == 1`), en estado "En Desarme".
   - **Caja de Cambios** (`id_categoria == 2`), en estado "En Desarme".
3. Posteriormente, en el módulo de **Bodega**, al paletizar o tras paletizar, el bodeguero cuenta con la opción de editar los datos del activo y de forzar el ingreso cuando faltan datos obligatorios.

Esta especificación aborda tres mejoras operativas críticas solicitadas por el negocio:
1. **Identificador de Motor con Siglas entre Corchetes `[XXXX]`**:
   - En el nombre/título de cada motor (y **únicamente en motores**), debe incorporarse al final, entre corchetes `[ ]`, las primeras 4 siglas/caracteres alfanuméricos de su número de motor (ej: `Motor - Toyota Yaris 2018 [1NZF]`).
   - Cajas de cambios y otras piezas no llevan corchetes ni siglas de motor en su título.
2. **Eliminación del Llenado Rápido Automático por Modelo en Recepción**:
   - Eliminar el mecanismo de inferencia reactiva que completaba automáticamente cilindrada, transmisión, combustible y tracción según lo que se escribía en el campo de modelo.
   - Eliminar el distintivo visual *"Autocompletado activo"*.
   - El operario debe completar todas las especificaciones a mano mediante los selectores y campos correspondientes.
   - **Se mantiene 100% operativo el Web Scraping por Patente** para recuperar los datos registrales iniciales.
3. **Edición Integral de Piezas (Motor, Caja y Vehículo Origen) en Inventario de Gerencia**:
   - Dotar a la vista de Inventario de Gerencia (`inventario_gerencia_view.dart`) de la capacidad de editar cualquier pieza (tanto en vista de tarjetas como en vista de tabla).
   - La edición debe permitir modificar tanto los datos del vehículo donante (`marca`, `modelo`, `año`, `tracción`, `número de motor`) como los datos técnicos específicos de la pieza (`combustible`, `transmisión`, `cilindrada`, `número de motor propio`), su ubicación física en bodega (`galpón`, `pasillo`, `pallet`) y sus observaciones.
   - Habilitar permisos en backend (`PATCH /api/v1/inventario/{id_activo}`) para roles de Gerencia (`id_rol == 4`) y Administrador (`id_rol == 5`), eliminando bloqueos de estado restrictivos para perfiles gerenciales.

---

## 2. Requerimiento 1: Siglas del Número de Motor en Corchetes `[ ]`

### 2.1 Regla de Normalización y Extracción
Para un activo con categoría Motor (`id_categoria == 1` o `nombre_categoria == 'Motor'`):
1. Si el motor tiene un `numero_motor` válido (no nulo, no vacío, distinto de `"S/A"`, `"N/A"`, `"SN"`, `"NULL"`):
   - Se limpian caracteres no alfanuméricos (guiones, espacios, puntos): `clean = re.sub(r'[^A-Za-z0-9]', '', numero_motor).upper()`.
   - Se extraen hasta los primeros 4 caracteres: `sigla = clean[:4]`.
   - Si `sigla` tiene entre 1 y 4 caracteres, se añade ` [SIGLA]` al final del título.
2. Si el motor no posee número de motor o es inválido, el título se genera sin corchetes.
3. Para cualquier categoría distinta de Motor (como Caja de Cambios `id_categoria == 2`), **NUNCA** se agregan corchetes ni siglas de motor.

### 2.2 Puntos de Integración
- **Frontend**:
  - `CatalogoItem.tituloRepuesto`: añade ` [SIGLA]` si es motor y tiene número de motor.
  - `CatalogoItem.tituloVehiculo`: añade ` [SIGLA]` si es motor y tiene número de motor (usado en la tabla de inventario de gerencia).
  - `ResultadoCard` (Bodega): muestra el título con ` [SIGLA]` si es motor.
- **Backend**:
  - `backend/routers/inventario.py`: función `extraer_siglas_motor(numero_motor)` aplicada en `obtener_activos_pendientes_precio` (`titulo_repuesto`).
  - `backend/routers/bodega.py`: aplicada en generación de `titulo_pieza` para motores.
  - `backend/routers/ordenes.py`: aplicada en generación de `titulo_item` para motores.

---

## 3. Requerimiento 2: Desactivación de Llenado Rápido por Modelo en Recepción

### 3.1 Comportamiento Anterior vs. Nuevo
| Aspecto | Comportamiento Anterior | Nuevo Comportamiento Requerido |
| :--- | :--- | :--- |
| **Escritura en Modelo/Marca** | Ejecutaba `_inferirEspecificacionesDesdeModelo()` en cada pulsación (`onChanged`), rellenando automáticamente transmisión, tracción, combustible y cilindrada. | **Se elimina por completo el listener reactivo**. La escritura de marca y modelo no modifica ningún otro campo. |
| **Badge en UI** | Mostraba *"Autocompletado activo"* con icono de varita mágica `Icons.auto_awesome`. | **Se elimina el badge**. Toda la captura técnica es manual. |
| **Selección de Datos** | Valores sobreescritos por inferencia de texto. | **Selección 100% manual**: el operario debe elegir manualmente el combustible, la transmisión y la tracción en los dropdowns, e ingresar la cilindrada. |
| **Scraping por Patente** | Al consultar patente, poblaba campos y ejecutaba `_inferirEspecificacionesDesdeModelo()`. | **Se mantiene intacto el scraping de patente**, pero **NO** ejecuta inferencia automática derivada del modelo. |

---

## 4. Requerimiento 3: Edición Integral de Piezas en Inventario de Gerencia

### 4.1 Modificaciones en Backend (`PATCH /api/v1/inventario/{id_activo}`)
1. **Control de Acceso RBAC**:
   - Se reemplaza la dependencia restrictiva `require_bodeguero_or_admin` por `require_inventario_editor`, permitiendo:
     - Bodeguero (`id_rol == 1`)
     - Gerencia (`id_rol == 4`)
     - Administrador (`id_rol == 5`)
     - Jefe de Ventas (`id_rol == 6`)
   - Se preserva el bloqueo `403 Forbidden` para Vendedores (`id_rol == 2`) y Caja (`id_rol == 3`).
2. **Flexibilidad de Estados para Gerencia**:
   - Mientras los bodegueros mantienen la regla de solo poder editar activos en estado "Disponible" (1) o "Paletizado" (7), los usuarios con rol Gerencia (4) o Administrador (5) pueden editar cualquier pieza registrada para rectificar errores de catálogo en cualquier estado activo.
3. **Persistencia Bidireccional de Vehículo Donante y Pieza**:
   - Datos de `Vehiculo_Origen`: `marca`, `modelo`, `anio`, `traccion`, `numero_motor`.
   - Datos de `Detalle_Motor`: `cilindrada`, `combustible`, `transmision_tipo`, `numero_motor`.
   - Datos de `Detalle_Caja_Cambio`: `transmision_tipo`.
   - Sincronización entre piezas del mismo vehículo cuando corresponda.

### 4.2 Modificaciones en Frontend (`inventario_gerencia_view.dart`)
1. **Modo Tarjetas**:
   - Incorporar un botón interactivo **"Editar"** (`Icons.edit_note`) junto al botón de Tasación.
2. **Modo Tabla**:
   - Incorporar en la columna de acción un botón/icono **"Editar"** que abra el modal de edición de datos de la pieza.
3. **Modal de Edición Integral**:
   - Modal bottom sheet con scroll que presenta:
     - Sección 1: Datos Vehiculares (`marca`, `modelo`, `año`, `tracción`, `número de motor`).
     - Sección 2: Especificaciones Técnicas (`combustible`, `transmisión`, `cilindrada`).
     - Sección 3: Ubicación Física (`galpón`, `pasillo`, `pallet`) y Observaciones.
   - Validación de cambios (dirty checking), guardado con `InventarioService.editarActivo` y recarga reactiva de la grilla sin perder filtros ni paginación.

---

## 5. Plan de Pruebas y Validación

1. **Pruebas de Siglas de Motor**:
   - Motores con número tipo `1NZ-FE-9921` deben generar `[1NZF]`.
   - Motores con número tipo `1GD-1234567` deben generar `[1GD1]`.
   - Motores con número corto `1NZ` deben generar `[1NZ]`.
   - Cajas de cambio no deben mostrar corchetes bajo ninguna circunstancia.
2. **Pruebas de Recepción Manual**:
   - Al tipear un modelo como `YARIS GLI 1.5 AT 4X2` no deben alterarse automáticamente los desplegables de transmisión, combustible ni tracción.
   - El botón de scraping por patente debe seguir rellenando los datos del vehículo correctamente.
3. **Pruebas de Edición en Gerencia**:
   - Usuario con rol Gerencia (`id_rol == 4`) debe poder ejecutar `PATCH /api/v1/inventario/{id_activo}` y recibir `200 OK`.
   - Cambios en marca, modelo, año, número de motor y transmisión deben verse reflejados de inmediato en la tarjeta y en la tabla.
   - Usuario con rol Vendedor (`id_rol == 2`) debe seguir recibiendo `403 Forbidden`.
