import 'dart:convert';
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
}
