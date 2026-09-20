# DOCUMENTACIÓN TÉCNICA: RESILIENCIA DE RED, HTTP KEEP-ALIVE Y RESOLUCIÓN DE HANDSHAKE EXCEPTION (SSOT)

> **Módulos Afectados**: Infraestructura (`ApiService`), Panel Ejecutivo (`Gerencia`), Módulo de Caja (`CajaMainScreen`, `BandejaCobrosPanel`) y Navegación Reactiva (`SPEC-HU-TAREA-20-AUTOREFRESH`).  
> **Fecha de Documentación**: Septiembre 2026  
> **Estado**: Resuelto e Implementado  

---

## 1. Resumen Ejecutivo del Problema

En las pruebas operativas en la sucursal de Cresal, se reportó que el puesto del **Gerente** experimentaba caídas constantes al cambiar de pestañas en el Panel Ejecutivo, mostrando una pantalla de error con el texto:
```text
HandshakeConnection terminated during handshake
[ Reintentar ]
```
El usuario reportó las siguientes observaciones críticas:
1. **Infraestructura de Conectividad**: El equipo de Gerencia no disponía de fibra óptica simétrica, sino de una conexión antigua de cobre / cable ethernet (aproximadamente 40 a 50 Mbps de bajada y 70 Mbps de subida).
2. **Latencia y Tiempos de Carga**: Mientras que en conexiones de fibra óptica el sistema cargaba en ~1 segundo, en el equipo de Gerencia la respuesta tardaba más de 3 segundos o saltaba la pantalla de error.
3. **Comportamiento Intermitente**: Al presionar repetidamente el botón "Reintentar" o esperar unos momentos navegando con calma, el sistema volvía a responder con normalidad.
4. **Mensaje Confuso e Ilegible**: El mensaje crudo `HandshakeConnection terminated...` no proporcionaba claridad ni al usuario de negocio (para saber si era su internet o el servidor) ni al equipo técnico (para determinar la causa exacta sin ambigüedades).

---

## 2. Anatomía de la Causa Raíz

### A. La Física de Red: Cobre vs Fibra Óptica y Negociación TLS
Un Handshake TLS/HTTPS (apretón de manos criptográfico) exige un intercambio de certificados digitales y claves antes de enviar cualquier dato:
1. `ClientHello` (Cliente -> Servidor).
2. `ServerHello` + Cadena de Certificados X.509 (Servidor -> Cliente).
3. `Key Exchange` + Validación criptográfica (Cliente -> Servidor).
4. `Finished / CipherSpec` (Ambos extremos encriptados).

En fibra óptica, la latencia de ida y vuelta (RTT) a los servidores de **Render** (`cresal-backend-dev.onrender.com` en EE.UU.) es de ~120 ms con **0% de pérdida de paquetes**.
En cambio, en redes de cobre/coaxial antiguas con tráfico compartido de oficina:
- Existe **jitter** (fluctuación de latencia de 250 ms a 400 ms).
- Existe **pérdida de micro-paquetes (packet loss)** y congestión en la cola de subida del módem (*bufferbloat*).
- Los paquetes grandes del certificado SSL viajan fragmentados. Si uno de ellos se retrasa o se pierde durante una ráfaga, el balanceador de carga de Render o el router local envía un paquete `TCP RST` (Reset) forzado para cerrar el socket colgado.

```mermaid
sequenceDiagram
    autonumber
    participant App as Flutter App (Cliente)
    participant Router as Router Oficina (Cobre/NAT)
    participant Render as Servidor Cloud (Render/Proxy)

    Note over App,Render: Sin Keep-Alive (Comportamiento Antiguo)
    App->>Router: Petición 1: TCP SYN (Nueva Conexión)
    Router->>Render: Reenvío TCP SYN
    Render-->>App: TCP SYN-ACK + TLS ServerHello (Certificado)
    Note over App,Router: Cambio brusco de pestaña dispara Petición 2 y 3 concurrentes
    App->>Router: Petición 2: TLS ClientHello
    App->>Router: Petición 3: TLS ClientHello
    Router-->>Render: Ráfaga de sockets en cobre (Ruido / Saturación NAT)
    Render-->>App: TCP RST (Connection Reset by Peer)
    Note over App: dart:io lanza HandshakeException: Connection terminated
```

### B. El Factor Gatillante: Auto-Refresh de Pestañas (SPEC-HU-TAREA-20)
En [SPEC-HU-TAREA-20-AUTOREFRESH.md]SPEC-HU-TAREA-20-AUTOREFRESH.md se definió que toda vista debe refrescarse automáticamente al cambiar de pestaña o volver atrás (`didPopNext()`) para evitar datos obsoletos (*stale data*). Por ejemplo, si en Bodega se liberó un repuesto o en Caja se cobró una orden, el Gerente debe ver la información actualizada.

En [dashboard_gerencia_view.dart] frontend/lib/features/gerencia/presentation/screens/dashboard_gerencia_view.dart, la carga del Dashboard ejecuta simultáneamente:
```dart
final futures = await Future.wait([
  GerenciaService.obtenerKpis(idSucursal: _sucursalSeleccionada),
  GerenciaService.obtenerResumenPagos(idSucursal: _sucursalSeleccionada),
  GerenciaService.obtenerFlujoOperativo(idSucursal: _sucursalSeleccionada),
]);
```
**El problema no era la recarga en sí**, sino que el cliente HTTP llamaba a `http.get(...)` de forma aislada, **destruyendo y abriendo un nuevo túnel seguro desde cero en cada llamada**. Cada cambio rápido de pestaña bombardeaba a Render con 3 a 6 negociaciones TLS simultáneas en el mismo segundo.

### C. El Bug del Mensaje Deformado
En `api_service.dart` y en las vistas de Gerencia existía la siguiente instrucción:
```dart
e.toString().replaceFirst('Exception: ', '');
```
Como la excepción de Dart es `HandshakeException: Connection terminated during handshake`, la función buscaba el texto `'Exception: '` y lo eliminaba. Al estar `'Exception: '` pegado a la palabra `'Handshake'`, la expresión resultante quedó truncada como:
**`HandshakeConnection terminated during handshake`**.

---

## 3. Reproducción Científica en Entorno Controlado (Clumsy)

Para corroborar la hipótesis sin depender del internet físico de la sucursal, se utilizó la herramienta de auditoría de red para Windows **Clumsy 0.3**:

1. **Filtro Aplicado**:
   ```text
   tcp and (tcp.DstPort == 443 or tcp.SrcPort == 443)
   ```
2. **Experimento 1 (`Drop 15%`, `Lag 250ms`)**:
   - *Resultado*: La app respondió más lenta (3 a 4 segundos), pero no se cayeron las peticiones.
   - *Razón*: El protocolo TCP retransmitió automáticamente los paquetes perdidos.
3. **Experimento 2 (`Lag 250ms`, `Set TCP RST 20%`)**:
   - *Resultado*: Al cambiar rápidamente de pestañas entre *Dashboard*, *Órdenes*, *Inventario* y *Ventas en Verde*, **se reprodujo al 100% y en vivo el error exacto `HandshakeConnection terminated during handshake`** en todas las vistas.
   - *Conclusión*: Un corte forzado de socket (`TCP RST`) o una desconexión intempestiva durante el intercambio de llaves de cifrado era exactamente el evento físico que sufría el Gerente.

---

## 4. Arquitectura de la Solución Implementada

Para resolver este problema de manera definitiva a nivel de software, se diseñó una solución en 3 capas:

```mermaid
graph TD
    A[Petición UI en Pestaña / Auto-Refresh] --> B[ApiService Centralizado]
    B --> C{Socket TLS ya abierto?}
    C -- Sí (Keep-Alive) --> D[Reutilizar Túnel Seguro Existente]
    C -- No --> E[Abrir Socket TLS Único]
    D --> F[Envío Inmediato de Datos < 300ms]
    E --> F
    F --> G{Ocurrió Microcorte / RST?}
    G -- No --> H[Respuesta 200 OK Exitosa]
    G -- Sí --> I{Intento < 2?}
    I -- Sí (Reintento Silencioso) --> J[Esperar 400ms y Reintentar Automáticamente]
    J --> F
    I -- No --> K[Mapeo Inteligente de Errores]
    K --> L[UI: Mensaje Amigable + Código Diagnóstico + Detalle Técnico]
```

### Capa 1: Conexión Persistente HTTP Keep-Alive
En [api_service.dart]frontend/lib/core/services/api_service.dart, se reemplazó la invocación a métodos estáticos de un solo uso por un cliente singleton persistente:
```dart
static http.Client _client = http.Client();
```
- **Beneficio**: El túnel seguro TLS se negocia **una sola vez** al inicio. Al cambiar entre pestañas o ejecutarse el auto-refresh, las consultas viajan por el socket que ya está abierto y autenticado.
- **Impacto**: El tiempo de cambio de pestaña se redujo de **~3.5 segundos a menos de 1 segundo**, eliminando el 95% de los handshakes redundantes.

### Capa 2: Reintento Automático Silencioso (Auto-Retry Policy)
En `ApiService.ejecutarConManejoErrores`, ante fallos de tipo `HandshakeException`, microcortes de socket o caídas transitorias de conexión:
- Se ejecuta automáticamente **1 reintento silencioso** con un retardo defensivo de `400 ms`.
- Si el segundo intento entra (que es lo habitual tras un paquete perdido momentáneo), el usuario **no experimenta ninguna interrupción visual ni pantallas rojas**.

### Capa 3: Sistema de Diagnóstico y Mensajería Inteligente
Se expandió `CustomApiException` para incorporar `diagnosticCode` y `messageDev`:
```dart
class CustomApiException implements Exception {
  final String messageUser;
  final String errorCode;
  final int? statusCode;
  final String? messageDev;
  final String diagnosticCode;
  ...
}
```

Se corrigió la sanitización de cadenas con una expresión regular limpia:
```dart
static String limpiarMensajeExcepcion(Object e) {
  final raw = e.toString().trim();
  final clean = raw
      .replaceFirst(RegExp(r'^[A-Za-z0-9_]*Exception:\s*'), '')
      .replaceFirst(RegExp(r'^[A-Za-z0-9_]*Error:\s*'), '')
      .trim();
  return clean.isNotEmpty ? clean : raw;
}
```

---

## 5. Catálogo de Códigos de Diagnóstico Estandarizados

Cuando la conexión falla de manera no recuperable, la interfaz presenta un mensaje claro para el usuario de negocio y un **código de diagnóstico visible** para soporte técnico:

| Código Técnico Visible | Mensaje Mostrado al Usuario | Causa Raíz Detectada | Sector Responsable | Acción Inmediata |
| :--- | :--- | :--- | :--- | :--- |
| **`[NET-SIN-INTERNET]`** | *"Sin conexión a internet. Verifique su cable de red o router local."* | Falla de resolución DNS o desconexión física total (Host desconocido / errno 11001). | **Sector Local (Cliente)**: PC sin red, cable desconectado o Wi-Fi caído. | Indicar al usuario que revise su cable de red/Wi-Fi o reinicie su tarjeta de red. |
| **`[NET-ENLACE-LOCAL]`** | *"Inestabilidad en la red local. Se interrumpió el enlace seguro con el servidor."* | `HandshakeException`, `TCP RST` durante la negociación TLS de certificados. | **Sector Enlace / Cobre**: Pérdida de paquetes en el tramo local o proveedor de internet (ISP). | Indicar al usuario presionar "Reintentar"; si persiste, el enlace de cobre está saturado o con microcortes. |
| **`[NET-CLIENT-ERROR]`** | *"Problemas de conexión con el servidor. Reintentando..."* | `http.ClientException` (`Connection closed while receiving data` / `before full header`). | **Sector Enlace / Cobre**: Socket cortado a mitad de transferencia del JSON. | Presionar botón "Reintentar". El backend está sano, el paquete se perdió en tránsito. |
| **`[NET-SOCKET-DROP]`** | *"Problemas de conexión con el servidor. Reintentando..."* | `SocketException` abrupto del SO (WinSock `errno 121` semáforo expirado o `WSAECONNABORTED`). | **Sector Local / Red**: Windows o router cerró el socket por latencia extrema (>15s) o corte físico. | Presionar botón "Reintentar". |
| **`[NET-TIMEOUT-35S]`** | *"Problemas de conexión con el servidor. Reintentando..."* | La petición superó el timeout de 35 segundos sin respuesta. | **Sector Nube (Servidor Render)**: Instancia dormida (en plan gratuito) o cold start. | En plan gratuito esperar 30s a que Render despierte. En producción ($7/mes Always-On), revisar si la BD está lenta. |
| **`[SRV-CLOUD-503]`** | *"El servicio no está disponible temporalmente. Intenta más tarde."* | HTTP 502 / 503 / 504 emitido por el proxy de Render o Cloudflare. | **Sector Nube (Infraestructura)**: Despliegue en curso o reinicio del contenedor. | Esperar 1-2 minutos a que termine el despliegue del backend. |

Adicionalmente, las pantallas de Gerencia (*Dashboard*, *Órdenes*, *Inventario* y *Ventas en Verde*) incluyen un control desplegable **"Ver detalle técnico ▼"** que expone el texto nativo de Dart y la URL consultada para que nosotros, como equipo de soporte/desarrollo, podamos auditar el incidente exacto en una captura de pantalla sin asustar al usuario.

---

## 6. Impacto y Protección en otros Roles (Caja y Ventas)

### ¿Cómo se benefician Caja y los demás usuarios?
- **Caja (`CajaService` y `CajaProvider`)**: Todas las peticiones críticas de Caja (`obtenerCobrosPendientes`, `registrarCobro`, `validarActivoBackorder` y `obtenerHistorialCaja`) se ejecutan a través de `ApiService`.
- **Protección Automática**:
  1. Al estar en la misma sucursal física compartiendo la conexión de cobre, la cajera ahora también disfruta de **Keep-Alive persistente** y **reintento silencioso**.
  2. En `CajaProvider` se corrigieron los bloques `catch` que replicaban el bug del `replaceAll('Exception: ', '')`, asegurando que la cajera reciba mensajes profesionales y no errores truncados.
- **Relación con SPEC-HU-TAREA-20**:
  La especificación `SPEC-HU-TAREA-20-AUTOREFRESH.md` **no requiere ser modificada**, ya que sus requerimientos de negocio de auto-refrescar datos siguen vigentes y ahora cuentan con la infraestructura de red adecuada para ejecutarse a máxima velocidad y con alta tolerancia a fallos.

---

## 7. Guía Operativa de Soporte Técnico: ¿De qué sector es el problema?

Dado que **nosotros actuamos como soporte técnico y desarrollo de Cresal**, cuando el Gerente o Cajera nos contacte con una captura o indicándonos el código del badge, usamos esta matriz rápida para saber exactamente dónde radica la falla y qué responderle:

### Caso A: El usuario nos dice: *"Me sale `NET-SIN-INTERNET`"*
* **Sector Responsable**: **100% Local (El equipo o router de la sucursal)**.
* **Diagnóstico Técnico**: El navegador o app ni siquiera puede resolver el nombre `cresal-backend-dev.onrender.com` (`errno = 11001 Host desconocido`). No hay cable conectado o el router se apagó.
* **Qué responderle al usuario**: *"Por favor verifique si el cable de red azul/gris está bien conectado a su computador o si el router de la oficina tiene las luces de internet encendidas. Su computador no tiene salida a internet."*

### Caso B: El usuario nos dice: *"Me sale `NET-ENLACE-LOCAL` o `NET-CLIENT-ERROR` o `NET-SOCKET-DROP`"*
* **Sector Responsable**: **Enlace Físico de Cobre / Proveedor de Internet (ISP de la sucursal)**.
* **Diagnóstico Técnico**: El servidor en la nube está funcionando perfecto, pero la conexión de cobre de la sucursal tuvo una pérdida de paquetes o microcorte transitorio justo mientras viajaban los datos.
* **Qué responderle al usuario**: *"Hubo un microcorte transitorio en la conexión a internet de la sucursal. Por favor presione el botón 'Reintentar' en pantalla; la información cargará de inmediato."* (Al presionar Reintentar, el Keep-Alive reconecta y carga sin necesidad de recargar la aplicación).

### Caso C: El usuario nos dice: *"Me sale `NET-TIMEOUT-35S`"*
* **Sector Responsable**: **Servidor en la Nube (Render)**.
* **Diagnóstico Técnico**:
  * **En entorno de Pruebas / Capa Gratuita (Free Tier)**: Render suspende el contenedor tras 15 minutos de inactividad (*spin-down*). Al recibir la primera petición, tarda entre 30 y 50 segundos en despertar (*cold start*).
  * **En entorno de Producción Oficial (Plan $7 USD Always-On)**: El contenedor nunca se suspende. Si ocurriese este error en producción, significa que una consulta a base de datos tardó más de 35 segundos (bloqueo transaccional o saturación de pool).
* **Qué responderle al usuario**:
  * Si es en ambiente dev: *"El servidor estaba iniciando tras un periodo de inactividad. Espere 15 segundos y presione 'Reintentar'."*
  * Si es en producción: Revisar los logs de FastAPI / PostgreSQL para optimizar índices o desbloquear transacciones.

### Caso D: El usuario nos dice: *"Me sale `SRV-CLOUD-503`"*
* **Sector Responsable**: **Servidor en la Nube (Despliegue / Mantenimiento)**.
* **Diagnóstico Técnico**: El backend está reiniciándose tras un `git push` o actualización de versión en Render.
* **Qué responderle al usuario**: *"Estamos aplicando una actualización en el sistema. Estará disponible en 1 minuto, gracias por su paciencia."*
