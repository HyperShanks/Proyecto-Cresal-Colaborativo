# ESPECIFICACIÓN TÉCNICA Y FUNCIONAL: EDICIÓN CONTROLADA DE PAGOS, POKA-YOKE Y AUDITORÍA EN CAJA

**Código de Especificación:** `SPEC-HU-EDICION-PAGOS-AUDITORIA`  
**Módulo:** Caja / Bandeja de Cobros / Historial de Órdenes  
**Fecha de Implementación Original:** Octubre 2026  
**Última Actualización (Saneamiento y Blindaje):** 22 de noviembre de 2026  
**Estado:** Vigente e Implementado (Edición 1 a 1 Blindada; División `1 → N` pendiente de fase posterior)

---

## 1. Contexto y Alcance Vigente

En la operación de mesón y caja de Cresal Repuestos se producen errores humanos al registrar cobros frente a terminales POS físicos desacoplados (por ejemplo, marcar *Efectivo* cuando el cliente pagó con *Débito*, o digitar un monto de abono incorrecto en una orden `Reservada`).

### Alcance Actual Implementado
1. **Edición controlada 1 a 1 (`PATCH /api/v1/caja/pagos/{id_pago}`):**
   * Permite corregir el **método de pago** en órdenes `Reservada`, `Pagada` o `Completada` (actualizando la fila existente en `Transaccion_Pago` para que las métricas del arqueo reflejen exclusivamente el nuevo método y no queden montos duplicados).
   * Permite corregir el **monto de un abono parcial** únicamente cuando la orden está en estado `Reservada` y siempre que la suma total de pagos procesados permanezca estrictamente menor al `total_venta`.
2. **Filtrado estricto de `estado_pago == "Procesado"` (`EstadoPagoEnum`):**
   * Los únicos estados oficiales de `Transaccion_Pago` en esta etapa son `Procesado` y `Anulado`.
   * Todas las consultas y sumatorias de Caja, Órdenes y Gerencia exigen `estado_pago == "Procesado"`, evitando que transacciones anuladas alteren arqueos, saldos o desgloses.
3. **Inmutabilidad de fecha de imputación:**
   * **Ningún rol** (ni Caja, ni Gerencia, ni Administrador) puede modificar `fecha_pago` una vez registrado el pago. En `EditarPagoDialog`, la fecha se muestra únicamente como dato informativo de solo lectura.
4. **Poka-Yoke de liquidación posterior (`ConfirmacionLiquidacionDialog`):**
   * Se mantiene la confirmación preventiva antes de liquidar el saldo total en órdenes con abonos previos o reservas backorder.

> [!NOTE]
> **Alcance diferido para una fase posterior (NO implementado todavía):**
> - División/rebalanceo multimétodo (`1 → N`) para repartir un pago único ya registrado en dos o más medios.
> - Reversión de cobros (`Pagada` → `Reservada`).

### 1.1 Hoja de Ruta y Decisiones de Diseño Pendientes (NO implementado — Referencia para futuras fases)

> [!WARNING]
> Todo lo listado en esta sección es **diseño previsto**, no código vigente. No debe asumirse que existe en el sistema actual.

**A. División / Rebalanceo `1 → N` (mismo total y misma `fecha_pago` original):**
* Permitir repartir un pago ya registrado en 2 o más métodos (ej. `$500.000 Débito` → `$200.000 Débito + $300.000 Efectivo`), exigiendo $\sum \text{nuevos} == \text{monto reemplazado}$.
* Las nuevas filas **heredan la `fecha_pago` del pago reemplazado** (nunca `NOW()`), para no mover dinero entre jornadas ya cerradas (ej. abono del lunes + pago del miércoles).
* El pago original **no se borra**: pasaría a `estado_pago = "Reemplazado"` (nuevo valor de `EstadoPagoEnum`, hoy inexistente).
* Cambios de esquema previstos en `Auditoria_Edicion_Pago` (hoy `id_pago` es `NOT NULL` y `valor_anterior`/`valor_nuevo` son `VARCHAR(255)`): `id_pago` pasaría a *nullable* con FK `ON DELETE SET NULL` (**nunca `CASCADE`**, para que borrar un pago no destruya su auditoría) y los valores a `TEXT`, de modo que un evento a nivel de orden (rebalanceo con 3+ métodos) pueda auditarse completo.

**B. Verificaciones obligatorias al introducir `"Reemplazado"`:**
* Los filtros actuales `estado_pago == "Procesado"` ya excluyen `Reemplazado` por construcción, pero deben cubrirse con tests explícitos (arqueo, `/pendientes`, `/historial`, KPIs de Gerencia y servicio ML).
* **Riesgo conocido:** `anular_orden_post` y `anular_orden_patch` (`ordenes.py`) marcan como `Anulado` **todo pago cuyo estado sea distinto de `Anulado`** y suman su monto en `monto_reversado`. Con `Reemplazado` existiendo, esa condición debe cambiar a `== "Procesado"`; de lo contrario se sobrescribiría el estado histórico y se inflaría el monto reversado.

**C. Reversión de cobro (`Pagada`/`Completada` → `Reservada`) — Decisión pendiente:**
* Si se aprueba en el futuro, debe quedar **bloqueada** cuando exista un escaneo exitoso en `Auditoria_Barrera` (la pieza ya salió físicamente) y, para Rol Caja, limitada a cobros de la jornada actual.
* Debe restaurar de forma atómica `qr_transaccional_salida = NULL`, estado de activos `Vendido → Reservado`, `Detalle_Orden.estado_preparacion`, `Reservas_Backorder` y `monto_pendiente`, marcando los pagos revertidos como `Anulado`.

**D. Poka-Yoke pre-cobro global — Decisión pendiente:**
* Hoy `ConfirmacionLiquidacionDialog` solo aparece al liquidar saldos posteriores. Extenderlo a todo cobro (venta nueva, abono y liquidación) fue evaluado y **diferido** por decisión de negocio.

---

## 2. Arquitectura, Seguridad y Base de Datos

### 2.1 Estados de `Transaccion_Pago` (`EstadoPagoEnum`)
* `Procesado`: Transacción válida y contabilizada en arqueos, historiales y saldos pendientes.
* `Anulado`: Transacción invalidada al anular una orden (`anular_orden_post` / `anular_orden_patch`); nunca se suma ni se muestra en el desglose activo.

### 2.2 Auditoría en `Auditoria_Edicion_Pago`
* Cada modificación exitosa en `PATCH /api/v1/caja/pagos/{id_pago}` inserta un registro inmutable en `Auditoria_Edicion_Pago` con `id_pago`, `id_orden`, `id_usuario`, `fecha_edicion`, `campo_modificado` (`monto` o `metodo_pago`), `valor_anterior`, `valor_nuevo` y `motivo` (mínimo 10 caracteres).
* Estos eventos se muestran cronológicamente en la línea de tiempo del historial de Caja y Gerencia, sin alterar el cálculo financiero de `Transaccion_Pago`.

### 2.3 Estados Operativos Reales de las Órdenes
* **Aclaración Crítica de Negocio:** El estado `Despachada` y la tabla `Despacho` **no están operativas en producción actualmente**.
* El ciclo de vida de las órdenes en el sistema se rige estricta y exclusivamente por **4 estados reales**:
  1. **`Reservada`:** Orden emitida por Mesón con saldo pendiente (con o sin abonos parciales). Repuestos físicos en estado `Reservado`.
  2. **`Pagada`:** Saldo liquidado al 100%. Repuestos físicos en estado `Vendido` y token `qr_transaccional_salida` emitido.
  3. **`Completada`:** Saldo liquidado al 100% en ventas que no requieren entrega física de activos inventariados (misceláneos / servicios).
  4. **`Anulada`:** Venta cancelada formalmente con reversa total de inventario y pagos (`estado_pago = "Anulado"`).

### 2.4 Blindaje de Seguridad y Concurrencia (`PATCH /api/v1/caja/pagos/{id_pago}`)
* **RBAC:** Permitido únicamente a Caja (`id_rol == 3`), Gerencia (`id_rol == 4`) y Administrador (`id_rol == 5`).
* **Aislamiento por sucursal:** Para Rol 3 (`Caja`), se valida estrictamente `orden.id_sucursal == current_user.id_sucursal` (`HTTP 403` si pertenece a otra sucursal).
* **Validación de estado de pago y orden:** Rechaza con `HTTP 400` cualquier edición sobre órdenes `Anulada` o transacciones cuyo `estado_pago != "Procesado"`.
* **Atomicidad ACID:** Envuelto en bloque `try / except` con `db.rollback()` ante cualquier error y bloqueo de fila `with_for_update()` sobre `Orden_Venta` en PostgreSQL.

---

## 3. Matriz de Reglas de Negocio Vigentes

| Escenario Operativo | Estado de la Orden | ¿Se Permite? | Comportamiento del Sistema |
|---|---|---|---|
| **1. Corregir método de pago (1 a 1)** | `Reservada`, `Pagada`, `Completada` | **PERMITIDO** | Actualiza `metodo_pago` en la transacción `Procesado` existente y registra auditoría. El arqueo refleja solo el método nuevo. |
| **2. Corregir monto de abono parcial** | Solo `Reservada` | **PERMITIDO** | Recalcula `orden.monto_pendiente` y `Reservas_Backorder.monto_abonado` validando `0 < total_procesado < total_venta`. |
| **3. Liquidar el 100% editando un abono** | `Reservada` | **BLOQUEADO (`400`)** | Debe liquidarse mediante el flujo formal de cobro (`POST /api/v1/caja/cobros/registrar`). |
| **4. Modificar monto en orden liquidada** | `Pagada`, `Completada` | **BLOQUEADO (`400`)** | No se permite alterar montos sobre órdenes ya liquidadas. |
| **5. Modificar `fecha_pago` de un cobro** | Todos los estados | **BLOQUEADO (Todos los roles)** | `EditarPagoRequest` no expone edición de fecha; la marca temporal original es inmutable. |
| **6. Editar pago `Anulado` u orden `Anulada`** | Cualquiera / `Anulada` | **BLOQUEADO (`400`)** | Registros anulados son estrictamente inmutables. |
| **7. Editar pago de otra sucursal (Rol Caja)** | Todos los estados | **BLOQUEADO (`403`)** | Rol 3 solo puede corregir pagos de su sucursal asignada. |

---

## 4. Los 7 Caminos Felices de Caja (Flujo Normal de Referencia)

Secuencias estándar de operación exitosa en caja (contexto de negocio para cualquier modificación futura):

| Camino Feliz | Tipo de Operación | Estado Inicial | Pago Realizado | Estado Final Orden | Estado Activo Físico | QR Salida | Destino Visual |
|---|---|---|---|---|---|---|---|
| **1. Contado Inmediato** | Repuesto Físico | `Reservada` | 100% Total | **`Pagada`** | `Vendido` (id: 3) | Emitido | *Historial de Caja* |
| **2. Contado Misceláneo** | Sin Activo Físico | `Reservada` | 100% Total | **`Completada`** | N/A | NULL | *Historial de Caja* |
| **3. Abono Inicial Reserva** | Repuesto Físico | `Reservada` | Parcial ($\ge$ piso) | **`Reservada`** | `Reservado` (id: 2) | NULL | *Bandeja de Cobros* |
| **4. Abono Venta en Verde** | Backorder sin activo | `Reservada` | Parcial ($\ge$ piso) | **`Reservada`** | N/A | NULL | *Bandeja de Cobros* |
| **5. Abonos Sucesivos** | Mixto / Saldo | `Reservada` | Parcial | **`Reservada`** | Sin cambio | NULL | *Bandeja de Cobros* |
| **6. Liquidación Reserva** | Repuesto Físico | `Reservada` | Saldo restante (100%) | **`Pagada`** | `Vendido` (id: 3) | Emitido | *Historial de Caja* |
| **7. Liquidación Backorder** | Venta en Verde | `Reservada` | Saldo restante (100%) | **`Pagada`** | `Vendido` (si hay SKU) o N/A | Solo si hay SKU | *Historial de Caja* |

---

## 5. Comportamiento del Modal `EditarPagoDialog` (Frontend)

* **Fecha y hora de imputación:** Renderizada como campo de solo lectura (`FECHA Y HORA DE IMPUTACIÓN (INMUTABLE)`), sin selector ni botón de cambio.
* **Validación estricta de monto:** Si el campo monto queda vacío o en `0`, `_montoIngresado` evalúa `0` real (reflejando el saldo pendiente completo en la vista previa) y el botón `Guardar` permanece deshabilitado (`_montoInvalido`).
* **Activación de `Guardar`:** Requiere cambio real en método o monto válido (`> 0` y `< saldo total`) más motivo explicativo de al menos 10 caracteres.

---

## 6. Cobertura de Pruebas Automatizadas

* **Backend (`backend/tests/test_caja_edicion_pagos.py`):**
  * Edición de método de pago (`Reservada` y `Pagada`) y verificación en timeline de historial.
  * Edición de monto en `Reservada`, bloqueo de liquidación total (`>= total_venta`) y bloqueo de monto en `Pagada`.
  * Rechazo de edición de fecha para todos los roles (preservando `fecha_pago` original).
  * Rechazo de edición sobre transacción `Anulado`, rechazo por sucursal ajena para Rol 3 (`403`) y exclusión de pagos `Anulado` en `/pendientes` y `/historial`.
  * Rechazo de motivo corto y de órdenes `Anulada`, y bloqueo RBAC (`403`) a vendedores.
* **Frontend (`frontend/test/features/caja/editar_pago_dialog_test.dart`):**
  * Renderizado de fecha inmutable (sin botón *Cambiar*), bloqueo de monto en `Pagada`, recálculo dinámico en `Reservada`, validación de motivo (`>= 10` chars), evaluación real de `0` sin fallback silencioso y garantía anti-overflow en 320px.
