// lib/features/paletizado/services/print_service.dart
//
// Módulo de Impresión Industrial para Honeywell PC42E-T vía Sockets TCP (Puerto Raw 9100).
//
// ARQUITECTURA: Clean Architecture / Feature-First
// Fase 1: Infraestructura de Red, Conexión TCP y Control de Excepciones.
// Fase 2: Diagnóstico de Salud Físico (Health Check con ~HS y Decodificador ZPL II).
// Fase 3: Ensamblaje ZPL Dinámico (Motor vs. Caja) y Transmisión de Bytes.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../domain/exceptions/printer_exceptions.dart';
import '../domain/models/etiqueta_data.dart';
import 'zpl_builder.dart';

/// Servicio de infraestructura para comunicación directa TCP con impresora térmica industrial.
class PrintService {
  // Configuración de red por defecto (IP Estática y Puerto Raw JetDirect)
  static const String defaultPrinterIp = '192.168.1.50';
  static const int defaultPrinterPort = 9100;
  static const Duration timeoutConexion = Duration(seconds: 3);
  static const Duration timeoutDiagnostico = Duration(seconds: 2);

  /// Valida de forma nativa si el dispositivo tiene interfaces de red activas.
  static Future<void> _verificarConexionRed() async {
    debugPrint('📌 [PRINT_SERVICE] 📶 Verificando interfaces de red locales...');
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      if (interfaces.isEmpty) {
        debugPrint('📌 [PRINT_SERVICE] ❌ No se detectaron interfaces de red activas (Wi-Fi desconectado).');
        throw const PrinterNetworkException();
      }

      debugPrint(
        '📌 [PRINT_SERVICE] 📶 Red disponible. Interfaces activas: ${interfaces.map((i) => i.name).join(", ")}',
      );
    } on SocketException catch (e) {
      debugPrint('📌 [PRINT_SERVICE] ❌ Fallo al consultar interfaces de red: $e');
      throw PrinterNetworkException('Fallo al validar conexión de red local.', e);
    }
  }

  /// Intenta abrir un Socket TCP directo hacia la impresora con timeout estricto de 3 segundos.
  static Future<Socket> _conectarSocket(String ip, int port) async {
    debugPrint('📌 [PRINT_SERVICE] 🔌 Intentando conectar a la impresora en $ip:$port (Timeout: ${timeoutConexion.inSeconds}s)...');
    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: timeoutConexion,
      );
      debugPrint('📌 [PRINT_SERVICE] 🟢 Conexión TCP establecida exitosamente con $ip:$port');
      return socket;
    } on SocketException catch (e) {
      debugPrint('📌 [PRINT_SERVICE] ❌ SocketException al conectar con $ip:$port -> $e');
      throw PrinterTimeoutException(
        ip,
        port,
        'No se pudo establecer conexión TCP con la impresora térmica.',
        e,
      );
    } on TimeoutException catch (e) {
      debugPrint('📌 [PRINT_SERVICE] ⏳ TimeoutException (${timeoutConexion.inSeconds}s) agotado con $ip:$port -> $e');
      throw PrinterTimeoutException(
        ip,
        port,
        'Tiempo de espera agotado (${timeoutConexion.inSeconds}s). Impresora apagada o fuera de red.',
        e,
      );
    } catch (e) {
      debugPrint('📌 [PRINT_SERVICE] ❌ Error inesperado al abrir socket TCP -> $e');
      throw PrinterCommunicationException(
        'Error inesperado al conectar con la impresora',
        e,
      );
    }
  }

  /// Envía el comando ZPL ~HS (Host Status) a la impresora y decodifica las banderas físicas.
  ///
  /// Lanza [PrinterPaperOutException] si detecta falta de papel, tapa/cabezal abierto o falta de ribbon.
  /// Lanza [PrinterCommunicationException] si la impresora está en pausa o responde con error.
  static Future<void> _verificarEstadoFisico(Socket socket) async {
    debugPrint('📌 [PRINT_SERVICE] 🩺 [FASE 2] Enviando comando de diagnóstico (~HS)...');

    final completer = Completer<String>();
    final buffer = StringBuffer();
    StreamSubscription<Uint8List>? subscription;

    // Timeout de seguridad de 2 segundos para la respuesta del socket
    final timer = Timer(timeoutDiagnostico, () {
      if (!completer.isCompleted) {
        debugPrint('📌 [PRINT_SERVICE] ⏱️ Timeout esperando respuesta de ~HS. Continuando con buffer acumulado...');
        completer.complete(buffer.toString());
      }
    });

    try {
      subscription = socket.listen(
        (data) {
          final chunk = utf8.decode(data, allowMalformed: true);
          buffer.write(chunk);

          final rawContent = buffer.toString();
          // Si ya tenemos el delimitador de cierre ETX (0x03) o al menos 3 líneas de estado
          if (rawContent.contains('\x03') || rawContent.split('\n').length >= 3) {
            if (!completer.isCompleted) {
              timer.cancel();
              completer.complete(rawContent);
            }
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            timer.cancel();
            completer.completeError(
              PrinterCommunicationException('Error en socket al leer estado físico (~HS)', error),
            );
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            timer.cancel();
            completer.complete(buffer.toString());
          }
        },
        cancelOnError: true,
      );

      // Enviamos el comando de solicitud de estado (~HS\r\n)
      socket.write('~HS\r\n');
      await socket.flush();

      // Esperamos la respuesta decodificada
      final rawResponse = await completer.future;
      timer.cancel();

      debugPrint('📌 [PRINT_SERVICE] 🩺 [FASE 2] Trama cruda devuelta por la máquina (~HS):\n$rawResponse');

      if (rawResponse.trim().isEmpty) {
        debugPrint('📌 [PRINT_SERVICE] ⚠️ Impresora no devolvió respuesta a ~HS. Se continuará con precaución.');
        return;
      }

      // ── Parser Defensivo ZPL II ──
      // Limpiamos caracteres STX (0x02), ETX (0x03) y retornos de carro
      final lineas = rawResponse
          .replaceAll('\x02', '') // STX
          .replaceAll('\x03', '') // ETX
          .replaceAll('\r', '')
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      debugPrint('📌 [PRINT_SERVICE] 🩺 Líneas parseadas de ~HS: $lineas');

      // ── Evaluación Línea 1: <STX>aaa,b,c,dddd,e,f,g,h,iii,j,k,l<ETX> ──
      if (lineas.isNotEmpty) {
        final camposLinea1 = lineas[0].split(',');
        // Bandera 'b' (Posición 1): Paper Out (0=OK, 1=Sin Papel)
        if (camposLinea1.length > 1) {
          final paperOutFlag = camposLinea1[1].trim();
          if (paperOutFlag == '1') {
            debugPrint('📌 [PRINT_SERVICE] ❌ Alerta física detectada: Paper Out (b=1).');
            throw const PrinterPaperOutException(
              'La impresora no tiene papel térmico. Por favor, cargue un nuevo rollo.',
            );
          }
        }
        // Bandera 'c' (Posición 2): Pause (0=Normal, 1=Pausada)
        if (camposLinea1.length > 2) {
          final pauseFlag = camposLinea1[2].trim();
          if (pauseFlag == '1') {
            debugPrint('📌 [PRINT_SERVICE] ⚠️ Alerta física detectada: Impresora Pausada (c=1).');
            throw const PrinterCommunicationException(
              'La impresora se encuentra pausada. Presione el botón de reanudar en el equipo.',
            );
          }
        }
      }

      // ── Evaluación Línea 2: <STX>mmm,n,o,p,q,r,s,t,uuuu,v,www<ETX> ──
      if (lineas.length > 1) {
        final camposLinea2 = lineas[1].split(',');
        // Bandera 'o' (Posición 2): Head Open (0=Cerrado, 1=Abierto)
        if (camposLinea2.length > 2) {
          final headOpenFlag = camposLinea2[2].trim();
          if (headOpenFlag == '1') {
            debugPrint('📌 [PRINT_SERVICE] ❌ Alerta física detectada: Head Open / Tapa abierta (o=1).');
            throw const PrinterPaperOutException(
              'La tapa o cabezal de la impresora se encuentra abierta. Ciérrela para continuar.',
            );
          }
        }
        // Bandera 'p' (Posición 3): Ribbon Out (0=OK, 1=Sin Cinta)
        if (camposLinea2.length > 3) {
          final ribbonOutFlag = camposLinea2[3].trim();
          if (ribbonOutFlag == '1') {
            debugPrint('📌 [PRINT_SERVICE] ❌ Alerta física detectada: Ribbon Out (p=1).');
            throw const PrinterPaperOutException(
              'Falta de cinta térmica (Ribbon Out) detectada en la impresora.',
            );
          }
        }
      }

      debugPrint('📌 [PRINT_SERVICE] 🟢 [FASE 2] Diagnóstico físico OK: Papel cargado y cabezal cerrado.');
    } finally {
      await subscription?.cancel();
    }
  }

  /// Ejecuta la secuencia de impresión térmica para el activo proporcionado en [data].
  ///
  /// Fases ejecutadas:
  /// - Fase 1: Validación de red local y apertura de Socket TCP.
  /// - Fase 2: Diagnóstico físico de salud (~HS).
  /// - Fase 3: Ensamblaje ZPL dinámico y transmisión de bytes al cabezal.
  static Future<bool> imprimirEtiqueta(
    EtiquetaData data, {
    String printerIp = defaultPrinterIp,
    int printerPort = defaultPrinterPort,
  }) async {
    debugPrint('📌 [PRINT_SERVICE] 🖨️ [FASE 3] Iniciando secuencia de impresión industrial...');
    debugPrint(
      '📌 [PRINT_SERVICE] 📦 Activo: ${data.skuQrFisico} | Folio: ${data.numeroIngreso}',
    );
    debugPrint(
      '📌 [PRINT_SERVICE] 📍 Ubicación: G:${data.galpon} / P:${data.pasillo} / Pa:${data.pallet}',
    );

    Socket? socket;
    try {
      // 1. Verificación de conectividad local (Wi-Fi)
      await _verificarConexionRed();

      // 2. Conexión TCP con timeout estricto de 3 segundos
      socket = await _conectarSocket(printerIp, printerPort);

      // 3. Health Check Físico (Fase 2): Envío de ~HS y validación de flags
      await _verificarEstadoFisico(socket);

      // 4. Ensamblaje ZPL Dinámico (Fase 3)
      debugPrint('📌 [PRINT_SERVICE] 🏗️ [FASE 3] Ensamblando plantilla ZPL para SKU: ${data.skuQrFisico}...');
      final tramaZpl = ZplBuilder.buildEtiquetaActivo(data);
      debugPrint('📌 [PRINT_SERVICE] 📄 Vista previa ZPL generado:\n$tramaZpl');

      // 5. Transmisión de Bytes por Socket TCP
      debugPrint('📌 [PRINT_SERVICE] ⚡ [FASE 3] Transmitiendo bytes UTF-8 al búfer de la Honeywell...');
      socket.add(utf8.encode(tramaZpl));
      await socket.flush();

      debugPrint('📌 [PRINT_SERVICE] ✅ [FASE 3] Etiqueta transmitida con éxito. Impresión física en curso.');
      return true;
    } on PrinterException catch (e) {
      debugPrint('📌 [PRINT_SERVICE] ❌ Excepción de dominio capturada: $e');
      rethrow;
    } catch (e) {
      debugPrint('📌 [PRINT_SERVICE] ❌ Excepción imprevista en servicio: $e');
      throw PrinterCommunicationException('Error general en el proceso de impresión', e);
    } finally {
      if (socket != null) {
        try {
          await socket.flush();
          await socket.close();
          socket.destroy();
          debugPrint('📌 [PRINT_SERVICE] 🔒 Socket TCP cerrado y recursos liberados.');
        } catch (e) {
          debugPrint('📌 [PRINT_SERVICE] ⚠️ Error al cerrar socket: $e');
        }
      }
    }
  }
}
