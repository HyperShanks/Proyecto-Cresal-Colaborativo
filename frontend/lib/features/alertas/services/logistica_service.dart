import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tarea_alerta.dart';

import '../../../core/constants/api_constants.dart';

class LogisticaService {

  static Future<List<TareaAlerta>> obtenerAlertas() async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.bodegaEndpoint}/tareas-pendientes'));

      if (response.statusCode == 200) {
        // Aseguramos decodificación correcta para caracteres especiales/tildes
        List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
        return body.map((dynamic item) => TareaAlerta.fromJson(item)).toList();
      } else {
        throw Exception(
          'Error al cargar alertas del servidor: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}
