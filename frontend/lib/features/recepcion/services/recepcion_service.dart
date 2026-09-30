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
      debugPrint('[RECEPCION_SERVICE] Consultando siguiente correlativo en: $uri');
      http.Response res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      // Si falla en remoto o responde 404, intentar contra el backend local
      if ((res.statusCode == 404 || res.statusCode == 502 || res.statusCode == 503) &&
          !uri.host.contains('127.0.0.1') && !uri.host.contains('localhost')) {
        try {
          final localUri = Uri.parse('http://127.0.0.1:8000/api/v1/vehiculos/recepcion/siguiente-ingreso');
          debugPrint('[RECEPCION_SERVICE] Fallback local para correlativo: $localUri');
          final localRes = await http.get(localUri, headers: headers).timeout(const Duration(seconds: 4));
          if (localRes.statusCode == 200) {
            res = localRes;
          }
        } catch (_) {}
      }

      // Si da 401 por token desfasado de otro entorno, intentar sin encabezado Authorization
      if (res.statusCode == 401) {
        try {
          final localUri = Uri.parse('http://127.0.0.1:8000/api/v1/vehiculos/recepcion/siguiente-ingreso');
          final noAuthRes = await http.get(localUri).timeout(const Duration(seconds: 4));
          if (noAuthRes.statusCode == 200) {
            res = noAuthRes;
          }
        } catch (_) {}
      }

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final numFolio = data['siguiente_ingreso']?.toString() ?? '1';
        debugPrint('[RECEPCION_SERVICE] Siguiente ingreso obtenido con éxito: N° $numFolio');
        return numFolio;
      }

      // Fallback retrocompatible
      final fallbackUri = Uri.parse('${ApiConstants.vehiculosEndpoint}/siguiente-ingreso');
      final fallbackRes = await http.get(fallbackUri, headers: headers).timeout(const Duration(seconds: 10));
      if (fallbackRes.statusCode == 200) {
        final data = jsonDecode(fallbackRes.body);
        return data['siguiente_ingreso']?.toString() ?? '1';
      }
      return '1';
    } catch (e) {
      debugPrint('[RECEPCION_SERVICE] Error al obtener siguiente ingreso: $e');
      // Intento final directo a localhost
      try {
        final localUri = Uri.parse('http://127.0.0.1:8000/api/v1/vehiculos/recepcion/siguiente-ingreso');
        final localRes = await http.get(localUri).timeout(const Duration(seconds: 4));
        if (localRes.statusCode == 200) {
          final data = jsonDecode(localRes.body);
          return data['siguiente_ingreso']?.toString() ?? '1';
        }
      } catch (_) {}
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
      debugPrint('[RECEPCION_SERVICE] Consultando recientes en: $uri');

      http.Response res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
      debugPrint('[RECEPCION_SERVICE] Recientes status: ${res.statusCode}');

      // Fallback automático al backend local si el endpoint remoto responde 404 o error de gateway
      if ((res.statusCode == 404 || res.statusCode == 502 || res.statusCode == 503) &&
          !uri.host.contains('127.0.0.1') && !uri.host.contains('localhost')) {
        try {
          final localUri = Uri.parse('http://127.0.0.1:8000/api/v1/vehiculos/recepcion/recientes')
              .replace(queryParameters: queryParams);
          debugPrint('[RECEPCION_SERVICE] Fallback local para recientes: $localUri');
          final localRes = await http.get(localUri, headers: headers).timeout(const Duration(seconds: 5));
          if (localRes.statusCode == 200) {
            res = localRes;
          }
        } catch (_) {}
      }

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>? ?? []);
        debugPrint('[RECEPCION_SERVICE] Recientes obtenidos: ${items.length} vehículos');
        return items
            .map((item) => VehiculoRecepcionModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      if (res.statusCode == 401) {
        debugPrint('⚠️ [RECEPCION_SERVICE] Error 401 No Autorizado. El token guardado no coincide con el backend activo. Se requiere re-login.');
      }

      return [];
    } catch (e) {
      debugPrint('[RECEPCION_SERVICE] Error al obtener recientes: $e');
      // Intento de rescate directo a localhost
      try {
        final headers = await _headers();
        final localUri = Uri.parse('http://127.0.0.1:8000/api/v1/vehiculos/recepcion/recientes');
        final localRes = await http.get(localUri, headers: headers).timeout(const Duration(seconds: 4));
        if (localRes.statusCode == 200) {
          final data = jsonDecode(localRes.body) as Map<String, dynamic>;
          final items = (data['items'] as List<dynamic>? ?? []);
          return items
              .map((item) => VehiculoRecepcionModel.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {}
      return [];
    }
  }

  /// Registra un nuevo vehículo donante en patio con las 13 columnas.
  Future<Map<String, dynamic>> registrarVehiculo(Map<String, dynamic> datos) async {
    try {
      final headers = await _headers();
      final uri = Uri.parse('${ApiConstants.vehiculosEndpoint}/recepcion/registro');

      final res = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(datos),
      ).timeout(const Duration(seconds: 30));

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

      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 30));

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
