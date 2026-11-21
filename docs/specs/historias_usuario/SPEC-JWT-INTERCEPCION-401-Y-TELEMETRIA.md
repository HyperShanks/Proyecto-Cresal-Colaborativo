# SPEC: Blindaje de Sesión Expirada (HTTP 401), Retorno Reactivo a PIN y Telemetría Segura en Consola

**Documento:** Especificación Técnica de Implementación  
**Módulo:** Autenticación, Ventas, Bodega, Caja y Soporte  
**Estado:** Implementado / Listo para Fase de Simulación  
**Fecha:** 2026-09-22  

---

## 1. Contexto y Problema Resuelto

### El Problema Previo:
* Vendedores de Mesón y Jefes de Ventas experimentaban en dispositivos móviles una pantalla bloqueada con ícono rojo:
  > **"Sesión expirada o token inválido"**  
  > `[ 🔄 Reintentar ]`
* Al presionar "Reintentar", se enviaba nuevamente la petición con el mismo token vencido, provocando un bucle infinito de bloqueo.
* En Bodega, el error 401 en alertas era silenciado retornando 0 tareas, lo que impedía que el personal supiera que su sesión requería renovación.
* No existía visibilidad en la consola de depuración (Debug Console) para saber de inmediato cuándo un token había expirado o qué respuesta HTTP devolvía el backend.

### La Solución Implementada:
1. **Blindaje de Intercepción Universal 401:** Se conectaron todos los servicios HTTP del frontend con `AuthService.manejarSesionExpirada()`. Ante cualquier rechazo por expiración o cambio de clave, la app invalida la sesión activa y navega instantáneamente a `PinLoginScreen` con un SnackBar flotante explicativo.
2. **Preservación Total del Estado de Venta:** `AuthService.manejarSesionExpirada()` no destruye el enrolamiento del terminal ni vacía el carrito en `CartController.instance`. Al reingresar el PIN de 4 dígitos, el operario retoma su venta en 2 segundos.
3. **Telemetría Segura en Consola (Debug Console):** Registros claros condicionados a `kDebugMode`, sin exponer información sensible (sin tokens completos, contraseñas ni PINs).

---

## 2. Reglas de Telemetría en Consola (`Debug Console`)

Todas las emisiones están estrictamente condicionadas a `if (kDebugMode) debugPrint(...)`, garantizando que en las compilaciones de producción (Release) para los vendedores reales no se emita ninguna traza técnica.

### Formatos Exactos de Salida:
1. **Fecha de Expiración al Autenticar o Renovar PIN:**
   ```text
   [AUTH] Token válido hasta: YYYY-MM-DD HH:MM:SS
   ```
   *Mecánica:* Decodifica el claim `exp` del payload base64 del JWT sin almacenar ni imprimir el token completo.

2. **Acción de Redirección Automática ante 401:**
   ```text
   [AUTH] 401 detectado -> Redirigiendo automáticamente a pantalla de PIN sin vaciar carrito
   ```

3. **Telemetría de Estados HTTP en Servicios:**
   ```text
   🌐 [CATALOGO] HTTP 200 OK
   🌐 [CATALOGO] HTTP 401 Unauthorized
   🌐 [INVENTARIO-VENTAS] HTTP 200 OK en pendientes-precio
   🌐 [LOGISTICA] HTTP 200 OK en tareas-pendientes
   🌐 [BODEGA] HTTP 200 OK en reingresos-pendientes
   🌐 [VENTAS] HTTP 201 OK en checkout-wizard
   🌐 [ORDENES] HTTP 401 Unauthorized en crearOrden
   🌐 [TICKETS] HTTP 200 OK
   ⚠️ [API-SERVICE] HTTP 401 Unauthorized detectado
   ```

---

## 3. Matriz de Archivos Modificados

| Archivo | Tipo de Cambio | Descripción Técnica |
| :--- | :--- | :--- |
| `frontend/lib/features/auth/services/auth_service.dart` | Modificado | • Incorporó `_loggearExpiracionToken(token)` en `enrolarTerminal` y `loginConPin`.<br>• Agregó telemetría de redirección en `manejarSesionExpirada`.<br>• Decodificación segura de `exp` vía `base64Url` sin dependencias externas. |
| `frontend/lib/features/ventas/services/catalogo_service.dart` | Modificado | • Interceptó HTTP 401 en `obtenerCatalogo` invocando `AuthService.manejarSesionExpirada()`.<br>• Interceptó HTTP 401 en `obtenerOpcionesFiltrosCatalogo`.<br>• Telemetría de estados HTTP con `kDebugMode`. |
| `frontend/lib/features/ventas/presentation/screens/catalogo_screen.dart` | Modificado | • En el `catch` de `_fetchCatalogo`, si el error corresponde a sesión expirada, se omite el `setState(_errorMessage = ...)` para evitar cualquier parpadeo de pantalla roja mientras se transiciona al PIN. |
| `frontend/lib/features/ventas/services/inventario_service.dart` | Modificado | • Interceptó HTTP 401 en `obtenerPendientesPrecio` y `asignarPrecio` llamando a `AuthService.manejarSesionExpirada()`.<br>• Telemetría `🌐 [INVENTARIO-VENTAS]`. |
| `frontend/lib/features/alertas/services/logistica_service.dart` | Modificado | • Interceptó 401 en `obtenerAlertas`, `verificarQrSalida`, `escanearSalida`, `completarPreentrega` y `obtenerResumenAlertas`.<br>• Elimina el silenciado silencioso de 0 tareas ante expiración. |
| `frontend/lib/features/alertas/services/bodega_service.dart` | Modificado | • Interceptó 401 en `obtenerReingresosPendientes` y `confirmarReingreso` llamando a `AuthService.manejarSesionExpirada()`. |
| `frontend/lib/features/ventas/services/ventas_service.dart` | Modificado | • Interceptó 401 en `processCheckoutWizard` llamando a `AuthService.manejarSesionExpirada()`. |
| `frontend/lib/features/ventas/services/ordenes_service.dart` | Modificado | • Interceptó 401 en `crearOrden`, `obtenerOrdenes`, `anularOrden`, `actualizarInstruccionesBodega` y `pagarOrden`. |
| `frontend/lib/features/tickets/services/ticket_service.dart` | Modificado | • Interceptó 401 en `obtenerTickets` llamando a `AuthService.manejarSesionExpirada()`. |
| `frontend/lib/features/ventas/services/carrito_service.dart` | Modificado | • Interceptó 401 en `reservarActivo`, `liberarActivo`, `heartbeat` y `obtenerMisReservas`.<br>• Telemetría `🌐 [CARRITO] HTTP 200/401`. |
| `frontend/lib/core/services/session_inactivity_service.dart` | Nuevo | • Detector global de inactividad de 10 minutos para todas las vistas y roles.<br>• Destruye pila previa y redirige a PIN sin guardar pantallas paradas. |
| `frontend/lib/core/services/api_service.dart` | Modificado | • Incorporó telemetría `kDebugMode` en `_checkStatusCode` ante 401. |

---

## 4. Garantías de Seguridad Implementadas

1. **Principio de Mínima Exposición:** Ningún print emite strings que comiencen con `eyJ...` (JWT crudo). Solo se expone la fecha calculada de expiración.
2. **Protección de Credenciales:** Ni el PIN de 4 dígitos ni las contraseñas corporativas se imprimen en ningún log.
3. **Aislamiento en Producción:** Toda la telemetría utiliza `debugPrint` condicionado por `kDebugMode`, el cual es optimizado y eliminado en modo `release`.

---

## 5. Guía de Ejecución para las Próximas Simulaciones

Cuando se desee ejecutar las pruebas de simulación (Tareas 1 y 3 de `JWT_DOCUMENTO_PRUEBA.md`), se seguirán estos pasos:

### Simulación A: Forzar 401 por Fecha/Hora en el Dispositivo
1. Iniciar sesión en la app con un vendedor (ej. `carlos.mendoza@cresal.cl` / PIN: `2002`).
2. Observar en consola:
   ```text
   [AUTH] Token válido hasta: 2026-09-23 21:30:00
   ```
3. Agregar repuestos al carrito.
4. En los ajustes de Android/Windows, adelantar la fecha del sistema en +2 días.
5. Volver a la app y navegar al Catálogo.
6. **Comportamiento Esperado:**
   - La consola imprime:
     ```text
     🌐 [CATALOGO] HTTP 401 Unauthorized
     [AUTH] 401 detectado -> Redirigiendo automáticamente a pantalla de PIN sin vaciar carrito
     ```
   - La pantalla transiciona limpiamente a `PinLoginScreen`.
   - Se muestra el SnackBar: *"Tu sesión ha expirado. Ingresa tu PIN nuevamente"*.
   - Se digita `2002` y el vendedor vuelve al Catálogo con su carrito intacto.

### Simulación B: Expiración Acelerada en Backend de Pruebas
1. En `backend/core/config.py` o en el panel de Render Dev, configurar temporalmente:
   `TOKEN_EXPIRE_MINUTES = 2`.
2. Iniciar sesión y esperar 2 minutos exactos.
3. Realizar una acción en la app (filtrar catálogo, ver órdenes o tareas de bodega).
4. **Comportamiento Esperado:** Redirección automática inmediata al PIN sin carteles rojos de error ni bucles de reintento.
5. Al finalizar las pruebas, restaurar `TOKEN_EXPIRE_MINUTES = 1440` (24 horas).
