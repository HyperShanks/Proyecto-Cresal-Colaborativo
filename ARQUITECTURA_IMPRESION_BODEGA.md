# Arquitectura de Impresión Térmica Industrial y Enrutamiento Multi-Red en Bodega (Cresal SaaS)

Este documento constituye la especificación técnica integral de hardware, topología de red, enrutamiento multi-red simultáneo (Dual-Homing), protocolo de comunicación por Sockets TCP nativos, diagnóstico de fallos físicos y calibración de la estación de impresión de etiquetas QR en bodega.

---

## 1. Dispositivos Involucrados y Topología Física

| Dispositivo | Rol en el Sistema | Interfaz de Conexión | Dirección IP / Puerto |
| :--- | :--- | :--- | :--- |
| **Impresora Honeywell PC42E-T** | Impresora térmica industrial (ZPL II / ZSim, 203 DPI, Ribbon de Resina). | Cable Ethernet RJ45 (Fast Ethernet 100 Mbps) | **`192.168.8.50`** : Puerto TCP **`9100`** |
| **Router Huawei B320 (CPE 4G)** | Puerta de enlace local y punto de acceso Wi-Fi 2.4 GHz (SSID: `HUAWEI_B320_D326`). | Ethernet LAN (Puente `br-lan`) + Wi-Fi 802.11 b/g/n | **`192.168.8.1`** (Gateway `/24`) *(Sin chip SIM / Solo switch local)* |
| **PDA Sunmi L3 / Android** | Terminal móvil rugerizada para el Bodeguero (Android). | Wi-Fi 2.4 GHz (LAN) + SIM 4G/5G Móvil (WAN) | Dinámica DHCP (`192.168.8.X`) |

### Topología de Red y Flujo de Tráfico

```
                        [ Nube: Supabase / Backend Render ]
                                       ▲
                                       │ Datos Móviles Celular (4G/5G)
                                       │ Ruta predeterminada OS (rmnet_data0)
                                       ▼
                             ┌───────────────────┐
                             │   PDA Sunmi L3    │
                             │ (Operador Bodega) │
                             │ IP: 192.168.8.X   │
                             └─────────┬─────────┘
                                       │
                                       │ Wi-Fi 2.4 GHz (SSID: HUAWEI_B320_D326)
                                       │ Enlace forzado a wlan0 (bindSocket)
                                       ▼
                             ┌───────────────────┐
                             │ Router Huawei B320│
                             │ Gateway:          │
                             │ 192.168.8.1 /24   │
                             │ Bridge: br-lan    │
                             │ (Sin chip SIM)    │
                             └─────────┬─────────┘
                                       │
                                       │ Cable UTP Cat5e/6 (Puerto LAN RJ45)
                                       ▼
                             ┌───────────────────┐
                             │ Impresora Térmica │
                             │ Honeywell PC42E-T │
                             │ IP: 192.168.8.50  │
                             │ Puerto Raw: 9100  │
                             └───────────────────┘
```

---

## 2. Direccionamiento IP, Seguridad y Protocolos de Red

### ¿Por qué se usa la IP `192.168.8.50`?
- Los routers asignan direcciones por DHCP dinámico en el rango medio/alto (`.100` al `.200`).
- Si la impresora utilizara DHCP dinámico sin reserva, cada reinicio podría cambiar su dirección IP, provocando pérdida de conectividad en la aplicación.
- Se fijó una **IP estática baja (`.50`)** mediante **Reserva DHCP (Static Lease)** en el router Huawei vinculada a la MAC del equipo. La impresora opera en DHCP automático, pero el router siempre le entrega `192.168.8.50`.

### Seguridad sobre la Dirección MAC (`0C:23:69:FA:89:3F`)
- La dirección MAC es un identificador de hardware físico de Capa 2 (Enlace de Datos) que **solo tiene validez dentro de la red local del router y el cable RJ45**.
- No es accesible ni enrutable desde internet. Su registro en esta documentación técnica es estrictamente operativo para tareas de soporte y eventual reposición o reconfiguración del router.

### ¿Por qué el Puerto TCP 9100?
- El puerto **9100** es el estándar mundial **Raw TCP / JetDirect** para impresión industrial.
- Cada byte transmitido por este socket es recibido e interpretado de inmediato por el procesador térmico de la Honeywell (emulación ZSim / ZPL II), sin requerir controladores, servidores de impresión (spoolers) ni capas intermedias.
- Permite comunicación bidireccional en tiempo real: la PDA envía comandos de diagnóstico (`~HS`) y la Honeywell responde con el estado de sus sensores físicos antes de proceder a la impresión.

---

## 3. Diagnóstico del Problema Multi-Red: ¿Por qué fallaba la conexión simultánea?

### El Escenario en Bodega
1. **Terminal Móvil (PDA Sunmi L3 / Samsung Galaxy)**: Cuenta con un chip SIM con plan de datos móviles para comunicarse con la nube (Render API y Supabase).
2. **Impresora Térmica (Honeywell PC42E-T)**: Conectada por cable Ethernet al router local Huawei con IP estática reservada `192.168.8.50:9100`.
3. **Router de Bodega (Huawei B320)**: Actúa como switch/puente Ethernet y punto de acceso Wi-Fi local en `192.168.8.0/24`. **No dispone de chip SIM ni salida a internet**.

### Limitación de Android y Dart (`dart:io`)
- **Comportamiento del SO Android**:  
  Al conectarse a una red Wi-Fi, Android ejecuta un sondeo HTTP (`generate_204`). Al comprobar que el router Huawei no tiene salida a internet (`NET_CAPABILITY_VALIDATED` ausente), el kernel asigna la **Ruta por Defecto (`0.0.0.0/0`) a la interfaz de Datos Móviles (4G/5G)** para que el usuario no pierda conectividad con servicios en la nube.
- **Limitación de Dart (`Socket.connect`)**:  
  Flutter/Dart utiliza llamadas POSIX estándar del sistema operativo. Al llamar a `Socket.connect('192.168.8.50', 9100)`, Dart consulta la tabla de rutas global y enruta los paquetes hacia la red celular. La red telefónica no reconoce la IP privada `192.168.8.50`, produciendo errores de tipo `Network is unreachable`, `No route to host` o un `SocketTimeoutException`.
- **Por qué fallaron las IPs manuales con Gateway/DNS en `0.0.0.0`**:  
  Si en los ajustes del terminal se asigna un Gateway o DNS en `0.0.0.0`, el stack de red de Android considera inválida la configuración y **desconecta automáticamente la interfaz Wi-Fi**, dejando el dispositivo únicamente en red celular.

---

## 4. La Solución Técnica: Multi-Network Routing Nativo (Socket Binding)

Para permitir que la PDA mantenga su enlace a la nube vía datos móviles y, simultáneamente, se comunique con la impresora vía Wi-Fi sin adquirir un segundo plan de datos para el router, se implementó una **arquitectura de enlace de socket a nivel de interfaz de red (Socket Binding)** con las APIs nativas de Android (`ConnectivityManager` y `Network`).

```
                              ┌──────────────────────────────────────────────┐
                              │           PDA SUNMI L3 / ANDROID             │
                              │                                              │
                              │  ┌─────────────────┐    ┌─────────────────┐  │
                              │  │  API Supabase / │    │ PrintService    │  │
                              │  │  Backend Render │    │ (Paletizado)    │  │
                              │  └────────┬────────┘    └────────┬────────┘  │
                              └───────────┼──────────────────────┼───────────┘
                                          │                      │ MethodChannel
                                          │ Default Route        │ ("cl.cresal/printer_channel")
                                          │ (SO Android)         ▼
                              ┌───────────┼──────────┐  ┌────────────────────────────┐
                              │ Interfaz Celular     │  │ Android Native MainActivity│
                              │ rmnet_data0 (4G/5G)  │  │ ConnectivityManager        │
                              └───────────┬──────────┘  │ NetworkCallback(WIFI)      │
                                          │             │ network.bindSocket(socket) │
                                          │             └─────────────┬──────────────┘
                                          │                           │ Forzado por wlan0
                                          ▼                           ▼
                        ┌───────────────────────────┐   ┌────────────────────────────┐
                        │   Nube: Backend Render    │   │ Interfaz Wi-Fi Local       │
                        │   Base de Datos Supabase  │   │ wlan0 (192.168.8.X)        │
                        └───────────────────────────┘   └─────────────┬──────────────┘
                                                                      │ Wi-Fi 2.4 GHz
                                                                      ▼
                                                        ┌────────────────────────────┐
                                                        │ Router Huawei B320         │
                                                        │ Subred: 192.168.8.0/24     │
                                                        │ (Sin chip SIM / Sin WAN)   │
                                                        └─────────────┬──────────────┘
                                                                      │ Cable Ethernet RJ45
                                                                      ▼
                                                        ┌────────────────────────────┐
                                                        │ Impresora Honeywell PC42E-T│
                                                        │ IP: 192.168.8.50 : 9100    │
                                                        │ Emulación ZSim (ZPL II)    │
                                                        └────────────────────────────┘
```

### Mecanismo de Enlace en Kotlin
1. **Registro de Red Wi-Fi sin Exigencia de Internet**:  
   En `MainActivity.kt`, se registra un `NetworkCallback` solicitando `TRANSPORT_WIFI` y removiendo explícitamente `NET_CAPABILITY_INTERNET`:
   ```kotlin
   val request = NetworkRequest.Builder()
       .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
       .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
       .build()
   ```
2. **Creación y Enlace Forzado del Socket (`bindSocket`)**:  
   Antes de invocar `connect()`, el socket TCP se enlaza a la interfaz física de la red local:
   ```kotlin
   val socket = wifiNetwork.socketFactory.createSocket()
   wifiNetwork.bindSocket(socket)
   socket.connect(InetSocketAddress("192.168.8.50", 9100), timeoutMs)
   ```
   El kernel de Linux/Android ignora la ruta celular por defecto para este socket y transmite los bytes por la tarjeta `wlan0` directamente al switch del router Huawei y a la impresora.
3. **Persistencia de Conectividad Celular**:  
   Todas las peticiones HTTP/HTTPS (Dio, Supabase, Render) continúan viajando por la ruta predeterminada celular (4G/5G), logrando convivencia simultánea y transparente.

---

## 5. Protocolo de Diagnóstico y Flujo de Impresión

Para garantizar que un activo automotriz **no sea marcado como impreso (`qr_impreso = true`)** hasta que la etiqueta física haya salido del cabezal térmico, la aplicación ejecuta la siguiente secuencia obligatoria:

```
[Operador presiona "Imprimir Ahora" o "Confirmar e Imprimir"]
                         │
                         ▼
        1. Verificar conectividad Wi-Fi local
              ├── [Sin Red] ──> Modal: "Active el Wi-Fi en la PDA"
              │
              ▼ [Conectado]
        2. Apertura de Socket TCP (192.168.8.50:9100, Timeout: 2.5s)
              ├── [Timeout] ──> Modal: "Impresora apagada o cable desconectado"
              │
              ▼ [Socket Abierto]
        3. Envío de Comando de Diagnóstico: ~HS\r\n (Host Status)
              ├── [Tapa Abierta]    ──> Modal: "Cierre el cabezal de la impresora"
              ├── [Sin Papel]       ──> Modal: "Cargue rollo de etiquetas de 4x2"
              ├── [Sin Resina]      ──> Modal: "Cargue la cinta ribbon de resina"
              ├── [Pausada]         ──> Modal: "Presione Feed para reanudar"
              ├── [Sobrecalentada]  ──> Modal: "Espere enfriamiento del cabezal"
              │
              ▼ [TODAS LAS BANDERAS FÍSICAS OK]
        4. Ensamblaje de Trama ZPL II (ZplBuilder) y Transmisión de Bytes
              │
              ▼
        5. Flush y Cierre de Socket TCP
              │
              ▼
        6. PATCH al Backend: /api/v1/vehiculos/inventario/{id}/impreso -> qr_impreso = true
              │
              ▼
        7. SnackBar Verde en la PDA + Actualización Reactiva de Alertas
```

### Mapeo de Banderas Físicas ZPL II (`~HS`)
La Honeywell PC42E-T responde a `~HS` con una trama estructurada de 3 líneas delimitadas por STX (`0x02`) y ETX (`0x03`):

| Fallo Físico | Bandera / Posición en `~HS` | Excepción en Código | Acción Guiada para el Bodeguero |
| :--- | :---: | :--- | :--- |
| **Rollo Agotado** | Línea 1, posición 1 (`b == '1'`) | `PrinterPaperOutException` | Abra la tapa, inserte un rollo nuevo de 4x2'' y ajuste las guías verdes. |
| **Falta de Cinta / Resina** | Línea 2, posición 3 (`p == '1'`) | `PrinterRibbonOutException` | Instale un rollo de ribbon de resina y ténselo girando el carrete superior. |
| **Cabezal / Tapa Abierta** | Línea 2, posición 2 (`o == '1'`) | `PrinterHeadOpenException` | Presione la tapa superior hacia abajo en ambos lados hasta escuchar el clic. |
| **Impresora Pausada** | Línea 1, posición 2 (`c == '1'`) | `PrinterPausedException` | Presione el botón frontal de alimentación (Feed) para salir de pausa. |
| **Cabezal Sobrecalentado** | Línea 1, posición 11 (`l == '1'`) | `PrinterOverheatException` | Deje reposar el equipo encendido durante 60 segundos. |
| **Impresora Apagada / Desconectada** | Timeout del Socket (>2.5s) | `PrinterTimeoutException` | Verifique que la impresora esté encendida con luz verde y cable conectado. |
| **Wi-Fi PDA Apagado** | Fallo de interfaz local (`NO_WIFI`) | `PrinterNetworkException` | Conéctese a la red Wi-Fi del router de bodega. |

---

## 6. Implementación en Código Fuente

### Archivos Principales del Subsistema:
1. **`frontend/android/app/src/main/AndroidManifest.xml`**:  
   Declara permisos `INTERNET`, `ACCESS_NETWORK_STATE` y `CHANGE_NETWORK_STATE` requeridos por Android para callbacks de conectividad.
2. **`frontend/android/app/src/main/kotlin/com/example/frontend/MainActivity.kt`**:  
   Implementa `MethodChannel("cl.cresal/printer_channel")` con `consultarEstadoFisico` y `transmitirZpl`. Enlaza forzadamente los sockets mediante `network.bindSocket()` a la interfaz Wi-Fi activa sin requerir internet.
3. **`frontend/lib/features/paletizado/services/print_service.dart`**:  
   Servicio de impresión. Detecta plataforma (`Platform.isAndroid`) y delega al canal nativo. Contiene el decodificador defensivo `_decodificarBanderasHs` y el fallback a sockets `dart:io` para entornos de pruebas o escritorio.
4. **`frontend/lib/features/paletizado/domain/exceptions/printer_exceptions.dart`**:  
   Jerarquía de excepciones de dominio ricas en metadatos para UI (`titulo`, `instruccionOperativa`, `icono`).
5. **`frontend/lib/features/paletizado/presentation/widgets/dialogo_falla_impresora.dart`**:  
   Widget modal interactivo adaptado al Modo Oscuro del terminal. Muestra la instrucción correctiva guiada y ofrece los botones **"REINTENTAR"** y **"CANCELAR"**.
6. **`frontend/lib/features/paletizado/presentation/screens/etiqueta_preview_screen.dart`**:  
   Pantalla de previsualización e impresión. Invoca `PrintService` y orquesta el bucle guiado de reintentos.
7. **`frontend/lib/features/paletizado/presentation/screens/paletizado_screen.dart`**:  
   Modal de confirmación post-paletizado con botón **"Imprimir Ahora"** y soporte del diálogo de diagnósticos físicos.
8. **`frontend/lib/features/paletizado/services/zpl_builder.dart`**:  
   Generador de plantillas ZPL II para etiquetas térmicas de 4x2 pulgadas (812x406 dots @ 203 DPI) optimizadas para repuestos automotrices (Motores vs. Cajas de Cambio).

---

## 7. Guía de Configuración Operativa en Terminales Móviles (PDA Sunmi L3 y Celulares)

Esta configuración debe realizarse una sola vez por terminal:

### Paso 1: Configuración de la Red Wi-Fi
1. Encienda el Wi-Fi del terminal y conéctese a la red del router Huawei (ej. `HUAWEI_B320_D326`).
2. Mantenga la configuración IP en **DHCP (Automática)** *(el router ya cuenta con la reserva fija `.50` para la impresora)*.
3. Al conectarse, Android mostrará la notificación:  
   > *"Esta red Wi-Fi no tiene acceso a internet. ¿Desea mantener la conexión?"*
4. Marque la casilla **"No volver a preguntar para esta red"** y seleccione **"Sí / Mantener conexión permanentemente"**.

### Paso 2: Habilitar "Datos móviles siempre activos"
1. Vaya a **Ajustes** -> **Acerca del teléfono / PDA**.
2. Presione 7 veces seguidas sobre **"Número de compilación"** para habilitar las **Opciones de desarrollador**.
3. Ingrese a **Ajustes** -> **Sistema / Opciones de desarrollador**.
4. En la sección **Redes**, active la casilla:  
   * **"Datos móviles siempre activos"** (*Mobile data always active*).
5. En terminales Samsung, desactive **"Cambiar a datos móviles automáticamente"** (Red inteligente) dentro de los Ajustes de Wi-Fi Avanzado.

---

## 8. Procedimiento de Calibración Manual de la Impresora Honeywell PC42E-T

La Honeywell PC42E-T opera directamente por sockets RAW en el puerto 9100 y no requiere interfaz web. La calibración de sensores ópticos de etiquetas y cinta se efectúa mediante su botón físico frontal:

1. Apague la impresora desde el interruptor trasero.
2. Compruebe que el rollo de etiquetas de 4x2'' y la cinta de resina estén instalados y el cabezal trabado en ambos lados.
3. **Mantenga presionado el botón superior Feed** y encienda el equipo con el interruptor trasero sin soltar el botón.
4. Cuando el LED frontal comience a parpadear (aproximadamente 5 segundos), **suelte el botón Feed**.
5. La impresora avanzará de 2 a 3 etiquetas para calibrar el sensor óptico de separación (Gap) y quedará con luz **verde fija**, lista para operar.

---

## 9. Matriz de Validación y Pruebas Operativas

| Escenario de Prueba | Red Celular | Conexión Wi-Fi | Comportamiento del Sistema |
| :--- | :---: | :---: | :--- |
| **Operación Normal** | 4G/5G Activo | Conectado a Huawei | Consulta API Render por 4G y envía impresión por Wi-Fi de forma transparente en menos de 1 segundo. |
| **Wi-Fi Apagado en PDA** | 4G/5G Activo | Desconectado | Modal interactivo inmediato: *"Active el Wi-Fi en la PDA y conéctese a la red de bodega"*. Botón Reintentar. |
| **Impresora Apagada** | 4G/5G Activo | Conectado a Huawei | Tras 2.5s de timeout, modal interactivo: *"Impresora apagada o cable desconectado"*. Permite encenderla y reintentar. |
| **Cabezal / Tapa Abierta** | 4G/5G Activo | Conectado a Huawei | Comando `~HS` detecta `o=1`. Modal guiado: *"Cierre el cabezal de la impresora"*. |
| **Rollo de Etiquetas Agotado** | 4G/5G Activo | Conectado a Huawei | Comando `~HS` detecta `b=1`. Modal guiado: *"Cargue rollo de etiquetas de 4x2 pulgadas"*. |
| **Falta de Cinta / Resina** | 4G/5G Activo | Conectado a Huawei | Comando `~HS` detecta `p=1`. Modal guiado: *"Cargue la cinta ribbon de resina"*. |
