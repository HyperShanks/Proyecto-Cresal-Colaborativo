# Sistema Integral de Refrescos y Sincronización Silenciosa por Rol

> **Documento Oficial de Arquitectura y Comportamiento de Refrescos**  
> **Versión:** 1.0 (Post Auditoría e Implementación Global)  
> **Módulos:** Bodega PDA, Ventas, Caja y Gerencia  
> **Referencia Técnica:** `SPEC-HU-TAREA-21-POLLING-SILENCIOSO.md`

---

## 1. Visión General y Filosofía de Diseño

### 1.1 El Problema del Modelo Antiguo
En las versiones iniciales, la aplicación recurría a recargas forzadas e incondicionales ante cualquier interacción del usuario:
- Cada cambio de pestaña o vista disparaba llamadas HTTP destructivas con `setState(() => _cargando = true)`.
- La interfaz parpadeaba y se reemplazaba con pantallas en blanco o indicadores centrales de carga (`CircularProgressIndicator`).
- Al abrir y cerrar un modal o tarjeta de detalle (incluso sin mutar datos), `didPopNext()` ejecutaba una recarga agresiva.
- En tablas paginadas (Caja, Órdenes de Gerencia, Inventario), los refrescos **reseteaban la navegación a la página 1**, expulsando al usuario del registro que estaba auditando.
- En Caja, un refresco en segundo plano podía **deseleccionar la orden** que la cajera estaba cobrando o borrar los métodos de pago digitados.

### 1.2 Los 4 Pilares del Nuevo Sistema de Refresco

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                           ARQUITECTURA DE REFRESCOS                              │
├───────────────────────┬────────────────────────┬─────────────────────────────────┤
│ 1. Silent Polling     │ 2. In-Memory Merge     │ 3. UI Protection Guards         │
│ (Sondeo en Background)│ (Reconciliación Viva)  │ (Pausa Inteligente en Formulario│
├───────────────────────┴────────────────────────┴─────────────────────────────────┤
│                       4. IndexedStack & Keep-Alive (60 FPS)                      │
│                  (Cambio de Pestañas a 0ms sin Destruir Estado)                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

1. **Silent Polling (Sondeo Silencioso Periódico):** Peticiones en segundo plano gobernadas por `SilentPollingManager`. Las respuestas actualizan los datos en pantalla sin spinners ni alertas sonoras invasivas.
2. **Reconciliación en Memoria (In-Memory Merge):** Si ya existen datos visuales (`_items.isNotEmpty`), el estado de carga (`_isLoading`) nunca oculta la información actual. La lista se refresca fluidamente sin parpadeos.
3. **Persistencia con `IndexedStack` (0ms / 60 FPS):** Las subvistas del panel permanecen instanciadas en memoria. Cambiar de pestaña no destruye la vista ni resetea la posición del scroll, los filtros aplicados o el número de página.
4. **Guardas de Seguridad en UI Activa:** El sondeo se suspende automáticamente si el usuario está interactuando con formularios críticos (cobro de caja, fijación de precios en modal) o si la aplicación móvil pasa a segundo plano (`AppLifecycleState.paused`).

---

## 2. Detalle Exhaustivo por Rol y Pantalla

---

### 📦 ROL 1: BODEGUERO (Bodega PDA)

El rol de bodega opera en terminales móviles o PDA industriales con lectores de código de barras / QR. Requiere máxima velocidad operativa sin bloqueos de pantalla.

#### 1. Alertas de Tareas de Bodega (`AlertasScreen`)
- **Ruta / Archivo:** `frontend/lib/features/alertas/presentation/screens/alertas_screen.dart`
- **Vistas internas:** Tabs de *Despacho*, *Devoluciones* y *Reingreso*.
- **Comportamiento del Toggle / Cambio de Pestaña:**
  - **100% en memoria:** Las tareas se encuentran en una lista local `_tareas`. Alternar entre tipos de tarea no realiza ninguna petición HTTP ni activa spinners.
  - La transición es instantánea a **60 FPS** sin congelar el hilo principal.
- **Sistema de Refresco:**
  - **Sondeo Silencioso:** Cuenta con un `SilentPollingManager` con intervalo de **15 segundos**.
  - **Reconciliación:** Si el despachador o el sistema asigna una nueva tarea, la lista se actualiza silenciosamente en segundo plano.
  - **Navegación Retorno (`didPopNext`):** Al volver a la pantalla tras atender una tarea, se ejecuta un refresco silencioso no destructivo sin bloquear los botones táctiles.
- **Guardas de Ahorro Energético:**
  - Si el bodeguero bloquea el terminal o minimiza la app (`paused`), el sondeo se detiene para no agotar la batería del dispositivo.

#### 2. Reingreso de Tareas (`ReingresoTareasScreen`)
- **Ruta / Archivo:** `frontend/lib/features/bodega/presentation/screens/reingreso_tareas_screen.dart`
- **Comportamiento:** Diálogos modales protegidos. Si el bodeguero pulsa "Cancelar", la pantalla **no** dispara peticiones a la API ni resetea el formulario.

---

### 🏷️ ROL 2: VENDEDOR (Ventas Móvil / Tablet)

El vendedor consulta repuestos, arma carritos de venta, gestiona pedidos pendientes y revisa precios de activos en tasación comercial.

#### 1. Navegador Principal (`VentasMainScreen`)
- **Ruta / Archivo:** `frontend/lib/features/ventas/presentation/screens/ventas_main_screen.dart`
- **Vistas integradas:** *Catálogo*, *Mis Órdenes*, *Tasación de Precios*, *Entregas/Envíos* y *Carrito*.
- **Comportamiento de Navegación:**
  - Conmutación no destructiva mediante BottomNavigationBar.
  - Al cambiar de pestaña, se invoca `refrescarCatalogoSilencioso()`, `refrescarSilencioso()` o `_cargarDatosSilencioso()`, **sin reiniciar paginaciones** ni borrar los criterios de búsqueda que el vendedor tenía escritos.

#### 2. Catálogo de Repuestos (`CatalogoScreen`)
- **Ruta / Archivo:** `frontend/lib/features/ventas/presentation/screens/catalogo_screen.dart`
- **Sistema de Refresco:**
  - **Sondeo Silencioso:** `SilentPollingManager` cada **30 segundos**.
  - **Sincronización Reactiva:** Escucha al `OrdenesSyncNotifier`. Cuando otra terminal reserva o vende un repuesto, el catálogo descuenta el stock en background.
  - **Preservación UI:** No resetea el scroll del catálogo ni la página en la que se encuentra navegando el vendedor.

#### 3. Historial de Órdenes del Vendedor (`HistorialScreen`)
- **Ruta / Archivo:** `frontend/lib/features/ventas/presentation/screens/historial_screen.dart`
- **Sistema de Refresco:**
  - **Sondeo Silencioso:** Sondeo cada **15 segundos** con `SilentPollingManager`.
  - **Modales de Ficha de Orden:** Protegidos con la guarda `_isModalAbierto`. Abrir y cerrar la ficha técnica o el QR de una orden no gatilla recargas con spinner ni hace parpadear la lista.

#### 4. Bandeja de Tasación de Precios (`BandejaPreciosScreen`)
- **Ruta / Archivo:** `frontend/lib/features/ventas/presentation/screens/bandeja_precios_screen.dart`
- **Sistema de Refresco:**
  - **Sondeo Silencioso:** Cada **20 segundos** para incorporar repuestos recién paletizados por bodega.
  - **Tras Asignar Precio:** Se actualiza silenciosamente con `_cargarPendientesSilencioso()`, removiendo el activo tasado sin congelar la pantalla.

#### 5. Entregas y Envíos (`EntregasEnviosScreen`)
- **Ruta / Archivo:** `frontend/lib/features/ventas/presentation/screens/entregas_envios_screen.dart`
- **Sistema de Refresco:**
  - Sincronización in-memory ante eventos de actualización de órdenes. Si ya existen datos, los cambios de estado (preparado, despachado) se reflejan sin mostrar barras de carga.

---

### 💳 ROL 3: CAJERO / CAJERA (Puesto de Caja y Cobro)

Puesto crítico de alta concurrencia donde se reciben pagos en efectivo, transferencias bancarias y tarjetas, emitiendo boletas y tickets QR.

#### 1. Módulo Principal de Caja (`CajaMainScreen`)
- **Ruta / Archivo:** `frontend/lib/features/caja/presentation/screens/caja_main_screen.dart`
- **Sidebar de Navegación y Carga Lazy:**
  - Alterna entre *Bandeja de Cobros*, *Historial de Pagos* y *Soporte*.
  - Al iniciar sesión solo carga *Bandeja de Cobros*; las pestañas de *Historial* y *Soporte* se inicializan bajo demanda (**lazy**) al abrirlas por primera vez y permanecen instanciadas en `IndexedStack` para cambios instantáneos.
- **Sincronización Híbrida en Tiempo Real (Push SSE + Respaldo 30s):**
  - **Canal Push SSE (`CajaSseService` → `GET /api/v1/caja/stream`):** Al crearse o anularse una orden en mesón o registrarse/editarse un pago en la sucursal, la terminal de Caja recibe el evento en **<1 segundo** sin que la cajera tenga que pulsar "Actualizar".
  - **Respaldo Silencioso:** `SilentPollingManager` sondea cada **30 segundos** con `await` estricto como red de seguridad ante eventuales microcortes del enlace.

#### 2. Cobros Pendientes (`CajaProvider`)
- **Ruta / Archivo:** `frontend/lib/features/caja/presentation/providers/caja_provider.dart`
- **🛡️ GUARDA CRÍTICA DE COBRO (Anti-Interrupción):**
  - Si la cajera ha seleccionado una orden y está en proceso de cobro (`isProcesandoCobro == true` o existen métodos de pago digitados en `pagosDivididos`), **tanto el stream SSE como el respaldo cada 30s omiten la actualización**.
  - **Garantía:** Jamás se deselecciona la orden en pantalla ni se limpian los montos ingresados por una actualización de red concurrente.

#### 3. Historial y Cuadre de Caja (`HistorialCajaScreen` / `HistorialCajaProvider`)
- **Ruta / Archivo:** `frontend/lib/features/caja/presentation/screens/historial_caja_screen.dart`
- **Tabla Persistente (Sin Pantalla en Blanco):**
  - El spinner centrado solo se muestra en la carga inicial (`isLoading && data == null`). Al cambiar página, período o filtro, la tabla y tarjetas de arqueo permanecen visibles con un `LinearProgressIndicator` sutil arriba.
- **Preservación de Paginación y Solicitudes:**
  - Dispone del método `Future<void> refrescarSilencioso()`, que se omite si ya hay una consulta explícita en curso y **nunca** invalida ni pisa la respuesta solicitada por el usuario.
- **Protección de Modales de Auditoría:**
  - `DetalleAuditoriaDialog` y los selectores de rango de fecha usan la guarda `_isModalAbierto`.
  - Al cerrar la ventana de inspección de una transacción sin mutaciones, la tabla no se blanquea ni se recarga desde cero.

> **Referencia técnica completa (eliminación de N+1 y SSE):** Ver [DOCUMENTACION_OPTIMIZACION_CAJA_Y_SSE.md](../../entregas/DOCUMENTACION_OPTIMIZACION_CAJA_Y_SSE.md).

---

### 👔 ROL 4: GERENCIA (Panel Ejecutivo y Control Operativo)

Vista corporativa de escritorio / web para directores y gerentes de sucursal, con análisis de KPIs financieros, auditoría forense de órdenes, tasación de inventario y monitoreo de backorders.

#### 1. Panel Ejecutivo Central (`DashboardGerenciaView`)
- **Ruta / Archivo:** `frontend/lib/features/gerencia/presentation/screens/dashboard_gerencia_view.dart`
- **Persistencia de Vistas con `IndexedStack` (0ms):**
  - Aloja en memoria las 4 vistas corporativas:
    1. `VistaGerencia.dashboard` (Dashboard Ejecutivo)
    2. `VistaGerencia.ordenes` (Historial de Órdenes Forense)
    3. `VistaGerencia.inventario` (Inventario y Tasación)
    4. `VistaGerencia.backorders` (Ventas en Verde)
  - Alternar entre cualquiera de estas vistas en el sidebar es **inmediato a 60 FPS**, conservando íntegros los filtros aplicados, la posición de desplazamiento (scroll) y la página consultada.
- **Regreso al Dashboard sin Bloqueos:**
  - Al pulsar en el sidebar "Dashboard Ejecutivo", si los KPIs ya están en memoria (`_kpis != null`) y no hay mutaciones pendientes (`!_dashboardDirty`), se conmuta de inmediato y se actualizan los datos silenciosamente con `_cargarDashboard(silent: true)`.
- **Orquestador Global de Polling Silencioso:**
  - `SilentPollingManager` (intervalo de **45 segundos**) sincroniza silenciosamente la vista que el gerente tenga activa en pantalla en ese instante.

#### 2. Auditoría Forense de Órdenes (`OrdenesGerenciaView`)
- **Ruta / Archivo:** `frontend/lib/features/gerencia/presentation/screens/ordenes_gerencia_view.dart`
- **Sistema de Refresco:**
  - Método `refrescarSilencioso({int? pagina})`.
  - Si el auditor está revisando transacciones sospechosas o anuladas en la página 4, un refresco en segundo plano actualiza los estados sin expulsarlo a la página 1.
  - El modal 360° `AuditoriaDetalleDialog` es de solo lectura forense y no emite llamadas a la API al cerrarse.

#### 3. Maestro de Inventario y Tasación (`InventarioGerenciaView`)
- **Ruta / Archivo:** `frontend/lib/features/gerencia/presentation/screens/inventario_gerencia_view.dart`
- **Fin a la Pantalla en Blanco:**
  - El spinner central solo se muestra en la carga inicial (`_isLoading && _items.isEmpty`). Si ya existen piezas visualizadas, la grilla o tabla permanece visible durante los cambios de página y refrescos.
- **Preservación de Filtros y Página:**
  - Cuenta con `refrescarSilencioso({int? pagina})`. Mantiene activos los filtros de pasillo, galpón, categoría y número de página.
- **🛡️ Guarda de Modal de Tasación (`isModalAbierto`):**
  - Al abrir el diálogo `_TasacionDialog` para fijar el precio de venta de un repuesto, se activa `_isModalAbierto = true`.
  - El sondeo periódico se inhibe para que ninguna actualización de fondo altere los campos de texto ni los rangos de precio que el gerente está digitando.

#### 4. Visor de Ventas en Verde / Backorders (`BackordersGerenciaView`)
- **Ruta / Archivo:** `frontend/lib/features/gerencia/presentation/screens/backorders_gerencia_view.dart`
- **Sistema de Refresco:**
  - Método `refrescarSilencioso()` que actualiza el capital retenido, las señas recaudadas en caja y el listado de reservas sinloaders bloqueantes.

---

## 3. Matriz Resumen de Refresco por Rol y Pantalla

| Rol | Vista / Pantalla | Tipo de Sincronización | Intervalo | Guardas Activas | ¿Mantiene Pág / Scroll? |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **Bodega** | Alertas de Tareas | Silent Polling + In-Memory | 15s | `AppLifecycleState.paused` | ✅ Sí (100% in-memory) |
| **Bodega** | Reingreso / Despacho | En evento / Cierre dialog | Manual | Sin llamadas al cancelar | ✅ Sí |
| **Ventas** | Catálogo de Repuestos | Silent Polling + Event Sync | 30s | `OrdenesSyncNotifier` | ✅ Sí |
| **Ventas** | Mis Órdenes (Historial) | Silent Polling | 15s | `_isModalAbierto` | ✅ Sí |
| **Ventas** | Bandeja de Tasación | Silent Polling + Post-Action | 20s | Formulario de precio | ✅ Sí |
| **Ventas** | Entregas y Envíos | Event Sync | En evento | In-memory merge | ✅ Sí |
| **Caja** | Cobros Pendientes | Push SSE (<1s) + Respaldo 30s | Push / 30s | `isProcesandoCobro` / Pagos en curso | ✅ Sí |
| **Caja** | Historial y Cuadre | Push SSE + Respaldo 30s + Lazy | Push / 30s | `_isModalAbierto` / `isCargando` | ✅ Sí (preserva pág y tabla visible) |
| **Gerencia** | Dashboard Ejecutivo | Silent Polling + On-Tab | 45s | `_dashboardDirty` | ✅ Sí |
| **Gerencia** | Historial de Órdenes | Silent Polling + Paginado | 45s (activo) | Modal de auditoría | ✅ Sí (preserva pág) |
| **Gerencia** | Inventario y Tasación | Silent Polling + Paginado | 45s (activo) | `_isModalAbierto` (`_TasacionDialog`) | ✅ Sí (preserva pág) |
| **Gerencia** | Ventas en Verde | Silent Polling | 45s (activo) | In-memory merge | ✅ Sí |

---

## 4. Guía de Buenas Prácticas para Nuevas Vistas (Reglas de Oro)

Para mantener la robustez del sistema en futuros desarrollos, todo desarrollador debe respetar los siguientes principios:

1. **Nunca mostrar un `CircularProgressIndicator` de pantalla completa si ya hay datos:**
   ```dart
   // ❌ ANTIPATRÓN:
   if (_cargando) return Center(child: CircularProgressIndicator());

   // ✅ FORMA CORRECTA:
   if (_cargando && _items.isEmpty) return Center(child: CircularProgressIndicator());
   ```

2. **Proteger los modales de inspección:**
   - Si un diálogo es de solo lectura (ej. ver detalles forenses), **no debe recargar la lista al cerrarse** a menos que el usuario haya ejecutado una mutación confirmada (guardar, cancelar, anular).

3. **Preservar la página en llamadas de refresco:**
   - Un método `refrescarSilencioso()` debe recibir `int? pagina` y por defecto usar `_paginaActual`. Solo se debe reiniciar a la página 1 cuando el usuario aplique explícitamente un nuevo filtro de búsqueda.

4. **Pausar sondeos durante interacciones críticas:**
   - Si una vista incluye formularios de ingreso de dinero o edición de datos, debe exponer una bandera (`isModalAbierto` o `isProcesando`) para que el `SilentPollingManager` se pause mientras el formulario esté en uso.

5. **Liberar recursos siempre en `dispose()`:**
   - Todo `SilentPollingManager` y `Timer` creado debe ser cancelado explícitamente en el método `dispose()` de su respectivo `State`.
