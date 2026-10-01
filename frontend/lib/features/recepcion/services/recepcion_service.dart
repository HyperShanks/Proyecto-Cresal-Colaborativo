import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../auth/services/auth_service.dart';
import '../models/vehiculo_recepcion_model.dart';

class RecepcionService {
  Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Consulta el siguiente número correlativo de patio.
  Future<String> obtenerSiguienteIngreso() async {
    try {
      final headers = await _headers();
      final uri = Uri.parse('${ApiConstants.vehiculosEndpoint}/recepcion/siguiente-ingreso');
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['siguiente_ingreso']?.toString() ?? '1';
      }

      // Fallback retrocompatible
      final fallbackUri = Uri.parse('${ApiConstants.vehiculosEndpoint}/siguiente-ingreso');
      final fallbackRes = await http.get(fallbackUri, headers: headers).timeout(const Duration(seconds: 15));
      if (fallbackRes.statusCode == 200) {
        final data = jsonDecode(fallbackRes.body);
        return data['siguiente_ingreso']?.toString() ?? '1';
      }
      return '1';
    } catch (e) {
      debugPrint('[RECEPCION_SERVICE] Error al obtener siguiente ingreso: $e');
      return '1';
    }
  }

  /// Obtiene los ingresos vehiculares recientes con soporte de búsqueda para patio.
  Future<List<VehiculoRecepcionModel>> obtenerRecientes({
    String? busqueda,
    int limite = 50,
  }) async {
    try {
      final headers = await _headers();
      final queryParams = <String, String>{
        'limite': limite.toString(),
        if (busqueda != null && busqueda.trim().isNotEmpty) 'busqueda': busqueda.trim(),
      };

      final uri = Uri.parse('${ApiConstants.vehiculosEndpoint}/recepcion/recientes')
          .replace(queryParameters: queryParams);

      var res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));

      // Si el servidor configurado (ej: Render) devuelve 404 porque aún no ha desplegado la ruta,
      // intentamos fallback automático al servidor local de desarrollo si está disponible.
      if (res.statusCode == 404 && !uri.host.contains('127.0.0.1') && !uri.host.contains('localhost')) {
        try {
          final fallbackLocalUri = Uri.parse('http://127.0.0.1:8000/api/v1/vehiculos/recepcion/recientes')
              .replace(queryParameters: queryParams);
          final localRes = await http.get(fallbackLocalUri, headers: headers).timeout(const Duration(seconds: 4));
          if (localRes.statusCode == 200) {
            res = localRes;
          }
        } catch (_) {}
      }

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>? ?? []);
        return items
            .map((item) => VehiculoRecepcionModel.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        debugPrint('[RECEPCION_SERVICE] HTTP ${res.statusCode} al obtener recientes: ${res.body}');
      }
      return [];
    } catch (e) {
      debugPrint('[RECEPCION_SERVICE] Error al obtener recientes: $e');
      return [];
    }
  }

  /// Registra un nuevo vehículo donante en patio con las 13 columnas.
  Future<Map<String, dynamic>> registrarVehiculo(Map<String, dynamic> datos) async {
    try {
      final headers = await _headers();
      final uri = Uri.parse('${ApiConstants.vehiculosEndpoint}/recepcion/registro');

      var res = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(datos),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 404 && !uri.host.contains('127.0.0.1') && !uri.host.contains('localhost')) {
        try {
          final localUri = Uri.parse('http://127.0.0.1:8000/api/v1/vehiculos/recepcion/registro');
          final localRes = await http.post(
            localUri,
            headers: headers,
            body: jsonEncode(datos),
          ).timeout(const Duration(seconds: 15));
          if (localRes.statusCode == 200 || localRes.statusCode == 201) {
            res = localRes;
          }
        } catch (_) {}
      }

      final body = jsonDecode(res.body);

      if (res.statusCode == 200 || res.statusCode == 201) {
        return {
          'exito': true,
          'mensaje': 'Vehículo registrado exitosamente en patio',
          'vehiculo': VehiculoRecepcionModel.fromJson(body as Map<String, dynamic>),
        };
      } else {
        final detail = body['detail'] ?? 'Error al registrar vehículo en patio';
        return {
          'exito': false,
          'mensaje': detail.toString(),
        };
      }
    } catch (e) {
      debugPrint('[RECEPCION_SERVICE] Error en registrarVehiculo: $e');
      return {
        'exito': false,
        'mensaje': 'Error de comunicación: $e',
      };
    }
  }

  /// Obtiene la matriz completa formateada en TSV para copiado directo a Excel o Google Sheets.
  Future<Map<String, dynamic>> exportarMatriz({int limite = 100}) async {
    try {
      final headers = await _headers();
      final uri = Uri.parse('${ApiConstants.vehiculosEndpoint}/recepcion/exportar-matriz?limite=$limite');

      var res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 30));

      if (res.statusCode == 404 && !uri.host.contains('127.0.0.1') && !uri.host.contains('localhost')) {
        try {
          final localUri = Uri.parse('http://127.0.0.1:8000/api/v1/vehiculos/recepcion/exportar-matriz?limite=$limite');
          final localRes = await http.get(localUri, headers: headers).timeout(const Duration(seconds: 15));
          if (localRes.statusCode == 200) {
            res = localRes;
          }
        } catch (_) {}
      }

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return {
          'exito': true,
          'tsv': data['tsv'] as String? ?? '',
          'total': data['total'] as int? ?? 0,
        };
      } else {
        return {
          'exito': false,
          'mensaje': 'Error al exportar matriz vehicular',
        };
      }
    } catch (e) {
      return {
        'exito': false,
        'mensaje': 'Error de red: $e',
      };
    }
  }
}
