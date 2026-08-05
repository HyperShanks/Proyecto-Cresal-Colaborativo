// lib/features/paletizado/services/print_service.dart
//
// HU-2.4 — Servicio de impresión Bluetooth (Stub de transición).
//
// ARQUITECTURA: Este servicio actúa como el "puerto" de salida (Clean Architecture)
// entre la lógica de presentación y el hardware de impresión.

import 'package:flutter/foundation.dart';
import '../domain/models/etiqueta_data.dart';

/// Servicio de abstracción para impresión de etiquetas térmicas.
class PrintService {
  /// Simula el envío de comandos ESC/POS a la impresora Bluetooth.
  ///
  /// Recibe [data] con la información del activo y simula el tiempo de transmisión.
  static Future<bool> imprimirEtiqueta(EtiquetaData data) async {
    debugPrint('📌 [PRINT_SERVICE] 🖨️ Iniciando secuencia de impresión...');
    debugPrint(
      '📌 [PRINT_SERVICE] 📦 Activo: ${data.skuQrFisico} | Folio: ${data.numeroIngreso}',
    );
    debugPrint(
      '📌 [PRINT_SERVICE] 📍 Ubicación: G:${data.galpon} / P:${data.pasillo} / Pa:${data.pallet}',
    );

    try {
      // Simulación de latencia de transmisión por Socket Bluetooth (1.5 segundos)
      await Future.delayed(const Duration(milliseconds: 1500));

      debugPrint(
        '📌 [PRINT_SERVICE] ✅ Comandos ESC/POS transmitidos con éxito.',
      );
      return true;
    } catch (e) {
      debugPrint('📌 [PRINT_SERVICE] ❌ Error en la transmisión Bluetooth: $e');
      return false;
    }
  }
}
