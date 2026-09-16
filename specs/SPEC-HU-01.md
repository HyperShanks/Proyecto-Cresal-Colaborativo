# SPEC-HU-01: Autenticación, Control de Acceso y Enrutamiento de Caja (CRES-213)

## 1. Contexto y Archivos Afectados
- **Objetivo**: Implementar el control de acceso y enrutamiento exclusivo para el rol Caja (id_rol == 3 y Administrador id_rol == 5), restringiendo el acceso a vistas operativas no autorizadas y estableciendo el layout base de escritorio (CajaMainScreen) con persistencia segura de sesión.
- **Archivos Backend a Crear / Modificar**:
  - `backend/core/security.py` (Modificar: Implementar helper de dependencias require_caja_role).
  - `backend/routers/auth.py` (Modificar: Validar serialización completa de claims de sesión).
  - `backend/schemas.py` (Modificar: DTOs Pydantic V2 de autenticación con ConfigDict).
  - `backend/tests/test_caja_auth.py` (Crear: Suite de pruebas Pytest para validación RBAC y login de caja).
- **Archivos Frontend Flutter a Crear / Modificar**:
  - `frontend/lib/features/auth/controllers/login_controller.dart` (Modificar: Lógica de redirección por rol hacia /caja).
  - `frontend/lib/features/auth/services/auth_service.dart` (Modificar: Persistencia y recuperación de contexto de turno).
  - `frontend/lib/features/caja/presentation/screens/caja_main_screen.dart` (Crear: Contenedor principal desktop con AppBar corporativo y navegación por vistas).
  - `frontend/lib/features/caja/presentation/widgets/caja_drawer.dart` (Crear: Menú lateral / sidebar restringido con datos de cajera y accesos autorizados).
  - `frontend/lib/routes/app_routes.dart` (Modificar: Registrar ruta /caja y guardas de navegación por rol).
  - `frontend/test/features/caja/caja_auth_test.dart` (Crear: Pruebas unitarias y de widgets para login y enrutamiento protegido).

---

## 2. Contratos de Datos y Firmas de API

### 2.1 Backend (FastAPI / SQLAlchemy / Pydantic V2)

**Modelos SQLAlchemy Involucrados (`backend/models.py`):**
```python
# Modelos existentes: Usuario y Rol
class Rol(Base):
    __tablename__ = "rol"
    id_rol = Column(Integer, primary_key=True, index=True)
    nombre_rol = Column(String(50), nullable=False, unique=True)
    estado = Column(String(20), default="Activo")

class Usuario(Base):
    __tablename__ = "usuario"
    id_usuario = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    id_rol = Column(Integer, ForeignKey("rol.id_rol"), nullable=False)
    id_sucursal = Column(Integer, ForeignKey("sucursal.id_sucursal"), nullable=False)
    rut_usuario = Column(String(12), unique=True, nullable=False)
    nombres = Column(String(100), nullable=False)
    apellidos = Column(String(100), nullable=False)
    email = Column(String(150), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    pin_acceso = Column(String(4), unique=True, nullable=False)
    estado = Column(String(20), default="Activo")

Esquemas Pydantic V2 (backend/schemas.py):
from pydantic import BaseModel, ConfigDict
import uuid

class LoginPinRequest(BaseModel):
    pin_acceso: str

class AuthUserData(BaseModel):
    id_usuario: uuid.UUID
    rut_usuario: str
    nombres: str
    apellidos: str
    email: str
    id_rol: int
    nombre_rol: str
    id_sucursal: int
    
    model_config = ConfigDict(from_attributes=True)

class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    usuario: AuthUserData

    model_config = ConfigDict(from_attributes=True)


Helper de Dependencias RBAC (backend/core/security.py):
from fastapi import Depends, HTTPException, status
from models import Usuario
from core.security import get_current_user

def require_caja_role(current_user: Usuario = Depends(get_current_user)) -> Usuario:
    if current_user.id_rol not in [3, 5]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acceso restringido: Se requieren permisos de Operario de Caja o Administrador."
        )
    return current_user

2.2 Endpoints de API
POST /api/auth/login-pin
    Acceso: Público (Rate limit / Sanity check).

    Payload Entrada:

    {
  "pin_acceso": "1234"
}
    Respuesta Exitosa (200 OK):
    {
  "access_token": "eyJhbGciOiJIUzI1NiIsIn...",
  "token_type": "bearer",
  "usuario": {
    "id_usuario": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
    "rut_usuario": "12.345.678-9",
    "nombres": "María Jesús",
    "apellidos": "López Vega",
    "email": "maria.lopez@cresal.cl",
    "id_rol": 3,
    "nombre_rol": "Caja",
    "id_sucursal": 1
  }
}

Respuestas de Error:

401 Unauthorized: {"detail": "PIN de acceso inválido o usuario inactivo."}

422 Unprocessable Entity: Formato de PIN incorrecto.

GET /api/v1/caja/verificar-acceso

Acceso: Privado (Depends(require_caja_role)).

Header: Authorization: Bearer <token>

Respuesta (200 OK):

{
  "autorizado": true,
  "rol": "Caja",
  "id_sucursal": 1
}

Respuesta (403 Forbidden): {"detail": "Acceso restringido: Se requieren permisos de Operario de Caja o Administrador."}

2.3 Modelos Frontend (Dart)
Modelo de Sesión de Usuario (frontend/lib/features/auth/models/auth_user_model.dart):


class AuthUserModel {
  final String idUsuario;
  final String rutUsuario;
  final String nombres;
  final String apellidos;
  final String email;
  final int idRol;
  final String nombreRol;
  final int idSucursal;

  AuthUserModel({
    required this.idUsuario,
    required this.rutUsuario,
    required this.nombres,
    required this.apellidos,
    required this.email,
    required this.idRol,
    required this.nombreRol,
    required this.idSucursal,
  });

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    return AuthUserModel(
      idUsuario: json['id_usuario'] as String,
      rutUsuario: json['rut_usuario'] as String,
      nombres: json['nombres'] as String,
      apellidos: json['apellidos'] as String,
      email: json['email'] as String,
      idRol: json['id_rol'] as int,
      nombreRol: json['nombre_rol'] as String,
      idSucursal: json['id_sucursal'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'id_usuario': idUsuario,
    'rut_usuario': rutUsuario,
    'nombres': nombres,
    'apellidos': apellidos,
    'email': email,
    'id_rol': idRol,
    'nombre_rol': nombreRol,
    'id_sucursal': idSucursal,
  };
}

3. Reglas de Negocio, Casos de Borde y Seguridad
Zero Trust & Control RBAC:

Todo endpoint del módulo de caja debe validar token JWT y pertenencia a id_rol in [3, 5] a nivel de backend.

La UI no debe basar la seguridad solo en ocultar botones: el Router de Flutter debe interceptar cualquier intento de navegación manual a rutas ajenas a Caja (/catalogo, /carrito, /recepcion-vehiculo, /paletizado).

Persistencia de Contexto de Turno:

Al autenticarse, se debe guardar en FlutterSecureStorage el token JWT y el objeto JSON del usuario (id_usuario, id_sucursal, id_rol, nombres).

La aplicación debe restaurar este contexto en memoria al iniciar si la sesión sigue vigente.

Manejo de Ciclo de Vida y Asincronía:

En login_controller.dart y en los diálogos de CajaDrawer, cualquier navegación o feedback visual posterior a un await debe estar protegido obligatoriamente por el guardián if (!mounted) return;.

Ergonomía Desktop:

El input de PIN debe aceptar foco automático (autofocus: true) y admitir números desde el teclado físico (Numpad).

El layout de CajaMainScreen debe adaptarse a resoluciones de escritorio mayores o iguales a 1366x768.

Drawer / Menú Lateral Restringido:

Debe contener exclusivamente:

Bandeja de Cobros (Órdenes Pendientes).

Historial de Órdenes y Pagos.

Tickets de Soporte.

Cerrar Sesión (con diálogo de confirmación y destrucción de credenciales).

4. Checklist de Tareas de Implementación (TDD)
[x] Tarea 1 (Backend - RBAC & DTOs Pydantic V2):

Crear la función dependency require_caja_role en backend/core/security.py.

Verificar que AuthUserData y LoginResponse en backend/schemas.py implementen ConfigDict(from_attributes=True) y serialicen id_rol e id_sucursal.

[x] Tarea 2 (Backend - Endpoints de Auth & Verificación):

Validar que POST /api/auth/login-pin y POST /api/auth/login retornen los claims requeridos.

Crear endpoint de prueba GET /api/v1/caja/verificar-acceso protegido con require_caja_role.

[x] Tarea 3 (Backend - Pruebas Pytest test_caja_auth.py):

Escribir tests que validen: login exitoso con PIN para cajera (id_rol = 3), login como Admin (id_rol = 5), rechazo de acceso (403) a endpoints de caja para rol Bodeguero (id_rol = 1) o Vendedor (id_rol = 2).

[x] Tarea 4 (Frontend - Controlador de Login y Enrutamiento):

Actualizar login_controller.dart para que tras autenticación exitosa con idRol == 3, ejecute Navigator.pushReplacementNamed(context, '/caja') con guardián if (!mounted) return;.

Configurar la persistencia segura del modelo AuthUserModel en auth_service.dart.

[x] Tarea 5 (Frontend - Layout Desktop CajaMainScreen y CajaDrawer):

Implementar CajaMainScreen con Scaffold, AppBar con nombre de la cajera, sucursal activa y tabs de navegación (Bandeja / Historial).

Construir CajaDrawer restringido con la información del turno y acción de Logout (pushNamedAndRemoveUntil a /login-pin).

Configurar las guardas de rutas en app_routes.dart para bloquear vistas de ventas/bodega al rol Caja.

[x] Tarea 6 (Frontend - Pruebas de Widgets y Navegación):

Crear frontend/test/features/caja/caja_auth_test.dart verificando:

Renderizado correcto de CajaMainScreen al autenticar rol 3.

Existencia exclusiva de las opciones autorizadas en CajaDrawer.

Bloqueo de navegación hacia rutas restringidas.


5. Criterios de Validación Automatizada
El agente autónomo solo considerará completada la especificación cuando los siguientes comandos se ejecuten sin errores:

Backend Tests:

Bash
cd backend && pytest tests/test_caja_auth.py -v
Backend Linting (Zero Fatal Errors):

Bash
flake8 backend/core/security.py backend/routers/auth.py --count --select=E9,F63,F7,F82
Frontend Tests:

Bash
cd frontend && flutter test test/features/caja/caja_auth_test.dart
Frontend Analyzer:

Bash
flutter analyze lib/features/caja/ lib/features/auth/