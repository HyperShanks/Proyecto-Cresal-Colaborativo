# SPEC-HU-TAREA-12: Validación Matemática de RUT Chileno (Módulo 11) en Captura y Registro de Clientes

## 1. Contexto y Archivos Afectados
- **Objetivo**: Proteger la integridad de los datos contables, de facturación y logística impidiendo el registro de identificadores ficticios en todo el sistema. Se consolidará una validación matemática estricta (Módulo 11) en el Backend y una sanitización visual/reactiva en los formularios del Frontend.
- **Archivos a crear**:
  - Backend: `backend/core/utils/validators.py` (Helper transversal para el cálculo de Módulo 11).
  - Frontend: `lib/core/utils/rut_validator.dart` (Lógica de validación matemática en Dart).
  - Frontend: `lib/core/utils/rut_formatter.dart` (TextInputFormatter para formatear en tiempo real y transformar `k -> K`).
- **Archivos a modificar**:
  - Backend: `backend/schemas.py` (Aplicación de `@field_validator` sobre campos de RUT).
  - Frontend: Formularios de clientes y despachos (ej: `lib/features/ventas/presentation/widgets/wizard_steps/paso_2_cliente.dart` y modal de cliente rápido) para inyectar validadores visuales reactivos.

## 2. Contratos de Datos y Firmas de API
- **Modelos Backend (Pydantic V2)**:
  ```python
  from pydantic import BaseModel, ConfigDict, field_validator
  from core.utils.validators import validar_rut_modulo11

  class BaseRutSchema(BaseModel):
      model_config = ConfigDict(from_attributes=True)

      @field_validator('rut_cliente', 'receptor_rut', 'rut_usuario', mode='before', check_fields=False)
      def normalizar_y_validar_rut(cls, v: str) -> str:
          if not v:
              return v
          es_valido, rut_limpio = validar_rut_modulo11(v)
          if not es_valido:
              raise ValueError("El RUT ingresado no es matemáticamente válido (falla en dígito verificador).")
          return rut_limpio
  ```

- **Endpoints Backend**:
  - Rutas como `POST /api/v1/clientes`, `POST /api/v1/ordenes-venta/checkout-wizard`, etc.
  - **Excepciones**: Si el RUT no pasa la validación Pydantic, el manejador global de FastAPI (ya implementado) devolverá `422 Unprocessable Entity` con payload estandarizado.

- **Modelos Frontend (Dart)**:
  - `RutValidator.isValid(String rut)`: Método estático booleano.
  - `RutFormatter()`: Extiende de `TextInputFormatter` inyectado en `TextFormField`.

## 3. Reglas de Negocio, Casos de Borde y Seguridad (Matriz Estandarizada de Errores)
- **Tolerancia y Limpieza de Entrada**: El sistema debe aceptar ingresos como `123456789`, `12345678-9` y `12.345.678-9`. Antes de aplicar la fórmula, debe eliminar puntos y guiones, y transformar una eventual letra 'k' minúscula en 'K' mayúscula de manera transparente al usuario.
- **Cálculo Módulo 11 Riguroso**: Todo verificador debe ser matemáticamente probado con la multiplicación regresiva de (2 a 7) sobre el cuerpo numérico. No se admiten validaciones por longitud o expresiones regulares simples como única defensa.

**Mensajería Intuitiva Exigida y Control de Excepciones**:
De acuerdo a las directivas de blindaje visual y UX:
1. **Frontend: RUT Matemáticamente Inválido (Visual en Formulario)**:
   - *Causa*: El usuario finaliza de tipear un RUT que no supera el Módulo 11.
   - *Mensaje UI (Texto de error debajo del TextFormField)*: `"RUT inválido. Verifique el número ingresado."`
   - *Restricción UX*: El botón "Continuar" o "Guardar" debe estar en estado `disabled` (bloqueado) para impedir una petición inútil de red.
2. **Frontend: Sanitización Dinámica (Feedback Transparente)**:
   - *Causa*: El usuario teclea "k" minúscula.
   - *Comportamiento*: El `RutFormatter` en `inputFormatters` fuerza inmediatamente la conversión visual a "K".
3. **Backend: Evasión por API o Falla General (422 Unprocessable Entity)**:
   - *Causa*: Inyección directa de payload malicioso por cURL ignorando la UI, o desincronización de cliente.
   - *Mensaje Payload JSON*: El exception handler global responderá con `{"error_code": "ERR_INVALID_RUT", "message_user": "El RUT ingresado no es válido legalmente. Verifica que el dígito verificador sea correcto."}`

## 4. Checklist de Tareas de Implementación (TDD)
- [x] **Tarea 1 (Backend - Utils)**: Desarrollar `backend/core/utils/validators.py` con el algoritmo Módulo 11 en Python puro.
- [x] **Tarea 2 (Backend - Schemas Pydantic)**: Aplicar el validador `normalizar_y_validar_rut` a todos los esquemas relevantes en `backend/schemas.py`.
- [x] **Tarea 3 (Backend - Pruebas Pytest)**: Escribir unit tests introduciendo RUTs válidos, inválidos e inventados (ej. `1.111.111-1`) y validar el rechazo de Pydantic (HTTP 422).
- [x] **Tarea 4 (Frontend - Utils y Formatter)**: Programar `RutValidator` y `RutFormatter` en `lib/core/utils/` replicando exactamente el comportamiento matemático en Dart.
- [x] **Tarea 5 (Frontend - UI y Validaciones)**: Inyectar validadores reactivos en el Wizard de Mesón y modal de clientes para bloquear botones de acción y desplegar el texto de advertencia rojo. Utilizar `if (!mounted) return;` en cualquier submisión.
- [x] **Tarea 6 (Frontend - Pruebas Widget)**: Redactar un Test en Flutter para asegurar que `RutValidator.isValid('12345678-5')` (rut falso) devuelva `false` y deshabilite el botón mock.
- [x] **Tarea 7 (Documentación OBLIGATORIA)**: Finalizado el código, anexar o crear un archivo `DICCIONARIO_ERRORES_TAREA12.md` detallando las capas (Front/Back) donde salta el error de RUT, la captura del `422` y los textos asociados requeridos.

## 5. Criterios de Validación Automatizada
- Backend Tests: Ejecutar `pytest tests/test_rut_validator.py -v`.
- Backend Linter: Ejecutar `flake8 backend/core/utils/validators.py backend/schemas.py`.
- Frontend Tests: Ejecutar `flutter test test/core/utils/rut_validator_test.dart`.
- Frontend Linter: Ejecutar `flutter analyze lib/core/ lib/features/ventas/`.
