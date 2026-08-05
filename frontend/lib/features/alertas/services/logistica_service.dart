import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tarea_alerta.dart';

class LogisticaService {
  // Si estás probando en local con el emulador, usa 'http://10.0.2.2:8000'
  // Si ya subiste el tareas.py a Render, usa tu URL de Render: 'https://cresal-backend-dev.onrender.com'
  static const String baseUrl =
      'https://cresal-backend-dev.onrender.com/api/v1/bodega';

  static Future<List<TareaAlerta>> obtenerAlertas() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/tareas-pendientes'));

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
