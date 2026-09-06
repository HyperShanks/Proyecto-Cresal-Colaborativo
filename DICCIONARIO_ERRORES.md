# DICCIONARIO DE ERRORES — Cresal SaaS (SPEC-HU-07)

Este documento constituye la **Matriz Exhaustiva de Errores, Sanitización y Mensajería al Usuario** del ecosistema Cresal SaaS. Define todos los códigos de error, condiciones de activación, respuestas HTTP y los mensajes normalizados que se presentan en la interfaz de usuario, garantizando el principio **Zero Technical Leaks** (Cero fuga de metadatos internos, tablas o trazas SQL).

---

## 1. Principios de Seguridad y UX en Manejo de Errores

1. **Zero Technical Leaks**: Queda estrictamente prohibido que respuestas `4xx` o `5xx` revelen sentencias SQL (`INSERT`, `SELECT`), nombres de columnas, restricciones de clave foránea crudas, drivers de base de datos (`psycopg2`, `asyncpg`) o *stack traces* de Python/FastAPI.
2. **Contrato Unificado `ErrorResponseDTO`**:
   ```json
   {
     "error_code": "RECORD_ALREADY_EXISTS",
     "message_user": "El registro ya existe en el sistema o tiene un identificador duplicado.",
     "message_dev": null,
     "detail": "El registro ya existe en el sistema o tiene un identificador duplicado."
   }
   ```
3. **Resiliencia y No-Bloqueo de UI**: Las fallas de conexión o respuestas lentas nunca bloquean la pantalla de forma infinita; activan el componente `CustomErrorSnackbar` con botón de **"Reintentar"**.

---

## 2. Matriz Exhaustiva de Errores del Sistema

### 🛒 Módulo 1: Carrito y Mesón de Ventas (`/ventas`, `/checkout-wizard`)

| Módulo | Código de Error (`error_code`) | Disparador (Cuándo se activa) | Mensaje al Usuario (`message_user`) | HTTP Status | Acción Sugerida en UI |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **Carrito** | `RESERVATION_COLLISION` | Colisión de concurrencia optimista (`version_lock`) al intentar reservar un repuesto físico que ya fue tomado por otro vendedor (`POST /api/v1/carrito/reservar`). | *"¡Lo sentimos! Este repuesto acaba de ser reservado por otro vendedor hace un instante."* | `409 Conflict` | Marca la tarjeta como bloqueada/reservada y desactiva el botón de agregar. |
| **Carrito** | `RESERVATION_ASSET_UNAVAILABLE` | Intento de agregar una pieza dada de baja o en mantenimiento (`POST /api/v1/carrito/reservar`). | *"El artículo seleccionado se encuentra en mantenimiento o fue dado de baja del inventario."* | `400 Bad Request` | Notificar al cliente o remover la pieza del catálogo. |
| **Carrito** | `RESERVATION_EXPIRED` | El tiempo de reserva (15 min) transcurre sin actividad (countdown timer llega a 0 en pantalla de carrito). | *"Tu tiempo de reserva ha finalizado por inactividad. Los artículos han sido devueltos al catálogo general."* | N/A (Local Timer) | Vacía el carrito local y libera las reservas en el backend. |
| **Carrito** | `RESERVATION_MISSING_CLIENT_RUT` | El vendedor intenta avanzar del Paso 1 (Cliente) en el Checkout Wizard sin identificar al cliente. | *"Falta identificar al cliente. Por favor, ingresa un RUT válido antes de proceder con la reserva de estos activos."* | N/A (Local Wizard) | Ingresar o buscar el RUT del cliente antes de continuar. |
| **Carrito** | `RESERVATION_NETWORK_ERROR` | Falla de conexión, timeout o socket al intentar reservar en el servidor (`POST /api/v1/carrito/reservar`). | *"No fue posible asegurar tu reserva debido a un problema de red. Reintentando..."* | N/A (Socket / Timeout) | Despliega SnackBar sin perder el estado del carrito ni congelar la pantalla. |
| **Carrito** | `CART_NO_ITEMS` | El vendedor intenta avanzar del Paso 0 (Ítems) con el carrito vacío. | *"Debes agregar al menos un artículo o servicio para proceder."* | N/A (Local) | Agregar repuestos o ítems manuales antes de continuar. |
| **Carrito** | `CART_NO_CUSTOMER` | El vendedor intenta avanzar del Paso 1 (Cliente) sin seleccionar o registrar un cliente. | *"Por favor, ingresa o busca el RUT del cliente antes de continuar."* | N/A (Local) | Buscar cliente por RUT o activar "Consumidor Final". |
| **Carrito** | `STOCK_COLLISION` | Al confirmar la orden, otro vendedor acaba de reservar uno de los repuestos en concurrencia. | *"Este repuesto acaba de ser reservado por otro vendedor."* | `409 Conflict` | Remover el ítem reservado o buscar repuesto sustituto. |
| **Carrito** | `INVALID_ORDER_DATA` | La orden contiene datos inconsistentes o parámetros vacíos. | *"Datos de la orden inválidos. Revisa el formulario."* | `400 Bad Request` | Corregir los campos destacados en el Stepper. |
| **Carrito** | `DESPACHO_INCOMPLETE` | Se seleccionó despacho a domicilio pero faltan datos del receptor o dirección. | *"Complete todos los campos obligatorios para el despacho a domicilio."* | N/A (Local) | Completar dirección, RUT y nombre del receptor. |
| **Carrito / CRM** | `ERR_INVALID_RUT` | Ingreso o envío de RUT que no supera el algoritmo matemático Módulo 11 (falla en dígito verificador). | *"El RUT ingresado no es válido legalmente. Verifica que el dígito verificador sea correcto."* (En UI: *"RUT inválido. Verifique el número ingresado."*) | `422 Unprocessable Entity` / Local UI | Bloquea el botón de avance y muestra texto rojo; en API responde 422 estandarizado. |
| **Carrito** | `ABONO_EXCEEDS_TOTAL` | El monto de abono ingresado supera el valor total de la venta. | *"El monto de abono no puede ser superior al total de la venta."* | N/A (Local) | Ajustar el valor del abono a un monto menor o igual al total. |

---

### 🔐 Módulo 2: Autenticación, PIN y Enrolamiento (`/auth`)

| Módulo | Código de Error (`error_code`) | Disparador (Cuándo se activa) | Mensaje al Usuario (`message_user`) | HTTP Status | Acción Sugerida en UI |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **Auth** | `AUTH_PIN_INVALID` | El operario digita un PIN de 4 dígitos incorrecto para el usuario vinculado al terminal. | *"PIN incorrecto para este terminal."* | `401 Unauthorized` | Reintentar ingreso de PIN (bloqueo tras 10 intentos). |
| **Auth** | `AUTH_CREDENTIALS_INVALID` | Ingreso de email o contraseña corporativa errónea. | *"Credenciales inválidas, verifica tu correo o contraseña."* | `401 Unauthorized` | Verificar correo y contraseña antes de reintentar. |
| **Auth** | `TERMINAL_NOT_ENROLLED` | Intento de login por PIN en un terminal sin usuario enrolado en almacenamiento seguro. | *"Terminal no enrolada, contacte a su administrador."* | N/A (Local) | Redirigir a pantalla `/enrolamiento` con credenciales maestras. |
| **Auth** | `AUTH_MAX_ATTEMPTS_EXCEEDED` | Se superaron los 10 intentos fallidos consecutivos de PIN. | *"Acceso bloqueado por seguridad tras 10 intentos fallidos."* | N/A (Local) | Desenrolar terminal o solicitar desbloqueo al administrador. |
| **Auth** | `SESSION_EXPIRED` | El token JWT expiró o fue revocado en el backend. | *"Tu sesión ha expirado. Ingresa tu PIN nuevamente."* | `401 Unauthorized` | Redirigir automáticamente a `/pin-login` limpiando credenciales. |
| **Auth** | `USER_ALREADY_EXISTS` | Intento de registrar un usuario con RUT o Email ya existente. | *"El correo electrónico o RUT ya se encuentra registrado en el sistema."* | `400 Bad Request` | Verificar datos del nuevo colaborador. |

---

### 💵 Módulo 3: Caja Desktop y Pasarela de Cobros (`/caja`)

| Módulo | Código de Error (`error_code`) | Disparador (Cuándo se activa) | Mensaje al Usuario (`message_user`) | HTTP Status | Acción Sugerida en UI |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **Caja** | `NO_PAYMENT_METHOD` | La cajera presiona procesar sin haber seleccionado ningún método de pago. | *"Selecciona un método de pago antes de procesar."* | `400 Bad Request` | Seleccionar al menos un método (Efectivo, Débito, etc.). |
| **Caja** | `INSUFFICIENT_PAYMENT` | La suma de los montos ingresados en los métodos es inferior al saldo pendiente de la orden. | *"El monto total ingresado no cubre el saldo pendiente de la orden."* | `400 Bad Request` | Ajustar montos o utilizar auto-rellenar en la pasarela. |
| **Caja** | `OVERPAYMENT_REJECTED` | La suma ingresada supera el total adeudado de la orden de venta. | *"Sobrepago rechazado: El monto a cobrar supera el saldo pendiente de la orden."* | `400 Bad Request` | Ajustar los montos de los métodos para cuadratura exacta. |
| **Caja** | `INVALID_PAYMENT_AMOUNT` | Uno de los métodos en modo dividido (split) tiene un valor menor o igual a $0. | *"Todos los métodos de pago deben registrar un monto estrictamente mayor a $0."* | `400 Bad Request` | Eliminar el método no utilizado o ingresar monto válido. |
| **Caja** | `ORDER_NOT_FOUND` | La orden seleccionada ya no existe o fue eliminada. | *"No se encontró la Orden de Venta especificada."* | `404 Not Found` | Refrescar la bandeja de cobros pendientes. |

---

### 📦 Módulo 4: Bodega PDA, Logística Inversa y Barrera Digital (`/bodega`)

| Módulo | Código de Error (`error_code`) | Disparador (Cuándo se activa) | Mensaje al Usuario (`message_user`) | HTTP Status | Acción Sugerida en UI |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **Bodega** | `SCAN_NOT_FOUND` | Se escanea un QR o token digital que no corresponde a ninguna orden activa. | *"El código escaneado no pertenece a ninguna orden activa."* | `404 Not Found` | Re-escanear ticket o verificar número de orden en sistema. |
| **Bodega** | `PIEZA_DUPLICADA` | El operario escanea dos veces la misma pieza física en el terminal de salida. | *"La pieza ya fue escaneada y registrada previamente."* | N/A (Local) | Continuar con la siguiente pieza requerida. |
| **Bodega** | `ORDER_MISMATCH` | El SKU físico escaneado pertenece a una orden distinta a la que se está liberando. | *"Cuidado, la pieza escaneada pertenece a otra orden."* | `400 Bad Request` | Retirar la pieza incorrecta y buscar el repuesto correcto. |
| **Bodega** | `ORDER_ALREADY_DELIVERED` | Intento de liberar una orden que ya fue completada y retirada previamente. | *"La orden ya fue entregada anteriormente."* | `400 Bad Request` | Verificar comprobante de entrega en auditoría. |
| **Bodega** | `ORDER_NOT_PAID` | Intento de liberar una orden en barrera que aún figura con saldo pendiente en caja. | *"La orden no se encuentra pagada en caja (Saldo pendiente)."* | `400 Bad Request` | Derivar al cliente a caja para liquidar el pago. |
| **Bodega** | `REINGRESO_SKU_INVALID` | El SKU escaneado en reingreso no coincide con el repuesto de la orden anulada. | *"El SKU físico no pertenece a la orden anulada especificada."* | `400 Bad Request` | Verificar el repuesto devuelto físicamente por el cliente. |
| **Bodega** | `INVENTARIO_CONCURRENCY_CONFLICT` | Colisión de concurrencia optimista (`version_lock`) al intentar guardar cambios en un activo modificado por otro operario (`PATCH /api/v1/inventario/{id_activo}`). | *"La información de este repuesto fue modificada por otro usuario recientemente. Los datos se actualizarán ahora para que revises los cambios antes de volver a editar."* | `409 Conflict` | Cierra el modal y refresca reactivamente la vista de detalle con los datos recientes. |
| **Bodega** | `INVENTARIO_NETWORK_TIMEOUT` | Pérdida de conectividad Wi-Fi/Datos en el galpón al intentar guardar cambios técnicos en el activo. | *"Conexión inestable. No pudimos guardar tus cambios. Por favor, reintenta en unos segundos."* | N/A (Timeout / Socket) | Despliega SnackBar de advertencia manteniendo los datos digitados en el formulario. |
| **Bodega** | `INVENTARIO_DIRTY_FORM_DISCARD` | El usuario modificó algún campo del formulario modal y presionó Cancelar o Atrás en el terminal PDA. | *"Tienes cambios sin guardar. ¿Estás seguro de que quieres salir y descartar las modificaciones?"* | N/A (Local Modal) | Diálogo de confirmación con opciones "Seguir editando" y "Descartar". |
| **Bodega** | `INVENTARIO_ASSET_LOCKED_SOLD` | Intento de modificar la ubicación o notas de un activo en estado 'Vendido' o 'Entregado' (`PATCH /api/v1/inventario/{id_activo}`). | *"Este artículo ya fue despachado o cobrado. Ya no es posible modificar su ubicación técnica."* | `400 Bad Request` | Despliega SnackBar de error bloqueando la alteración logística. |

---

### 🌐 Módulo 5: Red, Timeouts y Conectividad (`ApiService`)

| Módulo | Código de Error (`error_code`) | Disparador (Cuándo se activa) | Mensaje al Usuario (`message_user`) | HTTP Status | Acción Sugerida en UI |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **Red** | `NETWORK_TIMEOUT` | La petición al backend excede el tiempo límite establecido (12s - 15s). | *"Problemas de conexión con el servidor. Reintentando..."* | N/A (Timeout) | SnackBar con botón **"Reintentar"** sin congelar pantalla. |
| **Red** | `NETWORK_SOCKET_ERROR` | Pérdida de conexión Wi-Fi/Datos móviles en el terminal PDA. | *"Problemas de conexión con el servidor. Reintentando..."* | N/A (Socket) | SnackBar con botón **"Reintentar"** al restablecer señal. |
| **Red** | `DATABASE_UNAVAILABLE` | El servidor FastAPI pierde conexión con PostgreSQL (`OperationalError`). | *"El servicio de base de datos no está disponible temporalmente. Intenta nuevamente en unos momentos."* | `503 Unavailable` | Reintentar en 5 segundos tras reconexión automática. |
| **Red** | `INTERNAL_SERVER_ERROR` | Excepción no controlada en el servidor (500). Cero stack trace filtrado. | *"Ocurrió un error inesperado en el servidor. Intenta nuevamente."* | `500 Internal` | Notificar a soporte técnico mediante ticket de contingencia. |

---

### 🗄️ Módulo 6: Base de Datos y Persistencia Transaccional (`SQLAlchemyError`)

| Módulo | Código de Error (`error_code`) | Disparador (Cuándo se activa) | Mensaje al Usuario (`message_user`) | HTTP Status | Sanitización Aplicada |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **BD** | `RECORD_ALREADY_EXISTS` | Violación de `UNIQUE` constraint en PostgreSQL (RUT, Email, Folio). | *"El registro ya existe en el sistema o tiene un identificador duplicado."* | `409 Conflict` | Oculta nombres de constraints SQL y sentencias `INSERT`. |
| **BD** | `FOREIGN_KEY_VIOLATION` | Violación de `FOREIGN KEY` constraint al borrar o insertar registros vinculados. | *"La operación no pudo completarse porque hace referencia a un registro que no existe o está vinculado a otros datos."* | `409 Conflict` | Oculta tablas maestras y llaves foráneas crudas. |
| **BD** | `VALIDATION_ERROR` | Payload JSON mal formado o con tipos de datos inválidos (Pydantic 422). | *"Los datos ingresados no tienen un formato válido o faltan campos requeridos."* | `422 Unprocessable` | Transforma listas técnicas de Pydantic en explicaciones claras. |
| **BD** | `DATABASE_ERROR` | Error genérico de ejecución SQL. | *"Ocurrió un problema al procesar la información en la base de datos."* | `500 Internal` | Oculta sentencias SQL y parámetros transaccionales. |

---

## 3. Guía de Uso del Componente `CustomErrorSnackbar`

Para desplegar un error estandarizado con opción de reintento en cualquier vista de Flutter:

```dart
import 'package:frontend/core/widgets/custom_error_snackbar.dart';

// Uso dentro de un State/BuildContext:
CustomErrorSnackbar.mostrar(
  context,
  mensaje: 'Problemas de conexión con el servidor. Reintentando...',
  codigoError: 'NETWORK_TIMEOUT',
  onReintentar: () {
    // Lógica para volver a ejecutar la petición
    _cargarDatos();
  },
);

// Uso global (servicios desacoplados o background polling):
CustomErrorSnackbar.mostrarGlobal(
  mensaje: 'PIN incorrecto para este terminal.',
  codigoError: 'AUTH_PIN_INVALID',
);
```
