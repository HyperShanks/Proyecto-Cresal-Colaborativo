# Guía de Instalación, Pruebas y Roles — Sistema Cresal

> **Proyecto Colaborativo** — Plataforma integral de gestión de desarme, inventario, ventas (mesón/caja), logística en bodega (PDA) y analítica gerencial para **Cresal**.

---

## 1. Requisitos e Instalación Rápida (Entorno de Pruebas)

La aplicación cliente ya viene **preconfigurada y conectada al servidor backend de pruebas en la nube**, por lo que **no requiere levantar servidores locales ni configurar variables de entorno** para probarla.

1. Descarga el instalador **`Cresal_Setup.exe`** desde la sección **Releases** de este repositorio.
2. Ejecuta `Cresal_Setup.exe` en **Windows 10 / 11 (64 bits)** y sigue el asistente de instalación.
3. Abre **Cresal** desde el acceso directo del escritorio o menú Inicio.
4. En la pantalla de enrolamiento / inicio de sesión, utiliza cualquiera de las credenciales de prueba indicadas abajo.

> [!NOTE]
> * El entorno de pruebas utiliza una base de datos aislada sin información comercial real de clientes.
> * El sistema cuenta con inicio de sesión por **Correo + Contraseña** (enrolamiento inicial del terminal) y luego acceso rápido mediante **PIN de 4 dígitos**.

---

## 2. Credenciales de Prueba por Rol

| Rol ID | Perfil | Correo Electrónico | Contraseña | PIN | Sucursal |
| :---: | :--- | :--- | :---: | :---: | :--- |
| **1** | **Bodeguero** | `bodega@cresal.cl` | `Password123!` | `1001` | Viña del Mar (1) |
| **2** | **Vendedor (Mesón)** | `carlos.mendoza@cresal.cl` | `Password123!` | `2002` | Viña del Mar (1) |
| **2** | **Vendedor (Limache)** | `limache@cresal.cl` | `Password123!` | `2020` | Limache (2) |
| **3** | **Caja** | `lorena.valenzuela@cresal.cl` | `Password123!` | `3003` | Viña del Mar (1) |
| **4** | **Gerente** | `gerente@cresal.cl` | `Password123!` | `4004` | Viña del Mar (1) |
| **5** | **Administrador** | `admin@cresal.cl` | `Password123!` | `5005` | Viña del Mar (1) |
| **7** | **Vendedor Online** | `marcela.online@cresal.cl` | `Password123!` | `7007` | Viña del Mar (1) |
| **8** | **Auditor (Solo Lectura)** | `gerenteauditor@cresal.cl` | `Password123!` | `8008` | Viña del Mar (1) |
| **9** | **Recepción (Patio)** | `gloria@cresal.cl` | `RecepcionApp2026-16` | `4598` | Viña del Mar (1) |

*(Nota: Para desenrolar un terminal y cambiar de usuario, presiona el botón **Desenrolar** en la pantalla de PIN).*

---

## 3. ¿Qué funciones puedes probar en cada Rol?

### 📦 Rol 1 — Bodeguero (`bodega@cresal.cl` / PIN `1001`)
* **Desarme y Paletizado (`/paletizado`)**: Registrar piezas extraídas de vehículos donantes (motores, cajas de cambio, accesorios), asignar ubicación física (galpón, pasillo, pallet) y generar etiqueta con código **QR**.
* **Buscador e Inventario (`/buscador`)**: Consultar disponibilidad, estado y ubicación exacta de repuestos por SKU o palabra clave.
* **Bandeja de Alertas (`/alertas`)**: Ver órdenes reservadas/pagadas para bajar piezas del rack (`LISTO`) y ejecutar la **Barrera Digital de Salida** (escaneo dual QR orden + QR pieza).
* **Reingresos (`/reingresos`)**: Logística inversa para reingresar repuestos al stock tras anulación de órdenes.
* **Tickets de Soporte (`/tickets`)**: Reportar incidencias operativas internas.

### 🛒 Rol 2 y 7 — Vendedor Mesón / Limache / Online (`carlos.mendoza@cresal.cl` / PIN `2002`)
* **Catálogo de Ventas (`/catalogo`)**: Buscar repuestos disponibles con filtros por categoría, sucursal y estado, ver galería fotográfica y precios.
* **Carrito y Checkout Wizard (`/carrito`)**: Crear órdenes de venta asociando cliente (con validación de RUT Módulo 11), aplicar descuentos dentro de rango, registrar despacho/retiro o generar **Backorders (Venta en Verde)**.
* **Historial de Órdenes (`/historial`)**: Consultar estados (`Reservada`, `Pagada`, `Completada`, `Anulada`), imprimir ticket QR de retiro o anular órdenes con justificación.

### 💰 Rol 3 — Caja (`lorena.valenzuela@cresal.cl` / PIN `3003`)
* **Bandeja de Cobros (`/caja`)**: Visualizar en tiempo real (con actualización SSE) las órdenes pendientes de pago o abono.
* **Liquidación de Pagos**: Registrar pagos totales o abonos parciales (efectivo, débito, crédito, transferencia) liberando automáticamente la orden para entrega en bodega.
* **Historial y Edición Auditada de Caja**: Revisar cuadratura diaria, historial de transacciones y editar pagos/métodos dejando traza forense obligatoria (`Auditoria_Edicion_Pago`).

### 📊 Rol 4 y 8 — Gerente / Auditor (`gerente@cresal.cl` / PIN `4004`)
* **Dashboard Ejecutivo (`/gerencia`)**: KPIs de ventas, distribución por medios de pago, rendimiento por sucursal y **Proyección Financiera con Machine Learning (XGBoost)**.
* **Inventario Maestro y Tasación**: Detectar cuellos de botella (piezas sin tasar) y definir precio de referencia, mínimo y máximo.
* **Visor de Órdenes y Backorders**: Auditoría 360° de órdenes, anulaciones y reservas pendientes *(el Rol 8 Auditor opera en modo solo lectura)*.

### 🚗 Rol 9 — Recepción Patio (`gloria@cresal.cl` / PIN `4598`)
* **Ingreso de Vehículos Donantes (`/recepcion`)**: Registrar vehículos que ingresan a desarme (patente, VIN, marca, modelo, año, número de motor, factura, destino y grúa) generando el correlativo de ingreso.

### ⚙️ Rol 5 — Administrador (`admin@cresal.cl` / PIN `5005`)
* **Control Total**: Acceso transversal a todos los módulos operativos, gestión y resolución de **Tickets de Soporte**, supervisión de tasaciones, caja y auditoría del sistema.
