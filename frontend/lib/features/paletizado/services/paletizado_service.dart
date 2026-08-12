// lib/features/paletizado/services/paletizado_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';

class PaletizadoService {

  Future<Map<String, dynamic>?> buscarVehiculoPorIngreso(
    String numeroIngreso,
  ) async {
    try {
      debugPrint('📌 [PALETIZADO_SERVICE] 🔍 Buscando folio: $numeroIngreso');
      final url = Uri.parse('${ApiConstants.vehiculosEndpoint}/buscar/$numeroIngreso');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint("📌 [PALETIZADO_SERVICE] ❌ Error de conexión: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> validarOCRPieza(
    String numeroIngreso,
    File imagenPosca,
  ) async {
    // ... (Mantén este método exactamente como lo tenías, solo agrégale los debugPrint si deseas)
    try {
      debugPrint('📌 [PALETIZADO_SERVICE] 🤖 Iniciando validación OCR...');
      final url = Uri.parse('${ApiConstants.vehiculosEndpoint}/validar-ocr-pieza');
      var request = http.MultipartRequest('POST', url);
      request.fields['numero_ingreso'] = numeroIngreso;
      request.files.add(
        await http.MultipartFile.fromPath('imagen_posca', imagenPosca.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint("📌 [PALETIZADO_SERVICE] ❌ Error OCR: $e");
      return null;
    }
  }

  /// Envía los datos logísticos y recibe la respuesta enriquecida para la etiqueta.
  Future<Map<String, dynamic>?> guardarPaletizadoDefinitivo({
    required String folio,
    required String tipoRepuesto,
    required String galpon,
    required String pasillo,
    required String pallet,
    String? observaciones,
    required List<File> fotos,
  }) async {
    try {
      debugPrint(
        '📌 [PALETIZADO_SERVICE] 🚀 Enviando paletizado para Folio $folio...',
      );
      final url = Uri.parse('${ApiConstants.vehiculosEndpoint}/guardar-paletizado');
      var request = http.MultipartRequest('POST', url);

      request.fields['numero_ingreso'] = folio;
      request.fields['tipo_repuesto'] = tipoRepuesto;
      request.fields['galpon'] = galpon;
      request.fields['pasillo'] = pasillo;
      request.fields['pallet'] = pallet;

      if (observaciones != null && observaciones.isNotEmpty) {
        request.fields['observaciones'] = observaciones;
      }

      for (var foto in fotos) {
        request.files.add(
          await http.MultipartFile.fromPath('fotos_comerciales', foto.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint(
          '📌 [PALETIZADO_SERVICE] ✅ Éxito. Payload recibido con SKU: ${payload["sku_qr_fisico"]}',
        );
        return payload;
      } else {
        debugPrint(
          "📌 [PALETIZADO_SERVICE] ❌ Error ${response.statusCode}: ${response.body}",
        );
        return null;
      }
    } catch (e) {
      debugPrint("📌 [PALETIZADO_SERVICE] ❌ Error crítico de red: $e");
      return null;
    }
  }
}
