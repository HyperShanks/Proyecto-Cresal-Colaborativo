# SPEC-HU-TAREA-23: Auditoría Obligatoria de Anulaciones y Despaletizados con Notificaciones en Tiempo Real para Gerencia vía Telegram

## 1. Contexto y Justificación del Negocio

### 1.1 Problema Operativo y Vulnerabilidades Actuales
1. **Anulaciones Ciegas en Mesón y Caja**:
   - Actualmente, una orden de venta puede anularse sin registrar de forma persistente la causa raíz, la justificación detallada ni la identidad forense del responsable.
   - En la tabla `Orden_Venta`, el estado cambia a `'Anulada'`, pero no existen columnas para auditar `motivo_anulacion`, `observacion_anulacion`, `id_usuario_anulacion` ni `fecha_anulacion`.
   - Esto impide identificar si las anulaciones corresponden a desistimientos reales de clientes, errores reiterados de digitación de vendedores, quiebres de inventario no detectados o eventuales prácticas fraudulentas.
2. **Despaletizado Ciego en WMS (Bodega y Patio)**:
   - Al despaletizar un repuesto (`POST /api/v1/inventario/{id_activo}/despaletizar`), el sistema resetea a `NULL` los campos `ubicacion_galpon`, `ubicacion_pasillo` y `ubicacion_pallet`, y concatena un string simple en `observacion_estado VARCHAR(255)`.
   - Dicha columna tiene un límite estricto de 255 caracteres, arriesgando caídas con `DataError: value too long for type character varying(255)`.
   - Se pierde completamente el historial de dónde estaba ubicado el activo antes de salir a un estado flotante (`En Desarme`), imposibilitando auditorías de mermas, pérdidas o desorden logístico.
3. **Ceguera Informativa de la Gerencia**:
   - La Gerencia General y Auditoría no disponen de un mecanismo proactivo para enterarse de eventos de alto impacto financiero y operativo sin entrar al software y consultar pantallas manualmente.
   - Para no sobrecargar la infraestructura con plataformas de mensajería complejas (descartando dependencias de Google Firebase FCM / Google Services en clientes de escritorio Windows y móviles Android), se requiere canalizar las alertas críticas ejecutivas directamente a un canal seguro y universal: **Telegram Bot**.

### 1.2 Objetivos de la Tarea
1. **Aduana Poka-Yoke de Justificación**:
   - Exigir obligatoriamente la selección de un motivo tipificado y una observación justificada con un mínimo de 10 caracteres útiles antes de autorizar cualquier anulación de orden o despaletizado de repuesto.
2. **Trazabilidad Forense en Base de Datos**:
   - Enriquecer `Orden_Venta` con columnas de anulación.
   - Crear la tabla `Bitacora_Movimiento_Inventario` para registrar la ubicación física previa de cada repuesto despaletizado y la justificación del bodeguero.
   - Crear la tabla `Notificacion_Sistema` para almacenar la bitácora de mensajes enviados a Telegram, permitiendo reintentos y tolerancia a fallos.
3. **Notificaciones Inmediatas para Gerencia vía Telegram**:
   - Despacho asíncrono en segundo plano (`BackgroundTasks` de FastAPI) para los eventos neurálgicos de mayor impacto:
     1. **Venta Regular Pagada al 100% (Solo con Repuestos Inventariados)**: Confirmación de recaudación en Caja. Se filtran y omiten ventas puramente libres o misceláneas (`id_activo IS NULL` sin backorder).
     2. **Venta en Verde Pagada al 100% (Reserva Backorder)**: Alerta prioritaria de compromiso comercial por repuesto por desarmar o adquirir, con datos de contacto del cliente y vehículo requerido.
     3. **Entrega / Despacho Físico**: Salida física de repuesto desde Bodega hacia el cliente.
     4. **Anulación de Orden de Venta**: Alerta de reversa de venta, motivo y usuario auditor.
     5. **Despaletizado de Repuesto**: Alerta de retiro de pallet en patio con SKU, ubicación previa y justificación técnica.

---

## 2. Archivos Afectados

### 2.1 Backend (FastAPI / SQLAlchemy)
- `backend/models.py`:
  - Enriquecer modelo `Orden_Venta` con 4 columnas de auditoría de anulación.
  - Crear modelo `Bitacora_Movimiento_Inventario`.
  - Crear modelo `Notificacion_Sistema`.
- `backend/schemas.py`:
  - Actualizar `AnularOrdenRequest` con validadores de motivo y longitud mínima de observación ($\ge 10$ caracteres).
  - Crear `DespaletizarActivoRequest` con validadores de motivo y longitud mínima de observación ($\ge 10$ caracteres).
  - Enriquecer `OrdenAnulacionResponse` y schemas de inventario asociados.
- `backend/routers/ordenes.py`:
  - Actualizar `anular_orden_post`: persistir motivo, observación, usuario y fecha; disparar notificación asíncrona a Telegram en segundo plano.
- `backend/routers/inventario.py`:
  - Actualizar `despaletizar_activo`: recibir `DespaletizarActivoRequest`, registrar entrada en `Bitacora_Movimiento_Inventario` capturando la ubicación física previa, limpiar pallet y disparar notificación asíncrona a Telegram en segundo plano.
- `backend/routers/caja.py` y `backend/routers/bodega.py`:
  - Integrar disparadores de notificación a Telegram para eventos de **Venta Pagada** y **Despacho / Entrega**.
- **Nuevo**: `backend/services/telegram_service.py`:
  - Servicio centralizado y asíncrono para formatear y enviar alertas con Telegram Bot API vía `httpx` sin bloquear la respuesta al usuario.

### 2.2 Frontend (Flutter)
- `frontend/lib/features/ventas/presentation/widgets/modal_anular_orden.dart`:
  - Integrar selector desplegable de motivos tipificados.
  - Agregar campo de texto para justificación detallada con validación Poka-Yoke interactiva (contador visual de caracteres, bloqueo del botón hasta alcanzar 10 caracteres).
  - Mantener temporizador de 5 segundos y confirmación consciente.
- `frontend/lib/features/ventas/services/ventas_service.dart` y `ordenes_service.dart`:
  - Enviar `motivo` y `observacion` en la carga útil de anulación.
- `frontend/lib/features/inventario/presentation/widgets/dialogo_despaletizar.dart`:
  - Rediseñar el diálogo para uso táctil en bodega/patio (PDA Android y Windows).
  - Botones táctiles ergonómicos para selección de motivo.
  - Campo de texto obligatorio para justificación operativa ($\ge 10$ caracteres).
- `frontend/lib/features/inventario/services/inventario_service.dart`:
  - Actualizar método `despaletizarActivo` para enviar `motivo` y `observacion`.

---

## 3. Contratos de Datos y Esquema de Base de Datos

```
┌─────────────────────────────────┐           ┌──────────────────────────────────────┐
│          Orden_Venta            │           │   Bitacora_Movimiento_Inventario     │
├─────────────────────────────────┤           ├──────────────────────────────────────┤
│ id_orden (UUID, PK)             │           │ id_bitacora (SERIAL, PK)             │
│ estado_orden (VARCHAR)          │           │ id_activo (UUID, FK Activo)          │
│ total_venta (INT)               │           │ id_usuario (UUID, FK Usuario)        │
│ ...                             │           │ tipo_evento (VARCHAR(50))            │
│ motivo_anulacion (VARCHAR(100)) │           │ ubicacion_anterior (VARCHAR(100))    │
│ observacion_anulacion (TEXT)    │           │ ubicacion_nueva (VARCHAR(100))       │
│ id_usuario_anulacion (UUID, FK) │           │ motivo (VARCHAR(100))                │
│ fecha_anulacion (TIMESTAMPTZ)   │           │ observacion (TEXT)                   │
└─────────────────────────────────┘           │ fecha_registro (TIMESTAMPTZ)         │
                                              └──────────────────────────────────────┘
                                                                 │
                                                                 ▼
                                              ┌──────────────────────────────────────┐
                                              │        Notificacion_Sistema          │
                                              ├──────────────────────────────────────┤
                                              │ id_notificacion (SERIAL, PK)         │
                                              │ canal (VARCHAR(20))                  │
                                              │ destinatario (VARCHAR(100))          │
                                              │ tipo_evento (VARCHAR(50))            │
                                              │ referencia_id (VARCHAR(100))         │
                                              │ mensaje (TEXT)                       │
                                              │ estado (VARCHAR(20))                 │
                                              │ intentos (INT)                       │
                                              │ ultimo_error (TEXT)                  │
                                              │ fecha_creacion (TIMESTAMPTZ)         │
                                              │ fecha_envio (TIMESTAMPTZ)            │
                                              └──────────────────────────────────────┘
```

### 3.1 DDL SQL de Migración

```sql
-- 1. Enriquecer Orden_Venta con auditoría de anulación
ALTER TABLE "Orden_Venta"
  ADD COLUMN IF NOT EXISTS motivo_anulacion VARCHAR(100) NULL,
  ADD COLUMN IF NOT EXISTS observacion_anulacion TEXT NULL,
  ADD COLUMN IF NOT EXISTS id_usuario_anulacion UUID NULL REFERENCES "Usuario"(id_usuario),
  ADD COLUMN IF NOT EXISTS fecha_anulacion TIMESTAMP WITH TIME ZONE NULL;

-- 2. Crear tabla de bitácora para movimientos de inventario y WMS
CREATE TABLE IF NOT EXISTS "Bitacora_Movimiento_Inventario" (
  id_bitacora SERIAL PRIMARY KEY,
  id_activo UUID NOT NULL REFERENCES "Activo_Inventariado"(id_activo) ON DELETE CASCADE,
  id_usuario UUID NOT NULL REFERENCES "Usuario"(id_usuario),
  tipo_evento VARCHAR(50) NOT NULL, -- 'DESPALETIZADO', 'PALETIZADO', 'REUBICACION', 'AJUSTE'
  ubicacion_anterior VARCHAR(100) NULL, -- Ej: 'Galpón 1 | Pasillo B | Pallet 04'
  ubicacion_nueva VARCHAR(100) NULL,    -- Ej: 'Sin Pallet / En Desarme'
  motivo VARCHAR(100) NOT NULL,
  observacion TEXT NOT NULL,
  fecha_registro TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bitacora_activo ON "Bitacora_Movimiento_Inventario"(id_activo);
CREATE INDEX IF NOT EXISTS idx_bitacora_fecha ON "Bitacora_Movimiento_Inventario"(fecha_registro DESC);

-- 3. Crear tabla de resiliencia y auditoría de notificaciones del sistema
CREATE TABLE IF NOT EXISTS "Notificacion_Sistema" (
  id_notificacion SERIAL PRIMARY KEY,
  canal VARCHAR(20) NOT NULL DEFAULT 'TELEGRAM',
  destinatario VARCHAR(100) NOT NULL, -- Chat ID del grupo o usuario de Gerencia
  tipo_evento VARCHAR(50) NOT NULL,   -- 'VENTA_PAGADA', 'DESPACHO_ENTREGA', 'ORDEN_ANULADA', 'REPUESTO_DESPALETIZADO'
  referencia_id VARCHAR(100) NOT NULL,-- ID de orden, folio o SKU
  mensaje TEXT NOT NULL,
  estado VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE', -- 'PENDIENTE', 'ENVIADO', 'FALLIDO'
  intentos INTEGER NOT NULL DEFAULT 0,
  ultimo_error TEXT NULL,
  fecha_creacion TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  fecha_envio TIMESTAMP WITH TIME ZONE NULL
);

CREATE INDEX IF NOT EXISTS idx_notif_estado ON "Notificacion_Sistema"(estado);
```

### 3.2 Schemas Pydantic (`backend/schemas.py`)

```python
class AnularOrdenRequest(BaseModel):
    """Payload obligatorio para anulación de órdenes."""
    model_config = ConfigDict(from_attributes=True)
    
    motivo: str = Field(..., description="Motivo tipificado de la anulación")
    observacion: str = Field(..., min_length=10, description="Justificación detallada de la anulación")

    @field_validator("observacion")
    @classmethod
    def validar_observacion(cls, v: str) -> str:
        v_clean = v.strip()
        if len(v_clean) < 10:
            raise ValueError("La justificación u observación debe tener al menos 10 caracteres explicativos.")
        return v_clean


class DespaletizarActivoRequest(BaseModel):
    """Payload obligatorio para despaletizar un activo en bodega/patio."""
    model_config = ConfigDict(from_attributes=True)
    
    motivo: str = Field(..., description="Motivo tipificado del despaletizado")
    observacion: str = Field(..., min_length=10, description="Justificación detallada del movimiento")

    @field_validator("observacion")
    @classmethod
    def validar_observacion(cls, v: str) -> str:
        v_clean = v.strip()
        if len(v_clean) < 10:
            raise ValueError("La justificación u observación debe contener al menos 10 caracteres explicativos.")
        return v_clean
```

---

## 4. Experiencia de Usuario & Reglas Poka-Yoke

### 4.1 Modal de Anulación de Órdenes (`ModalAnularOrden`)
1. **Catálogo Tipificado de Motivos**:
   - `Desistimiento voluntario del cliente`: El cliente cambia de opinión o cancela compra.
   - `Error en digitación o repuesto erróneo`: Vendedor digitó un repuesto equivocado o precio incorrecto.
   - `Quiebre de stock físico o pieza defectuosa`: La pieza no se encuentra físicamente o se detectó fisura/daño al retirar.
   - `Duplicidad de orden`: Se emitió más de una orden para la misma transacción.
   - `Anulación administrativa autorizada`: Autorización especial de Gerencia o Jefatura.
2. **Aduana de Caracteres Poka-Yoke**:
   - Campo de texto multilínea con placeholder explicativo: *"Detalle el motivo exacto de la cancelación para la bitácora de auditoría y gerencia..."*.
   - Contador en tiempo real: `X / 10 caracteres mínimos requeridos`.
   - Mensaje de validación dinámico: si `texto.trim().length < 10`, se despliega en color naranja/rojo y se inhabilita el botón de confirmación.
3. **Mecanismos de Seguridad Preexistentes**:
   - Temporizador regresivo de 5 segundos (`_segundosRestantes`).
   - Casilla de confirmación consciente: *"He leído la advertencia y entiendo el impacto de anular esta orden"*.
   - Ambos factores deben cumplirse simultáneamente con la validación de caracteres para habilitar el botón **CONFIRMAR ANULACIÓN**.

### 4.2 Modal Táctil de Despaletizado en Bodega (`DialogoDespaletizar`)
1. **Ergonomía Industrial Táctil (Uso con guantes en PDA)**:
   - Botones tipo tarjeta/chip de gran tamaño (mínimo 48px de alto) para pulsar con facilidad en terreno:
     - 🏷️ `Preparación Venta / Despacho Inmediato`
     - ⚠️ `Merma / Daño Físico Detectado`
     - 🔄 `Garantía o Devolución a Revisión Técnica`
     - 📦 `Reubicación a Otro Pasillo o Nivel`
     - ❓ `Otro Motivo Operativo`
2. **Justificación Obligatoria**:
   - Input de observación con validación de $\ge 10$ caracteres útiles.
3. **Trazabilidad de Ubicación Previa en Pantalla**:
   - Se muestra visualmente la ubicación que será liberada:
     `Ubicación Actual: Galpón [X] ➔ Pasillo [Y] ➔ Pallet [Z]`.
   - Alerta visual: *"Esta pieza quedará sin ubicación registrada en WMS hasta ser repaletizada"*.

---

## 5. Servicio de Notificaciones Telegram para Gerencia

### 5.1 Configuración de Entorno (`.env`)
```bash
TELEGRAM_BOT_TOKEN="123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
TELEGRAM_GERENCIA_CHAT_ID="-1009876543210" # ID de canal o grupo privado de Gerencia
TELEGRAM_ENABLED="true"
```

### 5.2 Despacho Asíncrono No Bloqueante
- Las transacciones de Caja, Bodega y Mesón ejecutan primero su `db.commit()` garantizando integridad ACID inmediata.
- El envío hacia Telegram se delega a `BackgroundTasks` de FastAPI o a un hilo asíncrono no bloqueante con timeout estricto de 4 segundos.
- Si Telegram API no responde o hay pérdida de conexión a internet, se guarda el registro en `Notificacion_Sistema` con estado `'FALLIDO'`, sin generar jamás un error 500 al operador ni retrasar el flujo de venta.

### 5.3 Plantillas de Mensaje Markdown para Gerencia

#### 🔔 Disparador 1.A: Venta Regular Pagada al 100% (Solo con Repuestos Inventariados)
> **Regla de Negocio Poka-Yoke**: Este mensaje se dispara **únicamente** si la orden contiene al menos un repuesto inventariado físico (`Detalle_Orden.id_activo IS NOT NULL`). Si la orden está compuesta al 100% por ítems manuales, misceláneos o venta libre, se descarta silenciosamente para evitar saturar el canal de Gerencia con ventas menores no controladas por WMS.

```markdown
💰 *VENTA PAGADA EN CAJA (INVENTARIADO)*
━━━━━━━━━━━━━━━━━━━━━━
📋 *Orden:* `{folio}`
👤 *Cliente:* {cliente_nombre} ({rut_cliente})
💼 *Vendedor:* {vendedor_nombre}
🏦 *Cajero(a):* {cajero_nombre}
💵 *Monto Total:* ${total_venta}
💳 *Medio de Pago:* {medio_pago}
📦 *Repuestos Inventariados:* {cantidad_items_inventariados} pieza(s)
━━━━━━━━━━━━━━━━━━━━━━
⏱️ _{fecha_hora}_
```

#### 🌱 Disparador 1.B: Venta en Verde Pagada al 100% (Reserva Backorder)
> **Regla de Negocio**: Se dispara cuando una orden catalogada como **Venta en Verde** (`Reservas_Backorder` vinculada o ítem con prefijo `[VENTA EN VERDE]`) es cobrada al 100% en Caja. Aunque no posee SKU físico asignado de inmediato, es un compromiso comercial crítico que requiere seguimiento de compras o desarme prioritario en patio.

```markdown
🌱 *NUEVA VENTA EN VERDE PAGADA (RESERVA)*
━━━━━━━━━━━━━━━━━━━━━━
📋 *Orden:* `{folio}`
👤 *Cliente:* {cliente_nombre} ({rut_cliente})
📞 *Teléfono:* {telefono_contacto}
🚗 *Vehículo / Pieza:* {categoria_requerida} - {marca_requerida} {modelo_requerido}
💼 *Vendedor:* {vendedor_nombre}
🏦 *Cajero(a):* {cajero_nombre}
💵 *Monto Pagado:* ${monto_pagado}
💳 *Medio de Pago:* {medio_pago}
━━━━━━━━━━━━━━━━━━━━━━
⚠️ *Compromiso:* Pendiente de asignación física de repuesto en patio/bodega
⏱️ _{fecha_hora}_
```

#### 📦 Disparador 2: Entrega Física en Barrera de Salida (Bodega PDA / Dual-Scan)
> **Regla de Negocio (Zero Bypass)**: Se gatilla **única y exclusivamente** cuando el bodeguero realiza la validación exitosa del **Dual-Scan en la Barrera de Salida** (`POST /api/v1/bodega/escanear-salida`), validando el QR Transaccional de la orden frente al SKU físico del repuesto. Los ítems misceláneos o de venta libre entregados en mesón no pasan por barrera y no disparan este mensaje.

```markdown
🚚 *REPUESTO ENTREGADO EN BARRERA DE SALIDA*
━━━━━━━━━━━━━━━━━━━━━━
📋 *Orden:* `{folio}`
👤 *Cliente:* {cliente_nombre}
📦 *Repuesto:* {descripcion_pieza}
🏷️ *SKU:* `{sku}`
👷 *Validado en Barrera por:* {bodeguero_nombre}
🏢 *Sucursal:* {sucursal_nombre}
━━━━━━━━━━━━━━━━━━━━━━
⏱️ _{fecha_hora}_
```

#### ⚠️ Disparador 3: Anulación de Orden de Venta (Auditoría)
```markdown
⚠️ *ALERTA: ORDEN DE VENTA ANULADA*
━━━━━━━━━━━━━━━━━━━━━━
📋 *Orden:* `{folio}`
💵 *Monto Anulado:* ${total_venta}
👤 *Usuario Responsable:* {usuario_nombre} ({rol_nombre})
🎯 *Motivo:* *{motivo_anulacion}*
📝 *Observación:*
_{observacion_anulacion}_
━━━━━━━━━━━━━━━━━━━━━━
🔄 *Stock:* {cantidad_items} repuesto(s) liberados a inventario
⏱️ _{fecha_hora}_
```

#### 🚨 Disparador 4: Despaletizado de Repuesto (Alerta Inventario WMS)
```markdown
🚨 *ALERTA: REPUESTO DESPALETIZADO*
━━━━━━━━━━━━━━━━━━━━━━
🏷️ *SKU:* `{sku}`
📦 *Pieza:* {nombre_categoria} - {marca_modelo}
📍 *Ubicación Previa:* Galpón {galpon} | Pasillo {pasillo} | Pallet {pallet}
👷 *Operario:* {bodeguero_nombre}
🎯 *Motivo:* *{motivo_despaletizado}*
📝 *Justificación:*
_{observacion_despaletizado}_
━━━━━━━━━━━━━━━━━━━━━━
⚠️ *Estado Actual:* En Desarme (Sin ubicación fija)
⏱️ _{fecha_hora}_
```

---

## 6. Contratos de API (Endpoints)

### 6.1 Anulación de Orden
- **Ruta**: `POST /api/v1/ordenes/{id_orden}/anular`
- **Permisos**: Vendedor titular, Jefe de Ventas, Administrador o Gerente.
- **Payload Request**:
  ```json
  {
    "motivo": "Quiebre de stock físico o pieza defectuosa",
    "observacion": "El cliente vino a retirar la puerta pero presenta una abolladura no reportada en la foto original."
  }
  ```
- **Respuesta (200 OK)**:
  ```json
  {
    "id_orden": "a3b1c2d3-...",
    "estado_orden": "Anulada",
    "mensaje": "Orden anulada exitosamente. Stock devuelto a inventario.",
    "motivo_anulacion": "Quiebre de stock físico o pieza defectuosa",
    "activos_liberados": 1,
    "pagos_reversados": 0,
    "monto_reversado": 0
  }
  ```
- **Respuesta Error (422 Unprocessable Entity)**: Si `observacion` tiene menos de 10 caracteres o `motivo` está vacío.

### 6.2 Despaletizado de Repuesto
- **Ruta**: `POST /api/v1/inventario/{id_activo}/despaletizar`
- **Permisos**: Bodeguero, Jefe de Bodega o Administrador.
- **Payload Request**:
  ```json
  {
    "motivo": "Merma / Daño Físico Detectado",
    "observacion": "Se detectó fisura en el soporte metálico al mover el pallet en pasillo B."
  }
  ```
- **Respuesta (200 OK)**:
  ```json
  {
    "id_activo": "b4c2d3e4-...",
    "sku_qr_fisico": "ACT-2026-00452",
    "mensaje": "Activo despaletizado exitosamente. Bitácora de auditoría registrada.",
    "id_estado": 5,
    "ubicacion_anterior": "Galpón 1 | Pasillo A | Pallet 02",
    "motivo": "Merma / Daño Físico Detectado"
  }
  ```

---

## 7. Criterios de Aceptación (Definition of Done)

### 7.1 Persistencia y Base de Datos
- [ ] La migración de base de datos agrega las columnas a `Orden_Venta` y crea las tablas `Bitacora_Movimiento_Inventario` y `Notificacion_Sistema` sin corromper datos previos.
- [ ] Cada anulación guarda con fidelidad el `id_usuario_anulacion`, `fecha_anulacion`, `motivo_anulacion` y `observacion_anulacion`.
- [ ] Cada despaletizado guarda en la bitácora los valores exactos que tenían `ubicacion_galpon`, `ubicacion_pasillo` y `ubicacion_pallet` antes de su limpieza a `NULL`.

### 7.2 Aduana Poka-Yoke en Frontend
- [ ] El diálogo `ModalAnularOrden` bloquea el botón si la justificación no alcanza 10 caracteres útiles.
- [ ] El diálogo `DialogoDespaletizar` exige seleccionar un motivo y redactar al menos 10 caracteres antes de permitir la confirmación.
- [ ] Los tests unitarios en Flutter verifican que textos con espacios vacíos o menos de 10 caracteres impidan el envío.

### 7.3 Notificaciones Telegram para Gerencia
- [ ] Los 4 eventos (Venta Pagada, Entrega, Anulación y Despaletizado) envían el mensaje formateado al grupo de Telegram configurado.
- [ ] El envío a Telegram corre como tarea en segundo plano asíncrona: una falla o demora en la API de Telegram no congela ni aborta la transacción del usuario.
- [ ] Todo intento de notificación queda asentado en `Notificacion_Sistema` con su estado correspondiente (`ENVIADO` o `FALLIDO`).

### 7.4 Compatibilidad y Regresión
- [ ] El suite existente de pruebas unitarias (`pytest backend/tests` y `flutter test`) continúa ejecutándose al 100% sin regresiones.
