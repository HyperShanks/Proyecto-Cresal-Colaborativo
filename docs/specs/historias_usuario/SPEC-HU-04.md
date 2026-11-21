# SPEC-HU-04: Confirmación Financiera, Asignación de Cajera, Emisión de QR y Diálogo de Salida

## 1. Contexto, Referencias y Archivos Afectados

- **Objetivo**: Extender el endpoint transaccional de cobro en backend para inyectar la autoría de la cajera (`id_cajera`), transicionar estados (`Pagada`, `Reservada`, `Confirmada`) y generar el hash criptográfico `qr_transaccional_salida` solo al liquidar el 100%. En frontend, construir el diálogo modal reactivo (`ResultadoCobroDialog`) y la limpieza de cola en memoria, validando su estructura contra el prototipo HTML y el sistema de diseño central.

- **Archivos de Referencia Obligatoria para Inspección (Lectura previa sin alterar)**:
  - `prototipo_caja_sprint4.html`: Fuente de verdad visual y estructural para la disposición, espaciados y jerarquía del modal de confirmación.
  - `RULES.md`: Reglas y estándares de arquitectura, seguridad Zero Trust y patrones de concurrencia.
  - `frontend/lib/core/theme/tokens/app_palette.dart`: Paleta semántica obligatoria (cero colores hardcodeados).
  - `backend/models.py`: Modelo relacional inmutable (`Transaccion_Pago`, `Orden_Venta`, `Reservas_Backorder`).

- **Archivos a Crear**:
  - `frontend/lib/features/caja/presentation/widgets/resultado_cobro_dialog.dart`
  - `frontend/test/features/caja/resultado_cobro_dialog_test.dart`

- **Archivos a Modificar**:
  - `backend/schemas.py`: Extender `RegistrarCobroResponse` con el campo `qr_generado: Optional[str] = None`.
  - `backend/routers/caja.py`: Inyectar `id_cajera = current_user.id_usuario`, generar hash `TX-QR-[UUID]` si el saldo es `$0`, y actualizar los estados correspondientes dentro del bloque `try...except db.rollback()`.
  - `backend/tests/test_caja_cobros.py`: Añadir casos de prueba para validación de QR, autoría de cajera y transiciones de estado.
  - `frontend/lib/features/caja/models/cobro_model.dart`: Agregar la propiedad `qrGenerado` en el modelo de respuesta.
  - `frontend/lib/features/caja/presentation/providers/caja_provider.dart`: Incorporar método para remover la orden procesada de la lista de pendientes y resetear el panel lateral al estado inicial.
  - `frontend/lib/features/caja/presentation/widgets/panel_detalle_cobro.dart`: Conectar la respuesta exitosa del backend con la apertura del diálogo modal de confirmación.


## 2. Contratos de Datos y Firmas de API

### 2.1 Backend (FastAPI / Pydantic V2)

- **DTOs y Schemas (`backend/schemas.py`)**:
*(Nota: `RegistrarCobroRequest` e items se mantienen sin cambios desde HU-03. `id_cajera` nunca se expone en el body de petición por regla Zero Trust).*

```python
from typing import List, Optional
from uuid import UUID
from pydantic import BaseModel, ConfigDict

# --- DTO de Respuesta Extendido para HU-04 ---
class RegistrarCobroResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    success: bool
    mensaje: str
    folio: str
    monto_cobrado: int
    nuevo_saldo_pendiente: int
    estado_actualizado: str
    transacciones_ids: List[UUID]
    qr_generado: Optional[str] = None  # Contiene 'TX-QR-[UUID]' en liquidación al 100%, o None en abonos


class RegistrarCobroResponseModel {
  final bool success;
  final String mensaje;
  final String folio;
  final int montoCobrado;
  final int nuevoSaldoPendiente;
  final String estadoActualizado;
  final List<String> transaccionesIds;
  final String? qrGenerado; // Null si es Abono o Backorder, String si es Liquidación Total

  RegistrarCobroResponseModel({
    required this.success,
    required this.mensaje,
    required this.folio,
    required this.montoCobrado,
    required this.nuevoSaldoPendiente,
    required this.estadoActualizado,
    required this.transaccionesIds,
    this.qrGenerado,
  });

  factory RegistrarCobroResponseModel.fromJson(Map<String, dynamic> json) {
    return RegistrarCobroResponseModel(
      success: json['success'] as bool? ?? false,
      mensaje: json['mensaje'] as String? ?? '',
      folio: json['folio'] as String? ?? '',
      montoCobrado: json['monto_cobrado'] as int? ?? 0,
      nuevoSaldoPendiente: json['nuevo_saldo_pendiente'] as int? ?? 0,
      estadoActualizado: json['estado_actualizado'] as String? ?? '',
      transaccionesIds: (json['transacciones_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      qrGenerado: json['qr_generado'] as String?,
    );
  }
}
```

## 3. Reglas de Negocio, Casos de Borde y Seguridad

1. **Autoría Confiable y Zero Trust (Backend):**
   - El campo `id_cajera` tanto en `Orden_Venta` como en `Reservas_Backorder` debe asignarse obligatoriamente desde `current_user.id_usuario` (extraído del token JWT).
   - Queda estrictamente denegado aceptar identificadores de cajera enviados en el cuerpo JSON de la petición.

2. **Transiciones de Estado y Generación de Hash QR (Backend - CA-03, CA-04, CA-05):**
   - **Liquidación Total de Venta (`monto_pendiente == 0`):**
     - `estado_orden = 'Pagada'`.
     - `qr_transaccional_salida = f"TX-QR-{uuid.uuid4()}"` (Cadena única de autorización para barrera/bodega).
     - `id_cajera = current_user.id_usuario`.
   - **Abono Parcial en Venta (`monto_pendiente > 0`):**
     - Se actualiza `monto_pendiente = monto_pendiente - monto_declarado`.
     - `estado_orden = 'Reservada'` (Mantiene la retención del stock físico).
     - `id_cajera = current_user.id_usuario`.
     - `qr_transaccional_salida = None` (No se autoriza retiro físico).
   - **Abono en Backorder (Reserva en Verde):**
     - Se incrementa `monto_abonado = monto_abonado + monto_declarado`.
     - `estado_reserva = 'Confirmada'` (Habilita la reserva para match logístico).
     - `id_cajera = current_user.id_usuario`.
     - No aplica generación de QR transaccional.

3. **Atomicidad Transaccional ACID (Backend - CA-01, CA-02):**
   - Toda la secuencia (inserción de filas en `Transaccion_Pago`, actualización de saldos, cambio de estado, asignación de cajera y generación de QR) debe encapsularse en un único bloque `try...except`.
   - Ante cualquier excepción en base de datos o fallo de validación, se ejecuta `db.rollback()` inmediato para evitar registros de cobro huérfanos o inconsistencias contables.

4. **Comportamiento Reactivo del Diálogo Modal (Frontend - CA-06):**
   - La estructura, padding y jerarquía visual deben corresponder a la referencia en `prototipo_caja_sprint4.html`, utilizando los tokens semánticos de `AppPalette`.
   - **Caso Liquidación Total (100% Saldado):**
     - Círculo de estado en `AppPalette.success` con icono `Icons.check_circle_rounded`.
     - Mensaje textual explícito: *"QR Transaccional generado para barrera de salida"*.
     - **Restricción Estricta:** NO renderizar ninguna imagen, SVG o widget gráfico de código QR en la pantalla de caja.
   - **Caso Abono Parcial / Backorder:**
     - Círculo de estado en `AppPalette.primary` con icono `Icons.receipt_long_rounded`.
     - Banner de advertencia en fondo `AppPalette.warningBg` y texto `AppPalette.warningText` indicando la retención física sin entrega.
     - Fila destacada en tarjeta con el importe exacto del *"Nuevo Saldo Pendiente"*.

5. **Acción "Siguiente Orden" y Limpieza de Cola en Memoria (Frontend - CA-06):**
   - Al pulsar el botón "Siguiente Orden" en el modal:
     - Cerrar el diálogo flotante (`Navigator.of(context).pop()`).
     - Remover de inmediato el elemento seleccionado de la lista reactiva de pendientes en `CajaProvider` para despejar la bandeja de trabajo.
     - Resetear el panel lateral derecho al estado vacío inicial (Empty State con `Icons.account_balance_wallet_rounded`).

6. **Estándares Flutter y Protección de Concurrencia:**
   - Mientras la petición `registrarCobro` esté en curso, deshabilitar el botón de acción principal y mostrar `CircularProgressIndicator` para evitar envíos duplicados por doble clic.
   - Es obligatorio el uso de guardias `if (!mounted) return;` antes de invocar `showDialog` o interactuar con el `BuildContext` tras llamadas asíncronas.


## 4. Checklist de Tareas de Implementación (TDD)

- [ ] **Tarea 1 (Backend - Schemas):** Extender `RegistrarCobroResponse` en `backend/schemas.py` agregando el campo opcional `qr_generado: Optional[str] = None`.
- [ ] **Tarea 2 (Backend - Endpoint & Lógica ACID):** Actualizar `POST /api/v1/caja/cobros/registrar` en `backend/routers/caja.py` para inyectar `id_cajera = current_user.id_usuario`, generar el hash criptográfico `TX-QR-[UUID]` cuando `monto_pendiente == 0`, y transicionar los estados a `Pagada`, `Reservada` o `Confirmada` dentro del bloque `try...except db.rollback()`.
- [ ] **Tarea 3 (Backend - Pruebas Pytest):** En `backend/tests/test_caja_cobros.py`, agregar aserciones que verifiquen:
  - Generación obligatoria del hash QR en pagos totales al 100% y cambio a estado `Pagada`.
  - Ausencia de QR (`qr_generado is None`) y preservación del estado `Reservada` en abonos parciales.
  - Actualización a estado `Confirmada` en backorders.
  - Registro correcto del `id_cajera` autenticado en la base de datos.
- [ ] **Tarea 4 (Frontend - DTOs y Modelos):** Actualizar `RegistrarCobroResponseModel` en `frontend/lib/features/caja/models/cobro_model.dart` para parsear el campo `qr_generado`.
- [ ] **Tarea 5 (Frontend - Provider & Limpieza de Cola):** En `frontend/lib/features/caja/presentation/providers/caja_provider.dart`, implementar el método `removerOrdenProcesada(String idDocumento)` para quitar la orden de la lista reactiva en memoria y reiniciar el panel lateral derecho al estado inicial (Empty State).
- [ ] **Tarea 6 (Frontend - Diálogo Modal Dinámico):** Crear `frontend/lib/features/caja/presentation/widgets/resultado_cobro_dialog.dart` siguiendo la estructura de `prototipo_caja_sprint4.html` y los tokens de `AppPalette`:
  - Modo Liquidación Total: Encabezado verde (`AppPalette.success`), mensaje de autorización de salida con QR generado (sin renderizar imagen de código de barras/QR).
  - Modo Abono / Backorder: Encabezado azul (`AppPalette.primary`), banner ámbar de retención de stock y fila destacada con el "Nuevo Saldo Pendiente".
  - Botón "Siguiente Orden": Dispara la limpieza de la cola y el cierre del diálogo.
- [ ] **Tarea 7 (Frontend - Conexión & Mounted Guards):** En `frontend/lib/features/caja/presentation/widgets/panel_detalle_cobro.dart`, conectar la respuesta exitosa del provider con la apertura del diálogo modal (`ResultadoCobroDialog`), garantizando el uso de `if (!mounted) return;` y bloqueo reactivo de pulsaciones duplicadas durante la carga.
- [ ] **Tarea 8 (Frontend - Pruebas de Widgets):** Crear `frontend/test/features/caja/resultado_cobro_dialog_test.dart` para validar la renderización condicional (Liquidación vs. Abono), visualización del nuevo saldo pendiente y el disparo del callback "Siguiente Orden".

---

## 5. Criterios de Validación Automatizada

La especificación se considerará cumplida cuando se ejecuten exitosamente los 4 comandos de validación:

1. **Backend Tests:**
```bash
cd backend && pytest tests/test_caja_cobros.py -v

cd backend && flake8 routers/caja.py --count --select=E9,F63,F7,F82

cd frontend && flutter test test/features/caja/resultado_cobro_dialog_test.dart

cd frontend && flutter analyze lib/features/caja/