# SPEC-HU-06: Optimización UI en Bodega PDA (Eliminación de Notificaciones Push Simuladas y Contador de Alertas)

## 1. Contexto y Archivos Afectados
- **Objetivo**: Limpiar la UI de la aplicación Bodega PDA removiendo notificaciones y popups intrusivos, consolidando el control de la carga operativa en un botón en la barra superior con un `Badge` numérico reactivo y un panel desplegable de tareas.
- **Archivos a crear**:
  - Frontend: `lib/features/alertas/presentation/widgets/panel_tareas_desplegable.dart` (Modal bottom sheet o side-panel para visualizar las tareas).
- **Archivos a modificar**:
  - Backend: `backend/routers/bodega.py` (Ajustar endpoints de alertas para incluir conteos agregados de preparación, entrega y reingreso).
  - Frontend: `lib/features/alertas/services/bodega_polling_service.dart` (Eliminar callbacks de notificaciones emergentes, conservar actualización de estado reactivo).
  - Frontend: `lib/features/home/presentation/screens/home_screen.dart` (Remover `ScaffoldMessenger` de notificaciones, añadir botón de Alertas con `Badge` en el `AppBar` de la vista principal y de escaneo).

## 2. Contratos de Datos y Firmas de API
- **Modelos Backend (Pydantic V2)**:
  ```python
  from pydantic import BaseModel, ConfigDict
  from typing import List
  
  class ResumenAlertasDTO(BaseModel):
      model_config = ConfigDict(from_attributes=True)
      total_tareas: int
      desglose_preparacion: int
      desglose_entregas: int
      desglose_reingresos: int
  ```

- **Endpoints Backend**:
  - `GET /api/v1/bodega/resumen-alertas`:
    - **Headers**: JWT Bearer (`id_rol == 1` Bodeguero).
    - **Respuesta 200**: Retorna `ResumenAlertasDTO` con el conteo consolidado de tareas.
  - *(Opcional/Actualización)* `GET /api/v1/bodega/tareas-pendientes`:
    - Se asegura que este endpoint devuelva la lista priorizada (preparaciones urgentes, luego reingresos, luego impresiones) para nutrir el panel desplegable.

- **Modelos Frontend (Dart)**:
  - Consumir el `ResumenAlertasDTO` y actualizar `totalPendientesNotifier` en `BodegaPollingService`.

## 3. Reglas de Negocio, Casos de Borde y Seguridad
- **Cero Intrusión UI (Zero Trust Visual)**: Las operaciones de lectura de cámara o manejo de pallets no deben sufrir pérdida de foco por culpa de notificaciones tipo Push o Toasts persistentes. El bodeguero consultará las tareas voluntariamente al presionar el Badge.
- **Actualización Reactiva del Badge**: El contador del `Badge` debe decrementar en tiempo real. Esto requiere que tras cada mutación de éxito (ej. al llamar a `/completar-preentrega`, al escanear un QR de barrera, o al confirmar un reingreso), el frontend force un ciclo en `BodegaPollingService` o decremente manualmente el `totalPendientesNotifier`.
- **Ocultamiento de Badge**: Si el `totalPendientesNotifier` es `0`, el widget `Badge` no debe renderizar el número (Flutter `Badge` soporta `isLabelVisible: count > 0`).
- **Seguridad**: Todas las consultas al contador y lista deben filtrar estrictamente las órdenes correspondientes a la `sucursal_id` del usuario autenticado y validar el JWT.
- **Transaccionalidad (ACID)**: No hay mutaciones complejas aquí (solo consultas de lectura `GET`), por lo que no es necesario el bloque `try/commit` para los endpoints de reporte, pero las consultas deben estar aisladas.
- **Lifecycle Guards**: Al mostrar el modal/panel desplegable (e.g. `showModalBottomSheet`), asegurarse de validar `if (!mounted) return;` luego de consultas asíncronas para evitar fugas de memoria.

## 4. Checklist de Tareas de Implementación (TDD)
- [ ] **Tarea 1 (Backend - Schemas & Modelos)**: Agregar `ResumenAlertasDTO` en `backend/schemas.py`.
- [ ] **Tarea 2 (Backend - Endpoints)**: Desarrollar o modificar los endpoints en `backend/routers/bodega.py` para devolver el total agregado (`/resumen-alertas`) y asegurar el correcto ordenamiento en `/tareas-pendientes`.
- [ ] **Tarea 3 (Backend - Pruebas Pytest)**: Escribir tests asegurando que el conteo de alertas suma correctamente preparaciones, ventas pagadas y reingresos.
- [ ] **Tarea 4 (Frontend - Servicio & Modelos Dart)**: Limpiar `BodegaPollingService.dart` removiendo `onNotificacion` y `_emitirNotificacion`. Ajustar el polling para que consulte `/resumen-alertas`.
- [ ] **Tarea 5 (Frontend - UI, Controladores & Mounted Guards)**: 
    - Modificar `home_screen.dart`: Eliminar lógica de `ScaffoldMessenger.showSnackBar` para notificaciones simuladas.
    - Añadir un `IconButton` envuelto en un `Badge` vinculado a `BodegaPollingService.instance.totalPendientesNotifier` en el `AppBar.actions`.
    - Crear `panel_tareas_desplegable.dart` que consuma el listado y se abra al tocar el Badge.
- [ ] **Tarea 6 (Frontend - Pruebas Widget/Unitarias Flutter)**: Escribir un test de Widget verificando que el Badge actualiza su número y desaparece cuando el ValueNotifier emite un cero.

## 5. Criterios de Validación Automatizada
- Backend Tests: Ejecutar `pytest tests/test_bodega_alertas.py -v`.
- Backend Linter: Ejecutar `flake8 backend/routers/bodega.py backend/schemas.py`.
- Frontend Tests: Ejecutar `flutter test test/features/alertas/bodega_polling_test.dart`.
- Frontend Linter: Ejecutar `flutter analyze lib/features/alertas/ lib/features/home/`.
