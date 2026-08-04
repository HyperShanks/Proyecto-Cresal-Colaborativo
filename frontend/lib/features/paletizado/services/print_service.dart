// lib/features/paletizado/services/print_service.dart
//
// HU-2.4 — Servicio de impresión Bluetooth (stub).
//
// ARQUITECTURA: Este servicio actúa como el "puerto" de salida (Clean Architecture)
// entre la lógica de negocio y el hardware de impresión.
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  PUNTO DE INYECCIÓN BLUETOOTH (FUTURO)                                  │
// │                                                                         │
// │  Para conectar una impresora térmica real, instalar el paquete:         │
// │    flutter_blue_plus: ^1.x.x  (o print_bluetooth_thermal, etc.)        │
// │                                                                         │
// │  Pasos de integración:                                                  │
// │  1. Agregar el paquete a pubspec.yaml                                   │
// │  2. Declarar permisos en AndroidManifest.xml:                           │
// │       BLUETOOTH, BLUETOOTH_ADMIN, BLUETOOTH_CONNECT, BLUETOOTH_SCAN    │
// │  3. Reemplazar el cuerpo de `imprimirEtiqueta()` con:                   │
// │       a. Escaneo de dispositivos BT                                     │
// │       b. Pairing y conexión al StreamSocket                             │
// │       c. Serialización de la etiqueta a ESC/POS o ZPL                   │
// │       d. Escritura de bytes al socket                                   │
// │  4. El resto de la aplicación NO necesita cambios: solo este archivo.   │
// └─────────────────────────────────────────────────────────────────────────┘

import 'package:flutter/foundation.dart';
import '../domain/models/etiqueta_data.dart';

/// Servicio de impresión. Actualmente es un stub que simula la conexión.
/// Cuando se integre el hardware real, SOLO este archivo cambia.
class PrintService {
  /// Simula la conexión a una impresora Bluetooth y el envío de la etiqueta.
  ///
  /// [data] : Los datos del activo a imprimir en la etiqueta térmica.
  ///
  /// FUTURO: Aquí se inyectará `flutter_blue_plus` para la impresión real.
  /// Ver el bloque de documentación al inicio de este archivo.
  static Future<void> imprimirEtiqueta(EtiquetaData data) async {
    // ── STUB: Simulación de impresión ─────────────────────────────────────
    debugPrint('🖨️  PrintService: Conectando a Bluetooth...');
    debugPrint('🖨️  PrintService: Enviando etiqueta SKU=${data.skuQrFisico}');
    debugPrint('🖨️  PrintService: [STUB] Etiqueta enviada exitosamente.');

    // Simula la latencia de una conexión real (~1.5 segundos)
    await Future.delayed(const Duration(milliseconds: 1500));

    // FUTURO: Reemplazar con la implementación real de flutter_blue_plus:
    // final device = await _escanearyConectar();
    // final bytes = _serializarAEscPos(data);
    // await device.write(bytes);
  }
}
