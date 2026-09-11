# Arquitectura de Impresión Térmica Industrial en Bodega (Cresal SaaS)

Este documento detalla la arquitectura de hardware, topología de red, direccionamiento IP, protocolo de comunicación por Sockets TCP y manejo de diagnósticos físicos para la estación de impresión de etiquetas QR en bodega.

---

## 1. Dispositivos Involucrados

| Dispositivo | Rol en el Sistema | Interfaz de Conexión | Dirección IP / Puerto |
| :--- | :--- | :--- | :--- |
| **Impresora Honeywell PC42E-T** | Impresora térmica industrial (ZPL II / ZSim, 203 DPI, Ribbon de Resina). | Cable Ethernet RJ45 (Fast Ethernet 100 Mbps) | **`192.168.8.50`** : Puerto TCP **`9100`** |
| **Router Huawei B320 (CPE 4G)** | Puerta de enlace local y punto de acceso Wi-Fi 2.4 GHz. | Ethernet LAN (Puente `br-lan`) + Wi-Fi 802.11 b/g/n | **`192.168.8.1`** (Gateway) |
| **PDA Sunmi L3** | Terminal móvil rugerizada para el Bodeguero (Android). | Wi-Fi 2.4 GHz (LAN) + SIM 4G Móvil (WAN) | Dinámica DHCP (`192.168.8.X`) |

*(Nota: En caso de utilizar el router industrial Teltonika RUT240 en lugar del Huawei, la subred correspondiente es `192.168.1.0/24`, asignando `192.168.1.1` al router y `192.168.1.50` a la impresora).*

---

## 2. Topología de Red y Flujo de Tráfico

```
                        [ Nube: Supabase / Backend API ]
                                       ▲
                                       │ (4G Datos Móviles de la PDA)
                                       ▼
                             ┌───────────────────┐
                             │   PDA Sunmi L3    │
                             │ (Operador Bodega) │
                             │ IP: 192.168.8.X   │
                             └─────────┬─────────┘
                                       │
                                       │ Wi-Fi 2.4 GHz (SSID: HUAWEI_B320_D326)
                                       ▼
                             ┌───────────────────┐
                             │ Router Huawei B320│
                             │ Gateway:          │
                             │ 192.168.8.1 /24   │
                             │ Bridge: br-lan    │
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

### Comportamiento Híbrido de la PDA Sunmi L3 (Dual-Homing y Multi-Network Routing)
1. **Tráfico WAN (Internet)**: La PDA consulta y actualiza el inventario en Supabase y el backend en Render mediante su conexión de **datos móviles 4G/5G**.
2. **Tráfico LAN (Impresión Local por Socket Binding)**: Al momento de imprimir, la aplicación utiliza un canal nativo en Android (`cl.cresal/printer_channel`) que enlaza forzadamente el socket TCP a la interfaz Wi-Fi (`wlan0`) mediante `network.bindSocket()`. De este modo, los paquetes se transmiten a través del router Huawei hacia la Honeywell en `192.168.8.50:9100` **sin perder el acceso a internet celular ni conmutar de red**.
3. **Regla de Android para Wi-Fi sin Internet**: Cuando la PDA se conecta al Wi-Fi del router (que no dispone de chip SIM), Android preguntará: *"Esta red Wi-Fi no tiene acceso a internet. ¿Desea mantener la conexión?"*. Se debe marcar **"Sí / Mantener conexión permanentemente"** y verificar en opciones de desarrollo que la opción **"Datos móviles siempre activos"** (*Mobile data always active*) esté habilitada.
*(Para una explicación técnica profunda a nivel de kernel y sockets, ver [ARQUITECTURA_MULTI_RED_WIFI_DATOS.md](file:///c:/proyectos/CresalRepoCapstone/ARQUITECTURA_MULTI_RED_WIFI_DATOS.md)).*

---

## 3. Direccionamiento IP, Seguridad de la MAC y Puertos

### ¿Por qué se usa la IP `192.168.8.50`?
- Los routers domésticos y comerciales asignan direcciones por DHCP dinámico a teléfonos y laptops en el rango medio/alto (`.100` al `.200`).
- Si la impresora utilizara DHCP dinámico sin reserva, cada vez que se reinicie podría cambiar de IP (ej. de `.102` a `.108`), haciendo que la aplicación pierda conectividad.
- Se selecciona una **IP estática baja (`.50`)** mediante **Reserva DHCP (Static Lease)** en el router. La impresora continúa operando en DHCP automático, pero el router siempre le entrega la IP `.50` al reconocer su identificador de hardware.

### Seguridad sobre la Dirección MAC (`0C:23:69:FA:89:3F`)
- **¿Es seguro documentar la dirección MAC?**  
  **Sí, es completamente seguro.** La dirección MAC es un identificador de hardware físico de Capa 2 (Enlace de Datos) que **únicamente tiene validez dentro del cable y del router local**. No es accesible ni enrutable desde internet. Documentarla en este manual es una necesidad operativa para que el equipo de soporte técnico pueda configurar o reponer el router ante cualquier fallo de hardware.

### ¿Por qué el Puerto TCP 9100?
- El puerto **9100** es el estándar mundial **Raw TCP / JetDirect** para impresoras industriales.
- Todo byte transmitido en este puerto es recibido directamente por el procesador térmico de la Honeywell (emulación ZSim / ZPL II).
- Permite comunicación bidireccional inmediata: la PDA envía comandos de diagnóstico (`~HS`) y la Honeywell responde con el estado de sus sensores en tiempo real sin requerir controladores o servidores de impresión intermedios.

---

## 4. Protocolo de Diagnóstico y Detección de Fallos Físicos

Para garantizar que el activo **no sea marcado como impreso (`qr_impreso = true`)** hasta que la etiqueta salga físicamente del cabezal, la aplicación ejecuta una secuencia de validación previa obligatoria:

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
        7. SnackBar Verde en la PDA + Actualización de Alertas
```

### Mapeo de Banderas ZPL II (`~HS`)

La Honeywell PC42E-T responde al comando `~HS` con una trama estructurada de 3 líneas delimitadas por caracteres STX (`0x02`) y ETX (`0x03`):

| Fallo Físico | Bandera / Posición en `~HS` | Excepción en Código | Acción Guiada para el Bodeguero |
| :--- | :---: | :--- | :--- |
| **Rollo Agotado** | Línea 1, posición 1 (`b == '1'`) | `PrinterPaperOutException` | Abra la tapa, inserte un rollo nuevo de 4x2'' y ajuste las guías verdes. |
| **Falta de Cinta / Resina** | Línea 2, posición 3 (`p == '1'`) | `PrinterRibbonOutException` | Instale un rollo de ribbon de resina y ténselo girando el carrete superior. |
| **Cabezal / Tapa Abierta** | Línea 2, posición 2 (`o == '1'`) | `PrinterHeadOpenException` | Presione la tapa superior hacia abajo en ambos lados hasta escuchar el clic. |
| **Impresora Pausada** | Línea 1, posición 2 (`c == '1'`) | `PrinterPausedException` | Presione el botón frontal de alimentación (Feed) para salir de pausa. |
| **Cabezal Sobrecalentado** | Línea 1, posición 11 (`l == '1'`) | `PrinterOverheatException` | Deje reposar el equipo encendido durante 60 segundos. |
| **Impresora Apagada / Desconectada** | Timeout del Socket (>2.5s) | `PrinterTimeoutException` | Verifique que la impresora esté encendida con luz verde y cable conectado. |
| **Wi-Fi PDA Apagado** | Fallo en interfaz local | `PrinterNetworkException` | Conéctese a la red Wi-Fi del router de bodega. |

---

## 5. Implementación en Código Fuente

### Archivos Principales del Subsistema:
1. **`frontend/lib/features/paletizado/domain/exceptions/printer_exceptions.dart`**:  
   Jerarquía de excepciones de dominio ricas en metadatos para UI (`titulo`, `instruccionOperativa`, `icono`).
2. **`frontend/lib/features/paletizado/services/print_service.dart`**:  
   Servicio de infraestructura de impresión. En Android conmuta automáticamente al canal nativo `cl.cresal/printer_channel` para enlace de socket sobre Wi-Fi, manteniendo compatibilidad con sockets TCP estándar `dart:io` para otras plataformas. Contiene el decodificador ZPL II defensivo (`~HS`).
3. **`frontend/android/app/src/main/kotlin/com/example/frontend/MainActivity.kt`**:  
   Capa nativa Android con `ConnectivityManager`. Registra la interfaz Wi-Fi sin exigir internet y ejecuta `network.bindSocket()` para forzar el tráfico hacia la Honeywell en `192.168.8.50:9100` sin interrumpir la conexión de datos móviles a Render.
4. **`frontend/lib/features/paletizado/presentation/widgets/dialogo_falla_impresora.dart`**:  
   Widget modal de alerta interactivo adaptado al Modo Oscuro de la terminal PDA. Muestra la instrucción correctiva y ofrece los botones **"REINTENTAR"** y **"CANCELAR"**.
5. **`frontend/lib/features/paletizado/presentation/screens/etiqueta_preview_screen.dart`**:  
   Pantalla de previsualización e impresión de tarjeta. Elimina el mock de simulación, ejecuta la llamada real a `PrintService` y gestiona el bucle interactivo de reintentos.
6. **`frontend/lib/features/paletizado/presentation/screens/paletizado_screen.dart`**:  
   Modal de confirmación post-paletizado. Integra el botón **"Imprimir Ahora"** con el mismo diálogo guiado de diagnóstico físico.
7. **`frontend/lib/features/paletizado/services/zpl_builder.dart`**:  
   Generador de plantillas ZPL para etiquetas térmicas de 4x2 pulgadas (812x406 dots @ 203 DPI) calibradas para repuestos automotrices (Motores vs. Cajas de Cambio).

---

## 6. Procedimiento de Calibración Manual de la Impresora

La Honeywell PC42E-T es un modelo desktop compacto cuyo microcontrolador opera directamente por sockets y no requiere interfaz web HTTP. La calibración de sensores ópticos de etiquetas y ribbon se realiza con el botón físico frontal:

1. Apague la impresora desde el interruptor trasero.
2. Verifique que el rollo de etiquetas 4x2'' y la cinta de resina estén colocados y el cabezal trabado.
3. **Mantenga presionado el botón superior Feed** y encienda la impresora con el interruptor trasero sin soltar el botón.
4. Cuando el LED frontal comience a parpadear (aproximadamente 5 segundos), **suelte el botón Feed**.
5. La impresora avanzará automáticamente 2 a 3 etiquetas para calibrar el sensor de separación (Gap) y quedará con luz **verde fija**, lista para imprimir.
