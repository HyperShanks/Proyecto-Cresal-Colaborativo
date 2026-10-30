# ESPECIFICACIÓN TÉCNICA Y FUNCIONAL: EDICIÓN CONTROLADA DE PAGOS Y AUDITORÍA EN CAJA

**Código de Especificación:** `SPEC-HU-EDICION-PAGOS-AUDITORIA`  
**Módulo:** Caja / Historial de Órdenes  
**Fecha de Implementación:** Octubre 2026  
**Estado:** Implementado, Verificado y Aprobado  

---

## 1. Contexto y Necesidad de Negocio

En la operación diaria de mesón y caja de Cresal Repuestos, se suscitan errores humanos comunes y comprensibles:
- **Confusión de métodos de pago:** Un cajero selecciona por omisión "Efectivo" cuando el cliente transfirió a la cuenta bancaria de la empresa, o marca "Débito" habiendo cancelado con "Crédito".
- **Error de digitación en montos de abono:** Al registrar un anticipo o reserva de una pieza (por ejemplo, digitando $60.000 en vez de los $50.000 pactados).
- **Desfase en la fecha/hora de imputación:** Cobros recibidos al final de la jornada o fuera de turno que ameritan corregir su marca temporal para reflejarse en el arqueo del día correspondiente.

### El Problema Anterior
Anteriormente, una vez emitida la orden o cerrado el abono, la orden quedaba inmutable. Para corregir un medio de pago, el equipo debía:
1. **Anular la orden entera:** Lo que cancelaba la venta, revertía la reserva de piezas críticas (motores, cajas de cambio) y causaba confusión al cliente.
2. O bien, **asumir descuadres crónicos:** En el cuadre de caja de fin de turno y en las conciliaciones bancarias (diferencias entre saldo efectivo físico y cartola bancaria).

### Solución Implementada
Se habilitó una interfaz de **edición controlada sobre registros individuales de pago** directamente desde el Historial de Órdenes en Caja, con recálculo dinámico de saldos y una bitácora de auditoría estricta que registra quién, cuándo, qué valor original existía y por qué motivo justificado se realizó la corrección.

---

## 2. Decisiones de Arquitectura y Base de Datos

### 2.1 Adopción de la Opción A (Sin columnas ociosas en `Transaccion_Pago`)
- **Evaluación:** Se analizó si debía agregarse una columna `referencia` o `numero_comprobante` en la tabla `Transaccion_Pago`.
- **Decisión (Opción A):** **No se modificó la estructura de `Transaccion_Pago`**. El flujo actual de caja en Flutter (`panel_detalle_cobro.dart`) nunca ha solicitado ni capturado códigos de referencia/voucher bancario al procesar cobros de venta. Agregar una columna que no es alimentada por la interfaz operativa crearía columnas ociosas (NULL o vacías) y generaría deuda técnica innecesaria.
- Si en el futuro el negocio decide exigir comprobantes Transbank o números de transferencia al cobrar en mesón, se implementará un ciclo completo de captura desde el checkout de cobro.

### 2.2 Estrategia de Auditoría: Tabla Aditiva en Producción
- **Pregunta Crítica del Negocio:** *¿Crear la tabla de auditoría en una base de datos que ya está en producción generará bloqueos, caídas o problemas?*
- **Respuesta Técnica:** **No genera ningún problema.**
  - La tabla `Auditoria_Edicion_Pago` es **100% aditiva**.
  - No altera (`ALTER TABLE`), no renombra, no bloquea (`LOCK`) ni elimina ninguna columna o tabla existente de la base de datos de producción (`Orden_Venta`, `Transaccion_Pago`, `Reservas_Backorder`, etc.).
  - En PostgreSQL / Supabase, la sentencia `CREATE TABLE IF NOT EXISTS` se ejecuta en milisegundos sin interrumpir las transacciones concurrentes ni las consultas de caja.
  - SQLAlchemy y los endpoints leen y escriben en esta tabla de manera aislada.

#### DDL SQL Idempotente para Supabase / PostgreSQL:
```sql
CREATE TABLE IF NOT EXISTS public."Auditoria_Edicion_Pago" (
    id_auditoria UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_pago UUID NOT NULL REFERENCES public."Transaccion_Pago"(id_pago) ON DELETE CASCADE,
    id_orden UUID NOT NULL REFERENCES public."Orden_Venta"(id_orden) ON DELETE CASCADE,
    id_usuario UUID NOT NULL REFERENCES public."Usuario"(id_usuario),
    fecha_edicion TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    campo_modificado VARCHAR(50) NOT NULL,
    valor_anterior VARCHAR(255) NOT NULL,
    valor_nuevo VARCHAR(255) NOT NULL,
    motivo TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_auditoria_edicion_pago_orden ON public."Auditoria_Edicion_Pago"(id_orden);
CREATE INDEX IF NOT EXISTS idx_auditoria_edicion_pago_pago ON public."Auditoria_Edicion_Pago"(id_pago);
```

---

## 3. Matriz de Escenarios: Qué se Permite y Qué se Descartó Categóricamente

A diferencia de un archivo Excel donde una cajera podría sobrescribir cualquier celda sin restricciones, este sistema gestiona **piezas automotrices únicas con número de motor, chasis, tokens QR de despacho y control físico de portón**. Permitir modificaciones indiscriminadas destruiría la integridad operativa.

A continuación se detalla la matriz de seguridad con los ejemplos planteados:

| Escenario Operativo | Estado de la Orden | ¿Se Permite Editar? | Comportamiento del Sistema y Justificación |
|---|---|---|---|
| **1. Corrección de Medio de Pago** (Ej: Era Transferencia bancaria y se marcó Efectivo por omisión) | `Reservada`, `Pagada`, `Completada` |  **PERMITIDO** | **100% Seguro.** No afecta el stock físico ni el balance adeudado. Corrige de inmediato el arqueo de caja y la conciliación bancaria. Registra auditoría con motivo. |
| **2. Corrección de Fecha/Hora de Imputación** (Ej: Cobro de ayer ingresado hoy) | `Reservada`, `Pagada`, `Completada` |  **PERMITIDO** | Permite regularizar la jornada contable. Se valida estrictamente que la fecha **no sea futura** (`fecha <= now()`). |
| **3. Corrección de Monto de Abono Parcial** (Ej: Cliente abonaba $50.000 pero se digitó $60.000) | Solo en `Reservada` |  **PERMITIDO** | Se permite modificar el valor **siempre que el nuevo total de abonos sea menor al total de la venta**. El sistema recalcula matemáticamente `monto_pendiente` en la orden y `monto_abonado` en la reserva backorder. |
| **4. Simular Liquidación Total editando un Abono** (Ej: Venta de $500.000, abono de $50.000; intentar subir el abono a $500.000 desde el historial) | `Reservada` | ❌ **DESCARTADO / BLOQUEADO** | **Riesgo Crítico.** Simular una liquidación total editando un abono bypassearía el flujo formal de caja, no validaría la entrega física de la pieza, ni activaría las validaciones de token QR de salida. **Regla:** Para liquidar el saldo de una reserva, la cajera debe usar la bandeja de cobros oficial ("Liquidar Saldo"). El endpoint rechaza con `HTTP 400` y el frontend bloquea el formulario. |
| **5. Reducir Monto de Pago en Orden Pagada o Entregada** (Ej: Venta pagada de $500.000; intentar bajarla a $50.000 en el historial) | `Pagada`, `Despachada`, `Completada` | ❌ **DESCARTADO / BLOQUEADO** | **Riesgo Máximo de Fraude/Robo.** En una orden `Pagada` o `Completada`, la pieza ya fue retirada de bodega o el cliente ya cuenta con el código QR de portón liberado. Si se permitiera reducir el pago a $50.000, la orden quedaría mágicamente con saldo pendiente mientras el repuesto físico ya salió de la empresa. En el frontend el campo de monto se **deshabilita visualmente** y en el backend se rechaza con `HTTP 400 Bad Request`. |
| **6. Orden ya Anulada** | `Anulada` | ❌ **DESCARTADO / BLOQUEADO** | Los registros contables de órdenes anuladas son inmutables por ley y normativa contable. Rechazo automático. |

### ¿Qué se debe hacer en casos de errores graves en órdenes Pagadas?
Si una orden de $500.000 fue cobrada por error como liquidación completa y resulta que el cliente no pagó o el valor fue erróneo:
- **La solución oficial y segura es:** **Anular la Orden** a través de la función `anular_orden`.
- **Por qué:** La anulación devuelve las piezas físicas (motor, caja de cambio, repuestos) formalmente al stock disponible, invalida cualquier QR de portón emitido y requiere autorización explícita, manteniendo la cuadratura y evitando pérdidas de inventario.

---

## 4. Detalle de Cambios Técnicos Implementados

### 4.1 Backend (FastAPI / SQLAlchemy / Pydantic)

1. **Modelo `Auditoria_Edicion_Pago`** ([`backend/models.py`]):
   - Campos: `id_auditoria`, `id_transaccion`, `id_orden`, `id_usuario`, `fecha_edicion`, `monto_anterior`, `monto_nuevo`, `metodo_anterior`, `metodo_nuevo`, `fecha_pago_anterior`, `fecha_pago_nueva`, `motivo`.
2. **Esquemas Pydantic** ([`backend/schemas.py`]):
   - `EditarPagoRequest`: Validación de `nuevo_monto > 0`, `motivo` con mínimo 10 caracteres y máximo 255 caracteres, `nueva_fecha_pago` opcional.
   - `EditarPagoResponse`: Respuesta enriquecida con `id_transaccion`, `id_orden`, balances actualizados (`monto_pendiente_actualizado`, `total_liquidado_actualizado`) y `mensaje`.
3. **Endpoint Controlador** ([`backend/routers/caja.py`]):
   - `PATCH /api/v1/caja/pagos/{id_pago}`.
   - Seguridad: Restringido a roles autorizados (`Cajero`, `Supervisor`, `Administrador`).
   - Bloqueos de invariantes de negocio (estados, topes, fechas futuras).
   - Recálculo atómico de `monto_pendiente` en `Orden_Venta` y sincronización con `Reservas_Backorder.monto_abonado`.
4. **Línea de Tiempo y Trazabilidad** ([`backend/routers/caja.py`]/backend/routers/caja.py) y [`backend/routers/ordenes.py`]backend/routers/ordenes.py:
   - Las correcciones se integran en `historial_movimientos` con el tag `[CORRECCIÓN DE PAGO]`, detallando el usuario responsable, timestamp, cambio realizado y justificación obligatoria.

### 4.2 Frontend (Flutter / Material 3)

1. **CajaService** ([`frontend/lib/features/caja/services/caja_service.dart`]):
   - Definición e implementación de `Future<Map<String, dynamic>> editarPago(...)`.
2. **Modal `EditarPagoDialog`** ([`frontend/lib/features/caja/presentation/widgets/editar_pago_dialog.dart`]):
   - **Resumen visual superior:** Muestra Total Venta, Monto Actual del Pago y Saldo Restante en tarjetas adaptativas.
   - **Formulario interactivo:**
     - Selector de método de pago (Efectivo, Débito, Crédito, Transferencia, Cheque).
     - Input de monto con formateador de miles CLP y recálculo en tiempo real del saldo resultante. Deshabilitado reactivamente en órdenes `Pagada` o `Completada`.
     - Selector modal de fecha y hora para imputación contable.
     - Campo obligatorio de motivo con validación de al menos 10 caracteres.
   - **Garantía Anti-Overflow:** Implementado con `LayoutBuilder` y `Wrap` responsivo, certificado contra pantallas angostas (hasta 320px de ancho) sin desbordamientos de pixeles (`RenderFlex overflow`).
3. **Integración en `DetalleAuditoriaDialog`** ([`frontend/lib/features/caja/presentation/widgets/detalle_auditoria_dialog.dart`]):
   - Se añadió un botón de acción rápida `[Corregir]` con icono lápiz en cada registro del desglose de pagos. Al guardar una modificación, el modal retorna `true` para forzar la recarga de datos en segundo plano.
4. **Refresco Reactivo en `HistorialCajaScreen`** ([`frontend/lib/features/caja/presentation/screens/historial_caja_screen.dart`]):
   - Al cerrar el modal de detalle tras una corrección, la pantalla invoca `_cargarHistorialSilencioso()` para actualizar los totales y estados inmediatamente sin parpadeos ni recargas invasivas.

---

## 5. Matriz de Pruebas y Verificación

### 5.1 Pruebas Backend (`backend/tests/test_caja_edicion_pagos.py`)
Se crearon 10 pruebas automatizadas con SQLite en memoria y FastAPI TestClient:
1. `test_editar_metodo_pago_exitoso`: Modifica método de Efectivo a Transferencia; verifica persistencia y registro en auditoría.
2. `test_editar_monto_abono_orden_reservada_exitoso`: Modifica abono de $40.000 a $50.000; valida recálculo de saldo a $50.000.
3. `test_rechazo_abono_supera_o_iguala_total_venta`: Intenta modificar abono para cubrir 100% de la venta; valida rechazo `HTTP 400`.
4. `test_rechazo_modificar_monto_en_orden_pagada`: Intenta reducir monto en orden Pagada; valida rechazo `HTTP 400` y mensaje instructivo de anulación.
5. `test_permitir_modificar_metodo_en_orden_pagada`: Permite corregir medio de pago en orden Pagada sin alterar balances.
6. `test_rechazo_fecha_futura`: Valida rechazo `HTTP 400` al enviar una fecha en el futuro.
7. `test_rechazo_motivo_muy_corto`: Valida rechazo `HTTP 422` con motivo menor a 10 caracteres.
8. `test_rechazo_orden_anulada`: Valida inmutabilidad de órdenes en estado `Anulada`.
9. `test_rechazo_rol_no_autorizado`: Valida código `HTTP 403` para usuarios sin rol de caja o supervisión.
10. `test_auditoria_reflejada_en_historial_movimientos`: Verifica que la línea de tiempo de la orden contenga la traza de auditoría completa.

> **Resultado Backend:** **40 de 40 pruebas aprobadas (100% pass)** en 4.39s.

### 5.2 Pruebas Frontend Flutter (`frontend/test/features/caja/editar_pago_dialog_test.dart`)
Se ejecutaron pruebas de widgets con el framework oficial de Flutter:
1. *Renderiza correctamente cabecera, resumen de orden y campos del formulario.*
2. *En orden Reservada, permite editar monto y muestra recálculo dinámico del saldo.*
3. *En orden Pagada, bloquea la edición del monto del pago.*
4. *Valida que el motivo tenga al menos 10 caracteres.*
5. *Envía petición al servicio con datos válidos y cierra modal.*
6. *Garantía Anti-Overflow en resolución estrecha (320px) sin excepciones de RenderFlex.*

> **Resultado Frontend:** **66 de 66 pruebas aprobadas (100% pass)** en `test/features/caja/`.

---

## 6. Conclusión
La funcionalidad dota al personal de caja y supervisores de la flexibilidad operativa necesaria para subsanar errores humanos frecuentes en segundos, sin riesgo de descuadre contable, respetando la seguridad de los inventarios físicos y manteniendo una trazabilidad de auditoría inalterable.

