# SPEC-HU-TAREA-4: Flujo de Logística Inversa y Tarea de Reingreso/Paletizado en Bodega tras Anulación de Órdenes

## 1. Contexto y Archivos Afectados
- **Objetivo**: Habilitar la anulación de órdenes en el Mesón de Ventas, propagando la reversa de pagos y generando automáticamente tareas de reingreso (Logística Inversa) para la Bodega PDA, finalizando con el escaneo y reubicación del inventario.
- **Archivos a crear**:
  - Frontend: `lib/features/ventas/presentation/widgets/modal_anular_orden.dart` (UI para confirmar anulación en Mesón).
  - Frontend: `lib/features/bodega/presentation/screens/reingreso_tareas_screen.dart` (Vista PDA Bodega para lista de reingresos).
- **Archivos a modificar**:
  - Backend: `backend/schemas.py` (Crear DTOs para Tareas de Reingreso y Confirmación).
  - Backend: `backend/routers/ordenes.py` (Añadir endpoint de anulación con transacción ACID).
  - Backend: `backend/routers/bodega.py` (Añadir endpoints de listado de reingresos y confirmación por escaneo).
  - Frontend: `lib/features/ventas/services/ventas_service.dart` (Método `anularOrden`).
  - Frontend: `lib/features/alertas/services/bodega_service.dart` (Métodos para obtener tareas y confirmar reingreso).
  - Frontend: `lib/features/ventas/presentation/screens/ventas_main_screen.dart` o detalle de orden (Botón "Deshacer orden").

## 2. Contratos de Datos y Firmas de API
- **Modelos Backend (Pydantic V2)**:
  ```python
  from pydantic import BaseModel, ConfigDict
  from typing import List, Optional
  from uuid import UUID

  class AnularOrdenRequest(BaseModel):
      model_config = ConfigDict(from_attributes=True)
      motivo_anulacion: Optional[str] = None

  class ConfirmarReingresoRequest(BaseModel):
      model_config = ConfigDict(from_attributes=True)
      sku_qr_fisico: str
      id_orden_anulada: UUID

  class TareaReingresoDTO(BaseModel):
      model_config = ConfigDict(from_attributes=True)
      id_orden: UUID
      id_activo: UUID
      sku_qr_fisico: str
      ubicacion_pallet: Optional[str] = None
      ubicacion_pasillo: Optional[str] = None
      descripcion_pieza: str
  ```

- **Endpoints Backend**:
  - `POST /api/ordenes/{id_orden}/anular`:
    - **Payload**: `AnularOrdenRequest`
    - **Headers**: Autorización JWT Bearer (Vendedor/Jefe)
    - **Respuesta 200**: `{"msg": "Orden anulada, pagos reversados y tareas de reingreso generadas"}`
  - `GET /api/bodega/reingresos-pendientes`:
    - **Headers**: Autorización JWT Bearer (Bodeguero)
    - **Respuesta 200**: `List[TareaReingresoDTO]`
  - `POST /api/bodega/confirmar-reingreso`:
    - **Payload**: `ConfirmarReingresoRequest`
    - **Headers**: Autorización JWT Bearer (Bodeguero)
    - **Respuesta 200**: `{"msg": "Activo paletizado/disponible exitosamente"}`

- **Modelos Frontend (Dart)**:
  - `class TareaReingresoDTO { final String idOrden; final String skuQrFisico; final String? ubicacionPallet; final String? ubicacionPasillo; final String descripcionPieza; }`
  - Métodos en servicios correspondientes con manejo de `AuthResult` o retorno de `Future<bool>`.

## 3. Reglas de Negocio, Casos de Borde y Seguridad
- **Anulación de Venta (ACID)**: En una misma transacción de BD (bloque `try ... db.commit() ... except Exception as e: db.rollback(); raise e`), se debe:
  1. Cambiar `Orden_Venta.estado_orden` a `'Anulada'`.
  2. Buscar `Transaccion_Pago` asociada y cambiar `estado_pago` a `'Anulado'`.
- **Tareas de Reingreso (Flujo Implícito)**: No se requiere crear tabla nueva para tareas. Una "tarea de reingreso" es cualquier línea en `Detalle_Orden` que tenga un `id_activo`, donde su `Orden_Venta` esté en estado `'Anulada'` y el `Activo_Inventariado.id_estado` NO sea 7 (Paletizado) ni 1 (Disponible).
- **Confirmación de Reingreso (Control de Concurrencia)**: Al confirmar la ubicación vía PDA, el endpoint debe validar el `sku_qr_fisico` escaneado y mutar el inventario `Activo_Inventariado.id_estado = 7` (o 1). Se exige que esta actualización incremente atómicamente `version_lock = Activo_Inventariado.version_lock + 1` en la consulta ORM para prevenir condiciones de carrera.
- **Zona Horaria (UTC)**: Fechas como `fecha_actualizacion` deben setearse en UTC en el backend (`datetime.now(timezone.utc)`).
- **Zero Trust (RBAC)**: Endpoint de anulación debe validar rol de ventas/jefatura. Endpoints de reingreso deben validar rol de Bodeguero (`id_rol == 1`).
- **Guardián de Ciclo de Vida Frontend**: Obligatorio utilizar `if (!mounted) return;` en la UI de Flutter tras esperar llamadas API (ej. tras `await apiService.anularOrden()`).

## 4. Checklist de Tareas de Implementación (TDD)
- [x] **Tarea 1 (Backend - Schemas & Modelos)**: Crear DTOs usando Pydantic V2 (`AnularOrdenRequest`, `ConfirmarReingresoRequest`, `TareaReingresoDTO`, `ConfirmarReingresoResponse`) en `schemas.py`.
- [x] **Tarea 2 (Backend - Anulación ACID)**: Implementar `/api/ordenes/{id_orden}/anular` en `routers/ordenes.py` con transaccionalidad total (Orden + Pagos).
- [x] **Tarea 3 (Backend - Endpoints Bodega PDA)**: En `routers/bodega.py`, crear `/reingresos-pendientes` (Query con JOIN) y `/confirmar-reingreso` con incremento de `version_lock`.
- [x] **Tarea 4 (Backend - Pruebas Pytest)**: Tests para anular orden (Happy path + Rollback on exception) y confirmación de reingreso (concurrencia).
- [x] **Tarea 5 (Frontend - Servicio & Modelos Dart)**: DTOs en Dart, funciones asíncronas de API en servicios de Ventas y Bodega.
- [x] **Tarea 6 (Frontend - UI Mesón)**: Diálogo modal de anulación, integración de botón "Deshacer orden" y uso de `if (!mounted) return;`.
- [x] **Tarea 7 (Frontend - UI Bodega PDA)**: Vista y controlador de lista de reingresos. Integración de cámara/lector PDA para `sku_qr_fisico`.
- [x] **Tarea 8 (Frontend - Pruebas Widget/Unitarias)**: Tests en Dart comprobando rendering de tareas y disparo correcto de métodos.

## 5. Criterios de Validación Automatizada
- Backend Tests: Ejecutar `pytest tests/test_ordenes_anulacion.py tests/test_bodega_reingresos.py -v`.
- Backend Linter: Ejecutar `flake8 backend/routers/ordenes.py backend/routers/bodega.py backend/schemas.py`.
- Frontend Tests: Ejecutar `flutter test test/features/ventas/ test/features/bodega/`.
- Frontend Linter: Ejecutar `flutter analyze`.
