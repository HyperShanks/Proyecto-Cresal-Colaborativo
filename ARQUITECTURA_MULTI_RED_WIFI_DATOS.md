# Arquitectura Multi-Red: Wi-Fi Local + Datos Móviles Simultáneos (Dual-Homing)

Este documento detalla la solución técnica de **enrutamiento multi-red a nivel de socket (Multi-Network Routing)** implementada para permitir que la terminal PDA Sunmi L3 (y dispositivos Android como Samsung Galaxy) mantenga acceso continuo a internet (Supabase y Backend en Render vía Datos Móviles 4G/5G) y, al mismo tiempo, envíe impresiones industriales y consulte diagnósticos físicos en la impresora Honeywell PC42E-T conectada a un router local Huawei sin tarjeta SIM vía Wi-Fi.

---

## 1. Diagnóstico del Problema: ¿Por qué fallaba la conexión simultánea?

### El Escenario Físico en Bodega
1. **Terminal Móvil (PDA Sunmi L3 / Samsung S26 Ultra)**: Contiene un chip SIM con plan de datos móviles para comunicarse con la nube (Render API y Supabase).
2. **Impresora Térmica (Honeywell PC42E-T)**: Conectada por cable de red Ethernet RJ45 al router local de bodega con IP estática reservada **`192.168.8.50`** en el puerto TCP **`9100`**.
3. **Router de Bodega (Huawei B320 CPE 5s / Teltonika RUT240)**: Actúa como switch/puente Ethernet y punto de acceso Wi-Fi local en la subred `192.168.8.0/24`. **No dispone de chip SIM ni salida a internet**.

### La Limitación de Android y Flutter Estándar
- **Comportamiento del Sistema Operativo Android**:
  Cuando un dispositivo Android se conecta a una red Wi-Fi, el sistema operativo realiza una prueba de sondeo HTTP (`generate_204` o sondeo de portal cautivo). Al notar que el router Huawei no responde hacia internet, Android clasifica la red como **Wi-Fi sin internet** (`NET_CAPABILITY_VALIDATED` ausente).
  Para evitar que el usuario pierda conectividad con WhatsApp, correo o aplicaciones en la nube, el kernel de Android asigna la **Ruta por Defecto (Gateway Default `0.0.0.0/0`) a la interfaz de Datos Móviles (4G/5G)**.
- **La Limitación de Dart (`dart:io` `Socket.connect`)**:
  Flutter/Dart utiliza llamadas POSIX estándar del sistema operativo para abrir sockets TCP. Cuando se ejecuta `Socket.connect('192.168.8.50', 9100)`:
  1. Dart no tiene visibilidad para elegir la interfaz de red física (`wlan0` vs `rmnet_data0`).
  2. El kernel de Android evalúa la tabla de rutas global y, dado que la prioridad la tienen los datos móviles, intenta enrutar el socket hacia la red celular de la compañía telefónica.
  3. La red celular no reconoce la IP privada `192.168.8.50`, produciendo de inmediato un error `Network is unreachable`, `No route to host` o un `SocketTimeoutException` tras 2.5 segundos.
- **Por qué fallaron los intentos manuales de Gateway/DNS en 0.0.0.0**:
  Si en los ajustes del teléfono se configura una IP estática con Gateway `0.0.0.0` o DNS `0.0.0.0`, el stack de red de Android considera que la configuración es inválida y directamente **desconecta o desactiva la interfaz Wi-Fi**, provocando que el dispositivo quede únicamente en 5G sin ninguna posibilidad de hablar con el router Huawei.

---

## 2. La Solución Técnica: Multi-Network Routing Nativo

Para resolver este conflicto sin necesidad de comprar un segundo plan de datos para el router, se implementó una **arquitectura de enlace de socket a nivel de interfaz de red (Socket Binding)** aprovechando las APIs nativas de Android (`android.net.ConnectivityManager` y `android.net.Network`).

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

### ¿Cómo Funciona el Enlace Nativo?
1. **Registro de Red Wi-Fi sin Exigencia de Internet**:
   En Kotlin, se registra un `NetworkCallback` mediante `NetworkRequest.Builder()` especificando `TRANSPORT_WIFI` y removiendo explícitamente el requisito `NET_CAPABILITY_INTERNET`:
   ```kotlin
   val request = NetworkRequest.Builder()
       .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
       .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
       .build()
   ```
   Esto le indica a Android: *"Mantén la referencia al objeto `Network` del Wi-Fi incluso si no tiene salida a internet"*.
2. **Creación y Enlace Forzado del Socket (`bindSocket`)**:
   Antes de llamar a `connect()`, el socket TCP se asocia directamente a la interfaz física de la red local:
   ```kotlin
   val socket = wifiNetwork.socketFactory.createSocket()
   wifiNetwork.bindSocket(socket)
   socket.connect(InetSocketAddress("192.168.8.50", 9100), timeoutMs)
   ```
   Al hacer esto, el kernel de Linux/Android **ignora la ruta por defecto (datos móviles)** para ese socket específico y transmite los paquetes a través de la tarjeta `wlan0` directamente al switch del router Huawei y a la Honeywell PC42E-T.
3. **Persistencia de Datos Móviles**:
   Todo el resto del tráfico HTTP/HTTPS de la aplicación (solicitudes Dio, Supabase, Render) sigue utilizando la ruta predeterminada del sistema operativo (datos móviles 4G/5G), logrando una **convivencia perfecta y simultánea sin cortes ni conmutaciones manuales**.

---

## 3. Archivos y Cambios Implementados

### A. Permisos en `frontend/android/app/src/main/AndroidManifest.xml`
Se añadieron los permisos requeridos por Android para consultar el estado de las interfaces de red y gestionar callbacks de red:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />
```

### B. Implementación Nativa en `frontend/android/app/src/main/kotlin/com/example/frontend/MainActivity.kt`
- Registra el `ConnectivityManager.NetworkCallback` con `TRANSPORT_WIFI` y `TRANSPORT_ETHERNET` (para soporte de cunas de carga Sunmi con puerto Ethernet).
- Implementa el `MethodChannel("cl.cresal/printer_channel")` con dos métodos:
  1. **`consultarEstadoFisico`**: Abre el socket enlazado a Wi-Fi, envía el comando `~HS\r\n` (Host Status), lee la respuesta del microcontrolador de la Honeywell y devuelve la cadena cruda a Flutter.
  2. **`transmitirZpl`**: Abre el socket enlazado a Wi-Fi, transmite la trama de bytes ZPL UTF-8 al búfer de impresión y confirma la entrega.
- Manejo defensivo de excepciones:
  - Si el dispositivo no está conectado a la red Wi-Fi de bodega, retorna de inmediato el código de error `"NO_WIFI"`.
  - Si la impresora está apagada o el cable desconectado, captura `SocketTimeoutException` o `ConnectException` y retorna `"TIMEOUT"` o `"CONNECT_ERROR"`.

### C. Refactorización en `frontend/lib/features/paletizado/services/print_service.dart`
- **Detección de Plataforma Dinámica**:
  - En Android (`Platform.isAndroid`), invoca el canal nativo `_channel.invokeMethod` para garantizar el enrutamiento por Wi-Fi sin tocar los datos móviles.
  - En otras plataformas (pruebas unitarias, emuladores de escritorio, iOS), utiliza automáticamente el fallback con sockets estándar `dart:io`.
- **Decodificador Centralizado de Banderas Físicas (`_decodificarBanderasHs`)**:
  Procesa las 3 líneas de estado de ZPL II (`~HS`) y mapea los bits a las excepciones de dominio con instrucciones operativas para el bodeguero:
  * Bandera `b == '1'`: Falta de papel (`PrinterPaperOutException`).
  * Bandera `p == '1'`: Falta de cinta/ribbon (`PrinterRibbonOutException`).
  * Bandera `o == '1'`: Cabezal abierto (`PrinterHeadOpenException`).
  * Bandera `c == '1'`: Impresora pausada (`PrinterPausedException`).
  * Bandera `l == '1'`: Sobrecalentamiento (`PrinterOverheatException`).
- **Mapeo de Errores de Red**:
  * Código `"NO_WIFI"` -> `PrinterNetworkException` (despliega diálogo modal: *"Active el Wi-Fi en la PDA y conéctese a la red de bodega"*).
  * Códigos `"TIMEOUT"` / `"CONNECT_ERROR"` -> `PrinterTimeoutException` (despliega diálogo modal: *"Impresora apagada o fuera de red"*).

---

## 4. Guía de Configuración Operativa en la PDA Sunmi L3 y Celulares

Para que el dispositivo opere de forma óptima en el día a día, se debe realizar esta configuración por única vez en el terminal:

### Paso 1: Configurar la Conexión Wi-Fi
1. Encienda el Wi-Fi del terminal y conéctese a la red del router Huawei (ej. `HUAWEI_B320_D326`).
2. Mantenga la configuración IP en **DHCP (Automática)**. *(El router ya tiene configurada la reserva estática para la impresora en `192.168.8.50`)*.
3. Al conectarse, Android mostrará una notificación del sistema:
   > *"Esta red Wi-Fi no tiene acceso a internet. ¿Desea mantener la conexión?"*
4. Marque la casilla **"No volver a preguntar para esta red"** y presione **"Sí / Mantener conexión"**.

### Paso 2: Habilitar "Datos móviles siempre activos"
1. Vaya a **Ajustes** -> **Acerca del teléfono / Acerca de la PDA**.
2. Presione 7 veces seguidas sobre **"Número de compilación"** para activar las **Opciones de desarrollador**.
3. Ingrese a **Ajustes** -> **Sistema / Opciones de desarrollador**.
4. Busque la sección **Redes** y active la casilla:
   * **"Datos móviles siempre activos"** (*Mobile data always active* / *Mantener datos móviles encendidos incluso cuando el Wi-Fi esté conectado*).
5. En terminales Samsung, asegúrese de desactivar **"Cambiar a datos móviles automáticamente"** (Red inteligente) dentro de Ajustes de Wi-Fi Avanzado.

---

## 5. Matriz de Validación y Diagnóstico de Errores

| Escenario de Prueba | Estado de Red Móvil | Estado de Wi-Fi | Comportamiento del Sistema |
| :--- | :---: | :---: | :--- |
| **Operación Normal** | 4G/5G Activo | Conectado a Huawei | Consulta API Render por 4G y envía impresión por Wi-Fi de forma transparente en menos de 1 segundo. |
| **Wi-Fi Apagado en PDA** | 4G/5G Activo | Desconectado | Modal interactivo inmediato: *"Active el Wi-Fi en la PDA y conéctese a la red de bodega"*. Botón Reintentar. |
| **Impresora Apagada** | 4G/5G Activo | Conectado a Huawei | Tras 2.5s, modal interactivo: *"Impresora apagada o cable desconectado"*. Permite encenderla y pulsar Reintentar. |
| **Tapa de Impresora Abierta** | 4G/5G Activo | Conectado a Huawei | El comando `~HS` detecta `o=1`. Modal guiado: *"Cierre el cabezal de la impresora"*. |
| **Falta de Rollo de Etiquetas**| 4G/5G Activo | Conectado a Huawei | El comando `~HS` detecta `b=1`. Modal guiado: *"Cargue rollo de etiquetas de 4x2 pulgadas"*. |
| **Falta de Cinta de Resina**  | 4G/5G Activo | Conectado a Huawei | El comando `~HS` detecta `p=1`. Modal guiado: *"Cargue la cinta ribbon de resina"*. |
