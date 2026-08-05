import 'dart:convert';
import 'package:http/http.dart' as http;

class InventarioService {
  // Apuntando directo a tu servidor local vía Wi-Fi
  static const String baseUrl = 'http://192.168.1.85:8000/api/v1/inventario';

  static Future<Map<String, List<String>>> obtenerOpcionesFiltros() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/opciones-filtros'));

      if (response.statusCode == 200) {
        // Decodificamos el JSON
        final Map<String, dynamic> data = jsonDecode(
          utf8.decode(response.bodyBytes),
        );

        // Convertimos las listas dinámicas a List<String> fuertemente tipadas
        return data.map(
          (key, value) => MapEntry(key, List<String>.from(value)),
        );
      } else {
        throw Exception('Error al cargar filtros: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  static Future<List<dynamic>> buscarRepuestos({
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
      // 1. Armar los Query Parameters dinámicamente solo con lo que no sea nulo
      final Map<String, String> queryParams = {};

      if (categoria != null) queryParams['categoria'] = categoria;
      if (pasillo != null) queryParams['pasillo'] = pasillo;
      if (pallet != null) queryParams['pallet'] = pallet;
      if (marca != null) queryParams['marca'] = marca;
      if (modelo != null) queryParams['modelo'] = modelo;
      if (cilindrada != null) queryParams['cilindrada'] = cilindrada;
      if (combustible != null) queryParams['combustible'] = combustible;
      if (transmision != null) queryParams['transmision'] = transmision;

      // 2. Construir la URI con los parámetros
      final uri = Uri.parse(
        '$baseUrl/buscar',
      ).replace(queryParameters: queryParams);

      // 3. Ejecutar la petición
      final response = await http.get(uri);

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
