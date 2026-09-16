# SPEC-HU-TAREA-19-CONTINUIDAD: Ciclo de Vida de Tareas de Bodega — Coexistencia de Preparación Física ('Listo') y Entrega en Barrera ('Barrera')

---

## 1. Contexto y Antecedentes

En la especificación **SPEC-HU-TAREA-19**, se abordó la supervivencia de la tarea de pre-entrega post-pago:
> *"Cuando un vendedor envía una pieza a pre-entrega (...) y el cliente paga inmediatamente en caja, el activo reduce su monto_pendiente a 0 y la tarea en la PDA cambia a tipo LIBERADA. El componente visual task_card.dart estaba ocultando el botón 'LISTO' para forzar el botón 'BARRERA' (...). Solución: En task_card.dart, si la alerta es LIBERADA, no se debe ocultar el botón 'LISTO'."*

### El Problema Detectado Posteriormente
Aunque en el frontend (`task_card.dart`) se añadieron ambos botones (`[ LISTO ]` y `[ BARRERA ]`) de forma simultánea, **no se modificó la consulta del backend en `backend/routers/bodega.py`**.
En consecuencia:
- Si el operario de bodega presionaba `LISTO` (o si ya lo había presionado mientras la orden estaba en preparación anticipada), el backend ejecutaba `completar_preentrega`, marcando en base de datos: `Detalle_Orden.estado_preparacion = 'Listo'`.
- Como las consultas de `obtener_tareas_pendientes` y `obtener_resumen_alertas` tenían un filtro rígido `Detalle_Orden.estado_preparacion != 'Listo'`, la tarea **desaparecía inmediatamente del panel de alertas**.
- Al desaparecer la tarjeta de la pantalla de la PDA, el botón **`BARRERA`** se perdía con ella, dejando al bodeguero sin acceso a la pantalla de control de salida (`AuditoriaSalidaScreen`) para realizar el escaneo Dual-Scan (`/escanear-salida`).

---

## 2. Análisis: ¿Para qué servía previamente la lógica de "Listo"?

Para no romper flujos previos, se auditó la semántica de `estado_preparacion = 'Listo'` en todos los módulos del sistema:

1. **En Ventas / Mesón (`backend/routers/ordenes.py`)**:
   - En la pantalla de *Entregas y Envíos*, el endpoint `/entregas-envios` consulta `todos_preparados = all(d.estado_preparacion == "Listo")`.
   - Esto le comunica al vendedor en tiempo real si el bodeguero ya retiró físicamente los repuestos del pallet/pasillo y los tiene en el mesón de preparación.
2. **En Traslados Logísticos (`Tracking_Logistico`)**:
   - Al marcar "Listo" un ítem que va a otra sucursal, `estado_traslado` muta de `"Pendiente"` a `"Listo para Traslado"`.
3. **En Bodega (`backend/routers/bodega.py`)**:
   - El bodeguero lo utiliza para declarar que el trabajo de búsqueda y acondicionado físico de la pieza en el galpón concluyó.

**Conclusión**: "Listo" representa la **preparación física** interna del repuesto. La **entrega final al cliente** (salida en barrera) es un hito posterior e independiente que concluye cuando la orden pasa a `Completada` y el activo a `Entregado` (ID 6).

---

## 3. Matriz de Estados y Ciclo de Vida Unificado

| Estado Orden | Estado Preparación | ¿Está en Traslado? | Tipo de Alerta | Botones Visibles en PDA | Comportamiento al presionar |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `Reservada` (No pagada) | `Pendiente` | No | `PREPARACION` | `[ LISTO ]` + `[ DETALLES ]` | `LISTO` marca preparación física terminada. |
| `Reservada` (No pagada) | `Listo` | No | *(Oculta de prep)* | *(Ninguno)* | La preparación concluyó; la tarea espera el pago en caja sin saturar el panel de preparación. |
| `Pagada` | `Pendiente` | No | `LIBERADA` | `[ LISTO ]` + `[ BARRERA ]` | Puede marcar `LISTO` (la pieza pasa a preparada) o `BARRERA` (abrir scanner de salida). |
| `Pagada` | `Listo` | No | `LIBERADA` | `[ BARRERA ]` *(Ancho completo)* | La preparación ya está lista. La tarjeta permanece viva exclusivamente para realizar el despacho en barrera. |
| `Completada` | `Listo` | No | *(Finalizada)* | *(Ninguno)* | Tras el escaneo Dual-Scan en barrera, el activo pasa a `Entregado` (ID 6) y se desvincula de bodega. |

---

## 4. Solución Técnica Implementada

### A. Backend (`backend/routers/bodega.py`)
En `obtener_tareas_pendientes` y `obtener_resumen_alertas`:
Se ajusta la condición de filtrado para que incluya:
1. Activos que aún requieren preparación física (`Detalle_Orden.estado_preparacion != 'Listo'`).
2. **O** activos pertenecientes a órdenes pagadas que aún no han sido entregadas en barrera (`Orden_Venta.estado_orden == 'Pagada'`), **sin importar que su preparación ya esté `'Listo'`**.

```python
# Filtro inclusivo que retiene tareas pagadas para barrera
or_(
    Detalle_Orden.estado_preparacion != "Listo",
    Orden_Venta.estado_orden == "Pagada",
)
```

### B. Frontend (`frontend/lib/features/alertas/presentation/widgets/task_card.dart`)
1. En `tarea.tipoAlerta == 'LIBERADA'`:
   - Si `tarea.estadoPreparacion != 'Listo'`: Muestra `[ LISTO ]` y `[ BARRERA ]`.
   - Si `tarea.estadoPreparacion == 'Listo'`: Muestra exclusivamente `[ BARRERA ]` a ancho completo.
2. Se unifica el callback del botón `BARRERA` para que ambos utilicen `_abrirBarreraSalida()`, garantizando que al completar el escaneo de salida, el `BodegaPollingService` decremente reactivamente el badge y refresque la vista.

---

## 5. Criterios de Aceptación y Validación

- [x] Una orden pagada cuyo ítem tiene `estado_preparacion = 'Listo'` permanece en el panel de Bodega como `LIBERADA`.
- [x] La tarjeta en estado `LIBERADA` con preparación lista muestra el botón verde `BARRERA`.
- [x] Al pulsar `BARRERA` y confirmar el Dual-Scan match (`/escanear-salida`), la orden pasa a `Completada` y desaparece del panel de tareas pendientes.
- [x] Las órdenes reservadas (no pagadas) que se marcan como "Listo" continúan desapareciendo del panel de preparación hasta que caja confirme el pago.
