# SPEC-HU-TAREA-19: Ajustes Operativos y Ciclo de Vida Unificado (Mesón, Barrera de Bodega y Misceláneos)

---

## 1. Contexto, Objetivos y Alcance Operativo

Este documento consolida y actualiza de forma definitiva las especificaciones operativas de **Mesón de Ventas**, **Caja**, y **Bodega PDA**, resolviendo la coexistencia entre repuestos físicos inventariados (Motores, Cajas de Cambio) y productos de venta libre / misceláneos / servicios.

### Objetivos Clave
1. **Cero-Clics para el Vendedor en Misceláneos**: Eliminar la obligación de marcar manualmente "Listo" o "Confirmar Entrega" en el mesón cuando una orden de puros misceláneos/servicios ya fue pagada al 100% en caja.
2. **Protección Total de Barrera (Zero Bypass en Activos Físicos)**: Los activos inventariados (motores, transmisiones) NUNCA pueden ser marcados como entregados desde el mesón; su salida exige obligatoriamente el escaneo Dual-Scan en la Barrera de Salida de Bodega PDA (`/escanear-salida`).
3. **Manejo Robusto de Órdenes Mixtas**: En órdenes que combinan repuestos físicos de rack + misceláneos de mostrador, los misceláneos se marcan como listos inmediatamente al pagar para no ensuciar la bandeja de bodega, mientras que la orden permanece en `Pagada` hasta que el activo físico pase por barrera.
4. **Coexistencia en Bodega PDA**: Mantener visible el botón `BARRERA` en tareas pagadas (`LIBERADA`) incluso si el bodeguero ya completó la preparación física (`Listo`).
5. **Logística Inversa Desacoplada**: Al anular una orden, el repuesto vuelve a estar `Disponible` comercialmente de inmediato en el mesón; el reingreso en PDA solo actualiza pasillo/pallet físico.
6. **Renombramiento Comercial**: Reemplazo de "Reservas Backorder" por "Ventas en Verde" en todas las interfaces de usuario.

---

## 2. Matriz Definitiva de Transición de Estados tras Pago en Caja (`saldo == 0`)

| Tipo de Carrito | ¿Tiene Despacho Courier? | Estado Orden Resultante | QR Transaccional Emitido | Estado Repuestos Físicos | Estado Líneas Misceláneas | Acción Requerida del Vendedor | Hito de Cierre |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **Solo Misceláneos / Servicios** (0 activos en rack) | **No** (Retiro / Mesón) | **`Completada`** | `None` | N/A | `estado_preparacion = 'Listo'` | **Ninguna (0 clics)** | Cerrada automáticamente en el pago en Caja. |
| **Solo Misceláneos / Servicios** | **Sí** (Despacho a Domicilio) | **`Pagada`** | `None` | N/A | `estado_preparacion = 'Listo'` | **Ninguna** | Pasa al módulo de Despachos/Courier para guía y envío. |
| **Solo Activos Inventariados** (Motores, Cajas) | Indiferente | **`Pagada`** | `TX-QR-...` | `id_estado = 3 (Vendido)` | N/A | **Ninguna** | Bodeguero escanea Dual-Scan en Barrera $\rightarrow$ Orden a `Completada` y activo a `Entregado` (ID 6). |
| **Mixta** (Activo Físico + Misceláneos) | Indiferente | **`Pagada`** | `TX-QR-...` | `id_estado = 3 (Vendido)` | `estado_preparacion = 'Listo'` | **Ninguna** | Misceláneos listos de inmediato. Activo físico se valida en Barrera PDA $\rightarrow$ toda la orden pasa a `Completada`. |
| **Ventas en Verde (Backorder)** | Indiferente | `Confirmada` / `Pagada` | `TX-QR-...` solo al atribuir SKU | Según arribo/atribución | `estado_preparacion = 'Listo'` | Según arribo de repuesto | Asignación de SKU físico arribado a bodega. |

---

## 3. Comportamiento por Módulo y Rol

### A. Mesón de Ventas (Vendedor)
* **Venta de Misceláneos**: Al saldarse en Caja, la orden se actualiza automáticamente a `Completada`. Al abrir el detalle en `OrdenDetailSheet`, la UI muestra directamente la tarjeta verde *"Orden Completada - Los repuestos misceláneos fueron entregados exitosamente al cliente en mesón"*, suprimiendo botones redundantes de "Marcar como Entregado".
* **Venta de Activos o Mixta**: La orden queda en `Pagada`. El vendedor únicamente dispone del botón para visualizar o imprimir el ticket QR para que el cliente lo presente en bodega.
* **No Bypass**: No existe ningún botón que permita a ventas saltarse el escaneo de bodega para repuestos inventariados.

### B. Bodega PDA (Bodeguero)
* **Órdenes de Misceláneos**: Como sus líneas pasan inmediatamente a `estado_preparacion = 'Listo'` y la orden a `Completada`, **la PDA de bodega no recibe alertas parásitas** de preparación para productos ya entregados en mostrador.
* **Órdenes Mixtas y Físicas**: La PDA recibe exclusivamente la tarea de preparación y salida de los activos inventariados con rack asignado.
* **Ciclo de Tareas en PDA**:
  * `Reservada` + `Pendiente`: Tarea `PREPARACION` con botón `[ LISTO ]` (avisa que la pieza fue bajada del rack).
  * `Pagada` + `Pendiente`: Tarea `LIBERADA` con botones `[ LISTO ]` y `[ BARRERA ]`.
  * `Pagada` + `Listo`: Tarea `LIBERADA` con botón verde ancho completo `[ BARRERA ]` (habilita escaneo Dual-Scan).
  * `Completada`: Tarea finalizada, desaparece reactivamente del panel.

### C. Caja Desktop (Cajera)
* Al ejecutar `POST /api/v1/caja/cobros/registrar` o `/api/v1/ordenes/{id_orden}/pagar` y liquidar el saldo a `$0`:
  * El backend detecta de forma atómica si la orden contiene repuestos físicos o es puramente miscelánea.
  * Emite `qr_generado = 'TX-QR-...'` solo si hay activos físicos que retirar en bodega.
  * Para misceláneos de mostrador, retorna `estado_actualizado = 'Completada'` y `qr_generado = None`.

---

## 4. Endpoints y Lógica Transaccional (Backend ACID)

1. **`backend/routers/caja.py` (`/cobros/registrar`)**:
   * Valida cuadratura matemática del pago (único o split).
   * Al alcanzar `nuevo_saldo == 0`:
     * Si no hay activos inventariados ni backorders pendientes ni despacho courier: `orden.estado_orden = 'Completada'`, `d.estado_preparacion = 'Listo'`.
     * Si hay activos físicos: `orden.estado_orden = 'Pagada'`, activos a `Vendido (ID 3)`, misceláneos a `Listo`.
2. **`backend/routers/ordenes.py` (`/{id_orden}/pagar`)**:
   * Comportamiento análogo garantizando sincronía completa entre pagos directos y pagos por módulo de caja.
3. **`backend/routers/bodega.py` (`/escanear-salida`)**:
   * Realiza Dual-Scan match entre el ticket QR y los SKUs físicos escaneados.
   * Actualiza la orden a `Completada`, los repuestos a `Entregado (ID 6)` y libera ubicaciones físicas de rack.

---

## 5. Criterios de Validación Automatizada

* **Backend Tests**:
  * `pytest tests/test_pago_ordenes_qr.py`: Valida que `test_pago_orden_miscelaneos_sin_qr` pase la orden a `Completada`, con `monto_pendiente == 0`, sin QR y con detalle `Listo`.
  * `pytest tests/test_caja_cobros.py`: Valida que `test_registrar_cobro_orden_sin_activos_mantiene_qr_nulo` retorne `estado_actualizado = 'Completada'`.
  * Ejecutar suite con `pytest tests/test_pago_ordenes_qr.py tests/test_caja_cobros.py -v` (100% aprobado).
* **Frontend Tests**:
  * `flutter test test/historial_screen_test.dart`: 100% de tests aprobados para ordenes completadas y mixtas.
  * `flutter test test/entregas_envios_screen_test.dart`: 100% de tests aprobados para retiros y despachos.
