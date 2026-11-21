# SPEC-HU-07: Estandarización de Errores, Sanitización de Datos Sensibles y Mensajería Intuitiva al Usuario

## 1. Contexto y Archivos Afectados
- **Objetivo**: Implementar un blindaje total contra fugas de información técnica (SQL traces, metadata) mediante Exception Handlers globales, proveyendo al mismo tiempo notificaciones UI/UX contextuales, homogéneas y amigables para el usuario (Timeouts, validaciones de negocio). Adicionalmente se exige documentar toda la matriz de errores final.
- **Archivos a crear**:
  - Backend: `backend/core/exceptions.py` (Manejadores de error centralizados).
  - Frontend: `lib/core/widgets/custom_error_snackbar.dart` (Widget estandarizado de visualización con botón de acción/reintento).
  - Raíz: `DICCIONARIO_ERRORES.md` (Entregable final requerido tras programar).
- **Archivos a modificar**:
  - Backend: `backend/main.py` (Registro del Middleware o Exception Handlers).
  - Frontend: `lib/core/services/api_service.dart` (Ampliación del interceptor central para capturar fallos de red y status `5xx`).

## 2. Contratos de Datos y Firmas de API
- **Modelos Backend (Pydantic V2)**:
  ```python
  from pydantic import BaseModel, ConfigDict
  from typing import Optional

  class ErrorResponseDTO(BaseModel):
      model_config = ConfigDict(from_attributes=True)
      error_code: str
      message_user: str
      message_dev: Optional[str] = None  # En producción debe ser nulo o ignorado
  ```

- **Firmas Backend (FastAPI)**:
  ```python
  # En backend/core/exceptions.py
  from fastapi import Request
  from fastapi.responses import JSONResponse
  from sqlalchemy.exc import SQLAlchemyError

  async def global_sqlalchemy_exception_handler(request: Request, exc: SQLAlchemyError):
      # Lógica para ocultar el stack trace y devolver un ErrorResponseDTO seguro (código HTTP 500 o 409).
      pass
  ```

- **Modelos Frontend (Dart)**:
  - En `ApiService`:
    ```dart
    // Captura global en api_service.dart
    // throw CustomApiException(messageUser: ..., errorCode: ...)
    ```

## 3. Reglas de Negocio, Casos de Borde y Seguridad (Matriz de Errores Exhaustiva)

**Zero Trust y Cero Fuga Técnica**: Queda estrictamente prohibido que respuestas 4xx/5xx revelen excepciones Python, violaciones de llaves foráneas crudas, nombres de columnas de base de datos o *stack traces* de servidor.

**Mensajería Intuitiva Requerida en la UI**:
Se exige que los mensajes del sistema sigan las siguientes semánticas programadas y mapeadas:
1. **Carrito (Mesón)**:
   - Avance sin datos (Paso Cliente): *"Por favor, ingresa o busca el RUT del cliente antes de continuar."*
   - Avance sin artículos (Paso Ítems): *"Debes agregar al menos un artículo o servicio para proceder."*
   - Colisión en inventario (al reservar): *"Este repuesto acaba de ser reservado por otro vendedor."*
2. **Autenticación y PIN**:
   - PIN fallido en Bodega/Caja: *"PIN incorrecto para este terminal."*
   - Login Email fallido: *"Credenciales inválidas, verifica tu correo o contraseña."*
   - PIN en Terminal No Enrolada: *"Terminal no enrolada, contacte a su administrador."*
3. **Caja Desktop**:
   - Dinero faltante: *"El monto total ingresado no cubre el saldo pendiente de la orden."*
   - Método vacío: *"Selecciona un método de pago antes de procesar."*
4. **Bodega PDA**:
   - Escaneo no encontrado: *"El código escaneado no pertenece a ninguna orden activa."*
   - Pieza ya completada: *"La pieza ya fue escaneada y registrada previamente."*
   - Mismatch de Orden: *"Cuidado, la pieza escaneada pertenece a otra orden."*
5. **Fallos de Red (Timeouts / SocketException)**:
   - Interrupción de Internet o Backend Caído: *"Problemas de conexión con el servidor. Reintentando..."*. 
   - La pantalla no se debe congelar (CircularProgressIndicator no infinito). El Snackbar debe renderizar un botón "Reintentar".

## 4. Checklist de Tareas de Implementación (TDD)
- [ ] **Tarea 1 (Backend - Excepciones)**: Implementar `backend/core/exceptions.py` y crear los handlers globales (e.g. `SQLAlchemyError`, `RequestValidationError`). Retornar siempre `ErrorResponseDTO`.
- [ ] **Tarea 2 (Backend - Integración)**: Inyectar `app.add_exception_handler()` en `backend/main.py`.
- [ ] **Tarea 3 (Backend - Pruebas Pytest)**: Simular errores forzados (e.g. Constraint Violation, Internal Error) y comprobar que el payload devuelto NUNCA expone el error SQL.
- [ ] **Tarea 4 (Frontend - Interceptor Global)**: Modificar `ApiService` en Flutter envolviendo `http.get/post` en un bloque que procese fallas (`TimeoutException`, código 500) y extraiga el campo `message_user`.
- [ ] **Tarea 5 (Frontend - UI y Alertas)**: Crear el componente `CustomErrorSnackbar` con formato visual consistente. Integrar el botón "Volver" o "Reintentar".
- [ ] **Tarea 6 (Frontend - Pruebas Widget)**: Comprobar el comportamiento de Timeout forzado mediante Mocks en Flutter, asegurando que la UI muestra la alerta pero no se bloquea.
- [ ] **Tarea 7 (Documentación - DICCIONARIO DE ERRORES)**: **OBLIGATORIO.** Al terminar toda la programación de los manejadores, crear el archivo `DICCIONARIO_ERRORES.md` en la raíz documentando explícitamente todos los errores desarrollados (Dónde salta, Cuándo se activa, Cuál es el Mensaje).

## 5. Criterios de Validación Automatizada
- Backend Tests: Ejecutar `pytest tests/test_global_exceptions.py -v`.
- Backend Linter: Ejecutar `flake8 backend/core/exceptions.py backend/main.py`.
- Frontend Tests: Ejecutar `flutter test test/core/api_service_test.dart test/core/widgets/error_snackbar_test.dart`.
- Frontend Linter: Ejecutar `flutter analyze`.
