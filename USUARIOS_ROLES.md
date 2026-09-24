# Matriz de Usuarios y Credenciales por Rol (Cresal SaaS - Supabase)

Este documento detalla los usuarios activos cargados y sincronizados en la base de datos PostgreSQL de **Supabase**. Cada rol cuenta con un usuario configurado con contraseña segura estandarizada y PIN de acceso rápido para pruebas y operación.

---

## 1. Tabla Resumen de Credenciales

> [!TIP]
> **Contraseña universal para todos los usuarios**: `Password123!`

| Rol ID | Rol / Perfil | Nombre Completo | RUT | Correo Electrónico | Contraseña | PIN | Sucursal | Dispositivo / Entorno | Tema Visual (SSOT) |
|:---:|:---|:---|:---:|:---|:---:|:---:|:---:|:---|:---:|
| **1** | **Bodeguero** | Juan Pablo Bodega Pérez | `16.234.567-8` | `bodega@cresal.cl` | `Password123!` | `1001` | Viña del Mar (1) | PDA Industrial (Sunmi/Zebra) | **Dark Mode** (`ThemeMode.dark`) |
| **2** | **Vendedor (Mesón)** | Carlos Mendoza Silva | `19.876.543-2` | `carlos.mendoza@cresal.cl` | `Password123!` | `2002` | Viña del Mar (1) | Touch POS / All-in-One | **Light Mode** (`ThemeMode.light`) |
| **3** | **Caja** | Lorena Valenzuela Castro | `15.789.123-4` | `lorena.valenzuela@cresal.cl` | `Password123!` | `3003` | Viña del Mar (1) | Desktop POS (Teclado numérico) | **Light Mode** (`ThemeMode.light`) |
| **4** | **Gerente** | Roberto Gerente Silva | `14.567.890-1` | `gerente@cresal.cl` | `Password123!` | `4004` | Viña del Mar (1) | Monitor Ejecutivo (Full HD/2K) | **Light Mode** (`ThemeMode.light`) |
| **5** | **Administrador** | Admin Sistema Cresal | `11.111.111-1` | `admin@cresal.cl` | `Password123!` | `5005` | Viña del Mar (1) | Desktop / Laptop Técnica | **Light Mode** (`ThemeMode.light`) |
| **6** | **Jefe de Ventas** | Gastón Marcelo Zamora Herrera | `21.337.385-4` | `gastonzamoracc@gmail.com` | `Password123!` | `6006` | Viña del Mar (1) | Laptop / Monitor de Ventas | **Light Mode** (`ThemeMode.light`) |
| **7** | **Vendedor Online** | Marcela Online Soto | `12.345.678-9` | `marcela.online@cresal.cl` | `Password123!` | `7007` | Viña del Mar (1) | Desktop Omnicanal | **Light Mode** (`ThemeMode.light`) |
| **8** | **Auditor** *(Gerente Solo Lectura)* | Carlos Gerente Auditor | `13.456.789-0` | `gerenteauditor@cresal.cl` | `Password123!` | `8008` | Viña del Mar (1) | Desktop / Monitor Ejecutivo | **Light Mode** (`ThemeMode.light`) |

---

## 2. Política de Tematización y Ergonomía por Perfil

En la industria de software logístico y retail automotriz, la asignación de tema visual responde a **criterios ergonómicos y de hardware**, nunca al tamaño físico de la ventana:

1. **Bodega y Patio (Rol 1 - Dark Mode Obligatorio)**:
   - Los operarios usan terminales móviles PDA rugerizados (Sunmi L3, Zebra TC series) con pantallas OLED.
   - Operan en ambientes mixtos (patios exteriores de desarme y pasillos de galpón con iluminación tenue).
   - El **Modo Oscuro** reduce el deslumbramiento, incrementa drásticamente la legibilidad de códigos QR/barras bajo contraste y extiende la autonomía de la batería durante turnos de 8 a 10 horas.
2. **Mesón, Caja y Oficinas (Roles 2, 3, 4, 5, 6, 7, 8 - Light Mode Obligatorio)**:
   - Se ejecutan en mostradores de venta, cajas y escritorios gerenciales con iluminación ambiental estándar o fluorescente.
   - El **Modo Claro** optimiza la velocidad de lectura de tablas de órdenes densas, SKUs, facturación y estados financieros sin fatiga visual.
3. **Módulos Compartidos Multi-Rol (Ej: Tickets de Soporte `/tickets`)**:
   - Todo módulo accesible por múltiples roles hereda **el tema del rol autenticado** mediante `ThemeController`.
   - La pantalla **jamás debe forzar un tema por el ancho del monitor**; debe adaptar su layout (compacto vs. expandido) manteniendo la paleta cromática del usuario.

---

## 3. Detalle y Permisos por Rol

### 1. Bodeguero (`id_rol = 1`)
- **Usuario**: `bodega@cresal.cl`
- **PIN**: `1001`
- **UUID (`id_usuario`)**: `6f945e0c-8262-419c-8b8c-258b110bef16`
- **Ruta Principal**: `/home`
- **Módulos y Rutas Habilitadas**:
  - `/home`: Panel operativo de bodega.
  - `/recepcion`: Recepción física de vehículos e ingreso OCR.
  - `/paletizado`: Desarme y paletizado de repuestos con OCR/Manual.
  - `/etiqueta-preview`: Previsualización e impresión térmica con QR.
  - `/alertas`: Bandeja reactiva de alertas de preparación y traslados.
  - `/reingresos`: Logística Inversa y reingreso de piezas tras anulación de órdenes.
  - `/buscador`: Búsqueda y trazabilidad rápida de repuestos por pasillo/pallet.
  - `/tickets`: Soporte y mesa de ayuda interna.

---

### 2. Vendedor Mesón (`id_rol = 2`)
- **Usuario**: `carlos.mendoza@cresal.cl` *(Alternativo: `vendedor@cresal.cl` / PIN: `1234`)*
- **PIN**: `2002`
- **UUID (`id_usuario`)**: `6fa2f5a2-0edc-46e0-a7b2-fbea610b6a2c`
- **Ruta Principal**: `/ventas_main`
- **Módulos y Rutas Habilitadas**:
  - `/ventas_main`: Layout principal de ventas (Catálogo, Radar de Stock, Carrito, Historial).
  - `/catalogo`: Búsqueda multicriterio de piezas con radar de stock local/inter-sucursal.
  - `/checkout_crm`: Registro de clientes CRM, emisión de órdenes y tickets térmicos.
  - Historial y detalle de órdenes con función **"Deshacer Orden"** (Anulación ACID y reversa de pagos).
  - `/entregas-envios`: Módulo de despacho y entrega a clientes.

---

### 3. Caja (`id_rol = 3`)
- **Usuario**: `lorena.valenzuela@cresal.cl`
- **PIN**: `3003`
- **UUID (`id_usuario`)**: `78017700-5d8e-4991-a25f-59708426c085`
- **Ruta Principal**: `/caja`
- **Módulos y Rutas Habilitadas**:
  - `/caja`: Panel de caja escritorio optimizado para teclado numérico.
  - Bandeja de Cobros pendientes de órdenes de mesón y backorders.
  - Procesamiento de pagos (Efectivo, Tarjeta Débito/Crédito, Transferencia) y Split Payments.
  - Historial de transacciones y resumen de cuadre de caja diario.

---

### 4. Gerente (`id_rol = 4`)
- **Usuario**: `gerente@cresal.cl`
- **PIN**: `4004`
- **UUID (`id_usuario`)**: `7c25d4ec-99e9-4878-b6b6-b042328dcdf2`
- **Ruta Principal**: `/home` (con acceso global)
- **Módulos y Rutas Habilitadas**:
  - Acceso irrestricto a todos los módulos operativos y de ventas.
  - Supervisión de métricas, pedidos, auditoría de stock y logística.

---

### 5. Administrador (`id_rol = 5`)
- **Usuario**: `admin@cresal.cl`
- **PIN**: `5005`
- **UUID (`id_usuario`)**: `5ea60614-00e4-41c3-b53a-60cebfdadfbf`
- **Ruta Principal**: `/home` (con acceso global)
- **Módulos y Rutas Habilitadas**:
  - Acceso total e irrestricto a todos los endpoints y pantallas.
  - Registro y administración de usuarios (`POST /api/auth/register`).
  - Gestión de sucursales, auditorías de salida y configuración general.

---

### 6. Jefe de Ventas (`id_rol = 6`)
- **Usuario**: `gastonzamoracc@gmail.com`
- **PIN**: `6006`
- **UUID (`id_usuario`)**: `8d97a2c3-cea1-4983-8947-5f6cb2bec1cc`
- **Ruta Principal**: `/ventas_main`
- **Módulos y Rutas Habilitadas**:
  - `/ventas_main`: Módulo integral de ventas.
  - `/bandeja_precios`: Bandeja de tasación y asignación de precios de venta para piezas recién paletizadas (HU-3.8).
  - Anulación de ventas y control de descuentos especiales.

---

### 7. Vendedor Online (`id_rol = 7`)
- **Usuario**: `marcela.online@cresal.cl`
- **PIN**: `7007`
- **UUID (`id_usuario`)**: `ed7fb6c5-dd36-4e14-b6d7-f44d19cdf29e`
- **Ruta Principal**: `/ventas_main`
- **Módulos y Rutas Habilitadas**:
  - `/ventas_main`: Ventas digitales y catálogo omnicanal.
  - `/entregas-envios`: Coordinación de envíos a regiones (Starken, Chilexpress, Blue Express).
  - `/checkout_crm`: Creación de ventas con dirección de despacho.

---

### 8. Auditor / Gerente Solo Lectura (`id_rol = 8`)
- **Usuario**: `gerenteauditor@cresal.cl`
- **PIN**: `8008`
- **UUID (`id_usuario`)**: `8f41e0a1-7b82-4912-9c13-a41b89ef4128`
- **Ruta Principal**: `/gerencia` (Dashboard Ejecutivo)
- **Tema Visual**: Light Mode (`ThemeMode.light`)
- **Módulos y Rutas Habilitadas (Solo Lectura)**:
  - `/gerencia`: Panel Ejecutivo y Analítica en Tiempo Real (HU-5.1).
  - Pestaña **Dashboard**: Supervisión de KPIs de facturación, márgenes comerciales, métodos de pago y flujo de despachos.
  - Pestaña **Órdenes**: Visor histórico centralizado y auditoría forense 360° de ventas (HU-5.2).
  - Pestaña **Inventario**: Consulta multi-sucursal y filtros del maestro de repuestos y activos (HU-5.3).
  - Pestaña **Backorders**: Supervisión de compras por encargo, abonos y saldos pendientes (HU-5.4).
- **Restricciones Explícitas de Seguridad (Zero Trust)**:
  - ❌ **Sin permisos de tasación**: No puede fijar ni actualizar precios comerciales de repuestos (`verificar_rol_tasacion` emite `403 Forbidden`). En la interfaz se ocultan automáticamente los botones de "Tasar" y "Precio".
  - ❌ **Sin anulación de ventas ni emisiones**: No puede anular órdenes de venta ni registrar transacciones operativas.
  - ❌ **Sin operaciones de bodega ni caja**: No puede liberar repuestos ni registrar cobros físicos.

---

## 4. Flujo de Inicio de Sesión

1. **Primer Ingreso (Enrolamiento de Terminal)**:
   - Ingresar con **Correo Electrónico** y **Contraseña** (`Password123!`).
   - El sistema almacena la sesión de forma segura y vincula el terminal al usuario.
   - Redirige inmediatamente a la pantalla principal correspondiente a su rol.

2. **Reingreso Rápido (Desbloqueo por PIN)**:
   - En aperturas posteriores o tras bloqueo por inactividad, ingresar el **PIN de 4 dígitos** asignado en el teclado numérico industrial.
   - El sistema valida el PIN vinculado y genera un nuevo token JWT de sesión.
