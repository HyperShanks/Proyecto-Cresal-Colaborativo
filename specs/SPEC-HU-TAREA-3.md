# SPEC-HU-TAREA-3: Reserva Temporal y Bloqueo Concurrente de Activos Únicos en Carrito

## 1. Contexto y Archivos Afectados
- **Objetivo**: Evitar condiciones de carrera y dobles ventas al implementar una reserva temporal concurrente (con `version_lock`) sobre repuestos físicos en el carrito, habilitando la caducidad por inactividad y devolviendo mensajes de error altamente específicos e intuitivos para el usuario.
- **Archivos a crear**:
  - Backend: `backend/routers/carrito.py` (Endpoints de control de reserva temporal).
  - Frontend: `lib/features/ventas/services/carrito_service.dart` (Lógica de comunicación y heartbeat).
- **Archivos a modificar**:
  - Backend: `backend/models.py` (Extender `Activo_Inventariado` con `reservado_por` [UUID] y `reserva_expira_en` [DateTime] o crear una tabla `Sesion_Carrito`).
  - Backend: `backend/schemas.py` (Crear `ReservaCarritoRequest`).
  - Backend: `backend/main.py` (Registrar el router `/carrito`).
  - Frontend: `lib/features/ventas/presentation/screens/catalogo_screen.dart` (Reactividad visual de bloqueo y captura estricta de errores).
  - Frontend: `lib/features/ventas/presentation/screens/carrito_screen.dart` (Timer de sesión visual e intercepción de caducidad).

## 2. Contratos de Datos y Firmas de API
- **Modelos Backend (Pydantic V2)**:
  ```python
  from pydantic import BaseModel, ConfigDict
  from typing import Optional
  from uuid import UUID

  class ReservaCarritoRequest(BaseModel):
      model_config = ConfigDict(from_attributes=True)
      id_activo: UUID
      version_lock_esperado: int
  ```

- **Endpoints Backend**:
  - `POST /api/v1/carrito/reservar`:
    - **Headers**: JWT Bearer
    - **Payload JSON**: `ReservaCarritoRequest`
    - **Respuestas 409 Conflict**: Payload estandarizado si falla el version_lock.
  - `POST /api/v1/carrito/liberar/{id_activo}`:
    - Reversar `id_estado` a 1 (Disponible) y limpiar campos de reserva.
  - `POST /api/v1/carrito/heartbeat`:
    - Extiende el `reserva_expira_en` de todos los ítems asociados al usuario en X minutos.

- **Modelos Frontend (Dart)**:
  - Manejo de estado reactivo (e.g. `CarritoController`) para rastrear el tiempo restante y bloquear ítems en el catálogo al instante.

## 3. Reglas de Negocio, Casos de Borde y Seguridad (Matriz Estandarizada de Errores)
- **Bloqueo y Concurrencia Optimista (ACID)**: 
  - La query debe ser: `UPDATE Activo_Inventariado SET id_estado = 2, version_lock = version_lock + 1, reservado_por = :user, reserva_expira_en = :exp WHERE id_activo = :id AND version_lock = :vlock`. Si la BD devuelve `rowcount == 0`, significa colisión.
- **Liberación Automática**: Un *background task* en FastAPI o la misma consulta de catálogo (`GET /activos`) debe ignorar/limpiar el estado de reservas expiradas (`reserva_expira_en < now(UTC)`).

**Mensajería Intuitiva Exigida y Control de Excepciones**:
A continuación, se define cómo se le debe explicar cada error al usuario sin fugas técnicas:
1. **Condición de Carrera (Al dar tap en "Agregar")**: 
   - *Error Backend*: `409 Conflict` (Version Lock mismatch). 
   - *Mensaje UI*: `"¡Lo sentimos! Este repuesto acaba de ser reservado por otro vendedor hace un instante."`
2. **Intento de Agregar Pieza Dañada/Inactiva**:
   - *Error Backend*: `400 Bad Request` (Activo no disponible).
   - *Mensaje UI*: `"El artículo seleccionado se encuentra en mantenimiento o fue dado de baja del inventario."`
3. **Expiración del Carrito (Heartbeat fallido o inactividad)**:
   - *Mensaje UI (Automático en pantalla de carrito)*: `"Tu tiempo de reserva ha finalizado por inactividad. Los artículos han sido devueltos al catálogo general."`
4. **Validación Previas en el Wizard (Paso de Cliente)**:
   - *Mensaje UI*: `"Falta identificar al cliente. Por favor, ingresa un RUT válido antes de proceder con la reserva de estos activos."`
5. **Problemas de Conexión al Reservar**:
   - *Mensaje UI*: `"No fue posible asegurar tu reserva debido a un problema de red. Reintentando..."` (No debe crashear ni perder estado).

## 4. Checklist de Tareas de Implementación (TDD)
- [ ] **Tarea 1 (Backend - Schemas & Modelos)**: Modificar `Activo_Inventariado` para soportar campos de reserva temporal o crear tabla espejo. Definir `ReservaCarritoRequest` en `schemas.py`.
- [ ] **Tarea 2 (Backend - Endpoints Concurrentes)**: Implementar lógica de UPDATE atómico con `version_lock`. Levantar excepción controlada si `rowcount == 0`.
- [ ] **Tarea 3 (Backend - Limpieza Automática)**: Implementar lógica para invalidar reservas caducadas.
- [ ] **Tarea 4 (Backend - Pruebas Pytest)**: Simular dos requests simultáneos de reserva para el mismo `id_activo` y asegurar que uno reciba 409 y el otro 200.
- [ ] **Tarea 5 (Frontend - Interfaz de Catálogo)**: Reaccionar al estado bloqueado (`id_estado = 2`), desactivando visualmente el botón de compra en todos los terminales. Usar guardas `if (!mounted) return;`.
- [ ] **Tarea 6 (Frontend - Manejo de Errores Contextual)**: Mapear explícitamente en el interceptor o en el catch local los errores indicados en la sección 3.
- [ ] **Tarea 7 (Frontend - Timer Visual)**: Añadir un indicador de tiempo (countdown) en el carrito que invoque `heartbeat` o limpie el carrito local si llega a 0.
- [ ] **Tarea 8 (Documentación OBLIGATORIA)**: Al finalizar, crear el archivo `DICCIONARIO_ERRORES_TAREA3.md` detallando todos los mensajes de error programados en esta HU, el nombre de la excepción/endpoint que lo dispara, y las acciones recomendadas.

## 5. Criterios de Validación Automatizada
- Backend Tests: Ejecutar `pytest tests/test_carrito_concurrencia.py -v`.
- Backend Linter: Ejecutar `flake8 backend/routers/carrito.py backend/models.py`.
- Frontend Tests: Ejecutar `flutter test test/features/ventas/carrito_concurrencia_test.dart`.
- Frontend Linter: Ejecutar `flutter analyze lib/features/ventas/`.
