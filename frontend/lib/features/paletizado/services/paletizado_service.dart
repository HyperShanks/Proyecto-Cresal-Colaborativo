import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:flutter/foundation.dart';

class PaletizadoService {
  // Usamos la misma IP de tu red local que configuramos en la HU anterior
  static const String baseUrl =
      'https://cresal-backend-dev.onrender.com/api/v1/vehiculos';

  /// Busca un vehículo por su folio. Retorna un Map con los datos si lo encuentra, o null si falla/no existe.
  Future<Map<String, dynamic>?> buscarVehiculoPorIngreso(
    String numeroIngreso,
  ) async {
    try {
      final url = Uri.parse('$baseUrl/buscar/$numeroIngreso');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        // Podríamos manejar el error 404 específicamente, pero por ahora null basta para la UI
        return null;
      }
    } catch (e) {
      print("Error de conexión en buscarVehiculoPorIngreso: $e");
      return null;
    }
  }

  /// Envía la foto de validación y el folio a FastAPI para que Google Vision los compare.
  Future<Map<String, dynamic>?> validarOCRPieza(
    String numeroIngreso,
    File imagenPosca,
  ) async {
    try {
      final url = Uri.parse('$baseUrl/validar-ocr-pieza');

      // Creamos una petición multipart para enviar el texto y la imagen juntos
      var request = http.MultipartRequest('POST', url);

      // Agregamos el texto (Form data)
      request.fields['numero_ingreso'] = numeroIngreso;

      // Agregamos el archivo de la imagen
      request.files.add(
        await http.MultipartFile.fromPath('imagen_posca', imagenPosca.path),
      );

      // Enviamos la petición y esperamos la respuesta del servidor
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint("Error del servidor OCR: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("Error de conexión en validarOCRPieza: $e");
      return null;
    }
  }

  /// Envía los datos logísticos y la lista de fotos a FastAPI
  Future<bool> guardarPaletizadoDefinitivo({
    required String folio,
    required String tipoRepuesto,
    required String galpon,
    required String pasillo,
    required String pallet,
    String? observaciones, // <-- Parámetro opcional agregado
    required List<File> fotos,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/guardar-paletizado');
      var request = http.MultipartRequest('POST', url);

      // 1. Agregamos los datos de texto
      request.fields['numero_ingreso'] = folio;
      request.fields['tipo_repuesto'] = tipoRepuesto;
      request.fields['galpon'] = galpon;
      request.fields['pasillo'] = pasillo;
      request.fields['pallet'] = pallet;

      // 2. Si hay observación, la enviamos al backend
      if (observaciones != null && observaciones.isNotEmpty) {
        request.fields['observaciones'] = observaciones;
      }

      // 3. Agregamos TODAS las fotos al request
      for (var foto in fotos) {
        request.files.add(
          await http.MultipartFile.fromPath('fotos_comerciales', foto.path),
        );
      }

      // 4. Enviamos el paquete
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return true;
      } else {
        print(
          "Error al guardar paletizado: ${response.statusCode} - ${response.body}",
        );
        return false;
      }
    } catch (e) {
      print("Error de conexión en guardarPaletizadoDefinitivo: $e");
      return false;
    }
  }
}
