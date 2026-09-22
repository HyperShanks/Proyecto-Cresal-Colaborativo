# SPEC-HU-TAREA-21: Sincronización Multi-Usuario Silenciosa (Silent Polling, Fusión en Memoria y Bloqueo de UI Activa)

## 1. Contexto y Justificación del Cambio

### Problema Actual
En la Tarea 20 se introdujo una estrategia de auto-refresh universal (`RouteAware`, `didPopNext`, y disparadores al cambiar de pestaña). Si bien resolvió el problema de datos obsoletos, introdujo tres problemas críticos para la experiencia de usuario y la estabilidad operativa:
1. **Destrucción del trabajo en progreso (Riesgo de Caja y Venta):** Cuando la cajera está con un cliente cobrando una orden (ingresando billetes, seleccionando medio de pago o calculando vuelto), un refresco disparado por el cambio de estado de otra orden resetea la pantalla, borrando los inputs ingresados.
2. **Refresco innecesario en modales de solo lectura:** Abrir la ficha de un vehículo, el detalle de una orden o una card para leer información y cerrarla ejecuta un `didPopNext()` que vuelve a pedir todos los datos al servidor, provocando parpadeos visuales (*flickering*) con spinners de carga innecesarios.
3. **Falso tiempo real:** El sistema no se entera de los cambios ocurridos en otros dispositivos a menos que el usuario interactúe (cambie de pestaña o cierre un diálogo).

### Objetivo
Reemplazar el refresco destructivo y agresivo por una arquitectura de **Sincronización Silenciosa (Silent Polling & In-Memory Merge)** con **Bloqueo de Seguridad en UI Activa**, garantizando que los dispositivos de Mesón, Caja y Gerencia se mantengan al día sin interrumpir al operador ni parpadear.

---

## 2. Archivos Afectados

### Frontend (Flutter)
- **Nuevo**: `frontend/lib/core/services/silent_polling_manager.dart` (Gestor genérico y desacoplado de temporizadores de polling con conciencia del ciclo de vida).
- `frontend/lib/features/caja/presentation/screens/caja_main_screen.dart` (Protección de cobro activo y actualización en segundo plano de órdenes por cobrar).
- `frontend/lib/features/ventas/presentation/screens/historial_screen.dart` (Fusión en memoria de órdenes de venta y prevención de refresco en cierres de modal de solo lectura).
- `frontend/lib/features/ventas/presentation/screens/catalogo_screen.dart` (Refresco suave de stock sin alterar filtros ni posición del scroll).
- `frontend/lib/features/gerencia/presentation/screens/dashboard_gerencia_view.dart` (Sondeo no intrusivo de KPIs financieros y flujo operativo).

### Backend
- *Sin cambios de endpoints necesarios*: Se reutilizan los endpoints transaccionales existentes optimizando la frecuencia y el manejo de carga.

---

## 3. Pilares Arquitectónicos de la Solución

```
                    ┌─────────────────────────────────────────────────────────┐
                    │               SilentPollingManager                      │
                    │   - Intervalo: 10 a 15 segundos                         │
                    │   - Activo solo en AppLifecycleState.resumed            │
                    │   - Cancelación en dispose()                            │
                    └────────────────────────────┬────────────────────────────┘
                                                 │ Gatilla consulta periódica
                                                 ▼
                    ┌─────────────────────────────────────────────────────────┐
                    │            ¿Hay acción o flujo activo?                  │
                    │   (isProcessingPayment, isFormularioAbierto, Modal)     │
                    └────────────┬───────────────────────────────┬────────────┘
                                 │ SÍ                            │ NO
                                 ▼                               ▼
                    ┌─────────────────────────┐     ┌─────────────────────────┐
                    │    PAUSAR / OMITIR      │     │  Consulta en Background │
                    │   No tocar la UI ni     │     │  (Sin spinner global)   │
                    │   resetear el estado    │     └────────────┬────────────┘
                    └─────────────────────────┘                  │
                                                                 ▼
                                                    ┌─────────────────────────┐
                                                    │   In-Memory Merge       │
                                                    │   - Comparar IDs        │
                                                    │   - Insertar nuevas     │
                                                    │   - Actualizar badges   │
                                                    │   - Preservar Scroll    │
                                                    └─────────────────────────┘
```

### Pilar 1: Eliminación de Refrescos en Modales de Solo Lectura (Pop Return Awareness)
- **Regla:** Ningún modal de solo lectura (como ver detalle de una orden o consultar especificaciones técnicas de un activo) debe disparar recarga de datos al cerrarse.
- **Implementación:**
  - Los métodos que abren modales mutantes (donde se cambia estado, se asigna o se cancela) deben esperar el resultado: `final actualizado = await showModalBottomSheet<bool>(...);`.
  - Solo si `actualizado == true`, se invoca la recarga local o actualización focalizada.
  - Se remueve la invocación incondicional de `refrescar()` en el `didPopNext()` cuando se trata de retornos neutros.

### Pilar 2: Bloqueo de Seguridad de UI Activa (Active UI Guard)
- **Regla:** Si el usuario tiene el foco en una acción sensible, ningún proceso en segundo plano puede invocar `setState()` sobre el formulario en curso.
- **Implementación en Caja:**
  - Definir la bandera `bool _operacionEnCurso = false;`.
  - Al abrir el diálogo/panel de cobro (ingreso de efectivo, cálculo de vuelto, selección de comprobante): `_operacionEnCurso = true;`.
  - Al cerrar o finalizar: `_operacionEnCurso = false;`.
  - Durante el ciclo de polling:
    ```dart
    if (_operacionEnCurso) {
      debugPrint('[POLLING-CAJA] Operación en curso. Polling pausado temporalmente.');
      return;
    }
    ```

### Pilar 3: Polling Silencioso con Fusión en Memoria (In-Memory Merge)
- **Sin pantallas de bloqueo:**
  - El flag tradicional `_cargando = true` (que muestra la rueda de carga en toda la pantalla) **SOLO** se usa en la primera apertura de la pantalla.
  - Las consultas del polling periódico se ejecutan con `_silentLoading = true` (invisible al usuario).
- **Fusión en Memoria (Reconciliación):**
  - Cuando el backend entrega la lista nueva:
    1. Si no hay diferencias con la lista actual (mismos IDs y mismos estados), **no se llama a `setState()`**.
    2. Si hay órdenes nuevas: se insertan al inicio de la lista local conservando los elementos ya renderizados.
    3. Si una orden existente cambió de estado (ej: de *Pendiente* a *Completada*): se reemplaza únicamente el ítem en la lista local.
  - **Preservación de Scroll:** Al no vaciar la lista (`items.clear()`), el `ScrollController` de Flutter no salta a la posición cero, permitiendo que el usuario siga leyendo donde estaba.

### Pilar 4: Manejo Silencioso de Errores de Red
- Si una petición de background falla por micro-corte de conexión o latencia en Render:
  - **PROHIBIDO** desplegar `SnackBar` de error o alertas rojas en la pantalla.
  - Se registra el error únicamente en consola (`debugPrint('[POLLING-SILENCIOSO] Error temporal ignorado: $e')`).
  - La UI mantiene los datos que ya tenía en pantalla y lo reintenta silenciosamente en el próximo ciclo.

---

## 4. Parámetros de Configuración Recomendados

| Pantalla / Módulo | Frecuencia de Polling | Condición de Pausa | Estrategia de Fusión |
| :--- | :--- | :--- | :--- |
| **Caja (Órdenes por Cobrar)** | Cada 12 segundos | `_operacionEnCurso == true` (Cobro abierto) | Inserción en cabecera de nuevas órdenes por cobrar |
| **Mesón (Mis Órdenes)** | Cada 15 segundos | Modal de asignación / detalle abierto | Actualización in-place de estado (Pendiente ➔ Pagada) |
| **Catálogo (Ventas)** | Cada 30 segundos | Búsqueda activa o scroll en progreso | Actualización de stock de activos sin resetear filtros |
| **Gerencia (Dashboard)** | Cada 45 segundos | Tab no activa o modal de filtro abierto | Reemplazo suave de tarjetas KPI y gráficos |

---

## 5. Checklist de Tareas de Implementación

- [ ] **Tarea 1 (Infraestructura)**: Crear `lib/core/services/silent_polling_manager.dart` con inicio, detención, pausado y vinculación al ciclo de vida de la aplicación (`WidgetsBindingObserver`).
- [ ] **Tarea 2 (Limpieza de Modales)**: Auditar `didPopNext()` y llamadas a `showModalBottomSheet`/`showDialog` en `HistorialScreen`, `CatalogoScreen` y `CajaMainScreen`, eliminando recargas incondicionales cuando el modal retorna `null` o `false`.
- [ ] **Tarea 3 (Caja - Seguridad)**: Implementar `_operacionEnCurso` en Caja. Vincular el `SilentPollingManager` a la lista de órdenes pendientes por cobrar con fusión en memoria.
- [ ] **Tarea 4 (Mesón de Ventas)**: Implementar la reconciliación en memoria en `HistorialScreen` para que las órdenes asignadas o pagadas actualicen su badge sin parpadear.
- [ ] **Tarea 5 (Ciclo de Vida)**: Asegurar que todos los timers de polling se cancelen automáticamente en `dispose()` y se suspendan cuando la app esté minimizada (`AppLifecycleState.paused`).
- [ ] **Tarea 6 (Pruebas Automatizadas)**: Crear pruebas unitarias que verifiquen la lógica de fusión en memoria (merge sin duplicados) y que el temporizador respete el flag de operación en curso.

---

## 6. Criterios de Aceptación y Validación

1. **Prueba de la Cajera:** Al tener el panel de cobro de una orden abierto con datos ingresados, la llegada de una orden nueva generada por un vendedor no debe cerrar el panel, ni borrar el monto, ni mover la pantalla.
2. **Prueba de Cierre Neutro:** Abrir el detalle de una orden y cerrarlo con el botón "Volver" o deslizando hacia abajo no debe provocar ninguna llamada a la API ni mostrar ningún spinner.
3. **Prueba de Scroll Continuo:** Estar scrolleando en el catálogo o historial mientras el polling silencioso se ejecuta no debe causar saltos bruscos en la posición del scroll.
4. **Prueba de Recursos:** Con la aplicación minimizada en el teléfono, no deben ejecutarse peticiones periódicas en segundo plano.
