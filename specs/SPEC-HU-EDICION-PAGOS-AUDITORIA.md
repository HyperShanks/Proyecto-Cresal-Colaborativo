# ESPECIFICACIÓN TÉCNICA Y FUNCIONAL: EDICIÓN CONTROLADA DE PAGOS, POKA-YOKE Y AUDITORÍA EN CAJA

**Código de Especificación:** `SPEC-HU-EDICION-PAGOS-AUDITORIA`  
**Módulo:** Caja / Bandeja de Cobros / Historial de Órdenes  
**Fecha de Implementación Original:** Octubre 2026  
**Fecha de Extensión y Actualización:** Noviembre 2026  
**Estado:** Especificación Completa y Aprobada para Implementación  

---

## 1. Contexto y Necesidad de Negocio

En la operación diaria de mesón y caja de Cresal Repuestos, se suscitan errores humanos comunes derivados del uso de terminales POS desacoplados (terminales físicos Transbank/Redelcom independientes del software de gestión):
- **Anticipación en el software antes de la respuesta del POS físico:** La cajera presiona "Confirmar Cobro" en el sistema asumiendo que la tarjeta del cliente pasará, pero el POS arroja *Tarjeta rechazada*, *Fondos insuficientes* o el cliente solicita cambiar o repartir el medio de pago.
- **Confusión o división de métodos de pago:** Un cliente iba a cancelar $500.000 con débito, pero tras ser rechazada o por falta de cupo, cancela $200.000 con débito y $300.000 en efectivo o transferencia.
- **Error de digitación en montos de abono:** Al registrar un anticipo o reserva de una pieza (por ejemplo, digitando $60.000 en vez de los $50.000 pactados).
- **Desfase en la fecha/hora de imputación:** Se aclara que la fecha de registro en caja debe ser automática (`NOW()`) para preservar la integridad del arqueo diario de caja.

### El Problema Detectado con la Solución Inicial (Limitaciones Operativas)
1. **Limitación 1 a 1:** La herramienta anterior (`EditarPagoDialog`) solo permitía editar una fila de pago existente de forma aislada. Si se registró un pago único de $500.000, no permitía dividirlo en 2 o más métodos ($200.000 Débito + $300.000 Efectivo).
2. **Bloqueo Rígido en `Pagada` / `Completada`:** El sistema bloqueaba cualquier edición de montos en órdenes pagadas, impidiendo tanto el rebalanceo multimétodo (que mantiene el mismo total) como la reversión de pagos fallidos.
3. **Fricción Crítica con Mesón de Ventas:** Al estar bloqueada la cajera, la única solución existente era llamar al vendedor para que anulara la orden completa desde Mesón (`anular_orden`). Esto destruía la cotización, revertía la reserva de piezas críticas y obligaba a redactar la orden desde cero, colapsando la atención.

### Solución Ampliada
Se habilita una arquitectura integral que combina:
1. **Prevención Poka-Yoke antes del cobro:** Modal interactivo de confirmación visual en la bandeja de cobros antes de registrar el pago.
2. **Rebalanceo Multimétodo ($1 \to N$ con Suma Idéntica):** Permite redistribuir métodos de pago manteniendo el mismo total recaudado, habilitado en órdenes `Reservada`, `Pagada` y `Completada` sin tocar inventarios ni tokens QR.
3. **Reversión Segura de Cobro Erróneo a `Reservada` (Deshacer Cobro):** Permite a caja reversar un cobro fallido o parcial sin intervención de Mesón, invalidando atómicamente el código QR de salida, retornando las piezas al estado `Reservado` y devolviendo la orden a la Bandeja de Cobros para su cobro definitivo.

---

## 2. Decisiones de Arquitectura y Base de Datos

### 2.1 Adopción de la Opción A (Sin columnas ociosas en `Transaccion_Pago`)
- **Decisión:** Se mantiene la estructura de `Transaccion_Pago`. El flujo de caja no captura comprobantes ni números de voucher para no generar columnas ociosas innecesarias.
- Si en el futuro se integra un POS vía API o se exige voucher obligatorio, se implementará el ciclo completo de captura.

### 2.2 Estrategia de Auditoría: Tabla Aditiva en Producción
- La tabla `Auditoria_Edicion_Pago` es **100% aditiva**. No altera ni bloquea ninguna tabla existente (`Orden_Venta`, `Transaccion_Pago`, `Reservas_Backorder`, etc.).
- En PostgreSQL / Supabase, se ejecuta de manera idempotente sin interrupción de servicios:

```sql
CREATE TABLE IF NOT EXISTS public."Auditoria_Edicion_Pago" (
    id_auditoria UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_pago UUID REFERENCES public."Transaccion_Pago"(id_pago) ON DELETE CASCADE,
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

### 2.3 Clarificación de Estados Operativos Reales
- **Aclaración Crítica de Negocio:** El estado `Despachada` y la tabla `Despacho` **no están operativas en producción actualmente**.
- El ciclo de vida de las órdenes en el sistema se rige estricta y exclusivamente por 4 estados reales:
  1. **`Reservada`:** Orden emitida por Mesón con saldo pendiente (con o sin abonos parciales). Repuestos físicos en estado `Reservado`.
  2. **`Pagada`:** Saldo liquidado al 100%. Repuestos físicos en estado `Vendido` y token `qr_transaccional_salida` emitido.
  3. **`Completada`:** Saldo liquidado al 100% en ventas que no requieren entrega física de activos inventariados (misceláneos / servicios).
  4. **`Anulada`:** Venta cancelada formalmente con reversa total de inventario y pagos.

---

## 3. Matriz de Seguridad y Reglas de Negocio

| Escenario Operativo | Estado de la Orden | ¿Se Permite? | Comportamiento del Sistema y Justificación |
|---|---|---|---|
| **1. Rebalanceo de Métodos de Pago** (Mismo Total, ej: $500k Débito pasa a $200k Débito + $300k Efectivo) | `Reservada`, `Pagada`, `Completada` |  **PERMITIDO** | **100% Seguro.** La suma de nuevos pagos es idéntica al total recaudado. No altera inventario físico ni QR de salida. Corrige arqueo de caja con auditoría. |
| **2. Reversión de Cobro Erróneo a `Reservada`** (Pago falló al 100% o cliente solo abona parte) | `Pagada`, `Completada` |  **PERMITIDO (Acción Explícita)** | **Seguridad Garantizada.** Invalida de inmediato `qr_transaccional_salida = NULL`, regresa piezas de `Vendido` a `Reservado`, ajusta pagos y reabre la orden en la Bandeja de Cobros. |
| **3. Corrección de Monto de Abono Parcial** (Ej: digitó $60.000 en vez de $50.000) | Solo en `Reservada` |  **PERMITIDO** | Modifica el valor siempre que la suma total de abonos sea estrictamente menor al total de la venta. Recalcula `monto_pendiente` y reserva backorder. |
| **4. Simular Liquidación Total editando un Abono** (Subir abono para cubrir el 100% desde el historial) | `Reservada` | ❌ **BLOQUEADO** | Para liquidar el saldo, la cajera debe usar el flujo formal de cobro ("Liquidar Saldo"). Rechazo con `HTTP 400`. |
| **5. Modificación de Fecha por Cajera** | Todos los estados | ❌ **BLOQUEADO (Automático)** | La fecha de pago se fija automáticamente en `NOW()`. Solo perfiles de Supervisor/Admin pueden regularizar marcas temporales excepcionales. |
| **6. Orden ya Anulada** | `Anulada` | ❌ **BLOQUEADO** | Registros contables inmutables por ley y normativa de auditoría. |

---

## 4. Los 7 Caminos Felices de Caja (Flujo Normal)

A continuación se detallan todas las secuencias estándar de operación exitosa:

| Camino Feliz | Tipo de Operación | Estado Inicial | Pago Realizado | Estado Final Orden | Estado Activo Físico | QR Salida | Destino Visual |
|---|---|---|---|---|---|---|---|
| **1. Contado Inmediato** | Repuesto Físico | `Reservada` | 100% Total | **`Pagada`** | `Vendido` (id: 3) |  Emitido | *Historial de Caja* |
| **2. Contado Misceláneo**| Sin Activo Físico | `Reservada` | 100% Total | **`Completada`** | N/A | ❌ NULL | *Historial de Caja* |
| **3. Abono Inicial Reserva**| Repuesto Físico | `Reservada` | Parcial ($\ge$ piso) | **`Reservada`** | `Reservado` (id: 2) | ❌ NULL | *Bandeja de Cobros* |
| **4. Abono Venta en Verde**| Backorder sin activo | `Reservada` | Parcial ($\ge$ piso) | **`Reservada`** | N/A | ❌ NULL | *Bandeja de Cobros* |
| **5. Abonos Sucesivos** | Mixto / Saldo | `Reservada` | Parcial | **`Reservada`** | Sin cambio | ❌ NULL | *Bandeja de Cobros* |
| **6. Liquidación Reserva**| Repuesto Físico | `Reservada` | Saldo restante (100%)| **`Pagada`** | `Vendido` (id: 3) |  Emitido | *Historial de Caja* |
| **7. Liquidación Backorder**| Venta en Verde | `Reservada` | Saldo restante (100%)| **`Pagada`** | `Vendido` (si hay SKU) o N/A |  Solo si hay SKU | *Historial de Caja* |

---

## 5. Los 4 Caminos de Conflicto y Error de Caja

Situaciones donde la cajera se adelanta o el pago físico falla:

### Escenario E1: Rebalanceo Multimétodo (Mismo Total, Error de Medio)
* **Situación:** Venta de $500.000. Cajera marcó $500.000 Débito. La tarjeta no cubrió el total y el cliente paga $200.000 Débito y $300.000 Efectivo.
* **Resolución del Sistema:**  
  Permite sustitución $1 \to N$ donde $\sum \text{Nuevos Pagos} == \sum \text{Pagos Anteriores}$.  
  No modifica inventario físico ni invalida el código QR. Se cancelan las transacciones anteriores, se crean las nuevas y se registra auditoría.

### Escenario E2: El Fiasco Total (Marcada como `Pagada`, Pago Falló al 100%)
* **Situación:** Cajera confirmó $500.000 en el sistema, pero el POS rechazó todas las tarjetas del cliente. El cliente se retira sin pagar.
* **Resolución del Sistema (Acción "Reversar Cobro por Error en Pago"):**
  1. `orden.qr_transaccional_salida = NULL` (invalidación inmediata del token de salida).
  2. Activos inventariados regresan de `Vendido` a `Reservado` a nombre de la orden.
  3. Se anulan las transacciones de pago erróneas.
  4. `orden.monto_pendiente` vuelve al 100% de la venta ($500.000).
  5. `orden.estado_orden` regresa a **`Reservada`**.
  6. La orden vuelve a aparecer en la Bandeja de Cobros de Caja.

### Escenario E3: De Contado a Abono Parcial (Fallo de Cupo)
* **Situación:** Venta de $500.000 marcada como pagada. La tarjeta solo aprobó $100.000. El cliente deja esos $100.000 como abono y volverá por la tarde a pagar los $400.000 restantes.
* **Resolución del Sistema (Acción "Reversar Cobro y Declarar Abono Real"):**
  1. `orden.qr_transaccional_salida = NULL` (el cliente no puede retirar el repuesto).
  2. Activos inventariados regresan de `Vendido` a `Reservado`.
  3. Se ajusta el registro de pago al monto real ($100.000).
  4. `orden.monto_pendiente = $400.000`.
  5. `orden.estado_orden` pasa a **`Reservada`**.
  6. La orden queda en la Bandeja de Cobros con saldo pendiente de $400.000.

### Escenario E4: Error de Digitación en Abono de Orden `Reservada`
* **Situación:** Cliente abona $50.000 y la cajera digitó $60.000.
* **Resolución del Sistema:**  
  Como la orden nunca salió de `Reservada`, no hay afectación de QR ni de activos. Se corrige el monto del abono mediante la interfaz actual de edición de abono, recalculando el saldo pendiente y guardando auditoría.

---

## 6. Especificación de Experiencia de Usuario (UI/UX Poka-Yoke)

### 6.1 Modal Poka-Yoke Pre-Cobro (`panel_detalle_cobro.dart`)
Antes de invocar el endpoint de cobro definitivo, se despliega un diálogo modal de confirmación con:
1. **Resumen Financiero:** Total Venta (considerando descuentos aplicados en Mesón), Abonos Previos y Monto a Cobrar en la sesión.
2. **Desglose de Métodos:** Lista clara de los medios seleccionados con icono distintivo (Efectivo, Débito, Crédito, Transferencia).
3. **Tarjeta de Impacto Operativo Resultante:**
   - Si la orden queda saldada al 100%: Banner verde con icono `check_circle`:  
     **"La orden pasará a PAGADA y se emitirá el Código QR para retiro de repuestos en bodega."**
   - Si la orden queda con saldo pendiente: Banner ámbar con icono `pending_actions`:  
     **"La orden permanecerá en RESERVADA con un saldo pendiente de $X. NO se emitirá código QR de salida."**
4. **Mensaje de Seguridad:** *"Por favor verifique que los comprobantes del terminal POS físico hayan sido impresos y aprobados antes de confirmar."*
5. **Acciones:** Botón secundario `[Volver y Revisar]` y botón principal `[Confirmar y Registrar Pago]`.

### 6.2 Modal de Rebalanceo Multimétodo (`rebalancear_pagos_dialog.dart`)
Accesible desde el Historial de Caja:
- Muestra el Total Recaudado actual (fijo e inmutable).
- Lista dinámica de métodos con botones `[+ Agregar Método]` y `[- Quitar]`.
- Indicador en vivo de diferencia: *"Total: $500.000 | Distribuido: $500.000 | Diferencia: $0"*.
- El botón `[Guardar Rebalanceo]` solo se activa si la diferencia es exactamente $0 y el motivo cuenta con al menos 10 caracteres.

### 6.3 Acción "Reversar Cobro por Error en Pago"
Accesible desde el detalle de la orden en Historial de Caja para órdenes `Pagada` o `Completada`:
- Botón en color ámbar/alerta con icono `history_rounded`.
- Diálogo modal con advertencia explícita:  
  *"Esta acción anulará los pagos de esta transacción, invalidará inmediatamente el Código QR de salida y regresará los repuestos a estado RESERVADO. La orden volverá a la Bandeja de Cobros."*
- Campo obligatorio de motivo de reversión (mínimo 15 caracteres) y confirmación de seguridad.

---

## 7. Cambios Técnicos en Backend (FastAPI / SQLAlchemy)

### 7.1 Nuevo Endpoint de Rebalanceo Multimétodo
* **Ruta:** `POST /api/v1/caja/ordenes/{id_orden}/rebalancear-pagos`
* **Permisos:** Roles de Caja, Supervisor y Administrador.
* **Payload (`RebalancearPagosRequest`):**
  - `nuevos_pagos`: Lista de `{ metodo: MetodoPagoEnum, monto: int }`.
  - `motivo`: String obligatoria ($\ge 10$ caracteres).
* **Validaciones:**
  - $\sum \text{nuevos\_pagos} == \sum \text{pagos\_actuales\_orden}$.
  - Orden no puede estar en estado `Anulada`.
* **Efectos:** Da de baja transacciones anteriores, inserta nuevos registros y registra bitácora en `Auditoria_Edicion_Pago`.

### 7.2 Nuevo Endpoint de Reversión Segura a Reservada
* **Ruta:** `POST /api/v1/caja/ordenes/{id_orden}/reversar-cobro`
* **Permisos:** Roles de Caja, Supervisor y Administrador.
* **Payload (`ReversarCobroRequest`):**
  - `monto_abono_real`: Opcional (0 si el cliente no pagó nada; monto mayor a 0 si dejó abono parcial legítimo).
  - `metodo_abono_real`: Requerido si `monto_abono_real > 0`.
  - `motivo`: String obligatoria ($\ge 15$ caracteres).
* **Efectos Atómicos:**
  - `orden.qr_transaccional_salida = NULL`.
  - `orden.estado_orden = "Reservada"`.
  - Activos inventariados de la orden: `id_estado = 2 (Reservado)`.
  - Si hay backorder: `monto_abonado` ajustado a `monto_abono_real`.
  - Recálculo de `orden.monto_pendiente = orden.total_venta - monto_abono_real`.
  - Inserción de registro en `Auditoria_Edicion_Pago` con tag `[REVERSIÓN DE COBRO]`.

---

## 8. Matriz de Pruebas Automatizadas

### Backend (`backend/tests/test_caja_edicion_pagos.py`)
1. `test_rebalanceo_multimetodo_exitoso`: Reemplaza 1 pago de $500.000 por 2 de $200.000 y $300.000; valida que total no cambie y registre auditoría.
2. `test_rebalanceo_rechazo_suma_distinta`: Intenta rebalancear $500.000 con suma de $450.000; valida `HTTP 400 Bad Request`.
3. `test_reversar_cobro_total_exitoso`: Orden pagada con QR; reversa a $0 pagado. Valida que `qr_transaccional_salida` sea `None`, activos pasen a `Reservado` y orden quede en `Reservada`.
4. `test_reversar_cobro_a_abono_parcial`: Orden pagada de $500.000 reversada a abono de $100.000. Valida `monto_pendiente = $400.000`, `qr = None` y piezas en `Reservado`.
5. `test_reversar_cobro_rechazo_motivo_corto`: Valida rechazo `HTTP 422` con motivo menor a 15 caracteres.
6. `test_reversar_cobro_orden_anulada_rechazo`: Valida inmutabilidad de órdenes en estado `Anulada`.

### Frontend (`frontend/test/features/caja/`)
1. Pre-modal Poka-Yoke: Verifica renderizado de desglose, alerta preventiva y textos diferenciales según orden `Pagada` vs `Reservada`.
2. Diálogo Rebalanceo: Verifica cálculo dinámico de diferencia y habilitación del botón Guardar solo cuando diferencia es $0.
3. Diálogo Reversión: Verifica confirmación explícita, advertencia de invalidación de QR y envío de solicitud al servicio.
4. Cobertura de regresión: Garantizar 100% pass en la suite existente de pruebas de caja.
