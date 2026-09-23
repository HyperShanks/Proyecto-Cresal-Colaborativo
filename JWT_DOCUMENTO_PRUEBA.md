# JWT DOCUMENTO PRUEBA: Diagnóstico, Arquitectura y Plan de Validación

Este documento consolida el análisis exhaustivo realizado sobre el ciclo de vida del JWT, las diferencias de comportamiento entre ramas (`main` vs `develop`), la causa raíz del error de sesión en los dispositivos de los vendedores y el plan paso a paso diseñado para su prueba y blindaje definitivo.

---

## 1. El Problema Detectado

### Incidente Reportado
Usuarios con rol de **Vendedor de Mesón** y **Jefe de Ventas** experimentaron en sus teléfonos móviles una pantalla bloqueada con un ícono rojo de advertencia:
> **"Sesión expirada o token inválido"**  
> `[ 🔄 Reintentar ]`

Al pulsar el botón **"Reintentar"**, la aplicación repetía la petición sin éxito y no los redirigía a la pantalla de desbloqueo por PIN, dejándolos en un bucle infinito de bloqueo.

---

## 2. Diagnóstico Técnico y Causa Raíz

El incidente tiene tres explicaciones técnicas fundamentales que interactúan entre sí:

### A. Falta de Intercepción del Error HTTP 401 en el Catálogo
En el servicio de catálogo de ventas:
* Cuando el backend de Render rechaza una petición porque el token ya venció o cambió la firma secreta, responde con código **`HTTP 401 Unauthorized`**.
* En lugar de ejecutar la función global de sesión expirada (`AuthService.manejarSesionExpirada()`), el código lanza directamente una excepción:
  ```dart
  else if (response.statusCode == 401) {
    throw Exception('Sesión expirada o token inválido');
  }
  ```
* La vista del catálogo captura esta excepción en su variable de error y dibuja la interfaz con el botón `Reintentar`. Como el token almacenado sigue siendo el mismo token inválido, pulsar el botón reenvía la credencial caducada una y otra vez.

### B. Tokens Residuales y Diferencia de Entornos (Render Prod vs Render Test)
* Los teléfonos de los vendedores mantenían guardado en su almacenamiento seguro (`FlutterSecureStorage`) un token previo generado días atrás o emitido por otro entorno.
* Al apuntar la aplicación al backend de producción, este rechazó el token por expiración o por diferencia en la clave criptográfica (`JWT_SECRET_KEY`).
* La aplicación no contaba con el mecanismo reactivo para limpiar el estado inválido y solicitar el PIN de 4 dígitos.

### C. Disparidad entre Roles en el Manejo de Sesión
* **Ventas (`CatalogoScreen`):** Lanza excepción ruidosa que bloquea la pantalla con botón de reintento.
* **Bodega (`HomeScreen` / `logistica_service.dart`):** Ante un error 401 silencia la falla y devuelve una lista vacía de alertas (`ResumenAlertasModel.vacio()`), por lo que los operarios de bodega veían 0 tareas en lugar del cartel rojo.

---

## 3. Arquitectura del JWT: Autenticación vs Autorización Horaria

Para comprender el comportamiento del sistema, es crucial distinguir las dos capas independientes:

```
[Dispositivo Móvil: Petición HTTP con Bearer Token]
                         │
                         ▼
        ┌─────────────────────────────────┐
        │  1. CAPA DE AUTENTICACIÓN (JWT) │ ──► ¿El token es válido y no ha expirado?
        └─────────────────────────────────┘
                         │ (Si expiró -> 401 Unauthorized)
                         ▼
        ┌─────────────────────────────────┐
        │  2. CAPA DE POLÍTICAS (AuthZ)   │ ──► ¿El rol puede operar en este horario?
        └─────────────────────────────────┘
                         │ (Si fuera de horario -> 403 Forbidden)
```

### Capa 1: Autenticación JWT (`TOKEN_EXPIRE_MINUTES`)
* **Valor Configurado:** `1440` minutos (**24 horas continuas**).
* **Alcance:** **Afecta a todos los roles por igual** (Vendedor, Jefe de Ventas, Bodeguero, Cajero, Administrador, Gerente).
* **Mecánica:** El contador de 24 horas comienza en el instante exacto en que el usuario se autentica (ej. si ingresa a las 08:00 AM, el token es criptográficamente válido hasta las 08:00 AM del día siguiente, sin importar cortes de medianoche).
* **Prioridad en Render:** Render prioriza las variables de entorno configuradas en su panel web (*Environment*). Si la variable `TOKEN_EXPIRE_MINUTES` no está explícitamente definida en Render, toma por defecto los `1440` minutos establecidos en el código backend.

### Capa 2: Políticas de Horario Comercial (`policies.py`)
* **No afecta la validez del token:** No expira el JWT ni produce error 401.
* **Comportamiento por Rol:**
  * **Jefe de Ventas, Vendedor Online, Administrador, Gerente:** Operan **24/7** sin restricción horaria.
  * **Vendedor Mesón:** Solo tiene restricción al momento de *emitir/confirmar una orden de venta presencial* fuera del horario de tienda (más 30 minutos de gracia), pero puede consultar el catálogo de repuestos en cualquier momento mientras su JWT esté vigente.
  * **Bodega y Caja:** Restringidos a operaciones de escaneo físico y cobro dentro de la jornada laboral.

---

## 4. Comparativa de Ramas: `main` vs `develop`

| Aspecto | Estado en `main` | Estado en `develop` |
| :--- | :--- | :--- |
| **Respuesta ante 401 en Catálogo** | Lanza `Exception` y dibuja pantalla roja con "Reintentar". | En proceso de conectar a `AuthService.manejarSesionExpirada()`. |
| **Retorno al PIN ante 401** | Inexistente en Ventas. | Diseñado para preservar el carrito y solicitar PIN de 4 dígitos. |
| **Ciclo de vida en Ventas al salir al inicio** | No tiene observador de inactividad; al volver sigue abierta. | Integra políticas de inactividad seguras sin destruir la sesión. |
| **Manejo de Inactividad en Bodega** | Destructivo a los 5 minutos (`clearToken()` que cerraba todo). | Refactorizado a 15 minutos con bloqueo por PIN no destructivo. |
| **Validaciones Operativas de Horario** | Solo restringía creación de órdenes en meson. | Cobertura integral en escaneos de salida (Bodega) y cobros (Caja). |

---

## 5. Seguridad y Visibilidad de Logs (Console vs Render)

* **Seguridad de `print` / `debugPrint`:**
  * Es totalmente seguro y una buena práctica imprimir el código de estado (`HTTP 401`) y la fecha estimada de expiración para depuración.
  * **Regla estricta:** Nunca imprimir el token JWT completo (`Bearer eyJ...`), passwords o PINs en consola.
  * En Flutter se debe condicionar con `if (kDebugMode) debugPrint(...)`, garantizando que en las compilaciones para usuarios reales no se emita ningún dato.
* **¿Por qué la consola local no ve a los vendedores reales?**
  * La consola de depuración local solo recibe la telemetría del dispositivo físico conectado por cable USB.
  * El único lugar donde se registran las peticiones de los teléfonos de la sucursal es en los logs centralizados del servidor en Render.

---

## 6. Plan de Tres Tareas para Pruebas y Validación

Este es el plan estructurado para validar y blindar la solución sin generar sorpresas a los usuarios:

```
┌────────────────────────────────────────────────────────────────────────┐
│ TAREA 1: Prueba de Expiración Acelerada (Simulación)                   │
│ - Configurar temporalmente expiración corta (ej. 2 minutos) en Dev.   │
│ - O adelantar fecha/hora en dispositivo para forzar HTTP 401.          │
│ - Verificar emisión de logs limpios en consola.                        │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│ TAREA 2: Blindaje de Retorno al PIN en TODOS los Roles                 │
│ - Interceptar HTTP 401 en TODOS los servicios (Ventas, Bodega, Caja).  │
│ - Invocar AuthService.manejarSesionExpirada() automáticamente.         │
│ - Validar que la app no muestre "Reintentar" y pida PIN directamente.  │
│ - Validar que el carrito y los datos activos se mantengan intactos.    │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│ TAREA 3: Verificación Cruzada, Restauración y Documentación            │
│ - Restaurar expiración oficial de 1440 minutos (24 horas).             │
│ - Probar login por PIN y renovación limpia de credenciales.            │
│ - Integrar a develop con pruebas automatizadas aprobadas.              │
└────────────────────────────────────────────────────────────────────────┘
```

### Detalle de las Tareas:

1. **Tarea 1 - Simulación de Expiración:**
   * Usar el entorno de pruebas (`cresal-backend-dev.onrender.com` o backend local).
   * Generar la condición de token caducado (acortando tiempo o adelantando reloj).
   * Confirmar la recepción del `401 Unauthorized` desde el backend.

2. **Tarea 2 - Redirección Universal al PIN:**
   * Sustituir los `throw Exception('Sesión expirada...')` por llamadas reactivas a `manejarSesionExpirada()`.
   * Comprobar que en Vendedor, Jefe de Ventas, Bodega y Caja la expiración redirija inmediatamente a la pantalla de PIN sin pantallas rojas intermedias ni bucles de reintento.
3. **Tarea 3 - Restauración y Pase Limpio:**
   * Reconfirmar que `TOKEN_EXPIRE_MINUTES` quede en `1440` (24 horas).
   * Validar que ningún log exponga datos sensibles.
   * Consolidar los cambios en `develop` para su posterior pase seguro a `main`.

## 7. Referencias Técnicas Clave para la Implementación

Para asegurar que el próximo agente o chat tenga acceso directo a las piezas exactas del código:

* **Endpoints de Autenticación (`backend/routers/auth.py`):**
  * `POST /api/auth/login`: Login inicial por correo y contraseña. Emite el JWT de 24 horas y los datos completos del perfil.
  * `POST /api/auth/login-pin`: Login ágil por PIN de 4 dígitos (`request: { id_usuario, pin_acceso }`). Busca al usuario por UUID y PIN en la tabla `Usuario`. Si es válido, emite un **nuevo JWT fresco** con otros 1440 minutos de vida.
* **Manejo Centralizado de Expiración (`frontend/lib/features/auth/services/auth_service.dart`):**
  * `AuthService.manejarSesionExpirada()`: Método que preserva el usuario actual y limpia únicamente la validez activa del token para forzar la navegación a `/login` (que renderiza la vista de PIN si el usuario ya estaba vinculado).
* **Preservación del Carrito de Ventas (`frontend/lib/features/ventas/controllers/cart_controller.dart`):**
  * El estado de los repuestos seleccionados en el carrito reside en memoria del singleton `CartController.instance`. Al producirse un 401 y retornar a la pantalla del PIN, **el carrito no debe ser vaciado**; debe conservarse íntegro para que el vendedor retome su venta tras digitar su PIN.
* **Archivos Clave a Interceptar ante HTTP 401 en Frontend:**
  * `frontend/lib/features/ventas/services/catalogo_service.dart` (Búsqueda y paginación de repuestos)
  * `frontend/lib/features/ventas/services/inventario_service.dart` (Tasación y precios)
  * `frontend/lib/features/alertas/services/logistica_service.dart` (Resumen de alertas de bodega)
  * `frontend/lib/features/bodega/services/bodega_service.dart` (Escaneos y tareas de almacén)
  * `frontend/lib/features/caja/services/caja_service.dart` (Cobro de órdenes y validaciones de caja)

