# DICCIONARIO DE ERRORES - TAREA 12 (VALIDACIÓN RUT MÓDULO 11)

**Módulo:** Captura y Registro de Clientes / Micro-CRM / Checkout Wizard  
**Objetivo:** Proteger la integridad contable, tributaria (SII) y logística impidiendo el registro o ingreso de identificadores ficticios mediante validación matemática estricta Módulo 11 en Frontend y Backend.

---

## 1. Matriz de Excepciones y Respuestas por Capa

| Capa | Evento / Disparador | Detección / Componente | Comportamiento UI / Código HTTP | Payload / Mensaje Usuario |
| :--- | :--- | :--- | :--- | :--- |
| **Frontend (Visual)** | Usuario escribe un RUT matemáticamente inválido (falla Módulo 11 o formato) | `RutValidator.isValid()` en `TextFormField` / `TextField` | Muestra texto de advertencia rojo debajo del campo y **bloquea el botón** de acción ("Siguiente" / "Guardar") en estado `disabled`. | `"RUT inválido. Verifique el número ingresado."` |
| **Frontend (Formato)** | Usuario teclea letra 'k' minúscula en el campo de RUT | `RutFormatter` (`TextInputFormatter`) | Conversión automática e instantánea a mayúscula 'K' y aplicación de máscara con puntos y guion. | Transparente al usuario (`11111112k` -> `11.111.112-K`) |
| **Backend (Validación)** | Petición API directa (cURL, Postman o frontend desincronizado) con RUT inválido | Pydantic V2 `@field_validator` en `BaseRutSchema` -> `validar_rut_modulo11` | **HTTP 422 Unprocessable Entity** capturado por el `validation_exception_handler` global. | `{"error_code": "ERR_INVALID_RUT", "message_user": "El RUT ingresado no es válido legalmente. Verifica que el dígito verificador sea correcto."}` |

---

## 2. Detalle de Implementación Técnica

### 2.1 Frontend (Flutter 3.3x)

- **`lib/core/utils/rut_validator.dart`**:
  - `RutValidator.isValid(String? rut)`: Retorna `true` únicamente si el cuerpo numérico y el dígito verificador coinciden según la fórmula de ponderación regresiva cíclica (2 a 7) de derecha a izquierda:
    $$\text{resto} = \sum (\text{dígito}_i \times \text{ponderador}_i) \pmod{11}$$
    $$\text{resultado} = 11 - \text{resto}$$
    - Si resultado == 11 $\rightarrow$ '0'
    - Si resultado == 10 $\rightarrow$ 'K'
    - Otro $\rightarrow$ $\text{resultado}$
  - Exención legal: Reconoce y valida inmediatamente `6.666.666-6` y `66666666-6` para el cliente genérico de consumidor final.
  - `RutValidator.format(String rut, {bool withDots = true})`: Normaliza la cadena a formato `XX.XXX.XXX-X`.
  - `RutValidator.clean(String? rut)`: Remueve puntos, guiones y espacios en blanco, convirtiendo a mayúsculas.

- **`lib/core/utils/rut_formatter.dart`**:
  - `RutFormatter extends TextInputFormatter`: Filtra caracteres no permitidos, fuerza la letra 'K' mayúscula y formatea en tiempo real mientras el usuario escribe.

- **`lib/features/ventas/presentation/screens/checkout_wizard_screen.dart`**:
  - **Paso 2 (Cliente CRM)**: Campo `_rutController` con `RutFormatter()`, texto de error dinámico `"RUT inválido. Verifique el número ingresado."` y deshabilitación reactiva del botón "Siguiente" (`Key('btn_siguiente_wizard')`).
  - **Paso 3 (Logística / Despacho)**: Campo `_receptorRutController` con `RutFormatter()`, texto de error dinámico si el tipo de entrega es "Despacho" y deshabilitación reactiva del botón "Siguiente".

- **`lib/features/ventas/presentation/screens/carrito_screen.dart`**:
  - Campos `_rutController` y `_rutReceptorController` equipados con `RutFormatter()` y validación contra `RutValidator.isValid`.

### 2.2 Backend (FastAPI + Pydantic V2)

- **`backend/core/utils/validators.py`**:
  - `calcular_digito_verificador(cuerpo: str) -> str`
  - `formatear_rut(rut: str, con_puntos: bool = True) -> str`
  - `validar_rut_modulo11(rut: str, con_puntos: bool = True) -> Tuple[bool, str]`

- **`backend/schemas.py`**:
  - `BaseRutSchema(BaseModel)`: Clase transversal con `@field_validator('rut_cliente', 'receptor_rut', 'rut_usuario', mode='before', check_fields=False)`. Normaliza y valida automáticamente el identificador fiscal.
  - `ClienteCreateRequest(BaseRutSchema)`: DTO para el registro de clientes (`POST /api/v1/clientes`).

- **`backend/core/exceptions.py`**:
  - `validation_exception_handler`: Detecta incidencias sobre campos de RUT en `exc.errors()` y retorna el contrato estandarizado:
    ```json
    {
      "error_code": "ERR_INVALID_RUT",
      "message_user": "El RUT ingresado no es válido legalmente. Verifica que el dígito verificador sea correcto.",
      "message_dev": "El formato del campo 'rut_cliente' es inválido.",
      "detail": "El RUT ingresado no es válido legalmente. Verifica que el dígito verificador sea correcto."
    }
    ```

- **`backend/routers/clientes.py`**:
  - Endpoint `POST /api/v1/clientes`: Recibe `ClienteCreateRequest` y persiste bajo transacción ACID con rollback en caso de fallo.
