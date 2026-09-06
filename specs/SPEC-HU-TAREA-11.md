# SPEC-HU-TAREA-11: Edición Directa de Activos Inventariados desde la Vista de Inventario en Bodega PDA

## 1. Contexto y Archivos Afectados
- **Objetivo**: Desarrollar la capacidad de editar la localización (pasillo, pallet) y detalles técnicos (notas, estado físico) de los activos en Bodega PDA, implementando control de concurrencia (`version_lock`) y blindaje de campos inmutables para garantizar la trazabilidad.
- **Archivos a crear**:
  - Frontend: `lib/features/inventario/presentation/widgets/editar_activo_modal.dart` (Formulario reutilizable para edición técnica y logística).
- **Archivos a modificar**:
  - Backend: `backend/routers/inventario.py` (Creación del endpoint `PATCH /api/v1/inventario/{id_activo}`).
  - Backend: `backend/schemas.py` (Añadir `EditarActivoRequest`).
  - Frontend: `lib/features/inventario/services/inventario_service.dart` (Nuevo método `editarActivo`).
  - Frontend: `lib/features/inventario/presentation/screens/detalle_activo_screen.dart` o `resultado_card.dart` (Inyección de la acción de edición/lápiz en la interfaz gráfica).

## 2. Contratos de Datos y Firmas de API
- **Modelos Backend (Pydantic V2)**:
  ```python
  from pydantic import BaseModel, ConfigDict
  from typing import Optional
  
  class EditarActivoRequest(BaseModel):
      model_config = ConfigDict(from_attributes=True)
      ubicacion_pasillo: Optional[str] = None
      ubicacion_galpon: Optional[str] = None
      ubicacion_pallet: Optional[str] = None
      observacion_estado: Optional[str] = None
      numero_motor: Optional[str] = None
      cilindrada: Optional[str] = None
      version_lock_esperado: int
  ```
- **Endpoints Backend**:
  - `PATCH /api/v1/inventario/{id_activo}`:
    - **Headers**: JWT Bearer (Rol Bodeguero / Administrador).
    - **Payload JSON**: `EditarActivoRequest`
    - **Respuestas**: 
      - `200 OK`: Devuelve el modelo actualizado con su nuevo `version_lock`.
      - `409 Conflict`: Si `version_lock_esperado` no coincide.

- **Modelos Frontend (Dart)**:
  - Manejo del método asíncrono `Future<bool> editarActivo(String idActivo, Map<String, dynamic> datos)` asegurando intercepción de errores.

## 3. Reglas de Negocio, Casos de Borde y Seguridad (Matriz Estandarizada de Errores)
- **Bloqueo Concurrente y ACID**: Todo cambio en BD debe usar `UPDATE Activo_Inventariado SET ..., version_lock = version_lock + 1 WHERE id_activo = X AND version_lock = Y`. La operación global debe usar `try ... db.commit()`.
- **Campos Inmutables Restringidos**: No se pueden sobreescribir campos como `sku_qr_fisico`, `id_estado` (si impacta reservas transaccionales) ni los identificadores de sucursal mediante este endpoint.

**Mensajería Intuitiva Exigida y Control de Excepciones**:
A continuación, se define cómo se le debe explicar cada error al usuario en esta interfaz específica, omitiendo por completo los *stack traces* o respuestas técnicas:

1. **Condición de Carrera al Guardar Cambios (Error Backend: `409 Conflict`)**:
   - *Causa*: Otro operador actualizó el mismo activo mientras el usuario tenía el formulario modal abierto.
   - *Mensaje UI*: `"La información de este repuesto fue modificada por otro usuario recientemente. Los datos se actualizarán ahora para que revises los cambios antes de volver a editar."`
2. **Falla de Validación de Red / Timeout (Error Frontend: `TimeoutException / SocketException`)**:
   - *Causa*: El operario de bodega perdió señal de Wi-Fi en el galpón justo al presionar guardar.
   - *Mensaje UI*: `"Conexión inestable. No pudimos guardar tus cambios. Por favor, reintenta en unos segundos."`
3. **Cancelación Manual con Cambios Pendientes (Dirty Form en UI)**:
   - *Causa*: El usuario escribió algo en los textfields y presionó el botón "Atrás" de Android o el botón Cancelar.
   - *Mensaje UI (Modal de Confirmación)*: `"Tienes cambios sin guardar. ¿Estás seguro de que quieres salir y descartar las modificaciones?"`
4. **Intento de Edición de Pieza Vendida/Despachada (Error Backend: Validación HTTP `403` o `400`)**:
   - *Causa*: La pieza fue procesada por caja y su estado ya no permite alteraciones físicas de pallet.
   - *Mensaje UI*: `"Este artículo ya fue despachado o cobrado. Ya no es posible modificar su ubicación técnica."`

## 4. Checklist de Tareas de Implementación (TDD)
- [ ] **Tarea 1 (Backend - Schemas)**: Definir `EditarActivoRequest` en `schemas.py` asegurando la omisión de `sku_qr_fisico` y campos transaccionales en Pydantic.
- [ ] **Tarea 2 (Backend - Endpoints ACID)**: Implementar `PATCH /api/v1/inventario/{id_activo}`. Incluir el bloque transaccional atómico y la cláusula SQL de incremento de `version_lock`.
- [ ] **Tarea 3 (Backend - Pruebas Pytest)**: Probar exitosamente el endpoint, probar una colisión intencional de `version_lock` (esperando 409) y probar un fallo por rol inválido.
- [ ] **Tarea 4 (Frontend - Interfaz Lápiz)**: Inyectar botón tipo lápiz en la cabecera de la vista de detalle de la pieza, visible únicamente si el rol lo permite.
- [ ] **Tarea 5 (Frontend - Formulario y Guardas)**: Implementar `editar_activo_modal.dart`. Configurar `onWillPop` para la intercepción de campos sucios (Dirty Form) y obligar el uso de `if (!mounted) return;`.
- [ ] **Tarea 6 (Frontend - UX y Mensajes)**: Mapear e implementar los mensajes exactos indicados en la Sección 3 mediante Snackbars amigables. Refrescar la vista subyacente de forma reactiva al guardar con éxito.
- [ ] **Tarea 7 (Frontend - Pruebas Widget)**: Testear la apertura del diálogo de "Cambios sin guardar" (dirty check).
- [ ] **Tarea 8 (Documentación OBLIGATORIA)**: Al finalizar todo el código, crear el archivo `DICCIONARIO_ERRORES_TAREA11.md` en la raíz del proyecto. Debe detallar todos los mensajes de error mostrados al usuario, el componente/backend que los dispara y el contexto en que ocurren.

## 5. Criterios de Validación Automatizada
- Backend Tests: Ejecutar `pytest tests/test_inventario_edicion.py -v`.
- Backend Linter: Ejecutar `flake8 backend/routers/inventario.py backend/schemas.py`.
- Frontend Tests: Ejecutar `flutter test test/features/inventario/edicion_activo_test.dart`.
- Frontend Linter: Ejecutar `flutter analyze lib/features/inventario/`.
