import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../../auth/services/auth_service.dart';
class InventarioService {

  static Future<Map<String, List<String>>> obtenerOpcionesFiltros({
    String? categoria,
    String? pasillo,
    String? pallet,
    String? marca,
    String? modelo,
    String? cilindrada,
    String? combustible,
    String? transmision,
  }) async {
    try {
      final Map<String, String> queryParams = {};

      if (categoria != null) queryParams['categoria'] = categoria;
      if (pasillo != null) queryParams['pasillo'] = pasillo;
      if (pallet != null) queryParams['pallet'] = pallet;
      if (marca != null) queryParams['marca'] = marca;
      if (modelo != null) queryParams['modelo'] = modelo;
      if (cilindrada != null) queryParams['cilindrada'] = cilindrada;
      if (combustible != null) queryParams['combustible'] = combustible;
      if (transmision != null) queryParams['transmision'] = transmision;

      final uri = Uri.parse(
        '${ApiConstants.inventarioEndpoint}/opciones-filtros',
      ).replace(queryParameters: queryParams);
      final token = await AuthService.getToken();
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        return data.map(
          (key, value) => MapEntry(key, List<String>.from(value)),
        );
      } else {
        throw Exception('Error al cargar filtros dinámicos');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  static Future<List<dynamic>> buscarRepuestos({
    String? q,
    String? categoria,
    String? pasillo,
    String? pallet,
    String? marca,
    String? modelo,
    String? cilindrada,
    String? combustible,
    String? transmision,
    String? estado,
    int? limit,
    int? offset,
  }) async {
    try {
      // 1. Armar los Query Parameters dinámicamente solo con lo que no sea nulo
      final Map<String, String> queryParams = {};

      if (q != null && q.trim().isNotEmpty) queryParams['q'] = q.trim();
      if (categoria != null) queryParams['categoria'] = categoria;
      if (pasillo != null) queryParams['pasillo'] = pasillo;
      if (pallet != null) queryParams['pallet'] = pallet;
      if (marca != null) queryParams['marca'] = marca;
      if (modelo != null) queryParams['modelo'] = modelo;
      if (cilindrada != null) queryParams['cilindrada'] = cilindrada;
      if (combustible != null) queryParams['combustible'] = combustible;
      if (transmision != null) queryParams['transmision'] = transmision;
      if (estado != null && estado.trim().isNotEmpty) {
        queryParams['estado'] = estado.trim();
      }
      if (limit != null) queryParams['limit'] = limit.toString();
      if (offset != null) queryParams['offset'] = offset.toString();

      // 2. Construir la URI con los parámetros
      final uri = Uri.parse(
        '${ApiConstants.inventarioEndpoint}/buscar',
      ).replace(queryParameters: queryParams);

      // 3. Ejecutar la petición
      final token = await AuthService.getToken();
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('Error en búsqueda: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Edita la ubicación física y notas técnicas de un activo con control de concurrencia optimista (HU-11).
  static Future<Map<String, dynamic>> editarActivo(
    String idActivo,
    Map<String, dynamic> datos, {
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final uri = Uri.parse('${ApiConstants.inventarioEndpoint}/$idActivo');
      final token = await AuthService.getToken();
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final response = await httpClient
          .patch(
            uri,
            headers: headers,
            body: jsonEncode(datos),
          )
          .timeout(const Duration(seconds: 12));

      Map<String, dynamic> body = {};
      if (response.body.isNotEmpty) {
        try {
          body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        } catch (_) {}
      }

      if (response.statusCode == 200) {
        return body;
      } else if (response.statusCode == 409) {
        final msg = body['message_user'] ??
            body['detail'] ??
            'La información de este repuesto fue modificada por otro usuario recientemente. Los datos se actualizarán ahora para que revises los cambios antes de volver a editar.';
        throw Exception(msg);
      } else if (response.statusCode == 400) {
        final msg = body['message_user'] ??
            body['detail'] ??
            'Este artículo ya fue despachado o cobrado. Ya no es posible modificar su ubicación técnica.';
        throw Exception(msg);
      } else if (response.statusCode == 403) {
        final msg = body['message_user'] ??
            body['detail'] ??
            'Acceso restringido: Se requieren permisos de Bodeguero o Administrador.';
        throw Exception(msg);
      } else {
        final msg = body['message_user'] ?? body['detail'] ?? 'Error al actualizar el activo';
        throw Exception(msg);
      }
    } on SocketException {
      throw Exception('Conexión inestable. No pudimos guardar tus cambios. Por favor, reintenta en unos segundos.');
    } on TimeoutException {
      throw Exception('Conexión inestable. No pudimos guardar tus cambios. Por favor, reintenta en unos segundos.');
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('SocketException') ||
          errStr.contains('TimeoutException') ||
          errStr.contains('Tiempo de espera') ||
          errStr.contains('Conexión inestable')) {
        throw Exception('Conexión inestable. No pudimos guardar tus cambios. Por favor, reintenta en unos segundos.');
      }
      rethrow;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }
}

