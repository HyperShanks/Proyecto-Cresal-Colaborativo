# SPEC-HU-TAREA-1: Enrolamiento de Usuario, Acceso por PIN Vinculado y Control de Acceso por Rol (RBAC)

## 1. Contexto y Archivos Afectados
- **Objetivo**: Implementar un flujo de autenticación en dos etapas (enrolamiento inicial por email/password y bloqueo diario por PIN vinculado al usuario enrolado), sumado a la creación de guardas de navegación estrictas basadas en roles (RBAC) para el ecosistema Flutter.
- **Archivos a crear**:
  - Frontend: `lib/features/auth/presentation/screens/enrolamiento_screen.dart` (Nueva vista para enrolamiento inicial).
- **Archivos a modificar**:
  - Backend: `routers/auth.py` (Actualizar validación PIN para requerir UUID del usuario enrolado, agregar endpoint de desenrolamiento si es necesario).
  - Backend: `schemas.py` (Actualizar `LoginPINRequest` para incluir `id_usuario`).
  - Frontend: `lib/features/auth/presentation/screens/pin_login_screen.dart` (Adaptar para mostrar usuario enrolado y restringir acceso).
  - Frontend: `lib/features/auth/services/auth_service.dart` (Implementar `enrolarTerminal`, actualizar `loginConPin` y crear `desenrolarTerminal`).
  - Frontend: `lib/routes/app_routes.dart` (Implementar guardas RBAC completas para Bodeguero, Vendedor, Caja, Gerente, Administrador).

## 2. Contratos de Datos y Firmas de API

- **Modelos Backend (Pydantic V2)**:
  ```python
  from pydantic import BaseModel, ConfigDict, UUID4
  from typing import Optional

  class LoginPINRequest(BaseModel):
      """Payload de entrada para el login por PIN de operario vinculado."""
      model_config = ConfigDict(from_attributes=True)
      
      pin_acceso: str
      id_usuario: str  # ID del usuario previamente enrolado en el terminal
  ```

- **Endpoints Backend**:
  - `POST /api/auth/login`: Endpoint existente. Se reutiliza para el enrolamiento inicial con `email` y `password`. El frontend captura el JWT y los datos del usuario para fijar la terminal al operario.
  - `POST /api/auth/login-pin`:
    - **Headers**: None
    - **Payload JSON**: `{"pin_acceso": "1234", "id_usuario": "uuid-del-usuario-enrolado"}`
    - **Respuesta 200**: Devuelve `TokenResponse` con un nuevo JWT de sesión.
    - **Respuestas Error**: `401 Unauthorized` si el PIN no corresponde al `id_usuario` o credenciales son inválidas.
  
- **Modelos Frontend (Dart)**:
  - En `auth_service.dart`:
    ```dart
    // Claves de almacenamiento adicionales requeridas:
    // const String _enrolledUserIdKey = 'enrolled_user_id';
    // const String _enrolledUserEmailKey = 'enrolled_user_email';

    static Future<AuthResult> enrolarTerminal(String email, String password);
    static Future<AuthResult> loginConPin(String pin, String idUsuarioEnrolado);
    static Future<void> desenrolarTerminal();
    ```

## 3. Reglas de Negocio, Casos de Borde y Seguridad
- **Validación Estricta de PIN (Zero Trust)**: La validación de PIN en el endpoint `/login-pin` debe verificar obligatoriamente la condición `(Usuario.id_usuario == request.id_usuario) AND (Usuario.pin_acceso == request.pin_acceso)`. No confiar en la UI; cualquier intento de inyectar un PIN genérico sin el `id_usuario` debe ser denegado.
- **Flujo de Enrolamiento y Desenrolamiento**:
  - Si el terminal no tiene un `enrolled_user_id` persistido en el Secure Storage, la app inicia en `EnrolamientoScreen` (Email/Password).
  - Al completar exitosamente `/login`, los datos del enrolado (ID, Email, Rol) se guardan. La app redirige al panel según su rol.
  - Al vencer la sesión JWT (timeout inactividad), la app regresa a `PinLoginScreen`. NO borra el estado de enrolamiento.
  - El desenrolamiento (opción administrativa) purga completamente el Secure Storage y devuelve al terminal a `EnrolamientoScreen`.
- **Manejo de Transacciones (ACID)**: Para los endpoints de autenticación actuales (solo lectura) usar una única query de lectura con `Session`. Si se requiere registrar auditoría de logins (opcional), usar bloque `try: ... db.commit() except: ... db.rollback()`.
- **Guardas de Navegación por Rol (RBAC)**:
  - *Bodeguero (id_rol=1)*: Limitado a `/recepcion`, `/paletizado`, `/buscador`.
  - *Vendedor (id_rol=2, 7)*: Limitado a `/ventas_main`, `/catalogo`, `/checkout_crm`, `/bandeja_precios`.
  - *Caja (id_rol=3)*: Limitado a `/caja`.
  - Intento de acceso a ruta no autorizada -> `Navigator.pushReplacementNamed` al *home panel* correspondiente sin desloguear.
- **Consideraciones UI**: Manejo de asincronía en callbacks requiere `if (!mounted) return;` antes de cualquier manipulación de `Navigator` o `ScaffoldMessenger`.

## 4. Checklist de Tareas de Implementación (TDD)
- [ ] **Tarea 1 (Backend - Schemas & Modelos)**: Modificar `LoginPINRequest` en `schemas.py` exigiendo `id_usuario: str`. Aplicar `ConfigDict(from_attributes=True)`.
- [ ] **Tarea 2 (Backend - Endpoints & Transacciones ACID)**: Actualizar `/api/auth/login-pin` en `routers/auth.py` para comparar PIN y el `id_usuario` recibido simultáneamente. Manejar respuestas `401 Unauthorized`.
- [ ] **Tarea 3 (Backend - Pruebas Pytest)**: Escribir/actualizar tests unitarios en `test/` validando el acceso a `/login-pin` (camino feliz, error de pin incorrecto, error de usuario no coincide).
- [ ] **Tarea 4 (Frontend - Servicio & Modelos Dart)**: Implementar lógica de enrolamiento y desenrolamiento en `auth_service.dart`. Actualizar invocación de login por PIN enviando el `idUsuarioEnrolado` persistido.
- [ ] **Tarea 5 (Frontend - UI, Controladores & Mounted Guards)**: 
    - Crear `enrolamiento_screen.dart` (UI Email/Password).
    - Adaptar `pin_login_screen.dart` visualizando a quién pertenece la terminal, con botón administrativo de "Desenrolar" (exige confirmación).
    - Verificar `if (!mounted) return;` en todo el bloque `try-catch` del login.
- [ ] **Tarea 6 (Frontend - Guardas y Routing)**: Refactorizar `app_routes.dart` o añadir un observer de rutas para rechazar y redireccionar navegaciones no permitidas basadas en el RBAC.
- [ ] **Tarea 7 (Frontend - Pruebas Widget/Unitarias Flutter)**: Tests comprobando comportamiento de guardas RBAC e interfaz del enrolamiento/desenrolamiento.

## 5. Criterios de Validación Automatizada
- Backend Tests: Ejecutar `pytest tests/ -v` asegurando 100% pase en validaciones de Auth.
- Backend Linter: Ejecutar `flake8 backend/routers/auth.py backend/schemas.py`.
- Frontend Tests: Ejecutar `flutter test test/features/auth/`.
- Frontend Linter: Ejecutar `flutter analyze lib/features/auth lib/routes`.
