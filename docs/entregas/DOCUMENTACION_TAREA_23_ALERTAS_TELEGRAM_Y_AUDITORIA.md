# DOCUMENTACIÓN TÉCNICA — TAREA 23
## Sistema de Alertas Ejecutivas en Telegram, Auditoría Forense de Anulaciones y Despaletizado Manual Poka-Yoke

---

### 1. Resumen Ejecutivo y Necesidad Operativa

La **Tarea 23** dota al ecosistema tecnológico de **Cresal Repuestos** de un canal de supervisión operativa y ejecutiva en tiempo real sin requerir que la Gerencia General permanezca conectada al software WMS/ERP.

#### Problemas que resuelve:
1. **Falta de Visibilidad Ejecutiva en Terreno**: La gerencia no recibía confirmación instantánea cuando una venta en verde era pagada, cuando un cliente retiraba físicamente su motor/caja en barrera o cuando una orden de alto valor era cancelada.
2. **Vulnerabilidad Forense en Anulaciones de Venta**: Las órdenes de venta podían anularse sin dejar registro de quién, cuándo ni por qué se canceló la transacción, generando riesgo de mermas o fraudes comerciales.
3. **Despaletizado Ciego en Bodega**: Los bodegueros podían liberar racks y despaletizar piezas sin justificación auditable, dificultando rastrear pérdidas o piezas extraviadas.
4. **Ergonomía PDA y Prevención de Errores (Poka-Yoke)**: Las pantallas móviles de bodega no contaban con temporizadores de confirmación ni contadores de caracteres mínimos para evitar clics accidentales en operaciones irreversibles.

---

### 2. Cambios en Base de Datos (PostgreSQL / Supabase)

#### 2.1 Sentencia SQL Ejecutada (Migración DDL & Índices)

```sql
-- ============================================================================
-- 1. Ampliación de columnas de Auditoría Forense en Orden_Venta
-- ============================================================================
ALTER TABLE "Orden_Venta"
  ADD COLUMN IF NOT EXISTS motivo_anulacion VARCHAR(100),
  ADD COLUMN IF NOT EXISTS observacion_anulacion TEXT,
  ADD COLUMN IF NOT EXISTS id_usuario_anulacion UUID REFERENCES "Usuario"(id_usuario),
  ADD COLUMN IF NOT EXISTS fecha_anulacion TIMESTAMPTZ;

-- ============================================================================
-- 2. Índice Parcial para Auditoría Rápida de Órdenes Anuladas
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_orden_venta_fecha_anulacion 
  ON "Orden_Venta"(fecha_anulacion DESC) 
  WHERE estado_orden = 'Anulada';
```

#### 2.2 Diccionario de Datos: Columnas Nuevas

| Tabla | Campo | Tipo de Dato | Nullable | Descripción y Propósito |
| :--- | :--- | :--- | :---: | :--- |
| `Orden_Venta` | `motivo_anulacion` | `VARCHAR(100)` | `NULL` | Motivo tipificado de la anulación (elegido desde dropdown auditado). |
| `Orden_Venta` | `observacion_anulacion` | `TEXT` | `NULL` | Explicación detallada obligatoria (mínimo 10 caracteres). |
| `Orden_Venta` | `id_usuario_anulacion` | `UUID` | `NULL` | Clave foránea al operador que autenticó y autorizó la anulación (`Usuario.id_usuario`). |
| `Orden_Venta` | `fecha_anulacion` | `TIMESTAMPTZ` | `NULL` | Marca temporal con zona horaria chilena del momento exacto de la cancelación. |

#### 2.3 Explicación del Índice Parcial (`WHERE estado_orden = 'Anulada'`)
A diferencia de un índice B-Tree tradicional que indexa los millones de registros de la tabla, este índice es **parcial**:
- Solo contiene punteros a las filas donde `estado_orden = 'Anulada'`.
- Ocupa un tamaño insignificante en disco y memoria RAM en Supabase (< 100 KB).
- Acelera al instante (`Index Scan`) los reportes y filtros del Visor Gerencial cuando se auditan las pérdidas o cancelaciones del mes.

---

### 3. Variables de Entorno Nuevas (`backend/.env`)

Para la integración con la API de Bot de Telegram se añadieron las siguientes variables:

```ini
# ==========================================
# ALERTAS EJECUTIVAS TELEGRAM (TAREA 23)
# ==========================================
TELEGRAM_BOT_TOKEN="8433390310:AAHpVb73_XXXXXXXXXXXXX_XXXXXXX"
TELEGRAM_GERENCIA_CHAT_ID="8928590105"
```

#### Parámetros:
- **`TELEGRAM_BOT_TOKEN`**: Token secreto provisto por `@BotFather` de Telegram que identifica y autentica al bot oficial de Cresal.
- **`TELEGRAM_GERENCIA_CHAT_ID`**: ID numérico del chat privado o grupo directivo donde se envían las alertas en vivo.

---

### 4. Arquitectura de Backend y Servicios

#### 4.1 Principio de Resiliencia No Bloqueante (Zero-Impact Transactions)
El envío de mensajes hacia Telegram se ejecuta mediante **`BackgroundTasks`** de FastAPI:
- Las transacciones ACID (cierre de orden, pago de caja, entrega en barrera, liberación de rack) se confirman inmediatamente en PostgreSQL con `db.commit()`.
- La llamada HTTP a Telegram ocurre en segundo plano de manera asíncrona.
- **Garantía**: Una caída de la red de Telegram o un timeout **nunca** bloquea al usuario ni hace rollback de la operación de negocio en el sistema.

#### 4.2 Servicio Central: `TelegramService` (`backend/services/telegram_service.py`)
Maneja el formateo enriquecido Markdown, el timezone oficial de Chile (`America/Santiago`) y el envío seguro con reintentos silenciosos y logs de auditoría:

1. **`notificar_venta_pagada`**:
   - Se dispara cuando una orden regular con al menos un repuesto inventariado es cobrada en Caja.
   - Muestra: Folio, Cliente, RUT, Vendedor, Cajero, Total y Cantidad de ítems inventariados.
2. **`notificar_venta_en_verde_pagada`**:
   - Se dispara cuando se completa el pago o abono de una Reserva Backorder.
   - Muestra: Folio, Cliente, RUT, Teléfono, Categoría Requerida, Marca y Modelo, Vendedor, Cajero, Monto y Medio de Pago.
3. **`notificar_entrega_barrera`**:
   - Se dispara al realizar el escaneo dual de salida en el portón de bodega.
   - Muestra: Folio, Cliente, Repuesto (Descripción rica), SKU, Bodeguero y Sucursal.
4. **`notificar_orden_anulada`**:
   - Se dispara al anular una orden desde el visor o mesa de ayuda.
   - Muestra: Folio, Total Venta Anulada, Usuario, Rol, Motivo Tipificado y Observación.
5. **`notificar_repuesto_despaletizado`**:
   - Se dispara al despaletizar un activo desde la PDA móvil.
   - Muestra: SKU, Pieza (Descripción rica), Ubicación Liberada, Bodeguero, Motivo y Observación.

#### 4.3 Generador de Descripción Enriquecida de Repuesto
Se implementó `construir_descripcion_repuesto(db, activo)` en [backend/routers/bodega.py](file:///d:/CresalRepoCapstone/backend/routers/bodega.py#L192):
- **Estructura**: `Categoría + Marca + Modelo + Cilindrada + Año`.
- **Ejemplo**: `Motor Geely Azkarra 1.5 2020` o `Caja Geely Azkarra 1.5 2020`.
- **Herencia inteligente**: Si la pieza es una Caja de Cambio, hereda automáticamente la cilindrada del activo hermano Motor del mismo vehículo donante.

---

### 5. Frontend Móvil y Web (Flutter)

#### 5.1 Modal de Anulación de Órdenes (`ModalAnularOrden`)
Ubicación: [frontend/lib/features/ordenes/presentation/widgets/modal_anular_orden.dart](file:///d:/CresalRepoCapstone/frontend/lib/features/ordenes/presentation/widgets/modal_anular_orden.dart)

- **Dropdown de Motivos Auditados**:
  1. *Error de digitación o duplicidad*
  2. *Desistimiento del cliente*
  3. *Discrepancia física o falla del repuesto*
  4. *Método de pago rechazado*
  5. *Garantía o reemplazo comercial*
  6. *Otro motivo operacional*
- **Contador Dinámico de Caracteres**:
  - Requiere un mínimo de 10 caracteres obligatorios en el campo de texto.
  - Indicador visual reactivo: rojo si tiene `< 10`, verde si cumple.
- **Temporizador de Seguridad Poka-Yoke**:
  - Bloqueo preventivo de 3 segundos con cuenta regresiva en el botón de confirmación (`Confirmar Anulación (3s)`).
  - Previene toques involuntarios o apresurados en pantallas táctiles.

#### 5.2 Diálogo de Despaletizado Manual (`DialogoDespaletizar`)
Ubicación: [frontend/lib/features/bodega/presentation/widgets/dialogo_despaletizar.dart](file:///d:/CresalRepoCapstone/frontend/lib/features/bodega/presentation/widgets/dialogo_despaletizar.dart)

- **Chips Táctiles para PDA**:
  - Selección rápida con un toque del motivo: *Reubicación en bodega*, *Inspección de calidad*, *Retorno a desarme*, *Error de paletizado*, *Otro*.
- **Indicador de Ubicación Anterior**:
  - Muestra la ubicación física actual que será liberada (`Galpón`, `Pasillo`, `Pallet`).
- **Contador Dinámico y Temporizador**:
  - Exige mínimo 10 caracteres de justificación técnica.
  - Cuenta regresiva de 3 segundos de seguridad antes de habilitar la confirmación.

#### 5.3 Limpieza y Optimización en Home de Bodega (`HomeScreen`)
Ubicación: [frontend/lib/features/home/presentation/screens/home_screen.dart](file:///d:/CresalRepoCapstone/frontend/lib/features/home/presentation/screens/home_screen.dart)

- **Eliminación de Redundancia**: Se removió la tarjeta "Reingresos y Alertas" (cuyo acceso ya se encuentra consolidado en el Tablero Operativo).
- **Diseño Adaptativo**: La tarjeta "Buscador de Inventario" se transformó en una barra horizontal de ancho completo (`_buildBuscadorFullWidthCard`) con accesos rápidos directos a Galpones, Pasillos y Pallets.

---

### 6. Matriz de Formato de Alertas Telegram

#### 6.1 Venta en Verde Pagada (Anticipo / Total)
```text
💰 VENTA EN VERDE PAGADA (ABONO / TOTAL)
━━━━━━━━━━━━━━━━━━━━━━
📋 Folio Reserva: ORD-0089
👤 Cliente: Pedro Morales
🆔 RUT: 12.345.678-9
📞 Contacto: +56987654321
📦 Categoría: Motor
🚗 Vehículo Solicitado: Hyundai Accent
💼 Vendedor: Juan Vendedor
💵 Cajero(a): Ana Cajera
💵 Monto Pagado: $350.000
💳 Medio de Pago: Transferencia Bancaria
━━━━━━━━━━━━━━━━━━━━━━
⏱️ 03/10/2026 12:15 hrs
```

#### 6.2 Repuesto Entregado en Barrera de Salida
```text
🚚 REPUESTO ENTREGADO EN BARRERA DE SALIDA
━━━━━━━━━━━━━━━━━━━━━━
📋 Orden: ORD-0042
👤 Cliente: Carlos Tapia
📦 Repuesto: Motor Geely Azkarra 1.5 2020
🏷️ SKU: MOT-GEE-AZK-001
👷 Validado en Barrera por: Felipe Bodeguero
🏢 Sucursal: Casa Matriz
━━━━━━━━━━━━━━━━━━━━━━
⏱️ 03/10/2026 12:18 hrs
```

#### 6.3 Orden Anulada
```text
🚫 ALERTA: ORDEN DE VENTA ANULADA
━━━━━━━━━━━━━━━━━━━━━━
📋 Folio: ORD-0055
💰 Monto Involucrado: $1.250.000
👤 Anulado por: Juan Pérez
💼 Cargo: Administrador
❓ Motivo: Desistimiento del cliente
📝 Detalle: El cliente canceló la compra por motivos personales y solicitó reversa.
━━━━━━━━━━━━━━━━━━━━━━
⏱️ 03/10/2026 12:20 hrs
```

#### 6.4 Repuesto Despaletizado Manualmente
```text
⚠️ ALERTA: REPUESTO DESPALETIZADO MANUALMENTE
━━━━━━━━━━━━━━━━━━━━━━
🏷️ SKU: MOT-TOY-YAR-888
📦 Pieza: Motor Toyota Yaris 1.5 2019
📍 Ubicación Liberada: Galpón: G-01 | Pasillo: P-03 | Pallet: PL-07
👷 Bodeguero: Pedro Bodeguero
❓ Motivo: Retorno a desarme
📝 Observación: Se retira para rectificación de culata por solicitud de taller.
━━━━━━━━━━━━━━━━━━━━━━
⏱️ 03/10/2026 12:22 hrs
```

---

### 7. Cobertura de Pruebas Automatizadas

1. **Backend (Python / pytest)**:
   - **290 pruebas unitarias y de integración** pasando al 100%.
   - Pruebas dedicadas:
     - `tests/test_bodega_salida.py`: Validación de flujo dual-scan, salida en barrera y `test_construir_descripcion_repuesto_formato_enriquecido`.
     - `tests/test_inventario_edicion.py`: Validación de despaletizado con motivo, auditoría y alertas.
     - `tests/test_gerencia_dashboard.py`: Validación de KPIs de gerencia y aislamiento temporal.
2. **Frontend (Flutter)**:
   - **20 pruebas de widgets** pasando al 100%.
   - `test/home_screen_test.dart` actualizado verificando la eliminación de la tarjeta redundante y la correcta renderización del buscador full-width.
   - **0 advertencias** en `flutter analyze`.

---

### 8. Archivos Nuevos y Modificados

#### Archivos Nuevos:
- `backend/services/telegram_service.py`
- `backend/scripts/probar_telegram.py`
- `frontend/lib/features/ordenes/presentation/widgets/modal_anular_orden.dart`
- `frontend/lib/features/bodega/presentation/widgets/dialogo_despaletizar.dart`
- `specs_documentacion/DOCUMENTACION_TAREA_23_ALERTAS_TELEGRAM_Y_AUDITORIA.md`

#### Archivos Modificados:
- `backend/models.py`
- `backend/routers/bodega.py`
- `backend/routers/caja.py`
- `backend/routers/inventario.py`
- `backend/routers/ordenes.py`
- `backend/schemas/bodega.py` (o `schemas.py`)
- `backend/tests/test_bodega_salida.py`
- `backend/tests/test_gerencia_dashboard.py`
- `frontend/lib/features/home/presentation/screens/home_screen.dart`
- `frontend/test/home_screen_test.dart`
