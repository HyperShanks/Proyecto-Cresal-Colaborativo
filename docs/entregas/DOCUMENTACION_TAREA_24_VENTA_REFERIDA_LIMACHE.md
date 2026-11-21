# DOCUMENTACIÓN TÉCNICA — TAREA 24
## Emisión de Ventas Referidas a Sucursal Limache con Persistencia y Trazabilidad en "Mis Órdenes"

---

### 1. Resumen Ejecutivo y Necesidad Operativa

La **Tarea 24** aborda la operativa comercial inter-sucursal de **Cresal Repuestos**, permitiendo que un vendedor de mesón en **Viña del Mar** (`id_sucursal = 1`) emita cotizaciones y órdenes de repuestos asignándolas al perfil comercial **"Limache"** (`id_sucursal = 2`).

#### Problema que resuelve:
1. **Pérdida de Seguimiento del Vendedor Emisor**:
   En el flujo regular de ventas referidas, cuando el Vendedor A asigna una orden al Vendedor B, la orden se transfiere íntegramente y desaparece de la bandeja "Mis Órdenes" del Vendedor A.
   En ventas cruzadas donde clientes de Limache compran piezas que físicamente están en Viña del Mar, el vendedor de mesón que gestionó la atención presencial necesita mantener la orden en su pantalla para monitorear en tiempo real si el cliente ya pagó en caja, si bodega despachó la pieza o si la orden fue retirada en barrera.
2. **Atribución Comercial y Comisiones**:
   Para no alterar las comisiones del personal de Viña del Mar, la venta debe imputarse formalmente a la sucursal de destino comercial ("Limache"). El emisor debe conservar la **trazabilidad operativa** sin adjudicarse la comisión económica.
3. **Disponibilidad Transversal del Usuario Comercial**:
   Al filtrar vendedores por sucursal en el selector de checkout, los vendedores de Viña del Mar no veían usuarios de Limache. Se requiere que el usuario "Limache" esté siempre disponible como opción de destino comercial.

---

### 2. Modelo de Datos y Usuario Comercial "Limache" (Supabase / PostgreSQL)

#### 2.1 Especificación del Registro en Tabla `Usuario`

Se incorpora el usuario comercial representativo para la Sucursal Limache:

| Campo | Valor / Configuración | Propósito |
| :--- | :--- | :--- |
| `id_usuario` | `UUID` (autogenerado / fijo) | Identificador único relacional en PostgreSQL. |
| `id_rol` | `2` (`Vendedor`) | Habilitado comercialmente para emisión, titularidad y reportes. |
| `id_sucursal` | `2` (`Limache`) | Asignado formalmente a la Sucursal Limache (Patio / Desarme). |
| `rut_usuario` | `77.888.999-4` | RUT corporativo validado con algoritmo Módulo 11 chileno. |
| `nombres` | `Ventas` | Nombre de pila comercial. |
| `apellidos` | `Limache` | Distintivo de la sucursal. |
| `email` | `limache@cresal.cl` | Correo corporativo institucional. |
| `password_hash` | Hash bcrypt (`Password123!`) | Contraseña universal del sistema. |
| `pin_acceso` | `2020` | PIN de 4 dígitos para inicio de sesión rápido. |
| `estado` | `'Activo'` | Usuario operativo en el sistema. |

#### 2.2 Relación de Titularidad en `Orden_Venta`

- **`Orden_Venta.id_vendedor`**: Se fija al `id_usuario` de **Limache** (`limache@cresal.cl`). Es la clave que utilizan los módulos de gerencia, finanzas y caja para imputar la venta y comisiones.
- **`Orden_Venta.id_vendedor_asignado`**: Se fija al `id_usuario` del **vendedor de Viña del Mar** que operó el mesón y creó la orden. Permite identificar al responsable operativo de la atención.

---

### 3. Reglas de Backend (FastAPI)

#### 3.1 Disponibilidad en Selector: `GET /api/v1/ordenes/vendedores`
- **Regla**: El endpoint debe incluir siempre al usuario comercial `limache@cresal.cl` en la lista de opciones retornadas, independientemente del parámetro `sucursal_id` recibido en la consulta.
- **Implementación**:
  ```python
  if sucursal_id is not None:
      query = query.filter(
          or_(
              Usuario.id_sucursal == sucursal_id,
              func.lower(Usuario.email) == "limache@cresal.cl",
              func.lower(Usuario.apellidos).like("%limache%"),
          )
      )
  ```

#### 3.2 Regla de Visibilidad en "Mis Órdenes": `GET /api/v1/ordenes/mis-ventas`
El endpoint segmenta la visibilidad según dos reglas estrictas:
1. **Regla Estándar (Otros Vendedores)**:
   Si el Vendedor A emite una orden asignándola al Vendedor B, la orden tiene `id_vendedor = Vendedor B`. Vendedor A no cumple `Orden_Venta.id_vendedor == current_user.id_usuario`, por lo que **se oculta** de su bandeja (comportamiento original garantizado).
2. **Regla Excepcional (Limache)**:
   Si el Vendedor A emite una orden asignándola a **Limache**:
   - `id_vendedor = Limache`
   - `id_vendedor_asignado = Vendedor A`
   - La consulta filtra con condición `or_`:
     ```python
     condicion_visibilidad = or_(
         Orden_Venta.id_vendedor == current_user.id_usuario,
         and_(
             Orden_Venta.id_vendedor == id_usuario_limache,
             Orden_Venta.id_vendedor_asignado == current_user.id_usuario,
         )
     )
     ```
   - **Resultado**: La orden permanece visible tanto en la bandeja del vendedor emisor (Viña) como en la bandeja de entrada del usuario Limache.

#### 3.3 DTO de Salida: `OrdenHistorialItemResponse`
Se expone el campo `es_asignada_limache: bool`:
- `true`: Cuando la orden pertenece comercialmente a Limache pero fue emitida por el usuario solicitante.
- `false`: En ventas directas propias o cuando el usuario logueado es el propio titular Limache.

---

### 4. Componentes y UI en Frontend (Flutter)

#### 4.1 Selector de Titularidad en Checkout Wizard (`checkout_wizard_screen.dart`)
- En el dropdown de vendedores titulares, "Limache" se presenta como opción seleccionable con etiqueta destacada de sucursal.
- Al seleccionarse, `id_vendedor_titular` viaja con el ID de Limache y `id_vendedor_asignado` viaja con el ID del vendedor emisor.

#### 4.2 Distintivo Visual en `OrdenCard` (`orden_card.dart` e `historial_screen.dart`)
- En el listado de "Mis Órdenes", las ventas con `esAsignadaLimache == true` despliegan una insignia visual junto al folio:
  ```text
  [📍 Asignada a Limache]
  ```
- **Estilo Visual**:
  - Color ámbar cálido (`Color(0xFFD97706)` con fondo translúcido `0xFFF59E0B`).
  - Icono alusivo a tienda/sucursal (`Icons.storefront_outlined`).
  - Texto con tipografía semi-negrita de 11 pt para no sobrecargar la tarjeta.

#### 4.3 Visor de Detalle (`OrdenDetailSheet`)
- Muestra una nota informativa indicando que la venta está comisionada a la Sucursal Limache y que el vendedor actual mantiene el seguimiento operativo.

---

### 5. Atribución Comercial, Reportes y Cierres de Turno

- **Liquidación de Comisiones**:
  Los reportes en [backend/routers/gerencia.py](file:///d:/CresalRepoCapstone/backend/routers/gerencia.py) y las consultas de cuadratura en [backend/routers/caja.py](file:///d:/CresalRepoCapstone/backend/routers/caja.py) filtran por `Orden_Venta.id_vendedor`.
- **Cero Impacto en Viña**:
  El monto de la venta no suma a las comisiones del vendedor de Viña del Mar, salvaguardando la integridad contable solicitada por el negocio.

---

### 6. Criterios de Aceptación (Definition of Done)

- [x] **Disponibilidad de Usuario**: El usuario `limache@cresal.cl` figura como opción seleccionable al asignar o referir una venta en el catálogo y checkout.
- [x] **Persistencia en "Mis Órdenes"**: Al emitir una orden asignada a "Limache", el vendedor emisor la sigue visualizando dentro de su historial de "Mis Órdenes".
- [x] **Identificación Visual**: La orden en "Mis Órdenes" cuenta con el badge `[📍 Asignada a Limache]`.
- [x] **Mantenimiento del Flujo Regular**: Si la venta se asigna a cualquier otro vendedor convencional (ej. Juan asigna a Pedro), la orden sigue ocultándose de Juan.
- [x] **Imputación Comercial Exacta**: Los reportes de ventas y comisiones asignan la venta al usuario "Limache" y no al vendedor emisor.
- [x] **Validación Automatizada**: Cobertura de pruebas unitarias y de integración en backend (pytest) y frontend (Flutter).
