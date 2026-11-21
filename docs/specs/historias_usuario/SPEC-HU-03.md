# SPEC-HU-03: Panel de Detalle de Cobro con Pago Único o Dividido

## 1. Contexto y Archivos Afectados
- **Objetivo**: Implementar la vista del panel de cobro (patrón Master-Detail alimentado directamente del estado en memoria) y su lógica reactiva. En el backend, desarrollar exclusivamente el endpoint transaccional (`POST`) que valide la cuadratura y persista los pagos en la tabla existente, operando con montos estrictamente enteros (CLP). Queda prohibida la alteración de modelos de base de datos.
- **Archivos a crear**:
  - `frontend/lib/features/caja/presentation/widgets/panel_detalle_cobro.dart`
  - `frontend/test/features/caja/panel_detalle_cobro_test.dart`
  - `backend/tests/test_caja_cobros.py`
- **Archivos a modificar**:
  - `backend/routers/caja.py` (Agregar exclusivamente el endpoint `POST /api/v1/caja/cobros/registrar`).
  - `backend/schemas.py` (Definir DTOs `TransaccionPagoItemSchema`, `RegistrarCobroRequest`, `RegistrarCobroResponse`).
  - `frontend/lib/features/caja/services/caja_service.dart` (Agregar método `registrarCobro`).
  - `frontend/lib/features/caja/presentation/providers/caja_provider.dart` (Lógica reactiva de cuadratura y split, alimentada desde el modelo de la lista).
  - `frontend/lib/features/caja/presentation/screens/caja_main_screen.dart` (Integración del panel en la interfaz principal).

## 2. Contratos de Datos y Firmas de API

### 2.1 Backend (FastAPI / Pydantic V2)
*(Nota: El modelo `Transaccion_Pago` ya existe en `models.py` y NO debe ser modificado. Sus columnas actuales son: `id_pago`, `id_orden`, `id_reserva`, `monto` [Integer], `metodo_pago`, `estado_pago`, `fecha_pago`).*

- **DTOs y Schemas (`backend/schemas.py`)**:
```python
from enum import Enum
from typing import List
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field

class TipoOperacionEnum(str, Enum):
    ORDEN = "ORDEN"
    BACKORDER = "BACKORDER"

class ModalidadCobroEnum(str, Enum):
    LIQUIDACION = "LIQUIDACION"
    ABONO = "ABONO"

class MetodoPagoEnum(str, Enum):
    EFECTIVO = "Efectivo"
    DEBITO = "Debito"
    CREDITO = "Credito"
    TRANSFERENCIA = "Transferencia"
    CHEQUE = "Cheque"

class TransaccionPagoItemSchema(BaseModel):
    metodo: MetodoPagoEnum
    monto: int = Field(gt=0, description="El monto por método debe ser mayor a 0 y sin decimales")

class RegistrarCobroRequest(BaseModel):
    tipo_operacion: TipoOperacionEnum
    id_documento: UUID
    modalidad: ModalidadCobroEnum
    monto_declarado: int = Field(gt=0, description="Monto total acordado a pagar")
    pagos: List[TransaccionPagoItemSchema] = Field(min_length=1)

class RegistrarCobroResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    success: bool
    mensaje: str
    folio: str
    monto_cobrado: int
    nuevo_saldo_pendiente: int
    estado_actualizado: str
    transacciones_ids: List[UUID]
```

- **DTOs y Modelos (Frontend - Dart)**:
```dart
class TransaccionPagoItemModel {
  final String metodo;
  final int monto;
  
  TransaccionPagoItemModel({required this.metodo, required this.monto});
  
  Map<String, dynamic> toJson() => {'metodo': metodo, 'monto': monto};
}

class RegistrarCobroRequestModel {
  final String tipoOperacion;
  final String idDocumento;
  final String modalidad;
  final int montoDeclarado;
  final List<TransaccionPagoItemModel> pagos;
  
  RegistrarCobroRequestModel({
    required this.tipoOperacion,
    required this.idDocumento,
    required this.modalidad,
    required this.montoDeclarado,
    required this.pagos,
  });
  
  Map<String, dynamic> toJson() => {
    'tipo_operacion': tipoOperacion,
    'id_documento': idDocumento,
    'modalidad': modalidad,
    'monto_declarado': montoDeclarado,
    'pagos': pagos.map((p) => p.toJson()).toList(),
  };
}
```
## 3. Reglas de Negocio, Casos de Borde y Seguridad

1. **Lectura en Memoria y UI (Frontend):**
   - El widget `PanelDetalleCobro` NO debe ejecutar peticiones HTTP `GET`. Renderiza su contenido consumiendo el objeto ya seleccionado desde el estado del listado (patrón Master-Detail con Eager Loading).
   - **Desglose Adaptativo (CA-01):** Si es `Orden_Venta`, renderiza la lista de repuestos, total venta, abonos previos y saldo. Si es `Reservas_Backorder`, renderiza un grid 2x2 con especificaciones del repuesto a pedido, precio acordado y abono sugerido.
   - **Banner de Advertencia (CA-02):** Si se selecciona la modalidad "Abono", mostrar un banner ámbar indicando: *"Este pago registrará un abono y mantendrá la orden retenida sin emitir código QR de salida"*.

2. **Validación de Cuadratura Financiera (CA-05):**
   - La suma matemática de los montos ingresados en los distintos métodos de pago debe ser **estrictamente igual** al `monto_declarado` a cobrar.
   - **UI Reactiva:** 
     - Si la diferencia es `$0`: El indicador visual cambia a verde y el botón de "Procesar Cobro" se habilita.
     - Si la diferencia es distinta de `$0`: El indicador visual cambia a rojo mostrando el saldo faltante/sobrante y el botón permanece bloqueado.
   - **Auto-relleno (CA-04):** En pago dividido, el sistema debe incluir un botón de "Auto-rellenar restante" que calcule la diferencia y la asigne a la casilla activa.

3. **Protección Anti-Sobrepago y Valores Inválidos (CA-06):**
   - Backend y Frontend rechazarán transacciones con montos negativos o canales con un importe igual a `$0`.
   - **Orden de Venta:** El `monto_declarado` no puede superar el `monto_pendiente` de la orden.
   - **Backorder:** El `monto_declarado` no puede superar la diferencia entre el `precio_acordado` y el total ya abonado.

4. **Atomicidad ACID y Gestión de Estados (Backend):**
   - Todo el flujo del endpoint `POST` debe envolverse en un bloque transaccional: `try ... db.commit() ... except Exception: db.rollback()`.
   - **Transiciones de Estado:**
     - Orden de Venta con saldo resultante en `$0`: Cambia estado a `Pagada` y autoriza generación de QR de salida.
     - Orden de Venta con Abono (saldo > `$0`): Cambia/mantiene estado en `Retenida_Abono` sin emitir QR.
     - Reserva Backorder: Incrementa el monto abonado sin alterar la retención logística de la reserva.

5. **Zero Trust & RBAC (Seguridad Backend):**
   - El endpoint privado debe requerir token JWT válido.
   - Solo se autoriza la ejecución del registro de cobro si el usuario autenticado tiene `id_rol == 3` (Cajera) o `id_rol == 5` (Administrador). Cualquier otro rol retorna `403 Forbidden`.

6. **Estándares Flutter (Ciclo de Vida):**
   - En peticiones asíncronas de guardado que utilicen `BuildContext`, es estrictamente obligatorio usar el guardián `if (!mounted) return;` antes de mostrar *SnackBars* o navegar.
   - Liberar todos los `TextEditingController` en el método `dispose()`.

## 4. Checklist de Tareas de Implementación (TDD)

- [ ] **Tarea 1 (Backend - Schemas):** Definir los DTOs de entrada y salida para el registro de cobros en `backend/schemas.py` (`RegistrarCobroRequest`, `TransaccionPagoItemSchema`, etc.), asegurando que el tipo de dato del monto sea `int`.
- [ ] **Tarea 2 (Backend - Endpoint & ACID):** Desarrollar `POST /api/v1/caja/cobros/registrar` en `backend/routers/caja.py`. Implementar validación de sumatoria matemática, restricción anti-sobrepago, validación de roles (`id_rol` 3 y 5) y persistencia con commit transaccional atómico (`try...except db.rollback()`). 
- [ ] **Tarea 3 (Backend - Pruebas Pytest):** Crear `backend/test/test_caja_cobros.py`. Escribir tests unitarios que verifiquen: inserción exitosa, rechazo por descuadre (400), rechazo por sobrepago (400) y bloqueo por rol inválido (403).
- [ ] **Tarea 4 (Frontend - Servicio Dart):** Implementar la petición HTTP POST en `frontend/lib/features/caja/services/caja_service.dart` y mapear los modelos de envío en `cobro_model.dart`.
- [ ] **Tarea 5 (Frontend - Proveedor Reactivo):** Integrar la lógica de estado en `frontend/lib/features/caja/presentation/providers/caja_provider.dart`. Debe incluir el cálculo matemático en tiempo real para el split de pagos y la función de "Auto-rellenar restante".
- [ ] **Tarea 6 (Frontend - UI y Widget Guards):** Construir `PanelDetalleCobro` (`frontend/lib/features/caja/presentation/widgets/panel_detalle_cobro.dart`). Implementar el diseño Master-Detail (alimentado en memoria), el split payment dinámico con inputs estrictamente numéricos, banner ámbar para abonos, e indicador verde/rojo de cuadratura. Asegurar uso de `dispose()` y `if (!mounted) return;`.
- [ ] **Tarea 7 (Frontend - Pruebas Flutter):** Crear `frontend/test/features/caja/panel_detalle_cobro_test.dart` para asegurar que el botón de confirmación se bloquea si la suma de montos es incorrecta y se habilita solo cuando la diferencia es 0.

---

## 5. Criterios de Validación Automatizada

La historia de usuario se considerará completada únicamente cuando los siguientes comandos se ejecuten sin errores ni advertencias:

1. **Backend Tests:**
```bash
cd backend
pytest tests/test_caja_cobros.py -v
flake8 routers/caja.py --count --select=E9,F63,F7,F82
```

2. **Frontend Tests:**
```bash
cd frontend
flutter test test/features/caja/panel_detalle_cobro_test.dart
flutter analyze lib/features/caja/
```
